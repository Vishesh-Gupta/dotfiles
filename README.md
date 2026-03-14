# Dotfiles

[![Quality and Security Checks](https://github.com/Vishesh-Gupta/dotfiles/actions/workflows/quality-and-security.yml/badge.svg)](https://github.com/Vishesh-Gupta/dotfiles/actions/workflows/quality-and-security.yml)

Professional, reproducible macOS dotfiles focused on a modular Zsh setup.

## Scope

This repository intentionally tracks:

- Zsh shell configuration (`.zshrc`, `.zshrc.d`, `.zprofile`, `.zshenv`)
- Compatibility shell files (`.profile`, `.bashrc`)
- Terminal tool config (`.config/ghostty`, `.config/zellij`)
- Bootstrap automation (`scripts/install.sh`, `scripts/bootstrap.sh`)

This repository intentionally does **not** track machine-specific editor state (for example Cursor user settings).

## Repository Layout

- `.zshrc`: minimal entrypoint that loads modular config
- `.zshrc.d/`: split config by concern (`env`, `tools`, `aliases`, `functions`, `startup`)
- `.zprofile`: login-shell initialization
- `.zshenv`: environment required in all zsh contexts
- `.config/ghostty/config.toml`: Ghostty settings
- `.config/zellij/config.kdl`: Zellij settings (tmux alternative)
- `scripts/install.sh`: idempotent local installer
- `scripts/bootstrap.sh`: one-liner bootstrap entrypoint

## Prerequisites

- macOS (Darwin)
- internet connectivity for package and plugin installation

## Installation

### Option 1: Local clone (recommended for maintenance)

```sh
git clone https://github.com/Vishesh-Gupta/dotfiles.git "$HOME/personal/dotfiles"
cd "$HOME/personal/dotfiles"
./scripts/install.sh
```

### Option 2: One-liner remote bootstrap (no gist, no manual clone)

```sh
curl -fsSL "https://raw.githubusercontent.com/Vishesh-Gupta/dotfiles/main/scripts/bootstrap.sh" | bash
```

By default, `bootstrap.sh` downloads this repository archive from GitHub and installs from that temporary copy.

Override repo/ref at runtime:

```sh
DOTFILES_REPO="<owner>/<repo>" DOTFILES_REF="<branch-or-tag>" \
  curl -fsSL "https://raw.githubusercontent.com/Vishesh-Gupta/dotfiles/main/scripts/bootstrap.sh" | bash
```

Preview only (no changes):

```sh
curl -fsSL "https://raw.githubusercontent.com/Vishesh-Gupta/dotfiles/main/scripts/bootstrap.sh" | bash -s -- --dry-run
```

## Installer Behavior

`scripts/install.sh` is idempotent and safe to re-run:

- installs Homebrew only when missing
- installs missing formulas/casks only
- clones missing Zsh framework/plugins only
- updates links or files deterministically

### Install modes

```sh
./scripts/install.sh --link
```

- default mode
- symlinks files from the repo into `$HOME`
- ideal when keeping the repo on disk

```sh
./scripts/install.sh --copy --self-destruct
```

- copies files into `$HOME` (no symlink dependency)
- removes the cloned dotfiles repository after successful setup
- useful for ephemeral bootstrap flows

```sh
./scripts/install.sh --dry-run --copy --self-destruct
```

- prints planned actions without making changes

## Testing

Run the script test suite:

```sh
./scripts/test.sh
```

The suite validates:

- shell syntax for installer/bootstrap scripts
- CLI option guards and help text
- dry-run behavior for both `install.sh` and `bootstrap.sh`

Run the security scan:

```sh
./scripts/security-scan.sh
```

The security scan includes:

- `shellcheck` static analysis
- advisory pattern scan for potentially risky shell primitives (for manual review)

## Installed Dependencies

Homebrew formulas:

- `bat`
- `eza`
- `fzf`
- `gh`
- `git`
- `glow`
- `neofetch`
- `ripgrep`
- `zellij`
- `zoxide`

Homebrew casks:

- `ghostty`

Zsh ecosystem:

- `oh-my-zsh`
- `powerlevel10k`
- `zsh-autosuggestions`
- `zsh-syntax-highlighting`

## Usage

- open a new terminal, or run:

```sh
exec zsh
```

- launch multiplexer:

```sh
zellij
```

## Maintenance

- rerun setup anytime after pulling updates:

```sh
cd "$HOME/personal/dotfiles"
git pull
./scripts/install.sh
```

## Security Notes

- Review remote scripts before running `curl | bash`.
- Keep secrets out of this repository.
- Prefer machine-local files for host-specific settings.
