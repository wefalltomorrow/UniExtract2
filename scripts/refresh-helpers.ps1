[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$StageRoot,

    [Parameter(Mandatory = $true)]
    [string]$WorkRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$StageRoot = (Resolve-Path -LiteralPath $StageRoot).Path
$BinRoot = Join-Path $StageRoot 'bin'

Remove-Item -LiteralPath $WorkRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $WorkRoot -Force | Out-Null

$Baseline7z = Join-Path $BinRoot 'x64\7z.exe'
if (-not (Test-Path -LiteralPath $Baseline7z)) {
    $Baseline7z = Join-Path $BinRoot 'x86\7z.exe'
}
if (-not (Test-Path -LiteralPath $Baseline7z)) {
    throw 'A baseline 7-Zip executable is required before helper refresh.'
}

$RefreshLog = New-Object System.Collections.Generic.List[string]

function Add-RefreshLog {
    param([string]$Text)
    $RefreshLog.Add($Text)
    Write-Host $Text
}

function Get-Download {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [string]$FileName,

        [string]$ExpectedSha256 = '',

        [switch]$AllowInvalidCertificate
    )

    $Destination = Join-Path $WorkRoot $FileName
    Write-Host "Downloading $Url"

    if ($AllowInvalidCertificate) {
        # TC4Shell's current certificate chain is rejected by Windows Server's
        # PowerShell 5.1 TLS stack. This bootstrap path is allowed only when the
        # downloaded archive is subsequently content/version validated. Once the
        # current hashes are captured, release builds pin them below as well.
        & curl.exe -L --fail --retry 3 --connect-timeout 30 --insecure --output $Destination $Url
        if ($LASTEXITCODE -ne 0) {
            throw "curl failed to download $Url (exit code $LASTEXITCODE)."
        }
    } else {
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
    }

    if (-not (Test-Path -LiteralPath $Destination) -or (Get-Item -LiteralPath $Destination).Length -lt 1) {
        throw "Download failed or produced an empty file: $Url"
    }

    $ActualSha256 = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Host "SHA-256 $FileName = $ActualSha256"
    if ($ExpectedSha256 -and $ActualSha256 -ne $ExpectedSha256.ToLowerInvariant()) {
        throw "SHA-256 mismatch for $FileName. Expected $ExpectedSha256, got $ActualSha256."
    }

    return $Destination
}

function Expand-ZipPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Archive,

        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    Remove-Item -LiteralPath $Destination -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Expand-Archive -LiteralPath $Archive -DestinationPath $Destination -Force
}

function Expand-With7Zip {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Archive,

        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    Remove-Item -LiteralPath $Destination -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    & $Baseline7z x -y "-o$Destination" $Archive | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "7-Zip failed to extract $Archive (exit code $LASTEXITCODE)."
    }
}

function Find-RequiredFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $Matches = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $Name -ErrorAction SilentlyContinue)
    if ($Matches.Count -lt 1) {
        throw "Could not find $Name under $Root"
    }

    return ($Matches | Sort-Object { $_.FullName.Length } | Select-Object -First 1).FullName
}

function Copy-RequiredFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    $Parent = Split-Path -Parent $Destination
    if ($Parent) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    if (-not (Test-Path -LiteralPath $Destination)) {
        throw "Failed to copy $Source to $Destination"
    }
}

function Assert-CommandContains {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Exe,

        [string[]]$Arguments = @(),

        [Parameter(Mandatory = $true)]
        [string]$Expected,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $Output = (& $Exe @Arguments 2>&1 | Out-String)
    if ($Output -notmatch [regex]::Escape($Expected)) {
        throw ($Label + " validation failed. Expected '" + $Expected + "' in output." + [Environment]::NewLine + $Output)
    }
}

function Assert-FileVersionContains {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Expected,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $Version = (Get-Item -LiteralPath $Path).VersionInfo.FileVersion
    if ([string]::IsNullOrWhiteSpace($Version) -or $Version -notlike "*$Expected*") {
        throw "$Label version validation failed. Expected '$Expected', got '$Version'."
    }
}

