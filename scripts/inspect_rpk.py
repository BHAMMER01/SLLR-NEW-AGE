"""Inspect SLRR RPK metadata without starting the game.

This is a small, read-only diagnostic adapted from the older Brazil workspace.
It reports dependencies, entry metadata and GroundRef records.  It complements
the runtime RpkIndex; it is intentionally not a second resource loader.
"""
from __future__ import annotations

import argparse
import struct
from pathlib import Path


HEADER = struct.Struct("<4sIII")
ENTRY = struct.Struct("<IIBBfIIB")


def inspect(path: Path, ground_only: bool = False) -> int:
    data = path.read_bytes()
    if len(data) < HEADER.size:
        raise ValueError(f"{path}: truncated header")
    magic, version, dep_a, dep_b = HEADER.unpack_from(data)
    if magic != b"RPAK":
        raise ValueError(f"{path}: expected RPAK magic, got {magic!r}")
    dep_count = dep_a + dep_b
    table = HEADER.size + dep_count * 64
    if table + 8 > len(data):
        raise ValueError(f"{path}: dependency table exceeds file")
    table_size, count = struct.unpack_from("<II", data, table)
    cursor = table + 8
    print(f"pack={path} version={version} dependencies={dep_count} entries={count} table={table_size}")
    shown = 0
    for index in range(count):
        if cursor + ENTRY.size > len(data):
            raise ValueError(f"{path}: truncated entry {index}")
        super_id, type_id, kind, flags, unknown, offset, size, alias_len = ENTRY.unpack_from(data, cursor)
        cursor += ENTRY.size
        if cursor + alias_len > len(data):
            raise ValueError(f"{path}: truncated alias {index}")
        alias = data[cursor:cursor + alias_len].split(b"\0", 1)[0].decode("latin-1", "replace")
        cursor += alias_len
        if flags & 1:
            if cursor + 48 > len(data):
                raise ValueError(f"{path}: truncated extended entry {index}")
            cursor += 48
        is_ground = kind == 1
        if ground_only and not is_ground:
            continue
        end = offset + size
        valid_range = offset <= len(data) and end <= len(data)
        validity = "valid-range" if valid_range else "out-of-range"
        print(f"  index={index} type=0x{type_id:04x} kind={kind} flags=0x{flags:02x} "
              f"offset={offset} size={size} [{validity}] alias={alias!r}")
        shown += 1
    return shown


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+", type=Path)
    parser.add_argument("--ground-only", action="store_true")
    args = parser.parse_args()
    total = 0
    for path in args.paths:
        total += inspect(path, args.ground_only)
    print(f"shown={total}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
