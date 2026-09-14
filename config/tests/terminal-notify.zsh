#!/usr/bin/env zsh
set -eu

repo_root=${0:A:h:h:h}
plugin="$repo_root/home/.config/sheldon/plugins/terminal-notify.plugin.zsh"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

# Windows Terminal uses OSC 777 and delegates focused-pane suppression to the
# terminal itself rather than probing Windows from WSL.
(
  unset TERM_PROGRAM
  export TERM=xterm-256color
  export WT_SESSION=ci
  bgnotify_appid() { print -r -- fallback; }
  bgnotify_termid=fallback
  bgnotify_bell=true
  source "$plugin"

  [[ $_terminal_notify_protocol == osc777 ]]
  [[ $bgnotify_bell == false ]]
  [[ "$(bgnotify_appid)" == __terminal_notify_dispatch__ ]]
  [[ $bgnotify_termid == __terminal_notify_host_focus__ ]]
  output=$(bgnotify "build; finished" $'command\ncompleted' '')
  [[ $output == $'\e]777;notify;build, finished;command completed\e\\' ]]
)

# Unsupported terminals retain upstream bgnotify completely unchanged.
(
  unset WT_SESSION
  export TERM=xterm-256color
  export TERM_PROGRAM=unknown-terminal
  bgnotify() { print -r -- fallback; }
  bgnotify_bell=true
  source "$plugin"

  [[ -z $_terminal_notify_protocol ]]
  [[ $bgnotify_bell == true ]]
  [[ "$(bgnotify one two three)" == fallback ]]
)

# Direct Ghostty owns command completion via OSC 133, so bgnotify hooks are
# removed instead of producing duplicate notifications.
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

(
  typeset -ga preexec_functions precmd_functions
  preexec_functions=(bgnotify_begin)
  precmd_functions=(bgnotify_end)
  bgnotify_begin() {}
  bgnotify_end() {}
  fpath=("$test_root/fpath" $fpath)
  unset WT_SESSION
  export TERM_PROGRAM=ghostty
  source "$plugin"

  [[ -z ${preexec_functions[(r)bgnotify_begin]-} ]]
  [[ -z ${precmd_functions[(r)bgnotify_end]-} ]]
)