Write-Host ''
Write-Host 'Refreshing maintained helper binaries from pinned upstream releases...'

# 7-Zip 26.04 (x86 + x64)
$SevenX86 = Get-Download 'https://www.7-zip.org/a/7z2604.exe' '7z2604-x86.exe' '39bf65045153fc26c42fa9fe47afd8cd1b11671c7f11d031e738c9a13960c009'
$SevenX64 = Get-Download 'https://www.7-zip.org/a/7z2604-x64.exe' '7z2604-x64.exe' 'd54bf805f9f3704d1e8db2fa3498ae7ef2df0312b40b558e7c71c734430a665d'
$SevenX86Dir = Join-Path $WorkRoot '7zip-x86'
$SevenX64Dir = Join-Path $WorkRoot '7zip-x64'
Expand-With7Zip $SevenX86 $SevenX86Dir
Expand-With7Zip $SevenX64 $SevenX64Dir
Copy-RequiredFile (Find-RequiredFile $SevenX86Dir '7z.exe') (Join-Path $BinRoot 'x86\7z.exe')
Copy-RequiredFile (Find-RequiredFile $SevenX86Dir '7z.dll') (Join-Path $BinRoot 'x86\7z.dll')
Copy-RequiredFile (Find-RequiredFile $SevenX64Dir '7z.exe') (Join-Path $BinRoot 'x64\7z.exe')
Copy-RequiredFile (Find-RequiredFile $SevenX64Dir '7z.dll') (Join-Path $BinRoot 'x64\7z.dll')
Assert-CommandContains (Join-Path $BinRoot 'x86\7z.exe') @() '7-Zip 26.04' '7-Zip x86'
Assert-CommandContains (Join-Path $BinRoot 'x64\7z.exe') @() '7-Zip 26.04' '7-Zip x64'
Add-RefreshLog '7-Zip: 26.04 (x86/x64)'

# qpdf 12.4.2 (32-bit MinGW build keeps compatibility with 32-bit Windows)
$QpdfZip = Get-Download 'https://github.com/qpdf/qpdf/releases/download/v12.4.2/qpdf-12.4.2-mingw32.zip' 'qpdf-12.4.2-mingw32.zip' '6af53218eec293debb21e8036a95dfda0d690eef09f2f9023a22db0e3ad061fa'
$QpdfExtract = Join-Path $WorkRoot 'qpdf'
Expand-ZipPackage $QpdfZip $QpdfExtract
$QpdfExe = Find-RequiredFile $QpdfExtract 'qpdf.exe'
$QpdfBinDir = Split-Path -Parent $QpdfExe
$QpdfPackageRoot = Split-Path -Parent $QpdfBinDir
$QpdfDest = Join-Path $BinRoot 'qpdf'
Remove-Item -LiteralPath $QpdfDest -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $QpdfDest -Force | Out-Null
Copy-Item -Path (Join-Path $QpdfPackageRoot '*') -Destination $QpdfDest -Recurse -Force
Assert-CommandContains (Join-Path $QpdfDest 'bin\qpdf.exe') @('--version') '12.4.2' 'qpdf'
Add-RefreshLog 'qpdf: 12.4.2 (MinGW x86)'

# UPX 5.2.1 (32-bit binary works on x86 and x64 Windows)
$UpxZip = Get-Download 'https://github.com/upx/upx/releases/download/v5.2.1/upx-5.2.1-win32.zip' 'upx-5.2.1-win32.zip' '4a06f247b0184976c1e7fd5af9293977cdb1bf4ba9416ae58e3560bd62d871ff'
$UpxExtract = Join-Path $WorkRoot 'upx'
Expand-ZipPackage $UpxZip $UpxExtract
Copy-RequiredFile (Find-RequiredFile $UpxExtract 'upx.exe') (Join-Path $BinRoot 'upx.exe')
Assert-CommandContains (Join-Path $BinRoot 'upx.exe') @('--version') '5.2.1' 'UPX'
Add-RefreshLog 'UPX: 5.2.1'

