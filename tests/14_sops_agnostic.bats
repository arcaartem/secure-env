#!/usr/bin/env bats
# Tests for SOPS-agnostic encryption (no -p flag, relies on .sops.yaml)

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
}

teardown() {
    teardown_mock_gpg
    teardown_test_env
}

# =============================================================================
# Import uses .sops.yaml (no -p flag)
# =============================================================================

@test "import encrypts using .sops.yaml rules" {
    create_plain_env "local" "VAR=value"

    run_senv import
    [ "$status" -eq 0 ]
    assert_file_exists "$TEST_DEFAULT_SECRETS/$TEST_PROJECT/local.env.enc"
}

@test "import works with pgp backend from .sops.yaml" {
    create_plain_env "staging" "DB_HOST=localhost"

    run_senv import
    [ "$status" -eq 0 ]

    # Verify we can decrypt (proves it was encrypted correctly)
    run_senv use staging
    [ "$status" -eq 0 ]
    assert_file_contains ".env" "DB_HOST=localhost"
}

@test "import encrypts multiple files using .sops.yaml" {
    create_plain_env "local" "LOCAL=1"
    create_plain_env "staging" "STAGING=2"
    create_plain_env "production" "PROD=3"

    run_senv import
    [ "$status" -eq 0 ]

    # All should be encrypted
    assert_file_exists "$TEST_DEFAULT_SECRETS/$TEST_PROJECT/local.env.enc"
    assert_file_exists "$TEST_DEFAULT_SECRETS/$TEST_PROJECT/staging.env.enc"
    assert_file_exists "$TEST_DEFAULT_SECRETS/$TEST_PROJECT/production.env.enc"
}

# =============================================================================
# Save uses .sops.yaml (no -p flag)
# =============================================================================

@test "save encrypts using .sops.yaml rules" {
    # Create initial env using the test helper
    create_test_env "$TEST_PROJECT" "local" "ORIGINAL=value"

    run_senv use local
    [ "$status" -eq 0 ]

    # Modify and save
    echo "NEW=value" >> .env
    run_senv save
    [ "$status" -eq 0 ]

    # Verify by using again
    rm .env
    run_senv use local
    [ "$status" -eq 0 ]
    assert_file_contains ".env" "NEW=value"
}

@test "save preserves all content after re-encryption" {
    create_test_env "$TEST_PROJECT" "local" "VAR1=one
VAR2=two
VAR3=three"

    run_senv use local
    echo "VAR4=four" >> .env
    run_senv save
    [ "$status" -eq 0 ]

    rm .env
    run_senv use local
    assert_file_contains ".env" "VAR1=one"
    assert_file_contains ".env" "VAR2=two"
    assert_file_contains ".env" "VAR3=three"
    assert_file_contains ".env" "VAR4=four"
}

# =============================================================================
# Edit uses .sops.yaml (no -p flag)
# =============================================================================

@test "edit creates new file using .sops.yaml rules" {
    # Set editor to something that just exits
    export EDITOR="true"
    export VISUAL="true"

    # Run edit with timeout (SOPS will try to open editor)
    timeout 2 "$SENV_BIN" edit newenv 2>/dev/null || true

    # File should be created at correct location
    assert_file_exists "$TEST_DEFAULT_SECRETS/$TEST_PROJECT/newenv.env.enc"
}

# =============================================================================
# Use/Export/Diff work with .sops.yaml encrypted files
# =============================================================================

@test "use decrypts files encrypted via .sops.yaml" {
    create_test_env "$TEST_PROJECT" "local" "SECRET=mysecret"

    run_senv use local
    [ "$status" -eq 0 ]
    assert_file_contains ".env" "SECRET=mysecret"
}

@test "export decrypts files encrypted via .sops.yaml" {
    create_test_env "$TEST_PROJECT" "local" "EXPORTED=value"

    run_senv export
    [ "$status" -eq 0 ]
    assert_file_exists ".env.local"
    assert_file_contains ".env.local" "EXPORTED=value"
}

