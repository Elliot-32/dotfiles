#!/bin/sh
set -eu

flatpak_app="org.fcitx.Fcitx5"

has_native_fcitx=false
if command -v fcitx5 >/dev/null 2>&1; then
  has_native_fcitx=true
fi

has_flatpak_fcitx=false
if command -v flatpak >/dev/null 2>&1 &&
  flatpak info --user "$flatpak_app" >/dev/null 2>&1; then
  has_flatpak_fcitx=true
fi

if [ "$has_native_fcitx" = false ] && [ "$has_flatpak_fcitx" = false ]; then
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git is required to install Fcitx5 themes" >&2
  exit 1
fi

source_root="${XDG_DATA_HOME:-$HOME/.local/share}/fcitx5-theme-sources"
mkdir -p "$source_root"

sync_repo() {
  name="$1"
  url="$2"
  branch_name="$3"
  dir="$source_root/$name"

  if [ -d "$dir/.git" ]; then
    git -C "$dir" fetch --depth=1 origin "$branch_name"
    git -C "$dir" reset --hard "origin/$branch_name"
    git -C "$dir" clean -fdx
  else
    rm -rf -- "$dir"
    git clone --depth=1 --branch "$branch_name" "$url" "$dir"
  fi
}

sync_repo catppuccin https://github.com/catppuccin/fcitx5.git main
sync_repo mellow https://github.com/sanweiya/fcitx5-mellow-themes.git main

install_themes() {
  destination="$1"
  mkdir -p "$destination"

  find "$destination" -mindepth 1 -maxdepth 1 -type d     \( -name 'catppuccin-*' -o -name 'mellow-*' \)     -exec rm -rf -- {} +

  for theme in "$source_root/catppuccin"/src/catppuccin-*; do
    [ -d "$theme" ] || continue
    cp -a "$theme" "$destination/"
  done

  for theme in "$source_root/mellow"/mellow-*; do
    [ -d "$theme" ] || continue
    cp -a "$theme" "$destination/"
  done
}

if [ "$has_native_fcitx" = true ]; then
  install_themes "${XDG_DATA_HOME:-$HOME/.local/share}/fcitx5/themes"
fi

if [ "$has_flatpak_fcitx" = true ]; then
  install_themes "$HOME/.var/app/$flatpak_app/data/fcitx5/themes"
fi
