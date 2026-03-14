# Keep this file intentionally slim. Functional config lives in ~/.zshrc.d/*.zsh.

# Enable Powerlevel10k instant prompt near the top of .zshrc.
if [[ -o interactive ]] && [[ "${TERM:-}" != "dumb" ]] && [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source "$HOME/.zshrc.d/env.zsh"
source "$HOME/.zshrc.d/oh-my-zsh.zsh"
source "$HOME/.zshrc.d/prompt.zsh"
source "$HOME/.zshrc.d/tools.zsh"
source "$HOME/.zshrc.d/functions.zsh"
source "$HOME/.zshrc.d/aliases.zsh"
source "$HOME/.zshrc.d/startup.zsh"
