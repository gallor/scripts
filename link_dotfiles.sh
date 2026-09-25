#!/bin/bash

set -euo pipefail

DIRECTORY=${1:-}

function syncDotfiles() {
    shopt -s dotglob nullglob
    for f in "$DIRECTORY"/*; do
        base=$(basename "$f")
        if [[ -d $f ]]; then
            echo "Directory $base, skipping"
        else
            ln -sf "$f" "$HOME/$base"
            echo "Linked $base"
        fi
    done
    shopt -u dotglob nullglob
}

function syncNeovimRGAndZsh() {
    if [[ ! -d $HOME/.config ]]; then
        mkdir -p "$HOME/.config"
    fi
    ln -sfn "$DIRECTORY/nvim" "$HOME/.config/nvim"
    ln -sfn "$DIRECTORY/ripgrep" "$HOME/.config/ripgrep"
    ln -sfn "$DIRECTORY/zsh" "$HOME/.zsh"
}

function setupCompletion() {
    ln -sf "$DIRECTORY/zsh/.zshrc" "$HOME/.zshrc"
    ln -sf "$DIRECTORY/zsh/.zshenv" "$HOME/.zshenv"
}

if [[ -z $DIRECTORY ]]; then
    echo "Valid directory of dotfiles must be provided
Using Default directory of $HOME/Documents/code/dotfiles"
    DIRECTORY="$HOME/Documents/code/dotfiles"
fi
echo "Using dotfiles in $DIRECTORY"

read -r -n 1 -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " confirm
echo
if [[ $confirm =~ ^[Yy]$ ]]; then
    syncDotfiles
    syncNeovimRGAndZsh
    setupCompletion
else
    exit 2
fi

unset -f syncDotfiles syncNeovimRGAndZsh setupCompletion
