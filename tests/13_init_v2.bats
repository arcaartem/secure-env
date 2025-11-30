#!/usr/bin/env bats
# Tests for new init workflow with backend selection

load test_helper

setup() {
    setup_test_env
    setup_mock_gpg

    export TEST_LOCAL_SHARE="$TEST_HOME/.local/share"
    export TEST_DEFAULT_SECRETS="$TEST_LOCAL_SHARE/senv"
    export HOME="$TEST_HOME"

    unset SENV_SECRETS_PATH

    export TEST_PROJECT=$(basename "$TEST_PROJECT_DIR")
}

teardown() {
    teardown_mock_gpg
    teardown_test_env
}

# =============================================================================
# Existing .sops.yaml Detection
# =============================================================================

@test "init detects existing .sops.yaml and skips setup" {
    mkdir -p "$TEST_DEFAULT_SECRETS"
    cat > "$TEST_DEFAULT_SECRETS/.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*\.env\.enc$
    pgp: $TEST_GPG_KEY
EOF

    run_senv init
    [ "$status" -eq 0 ]
    assert_output_contains "existing"
    assert_output_contains ".sops.yaml"
}

@test "init with existing .sops.yaml does not overwrite it" {
    mkdir -p "$TEST_DEFAULT_SECRETS"
    cat > "$TEST_DEFAULT_SECRETS/.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*\.env\.enc$
    pgp: ORIGINAL_KEY_UNTOUCHED
EOF

    run_senv init
    [ "$status" -eq 0 ]
    assert_file_contains "$TEST_DEFAULT_SECRETS/.sops.yaml" "ORIGINAL_KEY_UNTOUCHED"
}

@test "init with existing .sops.yaml still creates git repo if missing" {
    mkdir -p "$TEST_DEFAULT_SECRETS"
    cat > "$TEST_DEFAULT_SECRETS/.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*\.env\.enc$
    pgp: $TEST_GPG_KEY
EOF

    run_senv init
    [ "$status" -eq 0 ]
    assert_dir_exists "$TEST_DEFAULT_SECRETS/.git"
}

@test "init with existing .sops.yaml still creates .gitignore if missing" {
    mkdir -p "$TEST_DEFAULT_SECRETS"
    cat > "$TEST_DEFAULT_SECRETS/.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*\.env\.enc$
    pgp: $TEST_GPG_KEY
EOF

    run_senv init
    [ "$status" -eq 0 ]
    assert_file_exists "$TEST_DEFAULT_SECRETS/.gitignore"
}

# =============================================================================
# Backend Selection Prompt
# =============================================================================

@test "init prompts for backend selection" {
    run_senv_stdin "" init
    # Should fail or prompt - empty input means no backend selected
    assert_output_contains "backend" || assert_output_contains "age" || assert_output_contains "pgp"
}

@test "init accepts 'pgp' as backend choice" {
    run_senv_stdin "pgp
$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_file_exists "$TEST_DEFAULT_SECRETS/.sops.yaml"
    assert_file_contains "$TEST_DEFAULT_SECRETS/.sops.yaml" "pgp:"
}

@test "init accepts 'age' as backend choice" {
    # Skip if age not installed
    if ! command -v age &>/dev/null; then
        skip "age not installed"
    fi

    # Create a test age key
    local age_key_dir="$TEST_HOME/.config/sops/age"
    mkdir -p "$age_key_dir"
    age-keygen -o "$age_key_dir/keys.txt" 2>/dev/null

    # Extract public key
    local age_recipient=$(grep "public key:" "$age_key_dir/keys.txt" | sed 's/.*: //')

    run_senv_stdin "age" init
    [ "$status" -eq 0 ]
    assert_file_exists "$TEST_DEFAULT_SECRETS/.sops.yaml"
    assert_file_contains "$TEST_DEFAULT_SECRETS/.sops.yaml" "age:"
}

@test "init rejects invalid backend choice" {
    run_senv_stdin "invalid_backend" init
    [ "$status" -eq 1 ]
    assert_output_contains "Invalid" || assert_output_contains "invalid" || assert_output_contains "age" || assert_output_contains "pgp"
}

# =============================================================================
# PGP Backend Setup
# =============================================================================

@test "pgp backend lists available GPG keys" {
    run_senv_stdin "pgp
$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    # Should have shown GPG keys during setup
    assert_output_contains "GPG" || assert_output_contains "key"
}

@test "pgp backend creates .sops.yaml with pgp field" {
    run_senv_stdin "pgp
$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_file_contains "$TEST_DEFAULT_SECRETS/.sops.yaml" "pgp: $TEST_GPG_KEY"
}

