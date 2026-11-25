param(
  [string] $Exe = (Join-Path $PSScriptRoot '..\build\Release\slrr_host.exe'),
  [string] $GameRoot = (Join-Path $PSScriptRoot '..\Street Legal Racing - Redline'),
  [string] $Out = (Join-Path $PSScriptRoot '..\build\monitor'),
  [int] $Seconds = 45,
  [string] $Renderer = 'vulkan',
  [switch] $Map,
  [switch] $RenderPerformance
)

$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$GameRoot = (Resolve-Path -LiteralPath $GameRoot).Path
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$csv = Join-Path (Resolve-Path -LiteralPath $Out).Path "system-$stamp.csv"
$perf = Join-Path (Resolve-Path -LiteralPath $Out).Path "perf-$stamp.csv"
$runRoot = Join-Path (Resolve-Path -LiteralPath $Out).Path "root-$stamp"
$stdout = Join-Path (Resolve-Path -LiteralPath $Out).Path "run-$stamp.out.log"
$stderr = Join-Path (Resolve-Path -LiteralPath $Out).Path "run-$stamp.err.log"
robocopy $GameRoot $runRoot /E /COPY:DAT /DCOPY:DAT /NFL /NDL /NJH /NJS /NP /R:1 /W:1 | Out-Null
if ($LASTEXITCODE -gt 7) { throw "Could not prepare private monitor root (robocopy $LASTEXITCODE)" }
$args = @('--game','--window','--no-vsync','--root',$runRoot,
  '--spawn-car','cars/racers/Baiern.rpk:0x6','--bench-map','Valocity','--bench-drive',"$Seconds",
  '--bench-time','13','--seed','3','--perf-log',$perf)
if ($Renderer -eq 'vulkan') { $args += @('--renderer','vulkan') }
elseif ($Renderer -ne 'auto') { throw 'Renderer must be auto or vulkan' }
if ($RenderPerformance) { $args += '--render-performance' }
if (-not $Map) { $args += '--auto-cmd'; $args += 'street' }

$p = Start-Process -FilePath $Exe -ArgumentList $args -WorkingDirectory (Split-Path $Exe) `
  -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
$sw = [Diagnostics.Stopwatch]::StartNew()
$rows = [System.Collections.Generic.List[object]]::new()
$lastCpu = 0.0
$lastWall = 0.0
try {
  while (-not $p.HasExited -and $sw.Elapsed.TotalSeconds -lt ($Seconds + 90)) {
    $proc = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
    $nowWall = $sw.Elapsed.TotalSeconds
    $nowCpu = if($proc){[double]$proc.CPU}else{$lastCpu}
    $cpuPct = if($nowWall -gt $lastWall){(($nowCpu-$lastCpu) / (($nowWall-$lastWall) * [Environment]::ProcessorCount)) * 100}else{0}
    $lastCpu = $nowCpu
    $lastWall = $nowWall
    $counters = Get-Counter '\Processor(*)\% Processor Time' -ErrorAction SilentlyContinue
    $cores = @($counters.CounterSamples | Where-Object { $_.InstanceName -ne '_Total' } |
      Sort-Object InstanceName | ForEach-Object { [math]::Round($_.CookedValue,2) })
    $gpuSamples = @()
    if ($proc) {
      $gpuCounters = Get-Counter '\GPU Engine(*)\Utilization Percentage' -ErrorAction SilentlyContinue
      $pidToken = "pid_$($p.Id)_"
      $gpuSamples = @($gpuCounters.CounterSamples | Where-Object {
        $_.Path -like "*$pidToken*"
      })
    }
    $gpu3d = @($gpuSamples | Where-Object { $_.Path -match 'engtype_3D|engtype_3d' } |
      Measure-Object -Property CookedValue -Sum).Sum
    $gpuCopy = @($gpuSamples | Where-Object { $_.Path -match 'engtype_copy' } |
      Measure-Object -Property CookedValue -Sum).Sum
    $row = [ordered]@{
      elapsed_s = [math]::Round($sw.Elapsed.TotalSeconds,3)
      process_cpu_pct = [math]::Round($cpuPct,2)
      process_cpu_equivalent_cores = [math]::Round(($cpuPct * [Environment]::ProcessorCount / 100),2)
      process_working_set_mb = if($proc){[math]::Round([double]$proc.WorkingSet64 / 1MB,2)}else{0}
      process_commit_mb = if($proc){[math]::Round([double]$proc.PrivateMemorySize64 / 1MB,2)}else{0}
      logical_cpu_avg_pct = if($cores.Count){[math]::Round((($cores | Measure-Object -Average).Average),2)}else{0}
      logical_cpu_max_pct = if($cores.Count){[math]::Round((($cores | Measure-Object -Maximum).Maximum),2)}else{0}
      logical_cpu = ($cores -join ';')
      gpu_engine_3d_pct = [math]::Round([double]$gpu3d,2)
      gpu_engine_copy_pct = [math]::Round([double]$gpuCopy,2)
    }
    $rows.Add([pscustomobject]$row)
    Start-Sleep -Milliseconds 250
    $p.Refresh()
  }
} finally {
  if (-not $p.HasExited) { $p.Kill() }
  $sw.Stop()
}
$rows | Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding utf8
[pscustomobject]@{ SystemCsv=$csv; PerfCsv=$perf; Samples=$rows.Count; ExitCode=$p.ExitCode } | Format-List
