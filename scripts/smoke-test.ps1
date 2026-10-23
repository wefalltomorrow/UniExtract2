[CmdletBinding()]
param([string]$StageRoot)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not $StageRoot) { $StageRoot = Join-Path $RepoRoot '.build\release' }
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

function Invoke-NormalFreeArcSmokeTest {
    $Fixture = Join-Path $RepoRoot 'tests\fixtures\freearc-normal.arc'
    $Case = Join-Path $SmokeRoot 'freearc-normal'
    $Output = Join-Path $Case 'output'
    New-Item -ItemType Directory -Path $Output -Force | Out-Null
    $Process = Start-Process -FilePath $Exe -ArgumentList ('"' + $Fixture + '" "' + $Output + '" /silent') -PassThru
    if (-not $Process.WaitForExit(60000)) {
        & taskkill.exe /PID $Process.Id /T /F | Out-Null
        throw 'Normal FreeArc extraction timed out.'
    }
    $Payload = Join-Path $Output 'hello.txt'
    if (-not (Test-Path -LiteralPath $Payload) -or [IO.File]::ReadAllText($Payload) -cne $Expected) {
        throw 'Normal FreeArc extraction did not reproduce the exact fixture payload.'
    }
    if ($null -ne $Process.ExitCode -and $Process.ExitCode -ne 0) { throw 'Normal FreeArc extraction returned failure.' }
    $Logs = @(Get-ChildItem -LiteralPath (Join-Path $StageRoot 'log') -Filter '*_FREEARC_freearc-normal.arc.log' -File | Sort-Object LastWriteTime -Descending)
    if ($Logs.Count -eq 0 -or -not ([IO.File]::ReadAllText($Logs[0].FullName).Contains('EXTRACTOR WINNER: unarc'))) {
        throw 'Normal FreeArc did not report the bundled unarc decoder as its winner.'
    }
    Write-Host 'Normal FreeArc extraction passed with the external backend disabled.'
}
Invoke-NormalFreeArcSmokeTest

# Full-pipeline regression: an ArC\x01 header must never be accepted as GARbro
# PD/KAAS, even if a numbered installer sidecar and setup.exe are adjacent.
# A tiny intentionally invalid FreeArc stub is used so this test does not ship
# or execute copyrighted game content and cannot decompress tens of gigabytes.
function Invoke-FreeArcRoutingSmokeTest {
    $Case = Join-Path $SmokeRoot 'freearc-header-falsepositive'
    $Output = Join-Path $Case 'output'
    New-Item -ItemType Directory -Path $Output -Force | Out-Null
    $Archive = Join-Path $Case 'setup-1.bin'
    [IO.File]::WriteAllBytes($Archive, [byte[]]@(0x41,0x72,0x43,0x01,0,0,0,0))
    [IO.File]::WriteAllBytes((Join-Path $Case 'setup.exe'),[byte[]]@(0x4d,0x5a))
    $Arguments = '"' + $Archive + '" "' + $Output + '" /silent'
    $Process = Start-Process -FilePath $Exe -ArgumentList $Arguments -PassThru
    if (-not $Process.WaitForExit(60000)) {
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
        throw 'FreeArc header routing regression timed out.'
    }
    if ($Process.ExitCode -eq 0) {
        throw 'Invalid FreeArc fixture was incorrectly considered successfully extracted.'
    }
    $FakePd = @(Get-ChildItem -LiteralPath $Output -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^setup-1#\d{4}' })
    if ($FakePd.Count -gt 0) {
        throw 'GARbro generated PD/KAAS pseudo-files for a FreeArc signature.'
    }
    Write-Host "FreeArc header routing passed: failed closed (exit $($Process.ExitCode)) without GARbro pseudo-files."
}
Invoke-FreeArcRoutingSmokeTest

# Real packaged-app integration checks: filename suffixes must never override
# verified header evidence or turn ordinary non-archives into game pseudo-files.
function Invoke-VerifiedHeaderRoutingSmokeTest {
    $CaseRoot = Join-Path $SmokeRoot 'verified-header-routing'
    $PayloadRoot = Join-Path $CaseRoot 'payload'
    $ExtractedRoot = Join-Path $CaseRoot 'extracted'
    New-Item -ItemType Directory -Force -Path $PayloadRoot, $ExtractedRoot | Out-Null
    $ExpectedText = 'Native ZIP content must win over game-archive guesses'
    $Payload = Join-Path $PayloadRoot 'verified.txt'
    Set-Content -LiteralPath $Payload -Value $ExpectedText -Encoding ASCII
    $Zip = Join-Path $CaseRoot 'legitimate.zip'
    Compress-Archive -LiteralPath $Payload -DestinationPath $Zip -CompressionLevel Optimal -Force
    $Disguised = Join-Path $CaseRoot 'legitimate.bin'
    Move-Item -LiteralPath $Zip -Destination $Disguised -Force

    $Arguments = '"' + $Disguised + '" "' + $ExtractedRoot + '" /silent'
    $Process = Start-Process -FilePath $Exe -ArgumentList $Arguments -PassThru
    if (-not $Process.WaitForExit(60000)) {
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
        throw 'Header-based ZIP extraction timed out.'
    }
    $ActualFiles = @(Get-ChildItem -LiteralPath $ExtractedRoot -Recurse -File -ErrorAction SilentlyContinue)
    $Found = @($ActualFiles | Where-Object { $_.Name -eq 'verified.txt' })
    $PseudoFiles = @($ActualFiles | Where-Object { $_.Name -match 'legitimate#\d{4}' })
    if ($Found.Count -ne 1 -or $PseudoFiles.Count -gt 0) {
        throw "Valid ZIP renamed .bin was misidentified or failed extraction (exit $($Process.ExitCode))."
    }
    $ActualText = (Get-Content -LiteralPath $Found[0].FullName -Raw).Trim()
    if ($ActualText -ne $ExpectedText) {
        throw "Extracted ZIP data did not match expected payload: $ActualText"
    }

    # A PNG signature with a misleading .zip extension is NOT an archive.
    # Never create GARbro/QuickBMS pseudo-output for an invalid image stub.
    $Fake = Join-Path $CaseRoot 'fake.zip'
    $FakeOutput = Join-Path $CaseRoot 'fake-output'
    New-Item -ItemType Directory -Force -Path $FakeOutput | Out-Null
    [IO.File]::WriteAllBytes($Fake, [byte[]]@(0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a,0,0,0,0))
    $Arguments = '"' + $Fake + '" "' + $FakeOutput + '" /silent'
    $Process = Start-Process -FilePath $Exe -ArgumentList $Arguments -PassThru
    if (-not $Process.WaitForExit(60000)) {
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
        throw 'Misleading-extension PNG routing timed out.'
    }
    $FakeFiles = @(Get-ChildItem -LiteralPath $FakeOutput -Recurse -File -ErrorAction SilentlyContinue)
    if ($FakeFiles.Count -gt 0) {
        throw "Ordinary PNG header with misleading .zip extension was falsely extracted ($($FakeFiles.Count) files)."
    }
    Write-Host 'Verified-header routing smoke passed: ZIP renamed .bin extracted correctly, PNG renamed .zip did not produce pseudo-files.'
}
Invoke-VerifiedHeaderRoutingSmokeTest

Write-Host 'All packaged extraction smoke tests passed.'
