# Resources, audio and video: issue notes

Verified notes on SCX/RPK/RPAK parsing, resource caches, audio voices and
video playback, moved from the knowledge base.

## Asset bounds checks (#91, #92)

SCX v3 validates all three face indices against the current material group's
vertex count before appending indices. Validation also runs for metadata reads;
an index referencing vertices in a later group is invalid even when the final
mesh would contain that index. Invalid geometry is marked not-ok with an error.

matrixdata_read checks declared keys against remaining bytes (eight floats per
key) before resizing times or track channels. This prevents allocation driven
by an unsupported key declaration. Existing quaternion/time/name checks remain.
These are parser corrections, not changes to deformation or animation behavior.

Release x64 build passes. Five deterministic fixtures exercise valid multi-group
SCX, an out-of-range local index, an index into a later group, truncated keys
with no channel allocation, and a valid named animation. Main 933cf0a: 2 pass /
3 fail; corrected: 5 pass / 0 fail. Evidence: assets/validation/asset-bounds.
Run `./scripts/run_save_io_tests.ps1 -Suite asset_bounds`; add
`-BaselineRef 933cf0a` to reproduce. Generated fixtures do not alter game assets
or saves. Knowledge-reference check: 219 references, zero errors.
In-game visual regression testing remains pending; these fixes are most directly
validated with malformed fixtures, not normal driving.

## Issues #107 / #94: RPK reads and index-scoped cache lifetime

`src/resources/rpk_index.cpp:RpkIndex::read_payload` reuses at most 64 lazily
opened pack streams in an LRU under a mutex, reopening evicted packs on demand.
Text/ICFG descriptors are cached by canonical full RID; large binary map
payloads are not retained as another resident copy. `payload_props` parses all text keys once under its own lock
and caches ordered repeated values, including negative key lookups. Empty
read failures are retried. Unscoped ids retain last-pack-wins resolution.
TOC lookups hash the low 16-bit local id directly (first matching TOC entry),
removing the linear fallback for misses. Dependency slots and host pack ids
remain separate. Cached descriptors are snapshots for the index lifetime;
editing a pack on disk requires rebuilding/rebinding the index.

`RpkIndex::set_root` clears packs, descriptor caches and open streams when
the root changes. A monotonic generation changes on root/pack registration
and distinguishes even index objects recreated at the same address.
`src/resources/script_cfg.cpp:frontend_cache` keys frontend pack/CFG state
by index identity and generation. `scene_instances_set_resources` also
clears shadow metadata, and `character_forget_all` clears skeleton/clip
caches as well as live characters. The active RPK pointer is cleared when
its owning index is destroyed; destroying another index does not clear it.
Root/index mutation must occur at a quiescent point after stopping preload
readers, followed by scene rebinding. Concurrent readers are supported;
concurrent root replacement and live-world RID migration are not added.

Validation: Release host compiles. The resource_cache suite creates two
isolated miniature RPAKs and frontend CFGs. Eight readers execute 1,600
property queries: instrumentation reports one payload disk read and one RSD
parse. Tests also verify key case/comments, repeated texture order, local/
qualified ids and misses, root-switch invalidation with reused RID values,
frontend cache rebuild with a different pack-id assignment, shadow metadata
rebinding, and active-index cleanup on destruction. Log:
`assets/validation/resource-cache/after.txt`. Existing map_props (Test Track
and ROC placements), night_props (window/sign data), ui_lifetime and save_io
suites pass. These checks do not measure full city load-time improvement.
SLRR_rev `SLRR_rev:docs/formats/rpk.md` and `SLRR_rev:src/formats/rpk.ts` were
consulted for RPAK structure and text/binary payload distinction; no parser
implementation was copied.

PR #145 was validated and merged at the user's request; #127/#101/#77 are
closed. For this resource wave, in-game menu/garage/city/track loading still
requires user confirmation before merge. No production Java is modified.

## Issues #80 / #95: RPAK ranges and bounded ground-node traversal

