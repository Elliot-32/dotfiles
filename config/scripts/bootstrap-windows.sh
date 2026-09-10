#!/bin/sh
set -eu

gum_available=false
if command -v gum >/dev/null 2>&1; then
  gum_available=true
fi

preview_active=false

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

require_interactive_terminal() {
  if [ ! -t 0 ] || [ ! -t 2 ]; then
    show_error "An interactive terminal is required to choose a Windows Terminal theme"
    return 1
  fi
}

theme_options() {
  printf '%s\t%s\n' \
    'catppuccin-mocha' 'Catppuccin Mocha — darkest Catppuccin flavor' \
    'catppuccin-macchiato' 'Catppuccin Macchiato — dark Catppuccin flavor' \
    'catppuccin-frappe' 'Catppuccin Frappe — softer dark Catppuccin flavor' \
    'catppuccin-latte' 'Catppuccin Latte — light Catppuccin flavor' \
    'tokyo-night' 'Tokyo Night — dark blue Tokyo palette' \
    'dracula' 'Dracula — classic purple Dracula palette'
}

set_theme_name() {
  case "$1" in
    catppuccin-mocha) theme_name='Catppuccin Mocha' ;;
    catppuccin-macchiato) theme_name='Catppuccin Macchiato' ;;
    catppuccin-frappe) theme_name='Catppuccin Frappe' ;;
    catppuccin-latte) theme_name='Catppuccin Latte' ;;
    tokyo-night) theme_name='Tokyo Night' ;;
    dracula) theme_name='Dracula' ;;
    *)
      show_error "Theme picker returned an unexpected Windows Terminal theme: $1"
      return 1
      ;;
  esac
}

windows_script_path() {
  config_dir=${MISE_CONFIG_DIR:-$HOME/.config/mise}
  script="$config_dir/scripts/bootstrap-windows.ps1"

  if [ ! -f "$script" ]; then
    show_error "Windows bootstrap script was not found: $script"
    return 1
  fi

  wslpath -w "$script"
}

invoke_windows_theme_mode() {
  mode=$1
  theme_arg=${2:-}

  windows_script=$(windows_script_path) || return 1

  if [ -n "$theme_arg" ]; then
    powershell.exe \
      -NoLogo \
      -NoProfile \
      -ExecutionPolicy Bypass \
      -File "$windows_script" \
      -Mode "$mode" \
      -Theme "$theme_arg"
  else
    powershell.exe \
      -NoLogo \
      -NoProfile \
      -ExecutionPolicy Bypass \
      -File "$windows_script" \
      -Mode "$mode"
  fi
}

preview_theme_command() {
  if [ "$#" -ne 1 ]; then
    return 2
  fi

  if ! command -v powershell.exe >/dev/null 2>&1 || ! command -v wslpath >/dev/null 2>&1; then
    return 1
  fi

  invoke_windows_theme_mode PreviewApply "$1" >/dev/null 2>&1
}

cleanup_preview() {
  if [ "$preview_active" = true ]; then
    invoke_windows_theme_mode PreviewCancel >/dev/null 2>&1 || :
    preview_active=false
  fi
}

handle_hup() {
  cleanup_preview
  exit 129
}

handle_int() {
  cleanup_preview
  exit 130
}

handle_term() {
  cleanup_preview
  exit 143
}

choose_theme() {
  require_interactive_terminal || return 1

  export WINDOWS_TERMINAL_THEME_HELPER="${MISE_CONFIG_DIR:-$HOME/.config/mise}/scripts/bootstrap-windows.sh"

  if ! invoke_windows_theme_mode PreviewBegin >/dev/null; then
    show_error "Could not start Windows Terminal theme preview"
    return 1
  fi

  preview_active=true
  trap cleanup_preview 0
  trap handle_hup HUP
  trap handle_int INT
  trap handle_term TERM

  # Apply the initially focused item immediately instead of relying on fzf's
  # first focus event. Moving the cursor will then replace this preview.
  if ! invoke_windows_theme_mode PreviewApply catppuccin-mocha >/dev/null; then
    show_error "Could not preview Windows Terminal themes"
    cleanup_preview
    return 1
  fi

  tab=$(printf '\t')
  if ! selection=$(
    theme_options | fzf \
      --delimiter "$tab" \
      --with-nth '2..' \
      --height '~12' \
      --layout reverse \
      --border rounded \
      --info hidden \
      --prompt 'Theme › ' \
      --header '↑/↓ preview • Enter apply • Esc cancel' \
      --bind='focus:execute-silent(sh "$WINDOWS_TERMINAL_THEME_HELPER" --preview-theme {1})'
  ); then
    cleanup_preview
    show_warning "Windows Terminal theme selection was cancelled; previous theme restored"
    return 1
  fi

  theme=$(printf '%s\n' "$selection" | cut -f1)
  set_theme_name "$theme" || {
    cleanup_preview
    return 1
  }
}

run_windows_bootstrap() {
  show_info "Selected $theme_name"
  show_info "Configuring Windows and applying $theme_name..."

  # Keep the real bootstrap attached to the terminal. WSL interop commands can
  # behave differently when their stdio is captured by a spinner or another
  # TUI, and winget may appear to hang in that situation.
  if ! invoke_windows_theme_mode Install "$theme"; then
    show_error "Windows bootstrap failed; previous Windows Terminal theme restored"
    cleanup_preview
    return 1
  fi

  if ! invoke_windows_theme_mode PreviewCommit >/dev/null; then
    show_error "Windows bootstrap succeeded, but the preview transaction could not be finalized"
    return 1
  fi

  preview_active=false
  trap - 0 HUP INT TERM
  show_success "Windows Terminal now uses $theme_name"
}

main() {
  show_header

  if ! command -v powershell.exe >/dev/null 2>&1; then
    show_warning "powershell.exe is unavailable; skipping Windows bootstrap"
    return 0
  fi

  require_command fzf || return 1
  require_command wslpath || return 1

  choose_theme || return 1
  run_windows_bootstrap
}

if [ "${1:-}" = '--preview-theme' ]; then
  shift
  preview_theme_command "$@"
  exit $?
fi

main "$@"
