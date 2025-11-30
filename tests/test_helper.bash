#!/usr/bin/env bash
# Test helper functions for senv tests

# Path to the senv script
SENV_BIN="${BATS_TEST_DIRNAME}/../senv"

# Setup a clean test environment
setup_test_env() {
    # Create temporary directories
    export TEST_HOME=$(mktemp -d)
    export TEST_PROJECT_DIR=$(mktemp -d)
    # New default location: ~/.local/share/senv
    export TEST_SECRETS_DIR="$TEST_HOME/.local/share/senv"

    # Clear any environment overrides
    unset SENV_PROJECT
    unset SENV_SECRETS_PATH

    # Change to test project directory
    cd "$TEST_PROJECT_DIR"
}

# Cleanup test environment
teardown_test_env() {
    cd /
    [[ -d "$TEST_HOME" ]] && rm -rf "$TEST_HOME"
    [[ -d "$TEST_PROJECT_DIR" ]] && rm -rf "$TEST_PROJECT_DIR"
}

# Create a mock GPG key for testing (uses a test keyring)
setup_mock_gpg() {
    export GNUPGHOME=$(mktemp -d)

    # Create a minimal GPG key for testing (no passphrase)
    cat > "$GNUPGHOME/key_params" <<EOF
%echo Generating test key
Key-Type: RSA
Key-Length: 2048
Name-Real: Test User
Name-Email: test@example.com
Expire-Date: 0
%no-protection
%commit
%echo Done
EOF

    gpg --batch --gen-key "$GNUPGHOME/key_params" 2>/dev/null

    # Get the key ID
    TEST_GPG_KEY=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep "^sec" | head -1 | awk '{print $2}' | cut -d'/' -f2)
    export TEST_GPG_KEY
}

# Cleanup mock GPG
teardown_mock_gpg() {
    [[ -d "$GNUPGHOME" ]] && rm -rf "$GNUPGHOME"
    unset GNUPGHOME
    unset TEST_GPG_KEY
}

# Initialize senv with test GPG key (non-interactive)
# No config.yaml needed - just .sops.yaml in secrets dir
init_senv_for_test() {
    mkdir -p "$TEST_SECRETS_DIR"

    # Set SENV_SECRETS_PATH to point to test secrets directory
    export SENV_SECRETS_PATH="$TEST_SECRETS_DIR"

    # Initialize secrets repo
    git -C "$TEST_SECRETS_DIR" init -q

    # Create .sops.yaml
    cat > "$TEST_SECRETS_DIR/.sops.yaml" <<EOF
creation_rules:
  - path_regex: .*\.env\.enc$
    pgp: $TEST_GPG_KEY
EOF

    # Create .gitignore
    cat > "$TEST_SECRETS_DIR/.gitignore" <<EOF
*.env
!*.env.enc
EOF
}

# Create a test environment file in the secrets repo
# Uses TEST_SECRETS_DIR by default, or TEST_DEFAULT_SECRETS if set
create_test_env() {
    local project="$1"
    local env="$2"
    local content="${3:-TEST_VAR=test_value}"

    # Use TEST_DEFAULT_SECRETS if set, otherwise TEST_SECRETS_DIR
    local secrets_dir="${TEST_DEFAULT_SECRETS:-$TEST_SECRETS_DIR}"
    local project_dir="$secrets_dir/$project"
    local output_file="$project_dir/${env}.env.enc"
    mkdir -p "$project_dir"

    # Encrypt the content using .sops.yaml
    # Use --filename-override so path_regex in .sops.yaml matches the output file
    echo "$content" | sops --config "$secrets_dir/.sops.yaml" --filename-override "$output_file" -e --input-type dotenv --output-type dotenv /dev/stdin > "$output_file"
}

# Create encrypted env file at specific path with specific config
create_encrypted_env() {
    local secrets_dir="$1"
    local project="$2"
    local env="$3"
    local content="${4:-TEST_VAR=test_value}"

    local project_dir="$secrets_dir/$project"
    local output_file="$project_dir/${env}.env.enc"
    mkdir -p "$project_dir"

    echo "$content" | sops --config "$secrets_dir/.sops.yaml" --filename-override "$output_file" -e --input-type dotenv --output-type dotenv /dev/stdin > "$output_file"
}

# Create a plain .env file in current directory
create_plain_env() {
    local env="$1"
    local content="${2:-PLAIN_VAR=plain_value}"

    echo "$content" > ".env.$env"
}

# Run senv command and capture output
# Usage: run_senv [args...]
# For piped input, use: echo "input" | $SENV_BIN args
run_senv() {
    run "$SENV_BIN" "$@"
}

# Run senv with stdin input
# Usage: run_senv_stdin "input" arg1 arg2...
run_senv_stdin() {
    local stdin_input="$1"
    shift
    run bash -c "echo '$stdin_input' | $SENV_BIN $*"
}

# Assert file exists
assert_file_exists() {
    [[ -f "$1" ]] || {
        echo "Expected file to exist: $1"
        return 1
    }
}

# Assert file does not exist
assert_file_not_exists() {
    [[ ! -f "$1" ]] || {
        echo "Expected file to not exist: $1"
        return 1
    }
}

# Assert directory exists
assert_dir_exists() {
    [[ -d "$1" ]] || {
        echo "Expected directory to exist: $1"
        return 1
    }
}

# Assert output contains string
assert_output_contains() {
    [[ "$output" == *"$1"* ]] || {
        echo "Expected output to contain: $1"
        echo "Actual output: $output"
        return 1
    }
}

# Assert output does not contain string
assert_output_not_contains() {
    [[ "$output" != *"$1"* ]] || {
        echo "Expected output to not contain: $1"
        echo "Actual output: $output"
        return 1
    }
}

# Assert file contains string
assert_file_contains() {
    local file="$1"
    local expected="$2"
    grep -q "$expected" "$file" || {
        echo "Expected file $file to contain: $expected"
        echo "Actual contents: $(cat "$file")"
        return 1
    }
}

# Assert file does not contain string
assert_file_not_contains() {
    local file="$1"
    local unexpected="$2"
    ! grep -q "$unexpected" "$file" || {
        echo "Expected file $file to not contain: $unexpected"
        echo "Actual contents: $(cat "$file")"
        return 1
    }
}
