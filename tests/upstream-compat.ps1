[CmdletBinding()]
param([string]$AutoItExe, [string]$StageRoot)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Repo = Split-Path -Parent $PSScriptRoot
if (-not $StageRoot) { $StageRoot = Join-Path $Repo '.build\release' }
$AutoItExe = @($AutoItExe, 'C:\Program Files (x86)\AutoIt3\AutoIt3.exe', (Join-Path $env:ProgramFiles 'AutoIt3\AutoIt3.exe')) |
    Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $AutoItExe) { throw 'AutoIt interpreter required.' }
$Seven = Join-Path $StageRoot 'bin\x64\7z.exe'
if (-not (Test-Path -LiteralPath $Seven)) { throw 'Packaged 7-Zip required.' }
$Source = Get-Content -LiteralPath (Join-Path $Repo 'UniExtract.au3') -Raw
$Fns = foreach ($Name in @('_ResetExtractionProbeState', '_HasInstallShieldCabMagic', '_IsInstallShieldCabCandidate', '_ResolveLegacyNonExeMatchesEarly', '_CheckBioruebeInnoThenIEFallback', 'GUI_Plugins_InstallCreateInstall', '_CopyCreateInstallPluginFiles', '_CreateInstallPluginComplete', '_CreateInstallPluginMissingMessage')) {
    $Match = [regex]::Match($Source, '(?ms)^Func ' + $Name + '\([^\r\n]*\)\r?\n.*?^EndFunc')
    if (-not $Match.Success) { throw "Production function missing: $Name" }
    $Match.Value
}
if ($Source.Contains('($Timeout * 1000)')) { throw 'Millisecond timeout was multiplied again.' }
$Start = [regex]::Match($Source, '(?ms)^Func StartExtraction\(\).*?^EndFunc').Value
if (-not $Start.Contains('_ResetExtractionProbeState()')) { throw 'Per-file reset not wired.' }
if ($Start.IndexOf('_ResolveLegacyNonExeMatchesEarly()') -lt $Start.IndexOf('If _IsVerified7ZipFormat')) { throw 'Legacy route bypasses header guards.' }
$Root = Join-Path $Repo ('.build\upstream-compat-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Root -Force | Out-Null
foreach ($Name in @('runtime', 'incomplete', 'duplicate\a', 'duplicate\b', 'destination', 'nested')) {
    New-Item -ItemType Directory -Path (Join-Path $Root $Name) -Force | Out-Null
}
foreach ($Name in @('ci-extractor.exe', 'gea.dll', 'gentee.dll')) {
    [IO.File]::WriteAllText((Join-Path $Root "runtime\$Name"), "fixture-$Name")
    [IO.File]::WriteAllText((Join-Path $Root "destination\$Name"), 'existing')
    [IO.File]::WriteAllText((Join-Path $Root "duplicate\a\$Name"), 'duplicate-a')
    [IO.File]::WriteAllText((Join-Path $Root "duplicate\b\$Name"), 'duplicate-b')
}
[IO.File]::WriteAllText((Join-Path $Root 'incomplete\ci-extractor.exe'), 'incomplete')
[IO.File]::WriteAllBytes((Join-Path $Root 'ordinary.cab'), [byte[]](73,83,99,40,0))
[IO.File]::WriteAllBytes((Join-Path $Root 'microsoft.cab'), [byte[]](77,83,67,70,0))
[IO.File]::WriteAllBytes((Join-Path $Root 'short.cab'), [byte[]](73,83,99))
Compress-Archive -Path (Join-Path $Root 'runtime\*') -DestinationPath (Join-Path $Root 'complete.zip')
Compress-Archive -Path (Join-Path $Root 'incomplete\*') -DestinationPath (Join-Path $Root 'incomplete.zip')
# An inert ZIP named .exe exercises nested probing without executing an installer.
Copy-Item -LiteralPath (Join-Path $Root 'complete.zip') -Destination (Join-Path $Root 'nested\cif-setup.exe')
Compress-Archive -Path (Join-Path $Root 'nested\*') -DestinationPath (Join-Path $Root 'nested.zip')
$Harness = @'
#include <File.au3>
#include <Array.au3>
#include <MsgBoxConstants.au3>
Global $isofailed = True, $observerfailed = True, $g_bArchiveIntegrityError = True
Global $g_bPasswordFailureAbort = True, $g_bInnoExtractUsable = True, $g_bSymlinkOnlyWarning = True
Global $fileext = "cab", $file = @ScriptDir & "\ordinary.cab", $filedir = @ScriptDir, $filenamefull = "data2.cab", $filename = "data2"
Global $extract = True, $g_bStrictPipeline = True, $g_sStoredTridType = "first" & @LF & "second", $g_sStoredUnixType = "stale"
Global $calls = "", $innofailed = False, $innoextract = "unused", $probe = "Inno Setup", $nonfatal = False, $ieCalls = 0, $terminated = False
Global Const $TYPE_INNO = "inno", $STATUS_SUCCESS = 0
Global $silentmode = True, $iTopmost = 0, $title = "Test", $7z = '"' & $CmdLine[1] & '"'
Global $dest = @ScriptDir & "\destination\", $required[3] = ["ci-extractor.exe", "gea.dll", "gentee.dll"]
Func Assert($ok, $label)
    If Not $ok Then
        ConsoleWrite("FAIL: " & $label & @CRLF)
        Exit 1
    EndIf
    ConsoleWrite("PASS: " & $label & @CRLF)
EndFunc
_ResetExtractionProbeState()
Assert(Not ($isofailed Or $observerfailed Or $g_bArchiveIntegrityError Or $g_bPasswordFailureAbort Or $g_bInnoExtractUsable Or $g_bSymlinkOnlyWarning), "retry clears previous failure state")
Assert(_HasInstallShieldCabMagic(), "ordinary cabinet name recognized by magic")
$file = @ScriptDir & "\microsoft.cab"
Assert(Not _HasInstallShieldCabMagic(), "Microsoft CAB is not InstallShield")
$file = @ScriptDir & "\short.cab"
Assert(Not _HasInstallShieldCabMagic(), "truncated CAB rejected")
$file = @ScriptDir & "\missing.cab"
Assert(Not _HasInstallShieldCabMagic(), "missing CAB rejected")
$file = @ScriptDir & "\ordinary.cab"
$fileext = "zip"
Assert(Not _HasInstallShieldCabMagic(), "other extensions are not redirected")
$fileext = "cab"
FileWrite(@ScriptDir & "\data1.hdr", "fixture")
Assert(_IsInstallShieldCabCandidate(), "later data volume preserves legacy set route")
_ResolveLegacyNonExeMatchesEarly()
Assert($calls = "first;second;unix;" And $g_bStrictPipeline And $g_sStoredTridType = "" And $g_sStoredUnixType = "", "legacy routes run in order and restore strict state")
$extract = False
$calls = ""
$g_sStoredTridType = "keep"
_ResolveLegacyNonExeMatchesEarly()
Assert($calls = "" And $g_sStoredTridType = "keep", "scan-only does not extract")
$extract = True
$g_sStoredTridType = "corrupt" & @LF & "must-not-run"
_ResolveLegacyNonExeMatchesEarly()
Assert($calls = "corrupt;" And $g_bStrictPipeline, "corruption stops remaining hints and Unix fallback")
_ResetExtractionProbeState()
$calls = ""
$g_sStoredTridType = "password" & @LF & "must-not-run"
_ResolveLegacyNonExeMatchesEarly()
Assert($calls = "password;" And $g_bStrictPipeline, "password failure stops remaining hints and Unix fallback")
_ResetExtractionProbeState()
_CheckBioruebeInnoThenIEFallback()
Assert($nonfatal And $innofailed And Not $terminated, "failed Inno extraction preserves fallbacks")
$innofailed = False
$probe = "Not a supported Inno Setup installer!"
_CheckBioruebeInnoThenIEFallback()
Assert($ieCalls = 1, "non-Inno executable reaches InstallExplorer")
Assert(Not _CopyCreateInstallPluginFiles(@ScriptDir & "\incomplete", $dest, $required), "incomplete plugin rejected")
Assert(FileRead($dest & "ci-extractor.exe") = "existing", "incomplete package preserves installed files")
Assert(Not _CopyCreateInstallPluginFiles(@ScriptDir & "\duplicate", $dest, $required), "ambiguous plugin runtimes rejected")
Assert(FileRead($dest & "ci-extractor.exe") = "existing", "ambiguous package preserves installed files")
Assert(Not GUI_Plugins_InstallCreateInstall(@ScriptDir & "\runtime|ci-extractor.exe|gea.dll", $dest), "incomplete multiselect rejected")
Assert(FileRead($dest & "ci-extractor.exe") = "existing", "incomplete multiselect preserves installed files")
Assert(GUI_Plugins_InstallCreateInstall(@ScriptDir & "\runtime|ci-extractor.exe|gea.dll|gentee.dll", $dest), "complete multiselect installed")
Assert(Not GUI_Plugins_InstallCreateInstall(@ScriptDir & "\missing\gea.dll", $dest), "failed single-file copy is not reported as success")
Assert(Not GUI_Plugins_InstallCreateInstall(@ScriptDir & "\unrelated.exe", $dest), "unrelated single file is rejected with existing runtime")
Assert(GUI_Plugins_InstallCreateInstall(@ScriptDir & "\runtime\gea.dll", $dest), "single runtime file can be updated")
FileDelete($dest & "*")
Assert(GUI_Plugins_InstallCreateInstall(@ScriptDir & "\complete.zip", $dest), "flat ZIP imported")
FileDelete($dest & "*")
Assert(GUI_Plugins_InstallCreateInstall(@ScriptDir & "\nested.zip", $dest), "nested inert setup imported with 7-Zip")
Assert(FileRead($dest & "gea.dll") = "fixture-gea.dll", "nested runtime bytes preserved")
Exit 0
Func Cout($text)
    ConsoleWrite($text & @CRLF)
EndFunc
Func tridcompare($text)
    Assert(Not $g_bStrictPipeline, "legacy TrID routing enabled")
    $calls &= $text & ";"
    If $text = "corrupt" Then $g_bArchiveIntegrityError = True
    If $text = "password" Then $g_bPasswordFailureAbort = True
EndFunc
Func FileScan_UnixFile()
    $calls &= "unix;"
EndFunc
Func FetchStdout($command, $dir, $show)
    Return $probe
EndFunc
Func _CreateTrayMessageBox($message)
EndFunc
Func _DeleteTrayMessageBox()
EndFunc
Func t($key)
    Return $key
EndFunc
Func extract($type, $display, $extra = "", $returnSuccess = False, $returnFail = False)
    $nonfatal = $returnSuccess And $returnFail
    Return False
EndFunc
Func terminate($status, $name, $type, $display)
    $terminated = True
EndFunc
Func checkIE()
    $ieCalls += 1
EndFunc
Func _Run($command, $dir, $show, $useCmd, $log, $initial)
    Local $result = RunWait($command, $dir, @SW_HIDE)
    Return $result
EndFunc
'@
$Path = Join-Path $Root 'test.au3'
[IO.File]::WriteAllText($Path, $Harness + [Environment]::NewLine + ($Fns -join [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
$Stdout = Join-Path $Root 'stdout.txt'
$Stderr = Join-Path $Root 'stderr.txt'
$Process = Start-Process -FilePath $AutoItExe -ArgumentList ('/ErrorStdOut "' + $Path + '" "' + $Seven + '"') -WindowStyle Hidden -PassThru -RedirectStandardOutput $Stdout -RedirectStandardError $Stderr
$null = $Process.Handle
if (-not $Process.WaitForExit(60000)) { Stop-Process -Id $Process.Id -Force; throw 'Upstream compatibility test timed out.' }
$Process.WaitForExit()
Get-Content $Stdout, $Stderr | Write-Host
if ($Process.ExitCode -ne 0) { throw "Upstream compatibility tests failed: $($Process.ExitCode)" }
Write-Host 'Upstream compatibility regression tests passed.'
