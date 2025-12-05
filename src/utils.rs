use colored::Colorize;
use std::io::{self, BufRead, Write};

/// Print an error message to stderr
pub fn err(msg: &str) {
    eprintln!("{} {}", "error:".red(), msg);
}

/// Print a warning message to stderr
pub fn warn(msg: &str) {
    eprintln!("{} {}", "warning:".yellow(), msg);
}

/// Print an info message to stderr
pub fn info(msg: &str) {
    eprintln!("{} {}", "info:".blue(), msg);
}

/// Print a success message to stderr
pub fn success(msg: &str) {
    eprintln!("{} {}", "success:".green(), msg);
}

/// Prompt the user for input with a message
pub fn prompt(msg: &str) -> io::Result<String> {
    eprint!("{}", msg);
    io::stderr().flush()?;

    let mut input = String::new();
    io::stdin().lock().read_line(&mut input)?;
    Ok(input.trim().to_string())
}

/// Prompt the user for confirmation (y/n)
pub fn confirm(msg: &str) -> io::Result<bool> {
    let response = prompt(&format!("{} [y/N] ", msg))?;
    Ok(matches!(response.to_lowercase().as_str(), "y" | "yes"))
}

/// Prompt the user to select from options
pub fn select(msg: &str, options: &[(&str, &str)]) -> io::Result<String> {
    eprintln!("{}:", msg);
    for (i, (key, desc)) in options.iter().enumerate() {
        eprintln!("  {}) {} - {}", i + 1, key, desc);
    }
    eprintln!();

    let response = prompt(&format!("Select [{}/{}]: ", options[0].0, options.get(1).map(|o| o.0).unwrap_or("")))?;

    // Check if response matches a key or number
    for (i, (key, _)) in options.iter().enumerate() {
        if response == *key || response == (i + 1).to_string() {
            return Ok(key.to_string());
        }
    }

    // Return first option if empty
    if response.is_empty() {
        return Ok(options[0].0.to_string());
    }

    Ok(response)
}

/// Check if a command exists in PATH
pub fn command_exists(cmd: &str) -> bool {
    which::which(cmd).is_ok()
}

/// Check for required dependencies, returning missing ones
pub fn check_deps(deps: &[&str]) -> Vec<String> {
    deps.iter()
        .filter(|cmd| !command_exists(cmd))
        .map(|s| s.to_string())
        .collect()
}

/// Print install instructions for missing dependencies
pub fn print_install_instructions(missing: &[String]) {
    err(&format!("Required dependencies not found: {}", missing.join(", ")));
    eprintln!();
    eprintln!("Install instructions:");
    for cmd in missing {
        match cmd.as_str() {
            "gpg" => eprintln!("  gpg:  brew install gnupg (macOS) or apt install gnupg (Ubuntu)"),
            "sops" => eprintln!("  sops: brew install sops (macOS) or see https://github.com/getsops/sops"),
            "git" => eprintln!("  git:  brew install git (macOS) or apt install git (Ubuntu)"),
            "age" => eprintln!("  age:  brew install age (macOS) or see https://github.com/FiloSottile/age"),
            _ => eprintln!("  {}: please install {}", cmd, cmd),
        }
    }
}

/// Read the first line of a file that matches a pattern
pub fn read_header_value(content: &str, prefix: &str) -> Option<String> {
    content
        .lines()
        .find(|line| line.starts_with(prefix))
        .map(|line| line.trim_start_matches(prefix).trim().to_string())
}

/// Strip senv header comments from .env content
pub fn strip_senv_headers(content: &str) -> String {
    let lines: Vec<&str> = content
        .lines()
        .filter(|line| {
            !line.starts_with("# senv:")
                && !line.starts_with("# Decrypted from:")
                && !line.starts_with("# Do not commit")
        })
        .collect();

    // Skip leading empty lines
    let start = lines.iter().position(|line| !line.is_empty()).unwrap_or(0);
    lines[start..].join("\n")
}

#[cfg(test)]
mod tests {
    use super::*;

