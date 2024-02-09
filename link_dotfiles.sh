#!/bin/bash

DIRECTORY=$0
if [[ -z $DIRECTORY ]]; then
    echo "Valid directory of dotfiles must be provided
    Using Default directory of $HOME/Documents/code/dotfiles
    "
    DIRECTORY="$HOME/Documents/code/dotfiles"
fi
echo "Using dotfiles in $HOME"

read confirm -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1
echo ""
if [[ $confirm =~ ^[Yy]$ ]]; then
    syncDotfiles
    syncNeovimAndRG
fi;

function syncDotfiles() {
    read -p
    FILES="$(ls -a $DIRECTORY)"
    echo $FILES
    for f in $FILES; do
    if [[ -d $f ]]; then
      echo "Directory $f, skipping"
    else
        ln -s $DIRECTORY/$f $HOME/$f
	echo "Linked $f"
    fi
    done
}

function syncNeovimAndRG() {
    if [[ ! -d ~/.config ]]; then
        mkdir -p ~/.config
    fi
    ln -s $DIRECTORY/nvim $HOME/.config/nvm
    ln -s $DIRECTORY/ripgrep $HOME/.confg/ripgrp
}



unset syncDotFiles;
unset syncNeovimAndRG;
