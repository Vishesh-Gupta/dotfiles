if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# macOS's /etc/zprofile (path_helper) moves system paths ahead of ours, so
# put user tools back in front for login shells.
path=("$HOME/.local/bin" "$HOME/.local/share/mise/shims" "$HOME/.cargo/bin" $path)

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
