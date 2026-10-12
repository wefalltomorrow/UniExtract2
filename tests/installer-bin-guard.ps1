[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Repo = Split-Path -Parent $PSScriptRoot
$Source = Get-Content -LiteralPath (Join-Path $Repo 'UniExtract.au3') -Raw
$Match = [regex]::Match($Source, '(?ms)^Func _ShouldAvoidBroadGameProbeForBin\(\)\r?\n.*?^EndFunc')
if (-not $Match.Success) { throw 'Installer sidecar detector missing from UniExtract.au3' }
$MagicMatch = [regex]::Match($Source, '(?ms)^Func _HasFreeArcMagic\(\$sPath\)\r?\n.*?^EndFunc')
if (-not $MagicMatch.Success) { throw 'FreeArc header check missing from UniExtract.au3.' }
if (-not $Source.Contains('If $g_sVerifiedFileSignature = "freearc" Then') -or
    -not $Source.Contains('If _HasFreeArcMagic($file) Then')) {
    throw 'Verified FreeArc magic must be prioritized both in the central pipeline and BIN extension guard.'
}
$InitialCheck = [regex]::Match($Source, '(?ms)^Func InitialCheckExt\(\)\r?\n.*?^EndFunc').Value
$BinCase = [regex]::Match($InitialCheck, '(?ms)^\s*Case "bin"\r?\n(.*?)(?=^\s*Case |^\s*EndSwitch)', 'Multiline').Value
if (-not $BinCase.Contains('If _HasFreeArcMagic($file) Then') -or
    $BinCase.IndexOf('If _HasFreeArcMagic($file) Then') -gt $BinCase.IndexOf('_TryExtCheck7z()')) {
    throw 'The .bin extension probe must defer to verified FreeArc magic before probing 7-Zip.'
}
$PdMatch = [regex]::Match($Source, '(?ms)^Func _ShouldRejectWeakGarbroClaim\(\$sClaim\)\r?\n.*?^EndFunc')
if (-not $PdMatch.Success) { throw 'Signatureless PD/KAAS recognition guard missing from source.' }
if (-not $Source.Contains('_ShouldAvoidBroadGameProbeForBin() Or _ShouldSkipNonFatalProbesForPrimaryMatch()') -or
    -not $Source.Contains('If Not $bSkipGameProbes Then') -or
    -not $Source.Contains('If _ShouldAvoidBroadGameProbeForBin() Then')) {
    throw 'Both speculative game probes and Game Extractor must respect the installer BIN guard.'
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
[IO.File]::WriteAllBytes((Join-Path $TestRoot 'free.arc'), [byte[]]@(0x41,0x72,0x43,0x01,0x00))
[IO.File]::WriteAllBytes((Join-Path $TestRoot 'not-arc.bin'), [byte[]]@(0x41,0x72,0x43,0x02,0x00))
[IO.File]::WriteAllBytes((Join-Path $TestRoot 'short.bin'), [byte[]]@(0x41,0x72,0x43))
$Harness = @'
#include <FileConstants.au3>
Global $file = @ScriptDir & "\not-arc.bin"
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
If Not _HasFreeArcMagic(@ScriptDir & "\free.arc") Then Exit 1
If _HasFreeArcMagic(@ScriptDir & "\not-arc.bin") Then Exit 1
If _HasFreeArcMagic(@ScriptDir & "\short.bin") Then Exit 1
If _HasFreeArcMagic(@ScriptDir & "\missing.bin") Then Exit 1
ConsoleWrite("PASS: FreeArc header matches exactly four magic bytes" & @CRLF)
$fileext = "bin"
$filename = "payload"
$g_sDieDetectionHint = ""
$g_sStoredTridType = ""
$file = @ScriptDir & "\free.arc"
TestGuard("magic bytes alone exclude broad game probes for BIN", True)
$file = @ScriptDir & "\not-arc.bin"
TestGuard("similar but incorrect magic is not considered FreeArc", False)
If Not _ShouldRejectWeakGarbroClaim("PD/KAAS") Then Exit 1
If _ShouldRejectWeakGarbroClaim("ZIP") Then Exit 1
$fileext = "dat"
If Not _ShouldRejectWeakGarbroClaim("PD/KAAS") Then Exit 1
$fileext = "zip"
If Not _ShouldRejectWeakGarbroClaim("PD/KAAS") Then Exit 1
$fileext = "pd"
If _ShouldRejectWeakGarbroClaim("PD/KAAS") Then Exit 1
ConsoleWrite("PASS: PD/KAAS BIN false positive rejected; other formats retained" & @CRLF)
ConsoleWrite("Installer BIN guard: all tests passed." & @CRLF)
Exit 0

'@
$Path = Join-Path $TestRoot 'guard-test.au3'
[IO.File]::WriteAllText($Path, $Harness + $MagicMatch.Value + [Environment]::NewLine + $Match.Value + [Environment]::NewLine + $PdMatch.Value + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
# AutoIt3.exe is a Windows GUI-subsystem process. PowerShell can omit
# LASTEXITCODE when invoking it with '&'; Start-Process reliably waits for it.
$StdOut = Join-Path $TestRoot 'stdout.txt'
$StdErr = Join-Path $TestRoot 'stderr.txt'
$Process = Start-Process -FilePath $AutoItExe -ArgumentList ('"' + $Path + '"') -Wait -PassThru -RedirectStandardOutput $StdOut -RedirectStandardError $StdErr
if (Test-Path -LiteralPath $StdOut) { Get-Content -LiteralPath $StdOut | ForEach-Object { Write-Host $_ } }
if (Test-Path -LiteralPath $StdErr) { Get-Content -LiteralPath $StdErr | ForEach-Object { Write-Host $_ } }
if ($Process.ExitCode -ne 0) { throw "Installer BIN guard failed: AutoIt exit code $($Process.ExitCode)" }
Write-Host 'Installer-sidecar and weak-PD regression tests passed.'
