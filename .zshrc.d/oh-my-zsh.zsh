# Oh My Zsh bootstrap.

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""

# Directory jumping is handled by zoxide (see tools.zsh), so no `z` plugin.
# fzf-tab must load before zsh-autosuggestions and zsh-syntax-highlighting.
if (( _use_fancy_shell )); then
  plugins=(
    git
    fzf
    rust
    colored-man-pages
    fzf-tab
    zsh-autosuggestions
    zsh-syntax-highlighting
    history-substring-search
  )
else
  plugins=(
    git
    colored-man-pages
  )
fi

# Docker CLI completion path (compinit handled by OMZ).
fpath=("$HOME/.docker/completions" $fpath)

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
else
  autoload -Uz compinit && compinit
fi
