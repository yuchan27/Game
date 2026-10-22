from __future__ import annotations

import hashlib
import json
import sys
import wave
from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[2]
HASH_TYPES = {"npc", "structure", "item", "equipment", "enemy", "boss", "weapon_overlay"}
TEXT_SCAN_DIRS = ["data", "scenes", "scripts", "docs"]
PLAYER_EXPECTED_FRAMES = 8
PLAYER_FRAME_SIZE = (112, 128)
MOJIBAKE_MARKERS = ["\ufffd", "敶", "雓", "鞊", "撅", "銝", "餈", "摮", "蹓", "嚗", "", ""]


def resolve(path: str) -> Path:
    if path.startswith("res://"):
        return ROOT / path.replace("res://", "", 1)
    return ROOT / path


def fail(message: str, failures: list[str]) -> None:
    failures.append(message)
    print(f"[FAIL] {message}")


def read_json(path: Path, failures: list[str]) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"JSON parse failed: {path.relative_to(ROOT)} ({exc})", failures)
        return {}
    return data if isinstance(data, dict) else {}


def check_image(path: Path, label: str, failures: list[str]) -> bytes | None:
    if not path.exists():
        fail(f"{label} missing: {path.relative_to(ROOT)}", failures)
        return None
    try:
        image = Image.open(path).convert("RGBA")
    except Exception as exc:
        fail(f"{label} cannot load: {path.relative_to(ROOT)} ({exc})", failures)
        return None
    alpha = image.getchannel("A")
    if alpha.getbbox() is None:
        fail(f"{label} is fully transparent: {path.relative_to(ROOT)}", failures)
    if image.size[0] < 8 or image.size[1] < 8:
        fail(f"{label} is too small to be a production asset: {path.relative_to(ROOT)}", failures)
    return path.read_bytes()


def verify_manifest(failures: list[str]) -> None:
    manifest_path = ROOT / "data" / "art" / "visual_assets.json"
    data = read_json(manifest_path, failures)
    assets: dict[str, dict] = data.get("assets", {}) if isinstance(data.get("assets", {}), dict) else {}
    if len(assets) < 35:
        fail("visual asset manifest has too few entries", failures)

    seen_paths: dict[str, str] = {}
    hashes: dict[str, str] = {}
    for asset_id, asset in assets.items():
        path = str(asset.get("path", ""))
        asset_type = str(asset.get("type", ""))
        if not path:
            fail(f"{asset_id} has no path", failures)
            continue
        if bool(asset.get("unique_required", False)) and path in seen_paths:
            fail(f"{asset_id} shares exact path with {seen_paths[path]}: {path}", failures)
        if bool(asset.get("unique_required", False)):
            seen_paths[path] = asset_id

        raw = check_image(resolve(path), asset_id, failures)
        if raw is not None and asset.get("source_sha256"):
            if hashlib.sha256(raw).hexdigest() != asset["source_sha256"]:
                fail(f"{asset_id} source image differs from its recorded SHA-256", failures)
            source_image = Image.open(resolve(path)).convert("RGBA")
            if source_image.getchannel("A").getextrema()[0] != 0:
                fail(f"{asset_id} requires a transparent background", failures)
            if list(source_image.size) != asset.get("source_dimensions"):
                fail(f"{asset_id} source dimensions disagree with manifest", failures)
        reuse_of = str(asset.get("reuse_of", ""))
        if reuse_of:
            original = assets.get(reuse_of, {})
            original_path = resolve(str(original.get("path", "")))
            if not original or not original_path.is_file() or raw != original_path.read_bytes():
                fail(f"{asset_id} declared reuse does not match {reuse_of}", failures)
            else:
                print(f"[WARN] {asset_id} intentionally reuses {reuse_of}; unique art is deferred")
        if raw is not None and asset_type in HASH_TYPES and bool(asset.get("unique_required", False)):
            digest = hashlib.sha256(raw).hexdigest()
            if digest in hashes:
                fail(f"{asset_id} has duplicate PNG hash with {hashes[digest]}", failures)
            hashes[digest] = asset_id

        portrait = str(asset.get("portrait", ""))
        if portrait:
            check_image(resolve(portrait), f"{asset_id} portrait", failures)

        variant_prefix = str(asset.get("variant_prefix", ""))
        variants = int(asset.get("variants", 0))
        if variant_prefix and variants > 0:
            variant_hashes: set[str] = set()
            for index in range(variants):
                variant_path = resolve(f"{variant_prefix}{index}.png")
                raw_variant = check_image(variant_path, f"{asset_id} variant {index}", failures)
                if raw_variant is not None:
                    variant_hashes.add(hashlib.sha256(raw_variant).hexdigest())
            if len(variant_hashes) < min(variants, 4):
                fail(f"{asset_id} has too few visually distinct variants", failures)


