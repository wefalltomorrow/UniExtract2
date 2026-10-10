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
$Expected = 'Universal Extractor 2 smoke test'

Remove-Item -LiteralPath $SmokeRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $SmokeRoot -Force | Out-Null

function Invoke-SmokeExtraction {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$ArchiveName
    )

    $CaseRoot = Join-Path $SmokeRoot $Name
    $InputRoot = Join-Path $CaseRoot 'input'
    $OutRoot = Join-Path $CaseRoot 'output'
    $Archive = Join-Path $CaseRoot $ArchiveName
    $Payload = Join-Path $InputRoot 'hello.txt'

    New-Item -ItemType Directory -Path $InputRoot, $OutRoot -Force | Out-Null
    Set-Content -LiteralPath $Payload -Value $Expected -Encoding ASCII
    Compress-Archive -LiteralPath $Payload -DestinationPath $Archive -CompressionLevel Optimal -Force

    $Arguments = '"' + $Archive + '" "' + $OutRoot + '" /silent'
    Write-Host "Smoke testing [$Name]: $Exe $Arguments"

    $Process = Start-Process -FilePath $Exe -ArgumentList $Arguments -PassThru
    if (-not $Process.WaitForExit(60000)) {
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
        throw "UniExtract smoke test '$Name' timed out after 60 seconds."
    }

    $Extracted = Get-ChildItem -LiteralPath $OutRoot -Filter 'hello.txt' -File -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if (-not $Extracted) {
        throw "Smoke test '$Name' did not extract hello.txt. UniExtract exit code: $($Process.ExitCode)"
    }

    $Actual = (Get-Content -LiteralPath $Extracted.FullName -Raw).Trim()
    if ($Actual -ne $Expected) {
        throw "Smoke-test payload mismatch in '$Name'. Expected '$Expected', got '$Actual'."
    }

    Write-Host "Smoke test passed [$Name]: $($Extracted.FullName)"
    Write-Host "UniExtract exit code [$Name]: $($Process.ExitCode)"
}

Invoke-SmokeExtraction -Name 'basic' -ArchiveName 'smoke-test.zip'

# Keep this script ASCII-only for Windows PowerShell 5.1, but still create a real Unicode filename.
$UnicodeArchiveName = 'smoke-' + [char]0x30E6 + [char]0x30CB + [char]0x30B3 + [char]0x30FC + [char]0x30C9 + '.zip'
Invoke-SmokeExtraction -Name 'unicode-filename' -ArchiveName $UnicodeArchiveName

# Regression fixture: a very short, mono 22.05 kHz CRI ADX sine wave generated
# from a synthetic signal. No third-party game content is included.
function Invoke-VgmstreamAudioSmokeTest {
    $Fixture = Join-Path $RepoRoot 'tests\fixtures\vgmstream-sine.adx'
    $CaseRoot = Join-Path $SmokeRoot 'vgmstream-adx'
    $OutRoot = Join-Path $CaseRoot 'output'
    if (-not (Test-Path -LiteralPath $Fixture)) {
        throw "vgmstream ADX test fixture missing: $Fixture"
    }
    New-Item -ItemType Directory -Path $OutRoot -Force | Out-Null

    $Arguments = '"' + $Fixture + '" "' + $OutRoot + '" /silent'
    Write-Host "Smoke testing [vgmstream-adx]: $Exe $Arguments"
    $Process = Start-Process -FilePath $Exe -ArgumentList $Arguments -PassThru
    if (-not $Process.WaitForExit(60000)) {
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
        throw 'vgmstream ADX extraction timed out after 60 seconds.'
    }

    $Wav = Get-ChildItem -LiteralPath $OutRoot -Filter '*.wav' -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt 44 } | Select-Object -First 1
    if (-not $Wav) {
        throw "vgmstream ADX extraction did not create a nonempty WAV file. Exit code: $($Process.ExitCode)"
    }

    $Header = [System.IO.File]::ReadAllBytes($Wav.FullName)
    if ([System.Text.Encoding]::ASCII.GetString($Header, 0, 4) -ne 'RIFF' -or
        [System.Text.Encoding]::ASCII.GetString($Header, 8, 4) -ne 'WAVE') {
        throw "vgmstream extracted output is not a valid RIFF/WAVE file: $($Wav.FullName)"
    }
    Write-Host "Smoke test passed [vgmstream-adx]: $($Wav.FullName), $($Wav.Length) bytes"
}

