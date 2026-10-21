# Tool integrations and lazy completion.

if command -v zoxide >/dev/null 2>&1; then
  # Override cd with zoxide's smarter jump behavior.
  eval "$(zoxide init zsh --cmd cd)"
fi

if command -v mise >/dev/null 2>&1; then
  # Puts the tool versions from mise.toml / .tool-versions on PATH per directory.
  eval "$(mise activate zsh)"
fi

if command -v entire >/dev/null 2>&1; then
  _entire_lazy_completion() {
    unfunction _entire_lazy_completion 2>/dev/null
    eval "$(entire completion zsh)"
  }
  compdef _entire_lazy_completion entire
fi
