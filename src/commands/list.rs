use anyhow::Result;
use std::fs;

use crate::config::Config;
use crate::utils;

/// List available environments for the current project
pub fn run(config: &Config) -> Result<()> {
    config.check_init()?;

    let project_dir = config.project_dir();

    if !project_dir.exists() {
        utils::err(&format!("No environments for project '{}'", config.project));
        utils::info("Create one with: senv edit <environment>");
        anyhow::bail!("No environments found");
    }

    let envs = list_environments(config)?;

    if envs.is_empty() {
        utils::err(&format!("No environments for project '{}'", config.project));
        utils::info("Create one with: senv edit <environment>");
        anyhow::bail!("No environments found");
    }

    for env in envs {
        println!("{}", env);
    }

    Ok(())
}

/// Get list of environment names for the current project
pub fn list_environments(config: &Config) -> Result<Vec<String>> {
    let project_dir = config.project_dir();

    if !project_dir.exists() {
        return Ok(vec![]);
    }

    let mut envs = Vec::new();

    for entry in fs::read_dir(&project_dir)? {
        let entry = entry?;
        let path = entry.path();

        if path.is_file() {
            if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
                if name.ends_with(".env.enc") {
                    let env_name = name.trim_end_matches(".env.enc");
                    envs.push(env_name.to_string());
                }
            }
        }
    }

    envs.sort();
    Ok(envs)
}
