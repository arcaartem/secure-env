#!/usr/bin/env bats
# Tests for new secrets path resolution (no config.yaml)
# Priority: -s flag → SENV_SECRETS_PATH env → ~/.local/share/senv (default)

load test_helper

setup() {
    setup_test_env
    setup_mock_gpg

    # Override HOME for predictable default path testing
    export TEST_LOCAL_SHARE="$TEST_HOME/.local/share"
    export TEST_DEFAULT_SECRETS="$TEST_LOCAL_SHARE/senv"

    # Clear any overrides
    unset SENV_SECRETS_PATH

    export TEST_PROJECT=$(basename "$TEST_PROJECT_DIR")
}

teardown() {
    teardown_mock_gpg
    teardown_test_env
}

# =============================================================================
# Default Path (no config.yaml needed)
# =============================================================================

@test "secrets path defaults to ~/.local/share/senv" {
    # Create the default directory structure with .sops.yaml
    mkdir -p "$TEST_DEFAULT_SECRETS"
    cat > "$TEST_DEFAULT_SECRETS/.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*\.env\.enc$
    pgp: $TEST_GPG_KEY
EOF

    # Override HOME so default resolves to our test directory
    export HOME="$TEST_HOME"

    run_senv repo
    [ "$status" -eq 0 ]
    assert_output_contains "$TEST_DEFAULT_SECRETS"
}

@test "init creates secrets directory at default location" {
    export HOME="$TEST_HOME"

    run_senv_stdin "pgp
$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_dir_exists "$TEST_DEFAULT_SECRETS"
}

@test "init creates .sops.yaml at default secrets location" {
    export HOME="$TEST_HOME"

    run_senv_stdin "pgp
$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_file_exists "$TEST_DEFAULT_SECRETS/.sops.yaml"
}

# =============================================================================
# Environment Variable Override
# =============================================================================

@test "SENV_SECRETS_PATH overrides default location" {
    local custom_path="$TEST_HOME/custom-secrets"
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

@test "init uses SENV_SECRETS_PATH when set" {
    local custom_path="$TEST_HOME/env-var-secrets"
    export SENV_SECRETS_PATH="$custom_path"

    run_senv_stdin "pgp
$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_dir_exists "$custom_path"
    assert_file_exists "$custom_path/.sops.yaml"
}

# =============================================================================
# Flag Override (highest priority)
# =============================================================================

@test "-s flag overrides SENV_SECRETS_PATH" {
    local env_path="$TEST_HOME/env-secrets"
    local flag_path="$TEST_HOME/flag-secrets"
    mkdir -p "$env_path" "$flag_path"

    for dir in "$env_path" "$flag_path"; do
        cat > "$dir/.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*\.env\.enc$
    pgp: $TEST_GPG_KEY
EOF
    done

    export SENV_SECRETS_PATH="$env_path"

    run_senv -s "$flag_path" repo
    [ "$status" -eq 0 ]
    assert_output_contains "$flag_path"
    assert_output_not_contains "$env_path"
}

@test "-s flag overrides default location" {
    local flag_path="$TEST_HOME/flag-secrets"
    mkdir -p "$flag_path"
    cat > "$flag_path/.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*\.env\.enc$
    pgp: $TEST_GPG_KEY
EOF

    export HOME="$TEST_HOME"

    run_senv -s "$flag_path" repo
    [ "$status" -eq 0 ]
    assert_output_contains "$flag_path"
}

@test "init with -s flag creates secrets at specified location" {
    local flag_path="$TEST_HOME/flag-init-secrets"

    run_senv_stdin "pgp
$TEST_GPG_KEY" -s "$flag_path" init
    [ "$status" -eq 0 ]
    assert_dir_exists "$flag_path"
    assert_file_exists "$flag_path/.sops.yaml"
}

# =============================================================================
# No Config File Required
# =============================================================================

@test "commands work without config.yaml" {
    # Set up secrets directory directly (no config.yaml)
    local secrets_path="$TEST_HOME/direct-secrets"
    mkdir -p "$secrets_path/$TEST_PROJECT"

    cat > "$secrets_path/.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*\.env\.enc$
    pgp: $TEST_GPG_KEY
EOF

    # Create a test environment
    echo "VAR=value" | sops -e --input-type dotenv --output-type dotenv \
        --pgp "$TEST_GPG_KEY" /dev/stdin > "$secrets_path/$TEST_PROJECT/local.env.enc"

    export SENV_SECRETS_PATH="$secrets_path"

    # Commands should work without any config.yaml
    run_senv list
    [ "$status" -eq 0 ]
    assert_output_contains "local"
}

@test "old config.yaml location is ignored" {
    # Create old-style config (should be ignored)
    local old_config_dir="$TEST_HOME/.config/senv"
    mkdir -p "$old_config_dir"
    cat > "$old_config_dir/config.yaml" <<EOF
secrets_path: $TEST_HOME/old-secrets
gpg_key: OLD_KEY_12345
EOF

    # Set up new location
    local new_secrets="$TEST_HOME/new-secrets"
    mkdir -p "$new_secrets"
    cat > "$new_secrets/.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*\.env\.enc$
    pgp: $TEST_GPG_KEY
EOF

    export SENV_SECRETS_PATH="$new_secrets"

    run_senv repo
    [ "$status" -eq 0 ]
    # Should use new location, not old config
    assert_output_contains "$new_secrets"
    assert_output_not_contains "old-secrets"
}

# =============================================================================
# Git Repo Initialization
# =============================================================================

@test "init creates git repo in secrets directory" {
    export HOME="$TEST_HOME"

    run_senv_stdin "pgp
$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_dir_exists "$TEST_DEFAULT_SECRETS/.git"
}

@test "init creates .gitignore in secrets directory" {
    export HOME="$TEST_HOME"

    run_senv_stdin "pgp
$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_file_exists "$TEST_DEFAULT_SECRETS/.gitignore"
    assert_file_contains "$TEST_DEFAULT_SECRETS/.gitignore" "*.env"
    assert_file_contains "$TEST_DEFAULT_SECRETS/.gitignore" "!*.env.enc"
}
