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

## 2026-11-25 — Isolate and correct the on-foot camera orbit

- Scope: player-pedestrian camera pose, orbit input and camera collision only;
  vehicle handling and the simulation contract are unchanged.
- Intent: make mouse movement intuitive in both axes, keep the camera locked
  to the pedestrian, and stop camera motion from popping at floor seams.
- Trace: an opt-in runtime trace showed the active fullscreen camera following
  the live `RenderRef`; raw mouse deltas reached that camera and updated its
  orbit. `angle_gain` and `follow_hold` were both zero, disproving the earlier
  inherited-angle-force hypothesis. The renderer converts world Z before
  constructing a left-handed BGFX view; the shared car follow path also applied
  its spring and collision sweep to the pedestrian.
- Changes: added `GameRefState::camera_on_foot` and a dedicated direct orbit
  branch for the pedestrian. It bypasses car follow smoothing/held-angle
  behavior, uses separate yaw and pitch signs, keeps the 1.55 m shoulder aim
  and 4.4 m start distance, and excludes floor/ceiling triangles from camera
  collision while retaining wall collision. `OnFootCameraSave` restores the
  prior camera mode; `C` cannot switch away from the pedestrian.
- Build: `cmake --build build --config Release --target slrr_host --parallel 8`
  passed.
- Runtime validation: Release `slrr_host.exe` opened ValoCity with Vulkan and
  VSync enabled. The user confirmed that the camera now turns as intended.
  The preceding no-VSync run showed screen artifacts during movement; the
  latest run used VSync, but the artifacts were not captured separately for QA.
- Evidence: raw camera trace stayed under ignored `build/Release/` files;
  temporary trace code was removed after identifying the active path.
- Limitations: no automated visual regression fixture exists for pedestrian
  orbit or camera collision.

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
## 2026-11-25 — Native player pedestrian mode (first runtime pass)

- Scope: New Age host input, pedestrian rendering/animation, player camera,
  controlled-car physics suspension and map-unload cleanup. No Java scripts,
  save data or external Godot project files changed.
- Intent: port the Godot on-foot interaction to New Age using a pedestrian
  type already registered by the active map.
- Changes: F exits the controlled car at up to 3 m/s and re-enters within 3 m;
  the actor spawns by the driver side on the sampled floor, follows the active
  camera, uses WASD/Shift/Space, and suspends the car while on foot. The seated
  driver is hidden during the mode and restored on return. Actor is GC-rooted
  and removed with the world.
- Animation: native walk clip remains active between interactions. A tracked
  converter retargets the Godot `vehicle_get_out_a` and `vehicle_get_in_a` GLB
  clips from the GTA `SKEL_*` rig onto each New Age `Bip01` pedestrian rig;
  the host resolves loose `.matrixdata`/`.bon` assets beside the executable,
  plays exit/entry clips as one-shots, and resumes walking or restores the car
  after the corresponding clip. The reproducible converter is
  `tools/godot_glb_ped_to_matrixdata.py`; run
  `scripts/generate_ped_transitions.ps1 -GameRoot "<game root>"` to generate
  all six families under `build/ped-transition/<pedestrian-family>/` from the
  local Godot asset set.
- Validation: production C++ parsers accepted all 16 generated clips (six
  pedestrian families, two clips each, 25 matching tracks per clip; the
  remaining four root-level clips are compatibility/prototype outputs). The
  Release host build passed. Retarget pose, timing against vehicle placement,
  and the complete F interaction have not yet been visually approved in-game.
- Build: `cmake --build build --config Release --target slrr_host --parallel 8`
  passed after resolving an initial link-scope error.
- Runtime validation: not run in-game. The user-facing F workflow, camera
  follow/orbit, character placement and return path still need interactive
  validation in ValoCity.
- Limits: requires the active GroundRef to have registered at least one usable
  pedestrian type and the matching generated transition files alongside the
  executable. Missing files fall back to walking on exit and immediate car
  restoration on entry. In-game transition visuals remain unverified.

## 2026-11-25 - On-foot camera follows the pedestrian (free look, no spin)

- Scope: player-pedestrian camera only. No vehicle physics, scripts, saves or
  rendering pipeline changes.
- Intent: F must anchor the camera on the actor that leaves the car, return it
  to the vehicle on re-entry, turn with the mouse without the right button
  (drone-like), and never spin. The Godot get-in/get-out clips are no longer
  used on entry/exit.
