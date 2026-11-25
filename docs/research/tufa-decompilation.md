# TUFA class inspection

SLRR New Age executes the installed TUFA classes through its C++ host. The
source checkout does not contain every stock Java source file, so behavior that
is present only in a shipped `.class` must be inspected from the game copy.

The project now vendors the built SLRR-JVM decompiler under
`third_party/slrr-jvm-decompiler`. The wrapper in
`scripts/decompile_slrr_class.ps1` uses that copy first, with the sibling
checkout as a fallback. It keeps output under `build/` and does not modify the
game installation:

```powershell
.
scripts\decompile_slrr_class.ps1 `
  "C:\games\SLRROPENCLEAN\SLRR-NEWAGE\Street Legal Racing - Redline\sl\Scripts\game\Track.class" `
  -OutputDirectory .\build\decompiled\Track -Ir -Strict
```

This workflow was used to inspect `Track.class`. Its decompiled source showed
that the stock game registered `Input.RCDIK_S` for `CMD_CRUISECONTROL`; the
New Age host remaps that specific command to P while retaining S as the brake.

The decompiler is an investigation dependency, not part of the game runtime.
`-DecompilerRoot` is only needed when using the external fallback.
