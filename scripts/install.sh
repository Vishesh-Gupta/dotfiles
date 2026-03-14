#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_MODE="link"
SELF_DESTRUCT=0
DRY_RUN=0

if [[ "${DOTFILES_SKIP_OS_CHECK:-0}" != "1" ]] && [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This bootstrap script currently supports macOS only."
  exit 1
fi

usage() {
  cat <<'EOF'
Usage: ./scripts/install.sh [--link|--copy] [--self-destruct] [--dry-run]

Options:
  --link            Symlink files from repo into $HOME (default)
  --copy            Copy files into $HOME (needed for self-destruct mode)
  --self-destruct   Delete the cloned repo after successful install
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

install_formula_if_missing() {
  local formula="$1"

  if (( DRY_RUN )); then
    echo "[dry-run] ensure formula installed: $formula"
    return 0
  fi

  if brew list --formula "$formula" >/dev/null 2>&1; then
    echo "[skip] formula already installed: $formula"
  else
    echo "[install] formula: $formula"
    run_cmd brew install "$formula"
  fi
}

install_cask_if_missing() {
  local cask="$1"

  if (( DRY_RUN )); then
    echo "[dry-run] ensure cask installed: $cask"
    return 0
  fi

  if brew list --cask "$cask" >/dev/null 2>&1; then
    echo "[skip] cask already installed: $cask"
  else
    echo "[install] cask: $cask"
    run_cmd brew install --cask "$cask"
  fi
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

link_file() {
  local src="$1"
  local dst="$2"
  run_cmd mkdir -p "$(dirname "$dst")"
  run_cmd ln -sfn "$src" "$dst"
  echo "[link] $dst -> $src"
}

copy_item() {
  local src="$1"
  local dst="$2"
  run_cmd mkdir -p "$(dirname "$dst")"

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
  if [[ "$INSTALL_MODE" == "copy" ]]; then
    copy_item "$src" "$dst"
  else
    link_file "$src" "$dst"
  fi
}

ensure_homebrew

formulas=(
  bat
  eza
  fzf
  gh
  git
  glow
  neofetch
  ripgrep
  zellij
  zoxide
)

for formula in "${formulas[@]}"; do
  install_formula_if_missing "$formula"
done

casks=(
  ghostty
)

for cask in "${casks[@]}"; do
  install_cask_if_missing "$cask"
done

clone_if_missing "https://github.com/ohmyzsh/ohmyzsh.git" "$HOME/.oh-my-zsh"
clone_if_missing "https://github.com/romkatv/powerlevel10k.git" "$HOME/powerlevel10k"
clone_if_missing "https://github.com/zsh-users/zsh-autosuggestions.git" "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
clone_if_missing "https://github.com/zsh-users/zsh-syntax-highlighting.git" "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"

sync_item "$REPO_ROOT/.zshrc" "$HOME/.zshrc"
sync_item "$REPO_ROOT/.zprofile" "$HOME/.zprofile"
sync_item "$REPO_ROOT/.zshenv" "$HOME/.zshenv"
sync_item "$REPO_ROOT/.profile" "$HOME/.profile"
sync_item "$REPO_ROOT/.bashrc" "$HOME/.bashrc"
sync_item "$REPO_ROOT/.zshrc.d" "$HOME/.zshrc.d"

sync_item "$REPO_ROOT/.config/ghostty/config.toml" "$HOME/.config/ghostty/config.toml"
sync_item "$REPO_ROOT/.config/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"

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
