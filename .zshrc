# Keep this file intentionally slim. Functional config lives in ~/.zshrc.d/*.zsh.

source "$HOME/.zshrc.d/env.zsh"
source "$HOME/.zshrc.d/oh-my-zsh.zsh"
source "$HOME/.zshrc.d/prompt.zsh"
source "$HOME/.zshrc.d/tools.zsh"
source "$HOME/.zshrc.d/functions.zsh"
source "$HOME/.zshrc.d/aliases.zsh"

# Machine-specific settings that should not live in the repo.
if [[ -r "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi
