# Vehicles, parts and driver: issue notes

Verified notes on physics bodies, steering, stock part data, the
dashboard, nitrous, opening panels and the seated driver. The driving
model is in [driving-model.md](driving-model.md); the physics clock and
engine calibration in [physics-tick.md](physics-tick.md).

## Per-body physics failure containment (#75)

The rigid-body kernel deliberately throws on invalid mass/bounds/orientation,
non-finite frames and non-finite integration state. Keep those kernel checks:
the owning runtime now contains failures at each chassis, loose-part and free
PhysicsRef body rather than allowing a frame pump to unwind a Java dialog or
terminate the host. std::exception failures are reported and handled locally.

Chassis configuration is transactional (configure/set_frame on a candidate).
An invalid chassis is suspended with physics_pending_placement cleared; a step
failure restores its saved rigid body and the last finite local pose, resets
motion and interpolation and leaves other chassis ticking. Pose orientation is
reconstructed as in dynamics_sync. With no valid pose to restore, the node is
hidden. The normal start/wakeup path can retry simulation; unchanged bad data
will suspend it again. A chassis failure is logged once per record lifetime.

Loose-body creation also configures a candidate. Failed native map promotion
cleans partial nodes, keeps the ordinary scenery and suppresses repeated retries
for that resource until the part runtime is reset. A failed active loose body
is removed; a promoted map prop returns to its authored placement. A failed free
PhysicsRef restores its last published finite pose and is removed from simulated
bodies. Failed loose/free contact steps restore the collision partner's saved
rigid body too. These guards do not roll back arbitrary script/asset mutations
or promise recovery from allocation failure.

GameRef.setMatrix rejects non-finite position/rotation before mutation. WheelRef
setters reject non-finite scalar or Vector3/Ypr fields atomically; finite values
retain their existing semantics. Numeric overflow generated later in the solver
is caught before an invalid body frame is published. Free bodies now have an
explicit first-configuration flag (live_id can legitimately still be zero), and
free-body state plus failed-native-type suppression reset with part registration.
No native signature is added; the kernel and normal physics tick remain intact.

Validation: physics_recovery is 0/8 passing on f3638a1 and 8/8 on the fix. Its
isolated synthetic RPK/CFG/SCX fixtures cover NaN poses, malformed free-body
bounds, invalid free frames, zero-height chassis bounds, corrupted chassis
pose/orientation, wheel updates, extreme finite velocity overflowing the render
frame, and transactional invalid map-body creation. A native pump callback
returns after the numerical failure while a healthy chassis keeps ticking.
This is not an automated real Dialog.display test. Active detached-panel failure
and contact-partner rollback paths are implemented but not separately fault-
injected by this suite. map_props and physics_position regressions pass. The
Release build and native audit checks pass. In-game driving/collision/dialog
smoke validation is pending. Evidence: assets/validation/physics-recovery.

## Initial garage steering (#125)

The setsteer command updated steering_input/request but placed attached parts
using the existing dynamic hub matrices. The steering wheel read the new scalar
while the wheels kept the prior pose until another operation recomputed it.
When dynamic_frames are already available, setsteer now calls pose_wheels,
which rebuilds steered/rolling frames from the current suspension state and
places/relinks the assembly. It does not integrate physics, change chassis pose,
repark the car or reset wheel spin. Before dynamic frame initialization the
existing rest placement path is preserved; later parking reads the saved steer.

Release x64 compiles; knowledge references 219 checked, zero errors. Source
trace: Garage.java sends setsteer -0.7 on entry and mechanic-mode changes.
No automated assembled-vehicle regression or agent in-game validation claimed.
Manual check: enter/load the garage and inspect wheel braquage before touching
any part; change mechanic modes and return from catalog/dealer, then confirm
normal driving steering still works. Notes stay in this file.

## Anti-roll bars: stock data behind the catalog branch (#300, PR #307)

Read-only scan of `game/parts.rpk` (RPAK TOC; the 16-byte TOC header sits after
the dependency table, as in `src/resources/rpk_index.cpp:RpkIndex::parse_rpak`):

- The stock RPK already holds 48 bar resources. They hang under
  `0x0220 "anti-roll"` → `0x021F "_hidden_"` → `0x0019 "runinggear"`, in nine
  brand folders `0x00DC..0x00E4` (Baiern … Shimutshibu). The stock Catalog only
  browses `0xF229` (Suspensions), so the hidden branch never showed. PR #307
  adds `parts:0x0220r` as a second root of the Running Gear/Suspension page;
  no RPK byte changes. `0xF232 "anti-roll"` under Shocks is an empty folder.
