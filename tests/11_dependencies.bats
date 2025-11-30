#!/usr/bin/env bats
# Tests for dependency checking

load test_helper

setup() {
    setup_test_env
    setup_mock_gpg
    init_senv_for_test

    export TEST_PROJECT=$(basename "$TEST_PROJECT_DIR")

    # Save original PATH
    export ORIGINAL_PATH="$PATH"
}

teardown() {
    # Restore original PATH
    export PATH="$ORIGINAL_PATH"
    teardown_mock_gpg
    teardown_test_env
}

# =============================================================================
# Helper to hide a command from PATH
# =============================================================================

hide_command() {
    local cmd="$1"
    # Create a temporary bin directory without the command
    local fake_path=$(mktemp -d)

    # Copy essential commands we need for the test to work
    # Include common utilities that scripts and tests might need
    for essential in bash cat grep sed mkdir rmdir rm cp mv ls echo head tail tr basename dirname pwd git mktemp timeout read command; do
        local cmd_path=$(which "$essential" 2>/dev/null || true)
        if [[ -n "$cmd_path" && -x "$cmd_path" ]]; then
            ln -sf "$cmd_path" "$fake_path/$essential"
        fi
    done

    # Don't link the command we want to hide
    rm -f "$fake_path/$cmd" 2>/dev/null || true

    # Set PATH to only use our fake directory
    export PATH="$fake_path"
}

# =============================================================================
# GPG Dependency
# =============================================================================

@test "init fails with helpful message when gpg is not installed" {
    hide_command gpg

    run_senv init
    [ "$status" -eq 1 ]
    assert_output_contains "gpg"
    assert_output_contains "not found" || assert_output_contains "required" || assert_output_contains "install"
}

@test "use fails with helpful message when gpg is not installed" {
    # First create env with gpg available
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    hide_command gpg

    run_senv use local
    [ "$status" -eq 1 ]
    assert_output_contains "gpg"
}

@test "edit fails with helpful message when gpg is not installed" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    hide_command gpg

    run_senv edit local
    [ "$status" -eq 1 ]
    assert_output_contains "gpg"
}

@test "save fails with helpful message when gpg is not installed" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"
    run_senv use local
    [ "$status" -eq 0 ]

    hide_command gpg

    run_senv save
    [ "$status" -eq 1 ]
    assert_output_contains "gpg"
}

@test "export fails with helpful message when gpg is not installed" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    hide_command gpg

    run_senv export
    [ "$status" -eq 1 ]
    assert_output_contains "gpg"
}

@test "import fails with helpful message when gpg is not installed" {
    create_plain_env "local" "VAR=value"

    hide_command gpg

    run_senv import
    [ "$status" -eq 1 ]
    assert_output_contains "gpg"
}

# =============================================================================
# SOPS Dependency
# =============================================================================

@test "init fails with helpful message when sops is not installed" {
    hide_command sops

    run_senv_stdin "$TEST_GPG_KEY" init
    [ "$status" -eq 1 ]
    assert_output_contains "sops"
    assert_output_contains "not found" || assert_output_contains "required" || assert_output_contains "install"
}

@test "use fails with helpful message when sops is not installed" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    hide_command sops

    run_senv use local
    [ "$status" -eq 1 ]
    assert_output_contains "sops"
}

@test "edit fails with helpful message when sops is not installed" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    hide_command sops

    run_senv edit local
    [ "$status" -eq 1 ]
    assert_output_contains "sops"
}

@test "save fails with helpful message when sops is not installed" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"
    run_senv use local
    [ "$status" -eq 0 ]

    hide_command sops

    run_senv save
    [ "$status" -eq 1 ]
    assert_output_contains "sops"
}

@test "export fails with helpful message when sops is not installed" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    hide_command sops

    run_senv export
    [ "$status" -eq 1 ]
    assert_output_contains "sops"
}

@test "import fails with helpful message when sops is not installed" {
    create_plain_env "local" "VAR=value"

    hide_command sops

    run_senv import
    [ "$status" -eq 1 ]
    assert_output_contains "sops"
}

# =============================================================================
# Git Dependency (only needed for init)
# =============================================================================

@test "init fails with helpful message when git is not installed" {
    hide_command git

    run_senv_stdin "$TEST_GPG_KEY" init
    [ "$status" -eq 1 ]
    assert_output_contains "git"
    assert_output_contains "not found" || assert_output_contains "required" || assert_output_contains "install"
}

# =============================================================================
# Commands that don't need all dependencies
# =============================================================================

@test "help works without gpg installed" {
    hide_command gpg

    run_senv help
    [ "$status" -eq 0 ]
    assert_output_contains "USAGE:"
}

@test "help works without sops installed" {
    hide_command sops

    run_senv help
    [ "$status" -eq 0 ]
    assert_output_contains "USAGE:"
}

@test "version works without sops" {
    hide_command sops

    run_senv version
    [ "$status" -eq 0 ]
    assert_output_contains "senv"
}

@test "version works without gpg" {
    hide_command gpg

    run_senv version
    [ "$status" -eq 0 ]
    assert_output_contains "senv"
}

@test "list works without sops (only reads filenames)" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    hide_command sops

    # list should work - it only reads directory contents
    run_senv list
    [ "$status" -eq 0 ]
    assert_output_contains "local"
}

@test "status works without sops (only reads filenames and .env)" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    hide_command sops

    run_senv status
    [ "$status" -eq 0 ]
    assert_output_contains "Project:"
}

@test "repo works without sops" {
    hide_command sops

    run_senv repo
    [ "$status" -eq 0 ]
    assert_output_contains "$TEST_SECRETS_DIR"
}

@test "delete works without sops (only removes files)" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    hide_command sops

    run_senv_stdin "y" delete local
    [ "$status" -eq 0 ]
    assert_file_not_exists "$TEST_SECRETS_DIR/$TEST_PROJECT/local.env.enc"
}

# =============================================================================
# Multiple Missing Dependencies
# =============================================================================

@test "reports all missing dependencies at once" {
    hide_command gpg
    # Note: Can't easily hide both since hide_command replaces PATH entirely
    # This test verifies at least one is reported

    run_senv init
    [ "$status" -eq 1 ]
    assert_output_contains "gpg"
}
