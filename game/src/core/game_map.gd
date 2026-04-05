class_name GameMap
extends Node

# Tile size in world units
const TILE_SIZE: int = 64
const DEFAULT_WIDTH: int = 128
const DEFAULT_HEIGHT: int = 96

# Terrain passability keys
const PASS_FOOT: String = "foot"
const PASS_WHEELED: String = "wheeled"
const PASS_TRACKED: String = "tracked"
const PASS_HOVER: String = "hover"
const PASS_FLYING: String = "flying"

signal map_loaded(width: int, height: int)

var width: int = DEFAULT_WIDTH
var height: int = DEFAULT_HEIGHT
var spawn_points: Dictionary = {}
var resource_nodes: Array = []
var expansion_points: Array = []

# tile_meta[x][y] = { passable_by: [...], vision_bonus: int, type: String }
var tile_meta: Array = []

func load_from_data(map_data: Dictionary) -> void:
	width = map_data.get("dimensions", {}).get("width", DEFAULT_WIDTH)
	height = map_data.get("dimensions", {}).get("height", DEFAULT_HEIGHT)

	_init_tile_meta()
	_apply_terrain(map_data.get("terrain", {}))

	spawn_points = map_data.get("spawn_points", {})
	resource_nodes = map_data.get("resources", [])
	expansion_points = map_data.get("expansions", [])

	emit_signal("map_loaded", width, height)

# Returns spawn data for a team
func get_spawn_data(team: String) -> Dictionary:
	return spawn_points.get(team, {})

# Spawn resource node entities at correct positions
func spawn_resource_nodes(ecs: Object, entity_factory: Object) -> void:
	for node_data in resource_nodes:
		var pos: Vector2 = Vector2(
			float(node_data["position"][0]),
			float(node_data["position"][1])
		) * TILE_SIZE
		var entity_id: int = ecs.create_entity()
		ecs.add_component(entity_id, "position", {"x": pos.x, "y": pos.y})
		ecs.add_component(entity_id, "resource_node", {
			"type": node_data["type"],
			"remaining": node_data.get("amount", 0)
		})

# Check if a tile is passable for a given movement type
func is_passable(tx: int, ty: int, movement_type: String) -> bool:
	if tx < 0 or ty < 0 or tx >= width or ty >= height:
		return false
	var meta: Dictionary = _get_tile_meta(tx, ty)
	var passable_by: Array = meta.get("passable_by", [PASS_FOOT, PASS_WHEELED, PASS_TRACKED, PASS_HOVER, PASS_FLYING])
	return movement_type in passable_by

# Returns vision bonus for a tile (from cliffs, towers, etc.)
func get_vision_bonus(tx: int, ty: int) -> int:
	var meta: Dictionary = _get_tile_meta(tx, ty)
	return meta.get("vision_bonus", 0)

# Returns tile type string
func get_tile_type(tx: int, ty: int) -> String:
	var meta: Dictionary = _get_tile_meta(tx, ty)
	return meta.get("type", "grass")

# ---- Private ----

func _init_tile_meta() -> void:
	tile_meta = []
	for _x in range(width):
		var col: Array = []
		for _y in range(height):
			col.append({
				"type": "grass",
				"passable_by": [PASS_FOOT, PASS_WHEELED, PASS_TRACKED, PASS_HOVER, PASS_FLYING],
				"vision_bonus": 0
			})
		tile_meta.append(col)

func _get_tile_meta(tx: int, ty: int) -> Dictionary:
	if tx < 0 or ty < 0 or tx >= width or ty >= height:
		return {}
	if tx >= tile_meta.size():
		return {}
	var col: Array = tile_meta[tx]
	if ty >= col.size():
		return {}
	return col[ty]

func _set_tile_meta(tx: int, ty: int, meta: Dictionary) -> void:
	if tx < 0 or ty < 0 or tx >= width or ty >= height:
		return
	if tx >= tile_meta.size():
		return
	var col: Array = tile_meta[tx]
	if ty >= col.size():
		return
	col[ty] = meta