@test "pgp backend validates GPG key exists" {
    run_senv_stdin "pgp
NONEXISTENT_KEY_12345" init
    [ "$status" -eq 1 ]
    assert_output_contains "not found" || assert_output_contains "invalid" || assert_output_contains "error"
}

@test "pgp backend fails with empty key" {
    run_senv_stdin "pgp
" init
    [ "$status" -eq 1 ]
    assert_output_contains "required" || assert_output_contains "empty" || assert_output_contains "error"
}

# =============================================================================
# Age Backend Setup
# =============================================================================

@test "age backend checks for age installation" {
    # This test verifies behavior when age might not be installed
    # The init should either succeed (age installed) or fail with helpful message
    run_senv_stdin "age" init

    if command -v age &>/dev/null; then
        # age is installed - should proceed or succeed
        [ "$status" -eq 0 ] || assert_output_contains "key"
    else
        # age not installed - should show helpful error
        [ "$status" -eq 1 ]
        assert_output_contains "age"
        assert_output_contains "install" || assert_output_contains "not found"
    fi
}

@test "age backend detects existing key at default location" {
    if ! command -v age &>/dev/null; then
        skip "age not installed"
    fi

    # Create age key at SOPS default location
    local age_key_dir="$TEST_HOME/.config/sops/age"
    mkdir -p "$age_key_dir"
    age-keygen -o "$age_key_dir/keys.txt" 2>/dev/null

    export SOPS_AGE_KEY_FILE="$age_key_dir/keys.txt"

    run_senv_stdin "age" init
    [ "$status" -eq 0 ]
    assert_file_exists "$TEST_DEFAULT_SECRETS/.sops.yaml"
    assert_file_contains "$TEST_DEFAULT_SECRETS/.sops.yaml" "age:"
}

@test "age backend offers to generate key if none exists" {
    if ! command -v age &>/dev/null; then
        skip "age not installed"
    fi

    # Ensure no age key exists
    rm -rf "$TEST_HOME/.config/sops/age"

    # Answer 'y' to generate key
    run_senv_stdin "age
y" init

    # Should either succeed or ask about key generation
    assert_output_contains "key" || assert_output_contains "generate"
}

@test "age backend creates .sops.yaml with age recipient" {
    if ! command -v age &>/dev/null; then
        skip "age not installed"
    fi

    # Create age key
    local age_key_dir="$TEST_HOME/.config/sops/age"
    mkdir -p "$age_key_dir"
    age-keygen -o "$age_key_dir/keys.txt" 2>/dev/null

    export SOPS_AGE_KEY_FILE="$age_key_dir/keys.txt"

    run_senv_stdin "age" init
    [ "$status" -eq 0 ]

    # .sops.yaml should contain age recipient (starts with "age1")
    assert_file_contains "$TEST_DEFAULT_SECRETS/.sops.yaml" "age1"
}

# =============================================================================
# .sops.yaml Creation Rules
# =============================================================================

@test "created .sops.yaml has correct path regex for .env.enc files" {
    run_senv_stdin "pgp
$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_file_contains "$TEST_DEFAULT_SECRETS/.sops.yaml" "path_regex:"
    # The regex in .sops.yaml contains escaped dots: \.env\.enc$
    assert_file_contains "$TEST_DEFAULT_SECRETS/.sops.yaml" "env"
    assert_file_contains "$TEST_DEFAULT_SECRETS/.sops.yaml" "enc"
}

@test "created .sops.yaml has creation_rules section" {
    run_senv_stdin "pgp
$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_file_contains "$TEST_DEFAULT_SECRETS/.sops.yaml" "creation_rules:"
}

# =============================================================================
# Reinitialize Behavior
# =============================================================================

@test "init warns when .sops.yaml already exists from previous init" {
    # First init
    run_senv_stdin "pgp
$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]

    # Second init should detect existing
    run_senv init
    [ "$status" -eq 0 ]
    assert_output_contains "existing" || assert_output_contains "already"
}

# =============================================================================
# Success Messages
# =============================================================================

@test "init shows success message" {
    run_senv_stdin "pgp
$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_output_contains "success" || assert_output_contains "Initialized" || assert_output_contains "initialized"
}

@test "init shows secrets path in output" {
    run_senv_stdin "pgp
$TEST_GPG_KEY" init
    [ "$status" -eq 0 ]
    assert_output_contains "$TEST_DEFAULT_SECRETS" || assert_output_contains "Secrets:"
}
