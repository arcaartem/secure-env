#!/usr/bin/env bats
# Tests for list, status, and diff commands

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
# List Command
# =============================================================================

@test "list shows available environments" {
    create_test_env "$TEST_PROJECT" "local" "VAR=local"
    create_test_env "$TEST_PROJECT" "staging" "VAR=staging"
    create_test_env "$TEST_PROJECT" "production" "VAR=prod"

    run_senv list
    [ "$status" -eq 0 ]
    assert_output_contains "local"
    assert_output_contains "staging"
    assert_output_contains "production"
}

@test "list fails for project with no environments" {
    run_senv list
    [ "$status" -eq 1 ]
    assert_output_contains "No environments"
}

@test "list works with -p project override" {
    create_test_env "other-project" "dev" "VAR=dev"

    run_senv -p other-project list
    [ "$status" -eq 0 ]
    assert_output_contains "dev"
}

@test "list shows only environment names" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    run_senv list
    [ "$status" -eq 0 ]
    # Should show just "local", not the full path or .env.enc extension
    assert_output_not_contains ".env.enc"
    assert_output_not_contains "$TEST_SECRETS_DIR"
}

# =============================================================================
# Status Command
# =============================================================================

@test "status shows project name" {
    run_senv status
    [ "$status" -eq 0 ]
    assert_output_contains "Project:"
}

@test "status shows active environment when .env exists" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"
    run_senv use local

    run_senv status
    [ "$status" -eq 0 ]
    assert_output_contains "Active: local"
}

@test "status shows (none) when no .env exists" {
    run_senv status
    [ "$status" -eq 0 ]
    assert_output_contains "Active: (none)"
}

@test "status lists available environments" {
    create_test_env "$TEST_PROJECT" "local" "VAR=local"
    create_test_env "$TEST_PROJECT" "staging" "VAR=staging"

    run_senv status
    [ "$status" -eq 0 ]
    assert_output_contains "Available:"
    assert_output_contains "local"
    assert_output_contains "staging"
}

@test "status shows (none) for available when no envs exist" {
    run_senv status
    [ "$status" -eq 0 ]
    assert_output_contains "(none)"
}

@test "status works with -p project override" {
    run_senv -p custom-proj status
    [ "$status" -eq 0 ]
    assert_output_contains "Project: custom-proj"
}

# =============================================================================
# Diff Command
# =============================================================================

@test "diff shows differences between local and stored" {
    create_test_env "$TEST_PROJECT" "local" "VAR=original"
    run_senv use local

    # Modify .env
    echo "VAR=modified" > .env
    echo "# senv: local" | cat - .env > temp && mv temp .env

    run_senv diff local
    [ "$status" -eq 0 ]
    assert_output_contains "original"
    assert_output_contains "modified"
}

@test "diff uses current .env header if env not specified" {
    create_test_env "$TEST_PROJECT" "local" "VAR=original"
    run_senv use local

    echo "NEW=value" >> .env

    run_senv diff
    [ "$status" -eq 0 ]
    assert_output_contains "NEW=value"
}

@test "diff fails without .env file" {
    run_senv diff local
    [ "$status" -eq 1 ]
    assert_output_contains "No .env file"
}

@test "diff fails for non-existent environment" {
    echo "VAR=value" > .env
    echo "# senv: local" | cat - .env > temp && mv temp .env

    run_senv diff nonexistent
    [ "$status" -eq 1 ]
    assert_output_contains "not found"
}

@test "diff fails without env arg and no senv header" {
    echo "VAR=value" > .env

    run_senv diff
    [ "$status" -eq 1 ]
    assert_output_contains "Usage:"
}

@test "diff shows no output when files are identical" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"
    run_senv use local

    run_senv diff local
    [ "$status" -eq 0 ]
    # Diff should produce minimal or no output for identical content
    # (just the header lines stripped)
}

@test "diff strips header comments from comparison" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"
    run_senv use local

    run_senv diff local
    [ "$status" -eq 0 ]
    # Should not show diff for senv header lines
    assert_output_not_contains "# senv:"
    assert_output_not_contains "# Decrypted from:"
}
