#!/bin/sh
set -eu

mode=${1:-}

case "$mode" in
  apt|dnf|pacman)
    if ! command -v flatpak >/dev/null 2>&1; then
      case "$mode" in
        apt)
          sudo apt-get update
          sudo apt-get install --yes flatpak
          ;;
        dnf)
          sudo dnf install --assumeyes flatpak
          ;;
        pacman)
          sudo pacman -S --needed --noconfirm flatpak
          ;;
      esac
    fi

    flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    ;;
  ubuntu)
    if [ ! -d /usr/share/wayland-sessions ] && [ ! -d /usr/share/xsessions ]; then
      exit 0
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
    esac
    ;;
  fedora)
    if [ ! -d /usr/share/wayland-sessions ] && [ ! -d /usr/share/xsessions ]; then
      exit 0
    fi

    if [ -r /etc/os-release ]; then
      . /etc/os-release
    fi

    if [ "${ID:-}" != "fedora" ]; then
      exit 0
    fi

    ghostty_repo=/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:scottames:ghostty.repo
    if [ ! -f "$ghostty_repo" ] || ! grep -Eq '^[[:space:]]*enabled[[:space:]]*=[[:space:]]*1' "$ghostty_repo"; then
      if ! dnf copr --help >/dev/null 2>&1; then
        if command -v dnf5 >/dev/null 2>&1; then
          sudo dnf install --assumeyes dnf5-plugins
        else
          sudo dnf install --assumeyes dnf-plugins-core
        fi
      fi
      sudo dnf copr enable --assumeyes scottames/ghostty
    fi
    ;;
  *)
    echo "usage: $0 {apt|dnf|pacman|ubuntu|fedora}" >&2
    exit 2
    ;;
esac
