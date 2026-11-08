param(
    [Parameter(Mandatory=$true)][string]$BaselineDll,
    [Parameter(Mandatory=$true)][string]$CandidateDll
)
$ErrorActionPreference = 'Stop'
$BaselineDll = (Resolve-Path -LiteralPath $BaselineDll).Path
$CandidateDll = (Resolve-Path -LiteralPath $CandidateDll).Path
# Bind the reference to the exact DLL shipped in v3.1.9.
if ((Get-FileHash -LiteralPath $BaselineDll -Algorithm SHA256).Hash -ne 'D3FBAACC004B7F375F2DABE045C95C02799F72946F5F27F607B5C8953B5756F8') {
    throw 'Baseline is not the audited shipped Bio.cs 2.5 DLL.'
}
$Root = Join-Path (Split-Path -Parent $PSScriptRoot) ('.build/biolib-client-' + [Guid]::NewGuid().ToString('N'))
$Base = Join-Path $Root 'baseline'
$Candidate = Join-Path $Root 'candidate'
New-Item -ItemType Directory -Path $Base,$Candidate -Force | Out-Null
Copy-Item -LiteralPath $BaselineDll -Destination (Join-Path $Base 'Bio.cs.dll')
Copy-Item -LiteralPath $CandidateDll -Destination (Join-Path $Candidate 'Bio.cs.dll')
$Compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319/csc.exe'
$Exe = Join-Path $Base 'LegacyClient.exe'
& $Compiler /nologo /target:exe "/out:$Exe" "/reference:$BaselineDll" (Join-Path $PSScriptRoot 'fixtures/biolib-legacy-client.cs')
if ($LASTEXITCODE -ne 0) { throw 'Legacy client compilation failed' }
Copy-Item -LiteralPath $Exe -Destination (Join-Path $Candidate 'LegacyClient.exe')
foreach ($Directory in @($Base,$Candidate)) {
    $Info = New-Object Diagnostics.ProcessStartInfo
    $Info.FileName = Join-Path $Directory 'LegacyClient.exe'
    $Info.Arguments = '"' + (Join-Path $Directory 'sample.bin') + '"'
    $Info.UseShellExecute = $false
    $Info.CreateNoWindow = $true
    $Info.RedirectStandardOutput = $true
    $Info.RedirectStandardError = $true
    $Process = [Diagnostics.Process]::Start($Info)
    $OutputTask = $Process.StandardOutput.ReadToEndAsync()
    $ErrorTask = $Process.StandardError.ReadToEndAsync()
    if (-not $Process.WaitForExit(30000)) {
        $Process.Kill()
        throw "Legacy client timed out in $Directory"
    }
    $Process.WaitForExit()
    $Result = $OutputTask.Result
    $ErrorText = $ErrorTask.Result
    if ($Process.ExitCode -ne 0 -or $Result.Trim() -cne 'LEGACY-CLIENT-PASSED') { throw "Legacy client failed in $Directory : $ErrorText" }
    Write-Host "Legacy client passed with $Directory"
}
Write-Host 'BIOLIB-LEGACY-CLIENT-PASSED'
