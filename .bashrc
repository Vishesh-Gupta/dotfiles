if [ -r "$HOME/.cargo/env" ]; then
  . "$HOME/.cargo/env"
fi

if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --bash 2>/dev/null)"
fi
