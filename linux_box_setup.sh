#!/bin/bash

echo "==================\nLinux box setup\n=================="

echo "Creating ssh keypair"
read -p "Box URL/IP:" URL
read -p "User:" USER
read -p "Desired SSH filename [id_ssh]:" FILENAME
read -p "Desired SSH shortcut name:" SHORTCUT
DEFAULT_FILENAME='id_rsa'
SSH_FILENAME=${FILENAME:-DEFAULT_FILENAME}

ssh-keygen -o -t ed25519 -a 100 -f $SSH_FILENAME
scp '${SSH_FILENAME}.pub' $USER@$URL:~

mv $SSH_FILENAME ~/.ssh/
mv "${SSH_FILENAME}.pub" ~/.ssh/

ssh $USER@$URL 'mkdir ~/.ssh; touch ~/.ssh/authorized_keys;\
    chmod 700 ~/.ssh/authorized_keys;\
    mv ${SSH_FILENAME}.pub ~/.ssh/;\
    cat ~/.ssh/${SSH_FILENAME}.pub >> ~/.ssh/authorized_keys'

cat << EOF >> ~/.ssh/config
host ${SHORTCUT}
    Hostname ${URL}
    User ${USER}
    ForwardX11 yes
    ForwardX11Trusted yes
    IdentityFile ~/.ssh/${SSH_FILENAME}
EOF

sudo apt update
sudo apt install \
    curl \
    ca-certificates \
    gnupg \
    bat \
    fzf \
    git-all \
    virtualbox \
    trash-cli \
    vagrant-y \
    openssh-server \
    ripgrep \
    glibc-source \
    xsel \
    net-tools \
    jq \
    -y
mkdir -p ~/.local/bin
ln -s /usr/bin/batcat ~/.local/bin/bat

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash

curl -sL \
  "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh" > \
  "Miniconda3.sh"
bash Miniconda.sh -b
rm -rf MiniConda.sh

if [[ $(which conda) ]]; then
    conda install mamba -n base -c conda-forge
fi


echo "==> Setting up Fzf Bash complete"
if [[ ! -d ~/.local/opt/fzf-obc ]]; then
  mkdir -p ~/.local/opt/fzf-obc
fi
INSTALL_PATH=~/.local/opt/fzf-obc
git clone https://github.com/rockandska/fzf-obc ${INSTALL_PATH}


echo "==> Installing NVM"
curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
source ~/.bashrc
nvim install --lts
npm install --global yarn

echo "==> Installing Neovim"
if [[${which snap}]]; then
    sudo snap install nvim --classic
else
     curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage;
     mv nvim.appimage /usr/local/bin/nvim
fi
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
nvim --headless +PlugInstall +q

echo "==> Installing Tmux Plugin Support"
if [[ ! -d ~/.tmux/plugins/tpm ]]; then
  mkdir -p ~/.tmux/plugins/tpm
fi
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
git clone git@github.com:imomaliev/tmux-bash-completion.git ../tmux-bash-completion

echo "==> Installing VsCode SSH"
sudo apt-get install openssh-server

echo "==> Installing Python Neovim support"
pip install --user neovim
yarn global add neovim

# set up docker
echo "Install Docker"
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo docker run hello-world

# Docket Compose
echo "Install Docker Compose"
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Nerd Font
echo "[-] Install Nerd Font Inconsolata [-]"
echo "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/inconsolata.zip"
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/inconsolata.zip
if [[ ! -d ~/.local/share/fonts ]]; then
    mkdir -p ~/.local/share/fonts
fi
unzip inconsolata.zip -d ~/.local/share/fonts
rm -rf inconsolata.zip
fc-cache -fv
echo "done!"
