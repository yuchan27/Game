"""Read-only data/scene/Skill contract checks. No engine or asset production."""
from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOCUMENTS = {
    "items": "data/items/equipment.json", "recipes": "data/items/recipes.json",
    "enemies": "data/enemies/enemies.json", "quests": "data/maps/quests.json",
    "npcs": "data/maps/npcs.json", "events": "data/maps/events.json",
    "routes": "data/maps/wasteland_routes.json", "params": "data/maps/wasteland_params.json",
    "art": "data/art/visual_assets.json", "animation": "data/art/player_animation_manifest.json",
}
SCENES = {"main", "village", "guild", "wasteland"}


def validate_data(docs: dict) -> list[str]:
    errors: list[str] = []

    def require(ok: bool, message: str) -> None:
        if not ok:
            errors.append(message)

    def mapping(value, label: str) -> dict:
        require(isinstance(value, dict), label + " must be an object")
        return value if isinstance(value, dict) else {}

    def rows(value, label: str) -> list[dict]:
        require(isinstance(value, list), label + " must be an array")
        if not isinstance(value, list):
            return []
        require(all(isinstance(x, dict) for x in value), label + " entries must be objects")
        result = [x for x in value if isinstance(x, dict)]
        ids = [x.get("id") for x in result]
        require(all(isinstance(x, str) and x for x in ids), label + " ids must be nonempty strings")
        require(len(set(str(x) for x in ids)) == len(ids), label + " ids must be unique")
        return result

    def positive(value, label: str) -> None:
        require(type(value) in (int, float) and math.isfinite(value) and value > 0,
                label + " must be positive and finite")

    items = mapping(docs.get("items", {}), "items")
    equipment = mapping(items.get("equipment"), "equipment")
    resources = mapping(items.get("resources"), "resources")
    known_items = equipment.keys() | resources.keys()
    enemies = mapping(mapping(docs.get("enemies", {}), "enemies document").get("enemies"), "enemies")
    routes = mapping(mapping(docs.get("routes", {}), "routes document").get("routes"), "routes")
    art = mapping(mapping(docs.get("art", {}), "art document").get("assets"), "assets")
    for key, value in art.items():
        asset = mapping(value, "asset " + key)
        if "collision_footprint" in asset:
            foot = asset["collision_footprint"]
            valid = (isinstance(foot, list) and len(foot) == 4
                     and all(type(v) in (int, float) and math.isfinite(v) for v in foot))
            if valid:
                left, top, width, height = foot
                valid = left >= 0 and top >= 0 and width > 0 and height > 0 and left + width <= 1 and top + height <= 1
            require(valid, key + ": collision_footprint must fit the normalized source canvas")

    def quantities(value, label: str) -> None:
        for key, amount in mapping(value, label).items():
            require(key in known_items, f"{label}: unknown item {key}")
            require(type(amount) is int and amount > 0, f"{label}.{key}: quantity must be a positive integer")

    for key, value in {**equipment, **resources}.items():
        item = mapping(value, "item " + key)
        require(isinstance(item.get("name"), str) and bool(item.get("name")), f"{key}: name required")
        for field in ("icon_asset_id", "world_drop_asset_id", "weapon_sprite_asset_id"):
            if field in item:
                require(item[field] in art, f"{key}.{field}: unknown asset {item[field]}")
        if key in equipment:
            require(item.get("slot") in {"weapon", "ranged", "armor", "tool"}, f"{key}: invalid equipment slot")
        else:
            positive(item.get("stack"), key + ".stack")

    for kind in ("recipes", "quests", "npcs", "events"):
        entries = rows(mapping(docs.get(kind, {}), kind + " document").get(kind), kind)
        for entry in entries:
            label = kind + "." + str(entry.get("id"))
            for field in ("cost", "result", "reward"):
                if field in entry:
                    quantities(entry[field], label + "." + field)
            if kind == "npcs":
                require(entry.get("scene") in SCENES, label + ": unknown scene")
                for field in ("sprite_asset_id", "portrait_asset_id"):
                    require(entry.get(field) in art, label + ": unknown " + field)
                position = mapping(entry.get("position"), label + ".position")
                for axis in ("x", "y"):
                    v = position.get(axis)
                    require(type(v) in (float, int) and math.isfinite(v), label + ": invalid position")
            if kind == "quests":
                require(entry.get("route") in routes, label + ": unknown route")
                objectives = entry.get("objectives")
                require(isinstance(objectives, list) and bool(objectives), label + ": objectives required")
                for objective in objectives if isinstance(objectives, list) else []:
                    objective = mapping(objective, label + ".objective")
                    require(objective.get("type") in {"collect", "defeat"}, label + ": unsupported objective type")
                    v = objective.get("amount")
                    require(type(v) is int and v > 0, label + ": objective amount must be positive integer")
                    if objective.get("type") == "collect":
                        require(objective.get("item") in known_items, label + ": unknown objective item")
                    else:
                        require(objective.get("counter") in {"defeat_enemy", "defeat_boss"}, label + ": unsupported objective counter")

    for key, value in enemies.items():
        enemy = mapping(value, key)
        for field in ("hp", "speed", "damage"):
            positive(enemy.get(field), key + "." + field)
        quantities(enemy.get("drop_table", {}), key + ".drop_table")
        for item_id, drop in mapping(enemy.get("rare_drop_table", {}), key + ".rare_drop_table").items():
            drop = mapping(drop, key + ".rare_drop")
            quantities({item_id: drop.get("amount")}, key + ".rare_drop")
            v = drop.get("chance")
            require(type(v) in (int, float) and 0 <= v <= 100, key + ": drop chance out of range")
        for route in enemy.get("routes", []):
            require(route in routes, key + ": unknown enemy route")

    for key, value in routes.items():
        route = mapping(value, key)
        for field, valid in (("enemy_mix", enemies), ("resource_mix", resources)):
            mix = route.get(field)
            require(isinstance(mix, list) and bool(mix), key + ": empty/invalid " + field)
            for member in mix if isinstance(mix, list) else []:
                require(member in valid, f"{key}.{field}: unknown id {member}")
        for prop in route.get("prop_mix", []):
            require("prop_" + str(prop) in art, key + ": unknown prop " + str(prop))
        if "landmark_prop" in route:
            require("prop_" + str(route["landmark_prop"]) in art, key + ": unknown landmark prop")
        require(type(route.get("boss_enabled")) is bool, key + ": boss_enabled must be boolean")
    for key in ("width_tiles", "height_tiles", "tile_size", "enemy_limit", "projectile_limit", "prop_nodes", "resource_nodes"):
        value = mapping(docs.get("params", {}), "params").get(key)
        require(type(value) is int and value > 0, "map params: invalid " + key)
    return errors


