use anyhow::{Context, Result};
use std::fs;
use std::path::Path;

use crate::commands::list::list_environments;
use crate::config::Config;
use crate::sops;
use crate::utils;

/// Export all environments as .env.<env> files
pub fn run(config: &Config, output_dir: Option<&Path>, force: bool) -> Result<()> {
    let missing = utils::check_deps(&["sops"]);
    if !missing.is_empty() {
        utils::print_install_instructions(&missing);
        anyhow::bail!("Missing dependencies");
    }
    config.check_init()?;

    let output_dir = output_dir.unwrap_or(Path::new("."));

    // Check output directory exists
    if !output_dir.exists() {
        utils::err(&format!(
            "Output directory does not exist: {}",
            output_dir.display()
        ));
        anyhow::bail!("Output directory not found");
    }

    // Get list of environments
    let envs = list_environments(config)?;

    if envs.is_empty() {
        utils::warn(&format!(
            "No environments found for project '{}'",
            config.project
        ));
        return Ok(());
    }

    // Pre-check for conflicts (unless --force)
    if !force {
        let mut conflicts = Vec::new();
        for env in &envs {
            let target = output_dir.join(format!(".env.{}", env));
            if target.exists() {
                conflicts.push(target);
            }
        }

        if !conflicts.is_empty() {
            utils::err("Target files already exist:");
            for path in &conflicts {
                eprintln!("  - {}", path.display());
            }
            utils::info("Use --force to overwrite");
            anyhow::bail!("Target files exist");
        }
    }

    // Export all environments
    utils::info(&format!(
        "Exporting {} environment(s) for '{}'",
        envs.len(),
        config.project
    ));

    for env in &envs {
        let enc_path = config.enc_path(env);
        let target = output_dir.join(format!(".env.{}", env));

        let decrypted = sops::decrypt(&config.sops_config_path(), &enc_path)
            .with_context(|| format!("Failed to decrypt {}", env))?;

        fs::write(&target, decrypted).with_context(|| format!("Failed to write {}", target.display()))?;

        utils::success(&format!("Exported: {}", target.display()));
    }

    utils::success(&format!(
        "Exported {} environment(s) to {}",
        envs.len(),
        output_dir.display()
    ));

    Ok(())
}
