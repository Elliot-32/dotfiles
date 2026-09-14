param(
    [Parameter(Mandatory = $true)][string] $Title,
    [Parameter(Mandatory = $true)][string] $Message
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Exit codes consumed by wsl-notify.plugin.zsh:
#   0  toast displayed
#   10 Windows Terminal is focused; notification intentionally suppressed
#   11 foreground state could not be determined; fail closed
#   20 native toast delivery failed; the shell may fall back to BEL
$ExitToastShown = 0
$ExitFocused = 10
$ExitFocusUnknown = 11
$ExitDeliveryFailed = 20

function Get-ForegroundProcessName {
    try {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class ForegroundWindow {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
}
"@

        $window = [ForegroundWindow]::GetForegroundWindow()
        if ($window -eq [IntPtr]::Zero) {
            return $null
        }

        $foregroundProcessId = [uint32]0
        $threadId = [ForegroundWindow]::GetWindowThreadProcessId($window, [ref] $foregroundProcessId)
        if ($threadId -eq 0 -or $foregroundProcessId -eq 0) {
            return $null
        }

        return (Get-Process -Id $foregroundProcessId -ErrorAction Stop).ProcessName
    }
    catch {
        return $null
    }
}

function Get-NotificationAppId {
    $startApps = @(Get-StartApps)

    foreach ($candidate in @(
        'Microsoft.WindowsTerminal_8wekyb3d8bbwe!App',
        'Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe!App'
    )) {
        if ($startApps.AppID -contains $candidate) {
            return $candidate
        }
    }

    $appId = $startApps |
        Where-Object { $_.AppID -match '^Microsoft\.WindowsTerminal.*!App$' } |
        Select-Object -First 1 -ExpandProperty AppID

    if (-not [string]::IsNullOrWhiteSpace($appId)) {
        return $appId
    }

    return $startApps |
        Where-Object { $_.AppID -match 'PowerShell' } |
        Select-Object -First 1 -ExpandProperty AppID
}

$foregroundProcess = Get-ForegroundProcessName
if ([string]::IsNullOrWhiteSpace($foregroundProcess)) {
    exit $ExitFocusUnknown
}

if ($foregroundProcess -like 'WindowsTerminal*') {
    exit $ExitFocused
}

try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    $null = [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime]
    $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

    $appId = Get-NotificationAppId
    if ([string]::IsNullOrWhiteSpace($appId)) {
        throw 'No Start-menu AUMID suitable for WSL toast notifications was found.'
    }

    $document = [Windows.Data.Xml.Dom.XmlDocument]::new()
    $document.LoadXml('<toast><visual><binding template="ToastGeneric"><text/><text/></binding></visual><audio src="ms-winsoundevent:Notification.Default"/></toast>')
    $textNodes = $document.GetElementsByTagName('text')
    [void] $textNodes.Item(0).AppendChild($document.CreateTextNode($Title))
    [void] $textNodes.Item(1).AppendChild($document.CreateTextNode($Message))

    $toast = [Windows.UI.Notifications.ToastNotification]::new($document)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
    exit $ExitToastShown
}
catch {
    [Console]::Error.WriteLine("WSL notification failed: $($_.Exception.Message)")
    exit $ExitDeliveryFailed
}
