#!/bin/bash

# Define Colors
NOCOLOR='\033[0m'
BLACK='\033[30m'
WHITE='\033[1;37m'
RED='\033[0;31m'
LIGHTRED='\033[1;31m'
GREEN='\033[0;32m'
LIGHTGREEN='\033[1;32m'
ORANGE='\033[0;33m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
LIGHTBLUE='\033[1;34m'
PURPLE='\033[0;35m'
LIGHTPURPLE='\033[1;35m'
CYAN='\033[0;36m'
LIGHTCYAN='\033[1;36m'
LIGHTGRAY='\033[0;37m'
DARKGRAY='\033[1;30m'

# Going to user home directory
cd $HOME

# Download oh-my-zsh from GitHub
sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
echo -e "${GREEN}oh-my-zsh installed sucessfuly, please change your default shell to ${LIGHTRED}zsh${NOCOLOR}"

# Config oh-my-zsh theme to p10k
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM//themes/powerlevel10k
sed -i '/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k/powerlevel10k"/g' $HOME/.zshrc

echo -e "${BLUE}To use all features it's better to install MesloLGS NF fonts from --> ${LIGHTRED}'https://github.com/romkatv/powerlevel10k#fonts' ${BLUE}and setup to your terminal application from settings.${NOCOLOR}"

# oh-my-zsh plugins
git clone https://github.com/zsh-users/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git $ZSH_CUSTOM/plugins/fast-syntax-highlighting
git clone https://github.com/arzzen/calc.plugin.zsh.git $ZSH_CUSTOM/plugins/calc
sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting virtualenvwrapper kubectl docker docker-compose history emoji encode64 sudo web-search copypath copyfile copybuffer dirhistory jsontools pip node npm calc)/g' $HOME/.zshrc

# Config ssh-connect
git clone --recursive https://github.com/gko/ssh-connect $ZSH_CUSTOM/plugins/ssh-connect
echo "source $ZSH/custom/plugins/ssh-connect/ssh-connect.sh" >> $HOME/.zshrc

# Switch to colorls
if ! lsd; then
  # Colorls is based on ruby. So we try to install ruby.
  if ! sudo apt install lsd -y; then
    echo "lsd cannot be installed!";
  else
    # Retrying to install colorls with ruby package manager
    sudo gem install colorls;
  fi
elif ! mcdu; then
  if ! sudo apt install mcdu -y; then
    echo "mcdu is not available!";
elif ! bat; then
  if ! sudo apt install bat -y; then
    echo "bat is not available!";
else
  # Set alias and export to user zsh default
  echo "source $(dirname $(gem which colorls))/tab_complete.sh" >> $HOME/.zshrc
  echo "alias ls='lsd'" >> $HOME/.zshrc
  echo "alias tree='lsd --tree'" >> $HOME/.zshrc
  echo "alias treed='lsd --tree --depth'" >> $HOME/.zshrc
  echo 'alias lsdu="du -a -h --max-depth=1 | sort -hr"' >> $HOME/.zshrc
  echo 'alias du="ncdu"' >> $HOME/.zshrc
  echo "alias vim='lvim'" >> $HOME/.zshrc
fi

  
# Install LunarVim 
LV_BRANCH='release-1.4/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh)

# Deactive relative line number in SpaceVim
sed -i '25 a \\ \ \ \ relativenumber = false' $HOME/.SpaceVim.d/init.toml

# Creating aliast
echo "printcsv() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: printcsv <filename>"
        return 1
    fi

    if [ -f "$1" ]; then
        cat "$1" | column -t -s,
    else
        echo "Error: File '$1' not found."
        return 1
    fi
}" >> $HOME/.zshrc


