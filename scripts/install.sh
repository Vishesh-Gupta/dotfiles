#!/usr/bin/env bash
#
# One installer for macOS and Debian/Ubuntu. Shows a menu of tools from
# tools.conf, then installs the selection: system packages from apt (Debian)
# or Homebrew (macOS apps), CLI tools, runtimes and AI agents from mise, so
# both platforms get the same versions.
#
# Must stay compatible with macOS's /bin/bash 3.2: no associative arrays,
# mapfile, ${var,,} or expansions of possibly-empty arrays under `set -u`.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="$REPO_ROOT/tools.conf"
STATE_DIR="$HOME/.config/dotfiles"
SELECTION_FILE="$STATE_DIR/selected-tools"
MISE_CONFIG="$HOME/.config/mise/config.toml"
MISE_BIN="$HOME/.local/bin/mise"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

INSTALL_MODE="link"
SELF_DESTRUCT=0
DRY_RUN=0
INSTALL_PACKAGES=1
INTERACTIVE=1
SELECT_ALL=0
TOOLS_ARG=""
LIST_ONLY=0

APT_PACKAGES=(
  build-essential  # native npm modules (e.g. gemini-cli's node-pty)
  ca-certificates
  curl
  git
  python3          # node-gyp, for native npm modules
  unzip
  zsh
)

usage() {
  cat <<'EOF'
Usage: ./scripts/install.sh [options]

Without options, shows a menu to pick tools (pre-ticked with your last choice).

Tool selection:
  --yes             Skip the menu; reuse the last selection (or the defaults)
  --all             Skip the menu; install everything in tools.conf
  --tools a,b,c     Skip the menu; install exactly these tool ids (core is always added)
  --list            Show the tool catalog and exit

Install options:
  --link            Symlink files from repo into $HOME (default)
  --copy            Copy files into $HOME (needed for self-destruct mode)
  --self-destruct   Delete the repo after successful install
  --no-packages     Only sync dotfiles; skip the menu and all package installs
  --dry-run         Print actions without making changes
  -h, --help        Show help
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --link) INSTALL_MODE="link" ;;
    --copy) INSTALL_MODE="copy" ;;
    --self-destruct) SELF_DESTRUCT=1 ;;
    --no-packages) INSTALL_PACKAGES=0 ;;
    --dry-run) DRY_RUN=1 ;;
    --yes|-y) INTERACTIVE=0 ;;
    --all) INTERACTIVE=0; SELECT_ALL=1 ;;
    --tools)
      [[ $# -ge 2 ]] || { echo "--tools needs a comma-separated list of ids"; exit 1; }
      INTERACTIVE=0
      TOOLS_ARG="$2"
      shift
      ;;
    --tools=*) INTERACTIVE=0; TOOLS_ARG="${1#--tools=}" ;;
    --list) LIST_ONLY=1 ;;
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

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# ---------------------------------------------------------------------------
# Tool catalog and selection (parallel arrays; bash 3.2 has no assoc arrays)
# ---------------------------------------------------------------------------

T_ID=()
T_SECTION=()
T_LABEL=()
T_DEFAULT=()
T_KIND=()
T_SPEC=()
T_ON=()

load_catalog() {
  local line id section label default kind spec
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "${line//[[:space:]]/}" || "$line" == \#* ]] && continue
    IFS='|' read -r id section label default kind spec <<<"$line"
    kind="$(trim "$kind")"
    if [[ "$kind" == "brew-cask" ]] && [[ "$PLATFORM" != "macos" ]]; then
      continue
    fi
    T_ID+=("$(trim "$id")")
    T_SECTION+=("$(trim "$section")")
    T_LABEL+=("$(trim "$label")")
    T_DEFAULT+=("$(trim "$default")")
    T_KIND+=("$kind")
    T_SPEC+=("$(trim "$spec")")
    T_ON+=(0)
  done < "$CATALOG"
}

tool_index() {
  local i
  for i in "${!T_ID[@]}"; do
    if [[ "${T_ID[$i]}" == "$1" ]]; then
      echo "$i"
      return 0
    fi
  done
  return 1
}

