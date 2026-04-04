class_name EntityFactory
## Creates ECS entities from definitions.
## Loads real stats from YAML-sourced JSON via DataLoader.
## Falls back to hardcoded definitions when DataLoader is unavailable or unit_id is unknown.
##
## Usage:
##   var factory := EntityFactory.new(ecs, data_loader)
##   var unit_id  := factory.create_from_definition("aegis_rifleman", Vector2(10, 10))
##   var struct_id := factory.create_structure("aegis_barracks", Vector2(5, 5), 0)

var _ecs: ECS
var _data_loader: DataLoader  # injected at game start; null falls back to hardcoded defs


func _init(ecs: ECS, data_loader: DataLoader = null) -> void:
	_ecs = ecs
	_data_loader = data_loader


# ── Unit Creation ─────────────────────────────────────────────────────────────

## Create a unit entity from a unit type identifier.
## Loads from DataLoader (YAML-sourced JSON) with hardcoded fallback.
## Returns the new entity_id, or -1 if the unit type is completely unknown.
func create_test_unit(position: Vector2) -> int:
	return create_from_definition("aegis_rifleman", position)


func create_from_definition(unit_type: String, position: Vector2) -> int:
	var def: Dictionary = _resolve_unit_def(unit_type)
	if def.is_empty():
		push_error("EntityFactory.create_from_definition: unknown unit type '%s'" % unit_type)
		return -1
	return _create_unit_entity(def, position)


func _resolve_unit_def(unit_type: String) -> Dictionary:
	# Prefer live YAML data when DataLoader is wired up.
	if _data_loader != null:
		var yaml_def := _data_loader.get_unit(unit_type)
		if not yaml_def.is_empty():
			return _normalize_unit_def(yaml_def)
	# Fall back to hardcoded stubs for unknown ids or when loader is absent.
	return _builtin_unit_definitions().get(unit_type, {})


# ── Structure Creation ────────────────────────────────────────────────────────

## Create a structure entity from a structure type identifier and position.
## Loads from DataLoader (YAML-sourced JSON) with hardcoded fallback.
## Returns the new entity_id, or -1 if the structure type is unknown.
func create_structure(structure_type: String, position: Vector2, faction_id: int) -> int:
	var def: Dictionary = _resolve_structure_def(structure_type)
	if def.is_empty():
		push_error("EntityFactory.create_structure: unknown structure type '%s'" % structure_type)
		return -1
	return _create_structure_entity(def, position, faction_id)


func _resolve_structure_def(structure_type: String) -> Dictionary:
	if _data_loader != null:
		var yaml_def := _data_loader.get_structure(structure_type)
		if not yaml_def.is_empty():
			return _normalize_structure_def(yaml_def)
	return _builtin_structure_definitions().get(structure_type, {})


# ── YAML Schema Normalization ────────────────────────────────────────────────
# Translates the rich YAML schema (docs/06-DATA-SCHEMAS.md) into the flat dict
# format expected by _create_unit_entity / _create_structure_entity.

