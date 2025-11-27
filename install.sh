#!/usr/bin/env bash
set -euo pipefail

# senv installer - Creates symlink to ~/.local/bin

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"
SENV_PATH="$SCRIPT_DIR/senv"

echo "senv installer"
echo "=============="
echo

# Check senv exists
if [[ ! -f "$SENV_PATH" ]]; then
    echo "Error: senv script not found at $SENV_PATH"
    exit 1
fi

# Create install directory if needed
if [[ ! -d "$INSTALL_DIR" ]]; then
    echo "Creating $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
fi

# Check if already installed
if [[ -L "$INSTALL_DIR/senv" ]]; then
    current=$(readlink "$INSTALL_DIR/senv")
    if [[ "$current" == "$SENV_PATH" ]]; then
        echo "Already installed: $INSTALL_DIR/senv → $SENV_PATH"
        exit 0
    else
        echo "Updating symlink (was: $current)"
        rm "$INSTALL_DIR/senv"
    fi
elif [[ -f "$INSTALL_DIR/senv" ]]; then
    echo "Warning: $INSTALL_DIR/senv exists and is not a symlink"
    read -rp "Replace it? [y/N] " confirm
    [[ "$confirm" != [yY] ]] && exit 1
    rm "$INSTALL_DIR/senv"
fi

# Create symlink
ln -s "$SENV_PATH" "$INSTALL_DIR/senv"
echo "Installed: $INSTALL_DIR/senv → $SENV_PATH"

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
