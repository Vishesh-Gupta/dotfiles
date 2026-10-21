# Reusable shell functions.

# Smart viewer:
# - Markdown: rendered preview when available.
# - Other files: syntax-highlighted view via bat.
view() {
  local force_md=0
  if [[ "${1-}" == "--md" ]]; then
    force_md=1
    shift
  fi

  if (( $# == 0 )); then
    bat
    return
  fi

  local file lower
  for file in "$@"; do
    lower="${file:l}"
    if (( force_md )) || \
       [[ "$lower" == *.md ]] || \
       [[ "$lower" == *.markdown ]] || \
       [[ "$lower" == *.mdx ]] || \
       [[ "$lower" == *.mkd ]] || \
       [[ "$lower" == "readme" ]] || \
       [[ "$lower" == readme.* ]] || \
       [[ "$lower" == "changelog" ]] || \
       [[ "$lower" == changelog.* ]]; then
      if command -v glow >/dev/null 2>&1; then
        glow "$file"
      else
        bat --language=markdown "$file"
      fi
    else
      bat "$file"
    fi
  done
}

# Terraform init with multi-platform lock file.
tfinit() {
  terraform init "$@" && \
  terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=darwin_amd64
}

# Delete local branches whose upstream was deleted (asks before deleting).
git-cleanup() {
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Not in a git repository"
    return 1
  fi

  echo "Fetching and pruning remote branches..."
  git fetch --prune || return 1

  local current
  current=$(git branch --show-current)

  local -a branches
  branches=(${(f)"$(git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads | awk '$2 == "[gone]" { print $1 }')"})
  branches=(${branches:#$current})

  if (( ! $#branches )); then
    echo "No branches with a deleted upstream"
    return 0
  fi

  echo "Branches whose upstream is gone:"
  print -l -- "${(@)branches/#/  }"
  if ! read -q "?Delete ${#branches} branch(es)? [y/N] "; then
    echo
    return 0
  fi
  echo

  git branch -D -- "${branches[@]}"
}

# Benchmark shell startup in a pseudo-tty.
bench-shell() {
  local runs="${1:-5}"
  if ! [[ "$runs" == <-> ]] || (( runs < 1 )); then
    echo "Usage: bench-shell [positive-runs]"
    return 1
  fi

  python3 - "$runs" <<'PY'
import statistics
import subprocess
import sys
import time

runs = int(sys.argv[1])
vals = []
for _ in range(runs):
    start = time.perf_counter()
    proc = subprocess.run(
        ["script", "-q", "/dev/null", "zsh", "-i", "-c", "exit"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if proc.returncode != 0:
        print(f"Benchmark run failed with exit code {proc.returncode}.")
        sys.exit(proc.returncode)
    vals.append(time.perf_counter() - start)

print(f"runs: {vals}")
print(f"avg: {statistics.mean(vals):.3f}s  min: {min(vals):.3f}s  max: {max(vals):.3f}s")
PY
}
