param(
    [ValidateSet(
        'catppuccin-mocha',
        'catppuccin-macchiato',
        'catppuccin-frappe',
        'catppuccin-latte',
        'tokyo-night',
        'dracula'
    )]
    [string] $Theme = 'catppuccin-mocha'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$gitPackage = 'Git.Git'
$fontPackage = 'DEVCOM.JetBrainsMonoNerdFont'
$fontFace = 'JetBrainsMono Nerd Font Mono'
$wingetPackageAlreadyInstalled = -1978335135 # 0x8A150061 APPINSTALLER_CLI_ERROR_PACKAGE_ALREADY_INSTALLED
$terminalAssetsDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\windows-terminal'

$themeFiles = @{
    'catppuccin-mocha' = @('catppuccin', 'mocha.json', 'mochaTheme.json')
    'catppuccin-macchiato' = @('catppuccin', 'macchiato.json', 'macchiatoTheme.json')
    'catppuccin-frappe' = @('catppuccin', 'frappe.json', 'frappeTheme.json')
    'catppuccin-latte' = @('catppuccin', 'latte.json', 'latteTheme.json')
    'tokyo-night' = @('tokyo-night', 'tokyo-night.json', 'theme.json')
    'dracula' = @('dracula', 'dracula.json', 'theme.json')
}

$themeDefinition = $themeFiles[$Theme]
$terminalThemeDirectory = Join-Path $terminalAssetsDirectory $themeDefinition[0]
$terminalSchemePath = Join-Path $terminalThemeDirectory $themeDefinition[1]
$terminalThemePath = Join-Path $terminalThemeDirectory $themeDefinition[2]

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

function Remove-JsonComments {
    param([Parameter(Mandatory = $true)][string] $Text)

    $builder = [System.Text.StringBuilder]::new()
    $inString = $false
    $escaped = $false
    $lineComment = $false
    $blockComment = $false

    for ($i = 0; $i -lt $Text.Length; $i++) {
        $char = $Text[$i]
        $next = if ($i + 1 -lt $Text.Length) { $Text[$i + 1] } else { [char]0 }

        if ($lineComment) {
            if ($char -eq "`r" -or $char -eq "`n") {
                [void] $builder.Append($char)
                $lineComment = $false
            }
            continue
        }

        if ($blockComment) {
            if ($char -eq '*' -and $next -eq '/') {
                $i++
                $blockComment = $false
            }
            elseif ($char -eq "`r" -or $char -eq "`n") {
                [void] $builder.Append($char)
            }
            continue
        }

        if ($inString) {
            [void] $builder.Append($char)
            if ($escaped) {
                $escaped = $false
            }
            elseif ($char -eq '\\') {
                $escaped = $true
            }
            elseif ($char -eq '"') {
                $inString = $false
            }
            continue
        }

        if ($char -eq '"') {
            $inString = $true
            [void] $builder.Append($char)
        }
        elseif ($char -eq '/' -and $next -eq '/') {
            $lineComment = $true
            $i++
        }
        elseif ($char -eq '/' -and $next -eq '*') {
            $blockComment = $true
            $i++
        }
        else {
            [void] $builder.Append($char)
        }
    }

    return $builder.ToString()
}

function Remove-JsonTrailingCommas {
    param([Parameter(Mandatory = $true)][string] $Text)

    $builder = [System.Text.StringBuilder]::new()
    $inString = $false
    $escaped = $false

    for ($i = 0; $i -lt $Text.Length; $i++) {
        $char = $Text[$i]

        if ($inString) {
            [void] $builder.Append($char)
            if ($escaped) {
                $escaped = $false
            }
            elseif ($char -eq '\\') {
                $escaped = $true
            }
            elseif ($char -eq '"') {
                $inString = $false
            }
            continue
        }

        if ($char -eq '"') {
            $inString = $true
            [void] $builder.Append($char)
            continue
        }

        if ($char -eq ',') {
            $nextIndex = $i + 1
            while ($nextIndex -lt $Text.Length -and [char]::IsWhiteSpace($Text[$nextIndex])) {
                $nextIndex++
            }

            if ($nextIndex -lt $Text.Length -and ($Text[$nextIndex] -eq '}' -or $Text[$nextIndex] -eq ']')) {
                continue
            }
        }

        [void] $builder.Append($char)
    }

    return $builder.ToString()
}

function Get-OrAddObjectProperty {
    param(
        [Parameter(Mandatory = $true)] $Object,
        [Parameter(Mandatory = $true)][string] $Name
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        $value = [pscustomobject] @{}
        $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $value
        return $value
    }

    if ($null -eq $property.Value -or $property.Value -isnot [pscustomobject]) {
        $property.Value = [pscustomobject] @{}
    }

    return $property.Value
}

function Set-ObjectPropertyValue {
    param(
        [Parameter(Mandatory = $true)] $Object,
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)] $Value
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
        return
    }

    $property.Value = $Value
}

