class_name StructureSystem
## Tick pipeline step: runs after EconomySystem, before ProductionSystem.
## Manages structure placement validation, build progress, cancel, and destroy.
##
## Reads:  Structure, Position, Footprint, FactionComponent
## Writes: Structure (built, build_progress), new entity via EntityFactory
## Emits:  structure_completed(entity_id, structure_type)
##         structure_destroyed(entity_id, structure_type, position)
## Depends on: EconomySystem (spend/refund), EntityFactory, NavGrid, Pathfinder

const TICKS_PER_SECOND: float = 15.0

## Injected at init — required for resource checks.
var economy_system: Object = null  # EconomySystem

## Injected at init — required for NavGrid blocking.
var nav_grid: Object = null  # NavGrid

## Injected at init — required for pathfinder cache invalidation.
var pathfinder: Object = null  # Pathfinder

## Injected at init — used to create structure entities.
var entity_factory: Object = null  # EntityFactory

## Structure definition cache: structure_type -> definition dict.
## Loaded from YAML (stubbed). Fallback: hardcoded T1 AEGIS/FORGE structures.
var _structure_definitions: Dictionary = {}

## Tracks blocked cells per entity: entity_id -> Array[Vector2i]
var _blocked_cells: Dictionary = {}

signal structure_completed(entity_id: int, structure_type: String)
signal structure_destroyed(entity_id: int, structure_type: String, position: Vector2)


# ── Public API ────────────────────────────────────────────────────────────────

## Place a structure for a faction at a position.
## Returns {success: bool, entity_id: int, error: String}
func place_structure(faction_id: int, structure_type: String, position: Vector2, ecs: ECS) -> Dictionary:
	var struct_def: Dictionary = _get_structure_definition(structure_type)
	if struct_def.is_empty():
		return {success = false, entity_id = -1, error = "UNKNOWN_STRUCTURE_TYPE"}

	# 1. Check resources
	var cost_primary: float = struct_def.get("cost_primary", 0.0)
	var cost_secondary: float = struct_def.get("cost_secondary", 0.0)
	if economy_system != null:
		var resources: Dictionary = economy_system.get_resources(faction_id)
		if resources.get("primary", 0.0) < cost_primary or resources.get("secondary", 0.0) < cost_secondary:
			return {success = false, entity_id = -1, error = "INSUFFICIENT_RESOURCES"}

	# 2. Validate position
	var footprint_w: int = struct_def.get("footprint_width", 2)
	var footprint_h: int = struct_def.get("footprint_height", 2)
	var placement_error: String = _validate_placement(position, footprint_w, footprint_h, ecs)
	if placement_error != "":
		return {success = false, entity_id = -1, error = placement_error}

	# 3. Check build requirements
	var requirements: Array = struct_def.get("build_requirements", [])
	if not _check_build_requirements(faction_id, requirements, ecs):
		return {success = false, entity_id = -1, error = "BUILD_REQUIREMENTS_NOT_MET"}

	# 4. Deduct cost
	if economy_system != null:
		var spent: bool = economy_system.spend(faction_id, cost_primary, cost_secondary)
		if not spent:
			return {success = false, entity_id = -1, error = "INSUFFICIENT_RESOURCES"}

	# 5. Create entity
	var entity_id: int = _spawn_structure_entity(structure_type, position, faction_id, struct_def, ecs)

	# 6. Block NavGrid cells
	_block_footprint(entity_id, position, footprint_w, footprint_h)

	# 7. Invalidate pathfinder cache
	if pathfinder != null and pathfinder.has_method("invalidate_region"):
		var region := Rect2(position, Vector2(float(footprint_w), float(footprint_h)))
		pathfinder.invalidate_region(region)

	return {success = true, entity_id = entity_id, error = ""}


## Tick — advance build progress on all under-construction structures.
func tick(ecs: ECS, tick_count: int) -> void:
	var entities: Array = ecs.query(["Structure", "FactionComponent"])
	for entity_id: int in entities:
		var structure: Dictionary = ecs.get_component(entity_id, "Structure")
		if structure.get("built", false):
			continue  # Already built — nothing to do

		var struct_type: String = structure.get("structure_type", "")
		var struct_def: Dictionary = _get_structure_definition(struct_type)
		var build_time: float = struct_def.get("build_time", 10.0)

		# Advance by 1 tick
		var progress: float = structure.get("build_progress", 0.0) + 1.0
		structure["build_progress"] = progress

		if progress >= build_time * TICKS_PER_SECOND:
			structure["built"] = true
			structure["build_progress"] = build_time * TICKS_PER_SECOND
			ecs.add_component(entity_id, "Structure", structure)

			# Add power components once built
			_activate_power_components(entity_id, struct_def, ecs)

			structure_completed.emit(entity_id, struct_type)
		else:
			ecs.add_component(entity_id, "Structure", structure)


