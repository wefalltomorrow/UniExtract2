[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$WorkRoot,
    [Parameter(Mandatory = $true)][string]$SevenZip
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not (Test-Path -LiteralPath $SevenZip -PathType Leaf)) { throw '7-Zip is required to unpack the pinned libmagic packages.' }
$SevenZip = (Resolve-Path -LiteralPath $SevenZip).Path
$Packages = [ordered]@{
    'file-5.48-1' = '844a8e6451f51aa9bfcbbdf92248b0e406891a51738ad2d8161835d7100d4f3f'
    'gettext-runtime-1.0-1' = 'be68d7f260633284b910c588c6d82ee304a81c8817a686d2cd9df83f872c27af'
    'libiconv-1.19-1' = '21e334d0911f25de75d3e18e0697648bcecfa9658256d600cad0827d719c2f35'
    'libsystre-1.0.2-3' = 'ea20a54127fe2a606ef0f2bef62b1abef77710840b661b832a933b4020bfe316'
    'libtre-0.9.0-2' = 'c4051508d063258e1e02dd29615edb7d73c5c5f582ae42795fdd92e7ddce506b'
}
$Cache = Join-Path $WorkRoot 'var\cache\pacman\pkg'
New-Item -ItemType Directory -Force -Path $Cache | Out-Null
$Records = @()
foreach ($Package in $Packages.Keys) {
    $Name = 'mingw-w64-x86_64-' + $Package + '-any.pkg.tar.zst'
    $Url = 'https://mirror.msys2.org/mingw/mingw64/' + $Name
    $Archive = Join-Path $Cache $Name
    if (-not (Test-Path -LiteralPath $Archive -PathType Leaf)) {
        & curl.exe --fail --location --retry 3 --connect-timeout 30 --max-time 180 --output $Archive $Url
        if ($LASTEXITCODE -ne 0) { throw "Download failed: $Name" }
    }
    $Digest = (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($Digest -ne $Packages[$Package]) { throw "Pinned package SHA-256 mismatch: $Name" }
    $Extract = Join-Path $WorkRoot ('unpacked\' + $Package)
    New-Item -ItemType Directory -Force -Path $Extract | Out-Null
    & $SevenZip x -y ('-o' + $Extract) $Archive | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Cannot decompress $Name" }
    $Tar = Join-Path $Extract ($Name.Substring(0, $Name.Length - 4))
    & $SevenZip x -y ('-o' + $Extract) $Tar | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Cannot unpack $Name" }
    $Prefix = Join-Path $Extract 'mingw64'
    # Check the seven binary/database audit hashes before execution in staging.
    foreach ($Subdir in @('bin', 'share\misc', 'share\licenses')) {
        $Source = Join-Path $Prefix $Subdir
        if (Test-Path -LiteralPath $Source -PathType Container) {
            $Destination = Join-Path (Join-Path $WorkRoot 'mingw64') $Subdir
            New-Item -ItemType Directory -Force -Path $Destination | Out-Null
            Get-ChildItem -LiteralPath $Source | Copy-Item -Destination $Destination -Recurse -Force
        }
    }
    $Records += [pscustomobject]@{Package=$Name;Url=$Url;SHA256=$Digest}
}
$Records | Export-Csv -LiteralPath (Join-Path $WorkRoot 'PACKAGES.csv') -NoTypeInformation -Encoding UTF8
(Resolve-Path -LiteralPath $WorkRoot).Path
