# SLRR New Age development and validation log

This is the decision and evidence log for work introduced after the initial
OpenSLRR DX11 fork. Git records the exact source diff; this file records why a
change was made, how it was tested, and what remains unverified.

## Entry format

Copy this template for each meaningful change:

```text
## YYYY-MM-DD — short title

- Scope: subsystem and whether physics/state is intentionally untouched.
- Intent: behavior or problem being addressed.
- Changes: source, scripts and documentation files.
- Build: exact command and result.
- Runtime validation: map, renderer, resolution, VSync, duration and result.
- Evidence: benchmark/log paths (raw files stay under ignored build/).
- Limitations: known gaps, regressions or follow-up work.
```

## 2026-11-25 — Cruise hotkey isolated from brake

Follow-up: braking now invokes `java.game.Vehicle.setCruiseControl(0)` on the
physical S down edge, so an active cruise is cancelled without allowing S to
press the cruise hotkey.

- Scope: host keyboard hotkey dispatch; vehicle physics and renderer untouched.
- Intent: pressing S while driving must not toggle cruise control; only P may
  generate the cruise transition.
- Changes: `src/platform/host_input.cpp` now evaluates the shipped cruise
  virtual axis 31 from the physical DirectInput P scan (`0x19`) instead of the
  aggregated controller axis. The direct city launch and input procedure are
  documented in `docs/TESTING.md` and `AGENTS.md`.
- Build: MSBuild Release x64 completed successfully and produced
  `build/Release/slrr_host.exe`.
- Runtime validation: direct `--auto-city --renderer vulkan` reached
  `java.game.Valocity`. The W/S test produced no cruise-down transition with
  `S=1, P=0`; transitions were observed only when `P=1`.
- Evidence: `build/cruise-input-20261125-062538.out.log`.
- Limitations: the automated input harness uses window messages; physical
  hardware bindings still need a manual confirmation.

## 2026-11-25 — New Age keyboard defaults

- Scope: script input defaults only; vehicle physics and simulation state are
  intentionally untouched.
- Intent: make the requested modern WASD driving layout the project default.
- Changes: added `patch/system/Scripts/io/src/ControlSet.java` with W throttle,
  S brake, A/D steering, Left Shift/Left Ctrl gear up/down, E clutch, N nitro,
  H horn and P cruise control; shipped the generated `ControlSet.class` and
  `ControlSetState.class`.
- Build: `build/Release/compile_game_sources.exe` succeeded against a private
  game copy (1 source, 2 classes); the installed game was not modified.
- Runtime validation: source compilation passed. In-game key-by-key validation
  remains pending because the game was not launched during this input-only edit.
- Limitations: an existing saved control profile can override these defaults;
  reset controls or create a fresh profile to observe them.

## 2026-11-25 — Skip legacy boot videos by default

- Scope: boot presentation only; simulation, physics and game data are
  unchanged.
- Intent: remove the two legacy Activision/Invictus opening FMVs from the
  normal New Age startup path.
- Changes: the host now skips boot intros by default; `--show-intros` restores
  them for compatibility/testing.
- Build: Release `slrr_host.exe` rebuilt successfully.
- Runtime validation: Vulkan window launch reached `java.game.SplashScreen`
  without opening `Activision.avi` or `Invictus.avi`.

## 2026-11-25 — Initial SLRR New Age performance baseline

- Scope: renderer, host audio, benchmark tooling and documentation. The later
  city stress test did not modify physics; earlier fork work includes a
  dedicated physics worker pool and a conservative vehicle broadphase, which
  remain separately documented in the rendering performance notes.
- Intent: replace the garage-only/invalid benchmark path with a reproducible
  ValoCity drive and identify the cause of the original 2–8 FPS city result.
- Changes: native bgfx Vulkan selection; ValoCity benchmark fallback through
  `java.game.ValoCity_Track`; negative caching for failed traffic audio loads;
  renderer/physics profiler zones; `scripts/run_fps_goal.ps1` and
  `scripts/monitor_slrr.ps1` with CPU, RAM, GPU-engine and frame-time output;
  performance notes in `docs/rendering/performance.md`.
- Build: `cmake --build build --config Release --target slrr_host --parallel 8`;
  Release build completed and produced `build/Release/slrr_host.exe`.
- Runtime validation: private ValoCity drive, Vulkan, 1280x720, no VSync,
  45-second stress run. After warm-up, 35 measured seconds averaged 111.05 FPS
  (9.02 ms), with a 103.08 FPS minimum window, 12.83 ms maximum p95, and a
  23.24 ms isolated worst frame. Physics averaged 3.85 ms and the GPU zone
  3.87 ms. The process averaged 3.66 equivalent CPU cores and peaked at 5.35;
  working set peaked at 480 MB; process 3D-engine utilization averaged 34.6%
  and peaked at 49.7%.
