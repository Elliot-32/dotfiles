#!/bin/sh
set -eu

flatpak_app="org.fcitx.Fcitx5"

if ! command -v flatpak >/dev/null 2>&1 ||
  ! flatpak info --user "$flatpak_app" >/dev/null 2>&1; then
  exit 0
fi

for command_name in curl tar zstd; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "$command_name is required to install the Fcitx5 Breeze theme" >&2
    exit 1
  fi
done

tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT HUP INT TERM

archive="$tmp_dir/fcitx5-breeze.pkg.tar.zst"
curl -fL --retry 3   -o "$archive"   "https://archlinux.org/packages/extra/any/fcitx5-breeze/download/"

mkdir -p "$tmp_dir/pkg"
tar --zstd -xf "$archive" -C "$tmp_dir/pkg" usr/share/fcitx5/themes

source_dir="$tmp_dir/pkg/usr/share/fcitx5/themes"
destination="$HOME/.var/app/$flatpak_app/data/fcitx5/themes"

mkdir -p "$destination"
find "$destination" -mindepth 1 -maxdepth 1 -type d -name 'breeze-*'   -exec rm -rf -- {} +

for theme in "$source_dir"/breeze-*; do
  [ -d "$theme" ] || continue
  cp -a "$theme" "$destination/"
done
