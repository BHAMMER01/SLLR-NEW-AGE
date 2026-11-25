param(
  [Parameter(Mandatory=$true)][string]$GameRoot,
  [string]$Source
)

$ErrorActionPreference = 'Stop'
$Source = if ($Source) { $Source } else { Join-Path $PSScriptRoot '..\assets\official_brazil_garage\garage' }
$sourcePath = (Resolve-Path -LiteralPath $Source).Path
$targetPath = Join-Path (Resolve-Path -LiteralPath $GameRoot).Path 'misc\garage'
if (-not (Test-Path -LiteralPath $sourcePath)) { throw "Garage source not found: $sourcePath" }
if (-not (Test-Path -LiteralPath $targetPath)) { throw "Game garage path not found: $targetPath" }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupPath = "$targetPath.before-brazil-$stamp"
Copy-Item -LiteralPath $targetPath -Destination $backupPath -Recurse
robocopy $sourcePath $targetPath /E /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -gt 7) { throw "robocopy failed with exit code $LASTEXITCODE" }

$count = (Get-ChildItem -LiteralPath $targetPath -Recurse -File).Count
$mwSource = Join-Path (Split-Path $sourcePath -Parent) 'mw_mod'
if (Test-Path -LiteralPath (Join-Path $mwSource 'MW_Mod.rpk')) {
  Copy-Item (Join-Path $mwSource 'MW_Mod.rpk') (Join-Path (Resolve-Path $GameRoot).Path 'MW_Mod.rpk') -Force
  if (Test-Path -LiteralPath (Join-Path $mwSource 'MW_Mod')) {
    Copy-Item (Join-Path $mwSource 'MW_Mod') (Join-Path (Resolve-Path $GameRoot).Path 'MW_Mod') -Recurse -Force
  }
}
[pscustomobject]@{ Garage=$targetPath; Backup=$backupPath; Files=$count; MW_Mod=(Test-Path (Join-Path (Resolve-Path $GameRoot).Path 'MW_Mod.rpk')) } | Format-List