def verify_json_references(failures: list[str]) -> None:
    for path in [
        ROOT / "data" / "maps" / "npcs.json",
        ROOT / "data" / "maps" / "quests.json",
        ROOT / "data" / "maps" / "events.json",
        ROOT / "data" / "maps" / "wasteland_routes.json",
        ROOT / "data" / "items" / "equipment.json",
        ROOT / "data" / "items" / "recipes.json",
        ROOT / "data" / "enemies" / "enemies.json",
        ROOT / "data" / "art" / "player_animation_manifest.json",
    ]:
        read_json(path, failures)


def _bbox_center_bottom(box: tuple[int, int, int, int]) -> tuple[float, float]:
    return ((box[0] + box[2]) / 2.0, float(box[3]))


def _verify_body_frame(path: Path, action_id: str, direction: int, frame: int, failures: list[str]) -> tuple[int, int, int, int] | None:
    if not path.exists():
        fail(f"R-17 split frame missing: {action_id} dir {direction} frame {frame}", failures)
        return None
    frame_image = Image.open(path).convert("RGBA")
    if frame_image.size != PLAYER_FRAME_SIZE:
        fail(f"R-17 split frame has wrong size: {path.relative_to(ROOT)} {frame_image.size}", failures)
    bbox = frame_image.getbbox()
    if bbox is None:
        fail(f"R-17 split frame is blank: {path.relative_to(ROOT)}", failures)
        return None
    if action_id in {"idle", "walk"}:
        if bbox[0] <= 0 or bbox[2] >= PLAYER_FRAME_SIZE[0] or bbox[1] <= 0 or bbox[3] >= PLAYER_FRAME_SIZE[1]:
            fail(f"R-17 locomotion frame touches edge and may be clipped: {path.relative_to(ROOT)} bbox={bbox}", failures)
        # Side/back views may occlude a hand. Color counts cannot prove missing art.
    elif action_id in {"shoot", "draw_sword", "slash"}:
        if bbox[0] <= 1 or bbox[2] >= PLAYER_FRAME_SIZE[0] - 1:
            fail(f"R-17 action body frame touches horizontal edge; weapon should not be baked into body: {path.relative_to(ROOT)} bbox={bbox}", failures)
    return bbox


