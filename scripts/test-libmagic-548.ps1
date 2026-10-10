[CmdletBinding()]
param([string]$Msys2Location = $env:MSYS2_LOCATION)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $Msys2Location) { throw 'MSYS2_LOCATION is required from setup-msys2 action' }

$Repo = Split-Path -Parent $PSScriptRoot
$Work = Join-Path $Repo '.build\file548'
$Stage = Join-Path $Work 'candidate'
$Bin = Join-Path $Msys2Location 'mingw64\bin'
$Magic = Join-Path $Msys2Location 'mingw64\share\misc\magic.mgc'
$SourceExe = Join-Path $Bin 'file.exe'
$ExpectedPackageHash = '844a8e6451f51aa9bfcbbdf92248b0e406891a51738ad2d8161835d7100d4f3f'
$PackageURL = 'https://mirror.msys2.org/mingw/mingw64/mingw-w64-x86_64-file-5.48-1-any.pkg.tar.zst'

New-Item -ItemType Directory -Force -Path $Work, $Stage | Out-Null
if (-not (Test-Path -LiteralPath $SourceExe -PathType Leaf) -or
    -not (Test-Path -LiteralPath $Magic -PathType Leaf)) {
    throw 'MSYS2 did not install both file.exe and its matching magic.mgc.'
}
# Also verify the official version-pinned package archive itself, not merely
# trusting a mutable package database or resource FileVersion metadata.
# setup-msys2 installs verified Pacman packages into its local package cache.
# Prefer that exact cached archive to a separate HTTPS download, which can be
# rejected by mirror anti-bot servers even when pacman succeeds.
$Cache = Join-Path $Msys2Location 'var\cache\pacman\pkg'
$PackageName = 'mingw-w64-x86_64-file-5.48-1-any.pkg.tar.zst'
$Matches = @(Get-ChildItem -LiteralPath $Cache -Filter $PackageName -File -ErrorAction SilentlyContinue)
if ($Matches.Count -lt 1) {
    # Request an authenticated package download through pacman, not through
    # PowerShell's web client. Fail closed if the package cannot be cached.
    Write-Host 'Refreshing the local signed pacman package cache...'
    $Pacman = Join-Path $Msys2Location 'usr\bin\pacman.exe'
    & $Pacman --noconfirm -Sw mingw-w64-x86_64-file
    if ($LASTEXITCODE -ne 0) { throw "pacman failed to cache file/libmagic 5.48 ($LASTEXITCODE)" }
    $Matches = @(Get-ChildItem -LiteralPath $Cache -Filter $PackageName -File -ErrorAction SilentlyContinue)
}
if ($Matches.Count -ne 1) {
    throw "Could not find exactly one authentic $PackageName in the local pacman cache."
}
$Archive = $Matches[0].FullName
$Hash = (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash.ToLowerInvariant()
if ($Hash -ne $ExpectedPackageHash) { throw "Cached upstream file/libmagic package SHA256 mismatch: $Hash" }
Write-Host "Official MSYS2 5.48-1 package SHA256 verified: $Hash"

# Dependency closure is determined from the PE import tables, not guessed
# from the upstream package's top-level dependency list.
& python -m pip install --disable-pip-version-check --no-input 'pefile==2024.8.26'
if ($LASTEXITCODE -ne 0) { throw 'Cannot install pinned pefile parser.' }
& python (Join-Path $PSScriptRoot 'stage-pe-deps.py') $Bin $Stage $SourceExe
if ($LASTEXITCODE -ne 0) { throw 'Could not stage complete DLL dependencies.' }
Copy-Item -LiteralPath $Magic -Destination (Join-Path $Stage 'magic.mgc') -Force

$LicSource = Join-Path $Msys2Location 'mingw64\share\licenses'
$LicDest = Join-Path $Stage 'licenses'
if (-not (Test-Path -LiteralPath (Join-Path $LicSource 'file\COPYING'))) {
    throw 'Missing file/libmagic license in MSYS2 package.'
}
# Preserve all installed dependency license notices for analysis. A final
# shipping update will need an exact smaller third-party bill of materials.
Copy-Item -LiteralPath $LicSource -Destination $LicDest -Recurse -Force

$Candidates = @(
    @{Name='pe'; Source=(Join-Path $env:windir 'System32\notepad.exe'); Pattern='PE32|executable|MS Windows|Windows executable'},
    @{Name='text'; Pattern='ASCII text|Unicode text|UTF-8 text|text'}
)
$TextFile = Join-Path $Work 'magic-probe.txt'
[IO.File]::WriteAllText($TextFile, 'Universal Extractor file/libmagic type recognition sample' + [Environment]::NewLine,
    (New-Object Text.UTF8Encoding($false)))
$Candidates[1].Source = $TextFile

$ZipPayload = Join-Path $Work 'payload.txt'
Set-Content -LiteralPath $ZipPayload -Value 'ZIP magic probe' -Encoding ASCII
$Zip = Join-Path $Work 'probe.zip'
Compress-Archive -LiteralPath $ZipPayload -DestinationPath $Zip -Force
$Candidates += @{Name='zip'; Source=$Zip; Pattern='Zip archive data|ZIP archive data'}

$OutFile = Join-Path $Stage 'file.exe'
$VersionOut = Join-Path $Work 'version.stdout.txt'
$VersionErr = Join-Path $Work 'version.stderr.txt'
$SavedPATH = $env:PATH
try {
    # Crucial: do not accidentally satisfy missing DLL imports from MSYS2's
    # normal PATH or other software on the GitHub runner.
    $env:PATH = "$Stage;$env:windir\System32;$env:windir"
    $VersionProcess = Start-Process -FilePath $OutFile -ArgumentList '--version' -WorkingDirectory $Stage -Wait -PassThru -NoNewWindow -RedirectStandardOutput $VersionOut -RedirectStandardError $VersionErr
    $VersionText = Get-Content -LiteralPath $VersionOut -Raw
    if ($VersionProcess.ExitCode -ne 0 -or $VersionText -notmatch '(?m)file(?:\.exe)?-5\.48\b') {
        throw "Isolated file.exe --version failed: $VersionText"
    }
    foreach ($Case in $Candidates) {
        $StdoutFile = Join-Path $Work ($Case.Name + '.stdout.txt')
        $StderrFile = Join-Path $Work ($Case.Name + '.stderr.txt')
        $Args = '-b -m "' + (Join-Path $Stage 'magic.mgc') + '" "' + $Case.Source + '"'
        $Process = Start-Process -FilePath $OutFile -ArgumentList $Args -WorkingDirectory $Stage -Wait -PassThru -NoNewWindow -RedirectStandardOutput $StdoutFile -RedirectStandardError $StderrFile
        $Output = Get-Content -LiteralPath $StdoutFile -Raw
        $ErrorText = Get-Content -LiteralPath $StderrFile -Raw -ErrorAction SilentlyContinue
        if ($Process.ExitCode -ne 0 -or $Output -notmatch $Case.Pattern) {
            throw "libmagic 5.48 failed '$($Case.Name)' detection (code $($Process.ExitCode)): $Output $ErrorText"
        }
        Write-Host "$($Case.Name) detection passed: $($Output.Trim())"
    }
} finally { $env:PATH = $SavedPATH }

$Inventory = Get-ChildItem -LiteralPath $Stage -File | Select-Object Name,Length,
    @{Name='SHA256';Expression={(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}}
$Inventory | Export-Csv -LiteralPath (Join-Path $Work 'CANDIDATE-INVENTORY.csv') -Encoding UTF8 -NoTypeInformation
@(
    'file/libmagic 5.48 Win64 candidate (not integrated)'
    "Official MSYS2 package URL: $PackageURL"
    "Official SHA256: $ExpectedPackageHash"
    "Runtime files staged: $($Inventory.Count)"
    'Windows-only dependency closure verified with pefile'
    'Isolated clean-PATH detection: PE, text, ZIP passed'
    'x86 fallback and existing UniExtract file.exe/magic.mgc unchanged'
) | Set-Content -LiteralPath (Join-Path $Work 'CANDIDATE-SUMMARY.txt') -Encoding UTF8
Compress-Archive -Path (Join-Path $Stage '*') -DestinationPath (Join-Path $Work 'libmagic-5.48-x64-candidate.zip') -Force
Write-Host 'libmagic 5.48 isolated candidate validated; no release files changed.'