# Tick only core tools plus the given ids (comma or whitespace separated).
# Unknown ids are an error unless the second argument is 0.
select_ids() {
  local i id idx
  for i in "${!T_ID[@]}"; do
    if [[ "${T_DEFAULT[$i]}" == "core" ]]; then T_ON[i]=1; else T_ON[i]=0; fi
  done
  for id in ${1//,/ }; do
    if idx="$(tool_index "$id")"; then
      T_ON[idx]=1
    elif (( ${2:-1} )); then
      echo "Unknown tool id: '$id' (see: ./scripts/install.sh --list)"
      exit 1
    fi
  done
}

init_selection() {
  local i
  if [[ -n "$TOOLS_ARG" ]]; then
    select_ids "$TOOLS_ARG"
  elif (( SELECT_ALL )); then
    for i in "${!T_ID[@]}"; do T_ON[i]=1; done
  elif [[ -r "$SELECTION_FILE" ]]; then
    # Ids that no longer exist in the catalog (or on this platform) are ignored.
    select_ids "$(tr '\n' ' ' < "$SELECTION_FILE")" 0
  else
    for i in "${!T_ID[@]}"; do
      case "${T_DEFAULT[$i]}" in
        core|on) T_ON[i]=1 ;;
        *) T_ON[i]=0 ;;
      esac
    done
  fi
}

core_labels() {
  local i out=""
  for i in "${!T_ID[@]}"; do
    if [[ "${T_DEFAULT[$i]}" == "core" ]]; then
      out+="${out:+, }${T_LABEL[$i]}"
    fi
  done
  printf '%s' "$out"
}

list_catalog() {
  local i prev=""
  for i in "${!T_ID[@]}"; do
    if [[ "${T_SECTION[$i]}" != "$prev" ]]; then
      prev="${T_SECTION[$i]}"
      printf '\n%s\n' "$prev"
    fi
    printf '  %-10s %-4s %s\n' "${T_ID[$i]}" "${T_DEFAULT[$i]}" "${T_LABEL[$i]}"
  done
}

have_tty() {
  { : <>/dev/tty; } 2>/dev/null
}

restore_tty() {
  stty "$1" <&3 2>/dev/null || true
  printf '\033[?25h\033[?1049l' >&3
}

# Checkbox menu on /dev/tty (works under `curl ... | bash`, where stdin is the script).
choose_tools() {
  local rows=() i prev="" cursor=-1
  for i in "${!T_ID[@]}"; do
    [[ "${T_DEFAULT[$i]}" == "core" ]] && continue
    if [[ "${T_SECTION[$i]}" != "$prev" ]]; then
      prev="${T_SECTION[$i]}"
      rows+=("h:$prev")
    fi
    rows+=("i:$i")
    (( cursor < 0 )) && cursor=$(( ${#rows[@]} - 1 ))
  done
  (( cursor >= 0 )) || return 0

  exec 3<>/dev/tty
  local saved_stty
  saved_stty="$(stty -g <&3)"
  printf '\033[?1049h\033[?25l' >&3
  # shellcheck disable=SC2064  # expand saved_stty now
  trap "restore_tty '$saved_stty'" EXIT
  trap 'exit 130' INT TERM

  local height top=0 key rest row idx mark n r core
  core="$(core_labels)"
  n=${#rows[@]}
  while true; do
    height="$(stty size <&3 2>/dev/null | cut -d' ' -f1)"
    height=$(( ${height:-24} - 6 ))
    (( height < 5 )) && height=5
    (( cursor < top )) && top=$cursor
    (( cursor >= top + height )) && top=$(( cursor - height + 1 ))
    # Keep the first section header visible when near the top.
    (( top == 1 )) && top=0

    {
      printf '\033[H\033[2J'
      printf '\033[1mDotfiles setup: choose what to install\033[0m\n'
      printf '\033[2m↑/↓ move · space toggle · a all · n none · enter install · q quit\033[0m\n'
      printf '\033[2mAlways installed: zsh config, %s\033[0m\n\n' "$core"
      for (( r = top; r < n && r < top + height; r++ )); do
        row="${rows[$r]}"
        if [[ "$row" == h:* ]]; then
          printf '\033[1;34m%s\033[0m\n' "${row#h:}"
          continue
        fi
        idx="${row#i:}"
        if (( T_ON[idx] )); then mark='[x]'; else mark='[ ]'; fi
        if (( r == cursor )); then
          printf '\033[1;36m> %s %s\033[0m\n' "$mark" "${T_LABEL[$idx]}"
        else
          printf '  %s %s\n' "$mark" "${T_LABEL[$idx]}"
        fi
      done
      (( top + height < n )) && printf '\033[2m  ↓ more\033[0m\n'
    } >&3

    IFS= read -rsn1 key <&3 || key="q"
    if [[ "$key" == $'\033' ]]; then
      IFS= read -rsn2 rest <&3 || rest=""
      key+="$rest"
    fi
    case "$key" in
      $'\033[A'|k)
        r=$(( cursor - 1 ))
        while (( r >= 0 )) && [[ "${rows[$r]}" == h:* ]]; do r=$(( r - 1 )); done
        (( r >= 0 )) && cursor=$r
        ;;
      $'\033[B'|j)
        r=$(( cursor + 1 ))
        while (( r < n )) && [[ "${rows[$r]}" == h:* ]]; do r=$(( r + 1 )); done
        (( r < n )) && cursor=$r
        ;;
      " "|x)
        idx="${rows[$cursor]#i:}"
        T_ON[idx]=$(( 1 - T_ON[idx] ))
        ;;
      a)
        for i in "${!T_ID[@]}"; do T_ON[i]=1; done
        ;;
      n)
        for i in "${!T_ID[@]}"; do
          [[ "${T_DEFAULT[$i]}" == "core" ]] || T_ON[i]=0
        done
        ;;
      ""|$'\n'|$'\r')
        break
        ;;
      q|Q)
        restore_tty "$saved_stty"
        trap - EXIT INT TERM
        echo "Cancelled. Nothing was installed."
        exit 1
        ;;
    esac
  done

  restore_tty "$saved_stty"
  exec 3>&-
  trap - EXIT INT TERM
}

