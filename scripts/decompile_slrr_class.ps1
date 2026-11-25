param(
  [Parameter(Mandatory=$true, Position=0)] [string] $ClassPath,
  [string] $OutputDirectory = (Join-Path $PSScriptRoot '..\build\decompiled'),
  [switch] $Ir,
  [switch] $Strict,
  [string] $DecompilerRoot = 'C:\games\SLRROPENCLEAN\SLRR_rev-main'
)

$ErrorActionPreference = 'Stop'
$ClassPath = (Resolve-Path -LiteralPath $ClassPath).Path
$localCli = Join-Path $PSScriptRoot '..\third_party\slrr-jvm-decompiler\dist\src\cli.js'
$externalCli = Join-Path $DecompilerRoot 'node_modules\slrr-jvm-decompiler\dist\src\cli.js'
$cli = if (Test-Path -LiteralPath $localCli) { (Resolve-Path $localCli).Path } else { $externalCli }
if (-not (Test-Path -LiteralPath $cli)) { throw "SLRR-JVM decompiler not found: $cli" }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$args = @($cli, '--out', $OutputDirectory)
if ($Ir) { $args += '--ir' }
if ($Strict) { $args += '--strict' }
$args += $ClassPath
& node @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Decompiled sources: $OutputDirectory"
