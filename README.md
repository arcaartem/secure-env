# senv - Secure Environment File Manager

A CLI tool that transparently manages encrypted `.env` files using SOPS and GPG. Projects remain unaware of the secrets repository - `senv` handles encryption/decryption and writes plain `.env` files that direnv and Python can consume.

## Prerequisites

- [SOPS](https://github.com/getsops/sops) - for encryption
- [GPG](https://gnupg.org/) - for key management
- [direnv](https://direnv.net/) - optional, for auto-loading env vars

```bash
# macOS
brew install sops gnupg direnv

# Create a GPG key if you don't have one
gpg --full-generate-key
```

## Installation

```bash
git clone <this-repo> ~/source/secure-env
cd ~/source/secure-env
./install.sh
```

This creates a symlink: `~/.local/bin/senv` → `<repo>/senv`

## Quick Start

```bash
# 1. Initialize senv (one-time setup)
senv init

# 2. Create an environment for your project
cd ~/projects/myapp
senv edit local          # Opens $EDITOR to create local.env.enc

# 3. Activate the environment
senv use local           # Decrypts → .env

# 4. Set up direnv (optional, for auto-loading)
echo "dotenv" > .envrc
direnv allow

# 5. After modifying .env, save it back
senv save                # Encrypts .env → local.env.enc
```

## Commands

| Command | Description |
|---------|-------------|
| `senv init` | Initialize senv (create config and secrets repo) |
| `senv use <env>` | Decrypt environment and write `.env` |
| `senv edit <env>` | Edit encrypted environment file in `$EDITOR` |
| `senv save` | Encrypt current `.env` back to secrets repo |
| `senv list` | List available environments for current project |
| `senv diff [env]` | Show diff between local `.env` and stored version |
| `senv status` | Show current project status |
| `senv help` | Show help message |

## How It Works

### Architecture

```
~/.config/senv/
├── config.yaml          # Global configuration
└── secrets/             # Git repo for encrypted files
    ├── .sops.yaml       # SOPS configuration
    ├── myapp/
    │   ├── local.env.enc
    │   ├── staging.env.enc
    │   └── production.env.enc
    └── another-project/
        └── local.env.enc

~/projects/myapp/
├── .env                 # ← Written by `senv use local` (gitignored)
├── .envrc               # ← direnv: `dotenv`
└── ...
```

### Project Identification

`senv` uses the current directory name as the project identifier. When you run `senv use staging` in `~/projects/myapp/`, it looks for:

```
~/.config/senv/secrets/myapp/staging.env.enc
```

### Encryption

Files are encrypted using SOPS with your GPG key. Only `.env.enc` files are stored in the secrets repository - plain `.env` files should always be gitignored.

## Workflow Examples

### Daily Development

```bash
cd ~/projects/myapp

# Start of day - activate environment
senv use local

# Work on your project...
# Environment variables are loaded via direnv

# Made changes to .env? Save them
senv save

# Switch to staging to test something
senv use staging
```

### Adding a New Project

```bash
cd ~/projects/newproject

# Create environments
senv edit local
senv edit staging
senv edit production

# Activate local
senv use local

# Set up direnv
echo "dotenv" > .envrc
direnv allow
```

### Checking for Changes

```bash
# See what's different from stored version
senv diff

# See status
senv status
```

### Syncing Secrets Across Machines

The secrets repository at `~/.config/senv/secrets/` is a git repo. You can push it to a private remote for backup and sync:

```bash
cd ~/.config/senv/secrets
git remote add origin git@github.com:you/secrets.git
git push -u origin main

# On another machine after senv init:
cd ~/.config/senv/secrets
git remote add origin git@github.com:you/secrets.git
git pull origin main
```

## Security Notes

1. **Never commit `.env` files** - Always add `.env` to your project's `.gitignore`
2. **Only commit `.env.enc` files** - These are encrypted and safe to store
3. **Protect your GPG key** - The security depends on your GPG key passphrase
4. **Private secrets repo** - If syncing to a remote, use a private repository

## Configuration

Config file: `~/.config/senv/config.yaml`

```yaml
secrets_path: ~/.config/senv/secrets
gpg_key: YOUR_GPG_KEY_ID
```

## Troubleshooting

### "GPG decryption failed"

Make sure your GPG agent is running and has your key unlocked:

```bash
gpg --list-secret-keys
echo "test" | gpg -e -r YOUR_KEY_ID | gpg -d
```

### "Environment not found"

Check that the project name matches your directory:

```bash
senv status  # Shows project name and available environments
```

### direnv not loading

```bash
# Check .envrc exists
cat .envrc  # Should contain: dotenv

# Allow direnv
direnv allow
```

## License

MIT
