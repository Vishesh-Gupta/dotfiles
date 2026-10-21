# fzf defaults. Loaded before Oh My Zsh so its fzf plugin picks these up.

export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border --info=inline'

if (( $+commands[fd] )); then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

  # Used by fzf's `**<Tab>` completion.
  _fzf_compgen_path() { fd --hidden --follow --exclude .git . "$1"; }
  _fzf_compgen_dir() { fd --type d --hidden --follow --exclude .git . "$1"; }
fi

if (( $+commands[bat] )); then
  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:300 {}'"
fi

if (( $+commands[eza] )); then
  export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always --icons {}'"
fi

# fzf-tab: fuzzy tab completion with previews.
zstyle ':completion:*' menu no
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:complete:(cd|__zoxide_z):*' fzf-preview 'eza -1 --color=always --icons $realpath'
