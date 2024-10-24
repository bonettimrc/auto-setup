#!/bin/bash

# Installation functions
aptInstall(){
  # Installs all needed programs from main repo
	sudo apt-get install "$1" --yes
}
gitInstall(){
  repository=$(jq --raw-output ".[] | select(.name==\"$1\") | .url" programs.json)
  programName="${repository##*/}"
  directory="$repositories_directory/$programName"
  git clone $repository $directory
  dependencies=($(jq --raw-output ".[] | select(.name==\"$1\") | .dependencies | .[]" programs.json))
  sudo apt-get install "${dependencies[@]}" --yes
  make --directory=$directory
  sudo make install --directory=$directory
}
wgetInstall(){
  file="$binaries_directory/$1.deb"
  url=$(jq --raw-output ".[] | select(.name==\"$1\") | .url" programs.json)
  wget $url --output-document="$file"
  sudo apt install "$file" --yes
}
complicatedInstall(){
  case $1 in
    "docker")
      # Install packages to allow apt to use a repository over HTTPS:
      sudo apt-get install ca-certificates curl gnupg lsb-release
      # Add Docker’s official GPG key:
      sudo mkdir "/etc/apt/keyrings" --parents
      curl "https://download.docker.com/linux/debian/gpg" --fail --silent --location| sudo gpg --dearmor -o "/etc/apt/keyrings/docker.gpg"
      sudo chmod a+r "/etc/apt/keyrings/docker.gpg"
      # Setup a repository
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee "/etc/apt/sources.list.d/docker.list" > /dev/null
      # Install docker engine
      sudo apt-get update
      sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin
      ;;
    "minegrub")
      directory="$repositories_directory/minegrub"
      git clone https://github.com/Lxtharia/minegrub-theme.git $directory
      sudo mkdir /boot/grub/themes/minegrub
      sudo cp --recursive --update --verbose $directory/minegrub /boot/grub/themes/
      echo "GRUB_TIMEOUT_STYLE=menu" | sudo tee --append /etc/default/grub
      echo "GRUB_THEME=/boot/grub/themes/minegrub/theme.txt" | sudo tee --append /etc/default/grub
      sudo update-grub
      ;;
    "neovim")
      # see https://www.reddit.com/r/debian/comments/188d3wc/neovim_on_debian/
      sudo apt install ninja-build gettext cmake unzip curl --yes
      git clone https://github.com/neovim/neovim $repositories_directory/neovim
      currentdir=$(pwd)
      cd $repositories_directory/neovim
      # change to stable release
      git checkout 8b98642002d0506d20628683958cb5c97a0dad80
      make CMAKE_BUILD_TYPE=RelWithDebInfo
      cd build
      cpack -G DEB
      sudo dpkg -i --force-overwrite nvim-linux64.deb
      cd $currentdir
      # install VimPlug
      sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
      # install VimPlug plugins
      nvim +'PlugInstall --sync' +qa
	;;
      *);;
  esac
}
# Actual script

# Set constants to be used throught the script
username="bonet"
repositories_directory="/home/$username/.local/src"
binaries_directory="/home/$username/.local/bin"
dotfiles_repository="https://github.com/bonettimrc/dotfiles"

# Create directory for repositories
mkdir $repositories_directory --parents

# Create directory for binaries
mkdir $binaries_directory --parents

# Upgrade and Update Command
echo -e "Updating and upgrading before performing further operations.";
sudo apt update && sudo apt upgrade --yes
sudo apt --fix-broken install --yes

# Installing make wget whiptail git
echo -e "Installing tools needed for further operations";
sudo apt-get install make wget git jq whiptail --yes

# Install dotfiles
git clone --bare $dotfiles_repository /home/$username/.dotfiles
git --git-dir=/home/$username/.dotfiles/ --work-tree=/home/$username config --local status.showUntrackedFiles no
git --git-dir=/home/$username/.dotfiles/ --work-tree=/home/$username checkout --force

# Ask which software to install
dialogbox=(whiptail --separate-output --ok-button "Install" --title "Auto Setup Script" --checklist "\nPlease select required software(s):\n(Press 'Space' to Select/Deselect, 'Enter' to Install and 'Esc' to Cancel)" 30 90 20)
options=()
while read program; do
    name=$(echo $program | jq --raw-output '.name')
    purpose=$(echo $program | jq --raw-output '.purpose')
    options+=("$name" "$purpose" "OFF");
done < <(jq -c '.[]' programs.json)
selected=$("${dialogbox[@]}" "${options[@]}" 2>&1 >/dev/tty)

# Install choosen software
for choice in $selected
do
  installation_type=$(jq --raw-output ".[] | select(.name==\"$choice\") | .installationType" programs.json)
  echo $installation_type
  TERM=ansi whiptail --title "Auto Setup Script" --infobox "Installing $choice" 9 70
  case $installation_type in
    "apt") aptInstall "$choice";;
    "wget") wgetInstall "$choice";;
    "git") gitInstall "$choice";;
    *) complicatedInstall "$choice";;
  esac
done

# Update font cache
fc-cache -v
