[CmdletBinding()]
param([string]$StageRoot, [string]$AutoItExe, [string]$SourceFile)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Repo = Split-Path -Parent $PSScriptRoot
if (-not $StageRoot) { $StageRoot = Join-Path $Repo '.build\release' }
if (-not $SourceFile) { $SourceFile = Join-Path $Repo 'UniExtract.au3' }
$AutoItExe = @($AutoItExe, 'C:\Program Files (x86)\AutoIt3\AutoIt3.exe', (Join-Path $env:ProgramFiles 'AutoIt3\AutoIt3.exe')) |
    Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $AutoItExe) { throw 'AutoIt3 interpreter missing.' }
$Source = Get-Content -LiteralPath $SourceFile -Raw
$Functions = foreach ($Name in @('_UnixFileType', 'FetchStdout', '_MakeCommand', 'Quote', '_WinGetByPID', 'KillHelper', '_KillProcessTree')) {
    $Match = [regex]::Match($Source, '(?ms)^Func ' + $Name + '\([^\r\n]*\)\r?\n.*?^EndFunc')
    if (-not $Match.Success) { throw "Missing production function: $Name" }
    $Match.Value
}
# A unique test folder avoids reusing or deleting another run's evidence.
$Root = Join-Path $Repo ('.build\magic-unicode-' + [guid]::NewGuid().ToString('N'))
$InputRoot = Join-Path $Root ('input ' + [char]0x65e5 + [char]0x672c + ' %PATH% !bang! & (space)^')
$RuntimeRoot = Join-Path $Root ('runtime ' + [char]0x8a9e + ' %TEMP% !bang! & (space)^')
New-Item -ItemType Directory -Path $InputRoot, $RuntimeRoot -Force | Out-Null
$Text = Join-Path $InputRoot 'text.bin'
[IO.File]::WriteAllText($Text, 'Universal Extractor detection sample' + [Environment]::NewLine, [Text.Encoding]::ASCII)
$Zip = Join-Path $InputRoot ('--' + [char]0x5165 + [char]0x529b + ' %PATH% !x! & (zip)^.bin')
Add-Type -AssemblyName System.IO.Compression
$Stream = [IO.File]::Create($Zip)
$Archive = New-Object IO.Compression.ZipArchive($Stream, [IO.Compression.ZipArchiveMode]::Create)
try {
    $Entry = $Archive.CreateEntry('payload.bin').Open()
    try { $Bytes = [byte[]](0, 26, 13, 10, 255, 65); $Entry.Write($Bytes, 0, $Bytes.Length) }
    finally { $Entry.Dispose() }
} finally { $Archive.Dispose(); $Stream.Dispose() }
[IO.File]::WriteAllBytes((Join-Path $InputRoot 'unknown.bin'), [byte[]](0, 255, 1, 254, 2, 253, 3, 252))
[IO.File]::WriteAllText((Join-Path $InputRoot 'pdf.bin'), (@('%PDF-1.4','1 0 obj','<<>>','endobj','%%EOF') -join [Environment]::NewLine), [Text.Encoding]::ASCII)
Copy-Item -LiteralPath (Join-Path $StageRoot 'UniExtract.exe') -Destination (Join-Path $InputRoot 'pe.bin')
$Before = @(Get-ChildItem -LiteralPath $InputRoot -File | ForEach-Object {
    $_.Name + '|' + $_.Length + '|' + $_.LastWriteTimeUtc.Ticks + '|' + (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
})
$Runtimes = @(@{Name='legacy'; Path=(Join-Path $StageRoot 'bin'); Files=@('file.exe','magic.mgc')})
if ([Environment]::Is64BitOperatingSystem) {
    $Runtimes += @{Name='x64'; Path=(Join-Path $StageRoot 'bin\x64\libmagic548'); Files=@('file.exe','magic.mgc','libmagic-1.dll','libsystre-0.dll','libtre-5.dll','libintl-8.dll','libiconv-2.dll')}
}
$Harness = @'
#include <AutoItConstants.au3>
#include <String.au3>
Global $file = "", $filedir = $CmdLine[2], $bindir = $CmdLine[1] & "\"
Global $cmd = @ComSpec & ' /d /c ', $run = 0, $runtitle = "", $Timeout = 10000
Global $exe = $bindir & "file.exe", $before = $CmdLine[3] = "True"
EnvSet("UE_MAGIC_EXE_" & @AutoItPID, "saved executable")
EnvSet("UE_MAGIC_INPUT_" & @AutoItPID, "saved input")
; Unicode input, Unicode runtime/database, shell characters, leading --.
Check("ZIP", "--" & ChrW(0x5165) & ChrW(0x529b) & " %PATH% !x! & (zip)^.bin", "(?i)^Zip archive data")
Check("text", "text.bin", "(?i)text")
Check("PE", "pe.bin", "^PE32")
Check("PDF", "pdf.bin", "^PDF document")
Check("unknown", "unknown.bin", "^$")
Check("missing input", "missing.bin", "^$")
Local $originalExe = $exe
$exe = $bindir & "missing.exe"
Check("missing executable", "text.bin", "^$")
$exe = $originalExe
If Not FileMove($bindir & "magic.mgc", $bindir & "magic.saved") Then Exit 2
Check("missing database", "text.bin", "^$")
If Not FileMove($bindir & "magic.saved", $bindir & "magic.mgc") Then Exit 2
ConsoleWrite("LIBMAGIC-UNICODE-TESTS-PASSED" & @CRLF)
Exit 0
Func Check($label, $name, $pattern)
    $file = $filedir & "\" & $name
    Local $argument = $exe
    If $before Then $argument = Quote($exe, True) & " -m " & Quote($bindir & "magic.mgc")
    Local $actual = _UnixFileType($argument)
    ConsoleWrite($label & ": " & $actual & @CRLF)
    If Not StringRegExp($actual, $pattern) Then Exit 1
    If EnvGet("UE_MAGIC_EXE_" & @AutoItPID) <> "saved executable" Or EnvGet("UE_MAGIC_INPUT_" & @AutoItPID) <> "saved input" Then Exit 3
EndFunc
Func Cout($value)
EndFunc
'@
$Script = Join-Path $Root 'unicode.au3'
[IO.File]::WriteAllText($Script, $Harness + [Environment]::NewLine + ($Functions -join [Environment]::NewLine), (New-Object Text.UTF8Encoding($true)))
$BeforeFix = $Source.Contains('Func _UnixFileToolCommand(')
foreach ($Runtime in $Runtimes) {
    $Destination = Join-Path $RuntimeRoot $Runtime.Name
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    foreach ($Name in $Runtime.Files) { Copy-Item -LiteralPath (Join-Path $Runtime.Path $Name) -Destination $Destination }
    $Out = Join-Path $Root ($Runtime.Name + '.stdout.txt')
    $Err = Join-Path $Root ($Runtime.Name + '.stderr.txt')
    $Args = '"' + $Script + '" "' + $Destination + '" "' + $InputRoot + '" ' + $BeforeFix
    $Process = Start-Process -FilePath $AutoItExe -ArgumentList $Args -WindowStyle Hidden -PassThru -RedirectStandardOutput $Out -RedirectStandardError $Err
    $Handle = $Process.Handle # Retain the process handle for ExitCode on Windows PowerShell 5.1.
    if (-not $Process.WaitForExit(60000)) { Stop-Process -Id $Process.Id -Force; throw 'Unicode test timed out.' }
    $Process.WaitForExit()
    $Output = Get-Content -LiteralPath $Out -Raw
    Write-Host ($Runtime.Name + ': ' + $Output)
    if ($Process.ExitCode -ne 0 -or $Output -notmatch 'LIBMAGIC-UNICODE-TESTS-PASSED') {
        Get-Content -LiteralPath $Err | ForEach-Object { Write-Host $_ }
        throw "Unicode detector test failed: $($Runtime.Name). Evidence: $Root"
    }
}
$After = @(Get-ChildItem -LiteralPath $InputRoot -File | ForEach-Object {
    $_.Name + '|' + $_.Length + '|' + $_.LastWriteTimeUtc.Ticks + '|' + (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
})
if (Compare-Object $Before $After) { throw 'Detector altered the input files.' }
Write-Host "Input hashes, sizes, timestamps and directory contents preserved. Evidence: $Root"
