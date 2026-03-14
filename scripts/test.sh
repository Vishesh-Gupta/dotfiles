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

bash "$REPO_ROOT/scripts/security-scan.sh" >/dev/null
pass "security scan script runs"

echo "All tests passed (${PASS_COUNT} checks)."
