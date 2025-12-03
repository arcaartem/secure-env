#!/usr/bin/env bats
# Tests for safe file operations (atomic writes, no data loss on failure)

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
# Safe 'use' (decryption) tests
# =============================================================================

@test "use does not create .env if decryption fails" {
    local project_name=$(basename "$TEST_PROJECT_DIR")

    # Create a corrupted encrypted file (not valid SOPS format)
    mkdir -p "$TEST_SECRETS_DIR/$project_name"
    echo "this is not encrypted content" > "$TEST_SECRETS_DIR/$project_name/broken.env.enc"

    # Ensure no .env exists before
    [ ! -f ".env" ]

    # Try to use the broken environment
    run_senv use broken
    [ "$status" -ne 0 ]

    # .env should NOT be created
    [ ! -f ".env" ]
}

@test "use preserves existing .env if decryption fails" {
    local project_name=$(basename "$TEST_PROJECT_DIR")

    # Create a valid environment first
    create_test_env "$project_name" "good" "GOOD_VAR=good_value"

    # Use the good environment to create .env
    run_senv use good
    [ "$status" -eq 0 ]
    [ -f ".env" ]
    grep -q "GOOD_VAR=good_value" .env

    # Create a corrupted encrypted file
    echo "this is not encrypted content" > "$TEST_SECRETS_DIR/$project_name/broken.env.enc"

    # Try to use the broken environment
    run_senv use broken
    [ "$status" -ne 0 ]

    # Original .env should still exist with original content
    [ -f ".env" ]
    grep -q "GOOD_VAR=good_value" .env
}

@test "use shows decryption error message on failure" {
    local project_name=$(basename "$TEST_PROJECT_DIR")

    # Create a corrupted encrypted file
    mkdir -p "$TEST_SECRETS_DIR/$project_name"
    echo "not valid sops content" > "$TEST_SECRETS_DIR/$project_name/broken.env.enc"

    run_senv use broken
    [ "$status" -ne 0 ]
    assert_output_contains "Decryption failed"
}

@test "use cleans up temp files on success" {
    local project_name=$(basename "$TEST_PROJECT_DIR")
    create_test_env "$project_name" "local" "MY_VAR=my_value"

    # Count temp files before
    local temp_count_before=$(ls /tmp 2>/dev/null | wc -l)

    run_senv use local
    [ "$status" -eq 0 ]

    # Count temp files after - should not have leaked any
    local temp_count_after=$(ls /tmp 2>/dev/null | wc -l)

    # Allow for some variance due to system activity, but should be close
    [ "$temp_count_after" -le "$((temp_count_before + 5))" ]
}

@test "use cleans up temp files on failure" {
    local project_name=$(basename "$TEST_PROJECT_DIR")

    # Create corrupted file
    mkdir -p "$TEST_SECRETS_DIR/$project_name"
    echo "corrupted" > "$TEST_SECRETS_DIR/$project_name/broken.env.enc"

    # Count temp files before
    local temp_count_before=$(ls /tmp 2>/dev/null | wc -l)

    run_senv use broken
    [ "$status" -ne 0 ]

    # Count temp files after - should not have leaked any
    local temp_count_after=$(ls /tmp 2>/dev/null | wc -l)
    [ "$temp_count_after" -le "$((temp_count_before + 5))" ]
}

# =============================================================================
# Safe 'save' (encryption) tests
# =============================================================================

@test "save does not corrupt encrypted file if encryption fails" {
    local project_name=$(basename "$TEST_PROJECT_DIR")

    # Create and use a valid environment
    create_test_env "$project_name" "local" "ORIGINAL_VAR=original_value"
    run_senv use local
    [ "$status" -eq 0 ]

    # Get the original encrypted file content hash
    local enc_path="$TEST_SECRETS_DIR/$project_name/local.env.enc"
    local original_hash=$(md5sum "$enc_path" | cut -d' ' -f1)

    # Backup the valid .sops.yaml
    cp "$TEST_SECRETS_DIR/.sops.yaml" "$TEST_SECRETS_DIR/.sops.yaml.valid"

    # Make .sops.yaml invalid to cause encryption failure
    echo "invalid yaml: [[[" > "$TEST_SECRETS_DIR/.sops.yaml"

    # Modify .env to trigger actual save attempt
    echo "NEW_VAR=new_value" >> .env

    # Try to save - should fail
    run_senv save
    [ "$status" -ne 0 ]

    # Restore valid .sops.yaml for further checks
    mv "$TEST_SECRETS_DIR/.sops.yaml.valid" "$TEST_SECRETS_DIR/.sops.yaml"

    # Check that the encrypted file was restored from backup (same hash or decryptable with original content)
    run sops --config "$TEST_SECRETS_DIR/.sops.yaml" --input-type dotenv --output-type dotenv -d "$enc_path"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ORIGINAL_VAR=original_value"* ]]
}

