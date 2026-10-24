[CmdletBinding()]
param([string]$AutoItExe)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Repo = Split-Path -Parent $PSScriptRoot
$AutoItExe = @($AutoItExe, 'C:\Program Files (x86)\AutoIt3\AutoIt3.exe', (Join-Path $env:ProgramFiles 'AutoIt3\AutoIt3.exe')) |
    Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $AutoItExe) { throw 'AutoIt3 interpreter not installed.' }
$Compiler = Join-Path (Split-Path $AutoItExe) 'Aut2Exe\Aut2exe.exe'
$Dir = Join-Path $Repo '.build\freearc-runtime'
New-Item -ItemType Directory -Path $Dir -Force | Out-Null
$Fixture = Join-Path $PSScriptRoot 'fixtures\external-freearc-wrapper.au3'
$Wrapper = Join-Path $Dir 'fixture.exe'
$Proc = Start-Process -FilePath $Compiler -ArgumentList ('/in "' + $Fixture + '" /out "' + $Wrapper + '" /console /x86') -PassThru
if (-not $Proc.WaitForExit(60000)) { Stop-Process -Id $Proc.Id -Force; throw 'Fixture compilation timed out.' }
if (-not (Test-Path -LiteralPath $Wrapper)) { throw 'Fixture compilation failed.' }
$Source = Get-Content -LiteralPath (Join-Path $Repo 'UniExtract.au3') -Raw
$Functions = foreach ($Name in @('_PrepareExternalFreeArcConfig', '_ExternalFreeArcFileCount', '_ExternalFreeArcDestinationEmpty', '_ExternalFreeArcCleanup', '_ExternalFreeArcRun', '_TryUserExternalFreeArc', '_KillProcessTree')) {
    $Match = [regex]::Match($Source, '(?ms)^Func ' + [regex]::Escape($Name) + '\([^\r\n]*\)\r?\n.*?^EndFunc')
    if (-not $Match.Success) { throw "Missing production function $Name" }
    $Match.Value
}
$Harness = @'
#include <File.au3>
#include <AutoItConstants.au3>
#include <StringConstants.au3>
Global $g_sExternalFreeArcStage = "", $g_iExternalFreeArcPid = 0, $g_hExternalFreeArcJob = 0, $run = 0
Global $prefs = @ScriptDir & "\preferences.ini", $g_sLastExtractorAttempt = "", $winner = "", $log = ""
Global $root = @ScriptDir & "\cases " & ChrW(0x65E5), $backend = $root & "\backend " & ChrW(0x672C)
Global $archive = $root & "\input " & ChrW(0x8A9E) & ".bin", $destination = $root & "\result"
Global $template = "InputFile=unused" & @CRLF & "OutputPath=unused" & @CRLF & "WorkPath=outside" & @CRLF & _
    "CfgFile=C:\outside.ini" & @CRLF & "Password=SYNTHETIC-Secret-Only" & @CRLF
Global $seenPid = 0, $mode = ""
Global $linkTarget = $root & "\link target"
Local $prefsHandle = FileOpen($prefs, 2 + 32)
FileWrite($prefsHandle, "[FreeArc]" & @CRLF)
FileClose($prefsHandle)
DirCreate($backend)
FileCopy(@ScriptDir & "\fixture.exe", $backend & "\unpack.exe", 1)
FileWrite($backend & "\unarc.dll", "synthetic placeholder, never loaded")
FileWrite($backend & "\arc.ini", "; fixture")
FileWrite($archive, Binary("0x41724301"))
IniWrite($prefs, "FreeArc", "ExternalUnpackerDir", $backend)
IniDelete($prefs, "FreeArc", "ExternalUnpackerEnabled")
Check("disabled by default", Not _TryUserExternalFreeArc($archive, $destination))
IniWrite($prefs, "FreeArc", "ExternalUnpackerEnabled", "1")
For $encoding In StringSplit("128,32,64", ",", 2)
    SetConfig("success", Number($encoding))
    Check("unicode/spaces success encoding " & $encoding, _TryUserExternalFreeArc($archive, $destination))
    Check("exact content", FileRead($destination & "\nested\payload.txt") == "fixture payload")
    Check("winner only after commit", $winner == "External FreeArc unpack.exe (user-supplied)")
    Check("source configuration unchanged", FileRead($backend & "\config.ini") == $template & "FixtureMode=success" & @CRLF & "FixtureDestination=" & $destination)
    CheckClean()
    DirRemove($destination, 1)
