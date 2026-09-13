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

resolve_windows_localappdata() {
  [[ -n "${TINTY_WINDOWS_LOCALAPPDATA:-}" ]] && return 0
  command -v powershell.exe >/dev/null 2>&1 || return 0
  command -v wslpath >/dev/null 2>&1 || return 0

  local windows_path
  if ! windows_path="$(
    powershell.exe \
      -NoLogo \
      -NoProfile \
      -NonInteractive \
      -Command '[Environment]::GetFolderPath("LocalApplicationData")' \
      | tr -d '\r'
  )"; then
    show_error "Failed to determine Windows LOCALAPPDATA"
    return 1
  fi

  if [[ -z "$windows_path" ]]; then
    show_error "Windows LOCALAPPDATA is empty"
    return 1
  fi

  if ! TINTY_WINDOWS_LOCALAPPDATA="$(wslpath -u "$windows_path")"; then
    show_error "Failed to convert Windows LOCALAPPDATA"
    return 1
  fi

  export TINTY_WINDOWS_LOCALAPPDATA
}

require_command gum
require_command tinty

if [[ ! -t 0 || ! -t 1 || ! -t 2 ]]; then
  show_error "An interactive terminal is required"
  exit 1
fi

resolve_windows_localappdata

original_scheme=""
if original_scheme="$(tinty current 2>/dev/null)"; then
  :
else
  original_scheme=""
fi

preview_active=false
keep_preview=false

apply_with_spinner() {
  local title=$1
  local scheme=$2

  if [[ -t 1 && -t 2 ]]; then
    gum spin \
      --spinner dot \
      --title "$title" \
      --show-error \
      -- tinty apply "$scheme" --quiet
  else
    tinty apply "$scheme" --quiet
  fi
}

restore_original() {
  if [[ "$preview_active" != true || "$keep_preview" == true || -z "$original_scheme" ]]; then
    return 0
  fi

  if ! apply_with_spinner "Restoring $original_scheme..." "$original_scheme"; then
    show_error "Failed to restore $original_scheme"
    return 1
  fi

  preview_active=false
}

cleanup_on_exit() {
  restore_original || true
}

handle_signal() {
  local status=$1
  if ! restore_original; then
    exit 1
  fi
  exit "$status"
}

trap cleanup_on_exit EXIT
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
    if ! restore_original; then
      exit 1
    fi
    show_info "Theme selection cancelled"
    exit 0
  fi

  [[ -n "$selected_scheme" ]] || continue

  preview_active=true
  if ! apply_with_spinner "Previewing $selected_scheme..." "$selected_scheme"; then
    show_error "Failed to apply $selected_scheme"
    restore_original || true
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
    if ! restore_original; then
      exit 1
    fi
    if [[ -n "$original_scheme" ]]; then
      show_info "Restored $original_scheme"
    else
      show_info "Theme selection cancelled"
    fi
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
      if ! restore_original; then
        exit 1
      fi
      if [[ -n "$original_scheme" ]]; then
        show_info "Restored $original_scheme"
      else
        show_info "Exited without a previous Tinty theme to restore"
      fi
      exit 0
      ;;
    *)
      show_error "gum returned an unexpected action: $action"
      restore_original || true
      exit 1
      ;;
  esac
done
