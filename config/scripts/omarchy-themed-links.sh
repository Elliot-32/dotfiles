#!/usr/bin/env bash
set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
config="$config_home/omarchy/themed-links.toml"
theme_dir="$HOME/.local/state/omarchy/current/theme"

[[ -f "$config" ]] || exit 0

if ! command -v dasel >/dev/null 2>&1; then
  printf 'omarchy themed-links: dasel is required to read %s\n' "$config" >&2
  exit 1
fi

if ! count="$(dasel -i toml -o json --compact 'len(links)' < "$config")"; then
  printf 'omarchy themed-links: failed to read %s\n' "$config" >&2
  exit 1
fi

if [[ ! "$count" =~ ^[0-9]+$ ]]; then
  printf 'omarchy themed-links: invalid links list in %s\n' "$config" >&2
  exit 1
fi

expand_output_path() {
  local path="$1"

  case "$path" in
    "~")
      printf '%s\n' "$HOME"
      ;;
    "~/"*)
      printf '%s/%s\n' "$HOME" "${path:2}"
      ;;
    /*)
      printf '%s\n' "$path"
      ;;
    *)
      printf 'omarchy themed-links: output must be absolute or start with ~/: %s\n' "$path" >&2
      return 1
      ;;
  esac
}

for ((i = 0; i < count; i++)); do
  template="$(dasel -i toml -o yaml "links[$i].template" < "$config")"
  output="$(dasel -i toml -o yaml "links[$i].output" < "$config")"

  if [[ -z "$template" || -z "$output" ]]; then
    printf 'omarchy themed-links: links[%d] requires template and output\n' "$i" >&2
    exit 1
  fi

  case "$template" in
    /* | ../* | */../* | */..)
      printf 'omarchy themed-links: invalid template path: %s\n' "$template" >&2
      exit 1
      ;;
  esac

  output="$(expand_output_path "$output")"
  source="$theme_dir/$template"

  mkdir -p -- "$(dirname -- "$output")"
  rm -f -- "$output"
  ln -s -- "$source" "$output"
done