`src/resources/rpk_index.cpp:RpkIndex::parse_rpak` reads only the header,
dependencies and TOC, leaving payloads on disk until first use. It checks file
sizing, 64-bit dependency-count sums, dependency/table spans, record count versus
minimum TOC record size, alias/bounds spans, and 64-bit offset+size against
the file snapshot before publishing entries. It parses into a temporary
pack: a bad record rejects the TOC instead of leaving a usable prefix.
File loading and allocations are inside an exception boundary. An open
pack with a rejected TOC retains its assigned id/path but has no entries.

`RpkPack::file_size` records the validated snapshot. Uncached read_payload
checks both that snapshot and the current stream length before allocating
the payload, and contains allocation/read exceptions for preload callers.
Descriptor cache hits remain immutable snapshots as described in #107;
this does not add hot pack editing. A file truncated after TOC parsing is
rejected by an uncached payload read before allocation.

`src/resources/scene_instances.cpp:walk_ground_node` visits each in-range
file offset once per GroundWalk. Cycles and repeated child pointers no
longer cause exponential recursion or duplicate placements/geometry. The
existing depth and byte-range guards remain; chunk iteration uses remaining
byte counts. Repeated node data is consumed once in first traversal order,
not interpreted as a new placement on each graph edge.

Validation: Release host compiles. rpk_validation covers huge TOC counts,
dependency addition overflow, huge payload sizes, offset+size overflow,
truncated aliases/bounds, oversized table ranges, a file truncated after
indexing, a two-edge self-cycle, and two children sharing a placement node.
All 80 actual RPK files / 11367 TOC entries are accepted. Actual Test Track
and ROC placement counts remain 1413 and 1791 respectively, matching the
previous wave's logs. Existing resource_cache suite passes. Evidence is in
`assets/validation/rpk-map-validation/`. No unsafe baseline cyclic walk or
huge reserve is deliberately executed. No game Java/data is modified.
SLRR_rev `SLRR_rev:docs/formats/rpk.md` and `SLRR_rev:src/formats/rpk.ts` were
consulted for RPAK spans and record contracts; no external code copied.

PR #147 was validated and merged at the user's request; #88/#89/#74 are
closed. In-game loading of garage, city and tracks remains the validation
step before merging this resource-validation wave.

## Issues #108 / #97: audio admission, PCM reuse and playlist recovery

`src/platform/host_sfx.cpp` admits requests before WAV reads/source creation.
At most 24 of 32 voices may be loops, leaving capacity for one-shots. At full
capacity an existing one-shot is selected for replacement before decoding,
but retired only when the replacement buffer is ready. Existing menu/burst
coalescing is retained. Rejected loop requests increment diagnostics without
reading their WAV. This is a common loop budget, not new engine-vs-ambient
priority; a 25th loop can still be denied until another loop stops.

FMOD decoded sample sounds are shared between voices and held in a
16 MiB decoded-PCM / 64-entry LRU cache. Samples are prepared for looping at
load time; each channel selects loop or one-shot playback independently.
Playing voices retain their sound even after cache eviction; root reset
stops voices and clears cached data/counters. `host_audio` owns the shared
FMOD mixer with independent effects/music groups; music streams are updated
through the existing frame pump even when only effects are playing.
Sounds above the cache limit can play up to the 64 MiB per-effect bound,
checked with an open-only metadata probe before full decode. `wave_reads`
counts uncached load attempts (probe plus decode), not OS file reads. Loop pitch
and gain updates now reject non-finite inputs via the same finite defaults
as play_file. HostSfxStats exposes rejection/read/hit/cache diagnostics.

`src/platform/host_music.cpp` tries at most one playlist pass when opening
a track fails, preserving next/previous direction. A stream failure advances
through the same bounded recovery path. A wholly unreadable set remains
stopped; update does not continuously retry it. Explicit change/next can
retry later. HostMusicStats exposes attempts/failures/current track for
diagnostics. No Java native or music-set/mode contract is added.