# TC4Shell 7-Zip format plugins. These are small architecture-paired DLL packages.
# Keep the upstream package layout out of the release and copy only the format DLLs.
$AsarZip = Get-Download 'https://www.tc4shell.com/binary/Asar.zip' 'Asar7z-1.5.zip' -AllowInvalidCertificate
$AsarExtract = Join-Path $WorkRoot 'asar7z'
Expand-ZipPackage $AsarZip $AsarExtract
$Asar32 = Find-RequiredFile $AsarExtract 'Asar.32.dll'
$Asar64 = Find-RequiredFile $AsarExtract 'Asar.64.dll'
Copy-RequiredFile $Asar32 (Join-Path $BinRoot 'x86\Formats\Asar.32.dll')
Copy-RequiredFile $Asar64 (Join-Path $BinRoot 'x64\Formats\Asar.64.dll')
Assert-FileVersionContains (Join-Path $BinRoot 'x86\Formats\Asar.32.dll') '1.5' 'Asar7z x86'
Assert-FileVersionContains (Join-Path $BinRoot 'x64\Formats\Asar.64.dll') '1.5' 'Asar7z x64'
Add-RefreshLog 'Asar7z: 1.5 (x86/x64)'

$EDecoderZip = Get-Download 'https://www.tc4shell.com/binary/eDecoder.zip' 'eDecoder-1.20.8.zip' 'cbd6c0357df0d419a6ac4bcf89dcc972a8ccfb8d5ba0cdd2b876ad21ef4217ab' -AllowInvalidCertificate
$EDecoderExtract = Join-Path $WorkRoot 'edecoder'
Expand-ZipPackage $EDecoderZip $EDecoderExtract
$EDecoder32 = Find-RequiredFile $EDecoderExtract 'eDecoder.32.dll'
$EDecoder64 = Find-RequiredFile $EDecoderExtract 'eDecoder.64.dll'
Copy-RequiredFile $EDecoder32 (Join-Path $BinRoot 'x86\Formats\eDecoder.32.dll')
Copy-RequiredFile $EDecoder64 (Join-Path $BinRoot 'x64\Formats\eDecoder.64.dll')
Assert-FileVersionContains (Join-Path $BinRoot 'x86\Formats\eDecoder.32.dll') '1.20.8' 'eDecoder x86'
Assert-FileVersionContains (Join-Path $BinRoot 'x64\Formats\eDecoder.64.dll') '1.20.8' 'eDecoder x64'
Add-RefreshLog 'eDecoder: 1.20.8 (x86/x64)'

$Iso7zZip = Get-Download 'https://www.tc4shell.com/binary/Iso7z.zip' 'Iso7z-1.8.7.zip' '4b41b567025cf884198d7f810994d37e4024b6d538871b1f93283bb1a67ccafd' -AllowInvalidCertificate
$Iso7zExtract = Join-Path $WorkRoot 'iso7z'
Expand-ZipPackage $Iso7zZip $Iso7zExtract
$Iso7z32 = Find-RequiredFile $Iso7zExtract 'Iso7z.32.dll'
$Iso7z64 = Find-RequiredFile $Iso7zExtract 'Iso7z.64.dll'
Copy-RequiredFile $Iso7z32 (Join-Path $BinRoot 'x86\Formats\Iso7z.32.dll')
Copy-RequiredFile $Iso7z64 (Join-Path $BinRoot 'x64\Formats\Iso7z.64.dll')
Assert-FileVersionContains (Join-Path $BinRoot 'x86\Formats\Iso7z.32.dll') '1.8.7' 'Iso7z x86'
Assert-FileVersionContains (Join-Path $BinRoot 'x64\Formats\Iso7z.64.dll') '1.8.7' 'Iso7z x64'
Add-RefreshLog 'Iso7z: 1.8.7 (x86/x64)'

