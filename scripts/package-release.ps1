[CmdletBinding()]
param(
    [string]$Version,
    [string]$HelperBaseUrl = 'https://github.com/gvp9000/UniExtract2/releases/download/v3.0.6/UniExtract2.zip'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not $Version) {
    $Version = (Get-Content -LiteralPath (Join-Path $RepoRoot 'VERSION') -Raw).Trim()
}

$Dist = Join-Path $RepoRoot 'dist'
$BuildRoot = Join-Path $RepoRoot '.build'
$BaseZip = Join-Path $BuildRoot 'helper-base.zip'
$ExtractRoot = Join-Path $BuildRoot 'helper-base'
$StageRoot = Join-Path $BuildRoot 'release'

Remove-Item -LiteralPath $Dist -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $BuildRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $Dist, $BuildRoot, $ExtractRoot, $StageRoot -Force | Out-Null

foreach ($File in @('UniExtract.exe', 'UniExtractUpdater.exe', 'UniExtractUpdater_NoAdmin.exe')) {
    $Path = Join-Path $RepoRoot $File
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$File is missing. Run scripts\build.ps1 first."
    }
}

Write-Host "Downloading helper base: $HelperBaseUrl"
Invoke-WebRequest -Uri $HelperBaseUrl -OutFile $BaseZip -UseBasicParsing
Expand-Archive -LiteralPath $BaseZip -DestinationPath $ExtractRoot -Force

$PackageRoot = $null
if (Test-Path -LiteralPath (Join-Path $ExtractRoot 'UniExtract.exe')) {
    $PackageRoot = $ExtractRoot
} else {
    $CandidateDirs = @(Get-ChildItem -LiteralPath $ExtractRoot -Directory)
    foreach ($Candidate in $CandidateDirs) {
        if (Test-Path -LiteralPath (Join-Path $Candidate.FullName 'UniExtract.exe')) {
            $PackageRoot = $Candidate.FullName
            break
        }
    }
}

if (-not $PackageRoot) {
    Write-Host 'Top-level helper archive entries:'
    Get-ChildItem -LiteralPath $ExtractRoot | ForEach-Object { Write-Host " - $($_.Name)" }
    throw 'Could not locate UniExtract.exe inside the helper base package.'
}

Write-Host "Helper package root: $PackageRoot"
Copy-Item -Path (Join-Path $PackageRoot '*') -Destination $StageRoot -Recurse -Force

$HelperRefreshScript = Join-Path $PSScriptRoot 'refresh-helpers.ps1'
$HelperRefreshRoot = Join-Path $BuildRoot 'helper-refresh'
if (-not (Test-Path -LiteralPath $HelperRefreshScript)) {
    throw "Helper refresh script not found: $HelperRefreshScript"
}
& $HelperRefreshScript -StageRoot $StageRoot -WorkRoot $HelperRefreshRoot

foreach ($File in @('UniExtract.exe', 'UniExtractUpdater.exe', 'UniExtractUpdater_NoAdmin.exe', 'English.ini', 'README.md', 'LICENSE', 'VERSION')) {
    Copy-Item -LiteralPath (Join-Path $RepoRoot $File) -Destination (Join-Path $StageRoot $File) -Force
}

foreach ($Dir in @('def', 'lang', 'docs')) {
    $Dest = Join-Path $StageRoot $Dir
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null
    Copy-Item -Path (Join-Path $RepoRoot "$Dir\*") -Destination $Dest -Recurse -Force
}

$IconDest = Join-Path $StageRoot 'support\Icons'
New-Item -ItemType Directory -Path $IconDest -Force | Out-Null
Copy-Item -Path (Join-Path $RepoRoot 'support\Icons\*') -Destination $IconDest -Recurse -Force
Remove-Item -Path (Join-Path $IconDest 'gvp9000*.png') -Force -ErrorAction SilentlyContinue

$Commit = $env:GITHUB_SHA
if (-not $Commit) {
    try {
        $Commit = (git -C $RepoRoot rev-parse HEAD 2>$null).Trim()
    } catch {
        $Commit = 'unknown'
    }
}
if (-not $Commit) { $Commit = 'unknown' }

@"
Universal Extractor 2
Version: $Version
Source: https://github.com/wefalltomorrow/UniExtract2
Commit: $Commit
Helper package base: gvp9000 UniExtract2 v3.0.6
Maintained helper overlay: scripts\refresh-helpers.ps1

Third-party helpers retain their own licenses. See docs and docs\third-party in this package.
"@ | Set-Content -LiteralPath (Join-Path $StageRoot 'BUILD-INFO.txt') -Encoding UTF8

$ZipName = "UniExtract2-v$Version.zip"
$ZipPath = Join-Path $Dist $ZipName
Compress-Archive -Path (Join-Path $StageRoot '*') -DestinationPath $ZipPath -CompressionLevel Optimal -Force

foreach ($File in @('UniExtract.exe', 'UniExtractUpdater.exe', 'UniExtractUpdater_NoAdmin.exe')) {
    Copy-Item -LiteralPath (Join-Path $RepoRoot $File) -Destination (Join-Path $Dist $File) -Force
}

$HashFiles = @(
    $ZipPath,
    (Join-Path $Dist 'UniExtract.exe'),
    (Join-Path $Dist 'UniExtractUpdater.exe'),
    (Join-Path $Dist 'UniExtractUpdater_NoAdmin.exe')
)

$HashLines = foreach ($File in $HashFiles) {
    $Hash = Get-FileHash -LiteralPath $File -Algorithm SHA256
    "{0}  {1}" -f $Hash.Hash.ToLowerInvariant(), (Split-Path -Leaf $File)
}
$HashLines | Set-Content -LiteralPath (Join-Path $Dist 'SHA256SUMS.txt') -Encoding ASCII

Write-Host 'Release package contents:'
Get-ChildItem -LiteralPath $StageRoot | Sort-Object Name | ForEach-Object { Write-Host " - $($_.Name)" }
Write-Host ''
Write-Host 'Release assets:'
Get-ChildItem -LiteralPath $Dist | Sort-Object Name | ForEach-Object {
    Write-Host (" - {0} ({1:N0} bytes)" -f $_.Name, $_.Length)
}
