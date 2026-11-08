[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$BaselineDll,
    [string]$DestinationRoot
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$BaselineDll = (Resolve-Path -LiteralPath $BaselineDll).Path
if ((Get-FileHash -LiteralPath $BaselineDll).Hash -ne 'D3FBAACC004B7F375F2DABE045C95C02799F72946F5F27F607B5C8953B5756F8') {
    throw 'Compile the repaired client against the exact shipped Bio.cs 2.5 DLL.'
}
if (-not $DestinationRoot) { $DestinationRoot = Join-Path (Split-Path $PSScriptRoot) '.build/godotdec-validation' }
$DestinationRoot = [IO.Path]::GetFullPath($DestinationRoot)
New-Item -ItemType Directory -Force -Path $DestinationRoot | Out-Null
$Archive = Join-Path $DestinationRoot 'source.zip'
$Commit = '475b61673189ef3ae5f759111f91cbda1dabde83'
Invoke-WebRequest ('https://codeload.github.com/Bioruebe/godotdec/zip/' + $Commit) -OutFile $Archive -UseBasicParsing
if ((Get-FileHash -LiteralPath $Archive).Hash -ne 'F9FFFE0526BE3D070C790ED5F47E430D013F0E656D2F7157D5296D1270BEAFD7') {
    throw 'Godot source archive checksum mismatch.'
}
$Source = Join-Path $DestinationRoot 'source'
Expand-Archive -LiteralPath $Archive -DestinationPath $Source -Force
$ProjectDir = Join-Path $Source ('godotdec-' + $Commit + '/godotdec')
$Program = Join-Path $ProjectDir 'Program.cs'
$Code = [IO.File]::ReadAllText($Program)
$Old = 'inputStream.BaseStream.WriteToFile(destination, PROMPT_ID, copyFunction);'
if (($Code.Split([string[]]@($Old), [StringSplitOptions]::None)).Count -ne 2) { throw 'Expected exactly one extraction call to patch.' }
$Code = $Code.Replace($Old, 'inputStream.BaseStream.WriteToFileRelative(destination, PROMPT_ID, copyFunction);')
$Code = $Code.Replace('private const string VERSION = "2.1.2";', 'private const string VERSION = "2.1.2-ue2.1";')
[IO.File]::WriteAllText($Program, $Code, (New-Object Text.UTF8Encoding($false)))
$Reference = [Security.SecurityElement]::Escape($BaselineDll)
$Project = Join-Path $ProjectDir 'Compat.csproj'
@"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType><TargetFramework>net40</TargetFramework>
    <AssemblyName>godotdec</AssemblyName><GenerateAssemblyInfo>false</GenerateAssemblyInfo>
    <EnableDefaultCompileItems>false</EnableDefaultCompileItems><Deterministic>true</Deterministic>
  </PropertyGroup>
  <ItemGroup>
    <Compile Include="Program.cs" /><Compile Include="Properties/AssemblyInfo.cs" />
    <Reference Include="Bio.cs"><HintPath>$Reference</HintPath><Private>false</Private></Reference>
  </ItemGroup>
</Project>
"@ | Set-Content -LiteralPath $Project -Encoding UTF8
$AssemblyInfo = Join-Path $ProjectDir 'Properties/AssemblyInfo.cs'
$Info = [IO.File]::ReadAllText($AssemblyInfo)
$Info = $Info -replace 'AssemblyVersion\("[^"]+"\)', 'AssemblyVersion("2.1.2.1")'
$Info = $Info -replace 'AssemblyFileVersion\("[^"]+"\)', 'AssemblyFileVersion("2.1.2.1")'
[IO.File]::WriteAllText($AssemblyInfo, $Info, (New-Object Text.UTF8Encoding($false)))
$Output = Join-Path $DestinationRoot 'bundle'
& dotnet build $Project --configuration Release --output $Output '-p:AutomaticallyUseReferenceAssemblyPackages=true'
if ($LASTEXITCODE -ne 0) { throw 'Godot candidate compilation failed.' }
$Assembly = [Reflection.Assembly]::ReflectionOnlyLoadFrom((Join-Path $Output 'godotdec.exe'))
$Framework = @($Assembly.GetCustomAttributesData() | Where-Object { $_.AttributeType.FullName -eq 'System.Runtime.Versioning.TargetFrameworkAttribute' })
if ($Framework.Count -ne 1 -or $Framework[0].ConstructorArguments[0].Value -cne '.NETFramework,Version=v4.0') { throw 'Godot must retain the net40 target.' }
if ($Assembly.GetName().Version.ToString() -ne '2.1.2.1') { throw 'Godot candidate version mismatch.' }
$BioReference = @($Assembly.GetReferencedAssemblies() | Where-Object { $_.Name -eq 'Bio.cs' })
if ($BioReference.Count -ne 1 -or $BioReference[0].Version.ToString() -ne '2.5.0.0') { throw 'Godot must reference Bio.cs 2.5.' }
Copy-Item -LiteralPath (Join-Path $Source ('godotdec-' + $Commit + '/LICENSE')) -Destination (Join-Path $Output 'godotdec-LICENSE')
@('Unshipped Godot 2.1.2-ue2.1 compatibility candidate',
  "Source commit: $Commit",
  'Patch: preserve archive payload position when writing extracted files',
  'Compiled against pinned Bio.cs 2.5, targeting .NET Framework 4.0',
  "SHA-256: $((Get-FileHash (Join-Path $Output 'godotdec.exe')).Hash.ToLowerInvariant())") |
    Set-Content (Join-Path $Output 'GODOT-CANDIDATE.txt') -Encoding UTF8
