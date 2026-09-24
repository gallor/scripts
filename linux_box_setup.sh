#!/bin/bash

# NOTE: intentionally no `set -e`. This script is best-effort: a failing step is
# logged and we move on. Dependent steps are gated on their prerequisite's
# success via the ok_* flags below (run_step returns the wrapped command's rc).

SETUP_LOG="$HOME/linux_box_setup.log"
: > "$SETUP_LOG"

# Directory this script lives in, so we can call sibling scripts (link_dotfiles.sh)
# regardless of the caller's cwd.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Linux clone root for personal repos (macOS uses ~/Documents/code; Linux uses ~/code).
CODE_DIR="$HOME/code"
DOTFILES_DIR="$CODE_DIR/dotfiles"

# Ensure ~/.local/bin exists and is on PATH for the rest of this run (asdf, pipx,
# condax, gh, duckdb, etc. all land here).
mkdir -p ~/.local/bin "$CODE_DIR"
export PATH="$HOME/.local/bin:$PATH"

# run_step "description" cmd args...
# Runs the command, logging failures to $SETUP_LOG and returning its exit code
# so callers can gate dependent steps with `if run_step ...; then ...; fi`.
run_step() {
    local desc="$1"; shift
    echo "==> ${desc}"
    if "$@"; then
        return 0
    else
        local rc=$?
        echo "!! FAILED (rc=${rc}): ${desc}" | tee -a "$SETUP_LOG" >&2
        return "$rc"
    fi
}

printf '==================\nLinux box setup\n==================\n'

# ---------------------------------------------------------------------------
# APT packages
# Chain: apt update -> apt install. Skip install if update fails.
# Only packages available in the base Ubuntu repos go in this single install;
# repo-gated tools (gh, docker) and possibly-unavailable ones (eza) are isolated
# below so one missing package can't abort the whole batch.
# ---------------------------------------------------------------------------
if run_step "apt update" sudo apt update; then
    run_step "apt install base packages" sudo apt install -y \
        curl \
        ca-certificates \
        gnupg \
        zsh \
        bat \
        fd-find \
        git-all \
        git-lfs \
        virtualbox \
        trash-cli \
        vagrant \
        openssh-server \
        ripgrep \
        shellcheck \
        pandoc \
        htop \
        tree \
        tty-clock \
        screen \
        sshpass \
        build-essential \
        cmake \
        universal-ctags \
        unzip \
        fontconfig \
        glibc-source \
        xsel \
        net-tools \
        jq
fi
# Ubuntu ships these under alternate binary names; symlink to the expected ones.
[[ -x /usr/bin/batcat ]] && ln -sf /usr/bin/batcat ~/.local/bin/bat
[[ -x /usr/bin/fdfind ]] && ln -sf /usr/bin/fdfind ~/.local/bin/fd

run_step "git lfs install" git lfs install

# eza is only in the Ubuntu repos on 23.10+; isolate so a miss on 22.04 just logs.
run_step "apt install eza (unavailable pre-24.04)" sudo apt install -y eza

# ---------------------------------------------------------------------------
# GitHub CLI (gh)  -- official apt repo (keyring + repo, like Docker below)
# ---------------------------------------------------------------------------
echo "==> Installing GitHub CLI (gh)"
if run_step "Set up gh apt repo" bash -c '
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update'; then
    run_step "Install gh" sudo apt install -y gh
fi

# ---------------------------------------------------------------------------
# yq (YAML processor) -- via snap, matching the current box
# ---------------------------------------------------------------------------
if command -v snap >/dev/null 2>&1; then
    run_step "Install yq (snap)" sudo snap install yq
fi

# ---------------------------------------------------------------------------
# Dotfiles + zsh + antidote  (do this EARLY: link_dotfiles.sh symlinks the
# repo's .tool-versions and .condaxrc into $HOME, which asdf and condax below
# rely on to reproduce the exact toolchain / tool set.)
# ---------------------------------------------------------------------------
echo "==> Cloning dotfiles"
if [[ ! -d $DOTFILES_DIR ]]; then
    run_step "Clone dotfiles" git clone https://github.com/gallor/dotfiles.git "$DOTFILES_DIR"
