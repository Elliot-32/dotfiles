param(
    [Parameter(Mandatory = $true)][string] $Title,
    [Parameter(Mandatory = $true)][string] $Message
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
$null = [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime]
$null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

$startApps = @(Get-StartApps)
$appId = $startApps |
    Where-Object { $_.AppID -eq 'Microsoft.WindowsTerminal_8wekyb3d8bbwe!App' } |
    Select-Object -First 1 -ExpandProperty AppID

if ([string]::IsNullOrWhiteSpace($appId)) {
    $appId = $startApps |
        Where-Object { $_.AppID -match '^Microsoft\.WindowsTerminal.*!App$' } |
        Select-Object -First 1 -ExpandProperty AppID
}

if ([string]::IsNullOrWhiteSpace($appId)) {
    $appId = $startApps |
        Where-Object { $_.AppID -match 'PowerShell' } |
        Select-Object -First 1 -ExpandProperty AppID
}

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
