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

echo "Installing Micromamba, conda, condax, and pipx"
mkdir -f ~/.local/bin
curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba
./micromamba shell init -s zsh -r ~/micromamba
source ~/.zshrc
echo "conda_executable: \"$HOME/.local/bin/micromamba\"" > $HOME/.condaxrc
micromamba create -y -n condax-toolenv condax -c conda-forge
echo -e '#!/bin/bash\micromamba run -n condax-toolenv condax $@' > ~/.local/bin/condax && chmod +x ~/.local/bin/condax
condax install conda
conda install -y -n base conda-build
condax install cruft -c conda-forge
condax install pre-commit -c conda-forge
condax install rattler-build
condax install pipx -c conda-forge

echo "===> Install Nvim Plugins"
# Install Nvim Plugins
npm install -g neovim
npm install -g instant-markdown-d
nvim -c PlugInstall -c q -c q
nvim -c UpdateRemotePlugins -c q

echo "===> Installing Inconsolata Nerd Font"
# Nerd Font
wget https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Inconsolata.zip -O Inconsolata.zip
unzip Inconsolata.zip -d ~/Library/Fonts
rm -rf Inconsolata.zip

echo "===> Downloading Dracula for ITerm"
wget https://github.com/dracula/iterm/archive/refs/heads/master.zip -O ~/Desktop/Dracula.zip

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

echo "===> Installing Rust"
curl https://sh.rustup.rs -sSf | sh

source ~/.zshrc
