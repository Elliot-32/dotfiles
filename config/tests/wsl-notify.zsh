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

# Ghostty owns command-finished notifications, so the bgnotify hooks must be
# removed instead of routing through the WSL helper.
zsh -f -c '
  function bgnotify_begin {}
  function bgnotify_end {}
  autoload -Uz add-zsh-hook
  add-zsh-hook preexec bgnotify_begin
  add-zsh-hook precmd bgnotify_end
  export WSL_DISTRO_NAME=ci
  export TERM_PROGRAM=ghostty
  source "$1"
  (( ${preexec_functions[(Ie)bgnotify_begin]} == 0 ))
  (( ${precmd_functions[(Ie)bgnotify_end]} == 0 ))
' zsh "$plugin"
