# Public user complaints and bug themes

This is a triage list from public Steam discussions, guides and release notes.
It is not a claim that every report reproduces in New Age.

## Recurring themes

| Theme | Reported symptoms | New Age validation |
|---|---|---|
| Valo City performance | FPS can collapse when spawning in the city; camera direction changes the result | City Vulkan benchmark and frametime telemetry |
| Crashes and stability | Random crashes entering/leaving races, hovering detached parts, damaged hinges, message boxes and long sessions | Stress test, scene transition loop, class/resource logs |
| Memory and loading | Stutter, cache behavior, leaks after scene changes or paint jobs | RAM telemetry and garage/city cycle |
| Physics/damage | Curbs destroy cars, parts detach unexpectedly, deformation can destabilize the game, engine output differs by map | Deterministic physics fixtures and deformation profiling |
| AI/traffic | Bad spawn/despawn, erratic night-race AI, police/chase problems | City traffic and race stress tests |
| Audio | Low-RPM engine sounds and missing/buggy audio | FMOD error counts and engine-sound cases |
| Garage/catalog | Wrong colors/names, poor part discoverability, missing previews, cursor/focus issues | Methanol content matrix and garage UI tests |
| Controls/UI | Controller support, remapping, cruise-control behavior, dialog/ESC issues | Input harness and `Dialog.class` compatibility test |
| Mod compatibility | Modded wheels/tires, old car parts, shaders and DLLs causing regressions | MethanolFuel structural and runtime corpus |

## Priority for New Age

1. City frametime spikes and resource-cache/streaming behavior.
2. Scene transition stability and memory growth.
3. Deformation/physics spikes and damaged-hinge safety.
4. Script/dialog compatibility, including the current `kind 2` failure.
5. Vehicle/part/mod compatibility in live rendering.
6. AI/traffic and audio regressions.

The strongest recurring evidence is the official 2.3.1 changelog, which lists
fixes for ground collision, CPU/render overhead, cache stutter, memory leaks,
hinge crashes, AI, audio, city framerate and numerous garage/race UI issues.
