[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$StageRoot,
    [string]$PackageRoot,
    [string]$SevenZip
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $PackageRoot) { $PackageRoot = Join-Path (Split-Path -Parent $StageRoot) 'libmagic548-packages' }
if (-not $SevenZip) { $SevenZip = Join-Path $StageRoot 'bin\x64\7z.exe' }
$Msys2Location = & (Join-Path $PSScriptRoot 'get-libmagic-548.ps1') -WorkRoot $PackageRoot -SevenZip $SevenZip

$PackageName = 'mingw-w64-x86_64-file-5.48-1-any.pkg.tar.zst'
$PackageSha256 = '844a8e6451f51aa9bfcbbdf92248b0e406891a51738ad2d8161835d7100d4f3f'
$Cache = Join-Path $Msys2Location 'var\cache\pacman\pkg'
$Cached = @(Get-ChildItem -LiteralPath $Cache -File -Filter $PackageName -ErrorAction SilentlyContinue)
if ($Cached.Count -ne 1) {
    throw "Exactly one cached official $PackageName is required. Found $($Cached.Count)."
}
$FoundPackageHash = (Get-FileHash -LiteralPath $Cached[0].FullName -Algorithm SHA256).Hash.ToLowerInvariant()
if ($FoundPackageHash -ne $PackageSha256) {
    throw "MSYS2 file/libmagic package SHA-256 mismatch: $FoundPackageHash"
}

# Each binary was independently validated by the isolated Windows candidate
# and is pinned here to prevent silent changes from MSYS2 rolling packages.
$Files = [ordered]@{
    'file.exe'       = '0d7d9d14f2cbbf3e941219ec819cd450a851d06ab9104ef20f7b0f22b7f97f84'
    'libmagic-1.dll' = '73e9ab47916462ca1631cf165385eeb8664333cf7740c54ed6f9e2e2d8f6c798'
    'libsystre-0.dll'= '4bc4dae17267afec9f9812e88167980808848c10a255ccbda9ef4fd758897938'
    'libtre-5.dll'   = '5833b2b1f62b67d8b4b3881f1bc05f42b0dee1a9f10cef897cdf44d74d094fdf'
    'libintl-8.dll'  = '0537c3dd2378218508ebe3cc416d72a99ee2d24ae1c5525e23458f32544ef861'
    'libiconv-2.dll' = '7a282a854e01be726c6cccfe46f548c716aa45b3014818468253aaa4efbcd067'
    'magic.mgc'      = '1a98967ddb2a9ef80f9dd1a3f1fa3bebc4991741878a512310f0d434428de85e'
}
$Target = Join-Path $StageRoot 'bin\x64\libmagic548'
New-Item -ItemType Directory -Force -Path $Target | Out-Null
$Inventory = @()
foreach ($Name in $Files.Keys) {
    $Source = if ($Name -eq 'magic.mgc') {
        Join-Path $Msys2Location 'mingw64\share\misc\magic.mgc'
    } else {
        Join-Path (Join-Path $Msys2Location 'mingw64\bin') $Name
    }
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { throw "Missing libmagic runtime component: $Source" }
    $FoundHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($FoundHash -ne $Files[$Name]) {
        throw "Pinned file/libmagic hash mismatch for $Name. Expected $($Files[$Name]), got $FoundHash"
    }
    $TargetFile = Join-Path $Target $Name
    Copy-Item -LiteralPath $Source -Destination $TargetFile -Force
    $CopiedHash = (Get-FileHash -LiteralPath $TargetFile -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($CopiedHash -ne $FoundHash) { throw "Copy integrity failed for $Name" }
    $Inventory += [pscustomobject]@{ Name=$Name; SHA256=$CopiedHash; Size=(Get-Item -LiteralPath $TargetFile).Length }
}

# Include the notices supplied with all linked MSYS2 dependencies. Copying
# only the file/libmagic COPYING text would omit notices for transitive DLLs.
$LicenseRoot = Join-Path $Msys2Location 'mingw64\share\licenses'
$RequiredFileLicense = Join-Path $LicenseRoot 'file\COPYING'
if (-not (Test-Path -LiteralPath $RequiredFileLicense -PathType Leaf)) {
    throw 'Missing upstream file/libmagic license.'
}
foreach ($Required in @('libsystre\LICENSE', 'libtre\LICENSE', 'gettext-runtime\intl\COPYING.LIB', 'libiconv\COPYING.LIB')) {
    if (-not (Test-Path -LiteralPath (Join-Path $LicenseRoot $Required) -PathType Leaf)) {
        throw "Missing dependency license: $Required"
    }
}
$LicenseTarget = Join-Path $StageRoot 'docs\third-party\libmagic548'
New-Item -ItemType Directory -Force -Path $LicenseTarget | Out-Null
Copy-Item -LiteralPath $LicenseRoot -Destination $LicenseTarget -Recurse -Force
Copy-Item -LiteralPath (Join-Path $Msys2Location 'PACKAGES.csv') -Destination $LicenseTarget -Force
& (Join-Path $PSScriptRoot 'stage-libmagic-sources.ps1') -PackageRoot $Msys2Location -Destination (Join-Path $LicenseTarget 'sources') -SevenZip $SevenZip
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\docs\LIBMAGIC-SOURCES.md') -Destination (Join-Path $LicenseTarget 'README.md') -Force

$Exe = Join-Path $Target 'file.exe'
$Magic = Join-Path $Target 'magic.mgc'
$SavedPath = $env:PATH
try {
    # Any overlooked runtime DLL must fail here instead of being loaded from
    # the development runner's global MSYS2 PATH.
    $env:PATH = "$Target;$env:windir\System32;$env:windir"
    $VersionOutput = (& $Exe --version 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0 -or $VersionOutput -notmatch '(?m)file(?:\.exe)?-5\.48\b') {
        throw "Staged libmagic --version failed: $VersionOutput"
    }
    $TextFixture = Join-Path $Target 'libmagic-smoke.txt'
    [IO.File]::WriteAllText($TextFixture, 'Libmagic staging validation' + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
    try {
        $TextOutput = (& $Exe -b -m $Magic $TextFixture 2>&1 | Out-String)
        if ($LASTEXITCODE -ne 0 -or $TextOutput -notmatch 'text') {
            throw "Staged libmagic text detection failed: $TextOutput"
        }
    } finally {
        Remove-Item -LiteralPath $TextFixture -Force -ErrorAction SilentlyContinue
    }
} finally {
    $env:PATH = $SavedPath
}

$Inventory | Export-Csv -LiteralPath (Join-Path $Target 'LIBMAGIC548-INVENTORY.csv') -NoTypeInformation -Encoding UTF8
Write-Host "Staged and verified file/libmagic 5.48 x64: $Target"