fi

echo "==> Installing Antidote (zsh plugin manager)"
if [[ ! -d ~/.antidote ]]; then
    run_step "Clone antidote" git clone --depth=1 https://github.com/mattmc3/antidote.git "$HOME/.antidote"
fi

echo "==> Linking dotfiles"
if [[ -d $DOTFILES_DIR ]]; then
    # Run as a subprocess so a declined prompt (link_dotfiles.sh exits 2) doesn't
    # abort this script. link_dotfiles handles $HOME symlinks + nvim/ripgrep/zsh.
    bash "$SCRIPT_DIR/link_dotfiles.sh" "$DOTFILES_DIR"
else
    echo "!! Skipping dotfile linking (dotfiles not cloned)" | tee -a "$SETUP_LOG"
fi

echo "==> Setting zsh as the default shell"
if command -v zsh >/dev/null 2>&1; then
    run_step "chsh to zsh" chsh -s "$(command -v zsh)"
else
    echo "!! Skipping chsh (zsh not installed)" | tee -a "$SETUP_LOG"
fi

# ---------------------------------------------------------------------------
# Micromamba -> pipx (base env) -> condax + Python CLI tools
# Chain: each link depends on the previous.
# Micromamba is a standalone conda-env manager; no miniconda/base Python required.
# ---------------------------------------------------------------------------
export MAMBA_ROOT_PREFIX="${HOME}/micromamba"
export MAMBA_EXE="${HOME}/.local/bin/micromamba"
if run_step "Install Micromamba" bash -c "curl -Ls https://micro.mamba.pm/api/micromamba/\$(uname)-\$(uname -m)/latest | tar -xj -C ~/.local/bin --strip-components=1 bin/micromamba"; then
    # Persist shell init for future bash + zsh sessions, then load into this shell.
    "$MAMBA_EXE" shell init -s bash -r "$MAMBA_ROOT_PREFIX"
    "$MAMBA_EXE" shell init -s zsh -r "$MAMBA_ROOT_PREFIX"
    # shellcheck source=/dev/null
    eval "$("$MAMBA_EXE" shell hook -s posix)"

    if run_step "pipx install (base env)" "$MAMBA_EXE" install -y -n base -c conda-forge pipx; then
        # pipx-managed standalone CLI tools (dedicated venvs).
        for tool in ipython mypy pyright pytest coverage towncrier uv websockets-cli bpython pydoro; do
            run_step "pipx install ${tool}" "$MAMBA_EXE" run -n base pipx install "$tool"
        done

        # ipython: default to vi editing mode (dotfiles ships .ipython/ but the
        # profile dir isn't symlinked, so create the profile and append the setting).
        if run_step "ipython profile create" "$MAMBA_EXE" run -n base ipython profile create; then
            IPY_CFG="$HOME/.ipython/profile_default/ipython_config.py"
            if [[ -f $IPY_CFG ]] && ! grep -q "editing_mode = 'vi'" "$IPY_CFG"; then
                echo "c.TerminalInteractiveShell.editing_mode = 'vi'" >> "$IPY_CFG"
            fi
        fi

        # condax manages conda-packaged CLI tools in isolated envs (reads ~/.condaxrc
        # from the linked dotfiles, which points condax at micromamba as its backend).
        # `conda` is itself a condax-managed app here.
        if run_step "pipx install condax" "$MAMBA_EXE" run -n base pipx install condax; then
            for tool in conda black ruff isort cruft pre-commit nox conda-merge rattler-build; do
                run_step "condax install ${tool}" condax install "$tool"
            done
            # conda-build (pulls conda-index/conda-debug) enables `conda build`; it lives
            # inside the condax-managed conda env rather than as its own app.
            run_step "condax inject conda-build" condax inject conda conda-build
        fi
    fi
else
    echo "!! Skipping micromamba/pipx/condax (micromamba install failed)" | tee -a "$SETUP_LOG"
fi