Pre-FMOD validation: Release host compiles. audio_recovery creates only digital-silence
PCM WAVs in an isolated fixture and mutes playback. Actual XAudio2/Media
Foundation checks pass: 24 loops share one disk read; the next loop is
rejected before I/O; nine distinct one-shots are admitted with 32 total
voices while existing loops remain; NaN loop updates do not interrupt the
voice; 65 new cues exercise the 64-entry limit while an evicted playing
buffer stays valid. Root reset releases voices/cache. An unreadable music
file is skipped to a valid WAV in both directions; an all-broken two-track
set makes two attempts then stays stopped through 100 updates. Mid-stream
fill-error recovery is implemented but not fault-injected by this fixture.
Log: `assets/validation/audio-recovery/after.txt`. resource_cache regression
also passes. These silent tests do not validate perceived sound balance or
engine/ambient priorities in gameplay; listen in menus, garage and city
before merging. SLRR_rev `SLRR_rev:docs/music.md` consulted for set contracts;
no external implementation copied. No production Java/game assets modified.

PR #148 was validated and merged at the user's request; #80/#95 are closed.

## Video frame bounds and shutdown (#78, #102)

The DirectShow Sample Grabber accepts only a complete VIDEOINFOHEADER describing
packed RGB32 (one plane, BI_RGB). Width/height validation rejects zero, negative
width, INT32_MIN height and byte counts beyond the signed 32-bit sample API.
`video_rgb32_bytes` and `video_copy_rgb32` in `include/slrr/video_frame.hpp`
validate the actual returned sample span before copying. The second
GetCurrentBuffer result, not scratch capacity or the initial query, determines
the valid bytes. Short samples never publish a new frame or copy stale rows.
Negative-height images retain top-down order; positive heights are flipped.
Dynamic media-format renegotiation is not implemented by this change.

WM_CLOSE only requests quit in the libbgfx backend. The main loop returns early
when quit is already requested and skips presentation if quit is requested
mid-frame. Backend close destroys/resets its FMV texture, dimensions and serial
before bgfx shutdown; HWND destruction remains after shutdown (this order was
already correct before this fix). Repeated close was verified.

Validation: Release build and `video_safety` pass. Synthetic pixel fixtures
cover both orientations, short/empty samples, extra trailing bytes and invalid
or overflowing dimensions. A real Direct3D 11 window test sends WM_CLOSE,
checks the HWND is still valid through mainloop_frame's quit return, then
checks it is destroyed by close and that close can be repeated. Test log:
`assets/validation/video-safety/after.txt`. Existing present/hiz shader-link
warnings (#105) were observed in that historical test; the backend still opened
and the test passed. The inactive passes and those programs are now removed;
this does not enable HiZ occlusion. Actual DirectShow decoder fallback, intro playback and FMV texture
allocation/release during playback remain manual validation; the synthetic
copy tests do not claim to cover a full decoder graph.


Intro cancellation follow-up (#102): `video_fmv_play_boot_intros` now takes a
boolean pump callback. False aborts the sequence, including ESC-release waits,
closes the active video and clears OSD blocking. Boot returns through renderer
cleanup before starting Init when the window was closed during intros. The
video_safety suite checks cancellation both before opening a decoder and after
opening a generated silent AVI; no later intro is opened. Immediate LibVLC
cancellation can log demux errors in this fixture; actual rendered frames are
not asserted. Release build and the suite pass.

Video without VLC (#216): 64-bit Windows ships no Cinepak codec (only the
32-bit `SysWOW64\iccvid.dll`), so without LibVLC both the AVIFile and the
DirectShow paths failed and every intro and `prime.avi` was skipped.
`video_fmv_open` now tries `src/platform/video_cinepak.cpp` first: it indexes
the AVI, decodes Cinepak frames in order into BGRA and plays PCM audio through
a dedicated FMOD channel/group, whose position drives the frame clock.
The FMV pump updates the shared mixer during boot intros, and EOF/channel
failure falls back to wall time from the last valid position without jumping
the picture. PCM is staged in a WAV memory sample (unsigned 8-bit or signed
16-bit, mono/stereo) and released before its shared mixer owner. Looping
replays the same sound with a fresh channel. Files it rejects
(another codec, or a first frame it cannot decode) still go to LibVLC, then
AVIFile/DirectShow. The video_safety suite checks the decoder and a generated
Cinepak AVI with PCM audio.
