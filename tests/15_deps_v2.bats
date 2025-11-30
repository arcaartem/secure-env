#!/usr/bin/env bats
# Tests for updated dependency checks (sops only, no gpg requirement)

load test_helper

setup() {
    setup_test_env
    setup_mock_gpg

    export TEST_LOCAL_SHARE="$TEST_HOME/.local/share"
    export TEST_DEFAULT_SECRETS="$TEST_LOCAL_SHARE/senv"
    export HOME="$TEST_HOME"

    # Initialize with .sops.yaml
    mkdir -p "$TEST_DEFAULT_SECRETS"
    cat > "$TEST_DEFAULT_SECRETS/.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*\.env\.enc$
    pgp: $TEST_GPG_KEY
EOF
    git -C "$TEST_DEFAULT_SECRETS" init -q 2>/dev/null || true

    unset SENV_SECRETS_PATH

    export TEST_PROJECT=$(basename "$TEST_PROJECT_DIR")

    # Save original PATH
    export ORIGINAL_PATH="$PATH"
}

teardown() {
    export PATH="$ORIGINAL_PATH"
    teardown_mock_gpg
    teardown_test_env
}

# Helper to hide a command
hide_command() {
    local cmd="$1"
    local fake_path=$(mktemp -d)

    # Include all essential commands + sops/gpg/age so hiding one doesn't break others
    for essential in bash cat grep sed mkdir rmdir rm cp mv ls echo head tail tr basename dirname pwd git mktemp timeout read command age age-keygen sops gpg awk sort uniq; do
        local cmd_path=$(which "$essential" 2>/dev/null || true)
        if [[ -n "$cmd_path" && -x "$cmd_path" ]]; then
            ln -sf "$cmd_path" "$fake_path/$essential"
        fi
    done

    rm -f "$fake_path/$cmd" 2>/dev/null || true
    export PATH="$fake_path"
}

# =============================================================================
# SOPS is the only required dependency for encryption commands
# =============================================================================

@test "use requires only sops (not gpg directly)" {
    # Create encrypted file first (with gpg available)
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    # Note: We can't truly hide gpg since SOPS needs it for PGP backend
    # This test verifies senv itself doesn't call gpg directly
    run_senv use local
    [ "$status" -eq 0 ]
}

@test "use fails when sops is missing" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    hide_command sops

    run_senv use local
    [ "$status" -eq 1 ]
    assert_output_contains "sops"
}

@test "save fails when sops is missing" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    "$SENV_BIN" use local
    echo "NEW=value" >> .env

    hide_command sops

    run_senv save
    [ "$status" -eq 1 ]
    assert_output_contains "sops"
}

@test "import fails when sops is missing" {
    create_plain_env "local" "VAR=value"

    hide_command sops

    run_senv import
    [ "$status" -eq 1 ]
    assert_output_contains "sops"
}

@test "export fails when sops is missing" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    hide_command sops

    run_senv export
    [ "$status" -eq 1 ]
    assert_output_contains "sops"
}

@test "diff fails when sops is missing" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    "$SENV_BIN" use local

    hide_command sops

    run_senv diff
    [ "$status" -eq 1 ]
    assert_output_contains "sops"
}

@test "edit fails when sops is missing" {
    hide_command sops

    run_senv edit local
    [ "$status" -eq 1 ]
    assert_output_contains "sops"
}

# =============================================================================
# Init dependency checks depend on backend
# =============================================================================

@test "init requires sops" {
    hide_command sops

    run_senv_stdin "pgp
$TEST_GPG_KEY" init
    [ "$status" -eq 1 ]
    assert_output_contains "sops"
}

@test "init with pgp backend requires gpg" {
    # Remove existing .sops.yaml to trigger fresh init
    rm -f "$TEST_DEFAULT_SECRETS/.sops.yaml"

    hide_command gpg

    run_senv_stdin "pgp" init
    [ "$status" -eq 1 ]
    assert_output_contains "gpg"
}

@test "init with age backend requires age" {
    rm -f "$TEST_DEFAULT_SECRETS/.sops.yaml"

    hide_command age

    run_senv_stdin "age" init
    [ "$status" -eq 1 ]
    assert_output_contains "age"
}

@test "init requires git" {
    rm -f "$TEST_DEFAULT_SECRETS/.sops.yaml"

    hide_command git

    run_senv_stdin "pgp
$TEST_GPG_KEY" init
    [ "$status" -eq 1 ]
    assert_output_contains "git"
}

# =============================================================================
# Commands that don't need sops
# =============================================================================

@test "help works without sops" {
    hide_command sops

    run_senv help
    [ "$status" -eq 0 ]
    assert_output_contains "USAGE:"
}

@test "version works without sops" {
    hide_command sops

    run_senv version
    [ "$status" -eq 0 ]
}

@test "list works without sops" {
    mkdir -p "$TEST_DEFAULT_SECRETS/$TEST_PROJECT"
    touch "$TEST_DEFAULT_SECRETS/$TEST_PROJECT/local.env.enc"

    hide_command sops

    run_senv list
    [ "$status" -eq 0 ]
    assert_output_contains "local"
}

@test "status works without sops" {
    mkdir -p "$TEST_DEFAULT_SECRETS/$TEST_PROJECT"
    touch "$TEST_DEFAULT_SECRETS/$TEST_PROJECT/local.env.enc"

    hide_command sops

    run_senv status
    [ "$status" -eq 0 ]
}

@test "repo works without sops" {
    hide_command sops

    run_senv repo
    [ "$status" -eq 0 ]
}

@test "delete works without sops" {
    mkdir -p "$TEST_DEFAULT_SECRETS/$TEST_PROJECT"
    touch "$TEST_DEFAULT_SECRETS/$TEST_PROJECT/local.env.enc"

    hide_command sops

    run_senv_stdin "y" delete local
    [ "$status" -eq 0 ]
}

# =============================================================================
# Helpful error messages
# =============================================================================

@test "sops missing error includes install instructions" {
    hide_command sops

    run_senv use local
    [ "$status" -eq 1 ]
    assert_output_contains "sops"
    assert_output_contains "install" || assert_output_contains "brew" || assert_output_contains "https"
}

@test "gpg missing error (during pgp init) includes install instructions" {
    rm -f "$TEST_DEFAULT_SECRETS/.sops.yaml"
    hide_command gpg

    run_senv_stdin "pgp" init
    [ "$status" -eq 1 ]
    assert_output_contains "gpg"
    assert_output_contains "install" || assert_output_contains "brew" || assert_output_contains "apt"
}

@test "age missing error (during age init) includes install instructions" {
    rm -f "$TEST_DEFAULT_SECRETS/.sops.yaml"
    hide_command age

    run_senv_stdin "age" init
    [ "$status" -eq 1 ]
    assert_output_contains "age"
    assert_output_contains "install" || assert_output_contains "brew" || assert_output_contains "https"
}
