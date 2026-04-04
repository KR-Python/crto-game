## role_definitions.gd
## Defines all role constants, permissions, and merge rules.
## Loads from data/role_permissions.yaml at runtime; falls back to hardcoded defaults.
class_name RoleDefinitions

# ---------------------------------------------------------------------------
# Role name constants
# ---------------------------------------------------------------------------
const ROLE_COMMANDER: String = "commander"
const ROLE_QUARTERMASTER: String = "quartermaster"
const ROLE_FIELD_MARSHAL: String = "field_marshal"
const ROLE_SPEC_OPS: String = "spec_ops"
const ROLE_CHIEF_ENGINEER: String = "chief_engineer"
const ROLE_AIR_MARSHAL: String = "air_marshal"

const ALL_ROLES: Array[String] = [
	ROLE_COMMANDER,
	ROLE_QUARTERMASTER,
	ROLE_FIELD_MARSHAL,
	ROLE_SPEC_OPS,
	ROLE_CHIEF_ENGINEER,
	ROLE_AIR_MARSHAL,
]

# ---------------------------------------------------------------------------
# Hardcoded defaults — game works without YAML
# ---------------------------------------------------------------------------

## Each entry: { selectable_tags_include, selectable_tags_exclude, allowed_actions, unit_cap, min_players_required }
const ROLE_DEFAULTS: Dictionary = {
	"commander": {
		"selectable_tags_include": ["structure", "construction_yard"],
		"selectable_tags_exclude": ["defense_turret"],
		"allowed_actions": [
			"PLACE_STRUCTURE", "CANCEL_STRUCTURE", "RESEARCH", "CANCEL_RESEARCH",
			"PING_MAP", "REQUEST_FROM_ROLE", "APPROVE_SUPERWEAPON",
			"TOGGLE_POWER", "TRANSFER_CONTROL",
		],
		"unit_cap": -1,
		"min_players_required": 2,
	},
	"quartermaster": {
		"selectable_tags_include": ["harvester", "production_building", "refinery"],
		"selectable_tags_exclude": [],
		"allowed_actions": [
			"QUEUE_PRODUCTION", "CANCEL_PRODUCTION", "SET_RALLY_POINT",
			"MOVE_UNITS",  # harvesters only — enforced by PermissionSystem
			"STOP", "TOGGLE_POWER",
			"PING_MAP", "REQUEST_FROM_ROLE",
		],
		"unit_cap": -1,
		"min_players_required": 3,
	},
	"field_marshal": {
		"selectable_tags_include": ["combat", "infantry", "vehicle", "naval"],
		"selectable_tags_exclude": ["spec_ops", "hero", "air", "harvester", "engineer_unit"],
		"allowed_actions": [
			"MOVE_UNITS", "ATTACK_TARGET", "ATTACK_MOVE", "PATROL", "GUARD",
			"STOP", "HOLD_POSITION", "SET_FORMATION",
			"PING_MAP", "REQUEST_FROM_ROLE", "APPROVE_SUPERWEAPON",
		],
		"unit_cap": -1,
		"min_players_required": 2,
	},
	"spec_ops": {
		"selectable_tags_include": ["spec_ops", "hero"],
		"selectable_tags_exclude": [],
		"allowed_actions": [
			"MOVE_UNITS", "ATTACK_TARGET", "INFILTRATE", "SABOTAGE", "MARK_TARGET",
			"STOP", "PING_MAP", "REQUEST_FROM_ROLE",
		],
		"unit_cap": 15,
		"min_players_required": 4,
	},
	"chief_engineer": {
		"selectable_tags_include": ["defense_turret", "wall", "gate", "mine", "sensor", "engineer_unit"],
		"selectable_tags_exclude": [],
		"allowed_actions": [
			"PLACE_STRUCTURE",  # defense structures only — enforced by PermissionSystem
			"PLACE_WALL", "PLACE_MINE", "REPAIR_STRUCTURE", "REPAIR_VEHICLE",
			"MOVE_UNITS",  # engineers only
			"STOP", "PING_MAP", "REQUEST_FROM_ROLE",
		],
		"unit_cap": -1,
		"min_players_required": 5,
	},
	"air_marshal": {
		"selectable_tags_include": ["air", "airfield"],
		"selectable_tags_exclude": [],
		"allowed_actions": [
			"MOVE_UNITS", "ATTACK_TARGET", "PATROL", "BOMBING_RUN", "PARADROP",
			"STOP", "PING_MAP", "REQUEST_FROM_ROLE",
		],
		"unit_cap": -1,
		"min_players_required": 5,
	},
}

## Merge rules: key = player count, value = list of {role, absorbs}
const MERGE_RULES: Dictionary = {
	2: [
		{"role": "commander", "absorbs": ["quartermaster", "chief_engineer"]},
		{"role": "field_marshal", "absorbs": ["spec_ops", "air_marshal"]},
	],
	3: [
		{"role": "commander", "absorbs": ["chief_engineer"]},
		{"role": "quartermaster", "absorbs": []},
		{"role": "field_marshal", "absorbs": ["spec_ops", "air_marshal"]},
	],
	4: [
		{"role": "commander", "absorbs": ["chief_engineer"]},
		{"role": "quartermaster", "absorbs": []},
		{"role": "field_marshal", "absorbs": ["air_marshal"]},
		{"role": "spec_ops", "absorbs": []},
	],
}

# ---------------------------------------------------------------------------
# Runtime data (loaded from YAML, falls back to defaults)
# ---------------------------------------------------------------------------
var _role_data: Dictionary = {}

func _init() -> void:
	_load_from_yaml_or_default()

func _load_from_yaml_or_default() -> void:
	var yaml_path: String = "res://data/role_permissions.yaml"
	if ResourceLoader.exists(yaml_path):
		_try_load_yaml(yaml_path)
	else:
		push_warning("RoleDefinitions: YAML not found at %s, using hardcoded defaults" % yaml_path)
		_role_data = ROLE_DEFAULTS.duplicate(true)

func _try_load_yaml(path: String) -> void:
	# Godot 4 has no native YAML loader — use a bundled parser or fall back.
	# For now, fall back to defaults and log.
	push_warning("RoleDefinitions: YAML loader not yet integrated, using hardcoded defaults")
	_role_data = ROLE_DEFAULTS.duplicate(true)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns the permission definition dict for a role, or {} if unknown.
func get_role_def(role: String) -> Dictionary:
	return _role_data.get(role, {})

## Returns allowed actions for a role (merged definitions are handled by RoleManager).
func get_allowed_actions(role: String) -> Array[String]:
	var def: Dictionary = get_role_def(role)
	if def.is_empty():
		return []
	return def.get("allowed_actions", []) as Array[String]

## Returns unit cap for a role (-1 = unlimited).
func get_unit_cap(role: String) -> int:
	var def: Dictionary = get_role_def(role)
	return def.get("unit_cap", -1)

## Returns the minimum player count at which this role is filled by a human.
func get_min_players_required(role: String) -> int:
	var def: Dictionary = get_role_def(role)
	return def.get("min_players_required", 2)

## Returns selectable tags for a role.
func get_selectable_tags(role: String) -> Dictionary:
	var def: Dictionary = get_role_def(role)
	return {
		"include": def.get("selectable_tags_include", []),
		"exclude": def.get("selectable_tags_exclude", []),
	}

## Returns the merge rules for a given player count.
func get_merge_rules(player_count: int) -> Array:
	# Use exact match, or the largest key <= player_count
	if player_count >= 5:
		return []
	var key: int = min(player_count, 4)
	return MERGE_RULES.get(key, [])
