# Stress and controls validation

Date: 2026-11-25

## 60-second city stress run

Command:

```powershell
.\scripts\run_fps_goal.ps1 -GameRoot '..\Street Legal Racing - Redline' \
  -Exe '.\build\Release\slrr_host.exe' -DriveSeconds 60 -Renderer vulkan
```

Result: process exited normally with 49 post-warmup samples.

- Average: **83.14 FPS** / **12.03 ms**
- Average P95: **19.66 ms**
- Worst window: **119.43 ms**
- Map: `Valocity`, car: `Baiern.rpk:0x6`

This confirms the game remains above 60 FPS on average, but does not meet the
120-FPS target or the 16.67-ms frame-time ceiling during sustained driving.
The complete CSV and logs are under `build/fps-goal/` with stamp
`20261125-065322`.

## Cruise/input harness

Command:

```powershell
.\scripts\test_cruise_input.ps1 -GameRoot '..\Street Legal Racing - Redline' \
  -Exe '.\build\Release\slrr_host.exe' -WaitSeconds 20
```

The run exited normally and captured two physical-S events:

```text
[input-hotkey] axis=31 down=1 S=0 P=1
[input-hotkey] axis=31 down=0 S=0 P=0
```

The event stream confirms the S/P remap path is active. The existing harness
also records the brake-cancel callback; no duplicate cruise toggle was observed
in this run.

## Remaining stress gap

This test drives the scripted route and validates process stability. The
automated scene loop and OS telemetry are recorded in the sections below.

## Controlled scene launch and RAM cycle

A controlled two-phase launch was executed on the Release binary. Each phase
ran for five seconds, sampled process working-set memory twice per second, then
closed the window and verified the exit log.

- Garage: entered `java.game.Garage`, exited normally (`exit=0`), peak working
  set approximately **171.1 MB**.
- Direct city: exited `java.game.Garage`, entered `java.game.Valocity`, and
  reached the soft main loop; peak working set approximately **500.6 MB**.

Evidence is under `build/verification/scene-cycle-20261125/` (`*.out.log`,
`*.err.log`, and `*.ram.csv`). The direct city transition is reproducible. The
test-only `--auto-garage-after-city` option now confirms the complete
`Garage -> Valocity -> Garage` transition with `exit=0`.

## Batch control probe

The temporary `scripts/test_key_batch.ps1` sent `W S A D E N H P Q` to the
direct-city window. The host log observed:

- W down/up (`scan=0x11`);
- S down/up (`scan=0x1f`);
- P down/up (`scan=0x19`, cruise remap path).

No `[input-key]` records were emitted for A, D, E, N, H or Q in this probe.
That means the current host logging/input path does not prove those controls
are reaching gameplay; it does not prove that the game ignores them. They need
dedicated action-level instrumentation or a focused UI state test before being
declared validated.

The host now supports `SLRR_INPUT_TRACE=1` for diagnostic runs. With that
environment variable, every physical key down/up is logged, allowing the next
probe to distinguish missing host input from an action-level script failure.

The follow-up batch with tracing detected all requested physical keys. Unique
scancodes included W=`0x11`, S=`0x1f`, A=`0x1e`, D=`0x20`, E=`0x12`, N=`0x31`,
H=`0x23` and P=`0x19`. This validates delivery to the host input layer; the
action-level effects still require gameplay-state assertions.

## Manual route capture and replay (2026-11-25)

The user drove the Baiern through the direct-city session and reported losing a
wheel. The session was stopped on request after recording completed. The route
file `build/verification/player-route-4.bin` is 2,950,893 bytes and contains
about 166 seconds of timestamped chassis matrices.

The same route was replayed automatically with the saved graphics profile. The
replay completed normally and produced `build/verification/perf-player-route-20261125/`:

- 111.44 FPS average;
- 9.04 ms average frame time;
- 5.18 ms flush and 7.22 ms GPU time;
- no host crash or fatal replay error.

The replay log confirms wheel/rim/tyre resources loaded, but the current
telemetry does not yet expose per-wheel detachment state. Therefore the manual
wheel loss is recorded as a reproducible route scenario, not yet as a proven
physics defect. The next instrumentation step is to emit wheel/axle health and
attachment state each physics frame and compare it against this replay.

### Wheel-release diagnostic hook

That instrumentation is now present behind `SLRR_WHEEL_TRACE=1`. The native
wheel-mount release paths report corner index, release reason (`travel` or
`impact`), impact energy/speed, and remaining mount condition. A 20-second
Vulkan city smoke run with tracing enabled completed with exit code 0 at
111.01 FPS and emitted no release event, so the ordinary benchmark path did
not lose a wheel. The recorded manual route remains the next input for a
longer traced replay; this separates a true mount failure from a visual or
script-side wheel disappearance.

The longer traced replay completed at 112.06 FPS (8.99 ms average frame,
5.18 ms flush, 7.25 ms GPU) and emitted **zero** `[wheel-trace]` release
events. Because the drive-path format stores chassis transforms rather than
the complete input, damage and part-attachment history, this does not replay
the manual wheel failure itself. It does establish that the recorded route is
stable under deterministic replay and that the mount-release code did not
trigger from the replayed transforms alone.
