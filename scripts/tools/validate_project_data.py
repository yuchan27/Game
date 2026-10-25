"""Read-only data/scene/Skill contract checks. No engine or asset production."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import struct
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
STORY_EVENT_ROUTES = {
    "story_scrap_manifest": "scrap_highway",
    "story_marsh_ledger": "toxic_marsh",
    "story_crystal_echo": "crystal_scar",
    "story_factory_blackbox": "old_factory",
    "story_metropolis_archive": "ruined_metropolis",
    "story_facility_memory": "underground_facility",
}
STORY_QUEST_EVENTS = {
    "clear_scrap_route": "story_scrap_manifest",
    "toxic_sample": "story_marsh_ledger",
    "crystal_scar_recon": "story_crystal_echo",
    "old_factory_core": "story_factory_blackbox",
    "metropolis_archive": "story_metropolis_archive",
    "facility_memory": "story_facility_memory",
}
STORY_QUEST_OPTIONAL = {
    "clear_scrap_route": True,
    "toxic_sample": True,
    "crystal_scar_recon": True,
    "old_factory_core": True,
    "metropolis_archive": False,
    "facility_memory": False,
}
STORY_QUEST_PREREQUISITES = {
    "metropolis_archive": [
        "clear_scrap_route",
        "toxic_sample",
        "crystal_scar_recon",
        "old_factory_core",
    ],
    "facility_memory": ["metropolis_archive"],
}


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

    entry_sets: dict[str, list[dict]] = {}
    field_objective_ids: set[str] = set()
    for kind in ("recipes", "quests", "npcs", "events"):
        entries = rows(mapping(docs.get(kind, {}), kind + " document").get(kind), kind)
        entry_sets[kind] = entries
        for entry in entries:
            label = kind + "." + str(entry.get("id"))
            for field in ("cost", "result", "reward"):
                if field in entry:
                    quantities(entry[field], label + "." + field)
            if kind == "events" and "visual_prop" in entry:
                require(isinstance(entry["visual_prop"], str) and "prop_" + entry["visual_prop"] in art,
                        label + ": visual_prop must reference a known prop")
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
                    require(objective.get("type") in {"collect", "defeat", "discover"}, label + ": unsupported objective type")
                    v = objective.get("amount")
                    require(type(v) is int and v > 0, label + ": objective amount must be positive integer")
                    if objective.get("type") == "collect":
                        require(objective.get("item") in known_items, label + ": unknown objective item")
                    elif objective.get("type") == "defeat":
                        require(objective.get("counter") in {"defeat_enemy", "defeat_boss"}, label + ": unsupported objective counter")
                    elif objective.get("type") == "discover":
                        event_id = objective.get("event")
                        route_id = objective.get("route")
                        require(isinstance(event_id, str) and bool(event_id), label + ": discovery event required")
                        require(route_id in routes, label + ": discovery has unknown route")
                        require(type(objective.get("optional")) is bool, label + ": discovery optional must be boolean")
                if "field_objective" in entry:
                    field_objective = mapping(entry.get("field_objective"), label + ".field_objective")
                    objective_id = field_objective.get("id")
                    require(isinstance(objective_id, str) and bool(objective_id.strip()), label + ": field objective id required")
                    if isinstance(objective_id, str):
                        require(objective_id not in field_objective_ids, label + ": field objective ids must be unique")
                        field_objective_ids.add(objective_id)
                    require(field_objective.get("route") in routes, label + ": field objective has unknown route")
                    require(field_objective.get("route") == entry.get("route"), label + ": field objective route must match quest route")
                    require(_normalized_position(field_objective.get("position")), label + ": field objective position must be normalized")
                    if "visual_prop" in field_objective:
                        visual_prop = field_objective.get("visual_prop")
                        require(isinstance(visual_prop, str) and "prop_" + visual_prop in art,
                                label + ": field objective visual_prop must reference a known prop")
                    for field in ("name", "action_name", "purpose", "pending_dialogue", "completed_dialogue"):
                        require(isinstance(field_objective.get(field), str) and bool(field_objective.get(field, "").strip()),
                                label + ": field objective " + field + " required")
                    require("reward" not in field_objective, label + ": field objectives must not grant a direct reward")

    _validate_story_contract(entry_sets.get("quests", []), entry_sets.get("events", []), routes, require)
    _validate_directional_metadata(art, require)
    for asset_id in ["player_r17", *("enemy_" + str(key) for key in enemies)]:
        asset = art.get(asset_id, {})
        require(isinstance(asset, dict) and any(field in asset for field in ("directional_path", "directional_body_path")),
                asset_id + ": authored eight-view art is required")

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
        _validate_route_expansion(key, route, entry_sets.get("events", []), enemies, art, require, quantities)
    for key in ("width_tiles", "height_tiles", "tile_size", "enemy_limit", "projectile_limit", "prop_nodes", "resource_nodes"):
        value = mapping(docs.get("params", {}), "params").get(key)
        require(type(value) is int and value > 0, "map params: invalid " + key)
    return errors


def _normalized_position(value) -> bool:
    return (isinstance(value, list) and len(value) == 2
            and all(type(v) in (int, float) and math.isfinite(v) and 0 < v < 1 for v in value))


def _validate_route_expansion(key: str, route: dict, events: list[dict], enemies: dict, art: dict,
                              require, quantities) -> None:
    size = route.get("size_tiles")
    valid_size = isinstance(size, list) and len(size) == 2 and all(type(v) is int and v > 0 for v in size)
    require(valid_size and size[0] * size[1] > 180 * 140, key + ": size_tiles must exceed the original shared map area")
    regions = route.get("regions")
    require(isinstance(regions, list) and len(regions) >= 4, key + ": at least four named regions are required")
    names = []
    for region in regions if isinstance(regions, list) else []:
        require(isinstance(region, dict), key + ": region must be an object")
        if not isinstance(region, dict):
            continue
        name = region.get("name")
        require(isinstance(name, str) and bool(name.strip()), key + ": region name required")
        names.append(str(name))
        require(_normalized_position(region.get("center")), key + ": region center must be a normalized position")
    require(len(names) == len(set(names)), key + ": region names must be unique")
    paths = route.get("exploration_paths")
    require(isinstance(paths, list) and len(paths) >= 5, key + ": at least five exploration paths are required")
    segments = []
    for path in paths if isinstance(paths, list) else []:
        valid = isinstance(path, list) and len(path) >= 2 and all(_normalized_position(point) for point in path)
        require(valid, key + ": exploration paths require at least two normalized positions")
        if not valid:
            continue
        for a, b in zip(path, path[1:]):
            # Native road capsules, map polylines and placement reserves accept
            # diagonal segments; retain finite normalized points and nonzero length.
            require(a != b, key + ": exploration path segments must be nonzero")
            segments.append((a, b))
    path_props = route.get("path_props")
    require(isinstance(path_props, list) and bool(path_props), key + ": path_props required")
    for prop in path_props if isinstance(path_props, list) else []:
        require("prop_" + str(prop) in art, key + ": unknown path prop " + str(prop))
    points = route.get("exploration_points")
    require(isinstance(points, list) and len(points) >= 3, key + ": at least three exploration points are required")
    ids = []
    nonstory_events = {event.get("id") for event in events if event.get("story") is not True}
    for point in points if isinstance(points, list) else []:
        require(isinstance(point, dict), key + ": exploration point must be an object")
        if not isinstance(point, dict):
            continue
        event_id = point.get("event")
        ids.append(str(event_id))
        require(isinstance(event_id, str) and event_id in nonstory_events, key + ": exploration point must reference a non-story event")
        label = key + ".exploration." + str(event_id)
        for field in ("name", "description"):
            require(isinstance(point.get(field), str) and bool(point[field].strip()), label + ": " + field + " required")
        position = point.get("position")
        position_valid = _normalized_position(position)
        require(position_valid, label + ": position must be normalized")
        if position_valid:
            on_path = False
            for a, b in segments:
                dx, dy = b[0] - a[0], b[1] - a[1]
                length_squared = dx * dx + dy * dy
                if length_squared == 0:
                    continue
                t = ((position[0] - a[0]) * dx + (position[1] - a[1]) * dy) / length_squared
                if (0 <= t <= 1 and math.isclose(a[0] + t * dx, position[0], abs_tol=1e-8)
                        and math.isclose(a[1] + t * dy, position[1], abs_tol=1e-8)):
                    on_path = True
                    break
            require(on_path, label + ": position must be reachable from an authored path")
        require("prop_" + str(point.get("prop")) in art, label + ": unknown reward prop")
        guards = point.get("guards")
        require(isinstance(guards, list) and len(guards) == 3, label + ": exactly three guards required")
        for guard in guards if isinstance(guards, list) else []:
            require(isinstance(guard, str) and guard in enemies and isinstance(enemies[guard], dict) and enemies[guard].get("type") != "boss",
                    label + ": guard must be a known non-boss enemy")
        reward = point.get("reward")
        require(isinstance(reward, dict) and bool(reward), label + ": reward required")
        quantities(reward, label + ".reward")
    require(len(ids) == len(set(ids)), key + ": exploration point event ids must be unique within the route")


def _validate_directional_metadata(art: dict, require) -> None:
    for asset_id, asset in art.items():
        if not isinstance(asset, dict) or not any(str(field).startswith("directional_") for field in asset):
            continue
        label = asset_id + ".directional"
        paths = [asset.get(field) for field in ("directional_path", "directional_body_path") if field in asset]
        require(len(paths) == 1 and isinstance(paths[0], str) and paths[0].startswith("res://assets/") and paths[0].endswith(".png"),
                label + ": exactly one runtime PNG path required")
        dimensions = asset.get("directional_dimensions")
        valid_dimensions = isinstance(dimensions, list) and len(dimensions) == 2 and all(type(v) is int and v > 0 for v in dimensions)
        require(valid_dimensions, label + ": dimensions must be two positive integers")
        digest = asset.get("directional_source_sha256")
        require(isinstance(digest, str) and re.fullmatch(r"[0-9a-f]{64}", digest) is not None, label + ": SHA-256 required")
        rects = asset.get("directional_rects")
        feet = asset.get("directional_feet")
        require(isinstance(rects, list) and len(rects) == 8, label + ": exactly eight source rectangles required")
        require(isinstance(feet, list) and len(feet) == 8, label + ": exactly eight foot anchors required")
        seen = set()
        for index, rect in enumerate(rects if isinstance(rects, list) else []):
            valid_rect = isinstance(rect, list) and len(rect) == 4 and all(type(v) is int for v in rect)
            if valid_rect and valid_dimensions:
                x, y, width, height = rect
                valid_rect = x >= 0 and y >= 0 and width > 0 and height > 0 and x + width <= dimensions[0] and y + height <= dimensions[1]
            require(valid_rect, label + f": source rectangle {index} must fit the PNG dimensions")
            if not valid_rect:
                continue
            require(tuple(rect) not in seen, label + ": source rectangles must be unique")
            seen.add(tuple(rect))
            foot = feet[index] if isinstance(feet, list) and index < len(feet) else None
            valid_foot = isinstance(foot, list) and len(foot) == 2 and all(type(v) is int for v in foot)
            if valid_foot:
                x, y, width, height = rect
                valid_foot = x <= foot[0] < x + width and y <= foot[1] < y + height
            require(valid_foot, label + f": foot anchor {index} must fit its source rectangle")


def validate_directional_files(art: dict, root: Path) -> list[str]:
    """Verify the separate runtime turnarounds, which the legacy atlas checker does not read."""
    errors = []
    for asset_id, asset in art.items():
        if not isinstance(asset, dict):
            continue
        raw_path = asset.get("directional_path", asset.get("directional_body_path"))
        if raw_path is None:
            continue
        label = asset_id + ".directional"
        if not isinstance(raw_path, str) or not raw_path.startswith("res://assets/"):
            errors.append(label + ": invalid runtime PNG path")
            continue
        path = (root / raw_path.removeprefix("res://")).resolve()
        if not path.is_relative_to((root / "assets").resolve()):
            errors.append(label + ": runtime PNG path must remain inside assets")
            continue
        try:
            raw = path.read_bytes()
            if len(raw) < 24 or raw[:8] != b"\x89PNG\r\n\x1a\n" or raw[12:16] != b"IHDR":
                raise ValueError("invalid PNG header")
            dimensions = list(struct.unpack(">II", raw[16:24]))
            if dimensions != asset.get("directional_dimensions"):
                errors.append(label + ": PNG dimensions disagree with manifest")
            if hashlib.sha256(raw).hexdigest() != asset.get("directional_source_sha256"):
                errors.append(label + ": PNG bytes disagree with recorded SHA-256")
        except (OSError, ValueError) as exc:
            errors.append(label + ": cannot read runtime PNG: " + str(exc))
    return errors


def _validate_story_contract(quests: list[dict], events: list[dict], routes: dict, require) -> None:
    """Keep the authored six-route campaign connected to real route and event data."""
    quest_by_id = {str(row.get("id", "")): row for row in quests}
    event_by_id = {str(row.get("id", "")): row for row in events}
    story_events = [row for row in events if row.get("story") is True]
    story_ids = {str(row.get("id", "")) for row in story_events}
    campaign_ids = {str(row.get("id", "")) for row in quests if row.get("main_campaign") is True}
    require(campaign_ids == set(STORY_QUEST_EVENTS), "campaign quests must define the six story quest ids exactly")
    discovery_links: list[str] = []
    for quest in quests:
        quest_id = str(quest.get("id", ""))
        objectives = quest.get("objectives", [])
        if not isinstance(objectives, list):
            continue
        for objective in objectives:
            if not isinstance(objective, dict) or objective.get("type") != "discover":
                continue
            event_id = objective.get("event")
            event = event_by_id.get(event_id, {}) if isinstance(event_id, str) else {}
            label = "quests." + quest_id
            require(event.get("story") is True, label + ": discovery must reference a story event")
            if event.get("story") is True and isinstance(event_id, str):
                discovery_links.append(event_id)
            require(objective.get("route") == event.get("route"), label + ": discovery route must match its story event")
            require(objective.get("route") == quest.get("route"), label + ": discovery route must match quest route")
            require(objective.get("amount") == 1 and type(objective.get("amount")) is int,
                    label + ": discovery amount must be 1")

    require(story_ids == set(STORY_EVENT_ROUTES), "story events must define the six campaign event ids exactly")
    events_by_route: dict[str, list[dict]] = {}
    story_chapters: list[int] = []
    for event in events:
        event_id = str(event.get("id", ""))
        if "story" in event:
            require(type(event["story"]) is bool, f"events.{event_id}: story must be boolean")
        if event.get("story") is not True:
            continue
        label = "events." + event_id
        route_id = event.get("route")
        require(route_id in routes, label + ": unknown route")
        expected_route = STORY_EVENT_ROUTES.get(event_id)
        require(expected_route is not None, label + ": unexpected story event")
        if expected_route is not None:
            require(route_id == expected_route, label + ": event is assigned to the wrong route")
        events_by_route.setdefault(str(route_id), []).append(event)
        require(type(event.get("chapter")) is int and int(event.get("chapter", 0)) > 0,
                label + ": chapter must be a positive integer")
        if type(event.get("chapter")) is int:
            story_chapters.append(int(event["chapter"]))
        for field in ("name", "objective", "description", "revelation"):
            require(isinstance(event.get(field), str) and bool(event.get(field, "").strip()),
                    label + ": " + field + " required")
        require("reward" not in event, label + ": story events must not grant a direct reward")

    for expected_event, route_id in STORY_EVENT_ROUTES.items():
        require(expected_event in event_by_id and event_by_id[expected_event].get("story") is True,
                "missing story event: " + expected_event)
        require(len(events_by_route.get(route_id, [])) == 1,
                route_id + ": expected exactly one story event")
    require(sorted(story_chapters) == list(range(1, 7)), "story event chapters must cover 1 through 6 exactly")

    # Check every prerequisite reference and detect cycles before runtime quest lookup.
    graph: dict[str, list[str]] = {}
    for quest in quests:
        quest_id = str(quest.get("id", ""))
        raw_prerequisites = quest.get("prerequisites", [])
        require(isinstance(raw_prerequisites, list), f"quests.{quest_id}: prerequisites must be an array")
        prerequisites = raw_prerequisites if isinstance(raw_prerequisites, list) else []
        require(all(isinstance(value, str) and value for value in prerequisites),
                f"quests.{quest_id}: prerequisites must be nonempty quest ids")
        require(len(prerequisites) == len(set(value for value in prerequisites if isinstance(value, str))),
                f"quests.{quest_id}: prerequisites must be unique")
        graph[quest_id] = []
        for prerequisite in prerequisites:
            if not isinstance(prerequisite, str):
                continue
            require(prerequisite in quest_by_id, f"quests.{quest_id}: unknown prerequisite {prerequisite}")
            require(prerequisite != quest_id, f"quests.{quest_id}: cannot require itself")
            if prerequisite in quest_by_id:
                graph[quest_id].append(prerequisite)

    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(quest_id: str) -> None:
        if quest_id in visiting:
            require(False, "quest prerequisites contain a cycle")
            return
        if quest_id in visited:
            return
        visiting.add(quest_id)
        for prerequisite in graph.get(quest_id, []):
            visit(prerequisite)
        visiting.remove(quest_id)
        visited.add(quest_id)

    for quest_id in graph:
        visit(quest_id)

    for quest_id, event_id in STORY_QUEST_EVENTS.items():
        quest = quest_by_id.get(quest_id)
        require(quest is not None, "missing story quest: " + quest_id)
        if quest is None:
            continue
        label = "quests." + quest_id
        route_id = str(quest.get("route", ""))
        chapter = quest.get("chapter")
        require(quest.get("main_campaign") is True, label + ": main_campaign must be true")
        require(type(chapter) is int and chapter > 0, label + ": chapter must be a positive integer")
        require(isinstance(quest.get("completion_text"), str) and bool(quest.get("completion_text", "").strip()),
                label + ": completion_text required")
        objectives = quest.get("objectives", [])
        discovers = [row for row in objectives if isinstance(row, dict) and row.get("type") == "discover"] if isinstance(objectives, list) else []
        matches = [row for row in discovers if row.get("event") == event_id]
        require(len(matches) == 1, label + ": expected exactly one discovery objective for " + event_id)
        if matches:
            objective = matches[0]
            require(objective.get("route") == route_id, label + ": discovery route must match quest route")
            require(objective.get("amount") == 1 and type(objective.get("amount")) is int,
                    label + ": discovery amount must be 1")
            require(type(objective.get("optional")) is bool and objective.get("optional") is STORY_QUEST_OPTIONAL[quest_id],
                    label + ": discovery optional flag does not match campaign contract")
            event = event_by_id.get(event_id, {})
            require(route_id == event.get("route"), label + ": discovery event must belong to the quest route")
            require(chapter == event.get("chapter"), label + ": chapter must match its story event")

    require(sorted(discovery_links) == sorted(STORY_QUEST_EVENTS.values()),
            "each campaign discovery event must be linked exactly once")

    for quest_id, expected in STORY_QUEST_PREREQUISITES.items():
        quest = quest_by_id.get(quest_id, {})
        actual = quest.get("prerequisites", [])
        require(actual == expected, f"quests.{quest_id}: prerequisites must be {expected}")


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
            errors.extend(validate_directional_files(docs["art"].get("assets", {}), root))
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
