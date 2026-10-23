[CmdletBinding()]
param([string]$AutoItExe, [string]$StageRoot)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Repo = Split-Path -Parent $PSScriptRoot
if (-not $StageRoot) { $StageRoot = Join-Path $Repo '.build\release' }
$Stage = $StageRoot
$Exe = Join-Path $Stage 'UniExtract.exe'
if (-not (Test-Path -LiteralPath $Exe)) { throw 'Build and package first.' }
$AutoItExe = @($AutoItExe, 'C:\Program Files (x86)\AutoIt3\AutoIt3.exe', (Join-Path $env:ProgramFiles 'AutoIt3\AutoIt3.exe')) |
    Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $AutoItExe) { throw 'AutoIt3 interpreter not installed.' }
$Case = Join-Path $Repo ('.build\packaged-external ' + [char]0x65E5)
$Backend = Join-Path $Case 'backend'
New-Item -ItemType Directory -Path $Backend -Force | Out-Null
$Compiler = Join-Path (Split-Path $AutoItExe) 'Aut2Exe\Aut2exe.exe'
$Fixture = Join-Path $PSScriptRoot 'fixtures\external-freearc-wrapper.au3'
$Wrapper = Join-Path $Backend 'unpack.exe'
$Process = Start-Process -FilePath $Compiler -ArgumentList ('/in "' + $Fixture + '" /out "' + $Wrapper + '" /console /x86') -PassThru
if (-not $Process.WaitForExit(60000)) { Stop-Process -Id $Process.Id -Force; throw 'Fixture compiler timed out.' }
if (-not (Test-Path -LiteralPath $Wrapper)) { throw 'Fixture compiler failed.' }
[IO.File]::WriteAllText((Join-Path $Backend 'unarc.dll'), 'placeholder, never loaded')
[IO.File]::WriteAllText((Join-Path $Backend 'arc.ini'), '; synthetic')
$Prefs = Join-Path $Stage 'UniExtract.ini'
$Original = if (Test-Path -LiteralPath $Prefs) { [IO.File]::ReadAllBytes($Prefs) } else { $null }
$PrefsText = if ($null -ne $Original) { [IO.File]::ReadAllText($Prefs) } else { '' }
$PrefsText = [regex]::Replace($PrefsText, '(?ms)^\[FreeArc\][^\[]*', '')
try {
    [IO.File]::WriteAllText($Prefs, $PrefsText + "`r`n[FreeArc]`r`nExternalUnpackerEnabled=1`r`nExternalUnpackerDir=$Backend`r`nExternalUnpackerTimeoutSeconds=10`r`n", [Text.Encoding]::Unicode)
    foreach ($Mode in @('success', 'nonzero', 'empty')) {
        $Archive = Join-Path $Case ('packaged-external-' + $Mode + '.bin')
        $Output = Join-Path $Case ('output-' + $Mode + '-' + [guid]::NewGuid().ToString('N'))
        [IO.File]::WriteAllBytes($Archive, [byte[]]@(0x41,0x72,0x43,0x01,0,0,0,0))
        $Config = "InputFile=unused`r`nOutputPath=unused`r`nWorkPath=unused`r`nCfgFile=unused`r`nPassword=SYNTHETIC-Secret-Only`r`nFixtureMode=$Mode"
        [IO.File]::WriteAllText((Join-Path $Backend 'config.ini'), $Config, (New-Object Text.UTF8Encoding($true)))
        $Started = Get-Date
        $Process = Start-Process -FilePath $Exe -ArgumentList ('"' + $Archive + '" "' + $Output + '" /silent') -PassThru
        if (-not $Process.WaitForExit(60000)) { & taskkill.exe /PID $Process.Id /T /F | Out-Null; throw "Packaged external $Mode timed out." }
        $Files = @(Get-ChildItem -LiteralPath $Output -Recurse -File -ErrorAction SilentlyContinue)
        if ($Mode -eq 'success') {
            $Payload = Join-Path $Output 'nested\payload.txt'
            if (-not (Test-Path -LiteralPath $Payload) -or [IO.File]::ReadAllText($Payload) -cne 'fixture payload') { throw 'Packaged external output mismatch.' }
            if ($null -ne $Process.ExitCode -and $Process.ExitCode -ne 0) { throw 'Packaged external success returned failure.' }
        } elseif ($Files.Count -ne 0 -or $Process.ExitCode -eq 0) { throw "Packaged external $Mode was incorrectly accepted." }
        $Reports = @(Get-ChildItem -LiteralPath (Join-Path $Stage 'log') -File | Where-Object { $_.LastWriteTime -ge $Started.AddSeconds(-1) -and $_.Name.Contains('packaged-external-' + $Mode) })
        if ($Reports.Count -eq 0) { throw 'Missing packaged diagnostic reports.' }
        $Html = @($Reports | Where-Object { $_.Extension -eq '.html' })
        if ($Html.Count -ne 1) { throw 'Expected one HTML pipeline report per attempt.' }
        $HtmlText = [IO.File]::ReadAllText($Html[0].FullName)
        $Text = ($Reports | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n"
        if ($Text.Contains('SYNTHETIC-Secret-Only')) { throw 'Credential found in packaged reports.' }
        if ($Mode -eq 'success' -and -not $Text.Contains('External FreeArc unpack.exe (user-supplied)')) { throw 'External winner missing from packaged reports.' }
        if ($Mode -ne 'success' -and $Text -match '(?i)>\s*(FULL SUCCESS|SUCCESS WITH WARNINGS)\s*<') { throw 'Failure report has a success badge.' }
        if ($Mode -ne 'success' -and $HtmlText -notmatch '(UNSUPPORTED / NOT EXTRACTED|EXTRACTION FAILED)') { throw 'Failure report has no final failure badge.' }
        if (@(Get-ChildItem -LiteralPath $Case -Directory -Filter '.UniExtract2-FreeArc-*').Count) { throw 'Packaged attempt left a staging directory.' }
        Write-Host "Packaged external FreeArc [$Mode] passed (output, reports, credentials and cleanup)."
    }
} finally {
    if ($null -ne $Original) { [IO.File]::WriteAllBytes($Prefs, $Original) }
    else { Remove-Item -LiteralPath $Prefs -ErrorAction SilentlyContinue }
}