function Set-NamedArrayEntry {
    param(
        [Parameter(Mandatory = $true)] $Object,
        [Parameter(Mandatory = $true)][string] $PropertyName,
        [Parameter(Mandatory = $true)] $Entry
    )

    $entryName = [string] $Entry.name
    $property = $Object.PSObject.Properties[$PropertyName]
    $entries = if ($null -eq $property -or $null -eq $property.Value) { @() } else { @($property.Value) }
    $filtered = @(
        $entries | Where-Object {
            $nameProperty = $_.PSObject.Properties['name']
            $null -eq $nameProperty -or [string] $nameProperty.Value -ne $entryName
        }
    )
    $updated = @($filtered + @($Entry))

    if ($null -eq $property) {
        $Object | Add-Member -MemberType NoteProperty -Name $PropertyName -Value $updated
        return
    }

    $property.Value = $updated
}

function Set-WindowsTerminalAppearance {
    param(
        [Parameter(Mandatory = $true)][string] $SettingsPath,
        [Parameter(Mandatory = $true)][string] $Face,
        [Parameter(Mandatory = $true)] $Scheme,
        [Parameter(Mandatory = $true)] $TerminalTheme
    )

    $schemeName = [string] $Scheme.name
    $themeName = [string] $TerminalTheme.name

    if (-not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) {
        $initialSettings = [pscustomobject] @{
            theme = $themeName
            profiles = [pscustomobject] @{
                defaults = [pscustomobject] @{
                    colorScheme = $schemeName
                    font = [pscustomobject] @{
                        face = $Face
                    }
                }
            }
            schemes = @($Scheme)
            themes = @($TerminalTheme)
        }
        $json = $initialSettings | ConvertTo-Json -Depth 100
        [System.IO.File]::WriteAllText($SettingsPath, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
        Write-Host "Created Windows Terminal settings with '$schemeName': $SettingsPath"
        return
    }

    $raw = [System.IO.File]::ReadAllText($SettingsPath)
    $json = Remove-JsonComments -Text $raw
    $json = Remove-JsonTrailingCommas -Text $json
    $settings = $json | ConvertFrom-Json

    if ($null -eq $settings) {
        $settings = [pscustomobject] @{}
    }

    $profiles = Get-OrAddObjectProperty -Object $settings -Name 'profiles'
    $defaults = Get-OrAddObjectProperty -Object $profiles -Name 'defaults'
    $font = Get-OrAddObjectProperty -Object $defaults -Name 'font'

    Set-ObjectPropertyValue -Object $font -Name 'face' -Value $Face
    Set-ObjectPropertyValue -Object $defaults -Name 'colorScheme' -Value $schemeName
    Set-ObjectPropertyValue -Object $settings -Name 'theme' -Value $themeName
    Set-NamedArrayEntry -Object $settings -PropertyName 'schemes' -Entry $Scheme
    Set-NamedArrayEntry -Object $settings -PropertyName 'themes' -Entry $TerminalTheme

    $backupPath = "$SettingsPath.dotfiles-backup"
    if (-not (Test-Path -LiteralPath $backupPath)) {
        Copy-Item -LiteralPath $SettingsPath -Destination $backupPath
    }

    $updated = $settings | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($SettingsPath, $updated + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Set Windows Terminal font and theme to '$schemeName': $SettingsPath"
}

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $winget) {
    throw 'WinGet is unavailable. Install or update Microsoft App Installer, then rerun the bootstrap.'
}

$script:WinGetCommand = $winget.Source
Invoke-WinGetInstall -Id $gitPackage
Invoke-WinGetInstall -Id $fontPackage

if (-not (Test-Path -LiteralPath $terminalSchemePath -PathType Leaf)) {
    throw "Windows Terminal color scheme is missing: $terminalSchemePath"
}
if (-not (Test-Path -LiteralPath $terminalThemePath -PathType Leaf)) {
    throw "Windows Terminal theme is missing: $terminalThemePath"
}

$terminalScheme = Get-Content -LiteralPath $terminalSchemePath -Raw | ConvertFrom-Json
$terminalTheme = Get-Content -LiteralPath $terminalThemePath -Raw | ConvertFrom-Json

$terminalStateDirectories = @(
    @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalCanary_8wekyb3d8bbwe\LocalState'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal')
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Container }
)

if ($terminalStateDirectories.Count -eq 0) {
    Write-Warning 'Windows Terminal settings directory was not found; skipping appearance configuration.'
    exit 0
}

foreach ($stateDirectory in $terminalStateDirectories) {
    Set-WindowsTerminalAppearance -SettingsPath (Join-Path $stateDirectory 'settings.json') -Face $fontFace -Scheme $terminalScheme -TerminalTheme $terminalTheme
}
