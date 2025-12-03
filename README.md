# senv - Secure Environment File Manager

A CLI tool for managing encrypted `.env` files using [SOPS](https://github.com/getsops/sops). Supports both **age** and **GPG** encryption backends.

## Features

- Encrypt/decrypt `.env` files with SOPS (age or GPG)
- Per-project, per-environment secrets (local, staging, production)
- Safe atomic operations - no data loss on encryption/decryption failures
- Import/export for easy migration
- Works with [direnv](https://direnv.net/) for automatic loading

## Installation

```bash
# Install dependencies (macOS)
brew install sops age  # or: brew install sops gnupg

# Install senv
git clone https://github.com/yourusername/secure-env.git
cd secure-env
./install.sh
```

## Quick Start

```bash
# Initialize (choose age or GPG backend)
senv init

# Create an environment for your project
cd ~/projects/myapp
senv edit local        # Opens $EDITOR

# Activate the environment
senv use local         # Decrypts to .env

# After modifying .env, save it back
senv save              # Encrypts .env
```

## Commands

| Command | Description |
|---------|-------------|
| `senv init` | Initialize senv (interactive backend selection) |
| `senv use <env>` | Decrypt environment to `.env` |
| `senv edit <env>` | Edit encrypted environment in `$EDITOR` |
| `senv save` | Encrypt `.env` back to secrets repo |
| `senv list` | List available environments |
| `senv diff [env]` | Show diff between local and stored |
| `senv status` | Show current project status |
| `senv export` | Export all environments as `.env.<name>` files |
| `senv import` | Import `.env.<name>` files into secrets repo |
| `senv delete <env>` | Delete an environment |
| `senv repo` | Print secrets repo path |

## Options

```bash
senv -p <project>       # Override project name (default: current directory)
senv -s <path>          # Override secrets path (default: ~/.local/share/senv)
```

Environment variables: `SENV_PROJECT`, `SENV_SECRETS_PATH`

## How It Works

```
~/.local/share/senv/           # Secrets repository (git-tracked)
├── .sops.yaml                 # SOPS encryption config
├── myapp/
│   ├── local.env.enc
│   └── production.env.enc
└── another-project/
    └── local.env.enc

~/projects/myapp/
├── .env                       # Written by `senv use` (gitignored)
└── .envrc                     # Optional: direnv with `dotenv`
```

Project name defaults to current directory. Encrypted files are stored in the secrets repo, organized by project.

## Syncing Across Machines

The secrets repo is git-initialized. Push to a private remote for backup/sync:

```bash
cd "$(senv repo)"
git remote add origin git@github.com:you/secrets.git
git push -u origin main
```

## Security

- Never commit `.env` files - add to `.gitignore`
- Only `.env.enc` files are stored (encrypted)
- Protect your age key or GPG passphrase
- Use a private repository if syncing secrets

## License

MIT