- The brand folders live in parts.rpk, so the Catalog's car-pack filter
  (`id() >> 16` against car packs) never hides them: every car sees all 48 bars,
  as it already does for the Suspensions brand folders.
- Each bar RSD is `script parts\running_gear\scripts\sways\swaybar_*.class` +
  `native part parts\running_gear\scripts\swaybar.cfg`. That CFG has
  `compatible 0x00004000 1`; `parts:0x4000` is the base class node
  `Swaybar` (`script java.game.parts.rgearpart.Swaybar`). Car mounts use
  `attach 0x00044000 1`, dependency 4 = parts.rpk. Fit is therefore generic:
  any bar fits any 701 (front) / 702 (rear) mount; the front/rear in the name
  is not a restriction.
- Only ten stock chassis CFGs author mounts: Duhen ×4 (701+702), Focer ×3
  (701+702), Einvagen ×3 (701 only). Other cars can buy a bar but cannot fit it.
- All 48 scripts set `force = 25000`, `damping = 2500`: every bar is
  functionally identical. Stock data also gives the six Ishima bars and the
  Duhen 1.8/2.0/2.2 bars `name_prefix = "Duhen SunStrip 1.5 DVC"`, which the
  patched `Swaybar.calcStuffs` now shows in their names.
- The Java `updatevariables` still has its `addrollbar` commands commented
  out; the host reads `force`/`damping` from the installed part instead
  (`src/resources/part_runtime.cpp:configure_anti_roll`).
- Every stock racer script lists its bars in commented-out
  `stock_parts_list_RGear_sways` lines (Focer RC 300 also `stg_1_`). `Chassis`
  already pushes that list with the other running-gear lists, and
  `src/resources/part_runtime.cpp:add_part` destroys a part no slot accepts, so
  a listed bar without a mount adds nothing. #311 adds the missing mounts to
  the 17 other racer chassis CFGs (Einvagen gets 702 only) and uncomments all
  24 lists. Stock lists that named the wrong bar are corrected: Duhen 1.5 rear
  `0x41FF` to `0x017C`, Ishima Enula WRZ `0x41FF` to `0x0195/0x0196` (stage 1
  `0x0197/0x0198`), WR SuperTurizmo `0x41FF` to `0x0197/0x0198`.
- **The installed MWM 2.2.1 car classes are not built from `sources/`.** MWM
  added stock neons to the NOS branches: five `addPart( parts:0xD2xxr, "<color>" )`
  after the canisters of each branch (`parts:0xD273` Red, `0xD285` Green,
  `0xD288` Blue, `0xD291` Cyan, `0xD294` Aqua, `0xD279` Pink, `0xD276` Purple,
  `0xD282` Orange, `0xD267` Yellow, `0xD270` White; neon RSDs under
  `parts:0xF24B`). The count per branch varies (5, 7 or 8). The SuperDuty top
  branch replaces the four canisters with two bottles (`parts:0xD215` Botle,
  `0xD339` Double Botle), ten neons and `cars.racers.SuperDuty:0xD1` rollbar
  (the RID form must match the `stg_` list one exactly, or the constant pool
  differs). No MWM car
  source ships, and recompiling `sources/` would drop them. The bundled compiler
  reproduces original classes byte for byte (only header bytes 9-11 differ;
  source line numbers are encoded in the tree), so a reconstruction is proven
  by an identical output. The reconstructed sources are in
  `patch/cars/racers/*_data/scripts/src/`; see scripting/compiler.md.
- **The local `game/` may hold an installed patch.** On 2026-11-22 the patch
  (sl, parts and ten car classes) was copied into `game/` for in-game tests, so
  tests that expect stock classes failed there. To test against stock, build a
  hard-linked view whose changed files come from the untouched MWM 2.2.1 copy
  and run the test executable from it; `tests/test_swaybars.cpp` builds its
  patched game view the same way (patched files replace their link, never
  written through).

## Dashboard pins: CFG `cockpit_rpm` / `cockpit_speed` (#301)