func _normalize_unit_def(yaml: Dictionary) -> Dictionary:
	var d: Dictionary = {}
	var faction: String = yaml.get("faction", "aegis")
	d["faction_id"] = 0 if faction == "aegis" else 1
	d["faction_name"] = faction
	d["role_tag"] = yaml.get("role_tag", "combat")

	var health: Dictionary = yaml.get("health", {})
	d["health_max"] = float(health.get("max", 100))
	d["armor_type"] = health.get("armor_type", "medium")

	var movement: Dictionary = yaml.get("movement", {})
	d["speed"] = float(movement.get("speed", 3.0))

	var vision: Dictionary = yaml.get("vision", {})
	d["vision_range"] = float(vision.get("range", 6.0))

	# First weapon only — multi-weapon support is Phase 3.
	var weapons: Array = yaml.get("weapons", [])
	if weapons.size() > 0:
		var w: Dictionary = weapons[0]
		d["damage"] = float(w.get("damage", 0))
		d["weapon_range"] = float(w.get("range", 5.0))
		d["cooldown"] = float(w.get("cooldown", 1.5))
		d["damage_type"] = w.get("damage_type", "kinetic")
		d["targets"] = w.get("targets", ["ground"])
		d["area_of_effect"] = float(w.get("area_of_effect", 0.0))

	# Harvester capacity from abilities.
	for ability: Dictionary in yaml.get("abilities", []):
		var effect: Dictionary = ability.get("effect", {})
		if effect.get("type") == "harvest":
			d["harvest_capacity"] = float(effect.get("capacity", 30.0))
			d["harvest_rate"] = float(effect.get("harvest_rate", 2.0))

	# Tags inferred from category + role_tag.
	var tags: Array = [yaml.get("category", "infantry"), d["role_tag"]]
	if yaml.get("movement", {}).get("type") == "flying":
		tags.append("flying")
	d["tags"] = tags

	return d


func _normalize_structure_def(yaml: Dictionary) -> Dictionary:
	var d: Dictionary = {}
	d["structure_type"] = yaml.get("structure_id", "")
	d["faction"] = yaml.get("faction", "aegis")

	var health: Dictionary = yaml.get("health", {})
	d["health_max"] = float(health.get("max", 500))
	d["armor_type"] = health.get("armor_type", "building")

	var footprint: Dictionary = yaml.get("footprint", {})
	d["footprint_width"] = int(footprint.get("width", 2))
	d["footprint_height"] = int(footprint.get("height", 2))

	var power: Dictionary = yaml.get("power", {})
	d["power_consumption"] = float(power.get("consumption", 0.0))
	d["power_production"] = float(power.get("production", 0.0))

	var vision: Dictionary = yaml.get("vision", {})
	d["vision_range"] = float(vision.get("range", 4.0))

	d["build_time"] = float(yaml.get("build_time", 10.0))
	d["cost_primary"] = float(yaml.get("cost", {}).get("primary", 0.0))
	d["cost_secondary"] = float(yaml.get("cost", {}).get("secondary", 0.0))

	return d


# ── Internal: Unit Assembly ───────────────────────────────────────────────────

func _create_unit_entity(def: Dictionary, position: Vector2) -> int:
	var entity_id: int = _ecs.create_entity()

	_ecs.add_component(entity_id, "Position", {"x": position.x, "y": position.y})
	_ecs.add_component(entity_id, "FactionComponent", {"faction_id": def.get("faction_id", 0)})

	_ecs.add_component(entity_id, "Health", {
		"current": def.get("health_max", 100.0),
		"max": def.get("health_max", 100.0),
		"armor_type": def.get("armor_type", "medium"),
	})

	if def.has("speed"):
		_ecs.add_component(entity_id, "MoveSpeed", {"speed": def["speed"]})
		_ecs.add_component(entity_id, "PathState", {"path": [], "current_index": 0})

	if def.has("vision_range"):
		_ecs.add_component(entity_id, "VisionRange", {"range": def["vision_range"]})

	if def.has("damage"):
		_ecs.add_component(entity_id, "Weapon", {
			"damage": def["damage"],
			"range": def.get("weapon_range", 5.0),
			"cooldown": def.get("cooldown", 1.5),
			"cooldown_remaining": 0.0,
			"damage_type": def.get("damage_type", "kinetic"),
			"targets": def.get("targets", ["ground"]),
			"area_of_effect": def.get("area_of_effect", 0.0),
		})
		_ecs.add_component(entity_id, "Attackable", {})

	var tags: Array = def.get("tags", [])
	if tags.size() > 0:
		_ecs.add_component(entity_id, "Tags", {"tags": tags})

	if "flying" in tags:
		_ecs.add_component(entity_id, "Flying", {})

	return entity_id


# ── Internal: Structure Assembly ──────────────────────────────────────────────

