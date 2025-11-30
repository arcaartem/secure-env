#!/usr/bin/env bats
# Tests for export command

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
# Basic Export
# =============================================================================

@test "export creates .env.<env> files for all environments" {
    create_test_env "$TEST_PROJECT" "local" "LOCAL=value"
    create_test_env "$TEST_PROJECT" "staging" "STAGING=value"
    create_test_env "$TEST_PROJECT" "production" "PROD=value"

    run_senv export
    [ "$status" -eq 0 ]
    assert_file_exists ".env.local"
    assert_file_exists ".env.staging"
    assert_file_exists ".env.production"
}

@test "export decrypts content correctly" {
    create_test_env "$TEST_PROJECT" "local" "DB_HOST=localhost
DB_PORT=5432"

    run_senv export
    [ "$status" -eq 0 ]
    assert_file_contains ".env.local" "DB_HOST=localhost"
    assert_file_contains ".env.local" "DB_PORT=5432"
}

@test "export does not include senv headers" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    run_senv export
    [ "$status" -eq 0 ]
    assert_file_not_contains ".env.local" "# senv:"
    assert_file_not_contains ".env.local" "# Decrypted from:"
    assert_file_not_contains ".env.local" "# Do not commit"
}

@test "export shows success message" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    run_senv export
    [ "$status" -eq 0 ]
    assert_output_contains "Exported"
    assert_output_contains "1 environment"
}

@test "export shows count for multiple environments" {
    create_test_env "$TEST_PROJECT" "local" "VAR=1"
    create_test_env "$TEST_PROJECT" "staging" "VAR=2"
    create_test_env "$TEST_PROJECT" "production" "VAR=3"

    run_senv export
    [ "$status" -eq 0 ]
    assert_output_contains "3 environment"
}

# =============================================================================
# Empty Project
# =============================================================================

@test "export warns and succeeds for empty project" {
    run_senv export
    [ "$status" -eq 0 ]
    assert_output_contains "warning"
    assert_output_contains "No environments"
}

@test "export warns when project directory doesn't exist" {
    run_senv -p nonexistent-project export
    [ "$status" -eq 0 ]
    assert_output_contains "warning"
}

# =============================================================================
# Output Directory
# =============================================================================

@test "export --output-dir writes to specified directory" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"
    local output_dir="$TEST_HOME/export-output"
    mkdir -p "$output_dir"

    run_senv export --output-dir "$output_dir"
    [ "$status" -eq 0 ]
    assert_file_exists "$output_dir/.env.local"
    assert_file_not_exists ".env.local"
}

@test "export fails if output directory doesn't exist" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    run_senv export --output-dir "/nonexistent/directory"
    [ "$status" -eq 1 ]
    assert_output_contains "does not exist"
}

# =============================================================================
# Conflict Handling
# =============================================================================

@test "export fails if target file already exists" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"
    echo "existing" > .env.local

    run_senv export
    [ "$status" -eq 1 ]
    assert_output_contains "already exist"
    assert_output_contains ".env.local"
}

@test "export fails and lists all conflicting files" {
    create_test_env "$TEST_PROJECT" "local" "VAR=1"
    create_test_env "$TEST_PROJECT" "staging" "VAR=2"
    echo "existing" > .env.local
    echo "existing" > .env.staging

    run_senv export
    [ "$status" -eq 1 ]
    assert_output_contains ".env.local"
    assert_output_contains ".env.staging"
}

@test "export suggests --force when conflicts exist" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"
    echo "existing" > .env.local

    run_senv export
    [ "$status" -eq 1 ]
    assert_output_contains "--force"
}

@test "export --force overwrites existing files" {
    create_test_env "$TEST_PROJECT" "local" "NEW=value"
    echo "OLD=content" > .env.local

    run_senv export --force
    [ "$status" -eq 0 ]
    assert_file_contains ".env.local" "NEW=value"
    assert_file_not_contains ".env.local" "OLD=content"
}

@test "export --force overwrites multiple existing files" {
    create_test_env "$TEST_PROJECT" "local" "LOCAL=new"
    create_test_env "$TEST_PROJECT" "staging" "STAGING=new"
    echo "OLD=local" > .env.local
    echo "OLD=staging" > .env.staging

    run_senv export --force
    [ "$status" -eq 0 ]
    assert_file_contains ".env.local" "LOCAL=new"
    assert_file_contains ".env.staging" "STAGING=new"
}

# =============================================================================
# Pre-check Behavior
# =============================================================================

@test "export checks all targets before exporting any" {
    create_test_env "$TEST_PROJECT" "local" "VAR=1"
    create_test_env "$TEST_PROJECT" "staging" "VAR=2"
    echo "existing" > .env.staging

    run_senv export
    [ "$status" -eq 1 ]
    # Should fail without creating .env.local
    assert_file_not_exists ".env.local"
}

# =============================================================================
# Project Override
# =============================================================================

@test "export works with -p project override" {
    create_test_env "other-project" "dev" "DEV=value"

    run_senv -p other-project export
    [ "$status" -eq 0 ]
    assert_file_exists ".env.dev"
    assert_file_contains ".env.dev" "DEV=value"
}

# =============================================================================
# Ignores .env without suffix
# =============================================================================

@test "export ignores existing .env file" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"
    echo "# senv: local" > .env
    echo "EXISTING=content" >> .env

    run_senv export
    [ "$status" -eq 0 ]
    # .env should be untouched, .env.local should be created
    assert_file_exists ".env.local"
    assert_file_contains ".env" "EXISTING=content"
}

# =============================================================================
# Unknown Options
# =============================================================================

@test "export fails on unknown option" {
    run_senv export --unknown
    [ "$status" -eq 1 ]
    assert_output_contains "Unknown option"
}
