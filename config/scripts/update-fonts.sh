#!/usr/bin/env bash
set -euo pipefail

if [[ -n ${WSL_DISTRO_NAME:-} || -n ${WSL_INTEROP:-} || -e /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
  echo 'WSL detected; skipping Linux font registration.'
  exit 0
fi

: "${MISE_TOOL_INSTALL_PATH:?MISE_TOOL_INSTALL_PATH is required}"

if ! command -v fc-cache >/dev/null 2>&1; then
  echo "error: required command 'fc-cache' is unavailable" >&2
  exit 1
fi

font_root="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
font_dir="$font_root/JetBrainsMonoNerdFont"

mkdir -p "$font_root"
rm -rf -- "$font_dir"
ln -s "$MISE_TOOL_INSTALL_PATH" "$font_dir"
fc-cache -f "$font_dir"

echo "Registered JetBrainsMono Nerd Font ${MISE_TOOL_VERSION:-unknown} from $MISE_TOOL_INSTALL_PATH"
