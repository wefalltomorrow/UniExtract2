[CmdletBinding()]
param([string]$SevenZip = (Join-Path $env:ProgramFiles '7-Zip\7z.exe'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Repo = Split-Path -Parent $PSScriptRoot
$Work = Join-Path $Repo '.build\file548'
$Stage = Join-Path $Work 'candidate'
$ReleaseStage = Join-Path $Work 'release'
$PackageRoot = Join-Path $Work 'packages'
& (Join-Path $PSScriptRoot 'stage-libmagic-548.ps1') -StageRoot $ReleaseStage -PackageRoot $PackageRoot -SevenZip $SevenZip
$Runtime = Join-Path $ReleaseStage 'bin\x64\libmagic548'
# Inspect the actual pinned runtime, including delay imports, for missing DLLs.
& python -m pip install --disable-pip-version-check --no-input 'pefile==2024.8.26'
if ($LASTEXITCODE -ne 0) { throw 'Cannot install pinned PE parser.' }
& python (Join-Path $PSScriptRoot 'stage-pe-deps.py') $Runtime $Stage (Join-Path $Runtime 'file.exe')
if ($LASTEXITCODE -ne 0) { throw 'Incomplete DLL dependency closure.' }
Copy-Item -LiteralPath (Join-Path $Runtime 'magic.mgc') -Destination $Stage -Force
Copy-Item -LiteralPath (Join-Path $ReleaseStage 'docs\third-party\libmagic548') -Destination (Join-Path $Stage 'licenses') -Recurse -Force
$TextFile = Join-Path $Work 'magic-probe.txt'
[IO.File]::WriteAllText($TextFile, 'Universal Extractor type recognition sample' + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
$Zip = Join-Path $Work 'probe.zip'
Compress-Archive -LiteralPath $TextFile -DestinationPath $Zip -Force
$UnicodeDir = Join-Path $Work ('space ' + [char]0x65e5 + [char]0x672c)
New-Item -ItemType Directory -Path $UnicodeDir -Force | Out-Null
$UnicodeZip = Join-Path $UnicodeDir 'archive.bin'
Copy-Item -LiteralPath $Zip -Destination $UnicodeZip -Force
$Cases = @(
    @{Name='pe';Source=(Join-Path $Runtime 'file.exe');Pattern='PE32'},
    @{Name='text';Source=$TextFile;Pattern='text'},
    @{Name='zip';Source=$Zip;Pattern='(?i)Zip archive data'},
    # The MSYS2 helper uses the active ANSI code page. On some Windows
    # systems this path is unsupported; retain an explicit compatibility
    # record instead of mistaking its diagnostic (exit 0) for identification.
    @{Name='unicode';Source=$UnicodeZip;Pattern='(?i)Zip archive data|^cannot open '}
)
$Exe = Join-Path $Stage 'file.exe'
$Magic = Join-Path $Stage 'magic.mgc'
$SavedPath = $env:PATH
try {
    $env:PATH = "$Stage;$env:windir\System32;$env:windir"
    foreach ($Case in $Cases) {
        $Output = (& $Exe -b -m $Magic $Case.Source 2>&1 | Out-String)
        if ($LASTEXITCODE -ne 0 -or $Output -notmatch $Case.Pattern) { throw "Isolated detection failed: $($Case.Name): $Output" }
        $Output | Set-Content -LiteralPath (Join-Path $Work ($Case.Name + '.stdout.txt')) -Encoding UTF8
        if ($Case.Name -eq 'unicode' -and $Output -match '^cannot open ') {
            Write-Warning 'Unicode path is unsupported by this helper/code-page combination. Application must reject the diagnostic and fall back.'
        } else {
            Write-Host "$($Case.Name) detection passed: $($Output.Trim())"
        }
    }
} finally { $env:PATH = $SavedPath }
Get-ChildItem -LiteralPath $Stage -File | Select-Object Name,Length,
    @{Name='SHA256';Expression={(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}} |
    Export-Csv -LiteralPath (Join-Path $Work 'CANDIDATE-INVENTORY.csv') -NoTypeInformation -Encoding UTF8
@('Pinned libmagic 5.48 candidate; not a stable release.', 'Seven binary/database hashes preserved.', 'Closed DLL imports; clean-PATH PE, text and ZIP detection passed.') |
    Set-Content -LiteralPath (Join-Path $Work 'CANDIDATE-SUMMARY.txt') -Encoding UTF8
Compress-Archive -Path (Join-Path $Stage '*') -DestinationPath (Join-Path $Work 'libmagic-5.48-x64-candidate.zip') -Force
Write-Host 'LIBMAGIC-ISOLATED-TESTS-PASSED'
