[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Repo = Split-Path -Parent $PSScriptRoot
$Source = Get-Content -LiteralPath (Join-Path $Repo 'UniExtract.au3') -Raw
$Match = [regex]::Match($Source, '(?ms)^Func _ShouldAvoidBroadGameProbeForBin\(\)\r?\n.*?^EndFunc')
if (-not $Match.Success) { throw 'Installer sidecar detector missing from UniExtract.au3' }
if (-not $Source.Contains('If _ShouldAvoidBroadGameProbeForBin() Then') -or
    -not $Source.Contains('If Not _ShouldAvoidBroadGameProbeForBin() Then')) {
    throw 'Both main and Game Extractor fallback must respect the BIN guard.'
}
if (-not $Source.Contains('LogExtractorWinner("GARbro")') -or
    -not $Source.Contains('LogExtractorWinner("unarc")')) {
    throw 'Summary must capture GARbro and unarc extractor results.'
}
$AutoItExe = @(
    'C:\Program Files (x86)\AutoIt3\AutoIt3.exe',
    (Join-Path $env:ProgramFiles 'AutoIt3\AutoIt3.exe')
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $AutoItExe) { throw 'AutoIt3 interpreter not installed.' }
$TestRoot = Join-Path $Repo '.build\installer-bin-guard-test'
New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null
New-Item -Path (Join-Path $TestRoot 'setup.exe') -ItemType File -Force | Out-Null
$Harness = @'
Global $fileext = "bin"
Global $filename = "setup-1"
Global $filedir = @ScriptDir
Global $g_sDieDetectionHint = ""
Global $g_sStoredTridType = ""

Func TestGuard($sCase, $bExpected)
    Local $bObserved = _ShouldAvoidBroadGameProbeForBin()
    If $bObserved <> $bExpected Then
        ConsoleWrite("FAIL: " & $sCase & " observed " & $bObserved & ", expected " & $bExpected & @CRLF)
        Exit 1
    EndIf
    ConsoleWrite("PASS: " & $sCase & @CRLF)
EndFunc

TestGuard("setup-1.bin with setup.exe", True)
$filename = "other-1"
TestGuard("unrelated numbered .bin, no matching .exe", False)
$filename = "payload"
$g_sDieDetectionHint = "Binary" & @LF & "Archive: FreeARC Archive (.ARC)"
$g_sStoredTridType = "FreeArc compressed archive"
TestGuard("independent FreeARC detector agreement", True)
$g_sDieDetectionHint = ""
TestGuard("only TrID identifies FreeARC", False)
$g_sDieDetectionHint = "Archive: FreeARC Archive"
$g_sStoredTridType = ""
TestGuard("only DiE identifies FreeARC", False)
$g_sStoredTridType = "FreeArc compressed archive"
$fileext = "arc"
TestGuard("other extension retains broad game probes", False)
ConsoleWrite("Installer BIN guard: all tests passed." & @CRLF)
Exit 0

'@
$Path = Join-Path $TestRoot 'guard-test.au3'
[IO.File]::WriteAllText($Path, $Harness + $Match.Value + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
& $AutoItExe $Path
if ($LASTEXITCODE -ne 0) { throw "Installer BIN guard failed: AutoIt exit code $LASTEXITCODE" }
Write-Host 'Installer-sidecar and independent-detector regression tests passed.'
