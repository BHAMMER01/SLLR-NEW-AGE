#!/usr/bin/env python3
"""Prototype retargeter for the Godot GTA-ped get-in/get-out GLB clips.

This converts GLB skeletal rotations to New Age's SLRR .matrixdata format for
the native Bip01 pedestrian rig. It preserves the target rig's bone offsets
and retargets each mapped joint's world-space rotation delta from the GLB bind
pose onto the native bind pose. It intentionally omits root translation, as
the Godot on-foot flow anchors the actor during vehicle transition clips.

The generated files are an offline prototype, not installed into humans.rpk.
Visual alignment and root/door timing still need an in-game integration test.
"""

from __future__ import annotations

import argparse
import json
import math
import struct
from pathlib import Path


TARGET_TO_SOURCE = {
    "Bip01": "SKEL_ROOT",
    "Bip01 Pelvis": "SKEL_Pelvis",
    "Bip01 Spine": "SKEL_Spine_Root",
    "Bip01 Spine1": "SKEL_Spine0",
    "Bip01 Spine2": "SKEL_Spine1",
    "Bip01 Neck": "SKEL_Neck_1",
    "Bip01 Head": "SKEL_Head",
    "Bip01 L Clavicle": "SKEL_L_Clavicle",
    "Bip01 L UpperArm": "SKEL_L_UpperArm",
    "Bip01 L Forearm": "SKEL_L_Forearm",
    "Bip01 L Hand": "SKEL_L_Hand",
    "Bip01 L Finger0": "SKEL_L_Finger00",
    "Bip01 R Clavicle": "SKEL_R_Clavicle",
    "Bip01 R UpperArm": "SKEL_R_UpperArm",
    "Bip01 R Forearm": "SKEL_R_Forearm",
    "Bip01 R Hand": "SKEL_R_Hand",
    "Bip01 R Finger0": "SKEL_R_Finger00",
    "Bip01 L Thigh": "SKEL_L_Thigh",
    "Bip01 L Calf": "SKEL_L_Calf",
    "Bip01 L Foot": "SKEL_L_Foot",
    "Bip01 L Toe0": "SKEL_L_Toe0",
    "Bip01 R Thigh": "SKEL_R_Thigh",
    "Bip01 R Calf": "SKEL_R_Calf",
    "Bip01 R Foot": "SKEL_R_Foot",
    "Bip01 R Toe0": "SKEL_R_Toe0",
}


def qnorm(q):
    length = math.sqrt(sum(x * x for x in q))
    if length < 1e-12:
        return (0.0, 0.0, 0.0, 1.0)
    return tuple(x / length for x in q)


def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (aw * bx + ax * bw + ay * bz - az * by,
            aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw,
            aw * bw - ax * bx - ay * by - az * bz)


def qinv(q):
    x, y, z, w = q
    return (-x, -y, -z, w)


def q_from_slrr_rows(rows):
    # Mirrors skeleton.cpp's matrix_from_rows() storage and quat_from_matrix().
    m = [rows[0][0], rows[0][1], rows[0][2], 0.0,
         rows[1][0], rows[1][1], rows[1][2], 0.0,
         rows[2][0], rows[2][1], rows[2][2], 0.0,
         0.0, 0.0, 0.0, 1.0]
    trace = m[0] + m[5] + m[10]
    if trace > 0.0:
        s = math.sqrt(trace + 1.0) * 2.0
        q = ((m[6] - m[9]) / s, (m[8] - m[2]) / s,
             (m[1] - m[4]) / s, 0.25 * s)
    elif m[0] > m[5] and m[0] > m[10]:
        s = math.sqrt(1.0 + m[0] - m[5] - m[10]) * 2.0
        q = (0.25 * s, (m[1] + m[4]) / s, (m[8] + m[2]) / s,
             (m[6] - m[9]) / s)
    elif m[5] > m[10]:
        s = math.sqrt(1.0 + m[5] - m[0] - m[10]) * 2.0
        q = ((m[1] + m[4]) / s, 0.25 * s, (m[6] + m[9]) / s,
             (m[8] - m[2]) / s)
    else:
        s = math.sqrt(1.0 + m[10] - m[0] - m[5]) * 2.0
        q = ((m[2] + m[8]) / s, (m[6] + m[9]) / s, 0.25 * s,
             (m[1] - m[4]) / s)
    return qnorm(q)


