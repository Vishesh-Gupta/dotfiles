#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS_COUNT=0

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "[pass] $1"
}

fail() {
  echo "[fail] $1" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  [[ "$haystack" == *"$needle"* ]] || fail "$label (missing '$needle')"
}

assert_not_exists() {
  local path="$1"
  local label="$2"
  [[ ! -e "$path" ]] || fail "$label (found '$path')"
}

echo "Running dotfiles script tests..."

bash -n "$REPO_ROOT/scripts/install.sh"
bash -n "$REPO_ROOT/scripts/bootstrap.sh"
bash -n "$REPO_ROOT/scripts/security-scan.sh"
pass "script syntax checks"

command -v zsh >/dev/null 2>&1 || fail "zsh is required to check zsh config syntax"
for zsh_file in "$REPO_ROOT"/.zshrc "$REPO_ROOT"/.zshenv "$REPO_ROOT"/.zprofile "$REPO_ROOT"/.zshrc.d/*.zsh; do
  zsh -n "$zsh_file" || fail "zsh syntax error in $zsh_file"
done
pass "zsh config syntax checks"

git config --file "$REPO_ROOT/.config/git/config" --list >/dev/null || fail "invalid .config/git/config"
pass "git config parses"

install_help="$(DOTFILES_SKIP_OS_CHECK=1 bash "$REPO_ROOT/scripts/install.sh" --help)"
assert_contains "$install_help" "--dry-run" "install help includes dry-run"
pass "install help output"

bootstrap_help="$(bash "$REPO_ROOT/scripts/bootstrap.sh" --help)"
assert_contains "$bootstrap_help" "--dry-run" "bootstrap help includes dry-run"
pass "bootstrap help output"

set +e
invalid_out="$(DOTFILES_SKIP_OS_CHECK=1 bash "$REPO_ROOT/scripts/install.sh" --self-destruct 2>&1)"
invalid_status=$?
set -e
[[ $invalid_status -ne 0 ]] || fail "invalid self-destruct combo should fail"
assert_contains "$invalid_out" "--self-destruct requires --copy" "invalid combo error text"
pass "invalid self-destruct guard"

tmp_home="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test-home.XXXXXX")"
trap 'rm -rf "$tmp_home"' EXIT

dry_run_out="$(HOME="$tmp_home" DOTFILES_SKIP_OS_CHECK=1 bash "$REPO_ROOT/scripts/install.sh" --dry-run --copy --self-destruct)"
assert_contains "$dry_run_out" "Dry run complete. No changes were made." "install dry-run completion message"
assert_not_exists "$tmp_home/.zshrc" "install dry-run should not create files"
pass "install dry-run safety"

bootstrap_dry_run_out="$(HOME="$tmp_home" bash "$REPO_ROOT/scripts/bootstrap.sh" --dry-run)"
assert_contains "$bootstrap_dry_run_out" "[dry-run] curl -fsSL" "bootstrap dry-run should avoid network call"
assert_contains "$bootstrap_dry_run_out" "--dry-run" "bootstrap dry-run should propagate dry-run to installer"
pass "bootstrap dry-run behavior"

link_home="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test-link.XXXXXX")"
trap 'rm -rf "$tmp_home" "$link_home"' EXIT
mkdir -p "$link_home/.zshrc.d"
echo "old zshrc" > "$link_home/.zshrc"
echo "local tweak" > "$link_home/.zshrc.d/local.zsh"

HOME="$link_home" DOTFILES_SKIP_OS_CHECK=1 bash "$REPO_ROOT/scripts/install.sh" --link --no-packages >/dev/null
[[ "$(readlink "$link_home/.zshrc")" == "$REPO_ROOT/.zshrc" ]] || fail ".zshrc should link to the repo"
[[ "$(readlink "$link_home/.zshrc.d")" == "$REPO_ROOT/.zshrc.d" ]] || fail ".zshrc.d should link to the repo, not inside an existing dir"
for cfg in starship.toml git/config git/ignore mise/config.toml ghostty/config zellij/config.kdl; do
  [[ -L "$link_home/.config/$cfg" ]] || fail ".config/$cfg should be linked"
done
backups=("$link_home"/.dotfiles-backup/*)
(( ${#backups[@]} == 1 )) || fail "expected one backup directory"
[[ "$(<"${backups[0]}/.zshrc")" == "old zshrc" ]] || fail "existing .zshrc should be backed up"
[[ -f "${backups[0]}/.zshrc.d/local.zsh" ]] || fail "existing .zshrc.d should be backed up"
pass "link install backs up existing files"

sleep 1
HOME="$link_home" DOTFILES_SKIP_OS_CHECK=1 bash "$REPO_ROOT/scripts/install.sh" --link --no-packages >/dev/null
backups=("$link_home"/.dotfiles-backup/*)
(( ${#backups[@]} == 1 )) || fail "re-running install should not create new backups"
pass "link install is idempotent"

HOME="$link_home" DOTFILES_SKIP_OS_CHECK=1 bash "$REPO_ROOT/scripts/install.sh" --copy --no-packages >/dev/null
[[ -f "$link_home/.zshrc" && ! -L "$link_home/.zshrc" ]] || fail ".zshrc should be a regular file after --copy"
[[ -d "$link_home/.zshrc.d" && ! -L "$link_home/.zshrc.d" ]] || fail ".zshrc.d should be a real dir after --copy"
pass "copy install replaces existing links"

startup_err="$(HOME="$link_home" TERM=xterm-256color zsh -i -c exit 2>&1 >/dev/null)" || fail "zsh startup exited non-zero: $startup_err"
[[ -z "$startup_err" ]] || fail "zsh startup printed errors: $startup_err"
pass "zsh starts cleanly"

bash "$REPO_ROOT/scripts/security-scan.sh" >/dev/null
pass "security scan script runs"

echo "All tests passed (${PASS_COUNT} checks)."
