#!/bin/bash

set -euo pipefail

SKIP=''

while getopts "s" o; do
case $o in
    s)
        SKIP="true"
        ;;
    *)
        echo "Usage: new_computer.sh [-s]  (-s skips the Homebrew/clone/bundle prelude)"
        exit 2
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

  # Put brew on PATH for the rest of this script (Apple Silicon, then Intel fallback).
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  brew install git

  [[ -d scripts ]] || git clone https://github.com/gallor/scripts.git
  [[ -d dotfiles ]] || git clone https://github.com/gallor/dotfiles.git
  cd ~/Documents/code/scripts
  brew bundle
  brew upgrade
fi

echo "===> Linking Dotfiles"
chmod +x ~/Documents/code/scripts/link_dotfiles.sh
# Run as a subprocess so a declined prompt (exit 2) doesn't abort this script.
bash ~/Documents/code/scripts/link_dotfiles.sh ~/Documents/code/dotfiles

echo "===> Installing kickstart.nvim"
# Config: clone the kickstart fork and point ~/.config/nvim at it (lazy.nvim manages plugins).
if [[ ! -d ~/Documents/code/kickstart.nvim ]]; then
  git clone -b personal-updates https://github.com/gallor/kickstart.nvim.git ~/Documents/code/kickstart.nvim
fi
mkdir -p ~/.config
ln -sfn ~/Documents/code/kickstart.nvim ~/.config/nvim

# Antidote
echo "===> Installing Antidote"
[[ -d "${ZDOTDIR:-$HOME}/.antidote" ]] || git clone --depth=1 https://github.com/mattmc3/antidote.git "${ZDOTDIR:-$HOME}/.antidote"

echo "===> Installing Node via asdf"
# asdf is installed via the Brewfile; it manages node/yarn/bun with versions pinned
# in the dotfiles' ~/.tool-versions (linked above). Mirrors linux_box_setup.sh so the
# mac and linux boxes share one toolchain manager.
export ASDF_DATA_DIR="$HOME/.asdf"
export PATH="${ASDF_DATA_DIR}/shims:$PATH"
if command -v asdf >/dev/null 2>&1; then
  asdf plugin add nodejs || true
  asdf plugin add yarn || true
  asdf plugin add bun || true
  # Prefer the pinned ~/.tool-versions (from dotfiles); otherwise grab latest node.
  if [[ -f "$HOME/.tool-versions" ]]; then
    asdf install
  else
    asdf install nodejs latest && asdf set -u nodejs latest
  fi
  asdf reshim
else
  echo "!! asdf not found on PATH; skipping node/yarn/bun (did brew bundle run?)"
fi

echo "===> Installing Micromamba"
# Micromamba (standalone conda-env manager; no miniconda/base Python required).
export MAMBA_ROOT_PREFIX="${HOME}/micromamba"
mkdir -p ~/.local/bin
# Auto-detects platform via uname (Darwin-arm64 / Darwin-x86_64).
curl -Ls "https://micro.mamba.pm/api/micromamba/$(uname)-$(uname -m)/latest" \
  | tar -xj -C ~/.local/bin --strip-components=1 bin/micromamba
export MAMBA_EXE="${HOME}/.local/bin/micromamba"
# Persist shell init for future zsh sessions, then load into this shell.
"$MAMBA_EXE" shell init -s zsh -r "$MAMBA_ROOT_PREFIX"
# shellcheck source=/dev/null
eval "$("$MAMBA_EXE" shell hook -s posix)"

# pipx lives in the (empty) base env; micromamba has no default packages.
"$MAMBA_EXE" install -y -n base -c conda-forge pipx
# Function (not alias) so it works in this non-interactive script.
pipx() { "$MAMBA_EXE" run -n base pipx "$@"; }

echo "===> Installing condax + conda"
# condax lives in its own micromamba env, exposed via a thin wrapper on PATH.
# (.condaxrc is provided by the dotfiles and points condax at micromamba.)
"$MAMBA_EXE" create -y -n condax-toolenv condax -c conda-forge
printf '#!/bin/bash\n%s run -n condax-toolenv condax "$@"\n' "$MAMBA_EXE" > ~/.local/bin/condax
chmod +x ~/.local/bin/condax
condax install conda
# conda-build (enables `conda build`) lives inside the condax-managed conda env.
condax inject conda conda-build
condax install cruft -c conda-forge
condax install pre-commit -c conda-forge
condax install rattler-build
condax install pipx -c conda-forge

echo "===> Installing Nvim providers + plugins"
# Optional node provider for :checkhealth (kickstart works without it).
npm install -g neovim
# Regenerate asdf shims so the new global node bins resolve on PATH.
command -v asdf >/dev/null 2>&1 && asdf reshim nodejs
# Install plugins headlessly via lazy.nvim.
nvim --headless "+Lazy! sync" +qa

echo "===> Installing Inconsolata Nerd Font"
# Nerd Font
wget https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Inconsolata.zip -O Inconsolata.zip
unzip Inconsolata.zip -d ~/Library/Fonts
rm -rf Inconsolata.zip

echo "===> Installing Fira Code Nerd Font"
wget https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip -O FiraCode.zip
unzip FiraCode.zip -d ~/Library/Fonts
rm -rf FiraCode.zip

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
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

echo "===> Installing Rust"
curl https://sh.rustup.rs -sSf | sh
