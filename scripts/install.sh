#!/usr/bin/env bash
#
# One installer for macOS and Debian/Ubuntu. System packages come from
# Homebrew (macOS) or apt (Debian); every CLI tool, language runtime and AI
# agent comes from mise (.config/mise/config.toml) so both platforms get the
# same versions.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_MODE="link"
SELF_DESTRUCT=0
DRY_RUN=0
INSTALL_PACKAGES=1
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
MISE_BIN="$HOME/.local/bin/mise"

APT_PACKAGES=(
  build-essential  # native npm modules (e.g. gemini-cli's node-pty)
  ca-certificates
  curl
  git
  unzip
  zsh
)

detect_platform() {
  case "$(uname -s)" in
    Darwin)
      echo "macos"
      ;;
    Linux)
      local id="" id_like=""
      if [[ -r /etc/os-release ]]; then
        id="$(. /etc/os-release && echo "${ID:-}")"
        id_like="$(. /etc/os-release && echo "${ID_LIKE:-}")"
      fi
      if [[ " $id $id_like " == *" debian "* ]]; then
        echo "debian"
      else
        echo "unsupported"
      fi
      ;;
    *)
      echo "unsupported"
      ;;
  esac
}

PLATFORM="$(detect_platform)"
if [[ "$PLATFORM" == "unsupported" ]] && [[ "${DOTFILES_SKIP_OS_CHECK:-0}" != "1" ]]; then
  echo "Supported platforms: macOS and Debian-based Linux (Debian, Ubuntu, ...)."
  exit 1
fi

usage() {
  cat <<'EOF'
Usage: ./scripts/install.sh [--link|--copy] [--self-destruct] [--no-packages] [--dry-run]

Options:
  --link            Symlink files from repo into $HOME (default)
  --copy            Copy files into $HOME (needed for self-destruct mode)
  --self-destruct   Delete the cloned repo after successful install
  --no-packages     Skip system packages, mise tools and Zsh plugins; only sync dotfiles
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

# Run a command as root: directly when already root (containers), else via sudo.
as_root() {
  if (( EUID == 0 )); then
    run_cmd "$@"
  elif command -v sudo >/dev/null 2>&1; then
    run_cmd sudo "$@"
  else
    echo "Need root for: $* (run as root or install sudo)."
    exit 1
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

install_system_packages() {
  case "$PLATFORM" in
    macos)
      ensure_homebrew
      echo "[brew] bundle $REPO_ROOT/Brewfile"
      run_cmd brew bundle --no-upgrade --file "$REPO_ROOT/Brewfile"
      ;;
    debian)
      local missing=() pkg
      for pkg in "${APT_PACKAGES[@]}"; do
        dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
      done
      if (( ${#missing[@]} == 0 )); then
        echo "[skip] apt packages already installed"
        return 0
      fi
      echo "[apt] install ${missing[*]}"
      as_root apt-get update
      as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
      ;;
    *)
      echo "[skip] system packages: unsupported platform"
      ;;
  esac
}

ensure_mise() {
  if [[ -x "$MISE_BIN" ]]; then
    echo "[skip] mise already installed"
    return 0
  fi
  if command -v mise >/dev/null 2>&1; then
    MISE_BIN="$(command -v mise)"
    echo "[skip] mise already installed: $MISE_BIN"
    return 0
  fi

  echo "[install] mise -> $MISE_BIN"
  if (( DRY_RUN )); then
    echo "[dry-run] curl -fsSL https://mise.run | sh"
    return 0
  fi
  curl -fsSL https://mise.run | MISE_INSTALL_PATH="$MISE_BIN" sh
}

install_mise_tools() {
  echo "[mise] install tools from ~/.config/mise/config.toml"
  # Inside the repo, mise treats .config/mise/config.toml as a project config
  # that must be trusted; it is the same file as the global config.
  run_cmd "$MISE_BIN" trust "$REPO_ROOT/.config/mise/config.toml"
  # Run from $HOME so only the global config applies.
  (cd "$HOME" && run_cmd "$MISE_BIN" install --yes)
  run_cmd "$MISE_BIN" reshim
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

# macOS already defaults to zsh; Debian defaults to bash.
ensure_zsh_login_shell() {
  [[ "$PLATFORM" == "debian" ]] || return 0

  local user zsh_path current
  user="$(id -un)"
  zsh_path="$(command -v zsh || echo /usr/bin/zsh)"
  current="$(getent passwd "$user" | cut -d: -f7)"
  if [[ "$current" == "$zsh_path" ]]; then
    echo "[skip] login shell already zsh"
    return 0
  fi

  echo "[shell] set login shell for $user to $zsh_path"
  as_root chsh -s "$zsh_path" "$user" || echo "[warn] could not change login shell; run: chsh -s $zsh_path"
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

sync_dotfiles() {
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

  # One set of agent instructions shared by every AI coding agent.
  sync_item "$REPO_ROOT/.config/ai/AGENTS.md" "$HOME/.claude/CLAUDE.md"
  sync_item "$REPO_ROOT/.config/ai/AGENTS.md" "$HOME/.codex/AGENTS.md"
  sync_item "$REPO_ROOT/.config/ai/AGENTS.md" "$HOME/.gemini/GEMINI.md"
  sync_item "$REPO_ROOT/.config/ai/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"

  ensure_secrets_template
}

# Untracked, owner-only file for API keys. Never overwritten.
ensure_secrets_template() {
  local secrets="$HOME/.config/ai/secrets.env"
  [[ -e "$secrets" ]] && return 0

  echo "[create] $secrets (chmod 600)"
  (( DRY_RUN )) && return 0
  mkdir -p "$(dirname "$secrets")"
  (
    umask 077
    cat > "$secrets" <<'EOF'
# API keys for AI tools. Not tracked by the dotfiles repo; keep it chmod 600.
# Loaded into every zsh/bash session. Uncomment what you use.
# ANTHROPIC_API_KEY=
# OPENAI_API_KEY=
# GEMINI_API_KEY=
EOF
  )
}

echo "[platform] $PLATFORM"

if (( INSTALL_PACKAGES )); then
  install_system_packages
fi

# Dotfiles first: mise reads its tool list from ~/.config/mise/config.toml.
sync_dotfiles

if (( INSTALL_PACKAGES )); then
  ensure_mise
  install_mise_tools
  install_rust

  clone_if_missing "https://github.com/ohmyzsh/ohmyzsh.git" "$HOME/.oh-my-zsh"
  clone_if_missing "https://github.com/Aloxaf/fzf-tab.git" "$HOME/.oh-my-zsh/custom/plugins/fzf-tab"
  clone_if_missing "https://github.com/zsh-users/zsh-autosuggestions.git" "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
  clone_if_missing "https://github.com/zsh-users/zsh-syntax-highlighting.git" "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"

  ensure_zsh_login_shell
fi

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
echo "Then sign in to your AI tools once: claude, codex, gemini, copilot (see: ai-doctor)."
