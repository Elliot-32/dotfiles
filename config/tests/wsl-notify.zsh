#!/usr/bin/env zsh
set -eu

repo_root=${0:A:h:h:h}
plugin="$repo_root/home/.config/sheldon/plugins/wsl-notify.plugin.zsh"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/bin"

cat >"$test_root/bin/wslpath" <<'EOF'
#!/bin/sh
printf '%s\n' 'C:\\wsl-notify.ps1'
EOF

cat >"$test_root/bin/powershell.exe" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$WSL_NOTIFY_TEST_LOG"
exit "${WSL_NOTIFY_TEST_EXIT:-0}"
EOF

chmod +x "$test_root/bin/wslpath" "$test_root/bin/powershell.exe"

export PATH="$test_root/bin:$PATH"
export MISE_CONFIG_DIR="$repo_root/config"
export WSL_DISTRO_NAME=ci
export WT_SESSION=ci
export WSL_NOTIFY_TEST_LOG="$test_root/powershell.log"
unset TERM_PROGRAM
rehash

source "$plugin"

[[ "$(bgnotify_appid)" == '__wsl_notify_dispatch__' ]]
[[ "$bgnotify_termid" == '__wsl_notify_terminal_foreground__' ]]
[[ ! -e "$WSL_NOTIFY_TEST_LOG" ]]

for exit_code in 0 10 11; do
  export WSL_NOTIFY_TEST_EXIT=$exit_code
  output=$(bgnotify 'build finished' 'command completed' '')
  [[ -z $output ]]
done

export WSL_NOTIFY_TEST_EXIT=20
output=$(bgnotify 'build finished' 'command completed' '')
[[ "$output" == $'\a' ]]
[[ "$(wc -l <"$WSL_NOTIFY_TEST_LOG")" -eq 4 ]]

# Exercise the Ghostty hook-removal path without depending on the runner's zsh
# function installation. The fixture is loaded through zsh's real autoload
# mechanism, just like add-zsh-hook is in an interactive shell.
mkdir -p "$test_root/fpath"
cat >"$test_root/fpath/add-zsh-hook" <<'EOF'
local mode=$1 hook=$2 callback=$3
[[ $mode == -d ]] || return 2

case $hook in
  preexec) preexec_functions=(${preexec_functions:#$callback}) ;;
  precmd) precmd_functions=(${precmd_functions:#$callback}) ;;
  *) return 2 ;;
esac
EOF

zsh -f -c '
  typeset -ga preexec_functions precmd_functions
  preexec_functions=(bgnotify_begin)
  precmd_functions=(bgnotify_end)
  function bgnotify_begin {}
  function bgnotify_end {}
  fpath=("$2" $fpath)
  export WSL_DISTRO_NAME=ci
  export TERM_PROGRAM=ghostty
  source "$1"
  [[ -z ${preexec_functions[(r)bgnotify_begin]-} ]]
  [[ -z ${precmd_functions[(r)bgnotify_end]-} ]]
' zsh "$plugin" "$test_root/fpath"