def verify_player_manifest(failures: list[str]) -> None:
    manifest = read_json(ROOT / "data" / "art" / "player_animation_manifest.json", failures)
    frame_size = manifest.get("frame_size", [])
    directions = int(manifest.get("directions", 0))
    frames = int(manifest.get("frames_per_action", 0))
    actions = manifest.get("actions", [])
    if frame_size != list(PLAYER_FRAME_SIZE):
        fail("R-17 player manifest frame_size must be [112, 128]", failures)
    if directions != 8 or frames != PLAYER_EXPECTED_FRAMES or len(actions) != 9:
        fail("R-17 player manifest must define 9 actions, 8 directions, 8 frames", failures)
    split_frame_dir = str(manifest.get("split_frame_dir", ""))
    action_sheet_dir = str(manifest.get("action_sheet_dir", ""))
    if not split_frame_dir:
        fail("R-17 player manifest must declare split_frame_dir", failures)
    if not action_sheet_dir:
        fail("R-17 player manifest must declare action_sheet_dir", failures)

    action_ids = [str(action.get("id", "")) for action in actions if isinstance(action, dict)]
    if len(set(action_ids)) != 9:
        fail("R-17 animation action ids must be unique", failures)
    reused_clips = []
    for action_id in action_ids:
        sheet_path = resolve(f"{action_sheet_dir}/{action_id}.png")
        if not sheet_path.exists():
            fail(f"R-17 action sheet missing: {action_id}", failures)
        else:
            sheet = Image.open(sheet_path).convert("RGBA")
            if sheet.size != (PLAYER_FRAME_SIZE[0] * PLAYER_EXPECTED_FRAMES, PLAYER_FRAME_SIZE[1] * 8):
                fail(f"R-17 action sheet has wrong size for {action_id}: {sheet.size}", failures)
        for direction in range(8):
            anchor_boxes: list[tuple[int, int, int, int]] = []
            frame_hashes: set[str] = set()
            for frame in range(PLAYER_EXPECTED_FRAMES):
                frame_path = resolve(f"{split_frame_dir}/{action_id}/dir_{direction}/frame_{frame}.png")
                bbox = _verify_body_frame(frame_path, action_id, direction, frame, failures)
                if frame_path.is_file():
                    frame_hashes.add(hashlib.sha256(frame_path.read_bytes()).hexdigest())
                if bbox is not None and action_id in {"idle", "walk"}:
                    anchor_boxes.append(bbox)
            if len(anchor_boxes) >= 2:
                anchors = [_bbox_center_bottom(box) for box in anchor_boxes]
                xs = [point[0] for point in anchors]
                bottoms = [point[1] for point in anchors]
                if max(xs) - min(xs) > 12.0:
                    fail(f"R-17 {action_id} dir {direction} drifts horizontally across frames: {xs}", failures)
                if max(bottoms) - min(bottoms) > 8.0:
                    fail(f"R-17 {action_id} dir {direction} foot anchor drifts vertically across frames: {bottoms}", failures)
            if len(frame_hashes) < PLAYER_EXPECTED_FRAMES:
                reused_clips.append(f"{action_id}/{direction}:{len(frame_hashes)}/8")

    if reused_clips:
        print("[WARN] Authored clips reuse frames (unique/total): " + ", ".join(reused_clips))

    atlas_path = resolve(str(manifest.get("atlas_path", "")))
    if not atlas_path.is_file():
        fail("R-17 atlas is missing: " + str(atlas_path.relative_to(ROOT)), failures)
    else:
        image = Image.open(atlas_path).convert("RGBA")
        expected_size = (PLAYER_FRAME_SIZE[0] * PLAYER_EXPECTED_FRAMES * 9, PLAYER_FRAME_SIZE[1] * 8)
        if image.size != expected_size:
            fail(f"R-17 atlas size must be {expected_size[0]}x{expected_size[1]}, got {image.size}", failures)
        idle_right = image.crop((0, 0, 112, 128))
        idle_left = image.crop((0, 4 * 128, 112, 5 * 128))
        if ImageChops.difference(idle_right, idle_left).getbbox() is None:
            fail("R-17 A/D idle frames are identical; left and right would read as reversed or flat", failures)
        # Direction-specific authored poses need not be exact horizontal mirrors.
        if image.size == expected_size:
            for action_index, action_id in enumerate(action_ids):
                sheet_path = resolve(f"{action_sheet_dir}/{action_id}.png")
                if sheet_path.is_file():
                    region = image.crop((action_index * 896, 0, (action_index + 1) * 896, 1024))
                    sheet = Image.open(sheet_path).convert("RGBA")
                    if region.size != sheet.size or region.tobytes() != sheet.tobytes():
                        message = f"R-17 runtime atlas differs from reference action sheet: {action_id}"
                        if manifest.get("action_sheets_usage") == "reference_only":
                            print("[WARN] " + message)
                        else:
                            fail(message, failures)
            for row in range(8):
                for column in range(8 * len(action_ids)):
                    frame = image.crop((column * 112, row * 128, (column + 1) * 112, (row + 1) * 128))
                    if frame.getchannel("A").getbbox() is None:
                        fail(f"R-17 runtime atlas has a blank frame: row {row}, column {column}", failures)


