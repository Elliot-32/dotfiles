#!/bin/sh
set -eu

distro=${1:-}

case "$distro" in
  ubuntu|fedora|arch) ;;
  *)
    echo "usage: $0 {ubuntu|fedora|arch}" >&2
    exit 2
    ;;
esac

if ! command -v flatpak >/dev/null 2>&1; then
  case "$distro" in
    ubuntu)
      sudo apt-get update
      sudo apt-get install --yes flatpak
      ;;
    fedora)
      sudo dnf install --assumeyes flatpak
      ;;
    arch)
      sudo pacman -S --needed --noconfirm flatpak
      ;;
  esac
fi

flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

[ "$distro" = "ubuntu" ] || exit 0

if [ -r /etc/os-release ]; then
  . /etc/os-release
fi

ubuntu_codename=${UBUNTU_CODENAME:-}
if [ -z "$ubuntu_codename" ] && [ "${ID:-}" = "ubuntu" ]; then
  ubuntu_codename=${VERSION_CODENAME:-}
fi

case "$ubuntu_codename" in
  noble)
    if ! grep -Rqs 'ppa.launchpadcontent.net/mkasberg/ghostty-ubuntu' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
      if ! command -v add-apt-repository >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install --yes software-properties-common
      fi
      sudo add-apt-repository --yes ppa:mkasberg/ghostty-ubuntu
    fi
    ;;
esac
