[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Find-FirstExistingPath {
    param([string[]]$Candidates)

    foreach ($Candidate in $Candidates) {
        if ($Candidate -and (Test-Path -LiteralPath $Candidate)) {
            return (Resolve-Path -LiteralPath $Candidate).Path
        }
    }

    return $null
}

$AutoItDir = Find-FirstExistingPath @(
    "${env:ProgramFiles(x86)}\AutoIt3",
    "${env:ProgramFiles}\AutoIt3"
)

if (-not $AutoItDir) {
    throw 'AutoIt was not found. Install AutoIt 3.3.18.0 before building.'
}

$Wrapper = Find-FirstExistingPath @(
    (Join-Path $AutoItDir 'SciTE\AutoIt3Wrapper\AutoIt3Wrapper.exe'),
    (Join-Path $AutoItDir 'SciTE\AutoIt3Wrapper\AutoIt3Wrapper.au3'),
    "${env:ProgramFiles(x86)}\AutoIt3\SciTE\AutoIt3Wrapper\AutoIt3Wrapper.exe",
    "${env:ProgramFiles(x86)}\AutoIt3\SciTE\AutoIt3Wrapper\AutoIt3Wrapper.au3",
    "${env:ProgramFiles}\AutoIt3\SciTE\AutoIt3Wrapper\AutoIt3Wrapper.exe",
    "${env:ProgramFiles}\AutoIt3\SciTE\AutoIt3Wrapper\AutoIt3Wrapper.au3"
)

if (-not $Wrapper) {
    $SearchRoots = @(
        "${env:ProgramFiles(x86)}",
        "${env:ProgramFiles}",
        'C:\ProgramData\chocolatey',
        $env:LOCALAPPDATA
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    foreach ($Root in $SearchRoots) {
        foreach ($Name in @('AutoIt3Wrapper.exe', 'AutoIt3Wrapper.au3')) {
            $Match = Get-ChildItem -LiteralPath $Root -Filter $Name -File -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($Match) {
                $Wrapper = $Match.FullName
                break
            }
        }
        if ($Wrapper) { break }
    }
}

if (-not $Wrapper) {
    throw 'AutoIt3Wrapper was not found. Install SciTE4AutoIt3 before building.'
}

$AutoItExe = Join-Path $AutoItDir 'AutoIt3.exe'
if (-not (Test-Path -LiteralPath $AutoItExe)) {
    throw "AutoIt3.exe was not found at $AutoItExe."
}

Write-Host "AutoIt: $AutoItDir"
Write-Host "Wrapper: $Wrapper"

$Targets = @(
    @{ Source = 'UniExtract.au3'; Output = 'UniExtract.exe' },
    @{ Source = 'UniExtractUpdater.au3'; Output = 'UniExtractUpdater_NoAdmin.exe' },
    @{ Source = 'UniExtractUpdater_Elevated.au3'; Output = 'UniExtractUpdater.exe' }
)

foreach ($Target in $Targets) {
    $SourcePath = Join-Path $RepoRoot $Target.Source
    $OutputPath = Join-Path $RepoRoot $Target.Output

    Remove-Item -LiteralPath $OutputPath -Force -ErrorAction SilentlyContinue

    Write-Host "Building $($Target.Source)..."

    $WrapperArgs = '/prod /in "' + $SourcePath + '" /autoit3dir "' + $AutoItDir + '" /NoStatus'
    if ([IO.Path]::GetExtension($Wrapper) -ieq '.au3') {
        $Process = Start-Process -FilePath $AutoItExe -ArgumentList ('"' + $Wrapper + '" ' + $WrapperArgs) -Wait -PassThru -NoNewWindow
    } else {
        $Process = Start-Process -FilePath $Wrapper -ArgumentList $WrapperArgs -Wait -PassThru -NoNewWindow
    }

    if ($Process.ExitCode -ne 0) {
        throw "AutoIt3Wrapper failed for $($Target.Source) with exit code $($Process.ExitCode)."
    }

    if (-not (Test-Path -LiteralPath $OutputPath)) {
        throw "Expected output was not created: $OutputPath"
    }

    $Info = Get-Item -LiteralPath $OutputPath
    $VersionInfo = $Info.VersionInfo
    Write-Host ("Built {0} ({1:N0} bytes, FileVersion {2})" -f $Target.Output, $Info.Length, $VersionInfo.FileVersion)
}

$ExpectedVersion = ((Get-Content -LiteralPath (Join-Path $RepoRoot 'VERSION') -Raw).Trim() + '.0')
$MainVersion = (Get-Item -LiteralPath (Join-Path $RepoRoot 'UniExtract.exe')).VersionInfo.FileVersion

if ($MainVersion -and $MainVersion -ne $ExpectedVersion) {
    throw "UniExtract.exe reports FileVersion '$MainVersion'; expected '$ExpectedVersion'."
}

Write-Host 'Build completed successfully.'
