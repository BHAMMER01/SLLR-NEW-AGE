param(
  [Parameter(Mandatory=$true)] [ValidateSet('Export','Import','RoundTrip')] [string] $Mode,
  [Parameter(Mandatory=$true)] [string] $InputPath,
  [Parameter(Mandatory=$true)] [string] $OutputPath,
  [string] $Toolbox = 'C:\games\SLRR_BRAZIL_V14.1(29_09_2024)\_TOOLBOX\01_Blender_e_Modelagem_3D'
)

$scx2obj = Join-Path $Toolbox 'scx2obj.py'
$obj2scx = Join-Path $Toolbox 'obj2scx.py'
if (-not (Test-Path -LiteralPath $scx2obj) -or -not (Test-Path -LiteralPath $obj2scx)) {
  throw "Toolbox SCX/OBJ nao encontrada: $Toolbox"
}
if (-not (Get-Command py -ErrorAction SilentlyContinue)) {
  throw 'Python Launcher (py.exe) nao encontrado.'
}

$outputFull = [IO.Path]::GetFullPath($OutputPath)
New-Item -ItemType Directory -Force (Split-Path -Parent $outputFull) -ErrorAction SilentlyContinue | Out-Null

switch ($Mode) {
  'Export' {
    & py -3 $scx2obj (Resolve-Path -LiteralPath $InputPath).Path $outputFull
    if ($LASTEXITCODE -ne 0) { throw "SCX -> OBJ falhou ($LASTEXITCODE)" }
  }
  'Import' {
    & py -3 $obj2scx (Resolve-Path -LiteralPath $InputPath).Path $outputFull
    if ($LASTEXITCODE -ne 0) { throw "OBJ -> SCX falhou ($LASTEXITCODE)" }
  }
  'RoundTrip' {
    $scratch = Join-Path ([IO.Path]::GetTempPath()) ('slrr-roundtrip-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force $scratch | Out-Null
    $obj = Join-Path $scratch 'roundtrip.obj'
    $scx = Join-Path $scratch 'roundtrip.scx'
    & py -3 $scx2obj (Resolve-Path -LiteralPath $InputPath).Path $obj
    if ($LASTEXITCODE -ne 0) { throw "SCX -> OBJ falhou ($LASTEXITCODE)" }
    & py -3 $obj2scx $obj $scx
    if ($LASTEXITCODE -ne 0) { throw "OBJ -> SCX falhou ($LASTEXITCODE)" }
    Copy-Item -LiteralPath $scx -Destination $outputFull -Force
    Remove-Item -LiteralPath $scratch -Recurse -Force
  }
}

Write-Output "OK: $Mode concluido"
Write-Output 'Eixos: SLRR=(Blender.X, Blender.Z, -Blender.Y), escala OBJ->SCX = 100'
