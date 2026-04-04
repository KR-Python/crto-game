class_name VisionSystem
## Tick pipeline step 11.
## Maintains per-team fog of war state. Updates each simulation tick.
##
## Fog grid: 64×48 cells (each covers 2×2 world units on a 128×96 tile map).
## Three states: 0=UNEXPLORED, 1=SEEN (previously visible), 2=VISIBLE (currently visible).
##
## Reads:  Position, VisionRange, FactionComponent, Stealthed, Detector, PoweredOff
## Writes: internal fog grids (per team)

const FOG_COLS: int = 64
const FOG_ROWS: int = 48
const CELL_SIZE: float = 2.0  # world units per fog cell side
const UNEXPLORED: int = 0
const SEEN: int = 1
const VISIBLE: int = 2

const MAX_TEAMS: int = 8

## Per-team fog grids. Index: [team_id][row * FOG_COLS + col]
var _fog: Array = []

## Faction → team mapping. Populated via register_faction_team().
var _faction_team: Dictionary = {}

## Pre-computed circle offsets per fog radius (cached for performance).
var _circle_cache: Dictionary = {}


func _init() -> void:
	for _i in range(MAX_TEAMS):
		var grid: PackedByteArray = PackedByteArray()
		grid.resize(FOG_COLS * FOG_ROWS)
		grid.fill(UNEXPLORED)
		_fog.append(grid)


func initialize(_w: int, _h: int) -> void:
	pass



# ── Public API ────────────────────────────────────────────────────────────────

## Register which team a faction belongs to (all same-team factions share vision).
func register_faction_team(faction_id: int, team_id: int) -> void:
	_faction_team[faction_id] = team_id


## Returns true if the world position is currently visible to the given faction.
func is_visible(world_pos: Vector2, faction_id: int) -> bool:
	return get_fog_state(world_pos, faction_id) == VISIBLE


## Returns fog state (0/1/2) for a world position and faction.
func get_fog_state(world_pos: Vector2, faction_id: int) -> int:
	var team_id: int = _get_team(faction_id)
	var fc: Vector2i = _world_to_fog(world_pos)
	if not _in_bounds(fc):
		return UNEXPLORED
	return _fog[team_id][fc.y * FOG_COLS + fc.x]


## Returns a 64×48 grayscale Image for GPU fog rendering.
## 0=black (unexplored), 128=dim (seen), 255=white (visible).
func get_fog_texture(faction_id: int) -> Image:
	var team_id: int = _get_team(faction_id)
	var grid: PackedByteArray = _fog[team_id]
	var img: Image = Image.create(FOG_COLS, FOG_ROWS, false, Image.FORMAT_L8)

	for row in range(FOG_ROWS):
		for col in range(FOG_COLS):
			var state: int = grid[row * FOG_COLS + col]
			var brightness: int = 0
			match state:
				UNEXPLORED: brightness = 0
				SEEN:       brightness = 128
				VISIBLE:    brightness = 255
			img.set_pixel(col, row, Color8(brightness, brightness, brightness))

	return img


# ── Tick ──────────────────────────────────────────────────────────────────────

## Main tick — recalculate vision for all teams.
func tick(ecs: ECS, tick_count: int) -> void:
	_decay_all_grids()
	_apply_vision_sources(ecs)


# ── Stealth Query ─────────────────────────────────────────────────────────────