- Format, from the MWM executable (SHA-256 `b284a7a5…2b03`, read-only
  disassembly): `cockpit_rpm` (0x00444B60) and `cockpit_speed` (0x00444CB0)
  scan `x y z yaw pitch roll render offset factor low high` with
  `%f %f %f %f %f %f %d %f %f %f %f`. The game's own scanner (0x00553890)
  reads `0x` hex for `%d`, so stock ids parse. Defaults (constructor
  0x004467D1): offset 2.2, factor -0.0005 rpm / -0.02 speed, low -2.2,
  high 2.2. The render is resolved as type 14 against the owning pack.
- Update (0x0043C0A0, mode 1): `angle = value * factor + offset`; below `low`
  it becomes `low`, otherwise above `high` it becomes `high` (no swap). The
  pin is posed at `(yaw, pitch, roll + angle)`, which with
  `src/resources/part_config.cpp:part_pose_matrix` (yaw, pitch, then roll) is
  a turn about the posed local Z axis. Values (0x0045283C): rpm is
  `|engine rad/s| * 9.5493` (0x005F0C14), speed `|velocity| * 3.6`
  (0x005F0C04), the same sources as `osd_rpmpin` / `osd_spdpin`.
- The modding tool's `needles.ts` description (field order, defaults, Z spin,
  km/h) matches the binary. Its "SLRR units, pi = 3.147" remark has no
  counterpart in the engine: the angle goes straight into the roll in radians.
- Stock data: 17 racer cfgs in `patch/` and 24 in `game/` carry both lines,
  all with pin `0x00020037` = `cars:0x37` (`cars\meshes\pin_small.SCX`).
  Enula, Nonus, SuperDuty pitch their pins; Einvagen rests at its `high` 1.5
  because its offset 2.2 is above it.
- OpenSLRR: `include/slrr/part_config.hpp:CockpitNeedle`, parsed in
  `src/resources/part_config.cpp:parse_part_config` (a line without pose and
  render, or with a bad number, goes to `unknown` and does not invalidate the
  cfg), angle in `src/resources/part_config.cpp:cockpit_needle_angle`. The
  chassis (`native_kind == "car"`) gets one RenderRef child per defined pin in
  `src/resources/part_runtime.cpp:render_part`, kept in `Record::needles`, not
  in `renders` (deformation, lamp snapping and HUD bounds must not see a part
  that turns). `src/resources/part_runtime.cpp:pose_cockpit_needles` sets
  their matrix every `part_physics_advance` after the steering column;
  `part_destroy` removes them and `part_visit_gc_roots` marks them.
- Build 606 only updates the pins in a view whose flag `+0x3C` is set and
  destroys them otherwise (0x00452836, view record `car + idx * 0x2B8 +
  0x11C`); the flag is not decoded (probably the internal camera). OpenSLRR
  keeps them on every car with the lines, in every view.
- Tests: `tests/test_cockpit_needles.cpp` (suite `cockpit_needles`): parse
  defaults and limits, stock Baiern (flat) and Enula (pitched) at rest and
  driving, pivot and axis fixed, pins removed with the car.
- Pin material: `cars\meshes\pin_small.SCX` is SCX3 with one group of flags
  `0x101` (SCX3 blend) on `cars	extures\Pin.dds`, a DXT5 card that is clear
  except for the needle. The vehicle path
  (`src/render/bgfx_lighting.cpp:draw_instance`) only sent the SCX4
  transparent bit `0x40000000` and flag-256 flames to its blended pass, so the
  card was drawn opaque: a black square behind each needle. SCX3 blend now
  blends on any vehicle mesh without `light_flags`. In the MWM `cars/` and
  `parts/`, the other SCX3 blend groups are lamp glows (`lampglow.SCX`,
  Focer and Enula light meshes), drawn with `light_flags`, so unchanged.
