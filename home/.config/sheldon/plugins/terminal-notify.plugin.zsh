# Route long-running command notifications through supported terminals.
# bgnotify remains the command-lifecycle source; this file only chooses delivery.

typeset -g _terminal_notify_protocol=''

_terminal_notify_disable_bgnotify() {
  autoload -Uz add-zsh-hook

  if (( ${+functions[bgnotify_begin]} )); then
    add-zsh-hook -d preexec bgnotify_begin
  fi
  if (( ${+functions[bgnotify_end]} )); then
    add-zsh-hook -d precmd bgnotify_end
  fi
}

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

_terminal_notify_osc777() {
  local title=$1
  local message=$2

  _terminal_notify_clean "$title"
  title=$REPLY
  _terminal_notify_clean "$message"
  message=$REPLY

  print -rn -- $'\e]777;notify;'"$title;$message"$'\e\\'
}

if [[ -n ${WT_SESSION:-} ]]; then
  _terminal_notify_protocol=osc777
  bgnotify_bell=false

  # Windows Terminal suppresses OSC 777 from its focused active pane, so let
  # the terminal make the focus decision instead of probing Windows from WSL.
  bgnotify_appid() {
    print -r -- '__terminal_notify_dispatch__'
  }
  bgnotify_termid='__terminal_notify_host_focus__'
elif [[ ${TERM_PROGRAM:-} == ghostty ]]; then
  # Ghostty owns command completion through its OSC 133 shell integration.
  _terminal_notify_disable_bgnotify
  return 0
else
  # Unsupported terminals keep upstream bgnotify unchanged.
  return 0
fi

bgnotify() {
  _terminal_notify_osc777 "$1" "$2"
}
