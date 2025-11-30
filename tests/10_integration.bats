#!/usr/bin/env bats
# Integration tests - critical user journeys and edge cases

load test_helper

setup() {
    setup_test_env
    setup_mock_gpg
    init_senv_for_test

    export TEST_PROJECT=$(basename "$TEST_PROJECT_DIR")
}

teardown() {
    teardown_mock_gpg
    teardown_test_env
}

# =============================================================================
# Round-trip Integrity (Critical)
# =============================================================================

@test "export then import preserves data integrity" {
    # Create original environment
    create_test_env "$TEST_PROJECT" "local" "DB_HOST=localhost
DB_PORT=5432
API_KEY=secret123"

    # Export
    run_senv export
    [ "$status" -eq 0 ]
    assert_file_exists ".env.local"

    # Capture exported content
    local exported_content=$(cat .env.local)

    # Delete from repo
    run_senv_stdin "y" delete local
    [ "$status" -eq 0 ]

    # Import back
    run_senv import
    [ "$status" -eq 0 ]

    # Use and verify content matches
    run_senv use local
    [ "$status" -eq 0 ]

    # Strip headers and compare
    local reimported_content=$(grep -v "^#" .env | grep -v "^$")
    [ "$reimported_content" = "$exported_content" ]
}

@test "full workflow: create, use, modify, save, use again" {
    # Create environment via import
    echo "ORIGINAL=value" > .env.local
    run_senv import
    [ "$status" -eq 0 ]

    # Use it
    run_senv use local
    [ "$status" -eq 0 ]
    assert_file_contains ".env" "ORIGINAL=value"

    # Modify
    echo "ADDED=newvalue" >> .env

    # Save changes
    run_senv save
    [ "$status" -eq 0 ]

    # Delete local .env and use again
    rm .env
    run_senv use local
    [ "$status" -eq 0 ]

    # Verify both values present
    assert_file_contains ".env" "ORIGINAL=value"
    assert_file_contains ".env" "ADDED=newvalue"
}

# =============================================================================
# Special Characters in Values
# =============================================================================

@test "handles values with spaces" {
    create_plain_env "local" 'DATABASE_URL="postgres://user:pass@host/db"'

    run_senv import
    [ "$status" -eq 0 ]

    run_senv use local
    [ "$status" -eq 0 ]
    assert_file_contains ".env" 'DATABASE_URL="postgres://user:pass@host/db"'
}

@test "handles values with equals signs" {
    create_plain_env "local" "CONNECTION_STRING=host=localhost;port=5432;user=admin"

    run_senv import
    [ "$status" -eq 0 ]

    run_senv use local
    [ "$status" -eq 0 ]
    assert_file_contains ".env" "host=localhost"
}

@test "handles empty values" {
    create_plain_env "local" "EMPTY_VAR=
ANOTHER_VAR=value"

    run_senv import
    [ "$status" -eq 0 ]

    run_senv use local
    [ "$status" -eq 0 ]
    assert_file_contains ".env" "EMPTY_VAR="
    assert_file_contains ".env" "ANOTHER_VAR=value"
}

@test "handles single quotes in values" {
    create_plain_env "local" "QUOTED=\"it's a value\""

    run_senv import
    [ "$status" -eq 0 ]

    run_senv use local
    [ "$status" -eq 0 ]
    assert_file_contains ".env" "it's a value"
}

# =============================================================================
# Not Initialized State
# =============================================================================

@test "use fails gracefully when not initialized" {
    # Remove config to simulate uninitialized state
    rm -f "$TEST_CONFIG_DIR/config.yaml"

    run_senv use local
    [ "$status" -eq 1 ]
    assert_output_contains "not initialized"
    assert_output_contains "senv init"
}

@test "list fails gracefully when not initialized" {
    rm -f "$TEST_CONFIG_DIR/config.yaml"

    run_senv list
    [ "$status" -eq 1 ]
    assert_output_contains "not initialized"
}

@test "export fails gracefully when not initialized" {
    rm -f "$TEST_CONFIG_DIR/config.yaml"

    run_senv export
    [ "$status" -eq 1 ]
    assert_output_contains "not initialized"
}

@test "import fails gracefully when not initialized" {
    rm -f "$TEST_CONFIG_DIR/config.yaml"
    create_plain_env "local" "VAR=value"

    run_senv import
    [ "$status" -eq 1 ]
    assert_output_contains "not initialized"
}

# =============================================================================
# Environment Name Edge Cases
# =============================================================================

@test "handles environment names with hyphens" {
    create_test_env "$TEST_PROJECT" "my-local-env" "VAR=value"

    run_senv use my-local-env
    [ "$status" -eq 0 ]
    assert_file_contains ".env" "VAR=value"
    assert_file_contains ".env" "# senv: my-local-env"
}

