#!/usr/bin/env bats
# Tests for senv init command

load test_helper

setup() {
    setup_test_env
    setup_mock_gpg
}

teardown() {
    teardown_mock_gpg
    teardown_test_env
}

# =============================================================================
# Init Command
# =============================================================================

@test "init creates config directory" {
    run_senv_stdin "$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_dir_exists "$TEST_CONFIG_DIR"
}

@test "init creates config file" {
    run_senv_stdin "$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_file_exists "$TEST_CONFIG_DIR/config.yaml"
}

@test "init creates secrets directory" {
    run_senv_stdin "$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_dir_exists "$TEST_SECRETS_DIR"
}

@test "init creates git repo in secrets directory" {
    run_senv_stdin "$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_dir_exists "$TEST_SECRETS_DIR/.git"
}

@test "init creates .sops.yaml" {
    run_senv_stdin "$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_file_exists "$TEST_SECRETS_DIR/.sops.yaml"
    assert_file_contains "$TEST_SECRETS_DIR/.sops.yaml" "$TEST_GPG_KEY"
}

@test "init creates .gitignore" {
    run_senv_stdin "$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_file_exists "$TEST_SECRETS_DIR/.gitignore"
    assert_file_contains "$TEST_SECRETS_DIR/.gitignore" "*.env"
    assert_file_contains "$TEST_SECRETS_DIR/.gitignore" "!*.env.enc"
}

@test "init stores gpg_key in config" {
    run_senv_stdin "$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_file_contains "$TEST_CONFIG_DIR/config.yaml" "gpg_key: $TEST_GPG_KEY"
}

@test "init shows success message" {
    run_senv_stdin "$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_output_contains "Initialized senv"
}

@test "init warns if already initialized" {
    # First init
    run_senv_stdin "$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]

    # Second init - answer 'n' to skip
    run_senv_stdin "n" init
    [ "$status" -eq 0 ]
    assert_output_contains "Already initialized"
}

@test "init fails with invalid GPG key" {
    run_senv_stdin "INVALID_KEY_12345" init
    [ "$status" -eq 1 ]
    assert_output_contains "not found"
}

@test "init fails with empty GPG key" {
    run_senv_stdin "" init
    [ "$status" -eq 1 ]
    assert_output_contains "required"
}
