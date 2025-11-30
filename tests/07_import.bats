#!/usr/bin/env bats
# Tests for import command

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
# Basic Import
# =============================================================================

@test "import encrypts .env.<env> files to secrets repo" {
    create_plain_env "local" "LOCAL=value"
    create_plain_env "staging" "STAGING=value"

    run_senv import
    [ "$status" -eq 0 ]
    assert_file_exists "$TEST_SECRETS_DIR/$TEST_PROJECT/local.env.enc"
    assert_file_exists "$TEST_SECRETS_DIR/$TEST_PROJECT/staging.env.enc"
}

@test "import encrypts content correctly" {
    create_plain_env "local" "DB_HOST=localhost
DB_PORT=5432"

    run_senv import --keep
    [ "$status" -eq 0 ]

    # Decrypt and verify
    run_senv use local
    [ "$status" -eq 0 ]
    assert_file_contains ".env" "DB_HOST=localhost"
    assert_file_contains ".env" "DB_PORT=5432"
}

@test "import shows success message" {
    create_plain_env "local" "VAR=value"

    run_senv import
    [ "$status" -eq 0 ]
    assert_output_contains "Imported"
    assert_output_contains "1 environment"
}

@test "import shows count for multiple files" {
    create_plain_env "local" "VAR=1"
    create_plain_env "staging" "VAR=2"
    create_plain_env "production" "VAR=3"

    run_senv import
    [ "$status" -eq 0 ]
    assert_output_contains "3 environment"
}

# =============================================================================
# File Discovery
# =============================================================================

@test "import discovers .env.local files" {
    create_plain_env "local" "VAR=value"

    run_senv import
    [ "$status" -eq 0 ]
    assert_output_contains "local"
}

@test "import discovers .env.staging files" {
    create_plain_env "staging" "VAR=value"

    run_senv import
    [ "$status" -eq 0 ]
    assert_output_contains "staging"
}

@test "import discovers .env.production files" {
    create_plain_env "production" "VAR=value"

    run_senv import
    [ "$status" -eq 0 ]
    assert_output_contains "production"
}

@test "import ignores plain .env file" {
    echo "PLAIN=value" > .env
    create_plain_env "local" "LOCAL=value"

    run_senv import --keep
    [ "$status" -eq 0 ]
    # .env should still exist and be unchanged
    assert_file_exists ".env"
    assert_file_contains ".env" "PLAIN=value"
}

@test "import ignores .env.enc files" {
    echo "ENCRYPTED=stuff" > .env.enc
    create_plain_env "local" "LOCAL=value"

    run_senv import --keep
    [ "$status" -eq 0 ]
    # Should only import local, not enc
    assert_file_exists ".env.enc"
}

@test "import ignores .env.backup files" {
    echo "BACKUP=stuff" > .env.backup
    create_plain_env "local" "LOCAL=value"

    run_senv import --keep
    [ "$status" -eq 0 ]
    assert_file_exists ".env.backup"
}

@test "import ignores multi-suffix files like .env.local.old" {
    echo "OLD=stuff" > .env.local.old
    create_plain_env "local" "LOCAL=value"

    run_senv import --keep
    [ "$status" -eq 0 ]
    assert_file_exists ".env.local.old"
}

@test "import ignores .env.local.backup" {
    echo "BACKUP=stuff" > .env.local.backup
    create_plain_env "local" "LOCAL=value"

    run_senv import --keep
    [ "$status" -eq 0 ]
    assert_file_exists ".env.local.backup"
}

# =============================================================================
# Empty Discovery
# =============================================================================

@test "import warns and succeeds when no files found" {
    run_senv import
    [ "$status" -eq 0 ]
    assert_output_contains "warning"
    assert_output_contains "No .env"
}

@test "import warns when only .env exists (no suffix)" {
    echo "VAR=value" > .env

    run_senv import
    [ "$status" -eq 0 ]
    assert_output_contains "warning"
}

# =============================================================================
# Source File Cleanup
# =============================================================================

@test "import deletes source files by default" {
    create_plain_env "local" "VAR=value"

    run_senv import
    [ "$status" -eq 0 ]
    assert_file_not_exists ".env.local"
    assert_output_contains "deleted"
}

@test "import --keep preserves source files" {
    create_plain_env "local" "VAR=value"

    run_senv import --keep
    [ "$status" -eq 0 ]
    assert_file_exists ".env.local"
    assert_output_contains "preserved"
}

