#!/usr/bin/env bats
# Tests for CLI argument parsing and help

load test_helper

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

# =============================================================================
# Help and Version
# =============================================================================

@test "help command shows usage" {
    run_senv help
    [ "$status" -eq 0 ]
    assert_output_contains "senv"
    assert_output_contains "USAGE:"
    assert_output_contains "COMMANDS:"
}

@test "--help flag shows usage" {
    run_senv --help
    [ "$status" -eq 0 ]
    assert_output_contains "USAGE:"
}

@test "-h flag shows usage" {
    run_senv -h
    [ "$status" -eq 0 ]
    assert_output_contains "USAGE:"
}

@test "version command shows version" {
    run_senv version
    [ "$status" -eq 0 ]
    assert_output_contains "senv"
    [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "--version flag shows version" {
    run_senv --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "-v flag shows version" {
    run_senv -v
    [ "$status" -eq 0 ]
    [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "no arguments shows help" {
    run_senv
    [ "$status" -eq 0 ]
    assert_output_contains "USAGE:"
}

@test "unknown command shows error" {
    run_senv unknown_command
    [ "$status" -eq 1 ]
    assert_output_contains "Unknown command"
}

@test "unknown option shows error" {
    run_senv --unknown-option
    [ "$status" -eq 1 ]
    assert_output_contains "Unknown option"
}

# =============================================================================
# Help shows new features
# =============================================================================

@test "help shows export command" {
    run_senv help
    [ "$status" -eq 0 ]
    assert_output_contains "export"
    assert_output_contains "Export all environments"
}

@test "help shows import command" {
    run_senv help
    [ "$status" -eq 0 ]
    assert_output_contains "import"
    assert_output_contains "Import all"
}

@test "help shows -s/--secrets-path option" {
    run_senv help
    [ "$status" -eq 0 ]
    assert_output_contains "-s, --secrets-path"
}

@test "help shows environment variables section" {
    run_senv help
    [ "$status" -eq 0 ]
    assert_output_contains "ENVIRONMENT VARIABLES:"
    assert_output_contains "SENV_PROJECT"
    assert_output_contains "SENV_SECRETS_PATH"
}

@test "help shows export options" {
    run_senv help
    [ "$status" -eq 0 ]
    assert_output_contains "EXPORT OPTIONS:"
    assert_output_contains "--output-dir"
    assert_output_contains "--force"
}

@test "help shows import options" {
    run_senv help
    [ "$status" -eq 0 ]
    assert_output_contains "IMPORT OPTIONS:"
    assert_output_contains "--keep"
}