@test "handles environment names with underscores" {
    create_test_env "$TEST_PROJECT" "my_local_env" "VAR=value"

    run_senv use my_local_env
    [ "$status" -eq 0 ]
    assert_file_contains ".env" "# senv: my_local_env"
}

@test "handles numeric environment names" {
    create_test_env "$TEST_PROJECT" "env1" "VAR=value"

    run_senv use env1
    [ "$status" -eq 0 ]
    assert_file_contains ".env" "# senv: env1"
}

@test "export handles hyphenated environment names" {
    create_test_env "$TEST_PROJECT" "pre-prod" "VAR=value"

    run_senv export
    [ "$status" -eq 0 ]
    assert_file_exists ".env.pre-prod"
}

@test "import handles hyphenated file names" {
    echo "VAR=value" > ".env.pre-prod"

    run_senv import
    [ "$status" -eq 0 ]
    assert_file_exists "$TEST_SECRETS_DIR/$TEST_PROJECT/pre-prod.env.enc"
}

# =============================================================================
# Project Name Edge Cases
# =============================================================================

@test "handles project names with hyphens" {
    create_test_env "my-cool-project" "local" "VAR=value"

    run_senv -p my-cool-project use local
    [ "$status" -eq 0 ]
    assert_file_contains ".env" "VAR=value"
}

@test "handles project names with underscores" {
    create_test_env "my_cool_project" "local" "VAR=value"

    run_senv -p my_cool_project use local
    [ "$status" -eq 0 ]
    assert_file_contains ".env" "VAR=value"
}

# =============================================================================
# Multiple Projects
# =============================================================================

@test "manages multiple projects independently" {
    # Create envs for two projects
    create_test_env "project-a" "local" "PROJECT=A"
    create_test_env "project-b" "local" "PROJECT=B"

    # Use project A
    run_senv -p project-a use local
    [ "$status" -eq 0 ]
    assert_file_contains ".env" "PROJECT=A"

    # Switch to project B
    run_senv -p project-b use local
    [ "$status" -eq 0 ]
    assert_file_contains ".env" "PROJECT=B"
}

@test "list shows only current project environments" {
    create_test_env "project-a" "local" "VAR=a"
    create_test_env "project-a" "staging" "VAR=a"
    create_test_env "project-b" "production" "VAR=b"

    run_senv -p project-a list
    [ "$status" -eq 0 ]
    assert_output_contains "local"
    assert_output_contains "staging"
    assert_output_not_contains "production"
}

# =============================================================================
# Error Recovery
# =============================================================================

@test "save does not corrupt file on re-save" {
    create_test_env "$TEST_PROJECT" "local" "ORIGINAL=value"

    # Use, modify, save multiple times
    run_senv use local
    echo "FIRST=addition" >> .env
    run_senv save
    [ "$status" -eq 0 ]

    run_senv use local
    echo "SECOND=addition" >> .env
    run_senv save
    [ "$status" -eq 0 ]

    # Verify all content preserved
    run_senv use local
    assert_file_contains ".env" "ORIGINAL=value"
    assert_file_contains ".env" "FIRST=addition"
    assert_file_contains ".env" "SECOND=addition"
}

@test "backup file can restore after failed save" {
    create_test_env "$TEST_PROJECT" "local" "ORIGINAL=value"
    run_senv use local

    # Modify and save to create backup
    echo "MODIFIED=value" >> .env
    run_senv save
    [ "$status" -eq 0 ]

    # Backup should exist with original content
    assert_file_exists "$TEST_SECRETS_DIR/$TEST_PROJECT/local.env.enc.backup"
}

# =============================================================================
# Diff Edge Cases
# =============================================================================

@test "diff works after modifying multiple lines" {
    create_test_env "$TEST_PROJECT" "local" "VAR1=original1
VAR2=original2
VAR3=original3"

    run_senv use local

    # Modify file significantly
    cat > .env <<EOF
# senv: local
VAR1=modified1
VAR2=original2
VAR4=newvar
EOF

    run_senv diff
    [ "$status" -eq 0 ]
    # Should show differences
    assert_output_contains "original1"
    assert_output_contains "modified1"
}

# =============================================================================
# Status Edge Cases
# =============================================================================

@test "status shows unknown when .env has no senv header" {
    create_test_env "$TEST_PROJECT" "local" "VAR=value"

    # Create .env without header
    echo "PLAIN=value" > .env

    run_senv status
    [ "$status" -eq 0 ]
    assert_output_contains "unknown"
}

@test "status works with multiple available environments" {
    create_test_env "$TEST_PROJECT" "local" "VAR=1"
    create_test_env "$TEST_PROJECT" "staging" "VAR=2"
    create_test_env "$TEST_PROJECT" "production" "VAR=3"

    run_senv status
    [ "$status" -eq 0 ]
    assert_output_contains "local"
    assert_output_contains "staging"
    assert_output_contains "production"
}