$Py7zZip = Get-Download 'https://www.tc4shell.com/binary/Py7z.zip' 'Py7z-1.2.1.zip' '46852cc664be105c62d619c7c9d9fe28e34cb1e85557b8f91a8322ca7e1ff29d' -AllowInvalidCertificate
$Py7zExtract = Join-Path $WorkRoot 'py7z'
Expand-ZipPackage $Py7zZip $Py7zExtract
$Py7z32 = Find-RequiredFile $Py7zExtract 'Py7z.32.dll'
$Py7z64 = Find-RequiredFile $Py7zExtract 'Py7z.64.dll'
Copy-RequiredFile $Py7z32 (Join-Path $BinRoot 'x86\Formats\Py7z.32.dll')
Copy-RequiredFile $Py7z64 (Join-Path $BinRoot 'x64\Formats\Py7z.64.dll')
Assert-FileVersionContains (Join-Path $BinRoot 'x86\Formats\Py7z.32.dll') '1.2.1' 'Py7z x86'
Assert-FileVersionContains (Join-Path $BinRoot 'x64\Formats\Py7z.64.dll') '1.2.1' 'Py7z x64'
Add-RefreshLog 'Py7z: 1.2.1 (x86/x64)'

# MediaInfoLib 26.10 (x86 DLL; UniExtract itself is compiled as x86)
$MediaInfoZip = Get-Download 'https://mediaarea.net/download/binary/libmediainfo0/26.10/MediaInfo_DLL_26.10_Windows_i386_WithoutInstaller.zip' 'MediaInfo_DLL_26.10_Windows_i386.zip' '6507e1ca54a1f96eb3afbf80c8de9f0c477f32fc614c259343568b622f192f81'
$MediaInfoExtract = Join-Path $WorkRoot 'mediainfo'
Expand-ZipPackage $MediaInfoZip $MediaInfoExtract
$MediaInfoDll = Find-RequiredFile $MediaInfoExtract 'MediaInfo.dll'
Copy-RequiredFile $MediaInfoDll (Join-Path $BinRoot 'MediaInfo.dll')
Assert-FileVersionContains (Join-Path $BinRoot 'MediaInfo.dll') '26.10' 'MediaInfo.dll'
Add-RefreshLog 'MediaInfoLib: 26.10 (x86)'

# Exeinfo PE 0.1.0.0.
# Keep the complete upstream package isolated so its own signatures/dependencies do not
# overwrite UniExtract's root-level PEiD support files.
$ExeinfoZip = Get-Download 'https://github.com/ExeinfoASL/Exeinfo/releases/download/v1.0.0/exeinfope.zip' 'exeinfope-0.1.0.0.zip' '26cbdf8ff9e172018668c71c6884294a1a9619c48a64148b11db385779b13194'
$ExeinfoExtract = Join-Path $WorkRoot 'exeinfo'
Expand-ZipPackage $ExeinfoZip $ExeinfoExtract
$ExeinfoExe = Find-RequiredFile $ExeinfoExtract 'exeinfope.exe'
$ExeinfoPackageRoot = Split-Path -Parent $ExeinfoExe
$ExeinfoDest = Join-Path $BinRoot 'Exeinfo'
Remove-Item -LiteralPath $ExeinfoDest -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $ExeinfoDest -Force | Out-Null
Copy-Item -Path (Join-Path $ExeinfoPackageRoot '*') -Destination $ExeinfoDest -Recurse -Force
Assert-FileVersionContains (Join-Path $ExeinfoDest 'exeinfope.exe') '0.1.0.0' 'Exeinfo PE'

