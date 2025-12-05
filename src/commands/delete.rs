use anyhow::Result;
use std::fs;

use crate::config::Config;
use crate::utils;

/// Delete an environment permanently
pub fn run(config: &Config, env: &str) -> Result<()> {
    config.check_init()?;

    let enc_path = config.enc_path(env);

    if !enc_path.exists() {
        utils::err(&format!(
            "Environment '{}' not found for project '{}'",
            env, config.project
        ));
        anyhow::bail!("Environment not found");
    }

    utils::warn(&format!(
        "This will permanently delete the '{}' environment for '{}'",
        env, config.project
    ));

    if !utils::confirm("Are you sure?")? {
        return Ok(());
    }

    // Delete the encrypted file
    fs::remove_file(&enc_path)?;

    // Delete backup if exists
    let backup_path = enc_path.with_extension("env.enc.backup");
    let _ = fs::remove_file(backup_path);

    utils::success(&format!("Deleted '{}' environment", env));

    // Clean up empty project directory
    let project_dir = config.project_dir();
    if project_dir.exists() {
        if let Ok(entries) = fs::read_dir(&project_dir) {
            if entries.count() == 0 {
                let _ = fs::remove_dir(&project_dir);
                utils::info("Removed empty project directory");
            }
        }
    }

    Ok(())
}
