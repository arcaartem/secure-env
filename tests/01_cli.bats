#!/usr/bin/env bats
# Tests for CLI argument parsing and help

load test_helper

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

# =============================================================================
# Help and Version
# =============================================================================

@test "help command shows usage" {
    run_senv help
    [ "$status" -eq 0 ]
    assert_output_contains "senv"
    assert_output_contains "Usage:"
    assert_output_contains "Commands:"
}

@test "--help flag shows usage" {
    run_senv --help
    [ "$status" -eq 0 ]
    assert_output_contains "Usage:"
}

@test "-h flag shows usage" {
    run_senv -h
    [ "$status" -eq 0 ]
    assert_output_contains "Usage:"
}

@test "--version flag shows version" {
    run_senv --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "-V flag shows version" {
    run_senv -V
    [ "$status" -eq 0 ]
    [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "no arguments shows error requiring subcommand" {
    run_senv
    [ "$status" -ne 0 ]
}

@test "unknown command shows error" {
    run_senv unknown_command
    [ "$status" -ne 0 ]
}

@test "unknown option shows error" {
    run_senv --unknown-option
    [ "$status" -ne 0 ]
}

# =============================================================================
# Help shows commands
# =============================================================================

@test "help shows init command" {
    run_senv help
    [ "$status" -eq 0 ]
    assert_output_contains "init"
}

@test "help shows use command" {
    run_senv help
    [ "$status" -eq 0 ]
    assert_output_contains "use"
}

@test "help shows edit command" {
    run_senv help
    [ "$status" -eq 0 ]
    assert_output_contains "edit"
}

@test "help shows save command" {
    run_senv help
    [ "$status" -eq 0 ]
    assert_output_contains "save"
}

@test "help shows list command" {
    run_senv help
    [ "$status" -eq 0 ]
    assert_output_contains "list"
}

@test "help shows diff command" {
    run_senv help
    [ "$status" -eq 0 ]
    assert_output_contains "diff"
}

@test "help shows delete command" {
    run_senv help
    [ "$status" -eq 0 ]
    assert_output_contains "delete"
}

@test "help shows status command" {
    run_senv help
    [ "$status" -eq 0 ]
    assert_output_contains "status"
}

@test "help shows repo command" {
    run_senv help
    [ "$status" -eq 0 ]
    assert_output_contains "repo"
}

@test "help shows export command" {
    run_senv help
    [ "$status" -eq 0 ]
    assert_output_contains "export"
}

@test "help shows import command" {
    run_senv help
    [ "$status" -eq 0 ]
    assert_output_contains "import"
}

# =============================================================================
# Global options shown in help
# =============================================================================

@test "help shows -p/--project option" {
    run_senv --help
    [ "$status" -eq 0 ]
    assert_output_contains "--project"
}

@test "help shows -s/--secrets-path option" {
    run_senv --help
    [ "$status" -eq 0 ]
    assert_output_contains "--secrets-path"
}
