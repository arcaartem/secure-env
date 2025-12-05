use anyhow::{Context, Result};
use std::env;
use std::fs;
use std::path::Path;
use std::process::Command;

use crate::config::Config;
use crate::git;
use crate::utils;

/// Initialize senv (interactive backend selection)
pub fn run(config: &Config) -> Result<()> {
    let missing = utils::check_deps(&["sops", "git"]);
    if !missing.is_empty() {
        utils::print_install_instructions(&missing);
        anyhow::bail!("Missing dependencies");
    }

    let secrets_path = &config.secrets_path;
    let sops_config = config.sops_config_path();

    // Check for existing .sops.yaml
    if sops_config.exists() {
        utils::success(&format!("Using existing .sops.yaml at {}", secrets_path.display()));

        // Ensure directory and git repo exist
        fs::create_dir_all(secrets_path)?;

        if !git::is_repo(secrets_path) {
            git::init(secrets_path)?;
            utils::info("Initialized git repository");
        }

        ensure_gitignore(secrets_path)?;

        utils::success("Initialized senv");
        utils::info(&format!("Secrets: {}", secrets_path.display()));
        return Ok(());
    }

    // Create secrets directory
    fs::create_dir_all(secrets_path)?;

    // Prompt for backend
    let backend = utils::select(
        "Select encryption backend",
        &[
            ("age", "Modern, simple encryption (recommended)"),
            ("pgp", "GPG/PGP encryption"),
        ],
    )?;

    match backend.as_str() {
        "age" | "1" => setup_age_backend(secrets_path)?,
        "pgp" | "2" => setup_pgp_backend(secrets_path)?,
        _ => {
            utils::err("Invalid backend. Choose 'age' or 'pgp'");
            anyhow::bail!("Invalid backend");
        }
    }

    // Initialize git repo
    if !git::is_repo(secrets_path) {
        git::init(secrets_path)?;
    }

    // Create .gitignore
    ensure_gitignore(secrets_path)?;

    utils::success("Initialized senv");
    utils::info(&format!("Secrets: {}", secrets_path.display()));

    Ok(())
}

/// Set up age encryption backend
fn setup_age_backend(secrets_path: &Path) -> Result<()> {
    let missing = utils::check_deps(&["age"]);
    if !missing.is_empty() {
        utils::print_install_instructions(&missing);
        anyhow::bail!("Missing dependencies");
    }

    // Determine age key file location
    let age_key_file = env::var("SOPS_AGE_KEY_FILE").unwrap_or_else(|_| {
        let home = dirs::home_dir().unwrap();
        home.join(".config/sops/age/keys.txt")
            .to_string_lossy()
            .to_string()
    });

    let age_key_path = Path::new(&age_key_file);
    let mut age_recipient = String::new();

    // Check for existing key
    if age_key_path.exists() {
        let content = fs::read_to_string(age_key_path)?;
        for line in content.lines() {
            if line.starts_with("# public key:") {
                age_recipient = line.trim_start_matches("# public key:").trim().to_string();
                break;
            }
        }

        if !age_recipient.is_empty() {
            utils::info(&format!("Found existing age key: {}", age_recipient));
        }
    }

    // If no key found, offer to generate
    if age_recipient.is_empty() {
        eprintln!("No age key found at {}", age_key_file);

        if utils::confirm("Generate a new age key?")? {
            // Create parent directory
            if let Some(parent) = age_key_path.parent() {
                fs::create_dir_all(parent)?;
            }

            // Generate key using age-keygen
            let output = Command::new("age-keygen")
                .args(["-o", &age_key_file])
                .output()
                .context("Failed to run age-keygen")?;

            if !output.status.success() {
                let stderr = String::from_utf8_lossy(&output.stderr);
                anyhow::bail!("age-keygen failed: {}", stderr);
            }

            // Extract public key from generated file
            let content = fs::read_to_string(age_key_path)?;
            for line in content.lines() {
                if line.starts_with("# public key:") {
                    age_recipient = line.trim_start_matches("# public key:").trim().to_string();
                    break;
                }
            }

            utils::success(&format!("Generated age key: {}", age_recipient));
            utils::info(&format!("Private key saved to: {}", age_key_file));
        } else {
            utils::err(&format!(
                "Age key required. Generate one with: age-keygen -o {}",
                age_key_file
            ));
            anyhow::bail!("Age key required");
        }
    }

    // Create .sops.yaml
    let sops_config = format!(
        r#"creation_rules:
  - path_regex: .*\.env\.enc$
    age: {}
"#,
        age_recipient
    );

    fs::write(secrets_path.join(".sops.yaml"), sops_config)?;
    utils::success("Configured age backend");

    Ok(())
}