## Returns true if `stealthed_entity` is detectable by `observer_faction`.
## Checks Detector range first, then close-proximity reveal (Stealthed.detection_range).
func is_entity_detectable(stealthed_entity: int, observer_faction: int, ecs: ECS) -> bool:
	var stealthed_comp: Dictionary = ecs.get_component(stealthed_entity, "Stealthed")
	if stealthed_comp.is_empty():
		return true  # Not stealthed — always visible

	var stealthed_pos_comp: Dictionary = ecs.get_component(stealthed_entity, "Position")
	if stealthed_pos_comp.is_empty():
		return false

	var stealthed_pos: Vector2 = Vector2(stealthed_pos_comp["x"], stealthed_pos_comp["y"])
	var detection_range: float = stealthed_comp.get("detection_range", 0.0)

	var stealthed_faction_comp: Dictionary = ecs.get_component(stealthed_entity, "FactionComponent")
	if stealthed_faction_comp.is_empty():
		return false
	var stealthed_faction: int = stealthed_faction_comp["faction_id"]

	# Check observer's Detector entities
	var detector_entities: Array = ecs.get_entities_with_component("Detector")
	for det_id in detector_entities:
		var det_faction_comp: Dictionary = ecs.get_component(det_id, "FactionComponent")
		if det_faction_comp.is_empty() or det_faction_comp["faction_id"] != observer_faction:
			continue

		var det_pos_comp: Dictionary = ecs.get_component(det_id, "Position")
		if det_pos_comp.is_empty():
			continue

		var det_pos: Vector2 = Vector2(det_pos_comp["x"], det_pos_comp["y"])
		var det_comp: Dictionary = ecs.get_component(det_id, "Detector")
		var detector_range: float = det_comp.get("range", 0.0)

		if stealthed_pos.distance_to(det_pos) <= detector_range:
			return true

	# Close-proximity reveal: any observer enemy within stealthed.detection_range
	var all_entities: Array = ecs.get_all_entities()
	for other_id in all_entities:
		if other_id == stealthed_entity:
			continue
		var other_faction_comp: Dictionary = ecs.get_component(other_id, "FactionComponent")
		if other_faction_comp.is_empty():
			continue
		if other_faction_comp["faction_id"] == stealthed_faction:
			continue
		if other_faction_comp["faction_id"] != observer_faction:
			continue

		var other_pos_comp: Dictionary = ecs.get_component(other_id, "Position")
		if other_pos_comp.is_empty():
			continue

		var other_pos: Vector2 = Vector2(other_pos_comp["x"], other_pos_comp["y"])
		if stealthed_pos.distance_to(other_pos) <= detection_range:
			return true

	return false


# ── Internal ──────────────────────────────────────────────────────────────────

func _decay_all_grids() -> void:
	for team_id in range(MAX_TEAMS):
		var grid: PackedByteArray = _fog[team_id]
		for i in range(grid.size()):
			if grid[i] == VISIBLE:
				grid[i] = SEEN


func _apply_vision_sources(ecs: ECS) -> void:
	var entities: Array = ecs.get_entities_with_component("VisionRange")

	for entity_id in entities:
		if ecs.has_component(entity_id, "PoweredOff"):
			continue

		var pos_comp: Dictionary = ecs.get_component(entity_id, "Position")
		if pos_comp.is_empty():
			continue

		var vision_comp: Dictionary = ecs.get_component(entity_id, "VisionRange")
		if vision_comp.is_empty():
			continue

		var faction_comp: Dictionary = ecs.get_component(entity_id, "FactionComponent")
		if faction_comp.is_empty():
			continue

		var world_pos: Vector2 = Vector2(pos_comp["x"], pos_comp["y"])
		var vision_range: float = vision_comp["range"]
		var team_id: int = _get_team(faction_comp["faction_id"])

		_illuminate(team_id, world_pos, vision_range)


func _illuminate(team_id: int, world_pos: Vector2, vision_range: float) -> void:
	var fog_center: Vector2i = _world_to_fog(world_pos)
	var fog_range: int = int(ceil(vision_range / CELL_SIZE))
	var offsets: Array = _get_circle_offsets(fog_range)
	var grid: PackedByteArray = _fog[team_id]

	for offset in offsets:
		var fc: Vector2i = fog_center + offset
		if _in_bounds(fc):
			grid[fc.y * FOG_COLS + fc.x] = VISIBLE


func _get_circle_offsets(fog_range: int) -> Array:
	if _circle_cache.has(fog_range):
		return _circle_cache[fog_range]

	var offsets: Array = []
	var range_sq: float = float(fog_range * fog_range)

	for dy in range(-fog_range, fog_range + 1):
		for dx in range(-fog_range, fog_range + 1):
			if float(dx * dx + dy * dy) <= range_sq:
				offsets.append(Vector2i(dx, dy))

	_circle_cache[fog_range] = offsets
	return offsets


func _world_to_fog(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / CELL_SIZE), int(world_pos.y / CELL_SIZE))


func _in_bounds(fc: Vector2i) -> bool:
	return fc.x >= 0 and fc.x < FOG_COLS and fc.y >= 0 and fc.y < FOG_ROWS


func _get_team(faction_id: int) -> int:
	return _faction_team.get(faction_id, faction_id % MAX_TEAMS)
