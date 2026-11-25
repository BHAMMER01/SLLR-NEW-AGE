# External project inventory

The New Age project now has local, reproducible research checkouts under
`third_party/research`. Their purpose is to transfer knowledge, not to merge
unreviewed forks into the runtime.

## Multiplayer direction

`SLRRMultiplayer` is the starting reference for multiplayer behavior. New Age
will implement networking in the native host instead of depending on a hook or
DLL injection. The first production milestone should replicate only the state
needed for a reliable session:

1. session identity and connect/disconnect lifecycle;
2. player input and authoritative car pose/velocity;
3. vehicle identity and spawn/despawn events;
4. interpolation, timeout and resynchronization;
5. explicit compatibility/version checks.

Physics remains authoritative locally until a deterministic simulation protocol
is designed. This avoids coupling multiplayer correctness to the legacy Java
input loop or to a particular mod installation.

The exact repositories, revisions, licenses and update commands are recorded in
[`third_party/research/README.md`](../../third_party/research/README.md).
