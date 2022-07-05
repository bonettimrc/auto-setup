#!/bin/bash

# Installation functions
aptInstall(){
  # Installs all needed programs from main repo
	sudo apt-get install "$1"
}
gitInstall(){
  repository=$(jq --raw-output ".[] | select(.name==\"$1\") | .url" programs.json)
  programName="${repository##*/}"
  directory="repositories-directory/$programName"
  git clone $repository $directory
  dependencies=($(jq --raw-output ".[] | select(.name==\"$1\") | .dependencies | .[]" programs.json))
  sudo apt-get install "${dependencies[@]}" --yes
  make --directory=$directory
  sudo make install --directory=$directory
}
wgetInstall(){
  file="./binaries-directory/$1.deb"
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
    *);;
  esac
}
# Actual script

# Create directory for repositories
mkdir "repositories-directory" --parents

# Create directory for binaries
mkdir "binaries-directory" --parents

# Upgrade and Update Command
echo -e "Updating and upgrading before performing further operations.";
sudo apt update && sudo apt upgrade --yes
sudo apt --fix-broken install --yes

# Installing make wget whiptail git
echo -e "Installing tools needed for further operations";
sudo apt-get install make wget git whiptail jq --yes

# Ask which software to install
dialogbox=(whiptail --separate-output --ok-button "Install" --title "Auto Setup Script" --checklist "\nPlease select required software(s):\n(Press 'Space' to Select/Deselect, 'Enter' to Install and 'Esc' to Cancel)" 30 90 20)
options=()
while read program; do
    name=$(echo $program | jq --raw-output '.name')
    purpose=$(echo $program | jq --raw-output '.purpose')
    options+=("$name" "$purpose" "OFF");
done < <(jq -c '.[]' programs.json)
selected=$("${dialogbox[@]}" "${options[@]}" 2>&1 >/dev/tty)
for choice in $selected
do
  tag=$(jq --raw-output ".[] | select(.name==\"$choice\") | .tag" programs.json)
  echo $tag
  TERM=ansi whiptail --title "Auto Setup Script" --infobox "Installing $choice" 9 70
  case $tag in
    "W") wgetInstall "$choice";;
    "G") gitInstall "$choice";;
    "C") complicatedInstall "$choice";;
    *) aptInstall "$choice";;
  esac
done
# VirtualMic for AudioRelay
# TODO: check if AudioRelay & PulseAudio are installed, change to sudo the cat execution
if dpkg-query --show --showformat='${Status}\n' "pulseaudio" 2> /dev/null | grep -quiet "ok installed"
then
    cat >> "/etc/pulse/default.pa" <<- EOF
    # Creates a device where AudioRelay can stream audio into
    load-module module-null-sink sink_name=audiorelay-virtual-mic-sink sink_properties=device.description=Virtual-Mic-Sink
    # Creates a device usable by communications apps (e.g: skype)
    load-module module-remap-source master=audiorelay-virtual-mic-sink.monitor source_name=audiorelay-virtual-mic-sink source_properties=device.description=Virtual-Mic
EOF
    pulseaudio -k
fi
