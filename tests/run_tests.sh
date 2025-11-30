#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

err() { echo -e "${RED}error:${NC} $*" >&2; }
info() { echo -e "${BLUE}info:${NC} $*"; }
success() { echo -e "${GREEN}success:${NC} $*"; }
warn() { echo -e "${YELLOW}warning:${NC} $*"; }

# Check dependencies
check_dependencies() {
    local missing=()

    if ! command -v bats &>/dev/null; then
        missing+=("bats")
    fi

    if ! command -v gpg &>/dev/null; then
        missing+=("gpg")
    fi

    if ! command -v sops &>/dev/null; then
        missing+=("sops")
    fi

    if ! command -v git &>/dev/null; then
        missing+=("git")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        err "Missing dependencies: ${missing[*]}"
        echo ""
        echo "Install instructions:"
        echo "  macOS:   brew install bats-core gnupg sops git"
        echo "  Ubuntu:  apt install bats gnupg git && brew install sops"
        echo ""
        exit 1
    fi
}

# Show usage
usage() {
    cat <<EOF
Usage: $0 [options] [test_file...]

Run senv test suite using BATS.

Options:
    -h, --help      Show this help message
    -v, --verbose   Show verbose output (bats --verbose-run)
    -t, --tap       Output in TAP format
    -f, --filter    Filter tests by name pattern
    --no-color      Disable colored output

Examples:
    $0                      # Run all tests
    $0 01_cli.bats          # Run specific test file
    $0 -v                   # Run with verbose output
    $0 -f "export"          # Run tests matching "export"

Test files:
    01_cli.bats             CLI argument parsing and help
    02_init.bats            Init command
    03_project_env.bats     Project name and secrets path resolution
    04_use_edit_save.bats   Use, edit, and save commands
    05_list_status_diff.bats List, status, and diff commands
    06_export.bats          Export command
    07_import.bats          Import command
    08_delete.bats          Delete command
    09_repo.bats            Repo command
EOF
}

# Parse arguments
VERBOSE=""
TAP=""
FILTER=""
NO_COLOR=""
TEST_FILES=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE="--verbose-run"
            shift
            ;;
        -t|--tap)
            TAP="--tap"
            shift
            ;;
        -f|--filter)
            FILTER="--filter $2"
            shift 2
            ;;
        --no-color)
            NO_COLOR="--no-color"
            shift
            ;;
        -*)
            err "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            TEST_FILES+=("$1")
            shift
            ;;
    esac
done

# Main
main() {
    info "Checking dependencies..."
    check_dependencies
    success "All dependencies found"
    echo ""

    info "Running senv test suite"
    echo "========================================"
    echo ""

    # Build bats command
    local bats_cmd="bats"
    [[ -n "$VERBOSE" ]] && bats_cmd="$bats_cmd $VERBOSE"
    [[ -n "$TAP" ]] && bats_cmd="$bats_cmd $TAP"
    [[ -n "$FILTER" ]] && bats_cmd="$bats_cmd $FILTER"
    [[ -n "$NO_COLOR" ]] && bats_cmd="$bats_cmd $NO_COLOR"

    # Run tests
    if [[ ${#TEST_FILES[@]} -gt 0 ]]; then
        # Run specific test files
        $bats_cmd "${TEST_FILES[@]}"
    else
        # Run all test files in order
        $bats_cmd *.bats
    fi

    local exit_code=$?
    echo ""
    if [[ $exit_code -eq 0 ]]; then
        success "All tests passed!"
    else
        err "Some tests failed"
    fi

    return $exit_code
}

main "$@"
