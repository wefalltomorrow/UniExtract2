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
        [string]$FileName
    )

    $Destination = Join-Path $WorkRoot $FileName
    Write-Host "Downloading $Url"
    Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
    if (-not (Test-Path -LiteralPath $Destination) -or (Get-Item -LiteralPath $Destination).Length -lt 1) {
        throw "Download failed or produced an empty file: $Url"
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
$SevenX86 = Get-Download 'https://www.7-zip.org/a/7z2604.exe' '7z2604-x86.exe'
$SevenX64 = Get-Download 'https://www.7-zip.org/a/7z2604-x64.exe' '7z2604-x64.exe'
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
$QpdfZip = Get-Download 'https://github.com/qpdf/qpdf/releases/download/v12.4.2/qpdf-12.4.2-mingw32.zip' 'qpdf-12.4.2-mingw32.zip'
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
$UpxZip = Get-Download 'https://github.com/upx/upx/releases/download/v5.2.1/upx-5.2.1-win32.zip' 'upx-5.2.1-win32.zip'
$UpxExtract = Join-Path $WorkRoot 'upx'
Expand-ZipPackage $UpxZip $UpxExtract
Copy-RequiredFile (Find-RequiredFile $UpxExtract 'upx.exe') (Join-Path $BinRoot 'upx.exe')
Assert-CommandContains (Join-Path $BinRoot 'upx.exe') @('--version') '5.2.1' 'UPX'
Add-RefreshLog 'UPX: 5.2.1'

# MediaInfoLib 26.10 (x86 DLL; UniExtract itself is compiled as x86)
$MediaInfoZip = Get-Download 'https://mediaarea.net/download/binary/libmediainfo0/26.10/MediaInfo_DLL_26.10_Windows_i386_WithoutInstaller.zip' 'MediaInfo_DLL_26.10_Windows_i386.zip'
$MediaInfoExtract = Join-Path $WorkRoot 'mediainfo'
Expand-ZipPackage $MediaInfoZip $MediaInfoExtract
$MediaInfoDll = Find-RequiredFile $MediaInfoExtract 'MediaInfo.dll'
Copy-RequiredFile $MediaInfoDll (Join-Path $BinRoot 'MediaInfo.dll')
Assert-FileVersionContains (Join-Path $BinRoot 'MediaInfo.dll') '26.10' 'MediaInfo.dll'
Add-RefreshLog 'MediaInfoLib: 26.10 (x86)'

# Exeinfo PE 0.1.0.0.
# Keep the complete upstream package isolated so its own signatures/dependencies do not
# overwrite UniExtract's root-level PEiD support files.
$ExeinfoZip = Get-Download 'https://github.com/ExeinfoASL/Exeinfo/releases/download/v1.0.0/exeinfope.zip' 'exeinfope-0.1.0.0.zip'
$ExeinfoExtract = Join-Path $WorkRoot 'exeinfo'
Expand-ZipPackage $ExeinfoZip $ExeinfoExtract
$ExeinfoExe = Find-RequiredFile $ExeinfoExtract 'exeinfope.exe'
$ExeinfoPackageRoot = Split-Path -Parent $ExeinfoExe
$ExeinfoDest = Join-Path $BinRoot 'Exeinfo'
Remove-Item -LiteralPath $ExeinfoDest -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $ExeinfoDest -Force | Out-Null
Copy-Item -Path (Join-Path $ExeinfoPackageRoot '*') -Destination $ExeinfoDest -Recurse -Force
Assert-FileVersionContains (Join-Path $ExeinfoDest 'exeinfope.exe') '0.1.0.0' 'Exeinfo PE'
Add-RefreshLog 'Exeinfo PE: 0.1.0.0 (isolated package)'

# PEA 1.33 from the current PeaZip portable release.
$PeaZip = Get-Download 'https://github.com/peazip/PeaZip/releases/download/11.3.0/peazip_portable-11.3.0.WINDOWS.zip' 'peazip_portable-11.3.0.WINDOWS.zip'
$PeaExtract = Join-Path $WorkRoot 'peazip'
Expand-ZipPackage $PeaZip $PeaExtract
Copy-RequiredFile (Find-RequiredFile $PeaExtract 'pea.exe') (Join-Path $BinRoot 'pea.exe')
Add-RefreshLog 'PEA: 1.33 (from PeaZip 11.3.0)'

# Inno Setup Unpacker 2.71.1.
# The upstream URL is rolling, so verify the downloaded executable before accepting it.
$InnoZip = Get-Download 'https://www.rathlev-home.de/tools/download/innounp-2.zip' 'innounp-2.zip'
$InnoExtract = Join-Path $WorkRoot 'innounp'
Expand-ZipPackage $InnoZip $InnoExtract
$InnoExe = Find-RequiredFile $InnoExtract 'innounp.exe'
Copy-RequiredFile $InnoExe (Join-Path $BinRoot 'innounp.exe')
Assert-CommandContains (Join-Path $BinRoot 'innounp.exe') @() '2.71.1' 'innounp'
Add-RefreshLog 'innounp: 2.71.1'

# TrID definitions snapshot: 08/10/2026, 22425 definitions.
# The upstream URL is rolling. Validate the definition count so a later upstream update
# fails loudly instead of silently changing a historical release build.
$TridDefsZip = Get-Download 'https://mark0.net/download/triddefs.zip' 'triddefs.zip'
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
$WinRarX64 = Get-Download 'https://www.rarlab.com/rar/winrar-x64-723.exe' 'winrar-x64-723.exe'
$WinRarExtract = Join-Path $WorkRoot 'winrar-x64'
Expand-With7Zip $WinRarX64 $WinRarExtract
Copy-RequiredFile (Find-RequiredFile $WinRarExtract 'UnRAR.exe') (Join-Path $BinRoot 'x64\UnRAR.exe')
Assert-CommandContains (Join-Path $BinRoot 'x64\UnRAR.exe') @() '7.23' 'UnRAR x64'
Add-RefreshLog 'UnRAR: 7.23 x64 (legacy x86 helper retained)'

# CHDMan 0.289 x64 from the current MAME release.
# The historical x86 helper remains for old 32-bit systems because modern MAME no longer
# publishes an x86 Windows build.
$MameX64 = Get-Download 'https://github.com/mamedev/mame/releases/download/mame0289/mame0289b_x64.exe' 'mame0289b_x64.exe'
$MameExtract = Join-Path $WorkRoot 'mame-x64'
Expand-With7Zip $MameX64 $MameExtract
$Chdman = Find-RequiredFile $MameExtract 'chdman.exe'
Copy-RequiredFile $Chdman (Join-Path $BinRoot 'x64\chdman.exe')
Assert-FileVersionContains (Join-Path $BinRoot 'x64\chdman.exe') '0.289' 'chdman x64'
Add-RefreshLog 'CHDMan: 0.289 x64 (legacy x86 helper retained)'

# SQLite 3.53.4.
# Official releases provide current x86/x64 DLLs but only an x64 command-line shell.
# Build the tiny x86 shell from the official amalgamation so UniExtract does not lose
# 32-bit Windows compatibility.
$SqliteAmalgamation = Get-Download 'https://www.sqlite.org/2026/sqlite-amalgamation-3530400.zip' 'sqlite-amalgamation-3530400.zip'
$SqliteDllX86 = Get-Download 'https://www.sqlite.org/2026/sqlite-dll-win-x86-3530400.zip' 'sqlite-dll-win-x86-3530400.zip'
$SqliteDllX64 = Get-Download 'https://www.sqlite.org/2026/sqlite-dll-win-x64-3530400.zip' 'sqlite-dll-win-x64-3530400.zip'
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
