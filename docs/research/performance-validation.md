# Performance validation — 2026-11-25

## Executed test

Command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/perf_baseline.ps1 `
  -SourceRoot '..\Street Legal Racing - Redline' `
  -Out build\verification\perf-20261125c `
  -Scenes day -Cpus all -Presets saved -DriveSeconds 20
```

The Release executable was already built successfully before the run. The
benchmark produced a CSV and stdout/stderr capture under
`build/verification/perf-20261125c/`.

## Observed result

The requested city benchmark did **not** enter the city. The command emitted
`[jvm] invoke miss java.game.Valocity.StartMap ()V` and exited in
`java.game.Garage`. This is a benchmark/launch limitation, not evidence about
city performance. The harness also failed while summarising because it assumed
the city run had produced a final benchmark row.

The captured garage frames nevertheless show:

- steady FPS after warm-up: approximately 406–412 FPS;
- frame average: approximately 2.43–2.46 ms;
- frame p95: approximately 4.1–4.2 ms;
- typical GPU time: approximately 2.36–2.40 ms;
- scripts: approximately 0.10–0.13 ms;
- physics: approximately 0.04–0.05 ms;
- render draws: approximately 284–288.

There was one isolated warm-up spike (`frame_max_ms` about 53 ms) and one
transient spike around second 14 (about 79 ms). The normal steady-state garage
frame time is well below the 16.67 ms target.

## Important limitation

This run does not validate the reported low-FPS city case. Before tuning
rendering or physics, the city launch path must be fixed so the benchmark can
enter `ValoCity` and record a repeatable route. CPU/RAM/GPU process telemetry
was not collected by this harness; the CSV contains engine timing and GPU timing
only.

## City benchmark fix and validated run

The benchmark fallback originally called the nonexistent `Valocity.StartMap()V`.
It now runs the constructor and active-section transition used by the direct
city launcher. A rebuilt Release Vulkan run completed with actual city draws:

```text
AverageFPS       : 111.84
AverageFrameMs   : 8.94
AverageP95Ms     : 11.45
WorstWindowMaxMs : 23.49
```

The log confirms `draws=4394`, `gpu=4.09 ms`, `physics=3.72 ms` and a measured
speed of 45.92 km/h. A later window reached 94.5 FPS / 10.59 ms while physics
rose to 5.54 ms and deformation to 1.38 ms. This is now a valid city
measurement: average performance is above 60 FPS but below the 120 FPS target,
with isolated frame-time spikes above 16.67 ms.

Evidence: `build/fps-goal/fps-20261125-065108.csv` and matching `.out.log`.

## Low preset comparison

The same city drive with the low graphics preset reached **98.65 FPS** and
**10.47 ms** average frametime, with `flush=5.3 ms` and `gpu=6.31 ms`.
This confirms that lowering graphics helps but does not reach 120 FPS; the
remaining budget is also being consumed by physics, scene collection and
submission work rather than only shader cost.

## Harness correction and follow-up run

Decompilation of the installed scripts confirmed that `java.game.Valocity`
inherits `City` and has no `StartMap()V` method. The original benchmark fallback
called that nonexistent method, which caused the earlier `invoke miss` and left
the run in the garage. The fallback now mirrors the stock transition:

```text
GameLogic.gameMode = GM_FREERIDE
GameLogic.changeActiveSection(new java.game.Valocity())
```

The Release build passed after this correction. A short follow-up produced:

- `[bench] MapBox empty; using java.game.Valocity`
- `[section] exit java.game.Garage`
- `[section] actual=java.game.Valocity`
- `[section] enter java.game.Valocity`

Evidence is in `build/verification/city-bench-fix-20261125/run.log` and
`city.csv`. However, the city scene did not finish render synchronization in
the captured window: after transition, timing rows reported zero draws/GPU work
and the process did not reach the normal benchmark completion marker before it
was stopped. The transition bug is fixed, but city rendering/loading remains a
separate blocker for a valid city FPS measurement.