- Evidence: raw files were kept in ignored paths under
  `build/monitor/` (`perf-20261125-045647.csv`,
  `system-20261125-045647.csv` and the corresponding run log).
- Limitations: 200+ FPS in the full city was not achieved. The remaining frame
  budget is dominated by render-thread submission/flush, vehicle rendering and
  scene draws; logical-CPU counters were unavailable on this Windows setup.
  The next safe optimization target is visual submission, LOD/culling and
  streaming, with physics frozen unless explicitly reopened.

## Open validation questions

- Compare a visual-only render-performance preset against the unchanged default
  without changing simulation state.
- Reduce city draw/submission cost while checking geometry, shadows and traffic
  visibility against a captured baseline.
- Add a repeatable regression command for Vulkan and Direct3D 11 once both paths
  are measured on the same private game copy.

## 2026-11-25 — Explicit renderer A/B selection

- Scope: bgfx API selection and benchmark script; simulation unchanged.
- Intent: make the renderer comparison from the Brazil workspace reproducible
  in New Age instead of relying on the platform default.
- Changes: `RenderApi` now accepts `auto`, `vulkan`, `d3d11`, `d3d12` and
  `opengl`; bgfx maps those names to the corresponding renderer type; the FPS
  harness accepts the same names.
- Build: MSBuild Release x64 passed.
- Runtime validation: matched 20-second ValoCity smoke runs completed at
  Vulkan 108.42 FPS / 9.22 ms / p95 11.43 ms and D3D11 109.52 FPS / 9.13 ms /
  p95 11.39 ms. Raw CSVs are under `build/verification/renderer-*`.
- Limitations: this is a performance A/B only. Visual parity, D3D12/OpenGL
  availability and a long-route comparison still require validation.

## 2026-11-25 — Public project description and scope

- Scope: README, documentation navigation and project identity; no engine or
  physics code changed.
- Intent: make the repository understandable to new contributors and clearly
  distinguish the initial OpenSLRR DX11 fork from the independent SLRR New Age
  project.
- Changes: updated `README.md` with the current direction, measured ValoCity
  baseline, validation snapshot, renderer status and honest roadmap; added the
  independent project identity page and generated SLRR New Age banner; linked
  the development log from the documentation index.
- Build: not required; documentation-only change.
- Runtime validation: not applicable. Existing Vulkan stress evidence remains
  recorded above and in `docs/rendering/performance.md`.
- Limitations: performance figures are hardware- and settings-specific; they
  are baselines, not a release guarantee.

## 2026-11-25 — Optional visual performance preset

- Scope: renderer options and benchmark tooling only; physics, fixed-step time,
  vehicle state and contact ordering are intentionally untouched.
- Intent: provide a reversible A/B path for reducing city rendering cost while
  the default visual quality remains unchanged.
- Changes: added `--render-performance` to the host and the FPS/monitor scripts.
  The preset adjusts map-prop LOD/culling, reflections, clouds, AO resolution
  and secondary shadow budgets.
- Build: configured and built the clean Git checkout with CMake/MSVC Release;
  `build/Release/slrr_host.exe` completed successfully. The first build also
  rebuilt bgfx, Tint, shaderc, SDL and generated shaders.
- Runtime validation: private ValoCity drive, Vulkan, 1280x720, no VSync. The
  preset produced 119.6 FPS / 8.38 ms over the last eight measured windows;
  physics remained around 3.2–4.7 ms and the log ended with
  `section=java.game.Valocity` and `drive done`.
- Evidence: raw files remain ignored under `build/fps-goal/`, including the
  `fps-20261125-053037` CSV and logs.
- Limitations: this is a short A/B sample and visibly trades distant detail and
  effects for frame time. It is opt-in and not the default profile; visual
  comparison and a longer stress run are still required before recommending it
  as the standard city preset.

## 2026-11-25 — Route Track camera changes through C

- Scope: keyboard input and Track camera selection; vehicle physics, scripts
  and save data are unchanged.
- Intent: remove the F1 camera conflict and make C the single selector for
  Track camera modes, including all camera points exposed by the current car.
- Findings: the installed `Track.class` registers F1–F5 for internal, TV,
  external/follow, chase and inverse chase. The installed `ControlSet.class`
  also maps F1/F2 to `AXIS_LOOK_PREVNEXT` and F5 to `AXIS_LOOK_REAR`.
