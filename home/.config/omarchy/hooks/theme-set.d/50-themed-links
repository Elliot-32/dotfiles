#!/usr/bin/env bash
set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
config="$config_home/omarchy/themed-links.toml"
theme_dir="$HOME/.local/state/omarchy/current/theme"
ensure_rendered=false

if [[ ${1:-} == "--ensure-rendered" ]]; then
  ensure_rendered=true
fi

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

read_link_value() {
  local index="$1"
  local key="$2"
  dasel -i toml -o yaml "links[$index].$key" < "$config"
}

validate_template() {
  local template="$1"

  if [[ -z "$template" ]]; then
    printf 'omarchy themed-links: template cannot be empty\n' >&2
    return 1
  fi

  case "$template" in
    /* | ../* | */../* | */..)
      printf 'omarchy themed-links: invalid template path: %s\n' "$template" >&2
      return 1
      ;;
  esac
}

expand_output_path() {
  local path="$1"

  case "$path" in
    "~")
      printf '%s\n' "$HOME"
      ;;
    \~/*)
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

if [[ "$ensure_rendered" == true ]]; then
  missing_rendered_template=false

  for ((i = 0; i < count; i++)); do
    template="$(read_link_value "$i" template)"
    validate_template "$template"

    if [[ ! -e "$theme_dir/$template" ]]; then
      missing_rendered_template=true
      break
    fi
  done

  if [[ "$missing_rendered_template" == true ]]; then
    if command -v omarchy-theme-refresh >/dev/null 2>&1; then
      omarchy-theme-refresh
    else
      printf 'omarchy themed-links: omarchy-theme-refresh is required to render missing templates\n' >&2
      exit 1
    fi
  fi
fi

for ((i = 0; i < count; i++)); do
  template="$(read_link_value "$i" template)"
  output="$(read_link_value "$i" output)"

  validate_template "$template"

  if [[ -z "$output" ]]; then
    printf 'omarchy themed-links: links[%d] requires output\n' "$i" >&2
    exit 1
  fi

  output="$(expand_output_path "$output")"
  source="$theme_dir/$template"

  if [[ ! -e "$source" ]]; then
    printf 'omarchy themed-links: rendered template is missing, keeping existing output: %s\n' "$source" >&2
    continue
  fi

  mkdir -p -- "$(dirname -- "$output")"
  rm -f -- "$output"
  ln -s -- "$source" "$output"
done
