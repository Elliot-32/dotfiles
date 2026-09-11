#!/usr/bin/env bash
set -euo pipefail

theme="${1:-}"
[[ -n "$theme" ]] || exit 0

config="${XDG_CONFIG_HOME:-$HOME/.config}/gomi/config.yaml"
[[ -f "$config" ]] || exit 0

theme="${theme,,}"
theme="${theme// /-}"
theme="${theme//_/-}"

colorscheme=""
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
esac

if [[ -n "$colorscheme" ]]; then
  sed -i -E \
    "s|^([[:space:]]*colorscheme:).*|\\1 ${colorscheme}|" \
    "$config"
fi

command -v omarchy-theme-color >/dev/null 2>&1 || exit 0

resolve_hex() {
  local key="$1"
  local fallback="${2:-}"
  local value

  if [[ -n "$fallback" ]]; then
    value="$(omarchy-theme-color "$key" "$fallback" 2>/dev/null)" || return 1
  else
    value="$(omarchy-theme-color "$key" 2>/dev/null)" || return 1
  fi

  [[ "$value" =~ ^#[0-9A-Fa-f]{6}$ ]] || return 1
  printf '%s\n' "$value"
}

accent="$(resolve_hex accent blue)" || exit 0
selected="$(resolve_hex green accent)" || exit 0
filter_match="$(resolve_hex orange yellow)" || exit 0
filter_prompt="$(resolve_hex blue accent)" || exit 0
border="$(resolve_hex foreground)" || exit 0
muted="$(resolve_hex muted dark_foreground)" || exit 0
pane_fg="$(resolve_hex light_foreground foreground)" || exit 0
pane_bg="$(resolve_hex dark_background background)" || exit 0
danger="$(resolve_hex red accent)" || exit 0

sed -i -E \
  -e "s|^      cursor:.*|      cursor: \"${accent}\"|" \
  -e "s|^      selected:.*|      selected: \"${selected}\"|" \
  -e "s|^      filter_match:.*|      filter_match: \"${filter_match}\"|" \
  -e "s|^      filter_prompt:.*|      filter_prompt: \"${filter_prompt}\"|" \
  -e "s|^      border:.*|      border: \"${border}\"|" \
  -e "s|^        border:.*|        border: \"${muted}\"|" \
  -e "s|^          fg:.*|          fg: \"${pane_fg}\"|" \
  -e "s|^          bg:.*|          bg: \"${pane_bg}\"|" \
  -e "s|^    deletion_dialog:.*|    deletion_dialog: \"${danger}\"|" \
  "$config"
