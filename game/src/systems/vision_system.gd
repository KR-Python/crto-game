class_name VisionSystem

# Computes fog-of-war visibility per faction.
# Uses dirty region tracking to avoid recomputing the entire map each tick.
#
# Phase 6: dirty region tracking is the key optimization.
# If no entities moved this tick, vision computation is completely skipped.
# When entities move, only cells near moved positions are recomputed.
#
# Reads: Position, VisionRange, Faction
# Writes: _visible_cells (internal), queried by renderer

var _spatial_hash: SpatialHash = null
var _dirty_positions: Array = []
var _visible_cells: Dictionary = {}  # int (faction_id) -> Dictionary{Vector2i -> int}
var _needs_full_rebuild: bool = true

const CELL_SIZE: float = 32.0  # fog cell size (1 tile)



## Register which team a faction belongs to (for shared vision between allies).
## Vision is currently per-faction; this is a stub for Phase 2 allied vision.
func register_faction_team(faction_id: int, _team_id: int) -> void:
	if not _visible_cells.has(faction_id):
		_visible_cells[faction_id] = {}

func set_spatial_hash(sh: SpatialHash) -> void:
	_spatial_hash = sh


func mark_dirty(position: Vector2) -> void:
	_dirty_positions.append(position)


func request_full_rebuild() -> void:
	_needs_full_rebuild = true


func is_visible(faction_id: int, world_pos: Vector2) -> bool:
	var cell: Vector2i = _pos_to_cell(world_pos)
	if _visible_cells.has(faction_id):
		return _visible_cells[faction_id].has(cell)
	return false


func get_visible_cell_count(faction_id: int) -> int:
	if _visible_cells.has(faction_id):
		return _visible_cells[faction_id].size()
	return 0


func tick(ecs: ECS, _tick_count: int) -> void:
	if _needs_full_rebuild:
		_full_rebuild(ecs)
		_needs_full_rebuild = false
		_dirty_positions.clear()
		return

	if _dirty_positions.is_empty():
		return

	_incremental_update(ecs)
	_dirty_positions.clear()


func _full_rebuild(ecs: ECS) -> void:
	_visible_cells.clear()
	var entities: Array = ecs.query(["Position", "VisionRange", "Faction"])
	for eid in entities:
		_add_vision_for_entity(ecs, eid)


func _incremental_update(ecs: ECS) -> void:
	var max_range: float = 256.0
	var dirty_cells: Dictionary = {}

	for pos in _dirty_positions:
		var min_c: Vector2i = _pos_to_cell(pos - Vector2(max_range, max_range))
		var max_c: Vector2i = _pos_to_cell(pos + Vector2(max_range, max_range))
		for x in range(min_c.x, max_c.x + 1):
			for y in range(min_c.y, max_c.y + 1):
				dirty_cells[Vector2i(x, y)] = true

	for faction_id in _visible_cells:
		var faction_vis: Dictionary = _visible_cells[faction_id]
		for cell in dirty_cells:
			faction_vis.erase(cell)

	var entities: Array = ecs.query(["Position", "VisionRange", "Faction"])
	for eid in entities:
		var pos: Dictionary = ecs.get_component(eid, "Position")
		var vr: Dictionary = ecs.get_component(eid, "VisionRange")
		var r: float = vr.get("range", 64.0)
		var epos := Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
		var min_c: Vector2i = _pos_to_cell(epos - Vector2(r, r))
		var max_c: Vector2i = _pos_to_cell(epos + Vector2(r, r))

		var overlaps: bool = false
		for cx in range(min_c.x, max_c.x + 1):
			if overlaps:
				break
			for cy in range(min_c.y, max_c.y + 1):
				if dirty_cells.has(Vector2i(cx, cy)):
					overlaps = true
					break

		if overlaps:
			_add_vision_for_entity(ecs, eid)


func _add_vision_for_entity(ecs: ECS, eid: int) -> void:
	var pos: Dictionary = ecs.get_component(eid, "Position")
	var vr: Dictionary = ecs.get_component(eid, "VisionRange")
	var faction: Dictionary = ecs.get_component(eid, "Faction")
	var faction_id: int = faction.get("faction_id", 0)
	var r: float = vr.get("range", 64.0)
	var epos := Vector2(pos.get("x", 0.0), pos.get("y", 0.0))

	if not _visible_cells.has(faction_id):
		_visible_cells[faction_id] = {}

	var faction_vis: Dictionary = _visible_cells[faction_id]
	var r_sq: float = r * r
	var min_c: Vector2i = _pos_to_cell(epos - Vector2(r, r))
	var max_c: Vector2i = _pos_to_cell(epos + Vector2(r, r))

	for cx in range(min_c.x, max_c.x + 1):
		for cy in range(min_c.y, max_c.y + 1):
			var cell_center := Vector2(cx * CELL_SIZE + CELL_SIZE * 0.5, cy * CELL_SIZE + CELL_SIZE * 0.5)
			var dx: float = cell_center.x - epos.x
			var dy: float = cell_center.y - epos.y
			if dx * dx + dy * dy <= r_sq:
				var cell := Vector2i(cx, cy)
				faction_vis[cell] = faction_vis.get(cell, 0) + 1


func _pos_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / CELL_SIZE)), int(floor(pos.y / CELL_SIZE)))
