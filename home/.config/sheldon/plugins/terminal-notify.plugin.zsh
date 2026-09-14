# Route long-running command notifications through supported terminals.
# bgnotify remains the command-lifecycle source; this file only chooses delivery.

bgnotify_bell=false
bgnotify_threshold=5

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

_terminal_notify_write() {
  local sequence=$1

  if [[ -n ${TMUX:-} ]]; then
    # tmux DCS passthrough requires every ESC in the nested sequence to be
    # doubled. `allow-passthrough` must be enabled in tmux for this to pass.
    sequence=${sequence//$'\e'/$'\e\e'}
    print -rn -- $'\ePtmux;'"$sequence"$'\e\\'
  else
    # Zellij understands notification OSC directly, so no extra envelope is
    # needed there.
    print -rn -- "$sequence"
  fi
}

_terminal_notify_osc777() {
  local title=$1
  local message=$2

  _terminal_notify_clean "$title"
  title=$REPLY
  _terminal_notify_clean "$message"
  message=$REPLY

  _terminal_notify_write $'\e]777;notify;'"$title;$message"$'\e\\'
}

if [[ -n ${WT_SESSION:-} ]]; then
  _terminal_notify_protocol=osc777

  # Windows Terminal already suppresses OSC 777 from its focused active pane.
  # Always let it make that decision instead of spawning a Windows focus probe.
  bgnotify_appid() {
    print -r -- '__terminal_notify_dispatch__'
  }
  bgnotify_termid='__terminal_notify_host_focus__'
else
  case ${TERM_PROGRAM:-} in
    ghostty)
      if [[ -z ${TMUX:-} && -z ${ZELLIJ:-} && -z ${ZELLIJ_SESSION_NAME:-} ]]; then
        # Direct Ghostty sessions have more accurate native OSC 133 command
        # tracking, including focus-aware command-finished notifications.
        _terminal_notify_disable_bgnotify
        return 0
      fi
      # Multiplexers can consume OSC 133 before Ghostty sees it. Emit an
      # explicit OSC 777 notification instead; tmux is wrapped above.
      _terminal_notify_protocol=osc777
      ;;
    rio)
      _terminal_notify_protocol=osc777
      ;;
  esac
fi

# Unsupported terminals keep upstream bgnotify's native OS fallbacks unchanged.
[[ -n $_terminal_notify_protocol ]] || return 0

bgnotify() {
  _terminal_notify_osc777 "$1" "$2"
}
