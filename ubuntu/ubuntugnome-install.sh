#!/usr/bin/env bash

###############################################################################
##                       Ubuntu Post Install Script                          ##
##                                                                           ##
## Script to set up UbuntuGnome dev environment customized to my liking.     ##
## You will probably not like this. Feel free to run anyway.                 ##
## Thanks to Eric Crosson for the reporter function.                         ##
##                                                                           ##
###############################################################################

set -e

INSTALL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Turn comments into literal programming, including output during execution.
function reporter() {
  message="$1"
  shift
  echo
  echo "${message}"
  for (( i=0; i<${#message}; i++ )); do
      echo -n '-'
  done
  echo
}

function main() {
  reporter "Checking for curl"
  if [ $(dpkg-query -W -f='${Status}' curl 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    sudo apt-get -y install curl;
  fi

  reporter "Confirming internet connection"
  if [[ ! $(curl -Is http://www.google.com/ | head -n 1) =~ "200 OK" ]]; then
    echo "Your Internet seems broken. Press Ctrl-C to abort or enter to continue."
    read
  else
    echo "Connection successful"
  fi

  reporter "Upgrading existing packages"
  sudo apt-get -qq -y upgrade

  reporter "Removing bloat packages"
  xargs sudo apt-get -qq -y purge < $INSTALL_DIR/data/bloat.list

  reporter "Removing orphaned packages"
  sudo apt-get -qq autoremove

  reporter "Adding dependent ppas"
  xargs -L1 sudo add-apt-repository < $INSTALL_DIR/data/ppa.list

  reporter "Updating apt-cache"
  sudo apt-get -qq -y update

  reporter "Installing dependendent packages"
  xargs sudo apt-get -qq -y install < $INSTALL_DIR/data/dependencies.list

  reporter "Installing apt packages"
  xargs sudo apt-get -qq -y install < $INSTALL_DIR/data/apt.list

  reporter "Installing pip packages"
  sudo pip install -qr $INSTALL_DIR/data/pip.list

  reporter "Installing Google Play Music desktop app"
  wget -q "https://github.com/MarshallOfSound/Google-Play-Music-Desktop-Player-UNOFFICIAL-/releases/download/v4.0.5/google-play-music-desktop-player_4.0.5_amd64.deb" -P /tmp/googleplay
  sudo dpkg -i /tmp/googleplay/google*
  sudo apt-get install -f

  reporter "Installing oh-my-zsh"
  current_user=$(whoami)
  sudo usermod -s /usr/bin/zsh $current_user
  sudo sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh | grep -Ev 'chsh -s|env zsh')"

  reporter "Removing old config files"
  old_configs=".bash_profile .bash_rc .zshrc .vimrc .vim .gitconfig"
  for config in ${old_configs}; do
      rm -rf $HOME/${config}
  done

  reporter "Cloning zsh-syntax-highlighting"
  mkdir $HOME/dev; mkdir $HOME/dev/utils;
  syntax_dir=$HOME/dev/utils/zsh-syntax-highlighting
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${syntax_dir}

  reporter "Grabbing and stowing dotfiles"
  dotfiles_repo=https://github.com/CullenTaylor/dotfiles.git
  dotfiles_destination=$HOME/dotfiles
  dotfiles_branch=master
  stow_list="bash git htop vim zsh sounds"

  git clone ${dotfiles_repo} ${dotfiles_destination}
  cd ${dotfiles_destination}
  git checkout ${dotfiles_branch}
  for app in ${stow_list}; do
      stow ${app}
  done
  cd ${HOME}

  reporter "Generating user RSA keys"
  ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa

  echo "Done! Reboot to finish"
}

main "$@"
