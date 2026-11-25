# SLRR New Age — current-state audit

Date: 2026-11-25

This audit revisits the repository after the New Age boot, input, renderer,
benchmark and compatibility changes. It is an inventory and evidence map, not
a claim that the whole original game is complete.

## Repository shape

The checkout currently contains 1,104 tracked/untracked files visible to the
source inventory: 105 C++ implementation files under `src/`, 75 public headers
under `include/`, 85 test sources under `tests/`, 15 validation/build scripts,
and 44 documentation files. The recent history is concentrated on 2026-11-25,
with the latest committed changes covering research corpus import, controls,
cruise-control routing, boot flow, and validation reports.

The only current working-tree edits are the wheel-release trace in
`src/resources/part_runtime.cpp` and its evidence section in
`docs/research/stress-controls-validation.md`. Both are diagnostic-only and
are guarded by `SLRR_WHEEL_TRACE=1`.

## What is confirmed by current evidence

- Release x64 builds complete with MSBuild and produce
  `build/Release/slrr_host.exe`.
- The direct-city path reaches `java.game.Valocity`; the controlled
  city-to-garage return path also exits normally.
- Vulkan city benchmarks are consistently above the 60 FPS floor. Saved-profile
  runs are about 110–112 FPS (roughly 9 ms average frame time); the opt-in
  render-performance profile reaches about 115 FPS in the longer sample.
- The recorded manual route is preserved at
  `build/verification/player-route-4.bin` and replays deterministically at
  112.06 FPS with no host crash.
- External telemetry measured multiple active CPU cores, working-set RAM and
  engine GPU/frame zones. The result is not a single-core-only limitation.
- The fixed-step dynamics fixture, wheel-mount calculations, contacts and
  input-layer tracing have standalone or runtime evidence. The cruise-control
  conflict fix routes physical `P` to cruise and `S` to brake/cancel.
- Stock and MethanolFuel resource readers accept the measured RPK/TUFA corpus;
  SCX/DDS geometry and texture submission paths have been exercised.
- The project identity is now explicit: initially forked/inspired by OpenSLRR,
  but maintained as the independent SLRR New Age continuation.

The renderer selector was extended from the previously exposed `auto|vulkan`
pair to `auto|vulkan|d3d11|d3d12|opengl`, reusing bgfx's existing embedded
shader profiles. A matched 20-second ValoCity smoke comparison completed both
explicit paths: Vulkan averaged 108.42 FPS (9.22 ms, p95 11.43 ms) and D3D11
109.52 FPS (9.13 ms, p95 11.39 ms). These are short A/B results, not a claim
of equal visual output; screenshot and longer-route comparison remain needed.

## What is implemented but not fully proven

- The control patch contains the requested WASD, shift/control, clutch, nitro,
  horn and `P` defaults, but saved user profiles can override them and several
  action-level effects still lack state assertions beyond physical key delivery.
- Vulkan is measured. D3D11 is available through the same bgfx backend, but a
  same-machine, same-route D3D11 comparison is still required.
- The MethanolFuel run proves resource loading and parser coverage, but not a
  clean visual garage/city acceptance pass for every vehicle, shader and scene.
- `Dialog.class` kind 2 is diagnosed in the TUFA reader and decompiler, but a
  safe production decoding change has not been accepted.
- The standalone physics model passes deterministic tests, while parity with
  the original game's handling, damage and long-session behavior remains open.
- The manual wheel loss is not reproduced by the transform-only replay. The
  new wheel trace proves that no mount-release event occurred in that replay;
  it does not capture the original input and damage event history.

## Current technical bottlenecks

The measured city frame is not dominated by one saturated CPU core. The main
remaining budget is render-thread submission/flush, scene draw count, vehicle
and traffic collection, and occasional isolated frame spikes. The 16.67 ms
target is met on average but not on every worst frame. Audio asset failures are
also visible in benchmark logs and should be treated separately from graphics
performance.

## Next analysis order

1. Run identical saved-profile Vulkan and D3D11 route benchmarks and compare
   frame zones, draw/instance counts and worst windows.
2. Add action-level control assertions for throttle, brake, steering, gear,
   clutch, nitro, horn and cruise state.
3. Extend route capture with input and wheel/damage events, then replay the
   manual wheel-loss case with `SLRR_WHEEL_TRACE=1`.
4. Complete the MethanolFuel garage/city visual acceptance pass and catalogue
   the missing exhaust texture separately from parser success.
5. Resolve the Dialog kind 2 format with a fixture-based parser test before
   changing production decoding.
6. Keep the default simulation unchanged while profiling submission, LOD,
   streaming and worst-frame spikes; do not claim 120 FPS constant until a
   long route has p95 and worst-frame evidence.

Multiplayer remains intentionally outside this audit and current phase.

## Tools ported from the Brazil/Godot workspace

Two read-only diagnostics were added to the New Age tree after reviewing that
workspace: `scripts/inspect_rpk.py` reports RPK dependencies, entry metadata,
GroundRef candidates and out-of-range payloads; `scripts/inspect_obj_mesh.ps1`
reports OBJ vertex/face/material counts and per-axis bounds. They preserve the
useful inspection ideas without importing Godot, old binaries or a second
runtime. The existing New Age SCX/DDS analyzers remain authoritative for native
game assets; the OBJ tool is for converted/external meshes only.
