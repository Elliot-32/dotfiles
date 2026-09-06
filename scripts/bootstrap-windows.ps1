$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$fontPackage = 'JetBrainsMono-NF-Mono'
$fontFace = 'JetBrainsMono Nerd Font Mono'

function Invoke-ScoopCommand {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Arguments
    )

    & $script:ScoopCommand @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "scoop $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

function Test-ScoopPackage {
    param([Parameter(Mandatory = $true)][string] $Name)

    & $script:ScoopCommand prefix $Name *> $null
    return $LASTEXITCODE -eq 0
}

function Ensure-ScoopPackage {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [string] $InstallName = $Name
    )

    if (Test-ScoopPackage -Name $Name) {
        Write-Host "Scoop package '$Name' is already installed."
        return
    }

    Invoke-ScoopCommand install $InstallName
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
            elseif ($char -eq '\') {
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
            elseif ($char -eq '\') {
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

    if ($null -eq $property.Value -or $property.Value -is [string] -or $property.Value.GetType().IsValueType) {
        $property.Value = [pscustomobject] @{}
    }

    return $property.Value
}

function Set-WindowsTerminalFont {
    param(
        [Parameter(Mandatory = $true)][string] $SettingsPath,
        [Parameter(Mandatory = $true)][string] $Face
    )

    if (-not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) {
        $initialSettings = [pscustomobject] @{
            profiles = [pscustomobject] @{
                defaults = [pscustomobject] @{
                    font = [pscustomobject] @{
                        face = $Face
                    }
                }
            }
        }
        $json = $initialSettings | ConvertTo-Json -Depth 100
        [System.IO.File]::WriteAllText($SettingsPath, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
        Write-Host "Created Windows Terminal settings with font '$Face': $SettingsPath"
        return
    }

    $raw = [System.IO.File]::ReadAllText($SettingsPath)
    $json = Remove-JsonComments -Text $raw
    $json = Remove-JsonTrailingCommas -Text $json
    $settings = $json | ConvertFrom-Json

    $profiles = Get-OrAddObjectProperty -Object $settings -Name 'profiles'
    $defaults = Get-OrAddObjectProperty -Object $profiles -Name 'defaults'
    $font = Get-OrAddObjectProperty -Object $defaults -Name 'font'
    $faceProperty = $font.PSObject.Properties['face']

    if ($null -ne $faceProperty -and $faceProperty.Value -eq $Face) {
        Write-Host "Windows Terminal already uses '$Face': $SettingsPath"
        return
    }

    if ($null -eq $faceProperty) {
        $font | Add-Member -MemberType NoteProperty -Name 'face' -Value $Face
    }
    else {
        $faceProperty.Value = $Face
    }

    $backupPath = "$SettingsPath.dotfiles-backup"
    if (-not (Test-Path -LiteralPath $backupPath)) {
        Copy-Item -LiteralPath $SettingsPath -Destination $backupPath
    }

    $updated = $settings | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($SettingsPath, $updated + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Set Windows Terminal font to '$Face': $SettingsPath"
}

if ((Get-ExecutionPolicy -Scope CurrentUser) -ne 'RemoteSigned') {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
}

$scoop = Get-Command scoop -ErrorAction SilentlyContinue
if ($null -eq $scoop) {
    Write-Host 'Installing Scoop...'
    Invoke-RestMethod -Uri 'https://get.scoop.sh' | Invoke-Expression
}

$scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE 'scoop' }
$scoop = Get-Command scoop -ErrorAction SilentlyContinue
if ($null -ne $scoop -and $scoop.Source) {
    $script:ScoopCommand = $scoop.Source
}
else {
    $script:ScoopCommand = Join-Path $scoopRoot 'shims\scoop.ps1'
}

if (-not (Test-Path -LiteralPath $script:ScoopCommand)) {
    throw "Unable to find Scoop command at '$script:ScoopCommand'."
}

Ensure-ScoopPackage -Name 'git'

$nerdFontsBucket = Join-Path $scoopRoot 'buckets\nerd-fonts'
if (-not (Test-Path -LiteralPath $nerdFontsBucket -PathType Container)) {
    Invoke-ScoopCommand bucket add nerd-fonts
}

Ensure-ScoopPackage -Name $fontPackage -InstallName "nerd-fonts/$fontPackage"

$terminalStateDirectories = @(
    (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'),
    (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal')
) | Where-Object { Test-Path -LiteralPath $_ -PathType Container }

if ($terminalStateDirectories.Count -eq 0) {
    Write-Warning 'Windows Terminal settings directory was not found; skipping font configuration.'
    exit 0
}

foreach ($stateDirectory in $terminalStateDirectories) {
    Set-WindowsTerminalFont -SettingsPath (Join-Path $stateDirectory 'settings.json') -Face $fontFace
}
