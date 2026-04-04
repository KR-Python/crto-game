class_name CommandProcessingSystem
extends RefCounted

## Processes move commands each tick. Groups units by destination and
## selects flowfield pathfinding for large groups (>FLOWFIELD_THRESHOLD)
## or individual A* for small ones.

const FLOWFIELD_THRESHOLD: int = 5

var _nav_grid: NavGrid
var _flowfield_cache: Dictionary = {}  # "x,y" → Flowfield
var _cache_valid: bool = true


func _init(nav_grid: NavGrid) -> void:
	_nav_grid = nav_grid
	_nav_grid.nav_grid_changed.connect(_on_nav_grid_changed)


func _on_nav_grid_changed() -> void:
	_flowfield_cache.clear()
	_cache_valid = true  # cache cleared, new lookups will rebuild


## Main per-tick entry point. Reads MoveCommand components, groups by
## destination, dispatches to flowfield or individual A*.
## Returns a Dictionary: entity_id → Vector2 (direction this tick).
func process_move_commands(ecs: Object, _tick_count: int) -> Dictionary:
	var directions: Dictionary = {}

	# Gather all entities with MoveCommand
	var move_entities: Array = _get_entities_with_move(ecs)
	if move_entities.is_empty():
		return directions

	# Group by destination cell
	var groups: Dictionary = {}  # "cx,cy" → [entity_data, ...]
	for entity_data: Dictionary in move_entities:
		var dest: Vector2 = entity_data["destination"]
		var cell: Vector2i = _nav_grid.world_to_cell(dest)
		var key: String = "%d,%d" % [cell.x, cell.y]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(entity_data)

	# Process each group
	for key: String in groups:
		var group: Array = groups[key]
		if group.size() > FLOWFIELD_THRESHOLD:
			directions.merge(_process_with_flowfield(group))
		else:
			directions.merge(_process_with_astar(group))

	return directions


## Get or build a cached flowfield for the given destination.
func get_or_build_flowfield(dest_world: Vector2, move_type: int = NavGrid.MOVE_TRACKED) -> Flowfield:
	var cell: Vector2i = _nav_grid.world_to_cell(dest_world)
	var key: String = "%d,%d" % [cell.x, cell.y]
	if _flowfield_cache.has(key):
		return _flowfield_cache[key]
	var ff: Flowfield = Flowfield.new(_nav_grid)
	ff.build(dest_world, move_type)
	_flowfield_cache[key] = ff
	return ff


func _process_with_flowfield(group: Array) -> Dictionary:
	var dirs: Dictionary = {}
	if group.is_empty():
		return dirs
	var dest: Vector2 = group[0]["destination"]
	var ff: Flowfield = get_or_build_flowfield(dest)
	for entity_data: Dictionary in group:
		var pos: Vector2 = entity_data["position"]
		dirs[entity_data["entity_id"]] = ff.get_direction(pos)
	return dirs


func _process_with_astar(group: Array) -> Dictionary:
	# Stub: individual A* not yet implemented. Return direct direction for now.
	var dirs: Dictionary = {}
	for entity_data: Dictionary in group:
		var pos: Vector2 = entity_data["position"]
		var dest: Vector2 = entity_data["destination"]
		var diff: Vector2 = dest - pos
		dirs[entity_data["entity_id"]] = diff.normalized() if diff.length() > 0.01 else Vector2.ZERO
	return dirs


func _get_entities_with_move(ecs: Object) -> Array:
	# Expects ecs to have get_entities_with_component("MoveCommand")
	# Each returns { entity_id, position: Vector2, destination: Vector2 }
	if ecs.has_method("get_entities_with_move_command"):
		return ecs.get_entities_with_move_command()
	return []