## Cancel an under-construction structure — full refund, entity removed.
func cancel_structure(entity_id: int, ecs: ECS) -> void:
	var structure: Dictionary = ecs.get_component(entity_id, "Structure")
	if structure.is_empty():
		push_warning("StructureSystem.cancel_structure: entity %d has no Structure component" % entity_id)
		return

	if structure.get("built", false):
		push_warning("StructureSystem.cancel_structure: entity %d is already built — use destroy_structure" % entity_id)
		return

	var struct_type: String = structure.get("structure_type", "")
	var struct_def: Dictionary = _get_structure_definition(struct_type)
	var faction_comp: Dictionary = ecs.get_component(entity_id, "FactionComponent")

	# Full refund
	if economy_system != null and not faction_comp.is_empty():
		economy_system.refund(
			faction_comp["faction_id"],
			struct_def.get("cost_primary", 0.0),
			struct_def.get("cost_secondary", 0.0)
		)

	_unblock_footprint(entity_id)
	ecs.destroy_entity(entity_id)


## Destroy a built structure — no refund. Triggers ProductionSystem 50% queue refund.
func destroy_structure(entity_id: int, ecs: ECS) -> void:
	var structure: Dictionary = ecs.get_component(entity_id, "Structure")
	if structure.is_empty():
		push_warning("StructureSystem.destroy_structure: entity %d has no Structure component" % entity_id)
		return

	var struct_type: String = structure.get("structure_type", "")
	var pos_comp: Dictionary = ecs.get_component(entity_id, "Position")
	var position := Vector2(pos_comp.get("x", 0.0), pos_comp.get("y", 0.0))

	_unblock_footprint(entity_id)
	ecs.destroy_entity(entity_id)

	structure_destroyed.emit(entity_id, struct_type, position)


# ── Structure Definitions ─────────────────────────────────────────────────────

## Register a structure type definition.
## In production this is loaded from YAML at startup.
func register_structure_definition(structure_type: String, def: Dictionary) -> void:
	_structure_definitions[structure_type] = def


# ── Internal Helpers ──────────────────────────────────────────────────────────

func _get_structure_definition(structure_type: String) -> Dictionary:
	if _structure_definitions.has(structure_type):
		return _structure_definitions[structure_type]
	# Hardcoded T1 AEGIS/FORGE fallback for Phase 1
	return _builtin_structure_definitions().get(structure_type, {})


func _builtin_structure_definitions() -> Dictionary:
	return {
		# AEGIS T1
		"aegis_construction_yard": {
			"structure_type": "aegis_construction_yard",
			"display_name": "Construction Yard",
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
			"water_allowed": false,
		},
		"aegis_power_plant": {
			"structure_type": "aegis_power_plant",
			"display_name": "Power Plant",
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
			"water_allowed": false,
		},
		"aegis_barracks": {
			"structure_type": "aegis_barracks",
			"display_name": "Barracks",
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
			"water_allowed": false,
		},
		"aegis_refinery": {
			"structure_type": "aegis_refinery",
			"display_name": "Refinery",
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
			"water_allowed": false,
		},
		"aegis_war_factory": {
			"structure_type": "aegis_war_factory",
			"display_name": "War Factory",
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
			"water_allowed": false,
		},
		# FORGE T1
		"forge_construction_yard": {
			"structure_type": "forge_construction_yard",
			"display_name": "Foundry Hub",
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
			"water_allowed": false,
		},
		"forge_power_plant": {
			"structure_type": "forge_power_plant",
			"display_name": "Combustion Plant",
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
			"water_allowed": false,
		},
		"forge_barracks": {
			"structure_type": "forge_barracks",
			"display_name": "Forge Barracks",
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
			"water_allowed": false,
		},
		"forge_war_factory": {
			"structure_type": "forge_war_factory",
			"display_name": "Iron Works",
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
			"water_allowed": false,
		},
	}


func _validate_placement(position: Vector2, footprint_w: int, footprint_h: int, ecs: ECS) -> String:
	# Check map bounds via NavGrid
	if nav_grid != null:
		var cell: Vector2i = nav_grid.world_to_cell(position)
		var max_x: int = cell.x + footprint_w - 1
		var max_y: int = cell.y + footprint_h - 1
		if not nav_grid.is_in_bounds(cell.x, cell.y) or not nav_grid.is_in_bounds(max_x, max_y):
			return "OUT_OF_BOUNDS"

		# Check all cells walkable (no water, no overlap with existing structures)
		for dy in range(footprint_h):
			for dx in range(footprint_w):
				var cx: int = cell.x + dx
				var cy: int = cell.y + dy
				if not nav_grid.is_walkable(cx, cy, NavGrid.MOVE_FOOT):
					return "INVALID_TERRAIN"
	else:
		# No NavGrid — do overlap check via ECS only
		pass

	# Check overlap with existing structures
	if _is_overlapping(position, footprint_w, footprint_h, ecs):
		return "OVERLAPPING_STRUCTURE"

	return ""