    // =============================================================================
    // read_header_value tests
    // =============================================================================

    #[test]
    fn test_read_header_value() {
        let content = "# senv: local\n# Other comment\nKEY=value";
        assert_eq!(read_header_value(content, "# senv:"), Some("local".to_string()));
    }

    #[test]
    fn test_read_header_value_with_spaces() {
        let content = "# senv:   production  \nKEY=value";
        assert_eq!(read_header_value(content, "# senv:"), Some("production".to_string()));
    }

    #[test]
    fn test_read_header_value_not_found() {
        let content = "# Other comment\nKEY=value";
        assert_eq!(read_header_value(content, "# senv:"), None);
    }

    #[test]
    fn test_read_header_value_empty_content() {
        let content = "";
        assert_eq!(read_header_value(content, "# senv:"), None);
    }

    #[test]
    fn test_read_header_value_middle_of_file() {
        let content = "KEY=value\n# senv: staging\nOTHER=key";
        assert_eq!(read_header_value(content, "# senv:"), Some("staging".to_string()));
    }

    // =============================================================================
    // strip_senv_headers tests
    // =============================================================================

    #[test]
    fn test_strip_senv_headers() {
        let content = "# senv: local\n# Decrypted from: /path\n# Do not commit\n\nKEY=value";
        let stripped = strip_senv_headers(content);
        assert!(!stripped.contains("senv:"));
        assert!(stripped.contains("KEY=value"));
    }

    #[test]
    fn test_strip_senv_headers_no_headers() {
        let content = "KEY=value\nOTHER=data";
        let stripped = strip_senv_headers(content);
        assert_eq!(stripped, "KEY=value\nOTHER=data");
    }

    #[test]
    fn test_strip_senv_headers_preserves_other_comments() {
        let content = "# senv: local\n# My custom comment\nKEY=value";
        let stripped = strip_senv_headers(content);
        assert!(!stripped.contains("senv:"));
        assert!(stripped.contains("# My custom comment"));
        assert!(stripped.contains("KEY=value"));
    }

    #[test]
    fn test_strip_senv_headers_skips_leading_empty_lines() {
        let content = "# senv: local\n# Decrypted from: /path\n\n\nKEY=value";
        let stripped = strip_senv_headers(content);
        assert!(!stripped.starts_with("\n"));
        assert!(stripped.starts_with("KEY=value"));
    }

    #[test]
    fn test_strip_senv_headers_empty_content() {
        let content = "";
        let stripped = strip_senv_headers(content);
        assert_eq!(stripped, "");
    }

    #[test]
    fn test_strip_senv_headers_only_headers() {
        let content = "# senv: local\n# Decrypted from: /path\n# Do not commit";
        let stripped = strip_senv_headers(content);
        assert_eq!(stripped, "");
    }

    // =============================================================================
    // command_exists tests
    // =============================================================================

    #[test]
    fn test_command_exists_common_command() {
        // ls should exist on all Unix systems
        assert!(command_exists("ls"));
    }

    #[test]
    fn test_command_exists_nonexistent() {
        assert!(!command_exists("this_command_definitely_does_not_exist_abc123"));
    }

    // =============================================================================
    // check_deps tests
    // =============================================================================

    #[test]
    fn test_check_deps_all_present() {
        let missing = check_deps(&["ls", "cat"]);
        assert!(missing.is_empty());
    }

    #[test]
    fn test_check_deps_some_missing() {
        let missing = check_deps(&["ls", "this_command_definitely_does_not_exist_abc123"]);
        assert_eq!(missing.len(), 1);
        assert!(missing.contains(&"this_command_definitely_does_not_exist_abc123".to_string()));
    }

    #[test]
    fn test_check_deps_all_missing() {
        let missing = check_deps(&["nonexistent1_xyz", "nonexistent2_xyz"]);
        assert_eq!(missing.len(), 2);
    }

    #[test]
    fn test_check_deps_empty_list() {
        let missing = check_deps(&[]);
        assert!(missing.is_empty());
    }
}