func _create_structure_entity(def: Dictionary, position: Vector2, faction_id: int) -> int:
	var entity_id: int = _ecs.create_entity()

	_ecs.add_component(entity_id, "Position", {"x": position.x, "y": position.y})

	_ecs.add_component(entity_id, "Structure", {
		"structure_type": def.get("structure_type", ""),
		"built": false,
		"build_progress": 0.0,
	})

	_ecs.add_component(entity_id, "Footprint", {
		"width": def.get("footprint_width", 2),
		"height": def.get("footprint_height", 2),
	})

	_ecs.add_component(entity_id, "Health", {
		"current": def.get("health_max", 500.0),
		"max": def.get("health_max", 500.0),
		"armor_type": def.get("armor_type", "building"),
	})

	_ecs.add_component(entity_id, "FactionComponent", {"faction_id": faction_id})

	if def.has("vision_range"):
		_ecs.add_component(entity_id, "VisionRange", {"range": def["vision_range"]})

	# Power components added post-construction (StructureSystem.tick handles this).
	# Store the power values in structure def for StructureSystem to apply on completion.
	# For structures with no build time (construction yard), apply immediately.
	var build_time: float = def.get("build_time", 10.0)
	if build_time <= 1.0:
		_apply_power_components(entity_id, def)

	# Role tag — all structures default to CommanderControlled
	_ecs.add_component(entity_id, "CommanderControlled", {})

	return entity_id


func _apply_power_components(entity_id: int, def: Dictionary) -> void:
	var consumption: float = def.get("power_consumption", 0.0)
	var production: float = def.get("power_production", 0.0)
	if consumption > 0.0:
		_ecs.add_component(entity_id, "PowerConsumer", {"drain": consumption, "priority": 2})
	if production > 0.0:
		_ecs.add_component(entity_id, "PowerProducer", {"output": production})


# ── Hardcoded Fallback Definitions ───────────────────────────────────────────
# Used until YAML loading is implemented (Phase 2).

func _builtin_unit_definitions() -> Dictionary:
	return {
		"aegis_rifleman": {
			"faction_id": 0,
			"health_max": 100.0,
			"armor_type": "light",
			"speed": 4.0,
			"vision_range": 6.0,
			"damage": 15.0,
			"weapon_range": 6.0,
			"cooldown": 0.8,
			"damage_type": "kinetic",
			"targets": ["ground"],
			"tags": ["infantry", "combat"],
		},
		"aegis_engineer": {
			"faction_id": 0,
			"health_max": 60.0,
			"armor_type": "light",
			"speed": 3.5,
			"vision_range": 5.0,
			"tags": ["infantry", "engineer"],
		},
		"aegis_harvester": {
			"faction_id": 0,
			"health_max": 150.0,
			"armor_type": "medium",
			"speed": 5.0,
			"vision_range": 4.0,
			"tags": ["vehicle", "harvester"],
		},
		"forge_rifleman": {
			"faction_id": 1,
			"health_max": 110.0,
			"armor_type": "light",
			"speed": 3.8,
			"vision_range": 6.0,
			"damage": 16.0,
			"weapon_range": 6.0,
			"cooldown": 0.9,
			"damage_type": "kinetic",
			"targets": ["ground"],
			"tags": ["infantry", "combat"],
		},
	}


