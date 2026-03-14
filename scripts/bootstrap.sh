#!/usr/bin/env bash

set -euo pipefail

OWNER_REPO="${DOTFILES_REPO:-Vishesh-Gupta/dotfiles}"
REF="${DOTFILES_REF:-main}"
ARCHIVE_URL="https://github.com/${OWNER_REPO}/archive/${REF}.tar.gz"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-bootstrap.XXXXXX")"
ARCHIVE_PATH="${TMP_DIR}/dotfiles.tar.gz"
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: ./scripts/bootstrap.sh [--dry-run]

Options:
  --dry-run    Print actions without making changes
  -h, --help   Show help
EOF
}

run_cmd() {
  if (( DRY_RUN )); then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

validate_inputs() {
  # Restrict to common GitHub owner/repo characters.
  if [[ ! "$OWNER_REPO" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]; then
    echo "Invalid DOTFILES_REPO value: '$OWNER_REPO'"
    exit 1
  fi

  # Allow branch/tag/SHA-like refs.
  if [[ ! "$REF" =~ ^[A-Za-z0-9._/-]+$ ]]; then
    echo "Invalid DOTFILES_REF value: '$REF'"
    exit 1
  fi
}

while (( $# > 0 )); do
  case "$1" in
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

validate_inputs

cleanup() {
  if (( DRY_RUN )); then
    echo "[dry-run] rm -rf $TMP_DIR"
  else
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

echo "[bootstrap] downloading archive: $ARCHIVE_URL"
run_cmd curl -fsSL "$ARCHIVE_URL" -o "$ARCHIVE_PATH"

echo "[bootstrap] extracting archive"
run_cmd tar -xzf "$ARCHIVE_PATH" -C "$TMP_DIR"

EXTRACTED_DIR="${TMP_DIR}/$(basename "${OWNER_REPO}")-${REF}"
if (( ! DRY_RUN )) && [[ ! -d "$EXTRACTED_DIR" ]]; then
  echo "Unable to locate extracted dotfiles directory."
  exit 1
fi

echo "[bootstrap] running installer in copy + self-destruct mode"
if (( DRY_RUN )); then
  run_cmd bash "$EXTRACTED_DIR/scripts/install.sh" --copy --self-destruct --dry-run
else
  run_cmd bash "$EXTRACTED_DIR/scripts/install.sh" --copy --self-destruct
fi

echo "[bootstrap] done"
