#!/usr/bin/env bats
# Tests for delete command

load test_helper

setup() {
    setup_test_env
    setup_mock_gpg
    init_senv_for_test

    export TEST_PROJECT=$(basename "$TEST_PROJECT_DIR")
}

teardown() {
    teardown_mock_gpg
    teardown_test_env
}

# =============================================================================
# Basic Delete
# =============================================================================

@test "delete removes encrypted environment file" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    run_senv_stdin "y" delete local
    [ "$status" -eq 0 ]
    assert_file_not_exists "$TEST_SECRETS_DIR/$TEST_PROJECT/local.env.enc"
}

@test "delete removes backup file too" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"
    # Create a backup file
    cp "$TEST_SECRETS_DIR/$TEST_PROJECT/local.env.enc" "$TEST_SECRETS_DIR/$TEST_PROJECT/local.env.enc.backup"

    run_senv_stdin "y" delete local
    [ "$status" -eq 0 ]
    assert_file_not_exists "$TEST_SECRETS_DIR/$TEST_PROJECT/local.env.enc.backup"
}

@test "delete shows success message" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    run_senv_stdin "y" delete local
    [ "$status" -eq 0 ]
    assert_output_contains "Deleted"
    assert_output_contains "local"
}

# =============================================================================
# Confirmation
# =============================================================================

@test "delete requires confirmation" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    # Answer 'n' to cancel
    run_senv_stdin "n" delete local
    [ "$status" -eq 0 ]
    assert_file_exists "$TEST_SECRETS_DIR/$TEST_PROJECT/local.env.enc"
}

@test "delete shows warning before confirmation" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    run_senv_stdin "n" delete local
    assert_output_contains "permanently delete"
    assert_output_contains "local"
}

@test "delete accepts 'y' as confirmation" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    run_senv_stdin "y" delete local
    [ "$status" -eq 0 ]
    assert_file_not_exists "$TEST_SECRETS_DIR/$TEST_PROJECT/local.env.enc"
}

@test "delete accepts 'Y' as confirmation" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    run_senv_stdin "Y" delete local
    [ "$status" -eq 0 ]
    assert_file_not_exists "$TEST_SECRETS_DIR/$TEST_PROJECT/local.env.enc"
}

@test "delete rejects other responses" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    run_senv_stdin "yes" delete local
    [ "$status" -eq 0 ]
    # 'yes' should be rejected (only 'y' or 'Y' accepted)
    assert_file_exists "$TEST_SECRETS_DIR/$TEST_PROJECT/local.env.enc"
}

# =============================================================================
# Error Cases
# =============================================================================

@test "delete fails without environment argument" {
    run_senv delete
    [ "$status" -eq 1 ]
    assert_output_contains "Usage:"
}

@test "delete fails for non-existent environment" {
    run_senv delete nonexistent
    [ "$status" -eq 1 ]
    assert_output_contains "not found"
}

# =============================================================================
# rm Alias
# =============================================================================

@test "rm is an alias for delete" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    run_senv_stdin "y" rm local
    [ "$status" -eq 0 ]
    assert_file_not_exists "$TEST_SECRETS_DIR/$TEST_PROJECT/local.env.enc"
}

# =============================================================================
# Project Override
# =============================================================================

@test "delete works with -p project override" {
    create_test_env "other-project" "dev" "VAR=value"

    run_senv_stdin "y" -p other-project delete dev
    [ "$status" -eq 0 ]
    assert_file_not_exists "$TEST_SECRETS_DIR/other-project/dev.env.enc"
}

# =============================================================================
# Directory Cleanup
# =============================================================================

@test "delete removes empty project directory" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"
    # Verify directory exists first
    assert_dir_exists "$TEST_SECRETS_DIR/$TEST_PROJECT"

    run_senv_stdin "y" delete local
    [ "$status" -eq 0 ]
    # Directory should be removed since it's now empty
    [ ! -d "$TEST_SECRETS_DIR/$TEST_PROJECT" ]
}

@test "delete keeps project directory if other environments exist" {
    create_test_env "$TEST_PROJECT" "local" "VAR=local"
    create_test_env "$TEST_PROJECT" "staging" "VAR=staging"

    run_senv_stdin "y" delete local
    [ "$status" -eq 0 ]
    # Directory should still exist because staging is there
    assert_dir_exists "$TEST_SECRETS_DIR/$TEST_PROJECT"
    assert_file_exists "$TEST_SECRETS_DIR/$TEST_PROJECT/staging.env.enc"
}

@test "delete shows info when removing empty directory" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    run_senv_stdin "y" delete local
    [ "$status" -eq 0 ]
    assert_output_contains "Removed empty project directory"
}
