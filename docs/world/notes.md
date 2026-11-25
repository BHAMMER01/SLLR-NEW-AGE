# World, maps and pedestrians: issue notes

Verified notes on map placement, garage shells, pedestrians and shared
races, moved from the knowledge base. The traffic and race audit is in
[traffic-races.md](traffic-races.md).

## Player pedestrian: first native runtime pass

The player can use F to leave the controlled car at up to 3 m/s. The host
creates a separate RenderRef using a pedestrian type registered by the active
GroundRef, places its feet on the sampled city floor beside the driver's side,
and suspends the car's physics while the player walks. WASD moves relative to
the active camera, Shift runs, Space jumps, and F returns to the parked car
within 3 m. On return, the host removes the player actor, restores the seated
driver and the car's prior physics-suspension state. The player actor is kept
in the GC root set and is removed during map unload.

Animation: the native walk clip plays while walking and stops when idle; no
get-in/get-out clip is played. Exit and entry are instant swaps of the actor,
as the game itself hides the seated driver render. The Godot
`vehicle_get_out_a` / `vehicle_get_in_a` conversion
(`tools/godot_glb_ped_to_matrixdata.py`,
`scripts/generate_ped_transitions.ps1`, `build/ped-transition/<family>/`) is
kept only as an unused asset experiment; the runtime no longer binds it.

Camera: on exit the host hands the script camera's `follow_vehicle` slot from
the car to the player actor (`anchor_onfoot_camera`) and `part_camera_pose`
answers with the actor's world frame, so the native chase camera (distance
spring, mouse orbit, collision sweep) follows the pedestrian. Unlike the car,
a pedestrian must not inherit the target heading: the mesh faces +Z and the
player turns to a camera-relative movement direction, so deriving the azimuth
from the body would chase its own yaw (the view spun when walking forward and
when strafing). `GameRefState::follow_azimuth` therefore holds the ped's eye
azimuth (set behind the actor on exit) and only the mouse orbit changes it;
the heading-derived azimuth and its tractrix tow stay car-only. Re-entry
restores the saved camera fields (`restore_onfoot_camera`), so the slot returns
to the controlled vehicle. `target_point` still cannot drive RenderRef nodes;
the follow slot is the supported path.

Facing: the human mesh's front is its +Z axis (`PedestrianLines::spawn` uses
`heading = (sin yaw, cos yaw)`), while the car's front is -Z. The player yaw
therefore uses `atan2(dx, dz)` for movement and `atan2(-car[8], -car[10])` on
exit; using the car convention made the actor walk backwards. The mesh matrix
itself is built like the crowd actors (`place_player_pedestrian`).


## Garage lifetime correction (#122)

Boot no longer loads G1 meshes unconditionally into the renderer's permanent
ScenePart list and the global static collision cache. Garage.java selects its
GroundRef and stuff RenderRef from garageIndex; the normal resource/scene path
owns their lifetime. The boot copy had no world owner and was drawn whenever
the garage viewport was active, including G2/G3/ROC, and entered reflection
captures as well. Its collision triangles also survived garage changes.

The patch removes this duplicate preload rather than adding garage-name checks
or deleting cached resources still owned by a live scene. Resource decoding
continues through natives_resref and scene_instances. No Java changes.
Release x64 compiles and knowledge reference validation passes (219 references).
No in-game validation is claimed yet. Test initial G1, then use fastpromotion
for club garages and letmeroc for the ROC garage; inspect walls, floor/lift,
props and reflections for old G1 geometry. Confirm the car remains supported
by each active garage's collision geometry and that returning to G1 works.
Issue #93 / PR #121 is independent of the garage lifetime correction.

### Garage shell follow-up: obsolete exclusion removed

User testing of #122 exposed missing garage shells after removing boot G1.
spawn_ground_shell still explicitly skipped model paths containing "garage",
assuming the boot preload owned them. Remove that exclusion: the selected
GroundRef now owns its POLY/render shell and collision override, like other
maps. Keep the boot preload removed. The user reports improved city shadows
with that removal; the causal rendering mechanism has not been isolated.

Read-only integration test against local game/misc/garage.rpk: G1 (0x7a),
G2 (0x06), G3 (0xc7), ROC (0x2f) each attach and collect one shell; repeated
spawn does not duplicate it. Before a61b1ba: 0/4 pass; corrected: 4/4 pass.
Run `./scripts/run_save_io_tests.ps1 -Suite garage_shell` (requires game assets),
and add `-BaselineRef a61b1ba` for reproduction. No saves or game files changed.
Release x64 rebuilt successfully. Full visual/collision validation in G3 and
ROC remains pending; the test checks scene attachment, not GPU output.

## Standalone map placements (#134)

spawn_ground_shell previously registered native placements only for secondary
grounds or primary grounds with exterior-map references. This silently excluded
standalone TestTrack and ROC, despite their placement tables being parsed.
Register placements for every attached ground shell; exterior references still
control traversal of additional maps. Existing render-id cache and attached-shell
checks prevent duplication. No Java edits or per-track special cases.

