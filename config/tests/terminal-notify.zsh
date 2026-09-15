#!/usr/bin/env zsh
set -eu

repo_root=${0:A:h:h:h}
plugin="$repo_root/home/.config/sheldon/plugins/terminal-notify.plugin.zsh"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

# Windows Terminal installs its own command lifecycle hooks.
(
  typeset -ga preexec_functions precmd_functions
  unset TERM_PROGRAM
  export TERM=xterm-256color
  export WT_SESSION=ci
  source "$plugin"

  [[ ${preexec_functions[(r)_terminal_notify_preexec]-} == _terminal_notify_preexec ]]
  [[ ${precmd_functions[(r)_terminal_notify_precmd]-} == _terminal_notify_precmd ]]
  [[ $_terminal_notify_threshold == 5 ]]

  _terminal_notify_elapsed 65
  [[ $REPLY == '1m 5s' ]]

  # Successful commands use a clean title and preserve the command in the body.
  _terminal_notify_threshold=0
  _terminal_notify_started=$EPOCHSECONDS
  _terminal_notify_command=$'mise; run\nupdate'
  _terminal_notify_elapsed() { REPLY='12s'; }
  true
  _terminal_notify_precmd >"$test_root/success.out"
  output=$(<"$test_root/success.out")
  [[ $output == $'\e]777;notify;Command finished · 12s;mise, run update\e\\' ]]

  # Failed commands use the failure title.
  _terminal_notify_started=$EPOCHSECONDS
  _terminal_notify_command='cargo build --release'
  _terminal_notify_elapsed() { REPLY='1m 5s'; }
  set +e
  false
  _terminal_notify_precmd >"$test_root/failure.out"
  set -e
  output=$(<"$test_root/failure.out")
  [[ $output == $'\e]777;notify;Command failed · 1m 5s;cargo build --release\e\\' ]]

  # Commands below the threshold stay silent.
  _terminal_notify_threshold=999999
  _terminal_notify_started=$EPOCHSECONDS
  _terminal_notify_command='true'
  true
  _terminal_notify_precmd >"$test_root/short.out"
  [[ ! -s "$test_root/short.out" ]]
)

# Ghostty handles command completion itself, so this plugin installs no hooks.
(
  typeset -ga preexec_functions precmd_functions
  unset WT_SESSION
  export TERM_PROGRAM=ghostty
  source "$plugin"

  [[ -z ${preexec_functions[(r)_terminal_notify_preexec]-} ]]
  [[ -z ${precmd_functions[(r)_terminal_notify_precmd]-} ]]
)

# Unsupported terminals are left untouched.
(
  typeset -ga preexec_functions precmd_functions
  unset WT_SESSION
  export TERM_PROGRAM=unknown-terminal
  source "$plugin"

  [[ -z ${preexec_functions[(r)_terminal_notify_preexec]-} ]]
  [[ -z ${precmd_functions[(r)_terminal_notify_precmd]-} ]]
)
