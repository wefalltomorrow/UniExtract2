[CmdletBinding()]
param([string]$AutoItExe)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Repo = Split-Path -Parent $PSScriptRoot
$Source = Get-Content -LiteralPath (Join-Path $Repo 'UniExtract.au3') -Raw
$Functions = foreach ($Name in @('_UnixFileToolCommand', '_UnixFileType', 'FileScan_UnixFile')) {
    $Match = [regex]::Match($Source, '(?ms)^Func ' + $Name + '\([^\r\n]*\)\r?\n.*?^EndFunc')
    if (-not $Match.Success) { throw "Missing production function: $Name" }
    $Match.Value
}
$AutoItExe = @($AutoItExe, 'C:\Program Files (x86)\AutoIt3\AutoIt3.exe', (Join-Path $env:ProgramFiles 'AutoIt3\AutoIt3.exe')) |
    Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $AutoItExe) { throw 'AutoIt3 interpreter missing.' }
$Root = Join-Path $Repo '.build\libmagic-fallback'
New-Item -ItemType Directory -Path $Root -Force | Out-Null
$Harness = @'
Global $iOsArch = 64, $archdir = @ScriptDir & "\x64\", $filetool = "legacy"
Global $file = "C:\space path\" & ChrW(0x5165) & ChrW(0x529b) & ".bin", $filedir = "C:\space path"
Global $extract = False, $appendext = False, $g_bStrictPipeline = False, $g_sStoredUnixType = ""
Global $calls = 0, $candidate = "", $legacy = "", $result = "", $status = "", $launchError = False
DirCreate($archdir & "libmagic548")
FileWrite($archdir & "libmagic548\file.exe", "fixture")
FileWrite($archdir & "libmagic548\magic.mgc", "fixture")

Check("filename-prefixed unknown", $file & ": data" & @CRLF, $file & ": Zip archive data" & @CRLF, "Zip archive data", 2)
Check("bare unknown", "data", "ASCII text", "ASCII text", 2)
Check("empty result", "", "ASCII text", "ASCII text", 2)
Check("both unknown", $file & ": data", $file & ": data", "", 2)
Check("candidate recognition", $file & ": PNG image data" & @CRLF, "unused", "PNG image data", 1)
Check("missing database", "file.exe: could not find any valid magic files!", "ASCII text", "ASCII text", 2)
Check("unreadable input", $file & ": cannot open (No such file or directory)", "data", "", 2)
$launchError = True
Check("launch failure", -1, "ASCII text", "ASCII text", 2)
$launchError = False
$iOsArch = 32
Check("x86 uses legacy", "unused", "ASCII text", "ASCII text", 1)
$iOsArch = 64
FileDelete($archdir & "libmagic548\magic.mgc")
Check("missing candidate uses legacy", "unused", "ASCII text", "ASCII text", 1)
ConsoleWrite("LIBMAGIC-FALLBACK-TESTS-PASSED" & @CRLF)
Exit 0

Func Check($label, $first, $second, $expected, $expectedCalls)
    $calls = 0
    $candidate = $first
    $legacy = $second
    $result = ""
    $status = ""
    FileScan_UnixFile()
    If $calls <> $expectedCalls Or $result <> $expected Or ($expected = "" And $status <> "UNKNOWN") Then
        ConsoleWrite("FAIL: " & $label & "; calls=" & $calls & "; result=" & $result & "; status=" & $status & @CRLF)
        Exit 1
    EndIf
    ConsoleWrite("PASS: " & $label & @CRLF)
EndFunc
Func FetchStdout($command, $directory, $show)
    $calls += 1
    If StringLeft($command, 6) = "legacy" Then Return $legacy
    If $launchError Then Return SetError(1, 0, -1)
    Return $candidate
EndFunc
Func Quote($value, $double = False)
    Return '"' & $value & '"'
EndFunc
Func t($key, $value)
    Return $value
EndFunc
Func Cout($value)
EndFunc
Func _CreateTrayMessageBox($value)
EndFunc
Func _DeleteTrayMessageBox()
EndFunc
Func _FiletypeAdd($tool, $value)
    $result = $value
EndFunc
Func _PipelineStep($kind, $tool, $state, $details)
    $status = $state
EndFunc
Func _PipelineCompactDetails($value)
    Return $value
EndFunc
Func filecompare($value)
EndFunc
'@
$Script = Join-Path $Root 'fallback.au3'
[IO.File]::WriteAllText($Script, $Harness + [Environment]::NewLine + ($Functions -join [Environment]::NewLine), (New-Object Text.UTF8Encoding($true)))
$Stdout = Join-Path $Root 'stdout.txt'
$Stderr = Join-Path $Root 'stderr.txt'
$Process = Start-Process -FilePath $AutoItExe -ArgumentList ('"' + $Script + '"') -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $Stdout -RedirectStandardError $Stderr
$Output = Get-Content -LiteralPath $Stdout -Raw
Write-Host $Output
if (Test-Path -LiteralPath $Stderr) { Get-Content -LiteralPath $Stderr | ForEach-Object { Write-Host $_ } }
if ($Process.ExitCode -ne 0 -or $Output -notmatch 'LIBMAGIC-FALLBACK-TESTS-PASSED') { throw 'Libmagic fallback regression failed.' }
