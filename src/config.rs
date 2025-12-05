use anyhow::{Context, Result};
use std::env;
use std::path::PathBuf;

/// Default secrets directory location
const DEFAULT_SECRETS_DIR: &str = ".local/share/senv";

/// Configuration for senv operations
#[derive(Debug, Clone)]
pub struct Config {
    /// Project name (from flag, env var, or current directory)
    pub project: String,
    /// Path to secrets repository
    pub secrets_path: PathBuf,
}

impl Config {
    /// Create a new Config, resolving values from flags, env vars, and defaults
    ///
    /// Priority (highest to lowest):
    /// 1. CLI flags
    /// 2. Environment variables (SENV_PROJECT, SENV_SECRETS_PATH)
    /// 3. Defaults (current directory name, ~/.local/share/senv)
    pub fn new(project_override: Option<String>, secrets_path_override: Option<PathBuf>) -> Result<Self> {
        let project = Self::resolve_project(project_override)?;
        let secrets_path = Self::resolve_secrets_path(secrets_path_override)?;

        Ok(Config {
            project,
            secrets_path,
        })
    }

    /// Resolve project name: flag > env var > current directory name
    fn resolve_project(override_value: Option<String>) -> Result<String> {
        if let Some(project) = override_value {
            return Ok(project);
        }

        if let Ok(project) = env::var("SENV_PROJECT") {
            if !project.is_empty() {
                return Ok(project);
            }
        }

        // Default to current directory name
        let cwd = env::current_dir().context("Failed to get current directory")?;
        let dir_name = cwd
            .file_name()
            .and_then(|s| s.to_str())
            .map(String::from)
            .context("Failed to get directory name")?;

        Ok(dir_name)
    }

    /// Resolve secrets path: flag > env var > default
    fn resolve_secrets_path(override_value: Option<PathBuf>) -> Result<PathBuf> {
        if let Some(path) = override_value {
            return Ok(path);
        }

        if let Ok(path) = env::var("SENV_SECRETS_PATH") {
            if !path.is_empty() {
                return Ok(PathBuf::from(path));
            }
        }

        // Default to ~/.local/share/senv
        let home = dirs::home_dir().context("Failed to determine home directory")?;
        Ok(home.join(DEFAULT_SECRETS_DIR))
    }

    /// Get the path to the .sops.yaml config file
    pub fn sops_config_path(&self) -> PathBuf {
        self.secrets_path.join(".sops.yaml")
    }

    /// Get the project directory within secrets path
    pub fn project_dir(&self) -> PathBuf {
        self.secrets_path.join(&self.project)
    }

    /// Get the encrypted file path for a given environment
    pub fn enc_path(&self, env: &str) -> PathBuf {
        self.project_dir().join(format!("{}.env.enc", env))
    }

    /// Check if senv is initialized (has .sops.yaml)
    pub fn is_initialized(&self) -> bool {
        self.sops_config_path().exists()
    }

    /// Ensure senv is initialized, returning an error if not
    pub fn check_init(&self) -> Result<()> {
        if !self.is_initialized() {
            anyhow::bail!(
                "senv not initialized. Run 'senv init' first.\n\
                 Secrets path: {}",
                self.secrets_path.display()
            );
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    // =============================================================================
    // enc_path tests
    // =============================================================================

    #[test]
    fn test_enc_path() {
        let config = Config {
            project: "myproject".to_string(),
            secrets_path: PathBuf::from("/home/user/.local/share/senv"),
        };

        assert_eq!(
            config.enc_path("local"),
            PathBuf::from("/home/user/.local/share/senv/myproject/local.env.enc")
        );
    }

    #[test]
    fn test_enc_path_with_hyphens() {
        let config = Config {
            project: "my-project".to_string(),
            secrets_path: PathBuf::from("/path/to/secrets"),
        };

        assert_eq!(
            config.enc_path("pre-prod"),
            PathBuf::from("/path/to/secrets/my-project/pre-prod.env.enc")
        );
    }

    #[test]
    fn test_enc_path_with_underscores() {
        let config = Config {
            project: "my_project".to_string(),
            secrets_path: PathBuf::from("/path/to/secrets"),
        };

        assert_eq!(
            config.enc_path("my_local_env"),
            PathBuf::from("/path/to/secrets/my_project/my_local_env.env.enc")
        );
    }

    // =============================================================================
    // sops_config_path tests
    // =============================================================================

    #[test]
    fn test_sops_config_path() {
        let config = Config {
            project: "test".to_string(),
            secrets_path: PathBuf::from("/path/to/secrets"),
        };

        assert_eq!(
            config.sops_config_path(),
            PathBuf::from("/path/to/secrets/.sops.yaml")
        );
    }

    // =============================================================================
    // project_dir tests
    // =============================================================================

    #[test]
    fn test_project_dir() {
        let config = Config {
            project: "testproject".to_string(),
            secrets_path: PathBuf::from("/path/to/secrets"),
        };

        assert_eq!(
            config.project_dir(),
            PathBuf::from("/path/to/secrets/testproject")
        );
    }

    // =============================================================================
    // is_initialized tests
    // =============================================================================

    #[test]
    fn test_is_initialized_false() {
        let temp_dir = TempDir::new().unwrap();
        let config = Config {
            project: "test".to_string(),
            secrets_path: temp_dir.path().to_path_buf(),
        };

        assert!(!config.is_initialized());
    }

    #[test]
    fn test_is_initialized_true() {
        let temp_dir = TempDir::new().unwrap();
        fs::write(temp_dir.path().join(".sops.yaml"), "creation_rules: []").unwrap();

        let config = Config {
            project: "test".to_string(),
            secrets_path: temp_dir.path().to_path_buf(),
        };

        assert!(config.is_initialized());
    }

    // =============================================================================
    // check_init tests
    // =============================================================================

    #[test]
    fn test_check_init_fails_when_not_initialized() {
        let temp_dir = TempDir::new().unwrap();
        let config = Config {
            project: "test".to_string(),
            secrets_path: temp_dir.path().to_path_buf(),
        };

        let result = config.check_init();
        assert!(result.is_err());
        let err_msg = result.unwrap_err().to_string();
        assert!(err_msg.contains("not initialized"));
        assert!(err_msg.contains("senv init"));
    }

    #[test]
    fn test_check_init_succeeds_when_initialized() {
        let temp_dir = TempDir::new().unwrap();
        fs::write(temp_dir.path().join(".sops.yaml"), "creation_rules: []").unwrap();

        let config = Config {
            project: "test".to_string(),
            secrets_path: temp_dir.path().to_path_buf(),
        };

        assert!(config.check_init().is_ok());
    }

    // =============================================================================
    // resolve tests (with env var manipulation)
    // =============================================================================

    #[test]
    fn test_new_with_overrides() {
        let temp_dir = TempDir::new().unwrap();
        let config = Config::new(
            Some("override-project".to_string()),
            Some(temp_dir.path().to_path_buf()),
        ).unwrap();

        assert_eq!(config.project, "override-project");
        assert_eq!(config.secrets_path, temp_dir.path());
    }

    #[test]
    fn test_project_override_takes_precedence() {
        // Even with SENV_PROJECT set, override should win
        let original = env::var("SENV_PROJECT").ok();
        env::set_var("SENV_PROJECT", "env-project");

        let config = Config::new(
            Some("override-project".to_string()),
            None,
        ).unwrap();

        assert_eq!(config.project, "override-project");

        // Restore original env
        if let Some(val) = original {
            env::set_var("SENV_PROJECT", val);
        } else {
            env::remove_var("SENV_PROJECT");
        }
    }
}
