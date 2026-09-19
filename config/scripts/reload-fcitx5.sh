#!/bin/sh
set -eu

flatpak_app="org.fcitx.Fcitx5"

if command -v fcitx5-remote >/dev/null 2>&1; then
  if fcitx5-remote --check >/dev/null 2>&1; then
    fcitx5-remote -r
  fi
  exit 0
fi

if command -v flatpak >/dev/null 2>&1 &&
  flatpak info --user "$flatpak_app" >/dev/null 2>&1 &&
  flatpak run --user --command=fcitx5-remote "$flatpak_app" --check >/dev/null 2>&1; then
  flatpak run --user --command=fcitx5-remote "$flatpak_app" -r
fi
