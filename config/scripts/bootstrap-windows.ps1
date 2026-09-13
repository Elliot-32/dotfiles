$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$fontPackage = 'DEVCOM.JetBrainsMonoNerdFont'
$wingetPackageAlreadyInstalled = -1978335135 # 0x8A150061 APPINSTALLER_CLI_ERROR_PACKAGE_ALREADY_INSTALLED

function Invoke-WinGetInstall {
    param([Parameter(Mandatory = $true)][string] $Id)

    $arguments = @(
        'install',
        '--id', $Id,
        '--exact',
        '--silent',
        '--no-upgrade',
        '--accept-package-agreements',
        '--accept-source-agreements',
        '--disable-interactivity'
    )

    & $script:WinGetCommand @arguments
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        return
    }

    if ($exitCode -eq $script:wingetPackageAlreadyInstalled) {
        Write-Host "WinGet package '$Id' is already installed."
        return
    }

    throw "winget install '$Id' failed with exit code $exitCode"
}

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $winget) {
    throw 'WinGet is unavailable. Install or update Microsoft App Installer, then rerun the bootstrap.'
}

$script:WinGetCommand = $winget.Source
Invoke-WinGetInstall -Id $fontPackage

Write-Host 'Windows JetBrainsMono Nerd Font is configured.'
