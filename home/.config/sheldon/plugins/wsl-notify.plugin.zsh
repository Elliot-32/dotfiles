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
    # Send a real Windows toast; its default audio replaces the terminal BEL.
    local toast_script="${MISE_CONFIG_DIR:-$HOME/.config/mise}/scripts/wsl-toast.ps1"
    local windows_toast_script

    if [[ -r $toast_script ]] && (( ${+commands[powershell.exe]} )) && (( ${+commands[wslpath]} )); then
      windows_toast_script=$(command wslpath -w "$toast_script") || windows_toast_script=
      if [[ -n $windows_toast_script ]] && powershell.exe -NoLogo -NoProfile -NonInteractive \
        -ExecutionPolicy Bypass -File "$windows_toast_script" \
        -Title "$title" -Message "$message" >/dev/null 2>&1; then
        return
      fi
    fi

    # Keep the old audible notification as a fallback if native toast delivery
    # is unavailable or fails unexpectedly.
    print -rn -- $'\a'
  elif (( ${+commands[notify-send]} )); then
    command notify-send "$title" "$message" \
      ${=icon:+--icon "$icon"} ${=bgnotify_extraargs:-}
  fi
}
