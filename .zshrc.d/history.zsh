# History. Loaded after Oh My Zsh so these settings win.

HISTSIZE=100000
SAVEHIST=100000

setopt extended_history       # record timestamps
setopt share_history          # share history across open shells
setopt hist_ignore_all_dups   # drop older duplicates of a command
setopt hist_save_no_dups
setopt hist_ignore_space      # commands starting with a space are not saved
setopt hist_reduce_blanks
setopt hist_verify            # show !! expansions before running them
