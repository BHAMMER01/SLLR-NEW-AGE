# Reverse-engineering tooling available for New Age

The following local tools are available for evidence about behavior that is
not present in the open-source host. They are research tools, not runtime
dependencies of SLRR New Age.

## Available workspaces

- `E:/ENGENHARIAREVERSA/ghidra-Ghidra_12.2_build` — Ghidra 12.2 source/build
  tree. Use it to import the original `StreetLegal_Redline.exe`, DLLs or
  recovered binaries and inspect functions, data references, strings, calling
  conventions and control flow.
- `E:/ENGENHARIAREVERSA/rea-main` — Reverse Engineering Anything tooling,
  including Ghidra bridges, seed/application helpers, Frida-oriented scripts
  and analysis documentation. Use it to automate repeatable annotations or
  bridge evidence between tools; do not copy its bridge into the game host.
- `E:/ENGENHARIAREVERSA/awesome-reverse-engineer-anything-master` — curated
  index of reverse-engineering tools and references. It is a catalogue, not a
  runtime library.

## New Age use cases

Use these tools when source and runtime evidence disagree, for example:

1. identify an unknown native or `Dialog.class` kind by tracing the original
   executable's call site and data layout;
2. verify DirectInput/control dispatch and cruise-control key handling;
3. inspect original RPK/TUFA/SCX parsing boundaries when a corpus sample is
   rejected;
4. compare original physics/damage constants with the native port;
5. confirm renderer/API selection, shader loading and frame-pacing behavior;
6. inspect the original wheel-release path when a manual loss is not reproduced
   by a transform-only replay.

## Evidence rules

- Keep original binaries and Ghidra projects outside the product source tree.
- Record binary hash, module/version, address/function name and the observation
  in a research note before changing New Age.
- Treat decompiler output as a hypothesis; confirm it with xrefs, runtime
  traces, fixtures or a controlled replay.
- Do not copy proprietary game binaries, generated databases or tool caches into
  Git. Port only independently authored behavior and document provenance.
- Multiplayer remains outside the current integration scope.

## GitHub finding: SLRR-Proofix

The public `CookiePLMonster/SLRR-Proofix` project documents a v2.3.1 parser
overrun caused by `asphalt.cfg`, `graph.cfg` and `graph_fade.cfg` lacking a
final newline. New Age's CFG readers already use `std::getline`, which accepts
the final unterminated line; a resource-cache fixture now intentionally omits
that newline so the behavior remains covered by regression tests. This is a
robustness lesson, not code copied from the patch.
