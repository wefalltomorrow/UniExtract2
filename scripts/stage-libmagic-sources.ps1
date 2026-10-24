[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PackageRoot,
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter(Mandatory = $true)][string]$SevenZip
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Packages = @(
    @{Name='file'; Version='5.48-1'; Binary='file'; SHA256='97f56f246ef830d5b3e1a6bd015b80c4158eca86030a53e0f86654e6827315e4'},
    @{Name='gettext'; Version='1.0-1'; Binary='gettext-runtime'; SHA256='cca0d0c8f60353faccc5ad40405240014e4a7ccc8b1c6ca9f4626aef3097d26e'},
    @{Name='libiconv'; Version='1.19-1'; Binary='libiconv'; SHA256='74428280c17094da5b702c29b2e1a0abae59556ea5dfdd65705cc8ccc1e000fb'},
    @{Name='libsystre'; Version='1.0.2-3'; Binary='libsystre'; SHA256='8c70a595f20ba799c226e298cbcb1ca347b1ab1537ce56dca4509e79caa8d90c'},
    @{Name='libtre'; Version='0.9.0-2'; Binary='libtre'; SHA256='57ee4f3b992e4ebe9b43fc8b5a0a66000ee40defc1089b727799330778344301'}
)
$Cache = Join-Path $PackageRoot 'sources'
New-Item -ItemType Directory -Force -Path $Cache, $Destination | Out-Null
$Records = @()
foreach ($Package in $Packages) {
    $Name = 'mingw-w64-' + $Package.Name + '-' + $Package.Version + '.src.tar.zst'
    $Url = 'https://repo.msys2.org/mingw/sources/' + $Name
    $Archive = Join-Path $Cache $Name
    if (-not (Test-Path -LiteralPath $Archive -PathType Leaf)) {
        & curl.exe --fail --location --retry 3 --connect-timeout 30 --max-time 180 --output $Archive $Url
        if ($LASTEXITCODE -ne 0) { throw "Source download failed: $Name" }
    }
    $Digest = (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($Digest -ne $Package.SHA256) { throw "Pinned source package SHA-256 mismatch: $Name" }
    $Extract = Join-Path $Cache ($Package.Name + '-' + $Package.Version)
    & $SevenZip x -y ('-o' + $Extract) $Archive | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Cannot decompress source: $Name" }
    & $SevenZip x -y ('-o' + $Extract) (Join-Path $Extract $Name.Substring(0, $Name.Length - 4)) | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Cannot unpack source: $Name" }
    $Recipe = Join-Path $Extract ('mingw-w64-' + $Package.Name + '\PKGBUILD')
    $RecipeHash = (Get-FileHash -LiteralPath $Recipe -Algorithm SHA256).Hash.ToLowerInvariant()
    $BuildInfo = Join-Path $PackageRoot ('unpacked\' + $Package.Binary + '-' + $Package.Version + '\.BUILDINFO')
    $Expected = [regex]::Match((Get-Content -LiteralPath $BuildInfo -Raw), '(?m)^pkgbuild_sha256sum = ([0-9a-f]{64})\r?$')
    if (-not $Expected.Success -or $RecipeHash -ne $Expected.Groups[1].Value) {
        throw "Source recipe does not match binary build metadata: $Name"
    }
    Copy-Item -LiteralPath $Archive -Destination $Destination -Force
    Copy-Item -LiteralPath $BuildInfo -Destination (Join-Path $Destination ($Package.Binary + '.BUILDINFO')) -Force
    $Records += [pscustomobject]@{Package=$Name;Url=$Url;SHA256=$Digest;PKGBUILD_SHA256=$RecipeHash}
}
$Records | Export-Csv -LiteralPath (Join-Path $Destination 'SOURCES.csv') -NoTypeInformation -Encoding UTF8
Write-Host 'Included five verified source packages; build recipes match binary metadata.'
