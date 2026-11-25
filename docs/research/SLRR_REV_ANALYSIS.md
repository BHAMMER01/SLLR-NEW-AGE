# SLRR_rev-main integration analysis

This checkout was compared with `C:\games\SLRROPENCLEAN\SLRR_rev-main` on
2026-11-25. The projects complement each other, but they do not share the same
runtime.

## Bring into New Age

These are development tools and source knowledge that directly improve the C++
host:

- TUFA decompilation and class/TREE inspection;
- Java boot and class coverage reports;
- native registry coverage reports;
- installed asset and class inventory;
- stock vehicle telemetry and frame reports;
- Java behavior audits for controls, tracks, city and saves;
- map, lightmap, collision and resource audits whose inputs are original game
  files;
- the reproducible evidence format used by the reports.

The first item is available through `scripts/decompile_slrr_class.ps1`. The
other tools should be ported one at a time after their TypeScript-only imports
are replaced with New Age inputs or host logs.

## Use as reference, not runtime code

The following SLRR_rev components are browser experiments and cannot be copied
as if they were New Age engine features:

- the Vite/WebGL application and `dist/` bundle;
- TypeScript `Vehicle3D`, traffic and map runtime implementations;
- the Cannon/WASM soft-body playground;
- browser-only Java Console and UI adapters;
- TypeScript tests that exercise those implementations rather than
  `slrr_host.exe`.

They remain valuable as independent hypotheses, visual debugging tools and
algorithm references. Any behavior copied into the C++ host must be revalidated
against the installed game and host logs.

## Concrete finding from the cruise audit

The SLRR_rev decompiler exposed the installed `Track.class` method that creates
`CMD_CRUISECONTROL` with `Input.RCDIK_S`. This was the missing evidence for the
cruise conflict. New Age now keeps S as brake, maps the cruise command to P and
explicitly calls `Vehicle.setCruiseControl(0)` on the brake edge.

## Counts observed

`SLRR_rev-main` contains the Web/TypeScript research application and roughly
3,500 tracked files. New Age contains the C++ host, build system, patches and
roughly 1,070 tracked files. The difference is mostly implementation medium,
not a list of missing production runtime files.
