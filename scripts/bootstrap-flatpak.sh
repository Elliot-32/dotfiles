#!/bin/sh

if ! command -v flatpak >/dev/null 2>&1; then
  case ",${MISE_ENV:-}," in
    *,apt,*)
      sudo apt-get update
      sudo apt-get install --yes flatpak
      ;;
    *,dnf,*)
      if command -v dnf5 >/dev/null 2>&1; then
        sudo dnf5 install --assumeyes flatpak
      else
        sudo dnf install --assumeyes flatpak
      fi
      ;;
    *,pacman,*)
      sudo pacman -S --needed --noconfirm flatpak
      ;;
    *)
      echo "No supported package manager environment found to install Flatpak" >&2
      exit 1
      ;;
  esac
fi

flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
