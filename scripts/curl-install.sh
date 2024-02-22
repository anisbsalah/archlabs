#!/usr/bin/env bash

# Checking if running in repo folder
if [[ "$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]')" =~ ^scripts$ ]]; then
	echo "You are running this in 'archlabs' folder."
	echo "Please use ./archlabs.sh instead!"
	exit
fi

# Installing git
printf "\n[*] Installing 'git'...\n\n"
pacman -Sy --noconfirm --needed git

# Cloning project
printf "\n[*] Cloning 'archlabs' project...\n\n"
git clone https://github.com/anisbsalah/archlabs.git

# Executing script
printf "\n[*] Executing 'archlabs.sh' script...\n\n"
cd "${HOME}/archlabs" || exit 1
exec ./archlabs.sh
