param(
    [Parameter(Mandatory = $true)]
    [string] $ThemeFile
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

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

function Set-WindowsTerminalTheme {
    param(
        [Parameter(Mandatory = $true)][string] $SettingsPath,
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
    Write-Host "Set Windows Terminal theme to '$schemeName': $SettingsPath"
}

if (-not (Test-Path -LiteralPath $ThemeFile -PathType Leaf)) {
    throw "Tinty Windows Terminal theme file is missing: $ThemeFile"
}

$generated = Get-Content -LiteralPath $ThemeFile -Raw | ConvertFrom-Json
$scheme = $generated.scheme
$terminalTheme = $generated.theme
if ($null -eq $scheme -or $null -eq $terminalTheme) {
    throw "Tinty Windows Terminal theme file must contain 'scheme' and 'theme': $ThemeFile"
}

$terminalStateDirectories = @(
    @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalCanary_8wekyb3d8bbwe\LocalState'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal')
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Container }
)

if ($terminalStateDirectories.Count -eq 0) {
    Write-Warning 'Windows Terminal settings directory was not found; skipping theme configuration.'
    exit 0
}

foreach ($stateDirectory in $terminalStateDirectories) {
    Set-WindowsTerminalTheme -SettingsPath (Join-Path $stateDirectory 'settings.json') -Scheme $scheme -TerminalTheme $terminalTheme
}
