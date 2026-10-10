[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Root = Split-Path -Parent $PSScriptRoot
$Work = Join-Path $Root '.build\die321'
New-Item -ItemType Directory -Path $Work -Force | Out-Null
$Candidates = @(
    @{ Arch = 'x86'; Url = 'https://github.com/horsicq/DIE-engine/releases/download/3.21/die_win32_portable_3.21_x86.zip'; Sha = '7d7195f757c45f6b69364d167c9958fa60339d53876a87e4a1edbcbf67d1e477' },
    @{ Arch = 'x64'; Url = 'https://github.com/horsicq/DIE-engine/releases/download/3.21/die_win64_portable_3.21_x64.zip'; Sha = '078f2934f267392247f9c7b759a1c2457a48bc2000b25b80c2f129955ee4a3b9' }
)
# Exact SHA-256 values measured from the packaged release candidate's x64 die directory.
# Compare without relying on PE resource versions.
$BaselineSHA256 = @{
    'die.exe'  = 'fef9c2d49bd377190145dcb7e37d3a589b6e0e7149c4de68d1c9b3a22815426a'
    'diec.exe' = 'dda171a904f6dc3a2c414e99e9d718c8d7500bc26c3dcdc1a72ec0e7d718cfe7'
    'diel.exe' = '1eb4684fc4f963561a2e7f984241876fe0d0a8a3fbab73d06a829da00857f0b6'
}
$Rows = @()
$Sample = Join-Path $env:windir 'System32\notepad.exe'
if (-not (Test-Path -LiteralPath $Sample)) { throw "Cannot locate Windows PE sample: $Sample" }

foreach ($Entry in $Candidates) {
    $Arch = [string]$Entry.Arch
    $Dest = Join-Path $Work $Arch
    $Zip = Join-Path $Work ("die-3.21-" + $Arch + ".zip")
    New-Item -ItemType Directory -Force -Path $Dest | Out-Null
    Write-Host "Fetching upstream Detect It Easy 3.21 $Arch..."
    Invoke-WebRequest -Uri $Entry.Url -OutFile $Zip -UseBasicParsing
    $Hash = (Get-FileHash -LiteralPath $Zip -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($Hash -ne $Entry.Sha) { throw "Detect It Easy $Arch archive hash mismatch: $Hash" }
    Expand-Archive -LiteralPath $Zip -DestinationPath $Dest -Force

    $CliFiles = @(Get-ChildItem -LiteralPath $Dest -Recurse -File -Filter 'diec.exe')
    if ($CliFiles.Count -ne 1) { throw "Expected exactly one $Arch diec.exe, found $($CliFiles.Count)" }
    $Cli = $CliFiles[0].FullName
    $PackageDir = Split-Path -Parent $Cli
    foreach ($Exe in @('die.exe', 'diel.exe', 'diec.exe')) {
        $ExePath = Join-Path $PackageDir $Exe
        if (-not (Test-Path -LiteralPath $ExePath -PathType Leaf)) {
            throw "Detect It Easy package $Arch missing $Exe beside diec.exe"
        }
        $FileVersion = (Get-Item -LiteralPath $ExePath).VersionInfo.FileVersion
        Write-Host "$Arch $Exe embedded version: $FileVersion"
        # The official 3.21 release may retain older PE resource version fields.
        # Source authenticity comes from the SHA-256-pinned upstream archive.
        if ($FileVersion -notlike '3.21*') {
            Write-Warning "Upstream 3.21 $Arch $Exe embeds version '$FileVersion'; record rather than rejecting an authentic release."
        }
        $ExeHash = (Get-FileHash -LiteralPath $ExePath -Algorithm SHA256).Hash.ToLowerInvariant()
        $Comparison = if ($Arch -eq 'x64') {
            if ($ExeHash -eq $BaselineSHA256[$Exe]) { 'identical-to-bundled' } else { 'differs-from-bundled' }
        } else { 'no-bundled-x86-comparison' }
        Write-Host "$Arch $Exe versus bundled: $Comparison"
        $Rows += [pscustomobject]@{
            Arch = $Arch
            File = $Exe
            Bytes = (Get-Item -LiteralPath $ExePath).Length
            EmbeddedFileVersion = $FileVersion
            OfficialRelease = '3.21'
            SHA256 = $ExeHash
            BaselineComparison = $Comparison
        }
    }

    # Isolate PATH from MSYS/Chocolatey to prove the release's own dependencies
    # work when started from its root on a standard Windows runner.
    $SavedPath = $env:PATH
    try {
        $env:PATH = "$env:windir\System32;$env:windir"
        $Out = Join-Path $Work ($Arch + '-scan.stdout.txt')
        $Err = Join-Path $Work ($Arch + '-scan.stderr.txt')
        $ArgLine = '-j "' + $Sample + '"'
        $P = Start-Process -FilePath $Cli -WorkingDirectory $PackageDir -ArgumentList $ArgLine -RedirectStandardOutput $Out -RedirectStandardError $Err -Wait -PassThru
        $Stdout = Get-Content -LiteralPath $Out -Raw -ErrorAction SilentlyContinue
        $Stderr = Get-Content -LiteralPath $Err -Raw -ErrorAction SilentlyContinue
        Write-Host "CLI $Arch exit code: $($P.ExitCode)"
        if ($P.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($Stdout)) {
            throw "Detect It Easy $Arch could not scan notepad.exe. STDOUT: $Stdout STDERR: $Stderr"
        }
        if ($Stdout -notmatch 'PE|EXE|Microsoft|Executable') {
            throw "Detect It Easy $Arch scan output did not identify a Windows executable: $Stdout"
        }
        Write-Host "Detect It Easy $Arch 3.21 scan passed."
    } finally { $env:PATH = $SavedPath }
}
$Rows | Export-Csv -LiteralPath (Join-Path $Work 'DIE-321-BINARIES.csv') -NoTypeInformation -Encoding UTF8
Write-Host 'Both Detect It Easy 3.21 candidate builds passed checksum and clean-path PE scan tests. Note: PE resource versions are not release tags.'
