# Render and frame-time profile

Date: 2026-11-25. All runs used the same Vulkan Valocity drive, Release x64
host, one car and 15 seconds after warm-up. Results are from
`build/verification/render-profile-20261125/summary.csv`.

| Preset | FPS | frame ms | flush ms | GPU ms | physics ms | collect ms | shadows ms | reflections ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| saved | 110.07 | 9.13 | 4.84 | 6.36 | 3.85 | 1.49 | 0.74 | 0.20 |
| low | 113.23 | 8.87 | 4.54 | 5.47 | 3.89 | 1.48 | 0.71 | 0.00 |
| AO off | 110.54 | 9.08 | 4.78 | 6.27 | 3.87 | 1.48 | 0.71 | 0.19 |
| reflections off | 112.60 | 8.94 | 4.60 | 5.52 | 3.90 | 1.50 | 0.73 | 0.00 |
| hard shadows | 103.32 | 9.74 | 5.17 | 6.66 | 4.05 | 1.58 | 0.78 | 0.19 |

## Interpretation

Lowering graphics improves the average only modestly. Disabling reflections is
more useful than disabling AO, but neither removes the main cost. The CPU-side
flush/submission path and physics remain significant even when GPU settings are
reduced. The `hard` shadow variant was worse in this run, so it should not be
treated as an optimization.

The next optimization target is therefore render submission/flush and scene
instance collection, followed by physics/deformation spikes. No visual setting
was changed in production based on this profile.

The diagnostic `--render-performance` preset was also run for 30 seconds. It
reached **114.15 FPS**, **8.76 ms** average frametime, **10.61 ms** average P95
and **23.97 ms** worst window. Stable windows can exceed 120 FPS, but the long
run still falls short of a sustained 120-FPS target; this preset is useful as a
reference lane, not a completed optimization.

The performance preset was then refined to use a 1500 m view distance and low
shadow quality (normal gameplay settings are unchanged). A 30-second repeat
reached **115.32 FPS**, **8.67 ms** average frametime, **10.55 ms** P95 and
**23.60 ms** worst window. This is a modest but repeatable improvement over the
previous 114.15 FPS reference, while still not meeting sustained 120 FPS.
An additional 500 m view-distance trial reached only **113.71 FPS** with a
24.34 ms worst window, so the 1500 m value is retained; aggressively culling
the city did not improve the main bottleneck.

A 15-second control run with `--physics-inline` reached only **84.89 FPS**
(11.78 ms average, 14.39 ms P95). The normal parallel physics path is therefore
substantially better; moving physics onto the main thread is not an optimization.

CPU-affinity comparison (`perf_baseline.ps1`, saved preset) produced **107.67
FPS / 9.32 ms** with all logical processors and **93.83 FPS / 10.73 ms** when
restricted to the four-performance-core profile. Flush rose from 4.93 ms to
6.19 ms and GPU time from 6.30 ms to 7.84 ms. More CPU parallelism helps, but
the remaining ceiling is still dominated by the main render/submission path.
