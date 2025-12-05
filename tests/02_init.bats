#!/usr/bin/env bats
# Tests for senv init command (v2 structure)
# More comprehensive init tests are in 13_init_v2.bats

load test_helper

setup() {
    setup_test_env
    setup_mock_gpg

    # Set up default secrets path
    export TEST_DEFAULT_SECRETS="$TEST_HOME/.local/share/senv"
    export HOME="$TEST_HOME"
    unset SENV_SECRETS_PATH
}

teardown() {
    teardown_mock_gpg
    teardown_test_env
}

# =============================================================================
# Init Command - Basic Behavior
# =============================================================================

@test "init creates secrets directory" {
    run_senv_stdin "pgp
$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_dir_exists "$TEST_DEFAULT_SECRETS"
}

@test "init creates git repo in secrets directory" {
    run_senv_stdin "pgp
$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_dir_exists "$TEST_DEFAULT_SECRETS/.git"
}

@test "init creates .sops.yaml" {
    run_senv_stdin "pgp
$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_file_exists "$TEST_DEFAULT_SECRETS/.sops.yaml"
    assert_file_contains "$TEST_DEFAULT_SECRETS/.sops.yaml" "$TEST_GPG_KEY"
}

@test "init creates .gitignore" {
    run_senv_stdin "pgp
$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_file_exists "$TEST_DEFAULT_SECRETS/.gitignore"
    assert_file_contains "$TEST_DEFAULT_SECRETS/.gitignore" "*.env"
    assert_file_contains "$TEST_DEFAULT_SECRETS/.gitignore" "!*.env.enc"
}

@test "init shows success message" {
    run_senv_stdin "pgp
$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_output_contains "Initialized" || assert_output_contains "success"
}

@test "init with existing .sops.yaml reuses it" {
    mkdir -p "$TEST_DEFAULT_SECRETS"
    cat > "$TEST_DEFAULT_SECRETS/.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*\.env\.enc$
    pgp: $TEST_GPG_KEY
EOF

    run_senv init
    [ "$status" -eq 0 ]
    assert_output_contains "existing"
}

@test "init fails with invalid GPG key" {
    run_senv_stdin "pgp
INVALID_KEY_12345" init
    [ "$status" -eq 1 ]
}

@test "init fails with empty GPG key" {
    run_senv_stdin "pgp
" init
    [ "$status" -eq 1 ]
}
