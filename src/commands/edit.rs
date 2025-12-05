use anyhow::{Context, Result};
use std::fs;

use crate::config::Config;
use crate::sops;
use crate::utils;

/// Edit encrypted environment file
pub fn run(config: &Config, env: &str) -> Result<()> {
    let missing = utils::check_deps(&["sops"]);
    if !missing.is_empty() {
        utils::print_install_instructions(&missing);
        anyhow::bail!("Missing dependencies");
    }
    config.check_init()?;

    let enc_path = config.enc_path(env);
    let project_dir = config.project_dir();

    // Create project directory if needed
    if !project_dir.exists() {
        fs::create_dir_all(&project_dir).context("Failed to create project directory")?;
    }

    // Create new file if it doesn't exist
    if !enc_path.exists() {
        utils::info(&format!("Creating new environment: {}", env));

        // Create minimal encrypted file
        let initial_content = "# Add your environment variables below\n";
        sops::create(&config.sops_config_path(), initial_content, &enc_path)?;
    }

    // Open in editor via SOPS
    sops::edit(&config.sops_config_path(), &enc_path)?;

    utils::success(&format!("Saved {} environment", env));

    Ok(())
}