def verify_weapon_overlays(failures: list[str]) -> None:
    weapon_dir = ROOT / "assets" / "sprites" / "player" / "weapons"
    for path in weapon_dir.glob("*_overlay.png"):
        raw = check_image(path, path.stem, failures)
        if raw is None:
            continue
        image = Image.open(path).convert("RGBA")
        bbox = image.getbbox()
        if bbox is None:
            continue
        if bbox[2] - bbox[0] < 26 or bbox[3] - bbox[1] < 16:
            fail(f"weapon overlay is too small or blocky-looking: {path.relative_to(ROOT)} bbox={bbox}", failures)


def verify_audio_assets(failures: list[str]) -> None:
    for rel_path, min_seconds in [
        ("assets/audio/music_intro.wav", 45.0),
        ("assets/audio/music_village.mp3", 24.0),
        ("assets/audio/music_guild.mp3", 24.0),
        ("assets/audio/music_wasteland.mp3", 24.0),
        ("assets/audio/voice_intro_story.wav", 20.0),
    ]:
        path = ROOT / rel_path
        if not path.exists():
            fail(f"audio missing: {rel_path}", failures)
            continue
        try:
            if path.suffix == ".mp3":
                raw = path.read_bytes()
                if len(raw) < 1024 or not (raw.startswith(b"ID3") or raw[0] == 255 and raw[1] & 224 == 224):
                    fail(f"invalid MP3 header: {rel_path}", failures)
                # Decode and duration are checked through the native Godot importer/runner.
                continue
            with wave.open(str(path), "rb") as wav:
                seconds = wav.getnframes() / float(wav.getframerate())
                if seconds < min_seconds:
                    fail(f"audio too short: {rel_path} {seconds:.2f}s < {min_seconds:.2f}s", failures)
                sample_width = wav.getsampwidth()
                frames = wav.readframes(min(wav.getnframes(), wav.getframerate() * 3))
                if sample_width == 2 and frames:
                    samples = [int.from_bytes(frames[i:i + 2], "little", signed=True) for i in range(0, len(frames) - 1, 2)]
                    peak = max(abs(value) for value in samples) if samples else 0
                    if peak < 512:
                        fail(f"audio appears silent: {rel_path}", failures)
        except Exception as exc:
            fail(f"audio cannot load: {rel_path} ({exc})", failures)


def verify_no_mojibake(failures: list[str]) -> None:
    for directory in TEXT_SCAN_DIRS:
        base = ROOT / directory
        if not base.exists():
            continue
        for path in base.rglob("*"):
            if ".godot" in path.parts or path.suffix.lower() not in {".gd", ".json", ".md", ".txt"}:
                continue
            if path.name == "verify_visual_assets.py":
                continue
            text = path.read_text(encoding="utf-8", errors="replace")
            for marker in MOJIBAKE_MARKERS:
                index = text.find(marker)
                if index >= 0:
                    near = text[max(0, index - 18): index + 18].replace("\n", " ")
                    fail(f"mojibake marker in {path.relative_to(ROOT)} near {near!r}", failures)
                    break


def main() -> int:
    failures: list[str] = []
    verify_manifest(failures)
    verify_json_references(failures)
    verify_player_manifest(failures)
    verify_weapon_overlays(failures)
    verify_audio_assets(failures)
    verify_no_mojibake(failures)
    if failures:
        print(f"[VERIFY] visual asset validation failed: {len(failures)} issue(s)")
        return 1
    print("[VERIFY] visual assets OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
