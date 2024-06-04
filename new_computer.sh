#!/bin/bash

set -e

SKIP=''

while getopts "s" o; do
case $o in
    s)
        SKIP="true"
        ;;
    esac
done

if [[ ! -d ~/Documents/code ]]; then
  mkdir ~/Documents/code
fi
cd ~/Documents/code

if [[ -z $SKIP ]]; then
# Homebrew
  echo "===> Install Homebrew and brewing Git"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  brew install git

  git clone https://github.com/gallor/scripts.git
  git clone https://github.com/gallor/dotfiles.git
  cd ~/Documents/code/scripts
  brew bundle
  brew upgrade
fi

echo "===> Linking Dotfiles"
chmod +x ~/Documents/code/scripts/link_dotfiles.sh
. ~/Documents/code/scripts/link_dotfiles.sh ~/Documents/code/dotfiles

echo "===> Installing VimPlug"
# Vim Plug
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
pip3 install pynvim

# Antidote
echo "===> Installing Antidote"
git clone --depth=1 https://github.com/mattmc3/antidote.git ${ZDOTDIR:-~}/.antidote

echo "===> Installing NVM"
# NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.zshrc
nvm install node

echo "===> Installing Miniforge"
# Conda/MiniForge
curl -fsSLo Miniforge3.sh "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-$(uname -m).sh"
bash Miniforge3.sh -b -p "${HOME}/conda"
rm -rf Miniforge3.sh
source "${HOME}/conda/etc/profile.d/conda.sh"
source "${HOME}/conda/etc/profile.d/mamba.sh"

source ~/.zshrc

mamba install -c conda-forge -n base condax
conda activate base
mkdir -p ~/.local/bin && ln -s $(which condax) ~/.local/bin/condax
condax install -c conda-forge pipx
 Plugins
echo "===> Install Nvim Plugins"
# Install Nvim Plugins
npm install -g neovim
npm install -g instant-markdown-d
nvim -c PlugInstall -c q -c UpdateRemotePlugins -c q

echo "===> Installing Inconsolata Nerd Font"
# Nerd Font
wget https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Inconsolata.zip -O Inconsolata.zip
unzip Inconsolata.zip -d ~/Library/Fonts
rm -rf Inconsolata.zip

echo ""
echo "If key repeat is not working in VSCode, run this command then restart VSCode:
defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false
defaults write -g ApplePressAndHoldEnabled -bool false
"
echo ""

echo "===> Installing Pydoro"
# Global Pip Packages
pipx install pydoro
pip3 install "pydoro[audio]"


echo "===> Installing iPython"
pipx install ipython
ipython profile create
echo "c.TerminalInteractiveShell.editing_mode = 'vi'" >> ~/.ipython/profile_default/ipython_config.py

echo "===> Installing Tmux Plugins"
if [[ ! -d ~/.tmux/plugins/tpm ]]; then
  mkdir -p ~/.tmux/plugins/tpm
fi
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm


zplug install
source ~/.zshrc
