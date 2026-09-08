#!/bin/sh
set -eu

gum_available=false
if command -v gum >/dev/null 2>&1; then
  gum_available=true
fi

can_style_output() {
  [ "$gum_available" = true ] && [ -t 2 ]
}

show_message() (
  message_prefix=$1
  message_color=$2
  shift 2

  if can_style_output; then
    if gum log \
      --level none \
      --prefix "$message_prefix" \
      --prefix.foreground "$message_color" \
      "$*" >&2; then
      exit 0
    fi
  fi

  printf '%s %s\n' "$message_prefix" "$*" >&2
)

show_error() {
  show_message "✗" 196 "$@"
}

show_warning() {
  show_message "!" 214 "$@"
}

show_info() {
  show_message "•" 39 "$@"
}

show_success() {
  show_message "✓" 42 "$@"
}

show_header() {
  if can_style_output; then
    gum style \
      --border rounded \
      --border-foreground 212 \
      --padding "0 1" \
      --bold \
      "Windows Terminal setup" >&2 || :
  else
    printf '%s\n' 'Windows Terminal setup' >&2
  fi
}

require_command() {
  if command -v "$1" >/dev/null 2>&1; then
    return 0
  fi

  show_error "$1 is not installed or unavailable"
  return 1
}

require_interactive_gum() {
  if [ "$gum_available" != true ]; then
    show_error "gum is not installed"
    return 1
  fi

  if [ ! -t 0 ] || [ ! -t 2 ]; then
    show_error "An interactive terminal is required to choose a Windows Terminal theme"
    return 1
  fi
}

choose_theme() {
  require_interactive_gum || return 1

  if ! theme=$(
    gum choose \
      --label-delimiter ":" \
      --header "Choose a Windows Terminal theme:" \
      "Catppuccin Mocha — darkest Catppuccin flavor:catppuccin-mocha" \
      "Catppuccin Macchiato — dark Catppuccin flavor:catppuccin-macchiato" \
      "Catppuccin Frappe — softer dark Catppuccin flavor:catppuccin-frappe" \
      "Catppuccin Latte — light Catppuccin flavor:catppuccin-latte" \
      "Tokyo Night — dark blue Tokyo palette:tokyo-night" \
      "Dracula — classic purple Dracula palette:dracula"
  ); then
    show_warning "Windows Terminal theme selection was cancelled"
    return 1
  fi

  case "$theme" in
    catppuccin-mocha) theme_name='Catppuccin Mocha' ;;
    catppuccin-macchiato) theme_name='Catppuccin Macchiato' ;;
    catppuccin-frappe) theme_name='Catppuccin Frappe' ;;
    catppuccin-latte) theme_name='Catppuccin Latte' ;;
    tokyo-night) theme_name='Tokyo Night' ;;
    dracula) theme_name='Dracula' ;;
    *)
      show_error "gum returned an unexpected Windows Terminal theme"
      return 1
      ;;
  esac
}

run_windows_bootstrap() {
  config_dir=${MISE_CONFIG_DIR:-$HOME/.config/mise}
  script="$config_dir/scripts/bootstrap-windows.ps1"

  if [ ! -f "$script" ]; then
    show_error "Windows bootstrap script was not found: $script"
    return 1
  fi

  windows_script=$(wslpath -w "$script")

  show_info "Selected $theme_name"
  show_info "Configuring Windows and applying $theme_name..."

  # Do not wrap powershell.exe in `gum spin` here. WSL interop commands can
  # behave differently when their stdio is captured by gum, and winget may
  # appear to hang even though the same PowerShell command works normally.
  if ! powershell.exe \
    -NoLogo \
    -NoProfile \
    -ExecutionPolicy Bypass \
    -File "$windows_script" \
    -Theme "$theme"; then
    show_error "Windows bootstrap failed"
    return 1
  fi

  show_success "Windows Terminal now uses $theme_name"
}

main() {
  show_header

  if ! command -v powershell.exe >/dev/null 2>&1; then
    show_warning "powershell.exe is unavailable; skipping Windows bootstrap"
    return 0
  fi

  require_command gum || return 1
  require_command wslpath || return 1

  choose_theme || return 1
  run_windows_bootstrap
}

main "$@"
