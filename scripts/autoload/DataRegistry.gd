extends Node

var equipment: Dictionary = {}
var resources: Dictionary = {}
var enemies: Dictionary = {}
var map_params: Dictionary = {}
var events: Array = []
var recipes: Array = []
var quests: Array = []
var npcs: Array = []
var wasteland_routes: Dictionary = {}
var visual_assets: Dictionary = {}

func _ready() -> void:
	load_all()

func load_all() -> void:
	var item_data := _load_json("res://data/items/equipment.json")
	equipment = item_data.get("equipment", {})
	resources = item_data.get("resources", {})
	recipes = _load_json("res://data/items/recipes.json").get("recipes", [])
	enemies = _load_json("res://data/enemies/enemies.json").get("enemies", {})
	map_params = _load_json("res://data/maps/wasteland_params.json")
	wasteland_routes = _load_json("res://data/maps/wasteland_routes.json").get("routes", {})
	visual_assets = _load_json("res://data/art/visual_assets.json").get("assets", {})
	events = _load_json("res://data/maps/events.json").get("events", [])
	quests = _load_json("res://data/maps/quests.json").get("quests", [])
	npcs = _load_json("res://data/maps/npcs.json").get("npcs", [])

func get_equipment(item_id: String) -> Dictionary:
	return equipment.get(item_id, {})

func get_resource(item_id: String) -> Dictionary:
	return resources.get(item_id, {})

func get_enemy(enemy_id: String) -> Dictionary:
	return enemies.get(enemy_id, {})

func enemy_ids() -> Array:
	return enemies.keys()

func get_recipe(recipe_id: String) -> Dictionary:
	for recipe in recipes:
		if String(recipe.get("id", "")) == recipe_id:
			return recipe
	return {}

func get_quest(quest_id: String) -> Dictionary:
	for quest in quests:
		if String(quest.get("id", "")) == quest_id:
			return quest
	return {}

func quest_ids() -> Array[String]:
	var ids: Array[String] = []
	for quest in quests:
		ids.append(String(quest.get("id", "")))
	return ids

func get_npc(npc_id: String) -> Dictionary:
	for npc in npcs:
		if String(npc.get("id", "")) == npc_id:
			return npc
	return {}

func get_wasteland_route(route_id: String) -> Dictionary:
	return wasteland_routes.get(route_id, {})

func get_visual_asset(asset_id: String) -> Dictionary:
	return visual_assets.get(asset_id, {})

func asset_path(asset_id: String, fallback := "") -> String:
	return String(get_visual_asset(asset_id).get("path", fallback))

func asset_portrait_path(asset_id: String, fallback := "") -> String:
	return String(get_visual_asset(asset_id).get("portrait", fallback))

func wasteland_route_ids() -> Array:
	return wasteland_routes.keys()

func npcs_for_scene(scene_id: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for npc in npcs:
		if String(npc.get("scene", "")) == scene_id:
			results.append(npc)
	return results

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Missing JSON: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Invalid JSON dictionary: %s" % path)
		return {}
	return parsed
