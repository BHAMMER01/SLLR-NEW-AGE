# MethanolFuel visual/runtime validation

Date: 2026-11-25

The New Age host was launched against the local `third_party/research/MethanolFuel-Edition`
root in a separate process; the modpack files were not modified. Test car:
`cars/racers/Baiern.rpk:0x6`.

## Observed evidence

- The host entered `java.game.Garage` and created the Baiern chassis.
- The log contains successful SCX geometry parsing for `chassis.scx`:
  `v=4`, `verts=2666`, `tris=2438`, `groups=4`.
- DDS assets were uploaded by bgfx, including chassis, exhaust, tyres,
  steering wheel and factory-color textures.
- Garage OSD textures/icons were loaded successfully.
- One referenced texture was missing:
  `cars/racers/Baiern_data/meshes/runninggear_exhaust.dds`.
- The direct modpack run did not reach a clean benchmark completion within the
  test window and was stopped; this is a runtime compatibility issue to isolate,
  not a render-pass result.

Evidence: `build/verification/methanol-visual/baiern.out.log`.

## Conclusion

Structural readers accept the Methanol corpus, and representative vehicle
geometry/textures reach the renderer. Full visual acceptance still requires a
small curated modpack copy with known script/DLL dependencies and a bounded
garage screenshot test so missing assets and startup loops do not get confused
with renderer failures.
