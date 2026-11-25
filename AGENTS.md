# Agent working guide

Before changing the engine, read [ENGINE_CONTRACT.md](docs/core/ENGINE_CONTRACT.md).
This guide describes the SLRR contract, subsystem responsibilities, and
compatibility pitfalls. Then read the specialized documentation for your task:

- VM, threads, events, and dialogs: [scripting/runtime.md](docs/scripting/runtime.md).
- Host threads, the worker pool and how to add parallel work:
  [KNOWLEDGE_BASE.md §5.10](docs/core/KNOWLEDGE_BASE.md#510-threads-and-the-worker-pool)
  and [ENGINE_CONTRACT.md §6](docs/core/ENGINE_CONTRACT.md#host-threads-and-the-worker-pool).
- Object lifetime: [scripting/vm-gc.md](docs/scripting/vm-gc.md).
- Script compilation: [scripting/compiler.md](docs/scripting/compiler.md).
- Bindings, no-ops, and limitations: [scripting/natives.md](docs/scripting/natives.md).
- Building and running: [README.md](README.md).
- Verified code map, known doc drift, open risks and issue entry points:
  [KNOWLEDGE_BASE.md](docs/core/KNOWLEDGE_BASE.md).
- Formats, mechanics and lessons from SLRR_rev and draft PR #3:
  [EXTERNAL_RESEARCH.md](docs/research/EXTERNAL_RESEARCH.md).
- Proposed roadmap: [MILESTONES.md](docs/planning/MILESTONES.md).
- Everything else (rendering, vehicles, world, UI, saves, resources, build)
  is grouped by subsystem; start from the [documentation index](docs/README.md).

SLRR_rev (https://github.com/nedobylskiy/SLRR_rev) implements most game
mechanics. Before implementing a missing native or mechanic, check whether
SLRR_rev already has it and migrate it, following
[EXTERNAL_RESEARCH.md §7](docs/research/EXTERNAL_RESEARCH.md#7-migrating-mechanics-from-slrr_rev).

After changing code that the documentation cites, run
`python scripts/check_knowledge_refs.py`.

Write an issue's verified notes (cause, fix, validation) in its subsystem's
notes file under `docs/<subsystem>/`, not in the knowledge base. The
knowledge base keeps only cross-cutting knowledge; its §14 lists where each
subsystem's notes live.

Check the active code: some audits and comments describe earlier implementations.
Preserve changes already present in the working tree. Fix general primitives
rather than adding VM exceptions for a specific car or screen. Java changes
must remain within the scope authorized by the user and must be included in
the distributed patch when needed.

Update the relevant documentation whenever a contract or responsibility changes.
Report compilation and in-game validation separately; neither result alone
establishes complete compatibility.

For missing Java source behavior, inspect the installed TUFA class before
changing the host. Use `scripts/decompile_slrr_class.ps1` with the sibling
`SLRR_rev-main` decompiler and keep generated `.java`/`.ir` files under
`build/decompiled/`. Do not treat SLRR_rev's browser physics or WebGL viewer as
the New Age runtime; reuse its TUFA, class-report and asset-audit knowledge at
the tool/documentation boundary.

## SLRR New Age evidence workflow

SLRR New Age is an independent continuation of an initial OpenSLRR DX11 fork.
Keep that project boundary and attribution intact; see
[PROJECT_IDENTITY.md](docs/PROJECT_IDENTITY.md).

Every engine change must leave an evidence trail:

1. Before editing, state the subsystem, intended behavior, and whether physics,
   scripts, rendering, audio, save data or tools are in scope.
2. After editing, update the relevant subsystem notes and append a concise entry
   to [DEVELOPMENT_LOG.md](docs/DEVELOPMENT_LOG.md). Each entry records intent,
   files changed, build/test commands, observed results, and remaining limits.
3. Keep raw benchmark CSVs, private game copies, logs and binaries under
   `build/` or another ignored directory. Commit the reproducible command and a
   summarized result, not generated game data.
4. Treat garage measurements, loading screens and headless smoke tests as
   separate evidence from in-city gameplay. Never present them as equivalent.
5. Do not change physics, fixed-step timing, contact ordering or vehicle state
   while pursuing a rendering/audio/tooling optimization unless the user
   explicitly authorizes physics work.
6. For performance work, report frame time in milliseconds as well as FPS, and
   include the test map, renderer, resolution, VSync state, warm-up policy and
   sample window. Report CPU/RAM/GPU counters with their collection limits.
7. Use focused commits. A recommended format is
   `perf(render): short description`, `fix(audio): short description`,
   `test(bench): short description`, or `docs: short description`.

An optimization is not considered validated until the build result and the
runtime result are both recorded. If a test is unavailable, record that gap
instead of inferring success from source inspection.

## Launching the game for manual tests

Use the SLRR New Age executable in `build/Release/slrr_host.exe` and pass the
installed game directory explicitly with `--root`. Do not launch the original
game executable for testing the host.

Open directly in the garage with the test Baiern:

```powershell
& .\build\Release\slrr_host.exe --game --window --no-vsync `
  --root "C:\games\SLRROPENCLEAN\SLRR-NEWAGE\Street Legal Racing - Redline" `
  --spawn-car cars/racers/Baiern.rpk:0x6 --renderer vulkan
```

Open directly in ValoCity with the same car by adding `--auto-city`:

```powershell
& .\build\Release\slrr_host.exe --game --window --no-vsync `
  --root "C:\games\SLRROPENCLEAN\SLRR-NEWAGE\Street Legal Racing - Redline" `
  --spawn-car cars/racers/Baiern.rpk:0x6 --auto-city --renderer vulkan
```

Confirm the startup location from the host log: garage startup prints
`[section] enter java.game.Garage`; direct city startup prints
`[boot] --auto-city entered java.game.Valocity`. The repeatable monitor script
is for benchmarks and does not replace these interactive launch commands. See
[`docs/TESTING.md`](docs/TESTING.md) for the procedure and log locations.

## Branches and pull requests

- Name branches `{type}/{issue_number}-short-desc`, where `type` is `feature`,
  `bug`, `hotfix`, or `spike`. The issue number is required. For example:
  `bug/44-remaining-limitations-fix`.
- Start the PR title with `#<issue_number>` and make its wording match the
  branch's short description, for example: `#44 Remaining limitations fix`.
- Keep the PR description concise and direct. Include a `Not fixed / limitations`
  section listing remaining work so a crawler can add it to issue #44; write
  `None` when nothing remains. Do not omit known gaps.
- For UI changes, include labelled **Before** and **After** screenshots in the
  PR description.
- Always request review from someone other than the PR author. PRs created by
  `antomys` must request `EliasFD3S`; PRs created by `EliasFD3S` must request
  `antomys`.

## Build speed and its edge cases

Compile options are described in [README.md](README.md#faster-builds). Known
limits and edge cases:

- Every target builds with `/MP`. With several builds at once the machine can
  run out of memory or cores; lower it with `-DSLRR_COMPILE_JOBS=<n>`.
- `slrr_host` uses a precompiled header of standard headers. Do not put project
  headers, macros such as `NOMINMAX`, or Windows headers in it, and a source
  file must still include what it uses.
- The shared `shaderc` (`SLRR_TOOLS_CACHE_DIR`) is keyed by the git revisions
  and uncommitted changes of bgfx.cmake, bgfx, bimg and bx, the compiler and the
  toolset. Changing the toolset's version or the sources builds a new copy;
  old `shaderc-<key>` folders are never deleted automatically, so remove them
  by hand when the disk fills.
- If those sources are not git checkouts, `shaderc` is built once in
  `<build>/shaderc-local` instead and is not shared. It is not rebuilt when the
  sources change: delete that folder after changing them.
- The first build for a new key compiles `shaderc` (about 13 minutes) while the
  other builds wait on its lock for up to 2 hours. A build killed midway leaves
  no half-written copy; the next build retries.
- `shaderc` is always built in Release, whatever configuration the game uses.
- Shader outputs are not regenerated when only `shaderc` changes; delete
  `<build>/generated/shaders` after switching to another `shaderc`.
- `tests/test_cmake_dependency_paths.py` needs Windows Python (it uses
  `winreg`); the agent environment has none, so it cannot be run there.
