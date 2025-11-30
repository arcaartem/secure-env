#!/usr/bin/env bats
# Tests for repo command

load test_helper

setup() {
    setup_test_env
    setup_mock_gpg
    init_senv_for_test
}

teardown() {
    teardown_mock_gpg
    teardown_test_env
}

# =============================================================================
# Basic Repo Command
# =============================================================================

@test "repo prints secrets path" {
    run_senv repo
    [ "$status" -eq 0 ]
    assert_output_contains "$TEST_SECRETS_DIR"
}

@test "repo shows hint for cd command" {
    run_senv repo
    [ "$status" -eq 0 ]
    assert_output_contains 'cd "$(senv repo)"'
}

# =============================================================================
# cd Alias
# =============================================================================

@test "cd is an alias for repo" {
    run_senv cd
    [ "$status" -eq 0 ]
    assert_output_contains "$TEST_SECRETS_DIR"
}

# =============================================================================
# Secrets Path Override
# =============================================================================

@test "repo respects -s flag" {
    local custom_path="$TEST_HOME/custom-secrets"
    mkdir -p "$custom_path"

    cat > "$custom_path/.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*\.env\.enc$
    pgp: $TEST_GPG_KEY
EOF

    run_senv -s "$custom_path" repo
    [ "$status" -eq 0 ]
    assert_output_contains "$custom_path"
}

@test "repo respects SENV_SECRETS_PATH" {
    local custom_path="$TEST_HOME/env-secrets"
    mkdir -p "$custom_path"

    cat > "$custom_path/.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*\.env\.enc$
    pgp: $TEST_GPG_KEY
EOF

    export SENV_SECRETS_PATH="$custom_path"
    run_senv repo
    [ "$status" -eq 0 ]
    assert_output_contains "$custom_path"
}
