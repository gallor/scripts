# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal machine-provisioning scripts (bash) for setting up a fresh macOS or Linux
development box. There is no build, no test suite, and no package manifest — the
"artifacts" are the shell scripts themselves, run once on a new machine. Changes are
validated by running the script on an actual new/clean box, not by CI.

## Entry points and how the scripts relate

The two setup scripts are **platform-specific and mutually exclusive** — pick one per box:

- `new_computer.sh` — **macOS** bootstrap (Homebrew world). This is the orchestrator:
  it creates `~/Documents/code`, clones `gallor/scripts` and `gallor/dotfiles` there,
  runs `brew bundle` against the `Brewfile`, then **sources** `link_dotfiles.sh` to
  symlink dotfiles, and finally installs the non-brew toolchain (vim-plug, antidote,
  nvm, miniforge/condax, nerd fonts, tmux tpm, pipx tools). `-s` skips the
  Homebrew/clone/bundle prelude (for re-running the post-brew steps on an already
  cloned box).
- `linux_box_setup.sh` — **Linux (apt/Ubuntu)** counterpart. Standalone and does *not*
  use the Brewfile; it apt-installs the equivalent tooling, generates an SSH keypair and
  pushes it to a remote box. Unlike the macOS orchestrator it clones the `gallor/dotfiles`
  repo into `~/code/dotfiles`, runs `link_dotfiles.sh`, installs antidote, and `chsh`es to
  zsh itself. Toolchain: **asdf** (node/yarn/bun, pinned via the dotfiles' `.tool-versions`;
  replaces nvm), micromamba + pipx + condax (black/ruff/isort/etc.), Rust (rustup), gh, yq,
  fzf, duckdb, cursor-agent, Docker/Compose, neovim + plugins, nerd fonts, tmux tpm. It
  duplicates much of `new_computer.sh`'s intent via `apt` instead of `brew`. Note the Linux
  clone root is `~/code` (macOS uses `~/Documents/code`).

Supporting pieces:

- `Brewfile` — declarative macOS package/cask list consumed by `brew bundle` (invoked
  from `new_computer.sh`). Edit this to change what a macOS box installs.
- `link_dotfiles.sh` — symlinks dotfiles into `$HOME`. Takes the dotfiles dir as `$1`
  (defaults to `~/Documents/code/dotfiles`). Top-level files are symlinked into `$HOME`;
  the `ripgrep` and `zsh` directories are special-cased into `~/.config` / `~/.zsh`.
  Neovim is deliberately NOT linked here — the nvim config is the separate
  `gallor/kickstart.nvim` fork (lazy.nvim, Lua), which the setup scripts clone and
  symlink to `~/.config/nvim` themselves.
  **Depends on the separate `gallor/dotfiles` repo** — that repo's layout (a `zsh/.zshrc`,
  `ripgrep/` dir) is an implicit contract this script relies on.
- Neovim config lives in the **`gallor/kickstart.nvim`** repo (branch `personal-updates`),
  not the dotfiles repo. `new_computer.sh`/`linux_box_setup.sh` clone it and run
  `nvim --headless "+Lazy! sync" +qa`; there is no vim-plug anymore.
- `gitrepo.sh` — unrelated standalone utility (not part of box setup): fetches a GitHub
  repo's latest release, uses `fzf` to pick an asset (optionally `-f` filtered), and
  `wget`s it. `-z`/`-t` grab the zipball/tarball instead. Requires `fzf` and `jq`.

## Conventions when editing

- These scripts assume `~/Documents/code` as the clone root on macOS. `link_dotfiles.sh`
  and `new_computer.sh` share that path assumption — keep them in sync if you change it.
- `new_computer.sh` runs under `set -e`; `linux_box_setup.sh` does not, so a failing step
  there is silently skipped. Account for this when adding steps.
- macOS changes usually need a matching change in both `new_computer.sh` and the
  `Brewfile`; the Linux equivalent lives in `linux_box_setup.sh` via `apt`.