- In game (`--bench-drive`, ValoCity, Baiern, F1 with the #318 fix): both pins
  show on the dashboard dials at rest, thin needles with no card. The chase
  view and the overlay pins are unchanged.

## Nitrous driving and exhaust (#303, #304)

- Ownership: `src/resources/part_runtime.cpp:configure_drive` takes mapped axis
  31 from the controlled mechanical car. Native remaining starts at zero;
  `reload` fills the script capacity, while refresh only clamps. `Canister.actual`
  remains unchanged script save data. Stock Track reloads on entering driving;
  arbitrary save/load does not preserve the native aggregate. HUD fill is the
  remaining/capacity ratio, only for positive injector consumption.
- Physics: `src/physics/vehicle_dynamics.cpp:VehicleDynamics::step_drive` keeps
  dry torque and accepts an optional wet dyno callback/input, blending after the
  predictive limiter. No #215 dyno or torque-gain correction is copied. The Part
  owner consumes `RPM * .0002 * input * limiter * dt * consumption_nitro` once per
  fixed solver step. The stock injector's nominal RPM/throttle fields are not
  exported. Audio uses the configured one-shot or default `sound:25` once per
  press; release, pause, reset and teardown do not create extra triggers.
- Evidence: direct read-only MWM executable disassembly, SHA-256
  `b284a7a53909d0b9ce59d59ddc11e14df40a7eb74d86fa76efb06305aadc2b03`,
  plus MWM Chassis, Canister, NOSInjectorSystem, Track and ControlSet sources.
  Addresses, version distinctions and upstream checks are in
  [EXTERNAL_RESEARCH §7](../research/EXTERNAL_RESEARCH.md#7-migrating-mechanics-from-slrr_rev).
- Actual authored asset: mufflers resolve `particles:1E` through `MW_Mod:28`
  (`NOS_Flames.SCX`, SCX3 flags 0x101, 48 vertices/16 triangles) and `MW_Mod:27`
  (`NOS_Flames.png`, RGBA8 425x554). Independent SCX parsing and full PNG
  CRC/zlib/filter decode establish alpha 0..209, not an opaque card. PNG uploads
  are premultiplied; only flag-256 transparent vehicle sections use the matching
  blend and no depth write. Flame geometry is excluded from lamp-glass snapping.
- Flag-256 mesh/fake-light visibility uses eligible injection, >1000 RPM,
  throttle >.01 and a shared deterministic 30% simulation-clock pulse. This is
  explicitly not the original per-render-child RNG cadence. Collection and
  cameras do not spend fuel or resample it; paused physics freezes it.
- Baiern's pipe carries two separate `particles:1F` FakeSpot children. All
  placements survive collection. `src/render/bgfx_lighting.cpp:LibBgfxBackend::draw_nitro_flares`
  draws their authored central atlas glow with source depth; they never enter
  physical road-light arrays. The Flares option gates this view-only draw.
  Sizing follows the existing sun approximation, with mode-2 atlas/cm-offset
  evidence from SLRR_rev `2663d686`. Original size units, directional convention
  and ray/ghost fidelity remain unverified; no arbitrary backward rotation,
  floodlight, replacement texture or particle emitter is introduced.
- Regression entry points: `tests/test_nitrous.cpp`, `tests/test_sdl_input.cpp`,
  `tests/test_vehicle_dynamics.cpp`, `tests/test_script_lights.cpp` and the
  `scene_shadow_gpu` nitrous case. Compilation and actual gameplay captures
  must still be reported separately; these sources alone are not pixel acceptance.

## Doors and hoods open with build 606's spring (#327, from #204)

- Before: a script open/close (`Part.flap`, `flap_toggle`) drove the hinge
  with a critically damped servo (9 rad/s): the panel glided to its stop like
  an interpolation. In the original game it visibly shakes.
- Build 606 (read-only disassembly): `flap_toggle` (0x00474B00, switch on the
  command) only sets flag 2 (open) or 4 (close) at joint+0x88, bit 1 being
  the latch (0x0043F280 releases it). The flap solver (0x0043F850; the drive
  at 0x0044030D) adds `gain * (target - edge) * dt` to the free edge's
  velocity, with no damping term there: open targets the edge at
  `0.05 lo + 0.95 hi` of the CFG travel and close the `lo` pose, both with
  gain 60 (0x42700000); otherwise the gain is a per-joint value at +0x34,
  used only above 0.1. Gravity acts on the same edge, so a heavy hood sags
  about 9.81 / 60 m below the target. Not decoded: the term scaled by
  joint+0x7C at 0x0043FF05 (likely a damping), and the CFG field order of
  +0x24 / +0x28 / +0x34.
- OpenSLRR (`src/physics/flap_hinge.cpp:flap_step`, `FlapTuning`): the open
  hold is `script_spring * (0.95 upper - angle) - script_damping * rate`
  (60 s⁻², 2.3 s⁻¹, a host damping ratio near 0.15 in place of the undecoded
  term), the close drive the same spring aimed 0.35 rad through the closed
  pose. The opening counts as finished once the panel has been free for 1 s
  and moves under 0.05 rad/s; the weaker door-check limit applies only then.
- Simulated (Baiern door, 1.134 rad travel): it reaches the stop at 0.25 s,
  falls back to 0.95, returns to the stop at 0.8 s and rests near 1.05-1.08
  by about 1.2 s. The Baiern hood rests near 0.66 of its 0.873 travel. A close
  latches in 0.2 s. Tests: `tests/test_flap_hinge.cpp` (12/12), including the
  overshoot onto the stop and the fall back below the target.

## Driver duplicate visibility (#112)

`DriverSeat` now owns a `GameRefRenderMask`. The duplicate-render mask is rebuilt
when the scene revision, root, kept render or resource type changes, rather
than undoing visibility and breadth-first walking the world on every pose.
Creation/upsert, removal, clear, alias binding, changed parenting and resource
type changes invalidate it. All production GameRef type assignments use
`gameref_set_type`; direct metadata mutation outside these entry points must
explicitly use upsert or the appropriate setter. Upsert conservatively
invalidates even an existing entry, as callers may initialize more metadata
afterwards. Ordinary transform changes and redundant parent assignments do not
invalidate. Frequent scene mutations can therefore still cause repeated walks;
there is no measured in-game frame-time claim.

Rebuild traversal has no 4,096-node cutoff and visits each canonical key once,
terminating even with aliases/cycles. Already-empty renders are left alone.
Release restores only entries hidden by this mask, checking their per-creation
incarnation so a recycled key or cleared world is never unhidden accidentally.
Incarnations continue across clear and do not alter live IDs or Java GC roots.

Release build and driver_mask, live_lookup, script_safety, ped_crossing pass.
The driver-mask fixture checks a duplicate after 5,000 nodes, 10,000 unchanged
cache hits, motion/no-op parenting, late creation, type/reparent/world changes,
alias/cycle traversal, original hidden visibility, removal/reused keys and
clear/release. This tests the shared production mask used by pose_driver, not
seated animation or a full garage transition. Evidence:
`assets/validation/driver-mask/after.txt`. No production Java/native API change.

## Driver head in the cockpit camera (#320)

- `src/resources/part_runtime.cpp:pose_driver` aims the seated driver's neck
  at the car's first cfg camera, 7.2 cm below it, so camera 0 sits in the
  head. The cockpit camera also leans with acceleration (`cockpit_offset`, in
  `part_camera_pose`), and the face then filled the view (seen in a bench
  drive: the driver's face from the front at full throttle).
- While this car's `_hostCockpitCamera` is camera 0 and is the scene camera
  (`fullscreen_script_camera`), `pose_driver` shrinks `Bip01 Head` to 1/1000
  about its joint with `src/resources/character.cpp:character_scale_bone`.
  Hair and face follow the head bone; neck, body and hands stay. The pose is
  rebuilt from bind every frame, so the head is back in every other view,
  for other cars and for the other internal cameras.
- Not checked: whether the original exe hides the head the same way (the
  view flag `+0x3C` of #301 is a candidate). The head is also missing from
  the car's shadow and mirrors while in the cockpit view.
- In game (`--bench-drive`, ValoCity, Baiern, F1 with #318): before, the face
  in front of the camera on six shots at full throttle; after, none. F3 back to
  the chase view runs unchanged.

## Driver hands on the wheel (#302, P2)

- `src/resources/part_runtime.cpp:pose_driver` aims each hand at the rim at
  ±1 rad from the top (radius = rim radius − 1.5 cm). It used to put the wrist
  7.8 cm behind that point along the seat's +Z and leave the hand on the
  forearm's bind orientation.
- Measured on stock Baiern and Enula, wheel centred and at both locks (bench
  drive, temporary log; the "palm" is the wrist plus 8 cm along the hand
  bone's X axis): the wrist target was always reached (reach 44–52 cm for a
  62 cm arm, no clamping), but the palm sat 2–3 cm inside the rim, 0.5 cm at
  Enula's right lock. On a raked column the seat's +Z is not the wheel axis,
  so the wrist landed 4.1 cm (Baiern) or 6.5 cm (Enula) out of the wheel
  plane instead of 7.8 cm.
- First fix (06610f4): the wrist on the elbow-to-palm line and the hand's X
  axis pointed at the rim. The palm point then sat within 1.2 mm of the rim,
  but in game the fists only rested on the wheel: the stock driver
  (`humans\drivers\vin.SCX`, 20 bones) has a single `Bip01 L/R Hand` bone and
  no finger bones; the fist is modelled closed.
- Grip: in hand space (bind pose, vertices weighted to the hand bone) the
  fist spans x 1.7–12.1 cm, palm toward -Z, and its grip hole is at about
  (9.5, 0, -1.2) cm, open along the hand's Y axis (both hands; the left one
  is mirrored in Y). `pose_driver` now puts that hole on the rim's centreline
  with Y along the rim, the palm (-Z) toward the wheel's centre and X as
  close to the forearm as that allows, solves the arm to the resulting wrist
  (two passes) and turns the hand with two `character_align_axis` calls (X,
  then Y, which is a twist about X).
- In game (cockpit view, Baiern, with #318 and #320 applied): the rim now
  runs into both fists. Not checked: steering locks in game, other drivers
  (the grip-hole numbers are for `vin.SCX`), P3 (gear-shift gesture).

## Gear-shift gesture (#302, P3)

- Build 606 (read-only disassembly of `StreetLegal_Redline.exe`): the chassis
  cfg line `shifter x y z [yaw pitch roll]` (handler 0x00444990) stores the
  lever knob at car+0x9AC. No stock racer has the line (only
  `cars\traffic\Wreck_data`), so the knob stays at the chassis origin.
- On a gear change (0x0044D0C0, gear at +0x1DF8, 0 = N, 1-6, 7 = R) the exe
  plays `sfx_gearchange`, sets two timers to now + 0.3 s and now + 0.7 s,
  and re-targets the console-side hand (right when the seat x < 0, otherwise
  left) to the knob plus an H-pattern offset per gear (table 0x0063C6B0,
  metres): N 0, 1 (-0.05, 0, -0.05), 2 (-0.05, 0, 0.05), 3 (0, 0, -0.05),
  4 (0, 0, 0.05), 5 (0.05, 0, -0.05), 6 (0.05, 0, 0.05), R (-0.09, 0, -0.05).
  When both timers have run out, 0x0044D260 puts the hand back on the wheel.
  The driver setup (0x00449200) reads the bone names `lfbone`, `rfbone`,
  `lhbone`, `rhbone`, `sthbone` and `gsbone` from the human, with Biped
  defaults; no stock human overrides them.
- OpenSLRR: `PartConfig::shifter` (parsed in
  `src/resources/part_config.cpp:parse_part_config`), and
  `src/resources/part_runtime.cpp:pose_driver` keeps the last gear per
  `DriverSeat`. A change starts a 0.7 s gesture counted in physics ticks (a
  pause holds it; releasing the seat cancels it). The console-side fist moves
  to the knob over 0.15 s, closes across the car with the palm down, and
  eases back over the last 0.15 s. The exe switches the hand at once.
- Tests: `cockpit_needles` case `parse_shifter_line`. In game (bench drive,
  Baiern, cockpit view): on the 1 to 2 shift the right hand leaves the rim for
  about 0.7 s and returns. With the knob at the chassis origin it goes below
  the view, as the stock data implies.

## PhysicsRef position readback (#86)

World PhysicsRef objects with a physics shape now return a fresh Vector3 from
canonical GameRefState.pos, the position updated by the free-body simulation.
Previously the stored setMatrix argument always won, hiding subsequent motion.
A body made static after moving must also report its current state.

Shape-less OSD hit rectangles retain their script-space position copy. They use
setMatrix for hotspot coordinates but physicsref_set_matrix deliberately does
not create a physical pose for them. Both paths return independent vectors so
Osd.moveFocus cannot mutate the stored rectangle position through its result.
No Java changes or section-specific exceptions are introduced. This fixes an
existing native readback contract; it does not change integration or collisions.

### Validation

Release x64 compilation succeeds. Tests invoke registered native methods,
create real box state and update its position as the simulation does. They
cover moved bodies, frozen bodies, independent results, and shape-less OSD
coordinates. The state update is deterministic; this is not a solver test.
Main c26ef62: 2 pass / 2 fail. Corrected: 4 pass / 0 fail.
Knowledge references: 219 checked, zero errors.

```powershell
./scripts/run_save_io_tests.ps1 -Suite physics_position
./scripts/run_save_io_tests.ps1 -Suite physics_position -BaselineRef c26ef62
python scripts/check_knowledge_refs.py
```

[Before](../../assets/validation/physics-position/before.txt) /
[after](../../assets/validation/physics-position/after.txt).
In-game validation remains pending: inspect moving PhysicsRef readback and
navigate menu focus with the arrow keys. There is no in-game screenshot yet.
