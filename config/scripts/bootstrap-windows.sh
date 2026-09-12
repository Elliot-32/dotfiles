#!/bin/sh
set -eu

show_error() {
  if command -v gum >/dev/null 2>&1 && [ -t 2 ]; then
    gum log --level error "$*" >&2 || true
  else
    printf 'error: %s\n' "$*" >&2
  fi
}

show_warning() {
  if command -v gum >/dev/null 2>&1 && [ -t 2 ]; then
    gum log --level warn "$*" >&2 || true
  else
    printf 'warning: %s\n' "$*" >&2
  fi
}

run_font_install() {
  config_dir=${MISE_CONFIG_DIR:-$HOME/.config/mise}
  script="$config_dir/scripts/bootstrap-windows.ps1"

  if [ ! -f "$script" ]; then
    show_error "Windows font bootstrap script was not found: $script"
    return 1
  fi

  windows_script=$(wslpath -w "$script")

  if command -v gum >/dev/null 2>&1 && [ -t 1 ] && [ -t 2 ]; then
    gum spin \
      --spinner dot \
      --title "Installing Windows JetBrainsMono Nerd Font..." \
      --show-error \
      -- powershell.exe \
        -NoLogo \
        -NoProfile \
        -ExecutionPolicy Bypass \
        -File "$windows_script"
  else
    powershell.exe \
      -NoLogo \
      -NoProfile \
      -ExecutionPolicy Bypass \
      -File "$windows_script"
  fi
}

if ! command -v powershell.exe >/dev/null 2>&1; then
  show_warning "powershell.exe is unavailable; skipping Windows bootstrap"
  exit 0
fi

if ! command -v wslpath >/dev/null 2>&1; then
  show_error "wslpath is not installed or unavailable"
  exit 1
fi

run_font_install
