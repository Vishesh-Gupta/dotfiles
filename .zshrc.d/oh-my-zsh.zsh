# Oh My Zsh bootstrap.

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""

# Directory jumping is handled by zoxide (see tools.zsh), so no `z` plugin.
if (( _use_fancy_shell )); then
  plugins=(
    git
    fzf
    colored-man-pages
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
