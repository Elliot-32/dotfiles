$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$packageId = 'DEVCOM.JetBrainsMonoNerdFont'
$alreadyInstalled = -1978335135 # 0x8A150061 APPINSTALLER_CLI_ERROR_PACKAGE_ALREADY_INSTALLED

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $winget) {
    throw 'WinGet is unavailable. Install or update Microsoft App Installer, then rerun the task.'
}

$arguments = @(
    'install',
    '--id', $packageId,
    '--exact',
    '--silent',
    '--accept-package-agreements',
    '--accept-source-agreements',
    '--disable-interactivity'
)

& $winget.Source @arguments
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host 'JetBrainsMono Nerd Font is installed or updated.'
    exit 0
}

if ($exitCode -eq $alreadyInstalled) {
    Write-Host 'JetBrainsMono Nerd Font is already installed.'
    exit 0
}

throw "winget install '$packageId' failed with exit code $exitCode"
