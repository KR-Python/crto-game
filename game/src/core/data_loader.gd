class_name DataLoader
## Singleton that loads and caches all game definitions from JSON files at startup.
## JSON files are generated from YAML sources by tools/yaml_to_json.py at CI time.
## Godot 4 has no built-in YAML parser, so YAML→JSON conversion happens offline.
##
## Usage (autoload or injected):
##   DataLoader.load_all()
##   var def = DataLoader.get_unit("aegis_rifleman")
##   var mult = DataLoader.get_damage_multiplier("explosive", "light")  # → 1.5
extends Node

var units: Dictionary = {}             # unit_id → unit definition dict
var structures: Dictionary = {}        # structure_id → structure definition dict
var tech_trees: Dictionary = {}        # faction → tech tree dict
var ai_personalities: Dictionary = {}  # personality_id → personality dict
var damage_armor_matrix: Dictionary = {}  # damage_type → armor_type → float


# ── Public API ────────────────────────────────────────────────────────────────

func load_all() -> void:
	_load_directory("res://data/units/", units, "unit_id")
	_load_directory("res://data/structures/", structures, "structure_id")
	_load_directory("res://data/tech_trees/", tech_trees, "faction")
	_load_directory("res://data/ai_personalities/", ai_personalities, "personality_id")
	_load_balance_data()
	push_warning(
		"DataLoader: loaded %d units, %d structures, %d tech trees, %d personalities"
		% [units.size(), structures.size(), tech_trees.size(), ai_personalities.size()]
	)


func get_unit(unit_id: String) -> Dictionary:
	return units.get(unit_id, {})


func get_structure(structure_id: String) -> Dictionary:
	return structures.get(structure_id, {})


func get_damage_multiplier(damage_type: String, armor_type: String) -> float:
	return damage_armor_matrix.get(damage_type, {}).get(armor_type, 1.0)


# ── Internal ──────────────────────────────────────────────────────────────────

func _load_directory(path: String, target: Dictionary, key_field: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("DataLoader: directory not found: %s (skipping)" % path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var full_path := path.path_join(file_name)
			var parsed := _parse_json_file(full_path)
			if parsed.is_empty():
				push_error("DataLoader: failed to parse or empty: %s" % full_path)
			else:
				var key: String = parsed.get(key_field, "")
				if key.is_empty():
					push_error(
						"DataLoader: missing key field '%s' in %s" % [key_field, full_path]
					)
				else:
					target[key] = parsed
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_balance_data() -> void:
	var matrix_path := "res://data/balance/damage_armor_matrix.json"
	var parsed := _parse_json_file(matrix_path)
	if parsed.is_empty():
		push_warning("DataLoader: damage_armor_matrix not found at %s — using 1.0 fallback" % matrix_path)
		return

	var raw_matrix: Dictionary = parsed.get("matrix", {})
	for damage_type: String in raw_matrix:
		damage_armor_matrix[damage_type] = {}
		var row: Dictionary = raw_matrix[damage_type]
		for armor_type: String in row:
			damage_armor_matrix[damage_type][armor_type] = float(row[armor_type])


func _parse_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataLoader: could not open file: %s" % path)
		return {}
	var json_text := file.get_as_text()
	file.close()
	var result: Variant = JSON.parse_string(json_text)
	if result == null:
		push_error("DataLoader: JSON parse failed: %s" % path)
		return {}
	if not result is Dictionary:
		push_error("DataLoader: expected JSON object at root: %s" % path)
		return {}
	return result as Dictionary
