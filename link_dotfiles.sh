#!/usr/bin/bash

SCRIPT=$(realpath -s "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

function syncDotfiles() {
    FILES="$(ls -a)"
    echo $FILES
    for f in $FILES; do
    if [ -d $f ]; then
      echo "Directory ${f}, skipping"
    else
      if [ $f != "setup.sh" ]; then
        ln -s ${SCRIPTPATH}/${f} ${HOME}/$f
      fi
    fi
    done
}

function syncNeovimAndRG() {
    if [[ ! -d ~/.config ]]; then
        mkdir -p ~/.config
    fi
    ln -s ${SCRIPTPATH}/nvim ${HOME}/.config/nvm
    ln -s ${SCRIPTPATH}/ripgrep ${HOME}/.confg/ripgrp
}

if [ "$1" == "--force" -o "$1" == "-f" ]; then
	syncDotfiles;
	syncNeovimAndRG;
else
    read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1;
    echo "";
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      syncDotfiles;
      syncNeovimAndRG;
    fi;
fi;


unset doIt;
unset syncNeovim;
