<#
.SYNOPSIS
    Downloads the standard (non-.NET) Godot 4 editor for Windows into tools/godot/.

.DESCRIPTION
    Fetches the latest stable Godot release from the official GitHub releases, picks the
    win64 standard build (not the Mono/C# build), and extracts it next to this script.
    The tools/godot/ folder is git-ignored, so the binary is never committed.

    Source is the official godotengine/godot GitHub releases only.

.EXAMPLE
    ./tools/install-godot.ps1
    ./tools/install-godot.ps1 -Version 4.4-stable
#>
[CmdletBinding()]
param(
    # Release tag to install, e.g. "4.4-stable". Defaults to the latest stable release.
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"
$destDir = Join-Path $PSScriptRoot "godot"

# Resolve which release to download.
if ([string]::IsNullOrWhiteSpace($Version)) {
    Write-Host "Looking up the latest stable Godot release..."
    $release = Invoke-RestMethod "https://api.github.com/repos/godotengine/godot/releases/latest" `
        -Headers @{ "User-Agent" = "metazoic-installer" }
} else {
    $release = Invoke-RestMethod "https://api.github.com/repos/godotengine/godot/releases/tags/$Version" `
        -Headers @{ "User-Agent" = "metazoic-installer" }
}

# Pick the standard win64 editor asset (exclude the mono/.NET build).
$asset = $release.assets |
    Where-Object { $_.name -match "win64\.exe\.zip$" -and $_.name -notmatch "mono" } |
    Select-Object -First 1

if (-not $asset) {
    throw "Could not find a standard win64 Godot asset in release '$($release.tag_name)'."
}

Write-Host "Release: $($release.tag_name)"
Write-Host "Asset:   $($asset.name)"

$zipPath = Join-Path $env:TEMP $asset.name
Write-Host "Downloading to $zipPath ..."
Invoke-WebRequest $asset.browser_download_url -OutFile $zipPath -UseBasicParsing

if (Test-Path $destDir) { Remove-Item $destDir -Recurse -Force }
New-Item -ItemType Directory -Path $destDir | Out-Null

Write-Host "Extracting to $destDir ..."
Expand-Archive -Path $zipPath -DestinationPath $destDir -Force
Remove-Item $zipPath -Force

$exe = Get-ChildItem $destDir -Filter "*.exe" -Recurse | Select-Object -First 1
if (-not $exe) { throw "Extraction finished but no .exe was found in $destDir." }

Write-Host ""
Write-Host "Godot installed:" -ForegroundColor Green
Write-Host "  $($exe.FullName)"
Write-Host ""
Write-Host "Open the project with:"
Write-Host "  & `"$($exe.FullName)`" --path `"$(Split-Path $PSScriptRoot -Parent)`""
