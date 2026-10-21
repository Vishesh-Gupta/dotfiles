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
bash -n "$REPO_ROOT/bin/dotfiles"
pass "script syntax checks"

command -v zsh >/dev/null 2>&1 || fail "zsh is required to check zsh config syntax"
for zsh_file in "$REPO_ROOT"/.zshrc "$REPO_ROOT"/.zshenv "$REPO_ROOT"/.zprofile "$REPO_ROOT"/.zshrc.d/*.zsh; do
  zsh -n "$zsh_file" || fail "zsh syntax error in $zsh_file"
done
pass "zsh config syntax checks"

git config --file "$REPO_ROOT/.config/git/config" --list >/dev/null || fail "invalid .config/git/config"
pass "git config parses"

toml_keys() {
  python3 -c 'import sys, tomllib; print(" ".join(tomllib.load(open(sys.argv[1], "rb")).get("tools", {})))' "$1"
}

toml_keys "$REPO_ROOT/.config/starship.toml" >/dev/null || fail "invalid TOML: .config/starship.toml"
pass "TOML configs parse"

# Print the mise config an install would generate for the given selection flags.
generated_mise_config() {
  local home out
  home="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test-gen.XXXXXX")"
  HOME="$home" DOTFILES_SKIP_OS_CHECK=1 bash "$REPO_ROOT/scripts/install.sh" --dry-run "$@" \
    | sed -n 's/^\[dry-run\]   //p' > "$home/config.toml"
  out="$(toml_keys "$home/config.toml")" || { rm -rf "$home"; fail "generated mise config is invalid TOML ($*)"; }
  rm -rf "$home"
  echo " $out "
}

list_out="$(DOTFILES_SKIP_OS_CHECK=1 bash "$REPO_ROOT/scripts/install.sh" --list)"
assert_contains "$list_out" "claude" "catalog lists claude"
pass "tool catalog lists"

for flags in "--yes" "--all" "--tools gemini,aider,llm,python"; do
  # shellcheck disable=SC2086  # flags are intentionally split
  generated_mise_config $flags >/dev/null
done
pass "generated mise config is valid TOML for every selection"

keys="$(generated_mise_config --tools claude,gemini)"
assert_contains "$keys" " fzf " "core tools are always installed"
assert_contains "$keys" " claude " "selected agent is installed"
assert_contains "$keys" " node " "npm-based agent pulls in node"
[[ "$keys" != *" codex "* ]] || fail "unselected agent should not be installed"
[[ "$keys" == *" ripgrep "*" cursor-agent "* || "$keys" != *" cursor-agent "* ]] || fail "AI agents must come after core tools"
pass "tool selection drives mise config"

keys="$(generated_mise_config --all)"
[[ "$keys" == *" ripgrep "*" cursor-agent "* ]] || fail "AI agents must come after core tools"
pass "AI agents listed after core tools"

set +e
unknown_out="$(DOTFILES_SKIP_OS_CHECK=1 bash "$REPO_ROOT/scripts/install.sh" --dry-run --tools nope 2>&1)"
unknown_status=$?
set -e
[[ $unknown_status -ne 0 ]] || fail "unknown tool id should fail"
assert_contains "$unknown_out" "Unknown tool id: 'nope'" "unknown tool error text"
pass "unknown tool id is rejected"

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

dry_run_out="$(HOME="$tmp_home" DOTFILES_SKIP_OS_CHECK=1 bash "$REPO_ROOT/scripts/install.sh" --dry-run --yes --copy --self-destruct)"
assert_contains "$dry_run_out" "Dry run complete. No changes were made." "install dry-run completion message"
assert_not_exists "$tmp_home/.zshrc" "install dry-run should not create files"
pass "install dry-run safety"

bootstrap_dry_run_out="$(HOME="$tmp_home" bash "$REPO_ROOT/scripts/bootstrap.sh" --dry-run --all)"
assert_contains "$bootstrap_dry_run_out" "$tmp_home/.dotfiles" "bootstrap defaults to ~/.dotfiles"
assert_contains "$bootstrap_dry_run_out" "--dry-run --all" "bootstrap passes options to the installer"
assert_not_exists "$tmp_home/.dotfiles" "bootstrap dry-run should not download"
pass "bootstrap dry-run behavior"

# Without git, bootstrap falls back to a tarball (curl or wget).
nogit_bin="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test-bin.XXXXXX")"
for tool in bash curl mktemp dirname cat rm; do
  ln -s "$(command -v "$tool")" "$nogit_bin/$tool"
done
bootstrap_nogit_out="$(HOME="$tmp_home" PATH="$nogit_bin" bash "$REPO_ROOT/scripts/bootstrap.sh" --dry-run)"
rm -rf "$nogit_bin"
assert_contains "$bootstrap_nogit_out" "archive/main.tar.gz" "bootstrap downloads a tarball without git"
pass "bootstrap tarball fallback"

dotfiles_help="$(bash "$REPO_ROOT/bin/dotfiles" help)"
assert_contains "$dotfiles_help" "upgrade" "dotfiles help lists commands"
[[ "$(DOTFILES_DIR=/somewhere bash "$REPO_ROOT/bin/dotfiles" dir)" == "/somewhere" ]] || fail "dotfiles dir honours DOTFILES_DIR"
pass "dotfiles command"

# Drive the checkbox menu through a pseudo-terminal (util-linux `script` only).
if script -qec true /dev/null >/dev/null 2>&1; then
  menu_out="$(
    { sleep 1; printf '\033[B'; sleep 0.3; printf ' '; sleep 0.3; printf '\r'; sleep 2; } \
      | HOME="$tmp_home" TERM=xterm-256color DOTFILES_SKIP_OS_CHECK=1 \
        script -qec "bash '$REPO_ROOT/scripts/install.sh' --dry-run" /dev/null 2>&1 | tr -d '\r'
  )"
  assert_contains "$menu_out" "Dotfiles setup: choose what to install" "menu renders"
  [[ "$menu_out" == *"[tools] core, claude, gemini"* ]] || fail "menu toggle should untick codex"
  pass "interactive menu toggles tools"
else
  echo "[skip] interactive menu test (needs util-linux script)"
fi

link_home="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test-link.XXXXXX")"
trap 'rm -rf "$tmp_home" "$link_home"' EXIT
mkdir -p "$link_home/.zshrc.d"
echo "old zshrc" > "$link_home/.zshrc"
echo "local tweak" > "$link_home/.zshrc.d/local.zsh"

HOME="$link_home" DOTFILES_SKIP_OS_CHECK=1 bash "$REPO_ROOT/scripts/install.sh" --link --no-packages >/dev/null
[[ "$(readlink "$link_home/.local/bin/dotfiles")" == "$REPO_ROOT/bin/dotfiles" ]] || fail "dotfiles command should be linked"
[[ "$(cat "$link_home/.config/dotfiles/repo")" == "$REPO_ROOT" ]] || fail "repo path should be recorded"
[[ "$(readlink "$link_home/.zshrc")" == "$REPO_ROOT/.zshrc" ]] || fail ".zshrc should link to the repo"
[[ "$(readlink "$link_home/.zshrc.d")" == "$REPO_ROOT/.zshrc.d" ]] || fail ".zshrc.d should link to the repo, not inside an existing dir"
[[ "$(readlink "$link_home/.bash_profile")" == "$REPO_ROOT/.bash_profile" ]] || fail ".bash_profile should be linked"
for cfg in .config/starship.toml .config/git/config .config/git/ignore \
           .config/ghostty/config .config/zellij/config.kdl \
           .claude/CLAUDE.md .codex/AGENTS.md .gemini/GEMINI.md .config/opencode/AGENTS.md; do
  [[ -L "$link_home/$cfg" ]] || fail "$cfg should be linked"
done
[[ "$(stat -c %a "$link_home/.config/ai/secrets.env" 2>/dev/null || stat -f %Lp "$link_home/.config/ai/secrets.env")" == "600" ]] \
  || fail "secrets.env template should be created with mode 600"
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

startup_err="$(cd "$link_home" && HOME="$link_home" TERM=xterm-256color zsh -i -c exit 2>&1 >/dev/null)" || fail "zsh startup exited non-zero: $startup_err"
[[ -z "$startup_err" ]] || fail "zsh startup printed errors: $startup_err"
pass "zsh starts cleanly"

# CI runners ship world-writable completion dirs, and Ubuntu's /etc/zsh/zshrc
# runs its own compinit unless ~/.zshenv sets skip_global_compinit. Mimic that
# system file via ZDOTDIR; no compinit may prompt.
insecure_dir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test-fpath.XXXXXX")"
chmod 777 "$insecure_dir"
zdotdir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test-zdotdir.XXXXXX")"
printf 'source %q/.zshenv\n' "$link_home" > "$zdotdir/.zshenv"
# shellcheck disable=SC2016  # written for zsh to expand
printf '%s\n' 'if [[ -z "$skip_global_compinit" ]]; then autoload -U compinit; compinit; fi' \
  "source $(printf '%q' "$link_home")/.zshrc" > "$zdotdir/.zshrc"
startup_err="$(cd "$link_home" && HOME="$link_home" ZDOTDIR="$zdotdir" TERM=xterm-256color \
  FPATH="$insecure_dir:$(zsh -fc 'echo $FPATH')" \
  zsh -i -c exit 2>&1 >/dev/null </dev/null)" || fail "zsh startup with insecure fpath exited non-zero: $startup_err"
rm -rf "$insecure_dir" "$zdotdir"
[[ -z "$startup_err" ]] || fail "zsh startup with insecure fpath printed errors: $startup_err"
pass "zsh starts cleanly with insecure completion dirs"

scan_out="$(bash "$REPO_ROOT/scripts/security-scan.sh" 2>&1)" || fail "security scan failed:
$scan_out"
pass "security scan script runs"

echo "All tests passed (${PASS_COUNT} checks)."
