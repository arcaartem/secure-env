use anyhow::{Context, Result};
use std::fs;
use std::path::Path;

use crate::config::Config;
use crate::sops;
use crate::utils;

/// Import all .env.<env> files into secrets repo
pub fn run(config: &Config, force: bool, keep: bool) -> Result<()> {
    let missing = utils::check_deps(&["sops"]);
    if !missing.is_empty() {
        utils::print_install_instructions(&missing);
        anyhow::bail!("Missing dependencies");
    }
    config.check_init()?;

    // Discover .env.<suffix> files (single suffix only)
    let current_dir = Path::new(".");
    let mut files_to_import: Vec<(String, String)> = Vec::new(); // (filename, env_name)

    for entry in fs::read_dir(current_dir)? {
        let entry = entry?;
        let path = entry.path();

        if !path.is_file() {
            continue;
        }

        if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
            // Match .env.* pattern
            if !name.starts_with(".env.") {
                continue;
            }

            let suffix = name.trim_start_matches(".env.");

            // Skip if suffix contains a dot (multi-suffix like .env.local.backup)
            if suffix.contains('.') {
                continue;
            }

            // Skip known extensions
            if matches!(suffix, "enc" | "backup" | "example" | "sample") {
                continue;
            }

            files_to_import.push((name.to_string(), suffix.to_string()));
        }
    }

    if files_to_import.is_empty() {
        utils::warn("No .env.<environment> files found to import");
        return Ok(());
    }

    // Pre-check for conflicts in repo (unless --force)
    if !force {
        let mut conflicts = Vec::new();
        for (_, env) in &files_to_import {
            let enc_path = config.enc_path(env);
            if enc_path.exists() {
                conflicts.push(env.clone());
            }
        }

        if !conflicts.is_empty() {
            utils::err("Environments already exist in secrets repo:");
            for env in &conflicts {
                eprintln!("  - {}", env);
            }
            utils::info("Use --force to overwrite");
            anyhow::bail!("Environments already exist");
        }
    }

    // Create project directory if needed
    let project_dir = config.project_dir();
    if !project_dir.exists() {
        fs::create_dir_all(&project_dir).context("Failed to create project directory")?;
    }

    // Import all files
    utils::info(&format!(
        "Importing {} environment(s) for '{}'",
        files_to_import.len(),
        config.project
    ));

    for (filename, env) in &files_to_import {
        let source_path = current_dir.join(filename);
        let enc_path = config.enc_path(env);

        // Read source file
        let content = fs::read_to_string(&source_path)
            .with_context(|| format!("Failed to read {}", filename))?;

        // Encrypt using SOPS
        let encrypted = sops::encrypt(&config.sops_config_path(), &content, &enc_path)
            .with_context(|| format!("Failed to encrypt {}", env))?;

        fs::write(&enc_path, encrypted)
            .with_context(|| format!("Failed to write {}", enc_path.display()))?;

        utils::success(&format!("Imported: {} → {}", filename, env));

        // Delete source file unless --keep
        if !keep {
            fs::remove_file(&source_path)?;
        }
    }

    utils::success(&format!(
        "Imported {} environment(s)",
        files_to_import.len()
    ));

    if keep {
        utils::info("Source files preserved (--keep)");
    } else {
        utils::info("Source files deleted");
    }

    utils::info(&format!(
        "Don't forget to commit changes in {}",
        config.secrets_path.display()
    ));

    Ok(())
}
