[CmdletBinding()]
param([string]$DestinationRoot)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$RepoRoot = Split-Path -Parent $PSScriptRoot
$PinnedCommit = '716ebe500a4b69839bd5383baa97d57ba7f21335'
if (-not $DestinationRoot) { $DestinationRoot = Join-Path $RepoRoot '.build\biolib-validation' }
$DestinationRoot = [IO.Path]::GetFullPath($DestinationRoot)
$Work = Join-Path $DestinationRoot 'source'
$Output = Join-Path $DestinationRoot 'compiled'
$Bundle = Join-Path $DestinationRoot 'bundle'
New-Item -ItemType Directory -Force -Path $DestinationRoot,$Work,$Output,$Bundle | Out-Null

$Archive = Join-Path $DestinationRoot 'Bio.cs.zip'
Invoke-WebRequest -Uri ('https://codeload.github.com/Bioruebe/Bio.cs/zip/' + $PinnedCommit) -OutFile $Archive -UseBasicParsing
Expand-Archive -LiteralPath $Archive -DestinationPath $Work -Force
$Projects = @(Get-ChildItem -LiteralPath $Work -File -Recurse -Filter 'Bio.cs.csproj')
if ($Projects.Count -ne 1) { throw "Expected one upstream library project, got $($Projects.Count)" }
$Project = $Projects[0].FullName
$Dir = Split-Path -Parent $Project
function Add-LegacyOverload([string]$File,[string]$Signature,[string]$Overload) {
    $Text = Get-Content -LiteralPath $File -Raw -Encoding UTF8
    $Index = $Text.IndexOf($Signature,[StringComparison]::Ordinal)
    if ($Index -lt 0 -or $Text.IndexOf($Signature,$Index + $Signature.Length,[StringComparison]::Ordinal) -ge 0) {
        throw "Signature missing or duplicated in $File"
    }
    $Text = $Text.Replace($Signature,$Overload + [Environment]::NewLine + '        ' + $Signature)
    [IO.File]::WriteAllText($File,$Text,(New-Object Text.UTF8Encoding($false)))
}
Add-LegacyOverload (Join-Path $Dir 'Bio.cs') 'public static FileStream FileOpen(string path, FileMode fileMode, FileAccess fileAccess = FileAccess.ReadWrite) {' 'public static FileStream FileOpen(string path, FileMode fileMode) { return FileOpen(path, fileMode, FileAccess.ReadWrite); }'
Add-LegacyOverload (Join-Path $Dir 'Extensions\BinaryReaderExtensions.cs') 'public static string Read8BitPrefixedString(this BinaryReader binaryReader, bool utf8 = true, bool ignoreTrailingNullBytes = false) {' 'public static string Read8BitPrefixedString(this BinaryReader binaryReader, bool utf8) { return Read8BitPrefixedString(binaryReader, utf8, false); }'

& dotnet build $Project --configuration Release --framework net45 --output $Output '-p:GeneratePackageOnBuild=false' '-p:AutomaticallyUseReferenceAssemblyPackages=true'
if ($LASTEXITCODE -ne 0) { throw "Bio.cs build failed: $LASTEXITCODE" }
$DLL = Join-Path $Output 'Bio.cs.dll'
if (-not (Test-Path -LiteralPath $DLL -PathType Leaf)) { throw 'Bio.cs.dll was not produced' }
$Asm = [Reflection.Assembly]::ReflectionOnlyLoadFrom($DLL)
$Version = $Asm.GetName().Version
if ($Version.Major -ne 2 -or $Version.Minor -ne 6) { throw "Expected 2.6.x; got $Version" }
$Checks = @(
    @{Type='BioLib.Bio'; Name='FileOpen'; Args='System.String,System.IO.FileMode'},
    @{Type='BioLib.Bio'; Name='FileOpen'; Args='System.String,System.IO.FileMode,System.IO.FileAccess'},
    @{Type='BioLib.Streams.BinaryReaderExtensions'; Name='Read8BitPrefixedString'; Args='System.IO.BinaryReader,System.Boolean'},
    @{Type='BioLib.Streams.BinaryReaderExtensions'; Name='Read8BitPrefixedString'; Args='System.IO.BinaryReader,System.Boolean,System.Boolean'}
)
foreach ($Check in $Checks) {
    $Type = $Asm.GetType($Check.Type,$true)
    $Found = @($Type.GetMethods([Reflection.BindingFlags]::Public -bor [Reflection.BindingFlags]::Static) | Where-Object {
        $_.Name -eq $Check.Name -and
        (($_.GetParameters() | ForEach-Object { $_.ParameterType.FullName }) -join ',') -ceq $Check.Args
    })
    if ($Found.Count -ne 1) { throw "Missing CLR method: $($Check.Type).$($Check.Name)($($Check.Args))" }
    Write-Host "Verified CLR method $($Check.Type).$($Check.Name)($($Check.Args))"
}
$Bin = Join-Path $Bundle 'bin'
New-Item -ItemType Directory -Force -Path $Bin | Out-Null
Copy-Item -LiteralPath $DLL -Destination (Join-Path $Bin 'Bio.cs.dll') -Force
$Lic = @(Get-ChildItem -LiteralPath $Work -File -Recurse -Filter 'LICENSE')
if ($Lic.Count -ne 1) { throw 'Missing or ambiguous upstream LICENSE' }
$LicDir = Join-Path $Bundle 'docs\third-party'
New-Item -ItemType Directory -Force -Path $LicDir | Out-Null
Copy-Item -LiteralPath $Lic[0].FullName -Destination (Join-Path $LicDir 'Bio.cs-LICENSE') -Force
@(
    'Bio.cs 2.6.0 compatibility candidate (not yet in public release)'
    "Upstream pinned commit: $PinnedCommit"
    'Target framework: net45'
    'Legacy FileOpen and Read8BitPrefixedString signatures preserved'
    'Dependent extractor behavioral tests remain outstanding'
    "SHA-256: $((Get-FileHash -LiteralPath $DLL -Algorithm SHA256).Hash.ToLowerInvariant())"
) | Set-Content -LiteralPath (Join-Path $Bundle 'BIOLIB-ABI.txt') -Encoding UTF8
Write-Host 'Bio.cs candidate build and ABI assertions passed.'