is_selected_kind() {
  local i
  for i in "${!T_ID[@]}"; do
    if (( T_ON[i] )) && [[ "${T_KIND[$i]}" == "$1" ]]; then
      return 0
    fi
  done
  return 1
}

print_selection() {
  local i out=""
  for i in "${!T_ID[@]}"; do
    if (( T_ON[i] )); then
      out+="${out:+, }${T_ID[$i]}"
    fi
  done
  echo "[tools] $out"
}

save_selection() {
  local i
  echo "[state] $SELECTION_FILE"
  (( DRY_RUN )) && return 0
  mkdir -p "$STATE_DIR"
  : > "$SELECTION_FILE"
  for i in "${!T_ID[@]}"; do
    if (( T_ON[i] )) && [[ "${T_DEFAULT[$i]}" != "core" ]]; then
      echo "${T_ID[$i]}" >> "$SELECTION_FILE"
    fi
  done
}

# ---------------------------------------------------------------------------
# Installers
# ---------------------------------------------------------------------------

ensure_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    return 0
  fi

  if (( DRY_RUN )); then
    echo "[dry-run] Homebrew is missing; would install Homebrew."
    return 0
  fi

  echo "Homebrew not found. Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
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
      # zsh and curl ship with macOS; git comes with the Command Line Tools.
      if ! xcode-select -p >/dev/null 2>&1; then
        echo "[install] Xcode Command Line Tools: finish the dialog, then re-run this installer."
        run_cmd xcode-select --install || true
        (( DRY_RUN )) || exit 1
      fi
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

