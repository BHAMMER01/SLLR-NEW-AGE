param(
  [string] $GameRoot = (Join-Path $PSScriptRoot '..\Street Legal Racing - Redline'),
  [string] $Exe = (Join-Path $PSScriptRoot '..\build\Release\slrr_host.exe'),
  [string] $Out = (Join-Path $PSScriptRoot '..\build\fps-goal'),
  [int] $DriveSeconds = 40,
  [string] $Map = 'Valocity',
  [string] $Car = 'cars/racers/Baiern.rpk:0x6',
  [string] $Renderer = 'auto',
  [switch] $Realtime
)
$ErrorActionPreference = 'Stop'
$GameRoot = (Resolve-Path -LiteralPath $GameRoot).Path
$Exe = (Resolve-Path -LiteralPath $Exe).Path
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$Out = (Resolve-Path -LiteralPath $Out).Path
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runRoot = Join-Path $Out "root-$stamp"
$csv = Join-Path $Out "fps-$stamp.csv"
$stdout = Join-Path $Out "fps-$stamp.out.log"
$stderr = Join-Path $Out "fps-$stamp.err.log"

# The host writes save/game/options on exit. Benchmark a private game copy.
robocopy $GameRoot $runRoot /E /COPY:DAT /DCOPY:DAT /NFL /NDL /NJH /NJS /NP /R:1 /W:1 | Out-Null
if ($LASTEXITCODE -gt 7) { throw "Could not prepare private benchmark root (robocopy $LASTEXITCODE)" }
$args = @('--game','--window','--no-vsync','--root',$runRoot,
  '--spawn-car',$Car,'--bench-map',$Map,'--bench-drive',"$DriveSeconds",
  '--bench-time','13','--seed','3','--perf-log',$csv)
if ($Realtime) { $args += '--bench-realtime' }
if ($Renderer -eq 'vulkan') { $args += '--renderer'; $args += 'vulkan' }
elseif ($Renderer -ne 'auto') { throw "Renderer must be auto or vulkan" }
$p = Start-Process -FilePath $Exe -ArgumentList $args -WorkingDirectory (Split-Path $Exe) `
  -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
if (-not $p.WaitForExit(600000)) {
  Stop-Process -Id $p.Id -Force
  throw "Benchmark timed out; logs: $stdout"
}
if (-not (Test-Path -LiteralPath $csv)) { throw "No perf CSV created; see $stderr" }
$rows = @(Import-Csv -LiteralPath $csv | Select-Object -Skip 2)
if (-not $rows.Count) { throw "Perf CSV has no post-warmup samples; see $stdout" }
$avg = ($rows | Measure-Object -Property frame_avg_ms -Average).Average
$p95 = ($rows | Measure-Object -Property frame_p95_ms -Average).Average
$worst = ($rows | Measure-Object -Property frame_max_ms -Maximum).Maximum
$fps = if ($avg -gt 0) { 1000 / $avg } else { 0 }
[pscustomobject]@{
  Renderer=$Renderer; Map=$Map; Car=$Car; Samples=$rows.Count
  AverageFPS=[math]::Round($fps,2); AverageFrameMs=[math]::Round($avg,2)
  AverageP95Ms=[math]::Round($p95,2); WorstWindowMaxMs=[math]::Round($worst,2)
  ExitCode=$p.ExitCode; Csv=$csv; Stdout=$stdout; Stderr=$stderr
} | Format-List