- Changes: `anchor_onfoot_camera` hands `GameRefState::follow_vehicle` to the
  actor's live id; `part_camera_pose` answers a RenderRef with the player's own
  position/yaw (not the car's scene tree); `GameRefState::follow_azimuth` keeps
  the ped eye azimuth and only the mouse orbit changes it, so a ped that turns
  to its camera-relative movement direction no longer chases the camera's own
  yaw; `sync_free_camera_mouse` also captures while `player_on_foot`, giving
  free look without the right button (drone sign convention); entry restores
  the saved camera fields and removes the actor. Removed the unused transition
  clip binding and the door/get-in sequence.
- Facing fix: the human mesh faces +Z (`heading = (sin yaw, cos yaw)`), the car
  faces -Z. Player yaw now uses `atan2(dx, dz)` and `atan2(-car[8], -car[10])`;
  the previous car convention made the actor walk backwards.
- Build: `cmd /c build\build_onfoot_door.bat` (MSVC 2022 BuildTools + VS 18
  CMake, Release x64, target `slrr_host`) passed.
- Runtime: automated ValoCity runs (`--auto-city`, Baiern 0x6, Vulkan) log
  `[onfoot] entered native pedestrian mode (camera follows ped...)`, then
  `follow == actor`, a stable eye distance (~4.2 m) and a fixed `camyaw`
  while W/A/D are held (`[onfoot-trace]`), then
  `[onfoot] camera back on vehicle` and `[onfoot] returned to controlled car`.
  A separate run with only mouse deltas injected and no right button is pending
  interactive confirmation.
- Limits: on-foot mouse capture pins the cursor, so HUD pointer clicks are not
  available while walking; the actor yaw snaps to the movement direction
  without turn smoothing; visual approval of the on-foot view is still
  interactive.

## 2026-11-25 - On-foot camera keeps ownership (C ignored, cockpit reset)

- Scope: player-pedestrian camera ownership and input only. No physics,
  scripts, save data or render changes.
- Intent: pressing C while on foot must not take the view off the pedestrian,
  and leaving the car from the internal (cockpit) camera must still chase the
  actor.
- Changes: `host_input_check_hotkeys` ignores C while `player_on_foot` and logs
  `[camera] C ignored: on foot`; `OnFootCameraSave` now stores `cockpit_index`,
  `anchor_onfoot_camera` clears it to -1 (the RenderRef path has no cockpit),
  and `tick_player_pedestrian` re-asserts `follow_vehicle` to the actor
  (variant 0, not attached) whenever a script or camera command retargets it,
  leaving orbit and distance untouched.
- Build: `cmd /c build\build_onfoot_door.bat` (MSVC 2022 BuildTools, Release
  x64, `slrr_host`) passed.
- Runtime: automated ValoCity run pressed C twice in the car, then F and C
  repeatedly on foot. The log shows six `[camera] C ignored: on foot, camera
  stays on the pedestrian` lines and `[onfoot-trace] follow == actor` with a
  stable ~4.2 m eye distance for the whole walk; no pose loss.
- Limits: on-foot camera modes are fixed (no per-mode distance); visual
  approval remains interactive.

## 2026-11-25 - On-foot framing and skinned character shadow reception

- Scope: RenderRef follow-camera framing and skinned character lighting only.
  Vehicle camera and global scene-shadow settings are unchanged.
- Camera: increased the on-foot start distance to 4.4 m, zoom range to
  2.4–8.5 m, shoulder-height target anchor to 1.55 m and follow response to
  9/s. The camera offset/elevation is preserved; only its aim point moves up.
- Lighting: the skinned path marks character fragments, does not receive the
  dynamic scene/car shadow maps or screen-space AO, and gets a 22% diffuse-sun
  ambient fill. Skinned actors continue to cast shadows onto the world. This
  avoids the broad false self-shade visible on the body and keeps its back
  readable without changing car or terrain shadows.
- Mouse: Win32 reports positive raw deltas for right/down. Free flight rotates
  its view direction directly, while on-foot mode moves the camera eye around
  its target; these coordinate frames need opposite signs. The previous shared
  free-flight sign inverted the on-foot orbit.
- Drone isolation: car and pedestrian controls are cleared while flight is
  active, both at input polling and at their simulation consumers. This also
  covers the toggle frame; F cannot enter or exit pedestrian mode during flight.
- Build: Release `slrr_host` and the DXBC, GLSL and SPIR-V shader variants
  passed. `scripts/check_knowledge_refs.py` passed with 665 references and no
  errors.
- Runtime: the Vulkan New Age build opened ValoCity. Mouse polarity, the
  raised shoulder anchor and no-motion input while flying need in-game
  confirmation in the latest relaunched build.
## 2026-11-25 — Document camera architecture and cockpit-to-ped ownership

- Scope: camera lifecycle and selection, Track modes, vehicle CFG cameras,
  pedestrian orbit, New Age free flight, auxiliary preview cameras and input
  ownership. No vehicle physics or stock scripts changed.
- Documentation: added `docs/ui/cameras.md` as the end-to-end camera reference;
  indexed it from `docs/README.md`, linked it from `README.md`, and connected
  it to `docs/ui/notes.md`. It records object creation, activation, reuse,
  hiding/destruction, camera selection, pose dispatch, input routes and the
  per-mode validation matrix.
- Trace: `fullscreen_script_camera` had a special world-ownership lookup for
  cockpit cameras, but did not resolve a followed target for `camera_on_foot`.
  Leaving a car from a cockpit view clears `cockpit_index` and retargets the
  camera to a pedestrian `RenderRef`; without using that actor to validate
  world ancestry, the main-camera selector rejected the camera and the frame
  retained only the clear color and HUD.
- Change: the selector now resolves the followed live target for both cockpit
  and on-foot states, requires a RenderRef for the latter, and checks the
  target's transform in the selected world. The saved cockpit index is restored
  on re-entry to the car.
- Validation: pending Release build, camera-mode round-trip automation, and
  documentation reference check. The matrix covers Baiern CFG camera indices
  0–4 plus Track TV, follow, chase and inverse-chase; it does not prove all
  vehicles, saved input profiles, Track point/free modes or rendered pixels.