# Remove the old flat Exeinfo copy inherited from the gvp helper base. The current
# source runs the isolated package above so these would only be stale duplicates.
foreach ($LegacyExeinfoFile in @('exeinfope.exe', 'exeinfopeRUN.cfg', 'Ext_Detector.dll')) {
    Remove-Item -LiteralPath (Join-Path $BinRoot $LegacyExeinfoFile) -Force -ErrorAction SilentlyContinue
}
Add-RefreshLog 'Exeinfo PE: 0.1.0.0 (isolated package; legacy flat copy removed)'

# Champollion 1.3.2 Papyrus decompiler.
$ChampollionZip = Get-Download 'https://github.com/Orvid/Champollion/releases/download/v1.3.2/Champollion.v1.3.2.zip' 'Champollion.v1.3.2.zip' 'ea53054276ac8006ccd3b323286bfbc6e34a454fa419d08da9bd440cbd31b383'
$ChampollionExtract = Join-Path $WorkRoot 'champollion'
Expand-ZipPackage $ChampollionZip $ChampollionExtract
$ChampollionExe = Find-RequiredFile $ChampollionExtract 'Champollion.exe'
Copy-RequiredFile $ChampollionExe (Join-Path $BinRoot 'Champollion.exe')
if ((Get-Item -LiteralPath (Join-Path $BinRoot 'Champollion.exe')).Length -lt 1) {
    throw 'Champollion validation failed: copied executable is empty.'
}
Add-RefreshLog 'Champollion: 1.3.2'

# PEA 1.33 from the current PeaZip portable release.
$PeaZip = Get-Download 'https://github.com/peazip/PeaZip/releases/download/11.3.0/peazip_portable-11.3.0.WINDOWS.zip' 'peazip_portable-11.3.0.WINDOWS.zip' '76ab0961b184e60f3534e62ce91aaf25bcb7cd409a4a7680a33d22c77a10f9de'
$PeaExtract = Join-Path $WorkRoot 'peazip'
Expand-ZipPackage $PeaZip $PeaExtract
Copy-RequiredFile (Find-RequiredFile $PeaExtract 'pea.exe') (Join-Path $BinRoot 'pea.exe')
Add-RefreshLog 'PEA: 1.33 (from PeaZip 11.3.0)'

# GNU gettext 1.0. Use the static x86 package so msgunfmt.exe remains a single,
# dependency-free helper on both 32-bit and 64-bit Windows.
$GettextZip = Get-Download 'https://github.com/mlocati/gettext-iconv-windows/releases/download/v1.0-v1.19/gettext1.0-iconv1.19-static-32.zip' 'gettext1.0-iconv1.19-static-32.zip' '18df5c0a47745f0b5ea9f622e0d2dfd09995d49076d3d18dcee31510bc4b90d3'
$GettextExtract = Join-Path $WorkRoot 'gettext'
Expand-ZipPackage $GettextZip $GettextExtract
Copy-RequiredFile (Find-RequiredFile $GettextExtract 'msgunfmt.exe') (Join-Path $BinRoot 'msgunfmt.exe')
Assert-CommandContains (Join-Path $BinRoot 'msgunfmt.exe') @('--version') '(GNU gettext-tools) 1.0' 'msgunfmt'
Add-RefreshLog 'GNU gettext msgunfmt: 1.0 (static x86)'

# Inno Setup Unpacker 2.71.1.
# The upstream URL is rolling, so verify the downloaded executable before accepting it.
$InnoZip = Get-Download 'https://raw.githubusercontent.com/jrathlev/InnoUnpacker-Windows-GUI/refs/heads/master/innounp-2/bin/innounp-2.zip' 'innounp-2.zip' 'f2f037fdbc63de31248efae9ccb294398d160dc0cbad5f36d14c2f159e17bbf5'
$InnoExtract = Join-Path $WorkRoot 'innounp'
Expand-ZipPackage $InnoZip $InnoExtract
$InnoExe = Find-RequiredFile $InnoExtract 'innounp.exe'
Copy-RequiredFile $InnoExe (Join-Path $BinRoot 'innounp.exe')
Assert-CommandContains (Join-Path $BinRoot 'innounp.exe') @() '2.71.1' 'innounp'
Add-RefreshLog 'innounp: 2.71.1'

