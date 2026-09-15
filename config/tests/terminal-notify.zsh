#!/usr/bin/env zsh
set -eu

repo_root=${0:A:h:h:h}
plugin="$repo_root/home/.config/sheldon/plugins/terminal-notify.plugin.zsh"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

# Windows Terminal installs its own command lifecycle hooks in an interactive shell.
WT_SESSION=ci TERM=xterm-256color zsh -f -i -c '
  set -eu
  plugin=$1
  test_root=$2
  typeset -ga preexec_functions precmd_functions
  source "$plugin"

  [[ ${preexec_functions[(r)_terminal_notify_preexec]-} == _terminal_notify_preexec ]]
  [[ ${precmd_functions[(r)_terminal_notify_precmd]-} == _terminal_notify_precmd ]]
  [[ $_terminal_notify_threshold == 5 ]]

  _terminal_notify_elapsed 65
  [[ $REPLY == "1m 5s" ]]

  # Successful commands use a clean title and preserve the command in the body.
  _terminal_notify_threshold=0
  _terminal_notify_started=$EPOCHSECONDS
  _terminal_notify_command=$'"'"'mise; run\nupdate'"'"'
  _terminal_notify_elapsed() { REPLY="12s"; }
  true
  _terminal_notify_precmd >"$test_root/success.out"
  output=$(<"$test_root/success.out")
  [[ $output == $'"'"'\e]777;notify;Command finished · 12s;mise, run update\e\\'"'"' ]]

  # Failed commands use the failure title.
  _terminal_notify_started=$EPOCHSECONDS
  _terminal_notify_command="cargo build --release"
  _terminal_notify_elapsed() { REPLY="1m 5s"; }
  set +e
  false
  _terminal_notify_precmd >"$test_root/failure.out"
  set -e
  output=$(<"$test_root/failure.out")
  [[ $output == $'"'"'\e]777;notify;Command failed · 1m 5s;cargo build --release\e\\'"'"' ]]

  # Commands below the threshold stay silent.
  _terminal_notify_threshold=999999
  _terminal_notify_started=$EPOCHSECONDS
  _terminal_notify_command="true"
  true
  _terminal_notify_precmd >"$test_root/short.out"
  [[ ! -s "$test_root/short.out" ]]
' terminal-notify-test "$plugin" "$test_root"

# Ghostty can inherit WT_SESSION from its parent Windows Terminal shell. The
# actual terminal identity must win so Ghostty keeps only its native notifier.
WT_SESSION=ci TERM_PROGRAM=ghostty TERM=xterm-ghostty zsh -f -i -c '
  set -eu
  plugin=$1
  typeset -ga preexec_functions precmd_functions
  source "$plugin"

  [[ -z ${preexec_functions[(r)_terminal_notify_preexec]-} ]]
  [[ -z ${precmd_functions[(r)_terminal_notify_precmd]-} ]]
' terminal-notify-test "$plugin"

# Unsupported terminals are left untouched when the Windows Terminal marker is absent.
TERM_PROGRAM=unknown-terminal TERM=xterm-256color zsh -f -i -c '
  set -eu
  plugin=$1
  typeset -ga preexec_functions precmd_functions
  unset WT_SESSION
  source "$plugin"

  [[ -z ${preexec_functions[(r)_terminal_notify_preexec]-} ]]
  [[ -z ${precmd_functions[(r)_terminal_notify_precmd]-} ]]
' terminal-notify-test "$plugin"
