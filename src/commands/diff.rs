use anyhow::{Context, Result};
use std::fs;
use std::path::Path;

use crate::config::Config;
use crate::sops;
use crate::utils;

/// Show diff between local .env and stored version
pub fn run(config: &Config, env_arg: Option<&str>) -> Result<()> {
    let missing = utils::check_deps(&["sops"]);
    if !missing.is_empty() {
        utils::print_install_instructions(&missing);
        anyhow::bail!("Missing dependencies");
    }
    config.check_init()?;

    let env_file = Path::new(".env");

    if !env_file.exists() {
        utils::err("No .env file in current directory");
        anyhow::bail!("No .env file found");
    }

    // Read local .env
    let local_content = fs::read_to_string(env_file).context("Failed to read .env file")?;

    // Get environment name from argument or header
    let env = match env_arg {
        Some(e) => e.to_string(),
        None => match utils::read_header_value(&local_content, "# senv:") {
            Some(e) => e,
            None => {
                utils::err("Usage: senv diff <environment>");
                anyhow::bail!("Environment name required");
            }
        },
    };

    let enc_path = config.enc_path(&env);

    if !enc_path.exists() {
        utils::err(&format!("Environment '{}' not found", env));
        anyhow::bail!("Environment not found");
    }

    // Decrypt stored version
    let stored = sops::decrypt(&config.sops_config_path(), &enc_path)?;

    // Strip headers from local content
    let local_clean = utils::strip_senv_headers(&local_content);

    // Compare and show diff
    show_diff(&stored, &local_clean, &env);

    Ok(())
}

/// Display a simple unified diff between stored and local content
fn show_diff(stored: &str, local: &str, env: &str) {
    let stored_lines: Vec<&str> = stored.lines().collect();
    let local_lines: Vec<&str> = local.lines().collect();

    if stored_lines == local_lines {
        println!("No differences found.");
        return;
    }

    println!("--- stored ({})", env);
    println!("+++ local (.env)");
    println!();

    // Simple line-by-line comparison
    // For a more sophisticated diff, consider using the `similar` crate
    let max_lines = stored_lines.len().max(local_lines.len());

    for i in 0..max_lines {
        let stored_line = stored_lines.get(i).copied();
        let local_line = local_lines.get(i).copied();

        match (stored_line, local_line) {
            (Some(s), Some(l)) if s == l => {
                println!(" {}", s);
            }
            (Some(s), Some(l)) => {
                println!("-{}", s);
                println!("+{}", l);
            }
            (Some(s), None) => {
                println!("-{}", s);
            }
            (None, Some(l)) => {
                println!("+{}", l);
            }
            (None, None) => {}
        }
    }
}
