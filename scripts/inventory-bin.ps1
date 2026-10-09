[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$StageRoot)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$StageRoot = (Resolve-Path -LiteralPath $StageRoot).Path
$BinRoot = Join-Path $StageRoot 'bin'
if (-not (Test-Path -LiteralPath $BinRoot -PathType Container)) { throw "Missing bin directory: $BinRoot" }

# Source classification only. "Legacy" must never be interpreted as "current".
$Overlay = @(
 'x86\7z.exe','x86\7z.dll','x64\7z.exe','x64\7z.dll',
 'upx.exe','MediaInfo.dll','Champollion.exe','pea.exe',
 'msgunfmt.exe','innounp.exe','TrIDDefs.TRD','sqlite3.exe',
 'x86\sqlite3.dll','x64\sqlite3.dll','x64\UnRAR.exe','x64\chdman.exe',
 'x86\Formats\Asar.32.dll','x64\Formats\Asar.64.dll',
 'x86\Formats\eDecoder.32.dll','x64\Formats\eDecoder.64.dll',
 'x86\Formats\Iso7z.32.dll','x64\Formats\Iso7z.64.dll',
 'x86\Formats\Py7z.32.dll','x64\Formats\Py7z.64.dll'
)
$Pinned = @{
 'acefile.exe' = 'compatible-exe-pinned: Python source 0.6.14 requires repackage'
 'lzip.exe' = 'compatible-exe-pinned: newer source, no official Windows executable'
 'x86\chdman.exe' = 'compatible-exe-pinned: x86 MAME no longer shipped'
 'x86\unrar.exe' = 'compatible-exe-pinned: x86 RARLab binary retained'
}

function Get-PeMachine([string]$Path) {
    $Stream = [IO.File]::OpenRead($Path)
    try {
        if ($Stream.Length -lt 64) { return '' }
        $H = New-Object byte[] 64
        if ($Stream.Read($H, 0, 64) -ne 64 -or $H[0] -ne 77 -or $H[1] -ne 90) { return '' }
        $Offset = [BitConverter]::ToInt32($H, 60)
        if ($Offset -lt 64 -or $Offset -gt ($Stream.Length - 6)) { return '' }
        $Stream.Position = $Offset
        $PE = New-Object byte[] 6
        if ($Stream.Read($PE, 0, 6) -ne 6 -or $PE[0] -ne 80 -or $PE[1] -ne 69 -or $PE[2] -ne 0 -or $PE[3] -ne 0) { return '' }
        switch ([BitConverter]::ToUInt16($PE, 4)) {
            332 { return 'x86' }
            34404 { return 'x64' }
            43620 { return 'ARM64' }
            default { return 'Other PE' }
        }
    } finally { $Stream.Dispose() }
}

$Files = @(Get-ChildItem -LiteralPath $BinRoot -Recurse -File | Sort-Object FullName)
if ($Files.Count -lt 50) { throw "Suspiciously few helper files ($($Files.Count)); refusing package" }
$Rows = @(
 foreach ($File in $Files) {
    $Path = $File.FullName.Substring($BinRoot.Length).TrimStart([char]'\', [char]'/')
    $Ext = $File.Extension.ToLowerInvariant()
    $Managed = ($Overlay -contains $Path) -or ($Path -like 'qpdf\*') -or
      ($Path -like 'Exeinfo\*') -or ($Path -like 'x86\vgmstream\*') -or
      ($Path -like 'x64\vgmstream\*')
    $Review = if ($Managed) { 'overlay-managed' }
      elseif ($Pinned.ContainsKey($Path.ToLowerInvariant())) { $Pinned[$Path.ToLowerInvariant()] }
      else { 'legacy-base: upstream review pending' }
    $FV = ''; $PV = ''; $Machine = ''
    if ($Ext -in @('.exe','.dll','.wcx','.ndll','.ocx','.sys')) {
      try {
        $Version = [Diagnostics.FileVersionInfo]::GetVersionInfo($File.FullName)
        $FV = [string]$Version.FileVersion
        $PV = [string]$Version.ProductVersion
        $Machine = Get-PeMachine $File.FullName
      } catch { Write-Warning ('Could not inspect {0}: {1}' -f $Path, $_.Exception.Message) }
    }
    [PSCustomObject]@{
      Path=$Path; Bytes=$File.Length; SHA256=(Get-FileHash -LiteralPath $File.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
      Extension=$Ext; PEMachine=$Machine; FileVersion=$FV; ProductVersion=$PV; ReviewStatus=$Review
    }
 }
)
$Rows | Export-Csv -LiteralPath (Join-Path $StageRoot 'BIN-INVENTORY.csv') -NoTypeInformation -Encoding UTF8

# Required helper files are checked separately from descriptive metadata.
$Required = @('x86\7z.exe','x64\7z.exe','x86\7z.dll','x64\7z.dll',
  'qpdf\bin\qpdf.exe','upx.exe','sqlite3.exe','x64\chdman.exe','x64\UnRAR.exe',
  'TrIDDefs.TRD','x86\vgmstream\vgmstream-cli.exe','x64\vgmstream\vgmstream-cli.exe')
$Missing = @($Required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $BinRoot $_) -PathType Leaf) })
if ($Missing.Count -gt 0) { throw "Missing required helpers: $($Missing -join ', ')" }

$OverlayCount = @($Rows | Where-Object { $_.ReviewStatus -eq 'overlay-managed' }).Count
$PinnedCount = @($Rows | Where-Object { $_.ReviewStatus -like 'compatible-exe-pinned:*' }).Count
$ExecCount = @($Rows | Where-Object { $_.Extension -eq '.exe' }).Count
$PECount = @($Rows | Where-Object { $_.PEMachine -ne '' }).Count
$MissingVersion = @($Rows | Where-Object { $_.PEMachine -ne '' -and $_.FileVersion -eq '' }).Count
$Summary = @(
 'Universal Extractor 2 bin inventory (generated from actual packaged binaries)',
 "Files: $($Rows.Count)"
 "Executables: $ExecCount"
 "Recognized PE binaries: $PECount"
 "PE binaries without FileVersion: $MissingVersion"
 "Fork overlay-managed entries: $OverlayCount"
 "Compatibility-pinned exceptions: $PinnedCount"
 "Legacy entries pending individual review: $($Rows.Count-$OverlayCount-$PinnedCount)"
 'File hashes and source/review status: BIN-INVENTORY.csv'
 'A legacy review label does not mean a helper is the latest available version.'
)
$Summary | Set-Content -LiteralPath (Join-Path $StageRoot 'BIN-INVENTORY-SUMMARY.txt') -Encoding UTF8
$Summary | ForEach-Object { Write-Host $_ }
