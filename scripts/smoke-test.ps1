[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
$StageRoot = Join-Path $RepoRoot '.build\release'
$Exe = Join-Path $StageRoot 'UniExtract.exe'

if (-not (Test-Path -LiteralPath $Exe)) {
    throw "Packaged UniExtract.exe not found at $Exe. Run scripts\package-release.ps1 first."
}

$SmokeRoot = Join-Path $RepoRoot '.build\smoke'
$Expected = 'Universal Extractor 2 smoke test'

Remove-Item -LiteralPath $SmokeRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $SmokeRoot -Force | Out-Null

function Invoke-SmokeExtraction {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$ArchiveName
    )

    $CaseRoot = Join-Path $SmokeRoot $Name
    $InputRoot = Join-Path $CaseRoot 'input'
    $OutRoot = Join-Path $CaseRoot 'output'
    $Archive = Join-Path $CaseRoot $ArchiveName
    $Payload = Join-Path $InputRoot 'hello.txt'

    New-Item -ItemType Directory -Path $InputRoot, $OutRoot -Force | Out-Null
    Set-Content -LiteralPath $Payload -Value $Expected -Encoding ASCII
    Compress-Archive -LiteralPath $Payload -DestinationPath $Archive -CompressionLevel Optimal -Force

    $Arguments = '"' + $Archive + '" "' + $OutRoot + '" /silent'
    Write-Host "Smoke testing [$Name]: $Exe $Arguments"

    $Process = Start-Process -FilePath $Exe -ArgumentList $Arguments -PassThru
    if (-not $Process.WaitForExit(60000)) {
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
        throw "UniExtract smoke test '$Name' timed out after 60 seconds."
    }

    $Extracted = Get-ChildItem -LiteralPath $OutRoot -Filter 'hello.txt' -File -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if (-not $Extracted) {
        throw "Smoke test '$Name' did not extract hello.txt. UniExtract exit code: $($Process.ExitCode)"
    }

    $Actual = (Get-Content -LiteralPath $Extracted.FullName -Raw).Trim()
    if ($Actual -ne $Expected) {
        throw "Smoke-test payload mismatch in '$Name'. Expected '$Expected', got '$Actual'."
    }

    Write-Host "Smoke test passed [$Name]: $($Extracted.FullName)"
    Write-Host "UniExtract exit code [$Name]: $($Process.ExitCode)"
}

Invoke-SmokeExtraction -Name 'basic' -ArchiveName 'smoke-test.zip'
Invoke-SmokeExtraction -Name 'unicode-filename' -ArchiveName 'smoke-ユニコード.zip'

Write-Host 'All packaged extraction smoke tests passed.'