@test "diff works with files encrypted via .sops.yaml" {
    create_test_env "$TEST_PROJECT" "local" "DIFFVAR=stored"

    run_senv use local
    [ "$status" -eq 0 ]

    # Modify local
    cat > .env <<EOF
# senv: local
DIFFVAR=modified
EOF

    run_senv diff
    [ "$status" -eq 0 ]
    assert_output_contains "stored"
    assert_output_contains "modified"
}

# =============================================================================
# Age Backend (if available)
# =============================================================================

@test "import works with age backend" {
    if ! command -v age &>/dev/null; then
        skip "age not installed"
    fi

    # Create age key
    local age_key_dir="$TEST_HOME/.config/sops/age"
    mkdir -p "$age_key_dir"
    age-keygen -o "$age_key_dir/keys.txt" 2>/dev/null
    local age_recipient=$(grep "public key:" "$age_key_dir/keys.txt" | sed 's/.*: //')

    export SOPS_AGE_KEY_FILE="$age_key_dir/keys.txt"

    # Update .sops.yaml to use age
    cat > "$TEST_DEFAULT_SECRETS/.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*\.env\.enc$
    age: $age_recipient
EOF

    create_plain_env "local" "AGE_VAR=encrypted_with_age"

    run_senv import
    [ "$status" -eq 0 ]

    # Verify decryption works
    run_senv use local
    [ "$status" -eq 0 ]
    assert_file_contains ".env" "AGE_VAR=encrypted_with_age"
}

@test "save works with age backend" {
    if ! command -v age &>/dev/null; then
        skip "age not installed"
    fi

    # Create age key
    local age_key_dir="$TEST_HOME/.config/sops/age"
    mkdir -p "$age_key_dir"
    age-keygen -o "$age_key_dir/keys.txt" 2>/dev/null
    local age_recipient=$(grep "public key:" "$age_key_dir/keys.txt" | sed 's/.*: //')

    export SOPS_AGE_KEY_FILE="$age_key_dir/keys.txt"

    # Update .sops.yaml to use age
    cat > "$TEST_DEFAULT_SECRETS/.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*\.env\.enc$
    age: $age_recipient
EOF

    # Create initial encrypted file using the updated .sops.yaml
    mkdir -p "$TEST_DEFAULT_SECRETS/$TEST_PROJECT"
    local enc_file="$TEST_DEFAULT_SECRETS/$TEST_PROJECT/local.env.enc"
    echo "ORIGINAL=value" | sops --config "$TEST_DEFAULT_SECRETS/.sops.yaml" --filename-override "$enc_file" -e --input-type dotenv --output-type dotenv /dev/stdin > "$enc_file"

    run_senv use local
    echo "ADDED=new" >> .env
    run_senv save
    [ "$status" -eq 0 ]

    rm .env
    run_senv use local
    assert_file_contains ".env" "ORIGINAL=value"
    assert_file_contains ".env" "ADDED=new"
}

# =============================================================================
# Error Handling
# =============================================================================

@test "import fails gracefully if .sops.yaml is missing" {
    rm -f "$TEST_DEFAULT_SECRETS/.sops.yaml"
    create_plain_env "local" "VAR=value"

    run_senv import
    [ "$status" -eq 1 ]
    # Should mention .sops.yaml or initialization
    assert_output_contains ".sops.yaml" || assert_output_contains "init"
}

@test "save fails gracefully if .sops.yaml is missing" {
    # Create a .env with header (simulating previous use)
    cat > .env <<EOF
# senv: local
VAR=value
EOF

    rm -f "$TEST_DEFAULT_SECRETS/.sops.yaml"

    run_senv save
    [ "$status" -eq 1 ]
}

@test "commands fail with helpful message when .sops.yaml has wrong permissions" {
    # This test is more about SOPS behavior, but good to verify senv handles it
    skip "Platform-dependent test"
}