func _is_overlapping(position: Vector2, footprint_w: int, footprint_h: int, ecs: ECS) -> bool:
	# Check against all existing structure entities
	var existing: Array = ecs.query(["Structure", "Position", "Footprint"])
	for entity_id: int in existing:
		var pos: Dictionary = ecs.get_component(entity_id, "Position")
		var fp: Dictionary = ecs.get_component(entity_id, "Footprint")
		var ex: float = pos.get("x", 0.0)
		var ey: float = pos.get("y", 0.0)
		var ew: float = float(fp.get("width", 1))
		var eh: float = float(fp.get("height", 1))

		# AABB overlap check
		var r1 := Rect2(position.x, position.y, float(footprint_w), float(footprint_h))
		var r2 := Rect2(ex, ey, ew, eh)
		if r1.intersects(r2):
			return true

	return false


func _check_build_requirements(faction_id: int, requirements: Array, ecs: ECS) -> bool:
	if requirements.is_empty():
		return true

	# Gather all built structures for this faction
	var built_types: Array = []
	var structs: Array = ecs.query(["Structure", "FactionComponent"])
	for entity_id: int in structs:
		var structure: Dictionary = ecs.get_component(entity_id, "Structure")
		if not structure.get("built", false):
			continue
		var faction: Dictionary = ecs.get_component(entity_id, "FactionComponent")
		if faction.get("faction_id", -1) != faction_id:
			continue
		var struct_type: String = structure.get("structure_type", "")
		if struct_type != "":
			built_types.append(struct_type)

	for req: String in requirements:
		if not req in built_types:
			return false

	return true


func _spawn_structure_entity(structure_type: String, position: Vector2, faction_id: int, struct_def: Dictionary, ecs: ECS) -> int:
	if entity_factory != null and entity_factory.has_method("create_structure"):
		return entity_factory.create_structure(structure_type, position, faction_id)

	# Fallback: create entity directly
	var entity_id: int = ecs.create_entity()
	ecs.add_component(entity_id, "Position", {"x": position.x, "y": position.y})
	ecs.add_component(entity_id, "Structure", {
		"structure_type": structure_type,
		"built": false,
		"build_progress": 0.0,
	})
	ecs.add_component(entity_id, "Footprint", {
		"width": struct_def.get("footprint_width", 2),
		"height": struct_def.get("footprint_height", 2),
	})
	ecs.add_component(entity_id, "Health", {
		"current": struct_def.get("health_max", 500.0),
		"max": struct_def.get("health_max", 500.0),
		"armor_type": struct_def.get("armor_type", "building"),
	})
	ecs.add_component(entity_id, "FactionComponent", {"faction_id": faction_id})
	ecs.add_component(entity_id, "VisionRange", {"range": struct_def.get("vision_range", 5.0)})
	ecs.add_component(entity_id, "CommanderControlled", {})
	return entity_id


func _activate_power_components(entity_id: int, struct_def: Dictionary, ecs: ECS) -> void:
	var consumption: float = struct_def.get("power_consumption", 0.0)
	var production: float = struct_def.get("power_production", 0.0)

	if consumption > 0.0:
		ecs.add_component(entity_id, "PowerConsumer", {"drain": consumption, "priority": 2})

	if production > 0.0:
		ecs.add_component(entity_id, "PowerProducer", {"output": production})


func _block_footprint(entity_id: int, position: Vector2, footprint_w: int, footprint_h: int) -> void:
	if nav_grid == null:
		return
	var cell: Vector2i = nav_grid.world_to_cell(position)
	var cells: Array[Vector2i] = []

	for dy in range(footprint_h):
		for dx in range(footprint_w):
			var cx: int = cell.x + dx
			var cy: int = cell.y + dy
			nav_grid.set_cell_walkable(cx, cy, false, 0)
			cells.append(Vector2i(cx, cy))

	_blocked_cells[entity_id] = cells


func _unblock_footprint(entity_id: int) -> void:
	if not _blocked_cells.has(entity_id):
		return
	if nav_grid == null:
		_blocked_cells.erase(entity_id)
		return

	var cells: Array = _blocked_cells[entity_id]
	for cell: Vector2i in cells:
		for move_type in [NavGrid.MOVE_FOOT, NavGrid.MOVE_WHEELED, NavGrid.MOVE_TRACKED, NavGrid.MOVE_HOVER, NavGrid.MOVE_FLYING]:
			nav_grid.set_cell_walkable(cell.x, cell.y, true, move_type)

	_blocked_cells.erase(entity_id)