/// Set up PGP/GPG encryption backend
fn setup_pgp_backend(secrets_path: &Path) -> Result<()> {
    let missing = utils::check_deps(&["gpg"]);
    if !missing.is_empty() {
        utils::print_install_instructions(&missing);
        anyhow::bail!("Missing dependencies");
    }

    // List available GPG keys
    eprintln!("Available GPG keys:");
    eprintln!();

    let output = Command::new("gpg")
        .args(["--list-secret-keys", "--keyid-format", "LONG"])
        .output()
        .context("Failed to list GPG keys")?;

    let key_output = String::from_utf8_lossy(&output.stdout);

    if key_output.trim().is_empty() {
        utils::err("No GPG keys found. Create one with: gpg --full-generate-key");
        anyhow::bail!("No GPG keys found");
    }

    // Parse and display keys
    let mut current_key = String::new();
    for line in key_output.lines() {
        if line.starts_with("sec") {
            // Extract key ID from lines like "sec   rsa4096/ABCD1234EFGH5678 2024-01-01"
            if let Some(key_part) = line.split_whitespace().nth(1) {
                if let Some(key_id) = key_part.split('/').nth(1) {
                    current_key = key_id.to_string();
                    eprintln!("  {} ({})", key_id, key_part.split('/').next().unwrap_or(""));
                }
            }
        } else if line.contains("uid") && !current_key.is_empty() {
            let uid = line.trim_start_matches("uid").trim();
            // Remove trust level like [ultimate]
            let uid_clean = uid
                .trim_start_matches(|c: char| c == '[' || c.is_alphabetic() || c == ']' || c == ' ')
                .trim();
            eprintln!("    {}", uid_clean);
        }
    }
    eprintln!();

    let gpg_key = utils::prompt("Enter GPG key ID (long format, e.g., ABCD1234EFGH5678): ")?;

    if gpg_key.is_empty() {
        utils::err("GPG key ID required");
        anyhow::bail!("GPG key ID required");
    }

    // Validate GPG key exists
    let check = Command::new("gpg")
        .args(["--list-secret-keys", &gpg_key])
        .output()?;

    if !check.status.success() {
        utils::err(&format!("GPG key '{}' not found", gpg_key));
        anyhow::bail!("GPG key not found");
    }

    // Create .sops.yaml
    let sops_config = format!(
        r#"creation_rules:
  - path_regex: .*\.env\.enc$
    pgp: {}
"#,
        gpg_key
    );

    fs::write(secrets_path.join(".sops.yaml"), sops_config)?;
    utils::success("Configured PGP backend");
    utils::info(&format!("GPG Key: {}", gpg_key));

    Ok(())
}

/// Ensure .gitignore exists with proper patterns
fn ensure_gitignore(secrets_path: &Path) -> Result<()> {
    let gitignore_path = secrets_path.join(".gitignore");

    if !gitignore_path.exists() {
        let content = r#"# Never commit decrypted files
*.env
!*.env.enc
"#;
        fs::write(&gitignore_path, content)?;
        utils::info("Created .gitignore");
    }

    Ok(())
}
