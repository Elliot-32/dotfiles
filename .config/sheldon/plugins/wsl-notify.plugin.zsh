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

# Windows Terminal is outside WSL's X/Wayland tree. Query Win32 directly so
# bgnotify only fires when Windows Terminal is not the foreground application.
if [[ -n ${WT_SESSION:-} ]]; then
  if [[ -n ${commands[powershell.exe]:-} ]]; then
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
  else
    # Without the Win32 foreground probe we cannot guarantee background-only
    # notifications, so fail closed instead of notifying while focused.
    autoload -Uz add-zsh-hook
    add-zsh-hook -d preexec bgnotify_begin
    add-zsh-hook -d precmd bgnotify_end
    return
  fi
fi

function bgnotify {
  local title="$1"
  local message="$2"
  local icon="$3"

  if [[ -n ${WT_SESSION:-} ]]; then
    # bgnotify_end already verified that Windows Terminal is in the background.
    # Let Windows Terminal translate BEL according to its bellStyle setting.
    print -rn -- $'\a'
  elif (( ${+commands[notify-send]} )); then
    command notify-send "$title" "$message" \
      ${=icon:+--icon "$icon"} ${=bgnotify_extraargs:-}
  fi
}