def read_glb(path):
    data = Path(path).read_bytes()
    if data[:4] != b"glTF" or struct.unpack_from("<I", data, 4)[0] != 2:
        raise ValueError("expected a GLB v2 file")
    total = struct.unpack_from("<I", data, 8)[0]
    if total != len(data):
        raise ValueError("GLB declared length does not match file")
    cursor = 12
    document = None
    binary = None
    while cursor < len(data):
        length, kind = struct.unpack_from("<II", data, cursor)
        cursor += 8
        chunk = data[cursor:cursor + length]
        cursor += length
        if kind == 0x4E4F534A:
            document = json.loads(chunk.decode("utf-8").rstrip("\x00 \t\r\n"))
        elif kind == 0x004E4942:
            binary = chunk
    if document is None or binary is None:
        raise ValueError("GLB must contain JSON and BIN chunks")
    return document, binary


def accessor(document, binary, index):
    a = document["accessors"][index]
    if a.get("componentType") != 5126:
        raise ValueError(f"accessor {index} is not float32")
    count = a["count"]
    width = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}.get(a["type"])
    if not width:
        raise ValueError(f"unsupported accessor type {a['type']}")
    view = document["bufferViews"][a["bufferView"]]
    stride = view.get("byteStride", width * 4)
    start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
    out = []
    for i in range(count):
        out.append(struct.unpack_from("<" + "f" * width, binary, start + i * stride))
    return out


def parse_target_skeleton(path):
    lines = Path(path).read_text(encoding="utf-8-sig").splitlines()
    if len(lines) % 9:
        raise ValueError("target SKL/BON must have nine lines per bone")
    bones = []
    for i in range(0, len(lines), 9):
        name = lines[i].strip()
        parent = int(lines[i + 1].strip())
        rotation = [tuple(float(x.strip()) for x in lines[i + row].split(","))
                    for row in (2, 3, 4)]
        position = tuple(float(x.strip()) for x in lines[i + 5].split(","))
        if not name or len(position) != 3 or any(len(row) != 3 for row in rotation):
            raise ValueError(f"invalid target skeleton block at line {i + 1}")
        if parent >= len(lines) // 9 or parent < -1:
            raise ValueError(f"invalid parent index for {name}")
        bones.append({"name": name, "parent": parent, "rotation": q_from_slrr_rows(rotation),
                      "position": position})
    for i, bone in enumerate(bones):
        seen = set()
        parent = bone["parent"]
        while parent >= 0:
            if parent == i or parent in seen:
                raise ValueError("cyclic target skeleton")
            seen.add(parent)
            parent = bones[parent]["parent"]
    return bones


def node_bind(node):
    if "matrix" in node:
        raise ValueError("matrix-authored GLB nodes need TRS decomposition")
    return {"translation": tuple(node.get("translation", (0.0, 0.0, 0.0))),
            "rotation": qnorm(tuple(node.get("rotation", (0.0, 0.0, 0.0, 1.0)))),
            "scale": tuple(node.get("scale", (1.0, 1.0, 1.0)))}


def glb_node_hierarchy(nodes):
    parents = [-1] * len(nodes)
    for i, node in enumerate(nodes):
        for child in node.get("children", []):
            if parents[child] != -1:
                raise ValueError("GLB node has multiple parents")
            parents[child] = i
    return parents


def source_world_rotations(nodes, parents, local_rotations):
    worlds = [None] * len(nodes)

    def solve(i):
        if worlds[i] is not None:
            return worlds[i]
        parent = parents[i]
        worlds[i] = qnorm(local_rotations[i] if parent < 0 else
                          qmul(solve(parent), local_rotations[i]))
        return worlds[i]

    for i in range(len(nodes)):
        solve(i)
    return worlds


