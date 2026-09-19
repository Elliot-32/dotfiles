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

system_theme_dir="/usr/share/fcitx5/themes"
source_dir="$system_theme_dir"
tmp_dir=""

has_breeze_theme() {
  find "$1" -mindepth 1 -maxdepth 1 -type d -name 'breeze-*' -print -quit 2>/dev/null |
    grep -q .
}

if ! has_breeze_theme "$source_dir"; then
  for command_name in curl tar zstd; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      echo "$command_name is required to install the Fcitx5 Breeze theme" >&2
      exit 1
    fi
  done

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf -- "$tmp_dir"' EXIT HUP INT TERM

  archive="$tmp_dir/fcitx5-breeze.pkg.tar.zst"
  curl -fL --retry 3     -o "$archive"     "https://archlinux.org/packages/extra/any/fcitx5-breeze/download/"

  mkdir -p "$tmp_dir/pkg"
  tar --zstd -xf "$archive" -C "$tmp_dir/pkg" usr/share/fcitx5/themes
  source_dir="$tmp_dir/pkg/usr/share/fcitx5/themes"
fi

install_themes() {
  destination="$1"
  mkdir -p "$destination"

  find "$destination" -mindepth 1 -maxdepth 1 -type d -name 'breeze-*'     -exec rm -rf -- {} +

  for theme in "$source_dir"/breeze-*; do
    [ -d "$theme" ] || continue
    cp -a "$theme" "$destination/"
  done
}

if [ "$has_native_fcitx" = true ] && [ "$source_dir" != "$system_theme_dir" ]; then
  install_themes "${XDG_DATA_HOME:-$HOME/.local/share}/fcitx5/themes"
fi

if [ "$has_flatpak_fcitx" = true ]; then
  install_themes "$HOME/.var/app/$flatpak_app/data/fcitx5/themes"
fi
