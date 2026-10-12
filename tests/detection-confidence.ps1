[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Repo = Split-Path -Parent $PSScriptRoot
$Source = Get-Content -LiteralPath (Join-Path $Repo 'UniExtract.au3') -Raw

$StartMatch = [regex]::Match($Source, '(?ms)^Func StartExtraction\(\)\r?\n.*?^EndFunc')
if (-not $StartMatch.Success) { throw 'StartExtraction function missing.' }
$Start = $StartMatch.Value
$ExtensionIndex = $Start.IndexOf("CheckExt()")
$NativeIndex = $Start.IndexOf('If check7z(0, False, True, True)')
$GameIndex = $Start.IndexOf("CheckIso()")
if ($ExtensionIndex -lt 0 -or $NativeIndex -le $ExtensionIndex -or $GameIndex -le $NativeIndex) {
    throw 'Speculative ISO/game probes must not precede native extraction and generic 7-Zip.'
}
if (-not $Start.Contains('If $g_sVerifiedFileSignature = "freearc" Then') -or
    -not $Start.Contains('If _IsVerified7ZipFormat($g_sVerifiedFileSignature) Then') -or
    -not $Start.Contains('If Not $bSkipGameProbes Then')) {
    throw 'Main detection pipeline does not use verified-header confidence gates.'
}
$Initial = [regex]::Match($Source, '(?ms)^Func InitialCheckExt\(\)\r?\n.*?^EndFunc').Value
if (-not $Initial.Contains('If $g_sVerifiedFileSignature <> ""')) {
    throw 'Extension-first probes must defer to independently verified headers.'
}
foreach ($Name in @('CheckIso', 'CheckGame', 'CheckTotalObserver')) {
    $Body = [regex]::Match($Source, '(?ms)^Func ' + $Name + '\([^\r\n]*\)\r?\n.*?^EndFunc').Value
    if (-not $Body.Contains('_IsPositiveQuickBmsListing($return)')) {
        throw "$Name must require positive QuickBMS file-list evidence."
    }
}

$AutoItExe = @(
    'C:\Program Files (x86)\AutoIt3\AutoIt3.exe',
    (Join-Path $env:ProgramFiles 'AutoIt3\AutoIt3.exe')
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $AutoItExe) { throw 'AutoIt3 interpreter missing from Windows runner.' }

$TestRoot = Join-Path $Repo '.build\detection-confidence-test'
New-Item -ItemType Directory -Force -Path $TestRoot | Out-Null
$Fixtures = @{
    'freearc.bin' = @(0x41,0x72,0x43,0x01)
    'wrong-freearc.bin' = @(0x41,0x72,0x43,0x02)
    'zip.dat' = @(0x50,0x4b,0x03,0x04)
    'empty-zip.dat' = @(0x50,0x4b,0x05,0x06)
    'sevenzip.png' = @(0x37,0x7a,0xbc,0xaf,0x27,0x1c)
    'rar4.bin' = @(0x52,0x61,0x72,0x21,0x1a,0x07,0x00)
    'rar5.bin' = @(0x52,0x61,0x72,0x21,0x1a,0x07,0x01,0x00)
    'gzip.bin' = @(0x1f,0x8b,0x08)
    'bzip2.bin' = @(0x42,0x5a,0x68)
    'xz.bin' = @(0xfd,0x37,0x7a,0x58,0x5a,0x00)
    'png.zip' = @(0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a)
    'jpeg.7z' = @(0xff,0xd8,0xff,0x00)
    'gif.bin' = @(0x47,0x49,0x46,0x38,0x39,0x61)
    'pdf.bin' = @(0x25,0x50,0x44,0x46,0x2d)
    'ogg.bin' = @(0x4f,0x67,0x67,0x53)
    'flac.bin' = @(0x66,0x4c,0x61,0x43)
    'ebml.bin' = @(0x1a,0x45,0xdf,0xa3)
    'mp4.bin' = @(0,0,0,16,0x66,0x74,0x79,0x70,0x69,0x73,0x6f,0x6d)
    'wav.bin' = @(0x52,0x49,0x46,0x46,0,0,0,0,0x57,0x41,0x56,0x45)
    'avi.bin' = @(0x52,0x49,0x46,0x46,0,0,0,0,0x41,0x56,0x49,0x20)
    'webp.bin' = @(0x52,0x49,0x46,0x46,0,0,0,0,0x57,0x45,0x42,0x50)
    'unknown.bin' = @(0,1,2,3,4,5,6,7)
    'short.bin' = @(0x50,0x4b,0x03)
}
foreach ($Case in $Fixtures.GetEnumerator()) {
    [IO.File]::WriteAllBytes((Join-Path $TestRoot $Case.Key), [byte[]]$Case.Value)
}

$ExtractedFunctions = @()
foreach ($Name in @('_GetVerifiedFileSignature', '_IsVerified7ZipFormat', '_IsVerifiedNonArchiveFormat', '_IsPositiveQuickBmsListing')) {
    $Match = [regex]::Match($Source, '(?ms)^Func ' + [regex]::Escape($Name) + '\([^\r\n]*\)\r?\n.*?^EndFunc')
    if (-not $Match.Success) { throw "Missing AutoIt confidence helper: $Name" }
    $ExtractedFunctions += $Match.Value
}

$Harness = @'
#include <FileConstants.au3>

Func TestSignature($sFilename, $sExpected)
    Local $sActual = _GetVerifiedFileSignature(@ScriptDir & "\" & $sFilename)
    If $sActual <> $sExpected Then
        ConsoleWrite("FAIL: " & $sFilename & " expected " & $sExpected & ", got " & $sActual & @CRLF)
        Exit 1
    EndIf
    ConsoleWrite("PASS: " & $sFilename & " = " & $sActual & @CRLF)
EndFunc

TestSignature("freearc.bin", "freearc")
TestSignature("wrong-freearc.bin", "")
TestSignature("zip.dat", "zip")
TestSignature("empty-zip.dat", "zip")
TestSignature("sevenzip.png", "7z")
TestSignature("rar4.bin", "rar")
TestSignature("rar5.bin", "rar")
TestSignature("gzip.bin", "gzip")
TestSignature("bzip2.bin", "bzip2")
TestSignature("xz.bin", "xz")
TestSignature("png.zip", "png")
TestSignature("jpeg.7z", "jpeg")
TestSignature("gif.bin", "gif")
TestSignature("pdf.bin", "pdf")
TestSignature("ogg.bin", "ogg")
TestSignature("flac.bin", "flac")
TestSignature("ebml.bin", "ebml")
TestSignature("mp4.bin", "mp4")
TestSignature("wav.bin", "wav")
TestSignature("avi.bin", "avi")
TestSignature("webp.bin", "webp")
TestSignature("unknown.bin", "")
TestSignature("short.bin", "")
TestSignature("missing.bin", "")

If Not _IsVerified7ZipFormat("zip") Or Not _IsVerified7ZipFormat("rar") Or _IsVerified7ZipFormat("png") Then Exit 1
If Not _IsVerifiedNonArchiveFormat("png") Or _IsVerifiedNonArchiveFormat("zip") Then Exit 1
If Not _IsPositiveQuickBmsListing("- 2 files found in 0 seconds") Then Exit 1
If Not _IsPositiveQuickBmsListing("1 file found") Then Exit 1
If _IsPositiveQuickBmsListing("0 files found") Then Exit 1
If _IsPositiveQuickBmsListing("Target directory: C:\temp" & @LF & "4 files found") Then Exit 1
If _IsPositiveQuickBmsListing("ERROR: unsupported format; 10 files found") Then Exit 1
If _IsPositiveQuickBmsListing("exception occurred; 3 files found") Then Exit 1
If _IsPositiveQuickBmsListing("") Then Exit 1
If _IsPositiveQuickBmsListing("3 names extracted, no file-count") Then Exit 1
ConsoleWrite("PASS: credible QuickBMS list evidence distinguishes errors and empty results" & @CRLF)
ConsoleWrite("Detection-confidence unit tests passed." & @CRLF)
Exit 0

'@
$Script = Join-Path $TestRoot 'confidence-test.au3'
[IO.File]::WriteAllText($Script, $Harness + ($ExtractedFunctions -join [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
$Stdout = Join-Path $TestRoot 'stdout.txt'
$Stderr = Join-Path $TestRoot 'stderr.txt'
$Process = Start-Process -FilePath $AutoItExe -ArgumentList ('"' + $Script + '"') -Wait -PassThru -RedirectStandardOutput $Stdout -RedirectStandardError $Stderr
if (Test-Path -LiteralPath $Stdout) { Get-Content -LiteralPath $Stdout | ForEach-Object { Write-Host $_ } }
if (Test-Path -LiteralPath $Stderr) { Get-Content -LiteralPath $Stderr | ForEach-Object { Write-Host $_ } }
if ($Process.ExitCode -ne 0) { throw "Detection-confidence AutoIt tests failed: exit code $($Process.ExitCode)" }
Write-Host 'Verified-header and QuickBMS heuristics regression suite passed.'
