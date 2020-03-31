# dotfiles

## Contents
1. Intro
2. Vim
3. VSCode


## Intro
As a developer, everyone struggles in creating a nice development environment. One gets confused in what is a good way of setting their IDE, text editor or computer in general. Personally, have faced lots of challenges doing this so this repository should help in setting basic custom environments.

### Vim

Vim settings are available in `~/.vim/`. The package manager used for Vim is Vundle.

Plugins being used:
1. Vundle - Package manager
2. Nerdtree - File System Display
3. Colorschemes - Better Color Schemes
4. Surround.Vim - Managing surroundings easily
5. YouCompleteMe - Auto syntax completions
6. Fugitive.Vim - Adds amazing Git commands

Installation:
```sh
git clone https://github.com/Vishesh-gupta/dotfiles.git/vim ~/.vim | Vi +PluginInstall +qall
```
And congratulations you have a configuration setup.


### VSCode
VSCode - Visual Studio Code - a text editor by Microsoft. Became extremelly popular in last few years. 

List of extensions recommended:
1. Intellisense - Intelligent syntax highlight and management for each language
2. Better Comments - Make commenting easier and cleaner
3. Remote-SSH - Ease in connecting to SSH server instances
4. Remote-WSL - Extension for windows users to connect to WSL
5. VSCode-Icons - Icon pack for cleaner looking icons
6. VimBinding - Add Vim bindings to VSCode

