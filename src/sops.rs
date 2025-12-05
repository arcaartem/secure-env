use anyhow::{Context, Result};
use std::io::Write;
use std::path::Path;
use std::process::{Command, Stdio};

/// Decrypt an encrypted file using SOPS
pub fn decrypt(sops_config: &Path, enc_path: &Path) -> Result<String> {
    let output = Command::new("sops")
        .args(["--config", sops_config.to_str().unwrap()])
        .args(["--input-type", "dotenv", "--output-type", "dotenv"])
        .args(["-d", enc_path.to_str().unwrap()])
        .output()
        .context("Failed to execute sops")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("Decryption failed: {}", stderr.trim());
    }

    String::from_utf8(output.stdout).context("Invalid UTF-8 in decrypted output")
}

/// Encrypt content using SOPS, writing to the specified path
/// Uses --filename-override so path_regex in .sops.yaml matches the output file
pub fn encrypt(sops_config: &Path, content: &str, output_path: &Path) -> Result<Vec<u8>> {
    let mut child = Command::new("sops")
        .args(["--config", sops_config.to_str().unwrap()])
        .args(["--filename-override", output_path.to_str().unwrap()])
        .args(["-e", "--input-type", "dotenv", "--output-type", "dotenv"])
        .arg("/dev/stdin")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .context("Failed to spawn sops")?;

    // Write content to stdin
    if let Some(mut stdin) = child.stdin.take() {
        stdin
            .write_all(content.as_bytes())
            .context("Failed to write to sops stdin")?;
    }

    let output = child.wait_with_output().context("Failed to wait for sops")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("Encryption failed: {}", stderr.trim());
    }

    Ok(output.stdout)
}

/// Open an encrypted file in the editor via SOPS
pub fn edit(sops_config: &Path, enc_path: &Path) -> Result<()> {
    let status = Command::new("sops")
        .args(["--config", sops_config.to_str().unwrap()])
        .args(["--input-type", "dotenv", "--output-type", "dotenv"])
        .arg(enc_path)
        .status()
        .context("Failed to execute sops")?;

    if !status.success() {
        anyhow::bail!("sops edit failed with exit code: {:?}", status.code());
    }

    Ok(())
}

/// Create a new encrypted file with initial content
pub fn create(sops_config: &Path, content: &str, output_path: &Path) -> Result<()> {
    let encrypted = encrypt(sops_config, content, output_path)?;
    std::fs::write(output_path, encrypted).context("Failed to write encrypted file")?;
    Ok(())
}

#[cfg(test)]
mod tests {
    // Integration tests would require actual sops binary and keys
    // These are placeholder tests
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn test_path_handling() {
        let config = PathBuf::from("/path/to/.sops.yaml");
        let enc = PathBuf::from("/path/to/local.env.enc");

        assert!(config.to_str().is_some());
        assert!(enc.to_str().is_some());
    }
}