@test "import deletes all source files" {
    create_plain_env "local" "VAR=1"
    create_plain_env "staging" "VAR=2"

    run_senv import
    [ "$status" -eq 0 ]
    assert_file_not_exists ".env.local"
    assert_file_not_exists ".env.staging"
}

@test "import --keep preserves all source files" {
    create_plain_env "local" "VAR=1"
    create_plain_env "staging" "VAR=2"

    run_senv import --keep
    [ "$status" -eq 0 ]
    assert_file_exists ".env.local"
    assert_file_exists ".env.staging"
}

# =============================================================================
# Conflict Handling
# =============================================================================

@test "import fails if environment already exists in repo" {
    create_test_env "$TEST_PROJECT" "local" "EXISTING=value"
    create_plain_env "local" "NEW=value"

    run_senv import
    [ "$status" -eq 1 ]
    assert_output_contains "already exist"
}

@test "import lists all conflicting environments" {
    create_test_env "$TEST_PROJECT" "local" "EXISTING=1"
    create_test_env "$TEST_PROJECT" "staging" "EXISTING=2"
    create_plain_env "local" "NEW=1"
    create_plain_env "staging" "NEW=2"

    run_senv import
    [ "$status" -eq 1 ]
    assert_output_contains "local"
    assert_output_contains "staging"
}

@test "import suggests --force when conflicts exist" {
    create_test_env "$TEST_PROJECT" "local" "EXISTING=value"
    create_plain_env "local" "NEW=value"

    run_senv import
    [ "$status" -eq 1 ]
    assert_output_contains "--force"
}

@test "import --force overwrites existing environments" {
    create_test_env "$TEST_PROJECT" "local" "OLD=value"
    create_plain_env "local" "NEW=value"

    run_senv import --force
    [ "$status" -eq 0 ]

    # Verify by using the environment
    run_senv use local
    [ "$status" -eq 0 ]
    assert_file_contains ".env" "NEW=value"
    assert_file_not_contains ".env" "OLD=value"
}

@test "import --force overwrites multiple environments" {
    create_test_env "$TEST_PROJECT" "local" "OLD=1"
    create_test_env "$TEST_PROJECT" "staging" "OLD=2"
    create_plain_env "local" "NEW=1"
    create_plain_env "staging" "NEW=2"

    run_senv import --force
    [ "$status" -eq 0 ]

    run_senv use local
    assert_file_contains ".env" "NEW=1"
}

# =============================================================================
# Pre-check Behavior
# =============================================================================

@test "import checks all conflicts before importing any" {
    create_test_env "$TEST_PROJECT" "staging" "EXISTING=value"
    create_plain_env "local" "NEW=1"
    create_plain_env "staging" "NEW=2"

    run_senv import
    [ "$status" -eq 1 ]
    # local.env.enc should not be created
    assert_file_not_exists "$TEST_SECRETS_DIR/$TEST_PROJECT/local.env.enc"
    # Source files should not be deleted
    assert_file_exists ".env.local"
    assert_file_exists ".env.staging"
}

# =============================================================================
# Project Override
# =============================================================================

@test "import works with -p project override" {
    create_plain_env "dev" "DEV=value"

    run_senv -p custom-import-project import
    [ "$status" -eq 0 ]
    assert_file_exists "$TEST_SECRETS_DIR/custom-import-project/dev.env.enc"
}

@test "import creates project directory if needed" {
    create_plain_env "local" "VAR=value"

    run_senv -p brand-new-project import
    [ "$status" -eq 0 ]
    assert_dir_exists "$TEST_SECRETS_DIR/brand-new-project"
}

# =============================================================================
# Combined Flags
# =============================================================================

@test "import --force --keep works together" {
    create_test_env "$TEST_PROJECT" "local" "OLD=value"
    create_plain_env "local" "NEW=value"

    run_senv import --force --keep
    [ "$status" -eq 0 ]
    assert_file_exists ".env.local"

    run_senv use local
    assert_file_contains ".env" "NEW=value"
}

# =============================================================================
# Shows Commit Reminder
# =============================================================================

@test "import shows reminder to commit" {
    create_plain_env "local" "VAR=value"

    run_senv import
    [ "$status" -eq 0 ]
    assert_output_contains "commit"
}

# =============================================================================
# Unknown Options
# =============================================================================

@test "import fails on unknown option" {
    run_senv import --unknown
    [ "$status" -eq 1 ]
    assert_output_contains "Unknown option"
}
