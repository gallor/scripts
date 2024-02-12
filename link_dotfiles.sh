#!/bin/bash

DIRECTORY=$1

function syncDotfiles() {
    FILES="$(ls -a $DIRECTORY)"
    echo $FILES
    for f in $FILES; do
        if [[ $f == ".." || $f == "." ]]; then
            echo "Skipping folder navigation"
        elif [[ -d $DIRECTORY/$f ]]; then
            echo "Directory $f, skipping"
        else
            ln -s $DIRECTORY/$f $HOME/$f
            echo "Linked $f"
        fi
    done
}

function syncNeovimAndRG() {
    if [[ ! -d ~/.config ]]; then
        mkdir -p $HOME/.config
    fi
    ln -s $DIRECTORY/nvim $HOME/.config/nvm
    ln -s $DIRECTORY/ripgrep $HOME/.confg/ripgrp
}
if [[ -z $DIRECTORY ]]; then
    echo "Valid directory of dotfiles must be provided
Using Default directory of $HOME/Documents/code/dotfiles"
    DIRECTORY="$HOME/Documents/code/dotfiles"
fi
echo "Using dotfiles in $DIRECTORY"

read -n 1 -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " confirm
if [[ $confirm =~ ^[Yy]$ ]]; then
    syncDotfiles
    syncNeovimAndRG
else
    exit 2
fi;

unset syncDotFiles;
unset syncNeovimAndRG;