# TrID definitions snapshot: 08/10/2026, 22425 definitions.
# The upstream URL is rolling. Validate the definition count so a later upstream update
# fails loudly instead of silently changing a historical release build.
$TridDefsZip = Get-Download 'https://mark0.net/download/triddefs.zip' 'triddefs.zip' '782f6910641942c736c8e33ec7c197dedfe4d1df59d5970bc97b97ebbaf65788'
$TridDefsExtract = Join-Path $WorkRoot 'triddefs'
Expand-ZipPackage $TridDefsZip $TridDefsExtract
Copy-RequiredFile (Find-RequiredFile $TridDefsExtract 'TrIDDefs.TRD') (Join-Path $BinRoot 'TrIDDefs.TRD')
$TridProbe = Join-Path $WorkRoot 'trid-probe.bin'
Set-Content -LiteralPath $TridProbe -Value 'UniExtract helper refresh probe' -Encoding ASCII
$TridOutput = (& (Join-Path $BinRoot 'trid.exe') $TridProbe 2>&1 | Out-String)
if ($TridOutput -notmatch 'Definitions found:\s*22425') {
    throw ('TrID definitions validation failed. Expected 22425 definitions from the 08/10/2026 snapshot.' + [Environment]::NewLine + $TridOutput)
}
Add-RefreshLog 'TrID definitions: 08/10/2026 (22425 definitions)'

# UnRAR 7.23 x64. RARLAB no longer publishes a matching current Win32 UnRAR binary,
# so retain the compatibility x86 copy from the helper base and refresh the x64 path.
$WinRarX64 = Get-Download 'https://www.rarlab.com/rar/winrar-x64-723.exe' 'winrar-x64-723.exe' '8ff0daf3ed564cc743c0e23ff2e253997ffc74460f9673f0b6dd037b2db4ce7b'
$WinRarExtract = Join-Path $WorkRoot 'winrar-x64'
Expand-With7Zip $WinRarX64 $WinRarExtract
Copy-RequiredFile (Find-RequiredFile $WinRarExtract 'UnRAR.exe') (Join-Path $BinRoot 'x64\UnRAR.exe')
Assert-CommandContains (Join-Path $BinRoot 'x64\UnRAR.exe') @() '7.23' 'UnRAR x64'
Add-RefreshLog 'UnRAR: 7.23 x64 (legacy x86 helper retained)'

# CHDMan 0.289 x64 from the current MAME release.
# The historical x86 helper remains for old 32-bit systems because modern MAME no longer
# publishes an x86 Windows build.
$MameX64 = Get-Download 'https://github.com/mamedev/mame/releases/download/mame0289/mame0289b_x64.exe' 'mame0289b_x64.exe' 'a1aa7912168c9d1b05e611906bc21b8b9be3935822aead36d12a1da363150b7d'
$MameExtract = Join-Path $WorkRoot 'mame-x64'
Expand-With7Zip $MameX64 $MameExtract
$Chdman = Find-RequiredFile $MameExtract 'chdman.exe'
Copy-RequiredFile $Chdman (Join-Path $BinRoot 'x64\chdman.exe')
Assert-CommandContains (Join-Path $BinRoot 'x64\chdman.exe') @('-help') '0.289' 'chdman x64'
Add-RefreshLog 'CHDMan: 0.289 x64 (legacy x86 helper retained)'

