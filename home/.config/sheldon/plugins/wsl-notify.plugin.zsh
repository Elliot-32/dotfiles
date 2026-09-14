# Configure bgnotify for terminals hosted by Windows.
[[ -n ${WSL_DISTRO_NAME:-} || -n ${WSL_INTEROP:-} ]] || return

bgnotify_bell=false
bgnotify_threshold=5

if [[ ${TERM_PROGRAM:-} == ghostty ]]; then
  # Ghostty provides accurate command-finished notifications itself.
  autoload -Uz add-zsh-hook
  add-zsh-hook -d preexec bgnotify_begin
  add-zsh-hook -d precmd bgnotify_end
  return
fi

if [[ -n ${WT_SESSION:-} ]]; then
  if [[ -z ${commands[powershell.exe]:-} || -z ${commands[wslpath]:-} ]]; then
    # Without the Windows-native helper path we cannot reliably distinguish a
    # focused terminal from a background one, so fail closed.
    autoload -Uz add-zsh-hook
    add-zsh-hook -d preexec bgnotify_begin
    add-zsh-hook -d precmd bgnotify_end
    return
  fi

  # Keep upstream bgnotify's timing and command formatting, but defer the
  # Windows foreground check to wsl-notify.ps1. These fixed, unequal IDs make
  # bgnotify_end dispatch without spawning a separate PowerShell probe.
  function bgnotify_appid {
    print -r -- '__wsl_notify_dispatch__'
  }
  bgnotify_termid='__wsl_notify_terminal_foreground__'
fi

function bgnotify {
  local title="$1"
  local message="$2"
  local icon="$3"

  if [[ -n ${WT_SESSION:-} ]]; then
    local notify_script="${MISE_CONFIG_DIR:-$HOME/.config/mise}/scripts/wsl-notify.ps1"
    local windows_notify_script
    local notify_status

    # If the helper cannot be resolved, suppress the notification rather than
    # guessing whether Windows Terminal is focused.
    [[ -r $notify_script ]] || return 0
    windows_notify_script=$(command wslpath -w "$notify_script") || return 0
    [[ -n $windows_notify_script ]] || return 0

    powershell.exe -NoLogo -NoProfile -NonInteractive \
      -ExecutionPolicy Bypass -File "$windows_notify_script" \
      -Title "$title" -Message "$message" >/dev/null 2>&1
    notify_status=$?

    case $notify_status in
      0|10|11)
        # Toast delivered, intentionally suppressed while focused, or focus
        # state was indeterminate and the helper failed closed.
        return 0
        ;;
      *)
        # Native delivery failed after dispatch; retain an audible fallback.
        print -rn -- $'\a'
        ;;
    esac
  elif (( ${+commands[notify-send]} )); then
    command notify-send "$title" "$message" \
      ${=icon:+--icon "$icon"} ${=bgnotify_extraargs:-}
  fi
}
