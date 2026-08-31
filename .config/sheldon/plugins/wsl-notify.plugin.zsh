# Configure bgnotify for terminals hosted by Windows.
[[ -n ${WSL_DISTRO_NAME:-} || -n ${WSL_INTEROP:-} ]] || return

bgnotify_bell=false
bgnotify_threshold=30

if [[ ${TERM_PROGRAM:-} == ghostty ]]; then
  # Ghostty provides accurate command-finished notifications itself.
  autoload -Uz add-zsh-hook
  add-zsh-hook -d preexec bgnotify_begin
  add-zsh-hook -d precmd bgnotify_end
  return
fi

# Windows Terminal is outside WSL's X/Wayland tree. Query Win32 directly so
# bgnotify only fires when Windows Terminal is not the foreground application.
if [[ -n ${WT_SESSION:-} && -n ${commands[powershell.exe]:-} ]]; then
  function bgnotify_appid {
    local process_name
    process_name=$(
      powershell.exe -NoLogo -NoProfile -NonInteractive -Command '
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class ForegroundWindow {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
}
"@
$window = [ForegroundWindow]::GetForegroundWindow()
$foregroundPid = [uint32]0
[void][ForegroundWindow]::GetWindowThreadProcessId($window, [ref]$foregroundPid)
(Get-Process -Id $foregroundPid).ProcessName
' 2>/dev/null | tr -d '\r\n'
    )
    print -r -- "${process_name:-$EPOCHSECONDS}"
  }
  bgnotify_termid=WindowsTerminal
fi

function bgnotify {
  local title="$1"
  local message="$2"
  local icon="$3"

  if (( ${+commands[wsl-notify-send.exe]} )); then
    command wsl-notify-send.exe \
      --category "${WSL_DISTRO_NAME:-WSL}" \
      "$title" "$message" &>/dev/null && return 0
  fi

  # Windows Terminal versions with OSC 777 support suppress notifications
  # while focused. Older versions safely ignore the sequence.
  if [[ -n ${WT_SESSION:-} ]]; then
    title=${title//$'\e'/}
    title=${title//;/,}
    message=${message//$'\e'/}
    message=${message//$'\a'/}
    message=${message//$'\n'/ }
    message=${message//;/,}
    print -rn -- $'\e]777;notify;'"$title;$message"$'\e\\'
  elif (( ${+commands[notify-send]} )); then
    command notify-send "$title" "$message" \
      ${=icon:+--icon "$icon"} ${=bgnotify_extraargs:-}
  fi
}