- Changes: C sends the native Track camera commands and reads the car's
  `GII_RENDER` camera count to step through all internal camera points. The
  host consumes F1–F4 and suppresses their ControlSet axes; F1 toggles photo
  mode only while free flight is active. F5's rear-look action remains
  separate from the C camera cycle.
- Build: passed with `cmake --build build --config Release --target slrr_host`.
- Runtime: the New Age host opened ValoCity in Vulkan. The city log records C
  transitions and F1 being consumed at the host input boundary; final manual
  confirmation that F1 cannot reach any Track camera handler remains pending.
- Evidence: `build/camera-controls-city.out.log`; the older run records the
  repeated C transitions. Fresh logs remain ignored under `build/`.
- Limits: verify F1 outside/inside flight, C through each internal point and
  Track mode, and F5 rear-look after the next launch.

## 2026-11-25 — Make free-flight look independent of mouse buttons

- Scope: free-flight camera input and HUD rendering; no vehicle physics,
  gameplay scripts, save data, audio or content assets changed.
- Intent: make mouse look active without right-click, assign E/Q to camera roll,
  adjust flight speed with the wheel, and ensure photo mode hides the minimap.
- Changes: raw relative mouse input is captured while free flight is active;
  E/Q apply roll around the view axis while mouse controls yaw/pitch. Wheel
  changes movement speed. The map is rendered by a separate camera preview at
  viewport priority 12, so photo mode now skips that preview and OSD drawing.
- Build: passed with `cmake --build build --config Release --target slrr_host`.
- Runtime: the rebuilt New Age opened directly into ValoCity under Vulkan;
  the user confirmed mouse look works without a button. A previous run showed
  the minimap remained visible, which led to identifying its separate
  viewport-12 camera-preview path and filtering it in photo mode.
- Limits: final visual confirmation that F1 hides the minimap after this fix,
  and E/Q roll direction still need an in-game check.

## 2026-11-25 — Add discrete free-flight speed multipliers

- Scope: free-flight movement speed and its OSD indicator; no vehicle physics,
  world scripts, saves, audio or assets changed.
- Intent: provide precise slow movement and a much higher top speed using the
  mouse wheel while free flight is active.
- Changes: wheel detents select discrete multipliers from x0.01 through x512;
  partial wheel deltas accumulate until a full detent. The flight OSD displays
  the selected multiplier. Outside flight the wheel remains camera zoom.
- Build: passed with `cmake --build build --config Release --target slrr_host`.
- Runtime: the rebuilt New Age opened directly into ValoCity in Vulkan; the
  running window is `OpenSLRR - Vulkan`.
- Runtime validation: the user confirmed the wheel multipliers behave as
  requested. Low-speed precision, maximum-speed travel and the label are not
  separately measured.
- Limits: test the lowest and highest levels on a long open stretch; avoid
  interpreting the configured multiplier as a measured travel speed.

## 2026-11-25 — Release free-flight mouse when the game loses focus

- Scope: Win32 window focus and free-flight cursor handling; camera mode and
  vehicle simulation are unchanged.
- Intent: prevent the system cursor from remaining clipped when the player
  switches from the windowed game to another application.
- Changes: the one-pixel `ClipCursor` region is now synchronized only while the
  New Age window is foreground. Losing foreground releases the clip and ends
  the host's camera cursor capture; returning to the game can capture it again.
- Build: `cmake --build build --config Release --target slrr_host --parallel 8`
  completed successfully with Visual Studio 2022 Build Tools.
- Runtime validation: not yet repeated interactively across an application
  focus switch; source path and Release compilation are verified.
- Limitations: confirm windowed free flight, Alt+Tab away/back, and normal
  cursor movement after the next interactive launch.

## 2026-11-25 — Give game menus the mouse during free flight

- Scope: OSD interaction and free-flight cursor capture; camera movement and
  vehicle simulation are unchanged.
- Intent: pressing Escape or opening another pointer-driven menu while flying
  must release the system cursor so the player can operate the interface.
- Changes: the OSD registry now detects visible menu/dialog hit targets above
  gameplay HUD layers. Free-flight capture yields to those controls, modal and
  loading UI, video playback, and the debug overlay. Escape and UI click paths
  resynchronize capture immediately; flight remains enabled behind the menu.
- Build: `cmake --build build --config Release --target slrr_host --parallel 8`
  completed successfully with Visual Studio 2022 Build Tools.
- Runtime validation: Release compilation passed; the Escape/menu mouse path
  still needs an interactive check.
