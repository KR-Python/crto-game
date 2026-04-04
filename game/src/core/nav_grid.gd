class_name NavGrid
extends RefCounted

## Navigation grid wrapping GameMap for pathfinding queries.
## Translates between world coordinates and tile coordinates,
## exposes passability checks by movement type constants.

# Movement type constants (match GameMap passability strings)
const MOVE_FOOT: int = 0
const MOVE_WHEELED: int = 1
const MOVE_TRACKED: int = 2
const MOVE_HOVER: int = 3
const MOVE_FLYING: int = 4

const _MOVE_STRINGS: Array = ["foot", "wheeled", "tracked", "hover", "flying"]

var width: int
var height: int
var tile_size: int

var _game_map: GameMap

## Optional override grid for unit tests (Array of bool, width*height).
## When set, is_walkable ignores _game_map entirely.
var _walkable_override: PackedByteArray = PackedByteArray()

signal nav_grid_changed


func _init(game_map: GameMap = null) -> void:
	if game_map:
		_game_map = game_map
		width = game_map.width
		height = game_map.height
		tile_size = GameMap.TILE_SIZE
	else:
		# Test mode — caller sets width/height/tile_size manually
		width = 0
		height = 0
		tile_size = 64


## Create a simple open grid for testing. All cells walkable.
static func create_open(w: int, h: int, t_size: int = 64) -> NavGrid:
	var grid := NavGrid.new(null)
	grid.width = w
	grid.height = h
	grid.tile_size = t_size
	grid._walkable_override.resize(w * h)
	grid._walkable_override.fill(1)
	return grid


## Mark a cell impassable in the override grid (test helper).
func set_blocked(cx: int, cy: int) -> void:
	if _walkable_override.size() > 0 and is_in_bounds(cx, cy):
		_walkable_override[cy * width + cx] = 0


func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(world_pos.x) / tile_size,
		int(world_pos.y) / tile_size
	)


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * tile_size + tile_size / 2.0,
		cell.y * tile_size + tile_size / 2.0
	)


func is_in_bounds(cx: int, cy: int) -> bool:
	return cx >= 0 and cy >= 0 and cx < width and cy < height


func is_walkable(cx: int, cy: int, move_type: int = MOVE_TRACKED) -> bool:
	if not is_in_bounds(cx, cy):
		return false
	if _walkable_override.size() > 0:
		return _walkable_override[cy * width + cx] != 0
	if _game_map == null:
		return false
	var move_str: String = _MOVE_STRINGS[move_type] if move_type < _MOVE_STRINGS.size() else "tracked"
	return _game_map.is_passable(cx, cy, move_str)


func invalidate() -> void:
	nav_grid_changed.emit()
