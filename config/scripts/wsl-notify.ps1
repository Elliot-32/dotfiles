param(
    [Parameter(Mandatory = $true)][string] $Title,
    [Parameter(Mandatory = $true)][string] $Message,
    [string] $DistroName = ''
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

function Get-WslDistroIconPath {
    param([string] $Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $null
    }

    foreach ($root in @(\\"\\wsl.localhost\\$Name\\", \\"\\wsl`$\\$Name\\")) {
        $configPath = Join-Path -Path $root -ChildPath 'etc\wsl-distribution.conf'
        if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
            continue
        }

        try {
            $section = ''
            $linuxIconPath = $null

            foreach ($rawLine in Get-Content -LiteralPath $configPath -ErrorAction Stop) {
                $line = ($rawLine -split '[#;]', 2)[0].Trim()
                if ($line.Length -eq 0) {
                    continue
                }

                if ($line -match '^\[(?<Section>[^\]]+)\]$') {
                    $section = $Matches['Section'].Trim()
                    continue
                }

                if ($section -ieq 'shortcut' -and $line -match '^(?i:icon)\s*=\s*(?<Icon>.+)$') {
                    $linuxIconPath = $Matches['Icon'].Trim()
                    if (($linuxIconPath.StartsWith('"') -and $linuxIconPath.EndsWith('"')) -or
                        ($linuxIconPath.StartsWith("'") -and $linuxIconPath.EndsWith("'"))) {
                        $linuxIconPath = $linuxIconPath.Substring(1, $linuxIconPath.Length - 2)
                    }
                    break
                }
            }

            if ([string]::IsNullOrWhiteSpace($linuxIconPath) -or -not $linuxIconPath.StartsWith('/')) {
                continue
            }

            $relativePath = $linuxIconPath.TrimStart('/').Replace('/', '\')
            $candidate = Join-Path -Path $root -ChildPath $relativePath
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return $candidate
            }
        }
        catch {
            continue
        }
    }

    return $null
}

function Get-WslDistroIconUri {
    param([string] $Name)

    $sourcePath = Get-WslDistroIconPath -Name $Name
    if ([string]::IsNullOrWhiteSpace($sourcePath)) {
        return $null
    }

    $extension = [IO.Path]::GetExtension($sourcePath).ToLowerInvariant()
    if ($extension -in @('.png', '.jpg', '.jpeg', '.svg')) {
        return ([Uri] $sourcePath).AbsoluteUri
    }

    if ($extension -ne '.ico') {
        return $null
    }

    try {
        Add-Type -AssemblyName System.Drawing

        $localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
        if ([string]::IsNullOrWhiteSpace($localAppData)) {
            return $null
        }

        $cacheDirectory = Join-Path -Path $localAppData -ChildPath 'wsl-notify\icons'
        [void] [IO.Directory]::CreateDirectory($cacheDirectory)

        $sha256 = [Security.Cryptography.SHA256]::Create()
        try {
            $cacheKey = [Text.Encoding]::UTF8.GetBytes("$Name`0$sourcePath")
            $hash = [BitConverter]::ToString($sha256.ComputeHash($cacheKey)).Replace('-', '').ToLowerInvariant()
        }
        finally {
            $sha256.Dispose()
        }

        $cachePath = Join-Path -Path $cacheDirectory -ChildPath "$hash.png"
        $sourceInfo = Get-Item -LiteralPath $sourcePath -ErrorAction Stop
        $refreshCache = -not (Test-Path -LiteralPath $cachePath -PathType Leaf)
        if (-not $refreshCache) {
            $cacheInfo = Get-Item -LiteralPath $cachePath -ErrorAction Stop
            $refreshCache = $cacheInfo.LastWriteTimeUtc -lt $sourceInfo.LastWriteTimeUtc
        }

        if ($refreshCache) {
            $icon = New-Object -TypeName System.Drawing.Icon -ArgumentList @($sourcePath, 48, 48)
            try {
                $bitmap = $icon.ToBitmap()
                try {
                    $bitmap.Save($cachePath, [System.Drawing.Imaging.ImageFormat]::Png)
                }
                finally {
                    $bitmap.Dispose()
                }
            }
            finally {
                $icon.Dispose()
            }
        }

        return ([Uri] $cachePath).AbsoluteUri
    }
    catch {
        return $null
    }
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

    $iconUri = Get-WslDistroIconUri -Name $DistroName
    if (-not [string]::IsNullOrWhiteSpace($iconUri)) {
        $binding = $document.SelectSingleNode('/toast/visual/binding')
        $image = $document.CreateElement('image')
        $image.SetAttribute('placement', 'appLogoOverride')
        $image.SetAttribute('src', $iconUri)
        if (-not [string]::IsNullOrWhiteSpace($DistroName)) {
            $image.SetAttribute('alt', $DistroName)
        }
        [void] $binding.AppendChild($image)
    }

    $toast = [Windows.UI.Notifications.ToastNotification]::new($document)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
    exit $ExitToastShown
}
catch {
    [Console]::Error.WriteLine("WSL notification failed: $($_.Exception.Message)")
    exit $ExitDeliveryFailed
}
