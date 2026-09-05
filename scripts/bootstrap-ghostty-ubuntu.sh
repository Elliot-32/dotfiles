#!/bin/sh

if [ -r /etc/os-release ]; then
  . /etc/os-release
fi

ubuntu_codename=${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}

if ! command -v add-apt-repository >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install --yes software-properties-common
fi

sudo add-apt-repository --yes universe

case "$ubuntu_codename" in
  noble)
    if ! grep -Rqs 'ppa.launchpadcontent.net/mkasberg/ghostty-ubuntu' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
      sudo add-apt-repository --yes ppa:mkasberg/ghostty-ubuntu
    fi
    ;;
esac