install_casks() {
  is_selected_kind brew-cask || return 0
  ensure_homebrew

  local i cask
  for i in "${!T_ID[@]}"; do
    if (( ! T_ON[i] )) || [[ "${T_KIND[$i]}" != "brew-cask" ]]; then
      continue
    fi
    cask="${T_SPEC[$i]}"
    if command -v brew >/dev/null 2>&1 && brew list --cask "$cask" >/dev/null 2>&1; then
      echo "[skip] app already installed: $cask"
    else
      echo "[install] app: $cask"
      run_cmd brew install --cask "$cask"
    fi
  done
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

# Print the [tools] lines for selected mise items. AI agents go last because
# mise resolves a binary name to the first tool that provides it, and some
# agents bundle their own copies of common tools (cursor-agent ships `rg`).
mise_tool_lines() {
  local pass i spec line key seen=" "
  for pass in tools agents; do
    for i in "${!T_ID[@]}"; do
      if (( ! T_ON[i] )) || [[ "${T_KIND[$i]}" != "mise" ]]; then
        continue
      fi
      if [[ "${T_SECTION[$i]}" == "AI agents" ]]; then
        [[ "$pass" == "agents" ]] || continue
      else
        [[ "$pass" == "tools" ]] || continue
      fi
      spec="${T_SPEC[$i]}"
      while [[ -n "$spec" ]]; do
        line="${spec%%;*}"
        if [[ "$spec" == *";"* ]]; then spec="${spec#*;}"; else spec=""; fi
        line="$(trim "$line")"
        [[ -n "$line" ]] || continue
        # TOML rejects duplicate keys; keep the first entry for each tool.
        key="$(trim "${line%%=*}")"
        [[ "$seen" == *" $key "* ]] && continue
        seen+="$key "
        echo "$line"
      done
    done
  done
}

write_mise_config() {
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/mise-config.XXXXXX")"
  {
    echo "# Generated by dotfiles from tools.conf. Change tools with: dotfiles install"
    echo "# Hand edits are overwritten on the next install; per-project versions go"
    echo "# in that project's mise.toml."
    echo
    echo "[tools]"
    mise_tool_lines
    echo
    echo "[settings]"
    echo "# Read .nvmrc, .python-version, etc. so existing projects just work."
    echo 'idiomatic_version_file_enable_tools = ["node", "python", "go"]'
    echo "# Install Python CLIs (pipx: tools) with uv."
    echo "pipx.uvx = true"
  } > "$tmp"

  echo "[mise] write $MISE_CONFIG"
  if (( DRY_RUN )); then
    sed 's/^/[dry-run]   /' "$tmp"
    rm -f "$tmp"
    return 0
  fi
  backup_existing "$tmp" "$MISE_CONFIG"
  mkdir -p "$(dirname "$MISE_CONFIG")"
  mv "$tmp" "$MISE_CONFIG"
  chmod 644 "$MISE_CONFIG"
}

install_mise_tools() {
  echo "[mise] install selected tools"
  # Run from $HOME so only the global config applies.
  (cd "$HOME" && run_cmd "$MISE_BIN" install --yes)
  run_cmd "$MISE_BIN" reshim
}

# Rust toolchain via the official rustup installer. PATH is managed by the
# dotfiles (~/.zshenv sources ~/.cargo/env), so rustup must not edit rc files.
install_rust() {
  is_selected_kind rustup || return 0
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

# ---------------------------------------------------------------------------
# Dotfile syncing
# ---------------------------------------------------------------------------

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
  sync_item "$REPO_ROOT/.bash_profile" "$HOME/.bash_profile"
  sync_item "$REPO_ROOT/.bashrc" "$HOME/.bashrc"
  sync_item "$REPO_ROOT/.zshrc.d" "$HOME/.zshrc.d"
  sync_item "$REPO_ROOT/bin/dotfiles" "$HOME/.local/bin/dotfiles"

  sync_item "$REPO_ROOT/.config/ghostty/config" "$HOME/.config/ghostty/config"
  sync_item "$REPO_ROOT/.config/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
  sync_item "$REPO_ROOT/.config/starship.toml" "$HOME/.config/starship.toml"
  sync_item "$REPO_ROOT/.config/git/config" "$HOME/.config/git/config"
  sync_item "$REPO_ROOT/.config/git/ignore" "$HOME/.config/git/ignore"

  # One set of agent instructions shared by every AI coding agent.
  sync_item "$REPO_ROOT/.config/ai/AGENTS.md" "$HOME/.claude/CLAUDE.md"
  sync_item "$REPO_ROOT/.config/ai/AGENTS.md" "$HOME/.codex/AGENTS.md"
  sync_item "$REPO_ROOT/.config/ai/AGENTS.md" "$HOME/.gemini/GEMINI.md"
  sync_item "$REPO_ROOT/.config/ai/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"

  ensure_secrets_template

  # Lets the `dotfiles` command find this checkout.
  echo "[state] $STATE_DIR/repo"
  if (( ! DRY_RUN )); then
    mkdir -p "$STATE_DIR"
    echo "$REPO_ROOT" > "$STATE_DIR/repo"
  fi
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

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

load_catalog

if (( LIST_ONLY )); then
  list_catalog
  exit 0
fi

echo "[platform] $PLATFORM"

if (( INSTALL_PACKAGES )); then
  init_selection
  if (( INTERACTIVE )); then
    if have_tty; then
      choose_tools
    else
      echo "[tools] no terminal for the menu; using saved selection or defaults (pass --tools/--all to choose)"
    fi
  fi
  print_selection

  install_system_packages
fi

sync_dotfiles

if (( INSTALL_PACKAGES )); then
  write_mise_config
  ensure_mise
  install_mise_tools
  install_rust
  install_casks

  clone_if_missing "https://github.com/ohmyzsh/ohmyzsh.git" "$HOME/.oh-my-zsh"
  clone_if_missing "https://github.com/Aloxaf/fzf-tab.git" "$HOME/.oh-my-zsh/custom/plugins/fzf-tab"
  clone_if_missing "https://github.com/zsh-users/zsh-autosuggestions.git" "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
  clone_if_missing "https://github.com/zsh-users/zsh-syntax-highlighting.git" "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"

  ensure_zsh_login_shell
  save_selection
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
  echo "Setup complete."
fi
echo "Open a new terminal (or run: exec zsh) to load the new config."
echo "Next: sign in to your AI tools (claude, codex, gemini, ...) and run: dotfiles doctor"
