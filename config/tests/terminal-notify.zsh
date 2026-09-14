#!/usr/bin/env zsh
set -eu

repo_root=${0:A:h:h:h}
plugin="$repo_root/home/.config/sheldon/plugins/terminal-notify.plugin.zsh"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

# Windows Terminal uses OSC 777 and delegates focused-pane suppression to the
# terminal itself rather than probing Windows from WSL.
zsh -f -c '
  unset TERM_PROGRAM KITTY_WINDOW_ID TMUX ZELLIJ ZELLIJ_SESSION_NAME
  export TERM=xterm-256color
  export WT_SESSION=ci
  function bgnotify_appid { print -r -- fallback; }
  bgnotify_termid=fallback
  source "$1"

  [[ $_terminal_notify_protocol == osc777 ]]
  [[ "$(bgnotify_appid)" == __terminal_notify_dispatch__ ]]
  [[ $bgnotify_termid == __terminal_notify_host_focus__ ]]
  output=$(bgnotify "build finished" "command completed" "")
  [[ $output == $'"'"'\e]777;notify;build finished;command completed\e\\'"'"' ]]
' zsh "$plugin"

# tmux receives the same terminal protocol through DCS passthrough with nested
# ESC bytes escaped as required by tmux.
zsh -f -c '
  unset TERM_PROGRAM KITTY_WINDOW_ID ZELLIJ ZELLIJ_SESSION_NAME
  export TERM=xterm-256color
  export WT_SESSION=ci
  export TMUX=/tmp/tmux-test
  function bgnotify_appid { print -r -- fallback; }
  bgnotify_termid=fallback
  source "$1"

  output=$(bgnotify "build finished" "command completed" "")
  [[ $output == $'"'"'\ePtmux;\e\e]777;notify;build finished;command completed\e\e\\\e\\'"'"' ]]
' zsh "$plugin"

# kitty gets its richer OSC 99 protocol with one logical notification split
# into title and body chunks.
zsh -f -c '
  unset TERM_PROGRAM WT_SESSION TMUX ZELLIJ ZELLIJ_SESSION_NAME
  export TERM=xterm-kitty
  export KITTY_WINDOW_ID=1
  function bgnotify { print -r -- fallback; }
  source "$1"

  [[ $_terminal_notify_protocol == osc99 ]]
  output=$(bgnotify "build finished" "command completed" "")
  [[ $output == $'"'"'\e]99;i=bgnotify:d=0;build finished\e\\\e]99;i=bgnotify:p=body:d=1;command completed\e\\'"'"' ]]
' zsh "$plugin"

# iTerm2 keeps its native OSC 9 notification path.
zsh -f -c '
  unset WT_SESSION KITTY_WINDOW_ID TMUX ZELLIJ ZELLIJ_SESSION_NAME
  export TERM=xterm-256color
  export TERM_PROGRAM=iTerm.app
  function bgnotify { print -r -- fallback; }
  source "$1"

  [[ $_terminal_notify_protocol == osc9 ]]
  output=$(bgnotify "build finished" "command completed" "")
  [[ $output == $'"'"'\e]9;build finished — command completed\e\\'"'"' ]]
' zsh "$plugin"

# Unknown terminals retain upstream bgnotify unchanged, preserving its native
# OS notification fallback instead of forcing an unsupported escape sequence.
zsh -f -c '
  unset WT_SESSION KITTY_WINDOW_ID TMUX ZELLIJ ZELLIJ_SESSION_NAME
  export TERM=xterm-256color
  export TERM_PROGRAM=unknown-terminal
  function bgnotify { print -r -- fallback; }
  source "$1"

  [[ -z $_terminal_notify_protocol ]]
  [[ "$(bgnotify one two three)" == fallback ]]
' zsh "$plugin"

# Exercise direct Ghostty hook removal using a fixture loaded through zsh's
# normal autoload mechanism. Direct Ghostty owns command completion via OSC 133.
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
  unset WT_SESSION KITTY_WINDOW_ID TMUX ZELLIJ ZELLIJ_SESSION_NAME
  export TERM_PROGRAM=ghostty
  source "$1"

  [[ -z ${preexec_functions[(r)bgnotify_begin]-} ]]
  [[ -z ${precmd_functions[(r)bgnotify_end]-} ]]
' zsh "$plugin" "$test_root/fpath"

# Inside tmux Ghostty cannot rely on OSC 133 reaching the outer terminal, so it
# falls back to an explicit OSC 777 notification through passthrough.
zsh -f -c '
  unset WT_SESSION KITTY_WINDOW_ID ZELLIJ ZELLIJ_SESSION_NAME
  export TERM_PROGRAM=ghostty
  export TMUX=/tmp/tmux-test
  function bgnotify { print -r -- fallback; }
  source "$1"

  [[ $_terminal_notify_protocol == osc777 ]]
  output=$(bgnotify "build finished" "command completed" "")
  [[ $output == $'"'"'\ePtmux;\e\e]777;notify;build finished;command completed\e\e\\\e\\'"'"' ]]
' zsh "$plugin"