Next
SetConfig("child", 128)
DirCreate($destination)
Check("existing empty destination and child wrapper", _TryUserExternalFreeArc($archive, $destination))
Check("child stopped when wrapper exits", Not ProcessExists(Number(FileRead($destination & "\child-pid.txt"))))
CheckClean()
DirRemove($destination, 1)
DirCreate($linkTarget)
FileWrite($linkTarget & "\sentinel.txt", "keep")
SetConfig("reparse", 128)
Local $linkConfig = FileOpen($backend & "\config.ini", 1 + 128)
FileWrite($linkConfig, @CRLF & "FixtureLinkTarget=" & $linkTarget)
FileClose($linkConfig)
Check("reparse output rejected", Not _TryUserExternalFreeArc($archive, $destination))
Check("link target preserved", FileRead($linkTarget & "\sentinel.txt") == "keep")
CheckClean()
For $mode In StringSplit("empty,nonzero,timeout,cancel", ",", 2)
    SetConfig($mode, 128)
    IniWrite($prefs, "FreeArc", "ExternalUnpackerTimeoutSeconds", "1")
    $seenPid = 0
    AdlibRegister("Observe", 50)
    Check("reject " & $mode, Not _TryUserExternalFreeArc($archive, $destination))
    AdlibUnRegister("Observe")
    Check("no committed output " & $mode, Not FileExists($destination))
    Check("no winner " & $mode, $winner == "")
    If $mode = "timeout" Or $mode = "cancel" Then Check("process stopped " & $mode, $seenPid > 0 And Not ProcessExists($seenPid))
    CheckClean()
Next
SetConfig("success", 128)
DirCreate($destination)
FileWrite($destination & "\sentinel.txt", "keep")
Check("reject occupied destination", Not _TryUserExternalFreeArc($archive, $destination))
Check("preserve existing bytes", FileRead($destination & "\sentinel.txt") == "keep")
DirRemove($destination, 1)
SetConfig("race", 128)
Check("destination created during extraction", Not _TryUserExternalFreeArc($archive, $destination))
Check("preserve raced destination", FileRead($destination & "\sentinel.txt") == "keep")
CheckClean()
DirRemove($destination, 1)
For $bad In StringSplit("duplicate,section,missing", ",", 2)
    SetConfig("success", 128)
    Local $text = FileRead($backend & "\config.ini")
    Switch $bad
        Case "duplicate"
            $text &= @CRLF & "InputFile=another"
        Case "section"
            $text = "[settings]" & @CRLF & $text
        Case "missing"
            $text = StringReplace($text, "WorkPath=outside", "; missing")
    EndSwitch
    Local $h = FileOpen($backend & "\config.ini", 2 + 128)
    FileWrite($h, $text)
    FileClose($h)
    Check("reject config " & $bad, Not _TryUserExternalFreeArc($archive, $destination))
    CheckClean()
Next
Check("no credential in diagnostics", Not StringInStr($log, "SYNTHETIC-Secret-Only", 1))
DirRemove($root, 1)
FileDelete($prefs)
ConsoleWrite("External FreeArc runtime tests passed" & @CRLF)
Exit 0
Func Observe()
    If $g_iExternalFreeArcPid Then $seenPid = $g_iExternalFreeArcPid
    If $mode = "cancel" And $run Then _KillProcessTree($run)
    If $mode = "cancel" Then $run = 0
EndFunc
Func SetConfig($m, $enc)
    $winner = ""
    Local $h = FileOpen($backend & "\config.ini", 2 + $enc)
    FileWrite($h, $template & "FixtureMode=" & $m & @CRLF & "FixtureDestination=" & $destination)
    FileClose($h)
EndFunc
Func Check($name, $ok)
    If Not $ok Then
        ConsoleWrite("FAIL " & $name & @CRLF & $log)
        Exit 1
    EndIf
    ConsoleWrite("PASS " & $name & @CRLF)
EndFunc
Func CheckClean()
    Local $h = FileFindFirstFile($root & "\.UniExtract2-FreeArc-*")
    Check("stage cleaned", $h = -1 And $g_sExternalFreeArcStage == "")
    If $h <> -1 Then FileClose($h)
EndFunc
Func Cout($message)
    $log &= $message & @CRLF
EndFunc
Func _PipelineStep($a, $b, $c, $d)
    $log &= $a & $b & $c & $d & @CRLF
EndFunc
Func LogExtractorWinner($value)
    $winner = $value
EndFunc
'@
$Test = Join-Path $Dir 'runtime.au3'
[IO.File]::WriteAllText($Test, $Harness + [Environment]::NewLine + ($Functions -join [Environment]::NewLine), (New-Object Text.UTF8Encoding($true)))
$Stdout = Join-Path $Dir 'stdout.txt'
$Stderr = Join-Path $Dir 'stderr.txt'
$Proc = Start-Process -FilePath $AutoItExe -ArgumentList ('/ErrorStdOut "' + $Test + '"') -PassThru -RedirectStandardOutput $Stdout -RedirectStandardError $Stderr
if (-not $Proc.WaitForExit(60000)) {
    & taskkill.exe /PID $Proc.Id /T /F | Out-Null
    throw 'External FreeArc runtime test timed out.'
}
$OutputText = [IO.File]::ReadAllText($Stdout)
$ErrorText = [IO.File]::ReadAllText($Stderr)
Write-Host $OutputText
if ($ErrorText) { Write-Host $ErrorText }
if ($OutputText -notmatch 'External FreeArc runtime tests passed') { throw 'External FreeArc runtime test did not reach success marker.' }
if ($OutputText.Contains('SYNTHETIC-Secret-Only') -or $ErrorText.Contains('SYNTHETIC-Secret-Only')) { throw 'Wrapper credential reached test output.' }
if ($null -ne $Proc.ExitCode -and $Proc.ExitCode -ne 0) { throw 'External FreeArc runtime test failed.' }
