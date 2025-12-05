// Integration tests for senv CLI behavior
// These tests mirror the BATS tests in tests/*.bats

use assert_cmd::Command;
use predicates::prelude::*;

fn senv() -> Command {
    Command::cargo_bin("senv").unwrap()
}

// =============================================================================
// Help and Version (01_cli.bats equivalents)
// =============================================================================

#[test]
fn help_flag_shows_usage() {
    senv()
        .arg("--help")
        .assert()
        .success()
        .stdout(predicate::str::contains("Usage:"))
        .stdout(predicate::str::contains("Commands:"));
}

#[test]
fn version_flag_shows_version() {
    senv()
        .arg("--version")
        .assert()
        .success()
        .stdout(predicate::str::contains("senv"));
}

#[test]
fn no_args_shows_help() {
    senv()
        .assert()
        .failure()
        .stderr(predicate::str::contains("Usage:"));
}

#[test]
fn unknown_command_fails() {
    senv()
        .arg("notacommand")
        .assert()
        .failure()
        .stderr(predicate::str::contains("unrecognized subcommand"));
}

#[test]
fn unknown_option_fails() {
    senv()
        .arg("--notanoption")
        .assert()
        .failure()
        .stderr(predicate::str::contains("unexpected argument"));
}

// =============================================================================
// Command Help (01_cli.bats equivalents)
// =============================================================================

#[test]
fn use_help_shows_usage() {
    senv()
        .args(["use", "--help"])
        .assert()
        .success()
        .stdout(predicate::str::contains("Usage:"));
}

#[test]
fn edit_help_shows_usage() {
    senv()
        .args(["edit", "--help"])
        .assert()
        .success()
        .stdout(predicate::str::contains("Usage:"));
}

#[test]
fn save_help_shows_usage() {
    senv()
        .args(["save", "--help"])
        .assert()
        .success()
        .stdout(predicate::str::contains("Usage:"));
}

#[test]
fn list_help_shows_usage() {
    senv()
        .args(["list", "--help"])
        .assert()
        .success()
        .stdout(predicate::str::contains("Usage:"));
}

#[test]
fn delete_help_shows_usage() {
    senv()
        .args(["delete", "--help"])
        .assert()
        .success()
        .stdout(predicate::str::contains("Usage:"));
}

#[test]
fn import_help_shows_usage() {
    senv()
        .args(["import", "--help"])
        .assert()
        .success()
        .stdout(predicate::str::contains("Usage:"));
}

#[test]
fn export_help_shows_usage() {
    senv()
        .args(["export", "--help"])
        .assert()
        .success()
        .stdout(predicate::str::contains("Usage:"));
}

#[test]
fn init_help_shows_usage() {
    senv()
        .args(["init", "--help"])
        .assert()
        .success()
        .stdout(predicate::str::contains("Usage:"));
}

#[test]
fn status_help_shows_usage() {
    senv()
        .args(["status", "--help"])
        .assert()
        .success()
        .stdout(predicate::str::contains("Usage:"));
}

#[test]
fn diff_help_shows_usage() {
    senv()
        .args(["diff", "--help"])
        .assert()
        .success()
        .stdout(predicate::str::contains("Usage:"));
}

#[test]
fn repo_help_shows_usage() {
    senv()
        .args(["repo", "--help"])
        .assert()
        .success()
        .stdout(predicate::str::contains("Usage:"));
}

// =============================================================================
// Aliases (01_cli.bats equivalents)
// =============================================================================

#[test]
fn ls_is_alias_for_list() {
    // Both should show help with same format
    let list_output = senv()
        .args(["list", "--help"])
        .output()
        .expect("Failed to run list --help");

    let ls_output = senv()
        .args(["ls", "--help"])
        .output()
        .expect("Failed to run ls --help");

    assert!(list_output.status.success());
    assert!(ls_output.status.success());
}

#[test]
fn rm_is_alias_for_delete() {
    // Both should show help with same format
    let delete_output = senv()
        .args(["delete", "--help"])
        .output()
        .expect("Failed to run delete --help");

    let rm_output = senv()
        .args(["rm", "--help"])
        .output()
        .expect("Failed to run rm --help");

    assert!(delete_output.status.success());
    assert!(rm_output.status.success());
}

// =============================================================================
// Required Arguments (04_use_edit_save.bats equivalents)
// =============================================================================

#[test]
fn use_requires_environment_argument() {
    senv()
        .arg("use")
        .assert()
        .failure()
        .stderr(predicate::str::contains("Usage:").or(predicate::str::contains("required")));
}

#[test]
fn edit_requires_environment_argument() {
    senv()
        .arg("edit")
        .assert()
        .failure()
        .stderr(predicate::str::contains("Usage:").or(predicate::str::contains("required")));
}

#[test]
fn delete_requires_environment_argument() {
    senv()
        .arg("delete")
        .assert()
        .failure()
        .stderr(predicate::str::contains("Usage:").or(predicate::str::contains("required")));
}

// =============================================================================
// Unknown Options (various .bats equivalents)
// =============================================================================

#[test]
fn use_fails_on_unknown_option() {
    senv()
        .args(["use", "--unknown"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("unexpected"));
}

#[test]
fn edit_fails_on_unknown_option() {
    senv()
        .args(["edit", "--unknown"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("unexpected"));
}

#[test]
fn save_fails_on_unknown_option() {
    senv()
        .args(["save", "--unknown"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("unexpected"));
}

#[test]
fn list_fails_on_unknown_option() {
    senv()
        .args(["list", "--unknown"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("unexpected"));
}

#[test]
fn delete_fails_on_unknown_option() {
    senv()
        .args(["delete", "--unknown"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("unexpected"));
}

#[test]
fn import_fails_on_unknown_option() {
    senv()
        .args(["import", "--unknown"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("unexpected"));
}

#[test]
fn export_fails_on_unknown_option() {
    senv()
        .args(["export", "--unknown"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("unexpected"));
}

#[test]
fn init_fails_on_unknown_option() {
    senv()
        .args(["init", "--unknown"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("unexpected"));
}

#[test]
fn status_fails_on_unknown_option() {
    senv()
        .args(["status", "--unknown"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("unexpected"));
}

#[test]
fn diff_fails_on_unknown_option() {
    senv()
        .args(["diff", "--unknown"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("unexpected"));
}

#[test]
fn repo_fails_on_unknown_option() {
    senv()
        .args(["repo", "--unknown"])
        .assert()
        .failure()
        .stderr(predicate::str::contains("unexpected"));
}
