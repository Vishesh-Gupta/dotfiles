# Bash is not the main shell, but agents and scripts often use it.
case ":$PATH:" in
  *":$HOME/.local/share/mise/shims:"*) ;;
  *) PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH" ;;
esac
export PATH

if [ -r "$HOME/.cargo/env" ]; then
  . "$HOME/.cargo/env"
fi

if [ -r "$HOME/.config/ai/secrets.env" ]; then
  set -a
  . "$HOME/.config/ai/secrets.env"
  set +a
fi

# Interactive-only setup below.
case $- in
  *i*) ;;
  *) return ;;
esac

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
fi

if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --bash 2>/dev/null)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash)"
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi
