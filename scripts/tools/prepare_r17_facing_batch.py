#!/usr/bin/env python3
"""prepare_r17_facing_batch.py

Portable standard-library-only production request builder for Wasteland Recycler (Godot 4.6.3).
Generates missing 32-facing idle requests and prompts from validated art manifests.
"""

import argparse
import hashlib
import json
import math
import struct
import sys
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(description="Build production idle-facing requests and prompts.")
    parser.add_argument("--project-root", required=True, help="Path to Godot project root.")
    parser.add_argument("--output", required=True, help="Destination directory (must not exist, outside root).")
    parser.add_argument("--family", default="blade", choices=["blade", "rifle", "heavy"], help="Weapon family.")
    return parser.parse_args()


def read_png_dimensions(filepath: Path):
    with filepath.open("rb") as f:
        sig = f.read(8)
        if sig != b"\x89PNG\r\n\x1a\n":
            raise ValueError(f"Invalid PNG signature: {filepath}")
        chunk_header = f.read(8)
        if len(chunk_header) < 8:
            raise ValueError(f"Truncated PNG chunk header: {filepath}")
        chunk_len, chunk_type = struct.unpack(">I4s", chunk_header)
        if chunk_len != 13 or chunk_type != b"IHDR":
            raise ValueError(f"First chunk must be 13-byte IHDR: {filepath}")
        ihdr_payload = f.read(13)
        if len(ihdr_payload) < 13:
            raise ValueError(f"Truncated IHDR chunk payload: {filepath}")
        width, height = struct.unpack(">II", ihdr_payload[:8])
        if width <= 0 or height <= 0:
            raise ValueError(f"Invalid PNG dimensions {width}x{height}: {filepath}")
        return width, height


def compute_sha256(filepath: Path) -> str:
    hasher = hashlib.sha256()
    with filepath.open("rb") as f:
        while chunk := f.read(65536):
            hasher.update(chunk)
    return hasher.hexdigest()


def check_num(val, name, allow_zero=True, min_val=None, max_val=None):
    if isinstance(val, bool) or not isinstance(val, (int, float)):
        raise ValueError(f"{name} must be numeric, got {type(val).__name__}")
    if not math.isfinite(val):
        raise ValueError(f"{name} must be finite: {val}")
    if not allow_zero and val == 0:
        raise ValueError(f"{name} must be non-zero")
    if min_val is not None and val < min_val:
        raise ValueError(f"{name} must be >= {min_val}, got {val}")
    if max_val is not None and val > max_val:
        raise ValueError(f"{name} must be <= {max_val}, got {val}")
    return val


def resolve_contained_file(path_str: str, project_root: Path) -> Path:
    if not isinstance(path_str, str) or not path_str.strip():
        raise ValueError("File path must be non-empty string")
    clean = path_str.strip()
    if clean.startswith("res://"):
        clean = clean[6:]
    if "\\" in clean or "/../" in f"/{clean}/" or clean.startswith(("../", "/")):
        raise ValueError(f"Disallowed traversal or absolute path: {path_str}")
    resolved = (project_root / clean).resolve()
    if not resolved.is_relative_to(project_root):
        raise ValueError(f"Path escapes project root: {path_str}")
    if not resolved.is_file():
        raise FileNotFoundError(f"Missing referenced file: {resolved}")
    return resolved


def validate_cells(cells_data, img_w, img_h, expected_count, label):
    if not isinstance(cells_data, list) or len(cells_data) != expected_count:
        raise ValueError(f"{label} cells count must match active angles ({expected_count})")
    validated = []
    for idx, cell in enumerate(cells_data):
        if not isinstance(cell, list) or len(cell) not in (9, 11):
            raise ValueError(f"{label} cell[{idx}] must contain exactly 9 or 11 numbers")
        nums = [check_num(v, f"{label} cell[{idx}][{i}]") for i, v in enumerate(cell)]
        x, y, w, h = nums[0], nums[1], nums[2], nums[3]
        for val, cname in zip((x, y, w, h), ("x", "y", "width", "height")):
            if not float(val).is_integer():
                raise ValueError(f"{label} cell[{idx}] {cname} must be integer without silent truncation: {val}")
        x, y, w, h = int(x), int(y), int(w), int(h)
        if w <= 0 or h <= 0:
            raise ValueError(f"{label} cell[{idx}] dimensions must be positive: {w}x{h}")
        if x < 0 or y < 0 or x + w > img_w or y + h > img_h:
            raise ValueError(f"{label} cell[{idx}] [{x},{y},{w},{h}] exceeds PNG {img_w}x{img_h}")
        sole_x, sole_y = nums[4], nums[5]
        grip_x, grip_y = nums[6], nums[7]
        if not (x <= sole_x <= x + w and y <= sole_y <= y + h):
            raise ValueError(f"{label} cell[{idx}] sole ({sole_x},{sole_y}) outside crop [{x},{y},{w},{h}]")
        if not (x <= grip_x <= x + w and y <= grip_y <= y + h):
            raise ValueError(f"{label} cell[{idx}] grip ({grip_x},{grip_y}) outside crop [{x},{y},{w},{h}]")
        body_h = nums[8]
        if body_h <= 0:
            raise ValueError(f"{label} cell[{idx}] standing body height index 8 must be positive: {body_h}")
        muzzle = [nums[9], nums[10]] if len(nums) == 11 else None
        if muzzle is not None and not (x <= muzzle[0] <= x + w and y <= muzzle[1] <= y + h):
            raise ValueError(f"{label} cell[{idx}] muzzle ({muzzle[0]},{muzzle[1]}) outside crop [{x},{y},{w},{h}]")
        validated.append({
            "crop": [x, y, w, h],
            "absolute_sole": [sole_x, sole_y],
            "absolute_grip": [grip_x, grip_y],
            "standing_body_height": body_h,
            "muzzle": muzzle,
        })
    return validated


def find_bracketing(target, active_angles):
    if target > active_angles[-1] or target < active_angles[0]:
        return (active_angles[-1], len(active_angles) - 1), (active_angles[0], 0)
    for i in range(len(active_angles) - 1):
        if active_angles[i] < target < active_angles[i + 1]:
            return (active_angles[i], i), (active_angles[i + 1], i + 1)
    raise ValueError(f"Angle {target} could not be bracketed")


def validate_idle_facing_extras(family, keys, project_root, base_angles):
    actions = family.get("actions")
    if not isinstance(actions, dict) or not isinstance(actions.get("idle"), list) or not actions["idle"]:
        raise ValueError("family actions.idle must be a non-empty sequence for idle production")
    idle_slot_count = len(actions["idle"])

    raw_actions = family.get("additional_action_facings", {})
    if not isinstance(raw_actions, dict):
        raise ValueError("additional_action_facings must be an object")
    raw_extras = raw_actions.get("idle", [])
    if not isinstance(raw_extras, list):
        raise ValueError("additional_action_facings.idle must be an array")

    seen_angle_keys = {round(angle, 2) for angle in base_angles}
    base_atlas_paths = set()
    for key_spec in keys.values():
        if not isinstance(key_spec, dict):
            continue
        base_path = key_spec.get("path")
        if not isinstance(base_path, str) or not base_path.strip():
            continue
        clean_path = base_path.strip()
        if clean_path.startswith("res://"):
            clean_path = clean_path[6:]
        base_atlas_paths.add(str((project_root / clean_path).resolve()).casefold())

    valid_angles = []
    for extra_index, extra in enumerate(raw_extras):
        label = f"additional_action_facings.idle[{extra_index}]"
        if not isinstance(extra, dict):
            raise ValueError(f"{label} must be an object")
        enabled = extra.get("enabled", False)
        if not isinstance(enabled, bool):
            raise ValueError(f"{label}.enabled must be a boolean")
        if not enabled:
            continue

        angle = check_num(extra.get("angle"), f"{label}.angle", min_val=0.0, max_val=360.0)
        if angle >= 360.0:
            raise ValueError(f"{label}.angle must be < 360 degrees")
        if round(angle % 11.25, 4) not in (0.0, 11.25):
            raise ValueError(f"{label}.angle {angle} must be on the 11.25 degree grid")
        angle_key = round(float(angle), 2)
        if angle_key in seen_angle_keys:
            raise ValueError(f"{label}.angle {angle} duplicates a base or enabled idle facing")

        frames = extra.get("frames")
        if not isinstance(frames, list) or len(frames) != idle_slot_count:
            raise ValueError(
                f"{label}.frames count must match idle sequence slots ({idle_slot_count})"
            )
        for frame_index, frame in enumerate(frames):
            frame_label = f"{label}.frames[{frame_index}]"
            if not isinstance(frame, dict):
                raise ValueError(f"{frame_label} must be an object")
            try:
                frame_path = resolve_contained_file(frame.get("path"), project_root)
                if str(frame_path).casefold() in base_atlas_paths:
                    raise ValueError(f"{frame_label} reuses a base family atlas path")
                frame_w, frame_h = read_png_dimensions(frame_path)
                validate_cells([frame.get("cell")], frame_w, frame_h, 1, frame_label)
            except (OSError, ValueError) as exc:
                raise ValueError(f"Invalid enabled {frame_label}: {exc}") from exc

        valid_angles.append(float(angle))
        seen_angle_keys.add(angle_key)

    return valid_angles


def build_prompt(angle, lower, upper, family, body_height):
    weapon_desc = {
        "blade": "short straight sword with short silver blade held firmly in right hand",
        "rifle": "compact two-handed rifle held with right trigger hand",
        "heavy": "two-handed heavy weapon held with right-hand grip",
    }.get(family, "weapon in right hand")

    return (
        f"Generate a new 3D camera perspective view at {angle:.2f} degrees on the Godot screen plane "
        f"(0 E/right, 90 S/front, 180 W/left, 270 N/back; clockwise). Perspective brackets between "
        f"base reference angles {lower:.2f} deg and {upper:.2f} deg. True 3D perspective projection; "
        f"do NOT flat-rotate or mirror existing sprites. "
        f"Art Style: Explicit crisp hard-edged pixel art for a 2.5D pixel game. Coherent limited color palette, "
        f"controlled pixel cluster size, and nearest-downsample readability. Never produce smooth 3D renders, "
        f"painterly textures, soft shading, or antialiasing. "
        f"Pose & Framing: Neutral standing idle with both boots firmly planted. Entire helmet, boots, cape, and weapon "
        f"must remain completely inside generous transparent margins. No floor, no ground shadow, no text, and no labels. "
        f"Character & Equipment: Medieval knight in blue-gray metal armor with gold trim, cylindrical closed helm with "
        f"a golden cross emblem strictly on the front of the helmet only, and a crimson red cape draping behind. "
        f"Weapon & Identity: {weapon_desc}. Strictly preserve right-hand grip, character proportions, and family-specific "
        f"ratios directly from the existing reference sheets; do not invent new armor or weapon designs. "
        f"Source canvas ~300px standing body height on transparent background, structured to scale cleanly down to "
        f"runtime target gameplay body height of {body_height:.1f}px. "
        f"Note: This prompt provides directional perspective guidance only; exact mathematical pixel angles cannot "
        f"be certified from raster output without Codex lead review."
    )


def main():
    args = parse_args()
    root = Path(args.project_root).resolve()
    if not root.is_dir():
        raise NotADirectoryError(f"Invalid project root: {root}")

    out_path = Path(args.output)
    if out_path.is_symlink():
        raise ValueError(f"Output path cannot be a symlink: {out_path}")
    if out_path.exists():
        raise FileExistsError(f"Output directory already exists: {out_path}")
    if out_path.resolve().is_relative_to(root):
        raise ValueError(f"Output directory must be outside project root: {out_path}")

    rel_manifest = "data/art/r17_presentation_v2.json" if args.family == "blade" else "data/art/r17_weapon_families_v2.json"
    manifest_file = resolve_contained_file(rel_manifest, root)

    with manifest_file.open("r", encoding="utf-8") as f:
        raw = json.load(f)

    if not isinstance(raw, dict) or "families" not in raw or not isinstance(raw["families"], dict):
        raise ValueError("Invalid manifest: missing 'families' mapping")
    if args.family not in raw["families"]:
        raise ValueError(f"Family '{args.family}' not found in manifest families")

    fam = raw["families"][args.family]
    body_h_val = fam.get("body_height_px", raw.get("body_height_px"))
    if body_h_val is None:
        raise ValueError(f"body_height_px not found in family '{args.family}' or root")
    body_height = check_num(body_h_val, "body_height_px", allow_zero=False, min_val=1.0)

    raw_angles = fam.get("facing_angles")
    if not isinstance(raw_angles, list) or len(raw_angles) < 2:
        raise ValueError("facing_angles must be a list of at least 2 angles for bracketing")

    base_angles = []
    for i, a in enumerate(raw_angles):
        val = check_num(a, f"facing_angles[{i}]", min_val=0.0, max_val=360.0)
        if val >= 360.0:
            raise ValueError(f"Angle {val} must be < 360")
        if not (round(val % 11.25, 4) in (0.0, 11.25)):
            raise ValueError(f"Angle {val} must be on 11.25 degree grid")
        if i > 0 and val <= base_angles[-1]:
            raise ValueError("facing_angles must be strictly ascending and distinct")
        base_angles.append(float(val))

    keys = fam.get("keys")
    if not isinstance(keys, dict) or "ready" not in keys:
        raise ValueError("family missing 'keys.ready' specification")
    ready_spec = keys["ready"]
    identity_spec = keys.get("contact_a", ready_spec)

    idle_extra_angles = validate_idle_facing_extras(fam, keys, root, base_angles)
    active_idle_angles = sorted(base_angles + idle_extra_angles)

    ready_file = resolve_contained_file(ready_spec["path"], root)
    ready_w, ready_h = read_png_dimensions(ready_file)
    ready_cells = validate_cells(ready_spec["cells"], ready_w, ready_h, len(base_angles), "ready")
    ready_sha = compute_sha256(ready_file)

    ident_file = resolve_contained_file(identity_spec["path"], root)
    ident_w, ident_h = read_png_dimensions(ident_file)
    ident_cells = validate_cells(identity_spec["cells"], ident_w, ident_h, len(base_angles), "identity")
    ident_sha = compute_sha256(ident_file)

    full_grid = [round(i * 11.25, 2) for i in range(32)]
    active_set = {round(angle, 2) for angle in active_idle_angles}
    missing_angles = [a for a in full_grid if a not in active_set]

    requests = []
    prompt_lines = []
    for req_angle in missing_angles:
        (lower_deg, lower_idx), (upper_deg, upper_idx) = find_bracketing(req_angle, base_angles)
        p_text = build_prompt(req_angle, lower_deg, upper_deg, args.family, body_height)
        prompt_lines.append(f"=== ANGLE {req_angle:.2f} DEG ===")
        prompt_lines.append(p_text)
        prompt_lines.append("")

        requests.append({
            "action": "idle",
            "requested_angle": req_angle,
            "bracket": {
                "reference_set": "base",
                "lower": {
                    "angle": lower_deg,
                    "cell_index": lower_idx,
                    "ready": {"path": ready_spec["path"], "sha256": ready_sha, "metadata": ready_cells[lower_idx]},
                    "identity": {"path": identity_spec["path"], "sha256": ident_sha, "metadata": ident_cells[lower_idx]},
                },
                "upper": {
                    "angle": upper_deg,
                    "cell_index": upper_idx,
                    "ready": {"path": ready_spec["path"], "sha256": ready_sha, "metadata": ready_cells[upper_idx]},
                    "identity": {"path": identity_spec["path"], "sha256": ident_sha, "metadata": ident_cells[upper_idx]},
                },
            },
            "prompt": p_text,
            "candidate_registration": {
                "requested_angle": req_angle,
                "review": "pending",
                "actual_image": None,
                "visually_accepted_angle": None,
                "runtime_registered_angle": None,
                "atlas_cell": None,
                "grip_anchor": None,
                "sole_anchor": None,
            },
        })

    payload = {
        "project": raw.get("project", "Wasteland Recycler"),
        "family": args.family,
        "production_action": "idle",
        "runtime_body_height_px": body_height,
        "runtime_count_delta": 0,
        "base_facing_count": len(base_angles),
        "base_facing_angles": base_angles,
        "active_facing_count": len(active_idle_angles),
        "active_facing_angles": active_idle_angles,
        "missing_facing_count": len(missing_angles),
        "missing_facing_angles": missing_angles,
        "requests": requests,
    }

    out_path.mkdir(parents=True, exist_ok=False)
    with (out_path / "batch_requests.json").open("x", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)
        f.write("\n")
    with (out_path / "prompts.txt").open("x", encoding="utf-8") as f:
        f.write("\n".join(prompt_lines))
        f.write("\n")

    print(f"Generated {len(requests)} facing requests in {out_path}")


if __name__ == "__main__":
    main()