# SQLite 3.53.4.
# Official releases provide current x86/x64 DLLs but only an x64 command-line shell.
# Build the tiny x86 shell from the official amalgamation so UniExtract does not lose
# 32-bit Windows compatibility.
$SqliteAmalgamation = Get-Download 'https://www.sqlite.org/2026/sqlite-amalgamation-3530400.zip' 'sqlite-amalgamation-3530400.zip' '1e71ddf93849c6a6ecf58b827c0692073d2dd7ee40196158068f7b29f422e87d'
$SqliteDllX86 = Get-Download 'https://www.sqlite.org/2026/sqlite-dll-win-x86-3530400.zip' 'sqlite-dll-win-x86-3530400.zip' '607673153c6d15f0465761a1a86413049d6ba5c897857da2dab24282faad0224'
$SqliteDllX64 = Get-Download 'https://www.sqlite.org/2026/sqlite-dll-win-x64-3530400.zip' 'sqlite-dll-win-x64-3530400.zip' '8b959b7eff4a81f6a62fc3468f9273e5cfe78d4a927e62215aed231b654fb104'
$SqliteSrc = Join-Path $WorkRoot 'sqlite-src'
$SqliteX86 = Join-Path $WorkRoot 'sqlite-dll-x86'
$SqliteX64 = Join-Path $WorkRoot 'sqlite-dll-x64'
Expand-ZipPackage $SqliteAmalgamation $SqliteSrc
Expand-ZipPackage $SqliteDllX86 $SqliteX86
Expand-ZipPackage $SqliteDllX64 $SqliteX64

$ShellC = Find-RequiredFile $SqliteSrc 'shell.c'
$SqliteC = Find-RequiredFile $SqliteSrc 'sqlite3.c'
$SqliteBuild = Join-Path $WorkRoot 'sqlite-build'
New-Item -ItemType Directory -Path $SqliteBuild -Force | Out-Null
$SqliteExe = Join-Path $SqliteBuild 'sqlite3.exe'

$ProgramFilesX86 = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)
$VsWhere = Join-Path $ProgramFilesX86 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $VsWhere)) {
    throw 'vswhere.exe was not found; cannot build the current x86 SQLite shell.'
}
$VsInstall = (& $VsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($VsInstall)) {
    throw 'Visual C++ build tools were not found; cannot build the current x86 SQLite shell.'
}
$VcVars = Join-Path $VsInstall 'VC\Auxiliary\Build\vcvars32.bat'
if (-not (Test-Path -LiteralPath $VcVars)) {
    throw "vcvars32.bat was not found at $VcVars"
}

$SqliteSourceDir = Split-Path -Parent $SqliteC
$CompileCommand = 'call "' + $VcVars + '" >nul && cl /nologo /O2 /DSQLITE_THREADSAFE=1 /DSQLITE_ENABLE_COLUMN_METADATA /I"' + $SqliteSourceDir + '" /Fe:"' + $SqliteExe + '" "' + $ShellC + '" "' + $SqliteC + '"'
& cmd.exe /d /c $CompileCommand
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $SqliteExe)) {
    throw "Failed to build SQLite 3.53.4 x86 shell (exit code $LASTEXITCODE)."
}

Copy-RequiredFile $SqliteExe (Join-Path $BinRoot 'sqlite3.exe')
Copy-RequiredFile (Find-RequiredFile $SqliteX86 'sqlite3.dll') (Join-Path $BinRoot 'x86\sqlite3.dll')
Copy-RequiredFile (Find-RequiredFile $SqliteX64 'sqlite3.dll') (Join-Path $BinRoot 'x64\sqlite3.dll')
Assert-CommandContains (Join-Path $BinRoot 'sqlite3.exe') @('--version') '3.53.4' 'SQLite shell'
Add-RefreshLog 'SQLite: 3.53.4 (x86 shell + x86/x64 DLLs)'

$RefreshLogPath = Join-Path $StageRoot 'HELPER-REFRESH.txt'
@(
    'Universal Extractor 2 maintained helper overlay',
    'Generated by scripts\refresh-helpers.ps1',
    '',
    $RefreshLog
) | Set-Content -LiteralPath $RefreshLogPath -Encoding UTF8

Write-Host ''
Write-Host 'Maintained helper refresh complete:'
$RefreshLog | ForEach-Object { Write-Host " - $_" }