def validate_skills(root: Path) -> list[str]:
    import yaml
    errors = []
    expected = {
        "godot-development",
        "godot-testing",
        "godot-visual-review",
        "godot-safe-refactor",
        "godot-2p5d-pixel-art-and-animation",
        "godot-audio-and-voice-pipeline",
    }
    found = set()
    for path in sorted((root / ".agents/skills").glob("*/SKILL.md")):
        try:
            text = path.read_text(encoding="utf-8")
            match = re.match(r"\A---\r?\n(.*?)\r?\n---(?:\r?\n|$)", text, re.S)
            if not match:
                raise ValueError("missing YAML frontmatter")
            meta = yaml.safe_load(match[1])
            if not isinstance(meta, dict) or meta.get("name") != path.parent.name or not isinstance(meta.get("description"), str) or not meta["description"].strip():
                raise ValueError("name/description mismatch")
            found.add(meta["name"])
        except (ValueError, yaml.YAMLError) as exc:
            errors.append(f"{path.relative_to(root)}: {exc}")
    if found != expected:
        errors.append("missing or unexpected repo Skills: " + str(found ^ expected))
    return errors


def validate_project(root: Path, skills_only: bool = False) -> list[str]:
    errors = validate_skills(root)
    if skills_only:
        return errors
    docs = {}
    for key, rel in DOCUMENTS.items():
        try:
            value = json.loads((root / rel).read_text(encoding="utf-8"))
            if not isinstance(value, dict):
                raise ValueError("top level must be an object")
            docs[key] = value
        except (OSError, ValueError) as exc:
            errors.append(f"{rel}: {exc}")
    if len(docs) == len(DOCUMENTS):
        try:
            errors.extend(validate_data(docs))
        except (TypeError, KeyError, AttributeError) as exc:
            errors.append("invalid nested data schema: " + str(exc))
    for scene in (root / "scenes").rglob("*.tscn"):
        for path in re.findall(r'path="res://([^"\n]+)"', scene.read_text(encoding="utf-8")):
            if not (root / path).is_file():
                errors.append(f"{scene.relative_to(root)}: missing resource {path}")
    return errors


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skills-only", action="store_true")
    args = parser.parse_args()
    failures = validate_project(ROOT, args.skills_only)
    for failure in failures:
        print("[FAIL] " + failure)
    print(f"[DATA] {'FAILED' if failures else 'OK'}: {len(failures)} issue(s)")
    raise SystemExit(bool(failures))