# ---------------------------------------------------------------------------
# asdf (version manager) -> node / yarn / bun
# Replaces nvm. asdf 0.16+ is a standalone Go binary; tools resolve via
# ~/.asdf/shims on PATH. `asdf install` (no args) reads the ~/.tool-versions
# symlinked in from the dotfiles repo, reproducing the pinned versions.
# ---------------------------------------------------------------------------
echo "==> Installing asdf"
ASDF_VERSION="v0.18.0"
case "$(uname -m)" in
    x86_64|amd64) ASDF_ARCH="amd64" ;;
    aarch64|arm64) ASDF_ARCH="arm64" ;;
    *) ASDF_ARCH="amd64" ;;
esac
ASDF_OS="$(uname | tr '[:upper:]' '[:lower:]')"
ASDF_URL="https://github.com/asdf-vm/asdf/releases/download/${ASDF_VERSION}/asdf-${ASDF_VERSION}-${ASDF_OS}-${ASDF_ARCH}.tar.gz"
export ASDF_DATA_DIR="$HOME/.asdf"
if run_step "Download asdf" bash -c "curl -fL '${ASDF_URL}' | tar -xz -C ~/.local/bin asdf"; then
    chmod +x ~/.local/bin/asdf
    # Shims dir must be ahead of the rest of PATH for node/npm/yarn/bun to resolve.
    export PATH="${ASDF_DATA_DIR}/shims:$HOME/.local/bin:$PATH"
    if command -v asdf >/dev/null 2>&1; then
        run_step "asdf plugin add nodejs" asdf plugin add nodejs
        run_step "asdf plugin add yarn" asdf plugin add yarn
        run_step "asdf plugin add bun" asdf plugin add bun
        # Prefer the pinned ~/.tool-versions (from dotfiles); otherwise grab latest node.
        if [[ -f "$HOME/.tool-versions" ]]; then
            run_step "asdf install (pinned .tool-versions)" asdf install
        else
            if run_step "asdf install nodejs latest" asdf install nodejs latest; then
                run_step "asdf set nodejs latest" asdf set -u nodejs latest
            fi
        fi
        run_step "asdf reshim" asdf reshim
    else
        echo "!! Skipping node/yarn/bun (asdf did not load)" | tee -a "$SETUP_LOG"
    fi
fi

# ---------------------------------------------------------------------------
# Global npm packages (needs asdf node on PATH)
# ---------------------------------------------------------------------------
if command -v npm >/dev/null 2>&1; then
    for pkg in neovim instant-markdown-d @openai/codex typescript typescript-language-server wscat; do
        run_step "npm install -g ${pkg}" npm install -g "$pkg"
    done
    # New global bins need shims regenerated to be visible on PATH.
    command -v asdf >/dev/null 2>&1 && run_step "asdf reshim nodejs" asdf reshim nodejs
else
    echo "!! Skipping global npm packages (npm not on PATH)" | tee -a "$SETUP_LOG"
fi

