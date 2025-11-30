#!/usr/bin/env bats
# Tests for project name and secrets path resolution

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
# Project Name Resolution
# =============================================================================

@test "project name defaults to current directory name" {
    # Create a project directory with known name
    local project_dir="$TEST_HOME/my-test-project"
    mkdir -p "$project_dir"
    cd "$project_dir"

    run_senv status
    [ "$status" -eq 0 ]
    assert_output_contains "Project: my-test-project"
}

@test "-p flag overrides project name" {
    run_senv -p custom-project status
    [ "$status" -eq 0 ]
    assert_output_contains "Project: custom-project"
}

@test "--project flag overrides project name" {
    run_senv --project another-project status
    [ "$status" -eq 0 ]
    assert_output_contains "Project: another-project"
}

@test "SENV_PROJECT env var overrides project name" {
    export SENV_PROJECT="env-var-project"
    run_senv status
    [ "$status" -eq 0 ]
    assert_output_contains "Project: env-var-project"
}

@test "-p flag takes priority over SENV_PROJECT" {
    export SENV_PROJECT="env-var-project"
    run_senv -p flag-project status
    [ "$status" -eq 0 ]
    assert_output_contains "Project: flag-project"
    assert_output_not_contains "env-var-project"
}

# =============================================================================
# Secrets Path Resolution
# =============================================================================

@test "secrets path defaults to config value" {
    run_senv repo
    [ "$status" -eq 0 ]
    assert_output_contains "$TEST_SECRETS_DIR"
}

@test "-s flag overrides secrets path" {
    local custom_secrets="$TEST_HOME/custom-secrets"
    mkdir -p "$custom_secrets"

    # Create minimal .sops.yaml in custom location
    cat > "$custom_secrets/.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*\.env\.enc$
    pgp: $TEST_GPG_KEY
EOF

    run_senv -s "$custom_secrets" repo
    [ "$status" -eq 0 ]
    assert_output_contains "$custom_secrets"
}

@test "--secrets-path flag overrides secrets path" {
    local custom_secrets="$TEST_HOME/custom-secrets-2"
    mkdir -p "$custom_secrets"

    cat > "$custom_secrets/.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*\.env\.enc$
    pgp: $TEST_GPG_KEY
EOF

    run_senv --secrets-path "$custom_secrets" repo
    [ "$status" -eq 0 ]
    assert_output_contains "$custom_secrets"
}

@test "SENV_SECRETS_PATH env var overrides secrets path" {
    local custom_secrets="$TEST_HOME/env-secrets"
    mkdir -p "$custom_secrets"

    cat > "$custom_secrets/.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*\.env\.enc$
    pgp: $TEST_GPG_KEY
EOF

    export SENV_SECRETS_PATH="$custom_secrets"
    run_senv repo
    [ "$status" -eq 0 ]
    assert_output_contains "$custom_secrets"
}

@test "-s flag takes priority over SENV_SECRETS_PATH" {
    local env_secrets="$TEST_HOME/env-secrets"
    local flag_secrets="$TEST_HOME/flag-secrets"
    mkdir -p "$env_secrets" "$flag_secrets"

    for dir in "$env_secrets" "$flag_secrets"; do
        cat > "$dir/.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*\.env\.enc$
    pgp: $TEST_GPG_KEY
EOF
    done

    export SENV_SECRETS_PATH="$env_secrets"
    run_senv -s "$flag_secrets" repo
    [ "$status" -eq 0 ]
    assert_output_contains "$flag_secrets"
    assert_output_not_contains "$env_secrets"
}

# =============================================================================
# Combined Overrides
# =============================================================================

@test "both -p and -s flags work together" {
    local custom_secrets="$TEST_HOME/combo-secrets"
    mkdir -p "$custom_secrets"

    cat > "$custom_secrets/.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*\.env\.enc$
    pgp: $TEST_GPG_KEY
EOF

    run_senv -p combo-project -s "$custom_secrets" status
    [ "$status" -eq 0 ]
    assert_output_contains "Project: combo-project"
}
