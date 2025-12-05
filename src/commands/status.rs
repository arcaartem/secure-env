use anyhow::Result;
use std::fs;
use std::path::Path;

use crate::commands::list::list_environments;
use crate::config::Config;
use crate::utils;

/// Show current project status
pub fn run(config: &Config) -> Result<()> {
    config.check_init()?;

    println!("Project: {}", config.project);

    // Check for current .env and its environment
    let env_file = Path::new(".env");
    if env_file.exists() {
        let content = fs::read_to_string(env_file)?;
        let env_name = utils::read_header_value(&content, "# senv:")
            .unwrap_or_else(|| "unknown".to_string());
        println!("Active: {}", env_name);
    } else {
        println!("Active: (none)");
    }

    println!("Available:");
    match list_environments(config) {
        Ok(envs) if !envs.is_empty() => {
            for env in envs {
                println!("  - {}", env);
            }
        }
        _ => {
            println!("  (none)");
        }
    }

    Ok(())
}
