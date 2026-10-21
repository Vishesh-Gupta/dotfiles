# Core environment and PATH handling.

_use_fancy_shell=0
if [[ -o interactive ]] && [[ "${TERM:-}" != "dumb" ]]; then
  _use_fancy_shell=1
fi

: "${GOPATH:=$HOME/go}"
export GOPATH

path=(
  /opt/homebrew/bin
  /opt/homebrew/sbin
  $HOME/.local/bin
  $HOME/Library/Python/*/bin(N-/On)
  $HOME/.antigravity/antigravity/bin
  $path
  $GOPATH/bin
)

# Drop directories that don't exist on this machine and de-duplicate,
# keeping the first occurrence.
path=($^path(N-/))
typeset -U path PATH
