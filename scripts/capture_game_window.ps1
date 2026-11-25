param(
    [string]$Title = 'OpenSLRR - dev',
    [string]$Output = 'perf/game-window.png'
)

$ffmpeg = (Get-Command ffmpeg -ErrorAction Stop).Source
$dir = Split-Path -Parent $Output
if ($dir) { New-Item -ItemType Directory -Force $dir | Out-Null }
& $ffmpeg -y -f gdigrab -framerate 1 -i "title=$Title" -frames:v 1 $Output
if ($LASTEXITCODE -ne 0) { throw "Não foi possível capturar a janela '$Title'." }
Write-Output (Resolve-Path $Output)
