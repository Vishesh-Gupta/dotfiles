# Dotfiles

[![Quality and Security Checks](https://github.com/Vishesh-Gupta/dotfiles/actions/workflows/quality-and-security.yml/badge.svg)](https://github.com/Vishesh-Gupta/dotfiles/actions/workflows/quality-and-security.yml)

Professional, reproducible macOS dotfiles focused on a modular Zsh setup.

## Scope

This repository intentionally tracks:

- Zsh shell configuration (`.zshrc`, `.zshrc.d`, `.zprofile`, `.zshenv`)
- Compatibility shell files (`.profile`, `.bashrc`)
- Terminal tool config (`.config/ghostty`, `.config/zellij`, `.config/starship.toml`)
- Git defaults and global ignore (`.config/git/`), mise settings (`.config/mise/`)
- Homebrew packages (`Brewfile`)
- Bootstrap automation (`scripts/install.sh`, `scripts/bootstrap.sh`)

This repository intentionally does **not** track machine-specific editor state (for example Cursor user settings).

## Repository Layout

- `.zshrc`: minimal entrypoint that loads modular config
- `.zshrc.d/`: split config by concern (`env`, `fzf`, `oh-my-zsh`, `history`, `prompt`, `tools`, `functions`, `aliases`)
- `~/.zshrc.local` (not tracked): optional machine-specific overrides, sourced last
- `.zprofile`: login-shell initialization
- `.zshenv`: environment required in all zsh contexts
- `.config/ghostty/config`: Ghostty settings
- `.config/zellij/config.kdl`: Zellij settings (tmux alternative)
- `.config/starship.toml`: Starship prompt settings
- `.config/git/config`: shared git defaults (delta pager, zdiff3, rebase on pull, ...)
- `.config/git/ignore`: global gitignore
- `.config/mise/config.toml`: global mise settings
- `Brewfile`: Homebrew formulas and casks
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
- installs missing `Brewfile` packages only (`brew bundle --no-upgrade`)
- clones missing Zsh framework/plugins only
- backs up existing dotfiles that differ from the repo to `~/.dotfiles-backup/<timestamp>/` before replacing them
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
./scripts/install.sh --no-packages
```

- skips Homebrew and plugin installs; only syncs dotfiles

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

- shell syntax for installer/bootstrap scripts and zsh config files
- CLI option guards and help text
- dry-run behavior for both `install.sh` and `bootstrap.sh`
- a real link-mode install into a temporary `$HOME` (backups, idempotency)
- an interactive zsh startup with no errors

Run the security scan:

```sh
./scripts/security-scan.sh
```

The security scan includes:

- `shellcheck` static analysis
- advisory pattern scan for potentially risky shell primitives (for manual review)

## Installed Dependencies

Homebrew packages are listed in [`Brewfile`](Brewfile). Install or refresh them on their own with:

```sh
brew bundle --file Brewfile
```

Rust is installed with the official [rustup](https://rustup.rs) installer (stable toolchain, `clippy`, `rustfmt`, `rust-analyzer`). It runs with `--no-modify-path`: `~/.zshenv` sources `~/.cargo/env` instead.

Zsh ecosystem:

- `oh-my-zsh`
- `fzf-tab`
- `zsh-autosuggestions`
- `zsh-syntax-highlighting`
- prompt: [`starship`](https://starship.rs) (from `Brewfile`)

## What's Configured

- **fzf**: uses `fd` (respects `.gitignore`, includes dotfiles). `Ctrl-T` finds files with a `bat` preview, `Alt-C` jumps to directories with an `eza` tree preview, and `Ctrl-R` searches history. `**<Tab>` triggers fuzzy path completion.
- **fzf-tab**: every Tab completion opens in fzf; `cd <Tab>` previews directory contents. Use `<` and `>` to switch completion groups.
- **eza**: `ls`, `la`, `ll` (git status, relative times), `lt` (tree, respects `.gitignore`).
- **zoxide**: `cd` learns your directories; `cd foo` jumps to the best match.
- **git + delta**: highlighted side-by-side-capable diffs with line numbers, `n`/`N` to jump between files, histogram diffs, `zdiff3` conflicts, `pull --rebase` with autostash, auto upstream on first push, pruning on fetch, rerere. Keep your name and email in `~/.gitconfig`.
- **mise**: per-project language versions from `mise.toml`, `.nvmrc`, `.python-version`, `.go-version`. Example: `mise use node@lts`.
- **uv**: Python tooling, for example `uv tool install ruff` instead of pipx.
- **History**: 100k entries, shared across shells, timestamps, no duplicates, and commands starting with a space are not saved.

## Shell Helpers

- `view <file>`: syntax-highlighted file viewer (`bat`), renders Markdown with `glow`
- `git-cleanup` / `gcleanup`: deletes local branches whose upstream was deleted, after confirmation
- `tfinit`: `terraform init` plus a multi-platform provider lock
- `bench-shell [runs]`: measures interactive zsh startup time

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