Read-only integration tests use local game assets and the production resource
index, ground decoder, shell attachment and scene collection. TestTrack reports
1413 placements / 1435 render instances; ROC 1791 / 1791. Before 933cf0a neither
registered its props (0/2 passing); corrected both register and supply resident
meshes (2/2 passing). Repeated attachment keeps the shell count unchanged.
Evidence: assets/validation/map-props. Run
`./scripts/run_save_io_tests.ps1 -Suite map_props`, optionally with
`-BaselineRef 933cf0a`. These tests require game assets; no saves are modified.
Release x64 compiled; knowledge references 219 checked, zero errors.
In-game validation remains pending: inspect poles/objects in TestTrack and ROC,
reenter the maps, and verify frame time and collisions now that props exist.
The scripted trigger/race progression issues are separate.

### Track structures casting shadows (follow-up to #134)

User confirms standalone native placements appear. The tower/stairs remain
unshadowed because they belong to the ground POLY itself, excluded wholesale
from the static shadow caster pass. Ground POLY now casts as well as receives;
vehicle, sky, skinned and light exclusions remain. Fragment receiver bias now
uses the depth gradient in shadow UV coordinates over the PCF footprint rather
than derivatives measured in screen pixels. This is intended to avoid terrain
self-shadow grids when including the ground; the cap is 0.004 normalized depth.
Potential tradeoff: excess bias can detach fine contact shadows, especially at
shallow angles. Visual validation is required before merge.

Release x64 and embedded DXBC/GLSL shaders compile. Knowledge references: 219
checked, zero errors. No GPU visual test was performed by the agent. Retest
TestTrack tower/stairs and adjacent apron for shadows/acne, then Valo buildings
and roads. These rendering checks are separate from placement integration tests.

## Character animation pause (#128)

Character pose rebuilds used gameref_now (wall time), while pedestrians moved
with the JVM simulation clock. With timeWarp(0), their world position stopped
but skinning continued. The main loop now publishes jvm.sim_time to character
animation immediately after advance_sim_time; all six character pose/bone/palette
read paths sample that clock. Pause and time scaling therefore match physics,
without adding the paused wall interval on resume. UI timers/orbit clocks are
unchanged. No Java changes. This applies to character animations, not FMVs.

Release x64 compiled; source audit confirms no remaining gameref_now calls in
character.cpp. Knowledge references: 219 checked, zero errors. No automated
animation playback or agent in-game validation is claimed. Manual check: in
Valo face a walking pedestrian, pause for several seconds, confirm limbs are
frozen, resume without pose catch-up, then repeat. Also check mechanic/driver
animations during normal play. Save/section changes should remain functional.

### Pedestrian worker after pause (PR #136 follow-up)

User reports walkers blocking each other after pause, near the first garage.
Direct deterministic crossing checks pass without changing avoidance forces.
Inspection found the worker cleared posted before calculating a step, allowing
another pre-result snapshot to be queued. A result can also become ready between
the main thread's consume and submit locks. Keep posted through calculation,
clear it only on result publication, and defer submission while posted OR ready.
Zero-duration (pause) ticks consume results/update poses but submit no new job.
This prevents stale snapshots and zero-time jobs from rolling back movement.

Release x64 rebuilt. Twenty head-on crossings on real city.walk corridors pass;
these are avoidance regression checks, not proof of the worker race fix or the
specific first-garage encounter. No adjustment to avoidance weights, density or
freecam range. In-game retest remains necessary: watch first-garage pedestrians,
pause/resume repeatedly, then watch opposing pairs pass. Freecam behavior was
explicitly deferred by the user. Knowledge check: 219 references, zero errors.

## Shared race support (#179; #60, #61, #62)

Road ownership and cache: `src/resources/race_runtime.cpp:race_ground_roads`;
directed TRC solver: `src/resources/road_routes.cpp:RoadRoutes`;
traffic identities/streaming/halts: `src/resources/traffic_runtime.cpp:race_traffic_tick`;
brain commands: `src/resources/race_brain.cpp:race_brain_command` and
`race_drive_input`; mechanical input integration:
`src/resources/part_runtime.cpp:configure_drive`; route ribbon:
`src/natives/natives_renderref.cpp:plotRoute`.
Sources and host limits: EXTERNAL_RESEARCH v221 section and scripting/runtime.md shared
race section. Tests: road_routes, race_brain, traffic_runtime and race_vehicle.
A real assembled Baiern moves under original Bot.startRace commands in an
isolated fixture; this is not proof of finished career day/night/ROC sessions.
A brain outside traffic finds its ground through the car's parents
(`src/resources/race_brain.cpp:car_ground`): nothing tags a script GroundRef or
native map with the GroundRef kind at run time, so before #226 day, quick and
night race opponents and pursuing police got no route and never moved.
The original issues and #179 were closed for consolidation, not gameplay acceptance;
#197 retains the remaining work. The [current audit](traffic-races.md)
records the baseline's missing chassis pairs/player-only movable contacts, the
shared-contact implementation and remaining physical/kinematic, seating/audio
limits. Contact integration is not acceptance of the complete #197 checklist.