func _apply_terrain(terrain: Dictionary) -> void:
	# base_type is already set to grass in _init_tile_meta
	# If a different base_type is specified, apply it
	var base_type: String = terrain.get("base_type", "grass")
	if base_type != "grass":
		_flood_base_type(base_type)

	var features: Array = terrain.get("features", [])
	for feature in features:
		_apply_feature(feature)

func _flood_base_type(base_type: String) -> void:
	var passable: Array = _passable_for_type(base_type)
	for tx in range(width):
		for ty in range(height):
			tile_meta[tx][ty] = {
				"type": base_type,
				"passable_by": passable,
				"vision_bonus": 0
			}

func _apply_feature(feature: Dictionary) -> void:
	var ftype: String = feature.get("type", "")
	var bounds: Dictionary = feature.get("bounds", {})
	var bx: int = bounds.get("x", 0)
	var by: int = bounds.get("y", 0)
	var bw: int = bounds.get("width", 1)
	var bh: int = bounds.get("height", 1)
	var passable_by: Array = feature.get("passable_by", [])
	var provides: Dictionary = feature.get("provides", {})

	match ftype:
		"water":
			# Water is impassable by default — only explicit bridge/ford overrides allow passage
			_apply_rect_tiles(bx, by, bw, bh, {
				"type": "water",
				"passable_by": [],
				"vision_bonus": 0
			})

		"bridge":
			# Bridge allows foot, wheeled, tracked — not hover or flying (they don't need it)
			var bridge_pass: Array = passable_by if passable_by.size() > 0 \
				else [PASS_FOOT, PASS_WHEELED, PASS_TRACKED]
			_apply_rect_tiles(bx, by, bw, bh, {
				"type": "bridge",
				"passable_by": bridge_pass,
				"vision_bonus": 0
			})

		"ford":
			# Ford is infantry-only by default
			var ford_pass: Array = passable_by if passable_by.size() > 0 else [PASS_FOOT]
			_apply_rect_tiles(bx, by, bw, bh, {
				"type": "ford",
				"passable_by": ford_pass,
				"vision_bonus": 0
			})

		"cliff":
			# Cliffs are passable by flying only; grant vision bonus
			var vision_bonus: int = provides.get("vision_bonus", 0)
			_apply_rect_tiles(bx, by, bw, bh, {
				"type": "cliff",
				"passable_by": [PASS_FLYING],
				"vision_bonus": vision_bonus
			})

		"rocky_ridge":
			# Impassable terrain barrier
			_apply_rect_tiles(bx, by, bw, bh, {
				"type": "rocky_ridge",
				"passable_by": [PASS_FLYING],
				"vision_bonus": 0
			})

		"sand":
			_apply_rect_tiles(bx, by, bw, bh, {
				"type": "sand",
				"passable_by": [PASS_FOOT, PASS_WHEELED, PASS_TRACKED, PASS_HOVER, PASS_FLYING],
				"vision_bonus": 0
			})

		_:
			push_warning("GameMap: unknown terrain feature type '%s'" % ftype)

func _apply_rect_tiles(bx: int, by: int, bw: int, bh: int, meta: Dictionary) -> void:
	for tx in range(bx, bx + bw):
		for ty in range(by, by + bh):
			_set_tile_meta(tx, ty, meta.duplicate(true))

func _passable_for_type(base_type: String) -> Array:
	match base_type:
		"water":
			return []
		"cliff", "rocky_ridge":
			return [PASS_FLYING]
		"sand", "grass", "dirt":
			return [PASS_FOOT, PASS_WHEELED, PASS_TRACKED, PASS_HOVER, PASS_FLYING]
		_:
			return [PASS_FOOT, PASS_WHEELED, PASS_TRACKED, PASS_HOVER, PASS_FLYING]

# Convenience: create a flat all-grass map of given dimensions (for testing)
func load_flat_map(w: int, h: int) -> void:
	width = w
	height = h
	_init_tile_meta()
	emit_signal("map_loaded", width, height)

# Returns world-space bounds of the map as a Rect2
func get_world_bounds() -> Rect2:
	return Rect2(0.0, 0.0, float(width * TILE_SIZE), float(height * TILE_SIZE))
