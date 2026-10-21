# Ubuntu's /etc/zsh/zshrc runs its own compinit; Oh My Zsh (or .zshrc) runs it.
skip_global_compinit=1

# Runs for every zsh, including the non-interactive shells that editors and AI
# agents spawn, so tools must be on PATH here (via mise shims), not only in .zshrc.
typeset -U path PATH
path=("$HOME/.local/bin" "$HOME/.local/share/mise/shims" $path)

if [[ -r "$HOME/.cargo/env" ]]; then
  . "$HOME/.cargo/env"
fi
