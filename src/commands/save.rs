use anyhow::{Context, Result};
use std::fs;
use std::path::Path;

use crate::config::Config;
use crate::git;
use crate::sops;
use crate::utils;

/// Encrypt current .env back to secrets repo
pub fn run(config: &Config) -> Result<()> {
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

    // Read and parse .env
    let content = fs::read_to_string(env_file).context("Failed to read .env file")?;

    // Get environment from header
    let env = match utils::read_header_value(&content, "# senv:") {
        Some(e) => e,
        None => {
            utils::err(".env was not created by senv (missing header)");
            utils::info("Use 'senv edit <env>' to create a new environment");
            anyhow::bail!("Invalid .env file");
        }
    };

    let enc_path = config.enc_path(&env);

    // Create backup if file exists
    let backup_path = enc_path.with_extension("env.enc.backup");
    if enc_path.exists() {
        fs::copy(&enc_path, &backup_path).context("Failed to create backup")?;
    }

    utils::info(&format!("Encrypting .env → {}", env));

    // Strip headers and encrypt
    let stripped = utils::strip_senv_headers(&content);

    match sops::encrypt(&config.sops_config_path(), &stripped, &enc_path) {
        Ok(encrypted) => {
            fs::write(&enc_path, encrypted).context("Failed to write encrypted file")?;

            // Remove backup on success
            let _ = fs::remove_file(&backup_path);

            utils::success(&format!("Saved to {}", enc_path.display()));

            // Auto-commit
            let relative_path = format!("{}/{}.env.enc", config.project, env);
            let commit_msg = format!("Update {}/{} environment", config.project, env);

            if let Err(e) = git::add_and_commit(&config.secrets_path, &relative_path, &commit_msg) {
                // Git commit failure is not fatal
                utils::warn(&format!("Auto-commit failed: {}", e));
            }

            Ok(())
        }
        Err(e) => {
            // Restore from backup on failure
            if backup_path.exists() {
                utils::info("Restoring from backup");
                let _ = fs::rename(&backup_path, &enc_path);
            }
            Err(e)
        }
    }
}
