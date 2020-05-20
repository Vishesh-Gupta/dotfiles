# dotfiles

## Contents
1. Intro
2. Vim
3. Tmux
3. VS Code
4. Contributing
5. FAQ!

## Intro
As a developer, everyone struggles in creating a nice development environment.
Development environments are based on the comfort of the user. Through this 
repoitory, one can experience my development environments.

### Vim

Vim is a popular text editor for a lot of developers. Vim is known to be very efficient once skilled at vim scripts, but it has a learning curve.

Vim settings are available in `~/.vim/`. The package manager used for Vim is Vundle.

Plugins being used:
1. Nerdtree - File System Display
2. Colorschemes - Better Color Schemes
3. Surround.Vim - Managing surroundings easily
4. YouCompleteMe - Auto syntax completions
5. Fugitive.Vim - Adds amazing Git commands
6. Vim-cpp-enhanced-highligts - Adds cpp highlighting
7. Vim-wakatime - Analysis of time spent on file types
8. Tagbar - Adds a tagbar to vim
9. Ctrlp.vim
10. Vimcompletesme
11. Vim-man - Adds man pages access to vim
12. Undotree - Descriptive undo history

Installation:
```sh
git clone https://github.com/Vishesh-gupta/dotfiles.git/vim ~/.vim | Vi +PluginInstall +qall
```
And congratulations you have a configuration setup.

### Tmux
Tmux stands for terminal multiplexer and has some really interesting features.

Installation:

```sh
cd ~/
wget https://github.com/Vishesh-gupta/dotfiles.git/tree/master/.tmux/.tmux.conf
source .tmux.conf
```

### VSCode
VSCode - Visual Studio Code - a text editor by Microsoft. Became extremely popular in last few years. 

List of extensions recommended:
1. Intellisense - Intelligent syntax highlight and management for each language
2. Better Comments - Make commenting easier and cleaner
3. Remote-SSH - Ease in connecting to SSH server instances
4. Remote-WSL - Extension for windows users to connect to WSL
5. VSCode-Icons - Icon pack for cleaner looking icons
6. VimBinding - Add Vim bindings to VSCode
7. MathSnippets - Adds math snippets such as
8. SFTP- File syncing extension to remote