# ---------------------------------------------------------------------------
# Rust toolchain (rustup) + cargo CLI tools
# ---------------------------------------------------------------------------
echo "==> Installing Rust (rustup)"
if run_step "Install rustup" bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"; then
    # shellcheck source=/dev/null
    [[ -s "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
    if command -v cargo >/dev/null 2>&1; then
        run_step "cargo install tree-sitter-cli" cargo install tree-sitter-cli
        run_step "cargo install pqrs" cargo install pqrs
    fi
fi

# ---------------------------------------------------------------------------
# fzf (fuzzy finder) -- git-clone install to ~/.fzf (also wires shell completion)
# ---------------------------------------------------------------------------
echo "==> Installing fzf"
if [[ ! -d ~/.fzf ]]; then
    run_step "Clone fzf" git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
fi
[[ -x ~/.fzf/install ]] && run_step "Run fzf install" ~/.fzf/install --all

# ---------------------------------------------------------------------------
# Neovim -> plug + PlugInstall + remote plugins
# Chain: PlugInstall only if nvim is present.
# ---------------------------------------------------------------------------
echo "==> Installing Neovim"
if command -v snap >/dev/null 2>&1; then
    run_step "Install neovim (snap)" sudo snap install nvim --classic
else
    if run_step "Download neovim appimage" curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage; then
        chmod +x nvim.appimage
        run_step "Install neovim appimage" sudo mv nvim.appimage /usr/local/bin/nvim
    fi
fi
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
run_step "pip pynvim" pip3 install --user pynvim
if command -v nvim >/dev/null 2>&1; then
    run_step "nvim PlugInstall" nvim --headless +PlugInstall +q
    run_step "nvim UpdateRemotePlugins" nvim --headless +UpdateRemotePlugins +q
else
    echo "!! Skipping PlugInstall (nvim not installed)" | tee -a "$SETUP_LOG"
fi

# ---------------------------------------------------------------------------
# Tmux plugin support (independent)
# ---------------------------------------------------------------------------
echo "==> Installing Tmux Plugin Support"
if [[ ! -d ~/.tmux/plugins/tpm ]]; then
    run_step "Clone tpm" git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi
if [[ ! -d "$CODE_DIR/tmux-bash-completion" ]]; then
    run_step "Clone tmux-bash-completion" git clone https://github.com/imomaliev/tmux-bash-completion.git "$CODE_DIR/tmux-bash-completion"
fi

echo "==> Installing VsCode SSH server"
run_step "Install openssh-server" sudo apt-get install -y openssh-server

# ---------------------------------------------------------------------------
# Docker
# Chain: keyring/repo -> install -> hello-world. Skip install if repo setup fails.
# ---------------------------------------------------------------------------
echo "Install Docker"
sudo apt-get remove -y docker docker-engine docker.io containerd runc
docker_repo_ok=1
if run_step "Set up Docker keyring" bash -c '
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg'; then
    # shellcheck disable=SC2016  # $() and $VERSION_CODENAME are meant to run on the remote shell, not expand now
    if run_step "Add Docker apt repo" bash -c '
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update'; then
        docker_repo_ok=0
    fi
fi
if [[ $docker_repo_ok -eq 0 ]]; then
    if run_step "Install Docker packages" sudo apt-get install -y \
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
        run_step "Docker hello-world" sudo docker run hello-world
    fi
else
    echo "!! Skipping Docker install (repo setup failed)" | tee -a "$SETUP_LOG"
fi

# ---------------------------------------------------------------------------
# DuckDB CLI (independent)
# ---------------------------------------------------------------------------
echo "==> Installing DuckDB"
run_step "Install DuckDB" bash -c "curl -fsSL https://install.duckdb.org | sh"

# ---------------------------------------------------------------------------
# Cursor CLI agent (independent)
# ---------------------------------------------------------------------------
echo "==> Installing Cursor CLI"
run_step "Install cursor-agent" bash -c "curl -fsS https://cursor.com/install | bash"

# ---------------------------------------------------------------------------
# Nerd Fonts (independent)
# ---------------------------------------------------------------------------
mkdir -p ~/.local/share/fonts
fonts_installed=1

echo "==> Install Nerd Font Inconsolata"
if run_step "Download Inconsolata Nerd Font" wget https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Inconsolata.zip -O Inconsolata.zip; then
    unzip Inconsolata.zip -d ~/.local/share/fonts
    rm -rf Inconsolata.zip
    fonts_installed=0
fi

echo "==> Install Nerd Font Fira Code"
if run_step "Download Fira Code Nerd Font" wget https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip -O FiraCode.zip; then
    unzip FiraCode.zip -d ~/.local/share/fonts
    rm -rf FiraCode.zip
    fonts_installed=0
fi

echo "==> Install Nerd Font Google Sans Code"
if run_step "Download Google Sans Code Nerd Font" wget https://github.com/wylu1037/google-sans-code-nerd-font/releases/latest/download/google-sans-code-nerd-font.zip -O google-sans-code-nerd-font.zip; then
    unzip google-sans-code-nerd-font.zip -d ~/.local/share/fonts
    rm -rf google-sans-code-nerd-font.zip
    fonts_installed=0
fi

[[ $fonts_installed -eq 0 ]] && fc-cache -fv

echo "done!"
if [[ -s "$SETUP_LOG" ]]; then
    echo "Some steps failed. See $SETUP_LOG:"
    cat "$SETUP_LOG"
fi