def matrixdata_clip(document, binary, target_skl, clip_index):
    bones = parse_target_skeleton(target_skl)
    nodes = document["nodes"]
    parents = glb_node_hierarchy(nodes)
    source_by_name = {n.get("name", ""): i for i, n in enumerate(nodes)}
    source_bind = [node_bind(n) for n in nodes]
    source_bone = {}
    for target in bones:
        src_name = TARGET_TO_SOURCE.get(target["name"])
        if not src_name:
            raise ValueError(f"no mapping configured for target bone {target['name']}")
        if src_name not in source_by_name:
            raise ValueError(f"source GLB does not contain mapped bone {src_name}")
        source_bone[target["name"]] = source_by_name[src_name]

    animation = document["animations"][clip_index]
    channels = {}
    all_times = set()
    for channel in animation.get("channels", []):
        sampler = animation["samplers"][channel["sampler"]]
        target = channel["target"]
        node_id = target["node"]
        path = target["path"]
        if path not in ("rotation", "translation"):
            continue
        if sampler.get("interpolation", "LINEAR") not in ("LINEAR", "STEP"):
            raise ValueError("only LINEAR/STEP glTF animation is supported in this prototype")
        times = [row[0] for row in accessor(document, binary, sampler["input"])]
        values = accessor(document, binary, sampler["output"])
        if len(times) != len(values) or not times:
            raise ValueError("animation sampler input/output counts differ")
        channels[(node_id, path)] = (times, values, sampler.get("interpolation", "LINEAR"))
        if node_id in source_bone.values():
            all_times.update(times)
    if not all_times:
        raise ValueError("clip has no keyframes for mapped pedestrian bones")
    times = sorted(all_times)
    t0 = times[0]
    times = [t - t0 for t in times]

    def sampled_channel(node_id, path, sample_time, fallback):
        item = channels.get((node_id, path))
        if item is None:
            return fallback
        src_times, vals, mode = item
        if sample_time <= src_times[0]:
            return vals[0]
        if sample_time >= src_times[-1]:
            return vals[-1]
        hi = next(i for i, x in enumerate(src_times) if x >= sample_time)
        lo = hi - 1
        if mode == "STEP":
            return vals[lo]
        alpha = (sample_time - src_times[lo]) / (src_times[hi] - src_times[lo])
        if path == "rotation":
            return tuple(qnorm(q_slerp(vals[lo], vals[hi], alpha)))
        return tuple(vals[lo][j] + (vals[hi][j] - vals[lo][j]) * alpha
                     for j in range(len(vals[lo])))

    def q_slerp(a, b, amount):
        dot = sum(a[i] * b[i] for i in range(4))
        if dot < 0.0:
            b = tuple(-x for x in b)
            dot = -dot
        if dot > 0.9995:
            return qnorm(tuple(a[i] + amount * (b[i] - a[i]) for i in range(4)))
        theta = math.acos(max(-1.0, min(1.0, dot)))
        sin_theta = math.sin(theta)
        wa = math.sin((1.0 - amount) * theta) / sin_theta
        wb = math.sin(amount * theta) / sin_theta
        return tuple(wa * a[i] + wb * b[i] for i in range(4))

    tracks = []
    for raw_time in sorted(all_times):
        local_anim = [b["rotation"] for b in source_bind]
        for (node_id, path), _ in channels.items():
            if path == "rotation":
                local_anim[node_id] = qnorm(sampled_channel(
                    node_id, path, raw_time, source_bind[node_id]["rotation"]))
        world_anim = source_world_rotations(nodes, parents, local_anim)
        world_rest = source_world_rotations(nodes, parents,
                                            [b["rotation"] for b in source_bind])
        desired_world = [None] * len(bones)
        for bi, target in enumerate(bones):
            src = source_bone[target["name"]]
            delta_world = qnorm(qmul(world_anim[src], qinv(world_rest[src])))
            desired_world[bi] = qnorm(qmul(delta_world, target["rotation"]))
        frame = []
        for bi, target in enumerate(bones):
            parent = target["parent"]
            local = desired_world[bi] if parent < 0 else qnorm(
                qmul(qinv(desired_world[parent]), desired_world[bi]))
            pos = target["position"]
            length = math.sqrt(sum(v * v for v in pos))
            direction = tuple(v / length for v in pos) if length > 1e-7 else (0.0, 1.0, 0.0)
            frame.append((local, direction))
        tracks.append(frame)

    out = bytearray(struct.pack("<I", len(bones)))
    for bi, bone in enumerate(bones):
        out += struct.pack("<I", len(tracks))
        for key, frame in enumerate(tracks):
            q, d = frame[bi]
            out += struct.pack("<8f", times[key], q[0], q[1], q[2], q[3],
                               d[0], d[1], d[2])
    out += ("\n".join(b["name"] for b in bones)).encode("utf-8")
    return out, len(times), len(bones), animation.get("name", f"animation_{clip_index}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("glb", type=Path)
    parser.add_argument("target_skl", type=Path, help="native New Age pedestrian .skl")
    parser.add_argument("output_matrixdata", type=Path)
    parser.add_argument("--animation", type=int, default=0, help="GLB animation index")
    parser.add_argument("--bon", type=Path, help="length donor; defaults to sibling target .bon")
    args = parser.parse_args()
    doc, blob = read_glb(args.glb)
    result, keys, bones, name = matrixdata_clip(doc, blob, args.target_skl, args.animation)
    args.output_matrixdata.parent.mkdir(parents=True, exist_ok=True)
    args.output_matrixdata.write_bytes(result)
    donor = args.bon or args.target_skl.with_suffix(".bon")
    out_bon = args.output_matrixdata.with_suffix(".bon")
    if donor.resolve() != out_bon.resolve():
        out_bon.write_bytes(donor.read_bytes())
    print(f"clip={name} bones={bones} keys={keys} bytes={len(result)}")
    print(f"matrixdata={args.output_matrixdata}")
    print(f"length donor={out_bon}")
    print("NOTE: syntactic conversion only; visual retarget, root motion, "
          "RPK registration, and vehicle transition timing remain unvalidated.")


if __name__ == "__main__":
    main()
