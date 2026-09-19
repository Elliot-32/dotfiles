#!/bin/sh
set -eu

if ! dnf copr --help >/dev/null 2>&1; then
  if command -v dnf5 >/dev/null 2>&1; then
    sudo dnf install --assumeyes dnf5-plugins
  else
    sudo dnf install --assumeyes dnf-plugins-core
  fi
fi

enabled_coprs="$(dnf copr list --enabled 2>/dev/null || :)"

enable_copr() {
  project="$1"
  if ! printf '%s\n' "$enabled_coprs" | grep -Fq "$project"; then
    sudo dnf copr enable --assumeyes "$project"
  fi
}

enable_copr scottames/ghostty
enable_copr apicalshark/fcitx5-mcbopomofo
