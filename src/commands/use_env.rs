use anyhow::{Context, Result};
use std::fs;
use std::path::Path;

use crate::config::Config;
use crate::sops;
use crate::utils;

/// Decrypt environment and write .env
pub fn run(config: &Config, env: &str) -> Result<()> {
    let missing = utils::check_deps(&["sops"]);
    if !missing.is_empty() {
        utils::print_install_instructions(&missing);
        anyhow::bail!("Missing dependencies");
    }
    config.check_init()?;

    let enc_path = config.enc_path(env);

    if !enc_path.exists() {
        utils::err(&format!(
            "Environment '{}' not found for project '{}'",
            env, config.project
        ));
        utils::info(&format!("Create it with: senv edit {}", env));
        anyhow::bail!("Environment not found");
    }

    // Check for unsaved changes from different environment
    let env_file = Path::new(".env");
    if env_file.exists() {
        let content = fs::read_to_string(env_file)?;
        if let Some(current_env) = utils::read_header_value(&content, "# senv:") {
            if current_env != env {
                utils::warn(&format!(
                    "Current .env is from '{}' environment",
                    current_env
                ));
            }
        }
    }

    utils::info(&format!("Decrypting {} → .env", env));

    // Decrypt the file
    let decrypted = sops::decrypt(&config.sops_config_path(), &enc_path)
        .context("Decryption failed")?;

    // Write .env with headers
    let content = format!(
        "# senv: {}\n# Decrypted from: {}\n# Do not commit this file!\n\n{}",
        env,
        enc_path.display(),
        decrypted
    );

    fs::write(env_file, content).context("Failed to write .env file")?;

    utils::success(&format!(
        "Activated '{}' environment for '{}'",
        env, config.project
    ));

    // Tip about .envrc
    if !Path::new(".envrc").exists() {
        utils::info("Tip: Create .envrc with 'dotenv' for auto-loading");
    }

    Ok(())
}
