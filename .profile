# Login shells other than zsh (bash, sh). Keep tools from mise on PATH so
# scripts and AI agents that use bash see the same tools as zsh.
case ":$PATH:" in
  *":$HOME/.local/share/mise/shims:"*) ;;
  *) PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH" ;;
esac
export PATH

if [ -r "$HOME/.cargo/env" ]; then
  . "$HOME/.cargo/env"
fi

# Debian's default ~/.profile loads ~/.bashrc for login bash; keep that.
if [ -n "${BASH_VERSION:-}" ] && [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
