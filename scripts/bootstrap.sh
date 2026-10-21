#!/usr/bin/env bash
#
# One-line setup for a new machine (macOS or Debian/Ubuntu):
#   curl -fsSL https://raw.githubusercontent.com/Vishesh-Gupta/dotfiles/main/scripts/bootstrap.sh | bash
#   wget -qO-  https://raw.githubusercontent.com/Vishesh-Gupta/dotfiles/main/scripts/bootstrap.sh | bash
#
# Puts the dotfiles in ~/.dotfiles (git clone when git works, else a tarball),
# then runs the installer, which shows the tool menu. Extra arguments are
# passed to the installer, e.g. `| bash -s -- --all`.

set -euo pipefail

OWNER_REPO="${DOTFILES_REPO:-Vishesh-Gupta/dotfiles}"
REF="${DOTFILES_REF:-main}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
DRY_RUN=0
INSTALL_ARGS=()

usage() {
  cat <<'USAGE'
Usage: bootstrap.sh [--dry-run] [installer options]

Options:
  --dry-run    Print actions without making changes
  -h, --help   Show help
Any other option is passed to scripts/install.sh (e.g. --all, --yes, --tools a,b).

Environment:
  DOTFILES_DIR   Where to keep the dotfiles (default: ~/.dotfiles)
  DOTFILES_REPO  GitHub owner/repo (default: Vishesh-Gupta/dotfiles)
  DOTFILES_REF   Branch or tag (default: main)
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      INSTALL_ARGS+=("$1")
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      INSTALL_ARGS+=("$1")
      ;;
  esac
  shift
done

run_cmd() {
  if (( DRY_RUN )); then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

# Restrict to common GitHub owner/repo and branch/tag characters.
if [[ ! "$OWNER_REPO" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]; then
  echo "Invalid DOTFILES_REPO value: '$OWNER_REPO'"
  exit 1
fi
if [[ ! "$REF" =~ ^[A-Za-z0-9._/-]+$ ]]; then
  echo "Invalid DOTFILES_REF value: '$REF'"
  exit 1
fi
case "$DOTFILES_DIR" in
  ""|"/"|"$HOME"|"$HOME/")
    echo "Refusing to use unsafe DOTFILES_DIR: '$DOTFILES_DIR'"
    exit 1
    ;;
esac

# On a fresh Mac, /usr/bin/git is a stub until the Command Line Tools exist,
# so check that git actually runs.
have_git() {
  git --version >/dev/null 2>&1
}

download() {
  local url="$1" out="$2"
  if command -v curl >/dev/null 2>&1; then
    run_cmd curl -fsSL "$url" -o "$out"
  elif command -v wget >/dev/null 2>&1; then
    run_cmd wget -qO "$out" "$url"
  else
    echo "Need curl or wget to download the dotfiles."
    exit 1
  fi
}

fetch_tarball() {
  local tmp
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-bootstrap.XXXXXX")"
  # shellcheck disable=SC2064  # expand tmp now
  trap "rm -rf '$tmp'" EXIT

  echo "[bootstrap] downloading https://github.com/${OWNER_REPO}/archive/${REF}.tar.gz"
  download "https://github.com/${OWNER_REPO}/archive/${REF}.tar.gz" "$tmp/dotfiles.tar.gz"
  # GitHub names the archive's top-level directory inconsistently (slashes in
  # branch names, leading "v" on tags), so strip it instead of guessing.
  run_cmd mkdir -p "$tmp/dotfiles"
  run_cmd tar -xzf "$tmp/dotfiles.tar.gz" -C "$tmp/dotfiles" --strip-components=1
  if (( ! DRY_RUN )) && [[ ! -f "$tmp/dotfiles/scripts/install.sh" ]]; then
    echo "Downloaded archive does not look like the dotfiles repo."
    exit 1
  fi
  run_cmd rm -rf "$DOTFILES_DIR"
  run_cmd mkdir -p "$(dirname "$DOTFILES_DIR")"
  run_cmd mv "$tmp/dotfiles" "$DOTFILES_DIR"
}

if [[ -d "$DOTFILES_DIR/.git" ]] && have_git; then
  echo "[bootstrap] updating $DOTFILES_DIR"
  run_cmd git -C "$DOTFILES_DIR" pull --ff-only
elif [[ ! -e "$DOTFILES_DIR" ]] && have_git; then
  echo "[bootstrap] cloning $OWNER_REPO into $DOTFILES_DIR"
  run_cmd git clone --depth=1 --branch "$REF" "https://github.com/${OWNER_REPO}.git" "$DOTFILES_DIR"
elif [[ ! -e "$DOTFILES_DIR" ]] || [[ -f "$DOTFILES_DIR/scripts/install.sh" ]]; then
  # No git yet (fresh Debian or Mac), or a previous tarball install to refresh.
  fetch_tarball
else
  echo "$DOTFILES_DIR exists but is not a dotfiles checkout; set DOTFILES_DIR to another path."
  exit 1
fi

echo "[bootstrap] running installer"
if (( DRY_RUN )) && [[ ! -f "$DOTFILES_DIR/scripts/install.sh" ]]; then
  echo "[dry-run] bash $DOTFILES_DIR/scripts/install.sh ${INSTALL_ARGS[*]-}"
  exit 0
fi
exec bash "$DOTFILES_DIR/scripts/install.sh" ${INSTALL_ARGS[@]+"${INSTALL_ARGS[@]}"}
