#!/bin/sh
set -eu

if command -v flatpak >/dev/null 2>&1; then
  flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
else
  echo "flatpak is not installed; skipping Flatpak packages"
fi

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
  *)
    echo "unsupported Ubuntu base; skipping Ghostty PPA"
    ;;
esac
