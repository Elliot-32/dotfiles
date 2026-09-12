#!/usr/bin/env bash
set -euo pipefail

show_error() {
  if command -v gum >/dev/null 2>&1 && [[ -t 2 ]]; then
    gum log --level error "$*" >&2 || true
  else
    printf 'error: %s\n' "$*" >&2
  fi
}

show_info() {
  if command -v gum >/dev/null 2>&1 && [[ -t 2 ]]; then
    gum log --level info "$*" >&2 || true
  else
    printf '%s\n' "$*" >&2
  fi
}

require_command() {
  if command -v "$1" >/dev/null 2>&1; then
    return 0
  fi

  show_error "$1 is not installed"
  return 1
}

require_command gum
require_command tinty

if [[ ! -t 0 || ! -t 1 || ! -t 2 ]]; then
  show_error "An interactive terminal is required"
  exit 1
fi

original_scheme=""
if original_scheme="$(tinty current 2>/dev/null)"; then
  :
else
  original_scheme=""
fi

preview_active=false
keep_preview=false

restore_original() {
  if [[ "$preview_active" != true || "$keep_preview" == true || -z "$original_scheme" ]]; then
    return 0
  fi

  tinty apply "$original_scheme" --quiet >/dev/null 2>&1 || true
  preview_active=false
}

handle_signal() {
  local status=$1
  restore_original
  exit "$status"
}

trap restore_original EXIT
trap 'handle_signal 129' HUP
trap 'handle_signal 130' INT
trap 'handle_signal 143' TERM

mapfile -t schemes < <(
  tinty list |
    grep -E '^(base16|base24)-' |
    LC_ALL=C sort -u
)
if (( ${#schemes[@]} == 0 )); then
  show_error "Tinty returned no Base16/Base24 schemes. Run 'tinty sync' first."
  exit 1
fi

while true; do
  header="Choose a Tinty theme"
  if [[ -n "$original_scheme" ]]; then
    header+=" · original: $original_scheme"
  fi

  if ! selected_scheme="$(
    printf '%s\n' "${schemes[@]}" |
      gum filter \
        --height 20 \
        --header "$header" \
        --placeholder "Search schemes..."
  )"; then
    restore_original
    show_info "Theme selection cancelled"
    exit 0
  fi

  [[ -n "$selected_scheme" ]] || continue

  preview_active=true
  if ! gum spin \
    --spinner dot \
    --title "Previewing $selected_scheme..." \
    -- tinty apply "$selected_scheme" --quiet; then
    show_error "Failed to apply $selected_scheme"
    restore_original
    exit 1
  fi

  restore_label="Exit"
  if [[ -n "$original_scheme" ]]; then
    restore_label="Restore $original_scheme and exit"
  fi

  if ! action="$(
    gum choose \
      --label-delimiter ":" \
      --header "Previewing $selected_scheme" \
      "Keep this theme:keep" \
      "Choose another:again" \
      "$restore_label:restore"
  )"; then
    restore_original
    show_info "Restored ${original_scheme:-previous state}"
    exit 0
  fi

  case "$action" in
    keep)
      keep_preview=true
      show_info "Applied $selected_scheme"
      exit 0
      ;;
    again)
      ;;
    restore)
      restore_original
      if [[ -n "$original_scheme" ]]; then
        show_info "Restored $original_scheme"
      else
        show_info "Exited without a previous Tinty theme to restore"
      fi
      exit 0
      ;;
    *)
      show_error "gum returned an unexpected action: $action"
      restore_original
      exit 1
      ;;
  esac
done