func _builtin_structure_definitions() -> Dictionary:
	return {
		# AEGIS T1
		"aegis_construction_yard": {
			"structure_type": "aegis_construction_yard",
			"faction": "aegis",
			"tier": 1,
			"cost_primary": 0.0,
			"cost_secondary": 0.0,
			"build_time": 1.0,
			"build_requirements": [],
			"footprint_width": 3,
			"footprint_height": 3,
			"health_max": 1500.0,
			"armor_type": "building",
			"power_consumption": 0.0,
			"power_production": 0.0,
			"vision_range": 8.0,
		},
		"aegis_power_plant": {
			"structure_type": "aegis_power_plant",
			"faction": "aegis",
			"tier": 1,
			"cost_primary": 300.0,
			"cost_secondary": 0.0,
			"build_time": 8.0,
			"build_requirements": [],
			"footprint_width": 2,
			"footprint_height": 2,
			"health_max": 600.0,
			"armor_type": "building",
			"power_consumption": 0.0,
			"power_production": 100.0,
			"vision_range": 4.0,
		},
		"aegis_barracks": {
			"structure_type": "aegis_barracks",
			"faction": "aegis",
			"tier": 1,
			"cost_primary": 600.0,
			"cost_secondary": 0.0,
			"build_time": 12.0,
			"build_requirements": [],
			"footprint_width": 2,
			"footprint_height": 2,
			"health_max": 800.0,
			"armor_type": "building",
			"power_consumption": 20.0,
			"power_production": 0.0,
			"vision_range": 5.0,
		},
		"aegis_refinery": {
			"structure_type": "aegis_refinery",
			"faction": "aegis",
			"tier": 1,
			"cost_primary": 1000.0,
			"cost_secondary": 0.0,
			"build_time": 15.0,
			"build_requirements": [],
			"footprint_width": 2,
			"footprint_height": 2,
			"health_max": 900.0,
			"armor_type": "building",
			"power_consumption": 15.0,
			"power_production": 0.0,
			"vision_range": 5.0,
		},
		"aegis_war_factory": {
			"structure_type": "aegis_war_factory",
			"faction": "aegis",
			"tier": 1,
			"cost_primary": 2000.0,
			"cost_secondary": 0.0,
			"build_time": 20.0,
			"build_requirements": ["aegis_barracks"],
			"footprint_width": 3,
			"footprint_height": 3,
			"health_max": 1200.0,
			"armor_type": "building",
			"power_consumption": 30.0,
			"power_production": 0.0,
			"vision_range": 6.0,
		},
		# FORGE T1
		"forge_construction_yard": {
			"structure_type": "forge_construction_yard",
			"faction": "forge",
			"tier": 1,
			"cost_primary": 0.0,
			"cost_secondary": 0.0,
			"build_time": 1.0,
			"build_requirements": [],
			"footprint_width": 3,
			"footprint_height": 3,
			"health_max": 1800.0,
			"armor_type": "building",
			"power_consumption": 0.0,
			"power_production": 0.0,
			"vision_range": 8.0,
		},
		"forge_power_plant": {
			"structure_type": "forge_power_plant",
			"faction": "forge",
			"tier": 1,
			"cost_primary": 350.0,
			"cost_secondary": 0.0,
			"build_time": 9.0,
			"build_requirements": [],
			"footprint_width": 2,
			"footprint_height": 2,
			"health_max": 700.0,
			"armor_type": "building",
			"power_consumption": 0.0,
			"power_production": 110.0,
			"vision_range": 4.0,
		},
		"forge_barracks": {
			"structure_type": "forge_barracks",
			"faction": "forge",
			"tier": 1,
			"cost_primary": 650.0,
			"cost_secondary": 0.0,
			"build_time": 12.0,
			"build_requirements": [],
			"footprint_width": 2,
			"footprint_height": 2,
			"health_max": 850.0,
			"armor_type": "building",
			"power_consumption": 20.0,
			"power_production": 0.0,
			"vision_range": 5.0,
		},
		"forge_war_factory": {
			"structure_type": "forge_war_factory",
			"faction": "forge",
			"tier": 1,
			"cost_primary": 2000.0,
			"cost_secondary": 0.0,
			"build_time": 20.0,
			"build_requirements": ["forge_barracks"],
			"footprint_width": 3,
			"footprint_height": 3,
			"health_max": 1300.0,
			"armor_type": "building",
			"power_consumption": 30.0,
			"power_production": 0.0,
			"vision_range": 6.0,
		},
	}
