param(
  [Parameter(Mandatory = $true)]
  [string] $GameRoot,
  [string] $GodotAssets = 'E:\GAMEGODO\vdrift_godot\driver\gta_ped_assets\vehicle_entry_prototype\slices'
)

$ErrorActionPreference = 'Stop'
$converter = Join-Path $PSScriptRoot '..\tools\godot_glb_ped_to_matrixdata.py'
$outputRoot = Join-Path $PSScriptRoot '..\build\ped-transition'
$pythonLauncher = Get-Command py -ErrorAction SilentlyContinue
if ($pythonLauncher) {
  $python = $pythonLauncher.Source
  $pythonPrefix = @('-3')
} else {
  $python = (Get-Command python -ErrorAction Stop).Source
  $pythonPrefix = @()
}
$families = @(
  @{ Name = 'gambler'; Skeleton = 'gambler_walk.skl' },
  @{ Name = 'golgoth'; Skeleton = 'golgoth_walk.skl' },
  @{ Name = 'hooley';  Skeleton = 'hooley_walk.skl' },
  @{ Name = 'kilos';   Skeleton = 'kilos_walk.skl' },
  @{ Name = 'kim';     Skeleton = 'kim_walk.skl' },
  @{ Name = 'meka';    Skeleton = 'meka_walk.skl' }
)

$source = Join-Path $GodotAssets 'aldinapoli_{0}_a.glb'
foreach ($family in $families) {
  $targetSkeleton = Join-Path $GameRoot (Join-Path 'humans\pedestrians' $family.Skeleton)
  foreach ($clip in @('get_out', 'get_in')) {
    $input = $source -f $clip
    $destination = Join-Path $outputRoot (Join-Path $family.Name ("vehicle_{0}_a.matrixdata" -f $clip))
    if (-not (Test-Path -LiteralPath $input)) { throw "Missing source GLB: $input" }
    if (-not (Test-Path -LiteralPath $targetSkeleton)) { throw "Missing target skeleton: $targetSkeleton" }
    & $python @pythonPrefix $converter $input $targetSkeleton $destination
    if ($LASTEXITCODE -ne 0) { throw "Retarget failed for $($family.Name)/$clip (exit $LASTEXITCODE)" }
  }
}

Write-Host "Generated pedestrian transition clips under $([IO.Path]::GetFullPath($outputRoot))"
