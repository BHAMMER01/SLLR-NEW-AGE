param(
  [string]$GameRoot = (Join-Path $PSScriptRoot '..\Street Legal Racing - Redline'),
  [string]$Exe = (Join-Path $PSScriptRoot '..\build\Release\slrr_host.exe'),
  [string]$Out = (Join-Path $PSScriptRoot '..\build\verification\telemetry'),
  [int]$DriveSeconds = 20
)
$ErrorActionPreference = 'Stop'
$GameRoot = (Resolve-Path $GameRoot).Path
$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Force $Out | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runRoot = Join-Path $Out "root-$stamp"
$csv = Join-Path $Out "engine-$stamp.csv"
$samples = Join-Path $Out "process-$stamp.csv"
$stdout = Join-Path $Out "runtime-$stamp.out.log"
$stderr = Join-Path $Out "runtime-$stamp.err.log"
robocopy $GameRoot $runRoot /E /COPY:DAT /DCOPY:DAT /NFL /NDL /NJH /NJS /NP /R:1 /W:1 | Out-Null
if ($LASTEXITCODE -gt 7) { throw "Could not prepare benchmark root" }
$args = @('--game','--window','--no-vsync','--renderer','vulkan','--root',$runRoot,
  '--spawn-car','cars/racers/Baiern.rpk:0x6','--bench-map','Valocity',
  '--bench-drive',"$DriveSeconds",'--bench-time','13','--seed','3','--perf-log',$csv)
$p = Start-Process -FilePath $Exe -ArgumentList $args -WorkingDirectory (Split-Path $Exe) `
  -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
$rows = [System.Collections.Generic.List[object]]::new()
while (-not $p.HasExited) {
  try {
    $q = Get-Process -Id $p.Id -ErrorAction Stop
    $cpu = [math]::Round($q.CPU,3)
    $ram = [math]::Round($q.WorkingSet64 / 1MB,2)
    $rows.Add([pscustomobject]@{ Timestamp=(Get-Date).ToString('o'); CpuSeconds=$cpu; WorkingSetMB=$ram; Threads=$q.Threads.Count })
  } catch {}
  Start-Sleep -Milliseconds 250
}
$p.WaitForExit()
$rows | Export-Csv $samples -NoTypeInformation -Encoding utf8
$engine = @(); if (Test-Path $csv) { $engine = @(Import-Csv $csv | Select-Object -Skip 2) }
$avg = if ($engine.Count) { [math]::Round((($engine | Measure-Object frame_avg_ms -Average).Average),2) } else { $null }
$peakRam = if ($rows.Count) { [math]::Round((($rows | Measure-Object WorkingSetMB -Maximum).Maximum),2) } else { $null }
@{
  ExitCode=$p.ExitCode; Samples=$rows.Count; PeakWorkingSetMB=$peakRam
  EngineSamples=$engine.Count; AverageFrameMs=$avg; ProcessCsv=$samples; EngineCsv=$csv
  Stdout=$stdout; Stderr=$stderr
} | ConvertTo-Json | Set-Content (Join-Path $Out "summary-$stamp.json") -Encoding utf8
Write-Output "Telemetry samples=$($rows.Count) peak_ram_mb=$peakRam engine_avg_frame_ms=$avg process_csv=$samples engine_csv=$csv"
