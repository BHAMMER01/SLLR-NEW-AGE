# Compatibility validation

Date: 2026-11-25

This pass validates the New Age readers against the installed game corpus. It
does not modify the game installation or copy the research modpack into the
runtime.

## TUFA/class corpus

Command (after the Release build):

```powershell
.\scripts\run_save_io_tests.ps1 -Suite tufa_validation -CorpusOnly
```

Result: **pass (exit 0)**. The installed corpus contained 1,452 class files;
1,492 classes were accepted. One file was rejected:
`game\system\Scripts\render\osd\Dialog.class`, with `CONS: unknown kind 2`.
This is a concrete compatibility gap to investigate before claiming complete
stock-script coverage.

## RPK corpus

Command:

```powershell
.\scripts\run_save_io_tests.ps1 -Suite rpk_validation -CorpusOnly
```

Result: **pass (exit 0)**. All 61 installed RPK files opened successfully,
with 10,863 entries accepted and zero rejected packs. The corpus included cars,
parts, maps, garage, catalog, frontend, textures, sound and system archives.

## Scope and limitations

- The validated corpus is the installed stock game used by New Age. The
  `MethanolFuel-Edition` checkout is a separate compatibility corpus and was
  not injected into the runtime during this pass.
- The first direct run exposed missing test-directory DLL dependencies; copying
  the Release runtime DLLs into the temporary test directories resolved that
  harness issue. Production binaries were not changed.
- These are structural reader tests. They do not prove that every script,
  vehicle, texture or city scene renders correctly in the live game.
- The next targeted test is `Dialog.class`: decompile it with the bundled TUFA
  tool, identify the `kind 2` constructor/constant encoding, add a focused
  regression fixture, then repeat the corpus scan.

## MethanolFuel-Edition corpus

The modpack was tested through a temporary directory junction named `game`;
the junction was removed after each run and the modpack files were not changed.

Inventory before validation:

| Extension | Files |
|---|---:|
| RPK | 87 |
| SCX | 3,224 |
| CLASS | 1,692 |
| Java | 138 |
| PNG | 624 |
| TGA | 22 |
| DDS | 1,560 |

Commands:

```powershell
cmd /c mklink /J game third_party\research\MethanolFuel-Edition
.\build\tufa-validation-tests\tufa-validation-after.exe --corpus
.\build\rpk-validation-tests\rpk-validation-after.exe --corpus
cmd /c rmdir game
```

Results: **both readers passed (exit 0)**. TUFA accepted all 1,692 class files
and 1,760 classes, with zero rejected files. RPK opened all 87 archives,
accepting 12,247 entries with zero rejected packs. This confirms structural
reader compatibility with the modpack's larger archive/class corpus; it does
not yet prove that every custom vehicle, shader, DLL or scene renders in the
live game.
