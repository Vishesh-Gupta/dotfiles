# Runs for every zsh, including the non-interactive shells that editors and AI
# agents spawn, so tools must be on PATH here (via mise shims), not only in .zshrc.
typeset -U path PATH
path=("$HOME/.local/bin" "$HOME/.local/share/mise/shims" $path)

if [[ -r "$HOME/.cargo/env" ]]; then
  . "$HOME/.cargo/env"
fi