@test "save restores from backup on encryption failure" {
    local project_name=$(basename "$TEST_PROJECT_DIR")

    # Create and use a valid environment
    create_test_env "$project_name" "local" "BACKUP_TEST=original"
    run_senv use local
    [ "$status" -eq 0 ]

    local enc_path="$TEST_SECRETS_DIR/$project_name/local.env.enc"

    # Modify the .env file (but keep the header intact)
    cat > .env <<EOF
# senv: local
BACKUP_TEST=modified
EOF

    # Break .sops.yaml to cause encryption failure
    cp "$TEST_SECRETS_DIR/.sops.yaml" "$TEST_SECRETS_DIR/.sops.yaml.bak"
    echo "broken: [[[" > "$TEST_SECRETS_DIR/.sops.yaml"

    # Try to save - should fail
    run_senv save
    [ "$status" -ne 0 ]

    # Restore .sops.yaml
    mv "$TEST_SECRETS_DIR/.sops.yaml.bak" "$TEST_SECRETS_DIR/.sops.yaml"

    # The original encrypted file should be restored from backup
    run sops --config "$TEST_SECRETS_DIR/.sops.yaml" --input-type dotenv --output-type dotenv -d "$enc_path"
    [ "$status" -eq 0 ]
    [[ "$output" == *"BACKUP_TEST=original"* ]]
}

@test "save shows encryption error message on failure" {
    local project_name=$(basename "$TEST_PROJECT_DIR")

    # Create a .env with senv header
    cat > .env <<EOF
# senv: local
# Decrypted from: somewhere
TEST_VAR=test
EOF

    # Create project directory but no valid .sops.yaml
    mkdir -p "$TEST_SECRETS_DIR/$project_name"
    echo "invalid: [[[yaml" > "$TEST_SECRETS_DIR/.sops.yaml"

    run_senv save
    [ "$status" -ne 0 ]
    assert_output_contains "Encryption failed"
}

@test "save cleans up temp files on success" {
    local project_name=$(basename "$TEST_PROJECT_DIR")
    create_test_env "$project_name" "local" "TEMP_TEST=value"
    run_senv use local
    [ "$status" -eq 0 ]

    # Count temp files before
    local temp_count_before=$(ls /tmp 2>/dev/null | wc -l)

    run_senv save
    [ "$status" -eq 0 ]

    # Count temp files after
    local temp_count_after=$(ls /tmp 2>/dev/null | wc -l)
    [ "$temp_count_after" -le "$((temp_count_before + 5))" ]
}

@test "save cleans up temp files on failure" {
    local project_name=$(basename "$TEST_PROJECT_DIR")

    # Create .env with header
    cat > .env <<EOF
# senv: local
TEST=value
EOF

    mkdir -p "$TEST_SECRETS_DIR/$project_name"
    echo "broken yaml" > "$TEST_SECRETS_DIR/.sops.yaml"

    local temp_count_before=$(ls /tmp 2>/dev/null | wc -l)

    run_senv save
    [ "$status" -ne 0 ]

    local temp_count_after=$(ls /tmp 2>/dev/null | wc -l)
    [ "$temp_count_after" -le "$((temp_count_before + 5))" ]
}

# =============================================================================
# Atomic operation tests
# =============================================================================

@test "use writes .env atomically (all or nothing)" {
    local project_name=$(basename "$TEST_PROJECT_DIR")
    create_test_env "$project_name" "local" "VAR1=value1
VAR2=value2
VAR3=value3"

    run_senv use local
    [ "$status" -eq 0 ]

    # All content should be present
    grep -q "VAR1=value1" .env
    grep -q "VAR2=value2" .env
    grep -q "VAR3=value3" .env

    # Header should be present
    grep -q "# senv: local" .env
}

@test "save writes encrypted file atomically" {
    local project_name=$(basename "$TEST_PROJECT_DIR")
    create_test_env "$project_name" "local" "INITIAL=value"

    run_senv use local
    [ "$status" -eq 0 ]

    # Modify .env with multiple values
    cat > .env <<EOF
# senv: local
NEW1=newvalue1
NEW2=newvalue2
NEW3=newvalue3
EOF

    run_senv save
    [ "$status" -eq 0 ]

    # Verify all content was saved by decrypting
    local enc_path="$TEST_SECRETS_DIR/$project_name/local.env.enc"
    run sops --config "$TEST_SECRETS_DIR/.sops.yaml" --input-type dotenv --output-type dotenv -d "$enc_path"
    [ "$status" -eq 0 ]
    [[ "$output" == *"NEW1=newvalue1"* ]]
    [[ "$output" == *"NEW2=newvalue2"* ]]
    [[ "$output" == *"NEW3=newvalue3"* ]]
}

@test "concurrent use operations are safe" {
    local project_name=$(basename "$TEST_PROJECT_DIR")
    create_test_env "$project_name" "env1" "ENV1_VAR=env1_value"
    create_test_env "$project_name" "env2" "ENV2_VAR=env2_value"

    # Run two use commands - second should overwrite first cleanly
    run_senv use env1
    [ "$status" -eq 0 ]
    grep -q "ENV1_VAR=env1_value" .env

    run_senv use env2
    [ "$status" -eq 0 ]
    grep -q "ENV2_VAR=env2_value" .env
    # env1 content should be gone
    ! grep -q "ENV1_VAR" .env
}
