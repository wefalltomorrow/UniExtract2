[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Repo = Split-Path -Parent $PSScriptRoot
$Source = Get-Content -LiteralPath (Join-Path $Repo 'UniExtract.au3') -Raw

function Get-FunctionText([string]$Name) {
    $Pattern = '(?ms)^Func ' + [regex]::Escape($Name) + '\([^\r\n]*\)\r?\n.*?^EndFunc'
    $Match = [regex]::Match($Source, $Pattern)
    if (-not $Match.Success) { throw "Missing AutoIt function: $Name" }
    return $Match.Value
}
$Fns = @('_PrepareExternalFreeArcConfig','_PipelineFinalBadgeText','_PipelineFinalBadgeClass') |
    ForEach-Object { Get-FunctionText $_ }
foreach ($Expected in @(
    'ExternalUnpackerEnabled',
    'ExternalUnpackerDir',
    'If $success <> $RESULT_SUCCESS And _TryUserExternalFreeArc($file, $outdir)',
    'LogExtractorWinner("External FreeArc unpack.exe (user-supplied)")',
    'If $sExtractor = "" And $g_sLastExtractorAttempt <> ""',
    'ERROR: archive structure corrupted'
)) {
    if (-not $Source.Contains($Expected)) { throw "Missing FreeArc compatibility integration: $Expected" }
}

$AutoItExe = @(
    'C:\Program Files (x86)\AutoIt3\AutoIt3.exe',
    (Join-Path $env:ProgramFiles 'AutoIt3\AutoIt3.exe')
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $AutoItExe) { throw 'AutoIt3 interpreter not installed.' }

$Dir = Join-Path $Repo '.build\freearc-backend-regression'
New-Item -ItemType Directory -Path $Dir -Force | Out-Null
$Harness = @'
Global $g_iPipelineWarn = 0, $g_iPipelineFail = 0

Func Check($sName, $bResult)
    If Not $bResult Then
        ConsoleWrite("FAIL " & $sName & @CRLF)
        Exit 1
    EndIf
    ConsoleWrite("PASS " & $sName & @CRLF)
EndFunc

Local $sTemplate = "InputFile=.\setup-1.bin" & @CRLF & _
    "OutputPath=.\CODEX-DATA" & @CRLF & "Password=ABC" & @CRLF & _
    "CfgFile=.\arc.ini" & @CRLF & "WorkPath=.\temp"
Local $sCfg = _PrepareExternalFreeArcConfig($sTemplate, "D:\Some Folder\setup-1.bin", "D:\Extracted Game")
Check("input path", StringInStr($sCfg, "InputFile=D:\Some Folder\setup-1.bin", 1) > 0)
Check("destination path", StringInStr($sCfg, "OutputPath=D:\Extracted Game", 1) > 0)
Check("supplied password unchanged", StringInStr($sCfg, "Password=ABC", 1) > 0)
Check("extra fields unchanged", StringInStr($sCfg, "CfgFile=.\arc.ini", 1) > 0)
Check("isolated temporary work directory", StringInStr($sCfg, "WorkPath=.\temp", 1) > 0)
Check("no duplicate original input assignment", StringInStr($sCfg, "InputFile=.\setup-1.bin", 1) = 0)
Check("reject incomplete template", _PrepareExternalFreeArcConfig("Password=ABC", "a", "b") = "")

$g_iPipelineWarn = 1
Check("unsupported never reported as success", _PipelineFinalBadgeText("notsupported") = "UNSUPPORTED / NOT EXTRACTED")
Check("unsupported neutral badge", _PipelineFinalBadgeClass("notsupported") = "info")
Check("failed is failure", _PipelineFinalBadgeText("failed") = "EXTRACTION FAILED")
Check("failed badge", _PipelineFinalBadgeClass("failed") = "fail")
Check("success with warning", _PipelineFinalBadgeText("success") = "SUCCESS WITH WARNINGS")
$g_iPipelineWarn = 0
Check("clean success", _PipelineFinalBadgeText("success") = "FULL SUCCESS")
ConsoleWrite("External FreeArc opt-in/parser/report unit tests passed" & @CRLF)
Exit 0

'@
$Test = Join-Path $Dir 'external-freearc-test.au3'
[IO.File]::WriteAllText($Test, $Harness + ($Fns -join [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
$Stdout = Join-Path $Dir 'stdout.txt'
$Stderr = Join-Path $Dir 'stderr.txt'
$Proc = Start-Process -FilePath $AutoItExe -ArgumentList ('"' + $Test + '"') -Wait -PassThru -RedirectStandardOutput $Stdout -RedirectStandardError $Stderr
if (Test-Path $Stdout) { Get-Content $Stdout | ForEach-Object { Write-Host $_ } }
if (Test-Path $Stderr) { Get-Content $Stderr | ForEach-Object { Write-Host $_ } }
if ($Proc.ExitCode -ne 0) { throw "External FreeArc unit test failed: $($Proc.ExitCode)" }
Write-Host 'FreeArc backend compatibility tests passed.'
