param(
  [Parameter(Mandatory=$true)] [string] $InputCsv,
  [string] $OutputCsv
)

$rows = Import-Csv -LiteralPath $InputCsv
if (-not $OutputCsv) { $OutputCsv = [IO.Path]::ChangeExtension($InputCsv, '.summary.csv') }

$summary = $rows | ForEach-Object {
  $du = [double]$_.uv0_max_u - [double]$_.uv0_min_u
  $dv = [double]$_.uv0_max_v - [double]$_.uv0_min_v
  [pscustomobject]@{
    texture = $_.texture
    sections = 1
    triangles = [int]$_.triangles
    max_u_repeat = [math]::Round([math]::Abs($du), 3)
    max_v_repeat = [math]::Round([math]::Abs($dv), 3)
    uv_valid = [int]$_.uv0_valid
    suspicious = [int]($($_.uv0_valid -eq '0' -or $_.texture -eq '<missing>' -or [math]::Abs($du) -gt 8 -or [math]::Abs($dv) -gt 8))
  }
} | Group-Object texture | ForEach-Object {
  $g = $_.Group
  [pscustomobject]@{
    texture = $_.Name
    sections = ($g | Measure-Object sections -Sum).Sum
    triangles = ($g | Measure-Object triangles -Sum).Sum
    max_u_repeat = ($g | Measure-Object max_u_repeat -Maximum).Maximum
    max_v_repeat = ($g | Measure-Object max_v_repeat -Maximum).Maximum
    invalid_uv_sections = ($g | Where-Object uv_valid -eq 0 | Measure-Object).Count
    suspicious_sections = ($g | Measure-Object suspicious -Sum).Sum
  }
}

$summary | Sort-Object @{Expression='suspicious_sections';Descending=$true}, @{Expression='max_u_repeat';Descending=$true} |
  Export-Csv -LiteralPath $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Output "Material audit summary: $OutputCsv"
$summary | Where-Object {$_.suspicious_sections -gt 0} | Select-Object -First 25 |
  Format-Table texture,sections,triangles,max_u_repeat,max_v_repeat,invalid_uv_sections,suspicious_sections -AutoSize

Write-Output "`nTerrain-like textures (road/asphalt/grass/ground/terrain/concrete):"
$summary | Where-Object {$_.texture -match '(?i)road|asphalt|grass|ground|terrain|concrete|beton|area|dirt|sand'} |
  Sort-Object @{Expression='max_u_repeat';Descending=$true} |
  Format-Table texture,sections,triangles,max_u_repeat,max_v_repeat,invalid_uv_sections -AutoSize
