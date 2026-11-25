# SLRR New Age — external research sources

These repositories are local research checkouts used to compare behavior, formats,
Java scripts, physics and multiplayer approaches. They are intentionally kept out
of the New Age production build and ignored by Git; this file is the durable index.

| Source | Revision | Intended use |
|---|---:|---|
| [slrr-javas](https://github.com/imagecode-git/slrr-javas) | `7e622de` | Java game-script and input behavior reference |
| [slrr-reverse](https://github.com/EliasFD3S/slrr-reverse) | `93588c4` | Reverse engineering, resource formats and TUFA/native research |
| [sl-remastered](https://github.com/nicolas-found42/sl-remastered) | `1721525` | Physics and gameplay implementation reference |
| [street-legal](https://github.com/nicolas-found42/street-legal) | `33eca3c` | Chassis, suspension and force-update reference |
| [SLRRMultiplayer](https://github.com/nedobylskiy/SLRRMultiplayer) | `8e8d93d` | Multiplayer protocol/session and hook behavior reference |
| [MethanolFuel-Edition](https://github.com/MethanolFuel/SLRR-LE2MWM-MethanolFuel-Edition) | `75b196d` | Mod/content compatibility and regression corpus |

## Update

```powershell
$names = 'slrr-javas','slrr-reverse','sl-remastered','street-legal','SLRRMultiplayer','MethanolFuel-Edition'
foreach ($name in $names) { git -C "third_party/research/$name" pull --ff-only }
```

Do not copy code blindly into the host. Each candidate change must be validated
against the New Age runtime, documented in `docs/DEVELOPMENT_LOG.md`, and checked
for the source repository's license. The multiplayer project is currently a
reference only: its hook/injection model is not linked into the C++ host.
