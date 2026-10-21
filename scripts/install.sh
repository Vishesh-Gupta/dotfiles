#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_MODE="link"
SELF_DESTRUCT=0
DRY_RUN=0
INSTALL_PACKAGES=1
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

if [[ "${DOTFILES_SKIP_OS_CHECK:-0}" != "1" ]] && [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This bootstrap script currently supports macOS only."
  exit 1
fi

usage() {
  cat <<'EOF'
Usage: ./scripts/install.sh [--link|--copy] [--self-destruct] [--no-packages] [--dry-run]

Options:
  --link            Symlink files from repo into $HOME (default)
  --copy            Copy files into $HOME (needed for self-destruct mode)
  --self-destruct   Delete the cloned repo after successful install
  --no-packages     Skip Homebrew and Zsh plugin installs; only sync dotfiles
  --dry-run         Print actions without making changes
  -h, --help        Show help
EOF
}

run_cmd() {
  if (( DRY_RUN )); then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

while (( $# > 0 )); do
  case "$1" in
    --link)
      INSTALL_MODE="link"
      ;;
    --copy)
      INSTALL_MODE="copy"
      ;;
    --self-destruct)
      SELF_DESTRUCT=1
      ;;
    --no-packages)
      INSTALL_PACKAGES=0
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

if (( SELF_DESTRUCT )) && [[ "$INSTALL_MODE" != "copy" ]]; then
  echo "--self-destruct requires --copy (symlinks would break after repo deletion)."
  exit 1
fi

ensure_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi

  if (( DRY_RUN )); then
    echo "[dry-run] Homebrew is missing; would install Homebrew."
    echo "[dry-run] /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    return 0
  fi

  echo "Homebrew not found. Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    echo "Homebrew installed but brew binary not found on PATH."
    exit 1
  fi
}

install_brewfile() {
  echo "[brew] bundle $REPO_ROOT/Brewfile"
  run_cmd brew bundle --no-upgrade --file "$REPO_ROOT/Brewfile"
}

# Rust toolchain via the official rustup installer. PATH is managed by the
# dotfiles (~/.zshenv sources ~/.cargo/env), so rustup must not edit rc files.
install_rust() {
  if command -v rustup >/dev/null 2>&1 || [[ -x "$HOME/.cargo/bin/rustup" ]]; then
    echo "[skip] rustup already installed"
    return 0
  fi

  echo "[install] rustup (stable toolchain + rust-analyzer)"
  if (( DRY_RUN )); then
    echo "[dry-run] curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile default --component rust-analyzer"
    return 0
  fi
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile default --component rust-analyzer
}

clone_if_missing() {
  local repo="$1"
  local target="$2"
  if [[ -d "$target" ]]; then
    echo "[skip] already exists: $target"
  else
    echo "[clone] $repo -> $target"
    run_cmd git clone --depth=1 "$repo" "$target"
  fi
}

# Move an existing file out of the way unless it already matches the repo.
backup_existing() {
  local src="$1"
  local dst="$2"

  if [[ ! -e "$dst" && ! -L "$dst" ]]; then
    return 0
  fi
  if [[ -L "$dst" ]] && [[ "$(readlink "$dst")" == "$src" ]]; then
    return 0
  fi
  if [[ ! -L "$dst" ]] && diff -rq "$src" "$dst" >/dev/null 2>&1; then
    return 0
  fi

  local backup="$BACKUP_DIR/${dst#"$HOME"/}"
  run_cmd mkdir -p "$(dirname "$backup")"
  run_cmd mv "$dst" "$backup"
  echo "[backup] $dst -> $backup"
}

link_file() {
  local src="$1"
  local dst="$2"
  run_cmd mkdir -p "$(dirname "$dst")"
  # ln -sfn would create the link inside an existing real directory.
  if [[ -d "$dst" && ! -L "$dst" ]]; then
    run_cmd rm -rf "$dst"
  fi
  run_cmd ln -sfn "$src" "$dst"
  echo "[link] $dst -> $src"
}

copy_item() {
  local src="$1"
  local dst="$2"
  run_cmd mkdir -p "$(dirname "$dst")"

  # A symlink left by --link mode would make cp copy the file onto itself.
  if [[ -L "$dst" ]]; then
    run_cmd rm -f "$dst"
  fi

  if [[ -d "$src" ]]; then
    run_cmd rm -rf "$dst"
    run_cmd cp -R "$src" "$dst"
  else
    run_cmd cp -f "$src" "$dst"
  fi

  echo "[copy] $dst <- $src"
}

sync_item() {
  local src="$1"
  local dst="$2"
  backup_existing "$src" "$dst"
  if [[ "$INSTALL_MODE" == "copy" ]]; then
    copy_item "$src" "$dst"
  else
    link_file "$src" "$dst"
  fi
}

if (( INSTALL_PACKAGES )); then
  ensure_homebrew
  install_brewfile
  install_rust

  clone_if_missing "https://github.com/ohmyzsh/ohmyzsh.git" "$HOME/.oh-my-zsh"
  clone_if_missing "https://github.com/Aloxaf/fzf-tab.git" "$HOME/.oh-my-zsh/custom/plugins/fzf-tab"
  clone_if_missing "https://github.com/zsh-users/zsh-autosuggestions.git" "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
  clone_if_missing "https://github.com/zsh-users/zsh-syntax-highlighting.git" "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
fi

sync_item "$REPO_ROOT/.zshrc" "$HOME/.zshrc"
sync_item "$REPO_ROOT/.zprofile" "$HOME/.zprofile"
sync_item "$REPO_ROOT/.zshenv" "$HOME/.zshenv"
sync_item "$REPO_ROOT/.profile" "$HOME/.profile"
sync_item "$REPO_ROOT/.bashrc" "$HOME/.bashrc"
sync_item "$REPO_ROOT/.zshrc.d" "$HOME/.zshrc.d"

sync_item "$REPO_ROOT/.config/ghostty/config" "$HOME/.config/ghostty/config"
sync_item "$REPO_ROOT/.config/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
sync_item "$REPO_ROOT/.config/starship.toml" "$HOME/.config/starship.toml"
sync_item "$REPO_ROOT/.config/git/config" "$HOME/.config/git/config"
sync_item "$REPO_ROOT/.config/git/ignore" "$HOME/.config/git/ignore"
sync_item "$REPO_ROOT/.config/mise/config.toml" "$HOME/.config/mise/config.toml"

if (( SELF_DESTRUCT )); then
  case "$REPO_ROOT" in
    ""|"/"|"$HOME")
      echo "Refusing to delete unsafe path: '$REPO_ROOT'"
      exit 1
      ;;
  esac
  run_cmd rm -rf "$REPO_ROOT"
  echo "[cleanup] removed repo: $REPO_ROOT"
fi

echo ""
if (( DRY_RUN )); then
  echo "Dry run complete. No changes were made."
else
  echo "Bootstrap complete."
fi
echo "Open a new terminal (or run: exec zsh) to load updated config."
