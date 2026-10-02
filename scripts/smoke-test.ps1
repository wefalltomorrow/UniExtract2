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
$InputRoot = Join-Path $SmokeRoot 'input'
$OutRoot = Join-Path $SmokeRoot 'output'
$Archive = Join-Path $SmokeRoot 'smoke-test.zip'
$Payload = Join-Path $InputRoot 'hello.txt'
$Expected = 'Universal Extractor 2 smoke test'

Remove-Item -LiteralPath $SmokeRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $InputRoot, $OutRoot -Force | Out-Null
Set-Content -LiteralPath $Payload -Value $Expected -Encoding ASCII
Compress-Archive -LiteralPath $Payload -DestinationPath $Archive -CompressionLevel Optimal -Force

$Arguments = '"' + $Archive + '" "' + $OutRoot + '" /silent'
Write-Host "Smoke testing: $Exe $Arguments"

$Process = Start-Process -FilePath $Exe -ArgumentList $Arguments -PassThru
if (-not $Process.WaitForExit(60000)) {
    Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
    throw 'UniExtract smoke test timed out after 60 seconds.'
}

$Extracted = Get-ChildItem -LiteralPath $OutRoot -Filter 'hello.txt' -File -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1

if (-not $Extracted) {
    throw "Smoke test did not extract hello.txt. UniExtract exit code: $($Process.ExitCode)"
}

$Actual = (Get-Content -LiteralPath $Extracted.FullName -Raw).Trim()
if ($Actual -ne $Expected) {
    throw "Smoke-test payload mismatch. Expected '$Expected', got '$Actual'."
}

Write-Host "Smoke test passed: $($Extracted.FullName)"
Write-Host "UniExtract exit code: $($Process.ExitCode)"
