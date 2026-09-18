#!/bin/sh
set -eu

if command -v paru >/dev/null 2>&1; then
  exit 0
fi

sudo pacman -S --needed --noconfirm base-devel git

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

git clone https://aur.archlinux.org/paru.git "$tmp_dir/paru"
(
  cd "$tmp_dir/paru"
  makepkg -si --noconfirm
)
