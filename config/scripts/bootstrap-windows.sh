#!/bin/sh
set -eu

jsonc_parser_version=3.3.1
palette_import=palette.json

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
      "Windows bootstrap" >&2 || :
  else
    printf '%s\n' 'Windows bootstrap' >&2
  fi
}

require_command() {
  if command -v "$1" >/dev/null 2>&1; then
    return 0
  fi

  show_error "$1 is not installed or unavailable"
  return 1
}

run_windows_package_bootstrap() {
  config_dir=${MISE_CONFIG_DIR:-$HOME/.config/mise}
  script="$config_dir/scripts/bootstrap-windows.ps1"

  if [ ! -f "$script" ]; then
    show_error "Windows bootstrap script was not found: $script"
    return 1
  fi

  windows_script=$(wslpath -w "$script")
  show_info "Configuring Windows packages..."

  if ! powershell.exe \
    -NoLogo \
    -NoProfile \
    -ExecutionPolicy Bypass \
    -File "$windows_script"; then
    show_error "Windows package bootstrap failed"
    return 1
  fi
}

get_windows_local_appdata() {
  windows_path=$(
    powershell.exe \
      -NoLogo \
      -NoProfile \
      -Command '[Environment]::GetFolderPath("LocalApplicationData")' \
      | tr -d '\r'
  )

  if [ -z "$windows_path" ]; then
    show_error "Could not determine Windows LOCALAPPDATA"
    return 1
  fi

  wslpath -u "$windows_path"
}

ensure_jsonc_parser() {
  cache_root=${XDG_CACHE_HOME:-$HOME/.cache}/elliot-dotfiles/windows-terminal-jsonc
  package_json="$cache_root/node_modules/jsonc-parser/package.json"
  jsonc_node_path="$cache_root/node_modules"

  installed_version=''
  if [ -f "$package_json" ]; then
    installed_version=$(node -e '
      const fs = require("node:fs");
      const pkg = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
      process.stdout.write(pkg.version ?? "");
    ' "$package_json")
  fi

  if [ "$installed_version" = "$jsonc_parser_version" ]; then
    return 0
  fi

  show_info "Installing jsonc-parser@$jsonc_parser_version in the dotfiles cache..."
  mkdir -p "$cache_root"
  npm install \
    --prefix "$cache_root" \
    --no-save \
    --package-lock=false \
    --ignore-scripts \
    --no-audit \
    --no-fund \
    --no-progress \
    "jsonc-parser@$jsonc_parser_version" >/dev/null
}

patch_windows_terminal_settings() {
  local_appdata=$1
  config_dir=${MISE_CONFIG_DIR:-$HOME/.config/mise}
  editor_script="$config_dir/scripts/ensure-windows-terminal-import.cjs"
  found=false

  if [ ! -f "$editor_script" ]; then
    show_error "Windows Terminal JSONC editor was not found: $editor_script"
    return 1
  fi

  for state_directory in \
    "$local_appdata/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState" \
    "$local_appdata/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState" \
    "$local_appdata/Packages/Microsoft.WindowsTerminalCanary_8wekyb3d8bbwe/LocalState" \
    "$local_appdata/Microsoft/Windows Terminal"
  do
    settings_path="$state_directory/settings.json"
    if [ ! -f "$settings_path" ]; then
      continue
    fi

    if [ "$found" = false ]; then
      ensure_jsonc_parser
      found=true
    fi

    NODE_PATH="$jsonc_node_path${NODE_PATH:+:$NODE_PATH}" \
      node "$editor_script" "$settings_path" "$palette_import"
  done

  if [ "$found" = false ]; then
    show_warning "Windows Terminal settings.json was not found; skipping palette import"
    return 0
  fi

  show_success "Windows Terminal imports $palette_import without replacing existing settings"
}

main() {
  show_header

  if ! command -v powershell.exe >/dev/null 2>&1; then
    show_warning "powershell.exe is unavailable; skipping Windows bootstrap"
    return 0
  fi

  require_command wslpath || return 1
  require_command node || return 1
  require_command npm || return 1

  run_windows_package_bootstrap || return 1
  local_appdata=$(get_windows_local_appdata) || return 1
  patch_windows_terminal_settings "$local_appdata"
}

main "$@"
