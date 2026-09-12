#!/bin/sh
set -eu

jsonc_parser_version=3.3.1
theme_import=tinty.json
legacy_theme_import=palette.json

rendered_theme=${1:-}
if [ -z "$rendered_theme" ] || [ ! -f "$rendered_theme" ]; then
  printf 'tinty windows-terminal: rendered theme file is required\n' >&2
  exit 1
fi

if [ -n "${TINTY_WINDOWS_LOCALAPPDATA:-}" ]; then
  local_appdata=$TINTY_WINDOWS_LOCALAPPDATA
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
    printf 'tinty windows-terminal: could not determine Windows LOCALAPPDATA\n' >&2
    exit 1
  fi

  local_appdata=$(wslpath -u "$windows_path")
fi

config_dir=${MISE_CONFIG_DIR:-$HOME/.config/mise}
editor_script="$config_dir/scripts/ensure-windows-terminal-import.cjs"

if [ ! -f "$editor_script" ]; then
  printf 'tinty windows-terminal: JSONC editor was not found: %s\n' "$editor_script" >&2
  exit 1
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
      printf 'tinty windows-terminal: node and npm are required to register tinty.json\n' >&2
      exit 1
    fi
    ensure_jsonc_parser
    found=true
  fi

  cp -f -- "$rendered_theme" "$state_directory/$theme_import"

  NODE_PATH="$jsonc_node_path${NODE_PATH:+:$NODE_PATH}" \
    node "$editor_script" \
      "$settings_path" \
      "$theme_import" \
      "$legacy_theme_import"

  rm -f -- "$state_directory/$legacy_theme_import"
done
