#!/usr/bin/env bash
set -euo pipefail

# senv installer - Builds and installs the Rust binary

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"

echo "senv installer"
echo "=============="
echo

# Check for Cargo
if ! command -v cargo &>/dev/null; then
    echo "Error: cargo not found. Please install Rust first:"
    echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 1
fi

# Check for required dependencies
missing_deps=()
command -v sops &>/dev/null || missing_deps+=("sops")
if ! command -v age &>/dev/null && ! command -v gpg &>/dev/null; then
    missing_deps+=("age (or gpg)")
fi

if [[ ${#missing_deps[@]} -gt 0 ]]; then
    echo "Warning: Missing dependencies: ${missing_deps[*]}"
    echo "Install with: brew install sops age"
    echo
fi

# Build release binary
echo "Building senv..."
cd "$SCRIPT_DIR"
cargo build --release --quiet

if [[ ! -f "$SCRIPT_DIR/target/release/senv" ]]; then
    echo "Error: Build failed - binary not found"
    exit 1
fi

echo "Build complete."
echo

# Create install directory if needed
if [[ ! -d "$INSTALL_DIR" ]]; then
    echo "Creating $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
fi

# Check if already installed
if [[ -f "$INSTALL_DIR/senv" ]]; then
    echo "Replacing existing installation..."
    rm "$INSTALL_DIR/senv"
fi

# Copy binary
cp "$SCRIPT_DIR/target/release/senv" "$INSTALL_DIR/senv"
chmod +x "$INSTALL_DIR/senv"
echo "Installed: $INSTALL_DIR/senv"

# Check PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo
    echo "Note: $INSTALL_DIR is not in your PATH"
    echo "Add this to your shell config (~/.bashrc, ~/.zshrc, etc.):"
    echo
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo
fi

echo
echo "Done! Run 'senv init' to get started."
