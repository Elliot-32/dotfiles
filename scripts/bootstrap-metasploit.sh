#!/bin/sh
set -eu

if command -v msfconsole >/dev/null 2>&1; then
  exit 0
fi

if [ "$(uname -s)" != "Linux" ]; then
  exit 0
fi

if [ -f /etc/arch-release ]; then
  sudo pacman -S --needed --noconfirm metasploit
  exit 0
fi

installer=$(mktemp)
trap 'rm -f "$installer"' EXIT HUP INT TERM

curl -fsSL \
  https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb \
  -o "$installer"

sudo sh "$installer"
