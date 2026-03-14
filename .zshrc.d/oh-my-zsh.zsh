# Oh My Zsh bootstrap.

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""

if (( _use_fancy_shell )); then
  plugins=(
    git
    z
    fzf
    zsh-autosuggestions
    zsh-syntax-highlighting
    colored-man-pages
    history-substring-search
  )
else
  plugins=(
    git
    z
    colored-man-pages
  )
fi

# Docker CLI completion path (compinit handled by OMZ).
fpath=("$HOME/.docker/completions" $fpath)

source "$ZSH/oh-my-zsh.sh"
