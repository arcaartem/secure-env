use anyhow::Result;

use crate::config::Config;
use crate::utils;

/// Print the secrets repo path
pub fn run(config: &Config) -> Result<()> {
    config.check_init()?;

    println!("{}", config.secrets_path.display());
    utils::info("Run: cd \"$(senv repo)\" to change directory");

    Ok(())
}
