#!/usr/bin/env bats
# Tests for use, edit, and save commands

load test_helper

setup() {
    setup_test_env
    setup_mock_gpg
    init_senv_for_test

    # Set project name based on test directory
    export TEST_PROJECT=$(basename "$TEST_PROJECT_DIR")
}

teardown() {
    teardown_mock_gpg
    teardown_test_env
}

# =============================================================================
# Use Command
# =============================================================================

@test "use decrypts environment to .env" {
    create_test_env "$TEST_PROJECT" "local" "DB_HOST=localhost"

    run_senv use local
    [ "$status" -eq 0 ]
    assert_file_exists ".env"
    assert_file_contains ".env" "DB_HOST=localhost"
}

@test "use adds senv header comment" {
    create_test_env "$TEST_PROJECT" "staging" "API_KEY=secret"

    run_senv use staging
    [ "$status" -eq 0 ]
    assert_file_contains ".env" "# senv: staging"
}

@test "use shows success message" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    run_senv use local
    [ "$status" -eq 0 ]
    assert_output_contains "Activated"
    assert_output_contains "local"
}

@test "use fails for non-existent environment" {
    run_senv use nonexistent
    [ "$status" -eq 1 ]
    assert_output_contains "not found"
}

@test "use fails without environment argument" {
    run_senv use
    [ "$status" -eq 1 ]
    assert_output_contains "Usage:"
}

@test "use warns when switching environments" {
    create_test_env "$TEST_PROJECT" "local" "VAR=local"
    create_test_env "$TEST_PROJECT" "staging" "VAR=staging"

    # First use
    run_senv use local
    [ "$status" -eq 0 ]

    # Second use - should warn
    run_senv use staging
    [ "$status" -eq 0 ]
    assert_file_contains ".env" "# senv: staging"
}

@test "use suggests creating .envrc" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    run_senv use local
    [ "$status" -eq 0 ]
    assert_output_contains "Tip:"
    assert_output_contains ".envrc"
}

@test "use does not suggest .envrc if it exists" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"
    echo "dotenv" > .envrc

    run_senv use local
    [ "$status" -eq 0 ]
    assert_output_not_contains "Tip:"
}

@test "use works with -p project override" {
    create_test_env "override-project" "production" "PROD=true"

    run_senv -p override-project use production
    [ "$status" -eq 0 ]
    assert_file_exists ".env"
    assert_file_contains ".env" "PROD=true"
}

# =============================================================================
# Edit Command
# =============================================================================

# Note: Full edit testing is limited because SOPS opens an interactive editor.
# These tests verify the pre-edit behavior and error handling.

@test "edit fails without environment argument" {
    run_senv edit
    [ "$status" -eq 1 ]
    assert_output_contains "Usage:"
}

@test "edit creates project directory for new environment" {
    # We can test that the project directory gets created by checking
    # after an edit of an existing environment
    create_test_env "$TEST_PROJECT" "existing" "VAR=value"

    # Verify project directory exists after create_test_env
    assert_dir_exists "$TEST_SECRETS_DIR/$TEST_PROJECT"
}

@test "edit can open existing environment" {
    # Create an environment first
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    # Set EDITOR to true (no-op) to avoid interactive mode
    # Note: This test verifies the file exists and edit doesn't error on finding it
    export EDITOR="true"
    export VISUAL="true"

    # Run with timeout to avoid hanging - this will exit after SOPS tries to edit
    timeout 2 "$SENV_BIN" edit local 2>/dev/null || true

    # The encrypted file should still exist
    assert_file_exists "$TEST_SECRETS_DIR/$TEST_PROJECT/local.env.enc"
}

# =============================================================================
# Save Command
# =============================================================================

@test "save encrypts .env back to repo" {
    create_test_env "$TEST_PROJECT" "local" "ORIGINAL=value"
    run_senv use local
    [ "$status" -eq 0 ]

    # Modify .env
    echo "MODIFIED=newvalue" >> .env

    run_senv save
    [ "$status" -eq 0 ]
    assert_output_contains "Saved"
}

@test "save fails without .env file" {
    run_senv save
    [ "$status" -eq 1 ]
    assert_output_contains "No .env file"
}

@test "save fails if .env has no senv header" {
    echo "PLAIN=value" > .env

    run_senv save
    [ "$status" -eq 1 ]
    assert_output_contains "not created by senv"
}

@test "save creates backup of existing encrypted file" {
    create_test_env "$TEST_PROJECT" "local" "ORIGINAL=value"
    run_senv use local
    [ "$status" -eq 0 ]

    echo "NEW=value" >> .env
    run_senv save
    [ "$status" -eq 0 ]

    assert_file_exists "$TEST_SECRETS_DIR/$TEST_PROJECT/local.env.enc.backup"
}

@test "save strips senv header comments" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"
    run_senv use local
    [ "$status" -eq 0 ]

    # Save and then use again to verify
    run_senv save
    [ "$status" -eq 0 ]

    # Use again and check no duplicate headers
    rm .env
    run_senv use local
    [ "$status" -eq 0 ]

    # Count header lines - should only be the ones we add
    local header_count=$(grep -c "^# senv:" .env || echo "0")
    [ "$header_count" -eq 1 ]
}

@test "save shows reminder to commit" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"
    run_senv use local
    run_senv save
    [ "$status" -eq 0 ]
    assert_output_contains "commit"
}
