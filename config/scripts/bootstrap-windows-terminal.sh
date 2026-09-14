#!/bin/sh
set -eu

jsonc_parser_version=3.3.1
config_dir=${MISE_CONFIG_DIR:-$HOME/.config/mise}
editor_script="$config_dir/scripts/ensure-windows-terminal-import.cjs"

for import_name in keybind.json notification.json; do
  fragment="$config_dir/windows-terminal/$import_name"
  if [ ! -f "$fragment" ]; then
    printf 'windows terminal bootstrap: fragment was not found: %s\n' "$fragment" >&2
    exit 1
  fi
done

if [ ! -f "$editor_script" ]; then
  printf 'windows terminal bootstrap: JSONC editor was not found: %s\n' "$editor_script" >&2
  exit 1
fi

if [ -n "${WINDOWS_TERMINAL_LOCALAPPDATA:-}" ]; then
  local_appdata=$WINDOWS_TERMINAL_LOCALAPPDATA
else
  if ! command -v powershell.exe >/dev/null 2>&1 || ! command -v wslpath >/dev/null 2>&1; then
    exit 0
  fi

  windows_path=$(
    powershell.exe \
      -NoLogo \
      -NoProfile \
      -NonInteractive \
      -Command '[Environment]::GetFolderPath("LocalApplicationData")' \
      | tr -d '\r'
  )

  if [ -z "$windows_path" ]; then
    printf 'windows terminal bootstrap: could not determine Windows LOCALAPPDATA\n' >&2
    exit 1
  fi

  local_appdata=$(wslpath -u "$windows_path")
fi

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

found=false
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
    if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
      printf 'windows terminal bootstrap: node and npm are required to register terminal fragments\n' >&2
      exit 1
    fi
    ensure_jsonc_parser
    found=true
  fi

  for import_name in keybind.json notification.json; do
    fragment="$config_dir/windows-terminal/$import_name"
    cp -f -- "$fragment" "$state_directory/$import_name"
    NODE_PATH="$jsonc_node_path${NODE_PATH:+:$NODE_PATH}" \
      node "$editor_script" "$settings_path" "$import_name"
  done
done
