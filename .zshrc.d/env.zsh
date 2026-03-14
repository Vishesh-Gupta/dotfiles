# Core environment and PATH handling.

_use_fancy_shell=0
if [[ -o interactive ]] && [[ "${TERM:-}" != "dumb" ]]; then
  _use_fancy_shell=1
fi

export PATH="/opt/homebrew/bin:$PATH"
export PATH="$HOME/Library/Python/3.13/bin:$PATH"

: "${GOPATH:=$HOME/go}"
export GOPATH
export PATH="$PATH:$GOPATH/bin"

# Added by Antigravity
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"

# De-duplicate PATH entries while preserving first occurrences.
typeset -U path PATH
