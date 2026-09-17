#!/bin/sh

if ! command -v flatpak >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install --yes flatpak
  elif command -v dnf5 >/dev/null 2>&1; then
    sudo dnf5 install --assumeyes flatpak
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install --assumeyes flatpak
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm flatpak
  else
    echo "No supported package manager found to install Flatpak" >&2
    exit 1
  fi
fi

flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
