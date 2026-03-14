#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$REPO_ROOT"

echo "[security] running shellcheck"
shellcheck -x scripts/install.sh scripts/bootstrap.sh scripts/test.sh scripts/security-scan.sh

echo "[security] scanning for risky shell patterns"
rg -n --glob "*.sh" --glob ".zshrc" --glob ".zprofile" --glob ".zshenv" --glob ".bashrc" --glob ".profile" \
  '(^|\s)(curl|wget)\s+[^|]*\|\s*(bash|sh)|eval\s+"\$\(|(^|\s)rm\s+-rf\s+["'"'"']?\$' . || true

echo "[security] pattern scan is advisory; review matches for intended usage."

echo "[security] complete"
