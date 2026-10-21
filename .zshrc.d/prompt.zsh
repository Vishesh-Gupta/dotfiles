# Prompt setup. Config lives in ~/.config/starship.toml.

if (( _use_fancy_shell )) && (( $+commands[starship] )); then
  eval "$(starship init zsh)"
fi
