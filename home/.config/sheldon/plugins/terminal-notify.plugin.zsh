# Notify on long-running commands in Windows Terminal using OSC 777.
# Ghostty handles command completion itself through OSC 133 shell integration,
# while Herdr emits its own terminal notifications.

[[ -o interactive ]] || return 0

# Ghostty can inherit WT_SESSION when launched from a Windows Terminal WSL
# shell. Prefer the actual terminal identity so its native command-finish
# notifications are not duplicated by the Windows Terminal hook.
[[ ${TERM_PROGRAM:-} == ghostty ]] && return 0

# tmux notification passthrough is intentionally outside this notifier's scope.
[[ -n ${TMUX:-} ]] && return 0
[[ -n ${WT_SESSION:-} ]] || return 0

zmodload zsh/datetime
autoload -Uz add-zsh-hook

typeset -g _terminal_notify_threshold=5
typeset -g _terminal_notify_started=0
typeset -g _terminal_notify_command=''

_terminal_notify_clean() {
  local value=$1
  value=${value//$'\e'/}
  value=${value//$'\a'/}
  value=${value//$'\n'/ }
  value=${value//$'\r'/ }
  value=${value//$'\t'/ }
  value=${value//;/,}
  REPLY=$value
}

_terminal_notify_elapsed() {
  local elapsed=$1

  if (( elapsed < 60 )); then
    REPLY="${elapsed}s"
  elif (( elapsed < 3600 )); then
    REPLY="$(( elapsed / 60 ))m $(( elapsed % 60 ))s"
  else
    REPLY="$(( elapsed / 3600 ))h $(( (elapsed % 3600) / 60 ))m $(( elapsed % 60 ))s"
  fi
}

_terminal_notify_osc777() {
  local title=$1
  local message=$2

  _terminal_notify_clean "$title"
  title=$REPLY
  _terminal_notify_clean "$message"
  message=$REPLY

  print -rn -- $'\e]777;notify;'"$title;$message"$'\e\\'
}

_terminal_notify_preexec() {
  _terminal_notify_started=$EPOCHSECONDS
  _terminal_notify_command=${1:-$2}
}

_terminal_notify_precmd() {
  local exit_status=$?
  local started=$_terminal_notify_started
  local command=$_terminal_notify_command

  _terminal_notify_started=0
  _terminal_notify_command=''

  (( started > 0 )) || return 0

  local elapsed=$(( EPOCHSECONDS - started ))
  (( elapsed >= _terminal_notify_threshold )) || return 0

  _terminal_notify_elapsed "$elapsed"
  local duration=$REPLY
  local title

  if (( exit_status == 0 )); then
    title="Command finished · $duration"
  else
    title="Command failed · $duration"
  fi

  _terminal_notify_osc777 "$title" "$command"
}

add-zsh-hook preexec _terminal_notify_preexec
add-zsh-hook precmd _terminal_notify_precmd
