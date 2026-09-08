#!/usr/bin/env bash
set -euo pipefail

theme="${1:-}"
[[ -n "$theme" ]] || exit 0

config="${XDG_CONFIG_HOME:-$HOME/.config}/gomi/config.yaml"
[[ -f "$config" ]] || exit 0

theme="${theme,,}"
theme="${theme// /-}"
theme="${theme//_/-}"

case "$theme" in
  catppuccin | catppuccin-mocha)
    colorscheme="catppuccin-mocha"
    ;;
  catppuccin-latte | dracula | gruvbox | gruvbox-light | nord | rose-pine | rose-pine-dawn | rose-pine-moon | solarized-dark | solarized-light)
    colorscheme="$theme"
    ;;
  kanagawa)
    colorscheme="kanagawa-wave"
    ;;
  kanagawa-dragon | kanagawa-lotus | kanagawa-wave)
    colorscheme="$theme"
    ;;
  tokyo-night)
    colorscheme="tokyonight-night"
    ;;
  tokyonight-day | tokyonight-moon | tokyonight-night | tokyonight-storm)
    colorscheme="$theme"
    ;;
  *)
    exit 0
    ;;
esac

sed -i -E \
  "s|^([[:space:]]*colorscheme:).*|\\1 ${colorscheme}|" \
  "$config"
