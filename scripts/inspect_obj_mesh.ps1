param([Parameter(Mandatory)][string[]] $Path)
$ErrorActionPreference = 'Stop'
foreach ($file in $Path) {
  $vertices = New-Object 'System.Collections.Generic.List[double[]]'
  $faces = 0; $materials = [ordered]@{}; $material = '<default>'
  foreach ($line in Get-Content -LiteralPath $file) {
    if ($line -match '^v\s+([-+0-9.eE]+)\s+([-+0-9.eE]+)\s+([-+0-9.eE]+)') {
      $vertices.Add(@([double]$Matches[1], [double]$Matches[2], [double]$Matches[3]))
    } elseif ($line -match '^usemtl\s+(.+)$') {
      $material = $Matches[1].Trim(); if (-not $materials.Contains($material)) { $materials[$material] = 0 }
    } elseif ($line -match '^f\s+') {
      $faces++; if (-not $materials.Contains($material)) { $materials[$material] = 0 }; $materials[$material]++
    }
  }
  if ($vertices.Count -eq 0) { Write-Output "${file}: no vertices"; continue }
  $min=@(0,0,0); $max=@(0,0,0)
  for($axis=0;$axis -lt 3;$axis++){ $v=$vertices|ForEach-Object{$_[$axis]};$min[$axis]=($v|Measure-Object -Minimum).Minimum;$max[$axis]=($v|Measure-Object -Maximum).Maximum }
  [pscustomobject]@{File=(Resolve-Path -LiteralPath $file).Path;Vertices=$vertices.Count;Faces=$faces;Materials=$materials.Count;Bounds="X[$($min[0]),$($max[0])] Y[$($min[1]),$($max[1])] Z[$($min[2]),$($max[2])]";FacesByMaterial=(($materials.GetEnumerator()|ForEach-Object{"$($_.Key)=$($_.Value)"}) -join '; ')}
}
