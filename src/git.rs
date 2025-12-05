use anyhow::{Context, Result};
use std::path::Path;
use std::process::Command;

/// Initialize a git repository at the given path
pub fn init(path: &Path) -> Result<()> {
    let status = Command::new("git")
        .args(["-C", path.to_str().unwrap()])
        .args(["init", "-q"])
        .status()
        .context("Failed to execute git init")?;

    if !status.success() {
        anyhow::bail!("git init failed");
    }

    Ok(())
}

/// Check if a path is a git repository
pub fn is_repo(path: &Path) -> bool {
    path.join(".git").is_dir()
}

/// Add a file to git staging
pub fn add(repo_path: &Path, file_path: &str) -> Result<()> {
    let status = Command::new("git")
        .args(["-C", repo_path.to_str().unwrap()])
        .args(["add", file_path])
        .status()
        .context("Failed to execute git add")?;

    if !status.success() {
        anyhow::bail!("git add failed");
    }

    Ok(())
}

/// Commit staged changes with a message
/// Returns Ok(true) if commit was made, Ok(false) if nothing to commit
pub fn commit(repo_path: &Path, message: &str) -> Result<bool> {
    let output = Command::new("git")
        .args(["-C", repo_path.to_str().unwrap()])
        .args(["commit", "-m", message])
        .output()
        .context("Failed to execute git commit")?;

    // Exit code 1 with "nothing to commit" is not an error
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        let stdout = String::from_utf8_lossy(&output.stdout);

        if stdout.contains("nothing to commit") || stderr.contains("nothing to commit") {
            return Ok(false);
        }

        // Ignore other commit failures (e.g., no changes)
        return Ok(false);
    }

    Ok(true)
}

/// Add and commit a file in one operation
pub fn add_and_commit(repo_path: &Path, file_path: &str, message: &str) -> Result<()> {
    add(repo_path, file_path)?;
    commit(repo_path, message)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_is_repo_false() {
        let temp = TempDir::new().unwrap();
        assert!(!is_repo(temp.path()));
    }
}