Invoke-VgmstreamAudioSmokeTest

# Use an upstream ACE regression sample with a pinned Git blob hash.
function Invoke-AcefileSmokeTest {
    $AceExe = Join-Path $StageRoot 'bin\acefile.exe'
    if (-not (Test-Path -LiteralPath $AceExe)) { throw "Missing acefile.exe: $AceExe" }
    $AceCase = Join-Path $SmokeRoot 'acefile'
    $AceOut = Join-Path $AceCase 'output'
    New-Item -ItemType Directory -Path $AceOut -Force | Out-Null
    $Archive = Join-Path $AceCase 'acefile-sample.ace'
    $FixtureUrl = 'https://raw.githubusercontent.com/droe/acefile-testdata/main/blocked_unregistered/winappdbg-winappdbg_v1.6_plain.ace'
    Invoke-WebRequest -Uri $FixtureUrl -OutFile $Archive -UseBasicParsing
    $ActualBlob = (& git hash-object -- $Archive | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $ActualBlob -ne 'a32763f0627cc925a79c0a3824e4790d9966ba51') {
        throw "ACE fixture Git blob hash mismatch: $ActualBlob"
    }
    $Version = (& $AceExe --version 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0 -or $Version -notmatch 'acefile 0\.6\.14') {
        throw "acefile version test failed: $Version"
    }
    # acefile emits successful progress and integrity totals to STDERR. In
    # Windows PowerShell 5.1, piping native STDERR under Stop preference can
    # turn a zero-exit command into a terminating NativeCommandError.
    # Capture both streams to separate files and check the actual exit code.
    function Invoke-AcefileCapture([string]$Label, [string]$Arguments) {
        $StdoutFile = Join-Path $AceCase ("acefile-" + $Label + ".stdout.txt")
        $StderrFile = Join-Path $AceCase ("acefile-" + $Label + ".stderr.txt")
        $Process = Start-Process -FilePath $AceExe -ArgumentList $Arguments -NoNewWindow -PassThru -Wait -RedirectStandardOutput $StdoutFile -RedirectStandardError $StderrFile
        $Captured = @()
        foreach ($LogFile in @($StdoutFile, $StderrFile)) {
            if ((Get-Item -LiteralPath $LogFile).Length -gt 0) {
                $Captured += (Get-Content -LiteralPath $LogFile -Raw)
            }
        }
        $Message = $Captured -join [Environment]::NewLine
        if ($Process.ExitCode -ne 0) {
            throw "acefile command '$Label' exited $($Process.ExitCode): $Message"
        }
        return $Message
    }
    $Test = Invoke-AcefileCapture 'integrity' ('-t "' + $Archive + '"')
    if ($Test -notmatch '268 ok, 0 failed') {
        throw "acefile integrity report did not confirm all 268 test entries: $Test"
    }
    $Output = Invoke-AcefileCapture 'extract' ('-x -v -d "' + $AceOut + '" "' + $Archive + '"')
    $Extracted = @(Get-ChildItem -LiteralPath $AceOut -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt 0 })
    if ($Extracted.Count -lt 1) {
        throw "acefile produced no output: $Output"
    }
    Write-Host ("Smoke test passed [acefile]: extracted {0} files" -f $Extracted.Count)
}
Invoke-AcefileSmokeTest

Write-Host 'All packaged extraction smoke tests passed.'
