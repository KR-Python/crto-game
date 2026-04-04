class_name GameMap
extends Node2D

const TILE_SIZE: int = 32   # pixels per tile
const DEFAULT_WIDTH: int = 128
const DEFAULT_HEIGHT: int = 96

var width: int = DEFAULT_WIDTH
var height: int = DEFAULT_HEIGHT
var nav_grid: NavGrid       # populated on load

# Tile types — index matches TileSet source IDs
enum TileType { GRASS = 0, WATER = 1, CLIFF = 2, BRIDGE = 3, FORD = 4 }

# Passability matrix: outer = TileType, inner = movement_type bitmask
# movement_type 0 = ground, 1 = water, 2 = air
const PASSABLE_MATRIX: Array[int] = [
	0b111,  # GRASS  — all movement types
	0b110,  # WATER  — water + air only
	0b000,  # CLIFF  — impassable
	0b111,  # BRIDGE — all movement types
	0b111,  # FORD   — all movement types
]

# Flat terrain data (width * height bytes)
var _tile_types: PackedByteArray

@onready var tilemap: TileMapLayer = $TileMapLayer

signal map_loaded(width: int, height: int)


func _ready() -> void:
	# TileMapLayer node must exist in scene tree (added via .tscn)
	_build_placeholder_tileset()
	load_flat_map(DEFAULT_WIDTH, DEFAULT_HEIGHT)


# ── Map Loading ───────────────────────────────────────────────────────────────

## Creates a flat all-grass map for Phase 0 testing.
func load_flat_map(w: int, h: int) -> void:
	width = w
	height = h
	_tile_types = PackedByteArray()
	_tile_types.resize(width * height)
	_tile_types.fill(TileType.GRASS)

	_render_tilemap()
	nav_grid = NavGrid.new(width, height)
	_populate_nav_grid()
	map_loaded.emit(width, height)


## YAML loading is stubbed — implemented in Phase 1.
func load_from_yaml(map_id: String) -> void:
	push_warning("GameMap.load_from_yaml: YAML loading not yet implemented for '%s'" % map_id)
	load_flat_map(DEFAULT_WIDTH, DEFAULT_HEIGHT)


# ── Terrain Queries ───────────────────────────────────────────────────────────

func get_tile_type(cell: Vector2i) -> TileType:
	if not _is_valid_cell(cell):
		return TileType.CLIFF   # out-of-bounds treated as impassable
	return _tile_types[cell.y * width + cell.x] as TileType


## movement_type: 0 = ground, 1 = water, 2 = air
func is_passable(cell: Vector2i, movement_type: int) -> bool:
	var tile: TileType = get_tile_type(cell)
	var mask: int = PASSABLE_MATRIX[tile]
	return (mask >> movement_type) & 1 == 1


## Returns the world-space Rect2 of the map, used for camera bounds clamping.
func get_world_bounds() -> Rect2:
	return Rect2(0, 0, width * TILE_SIZE, height * TILE_SIZE)


# ── Internal Helpers ──────────────────────────────────────────────────────────

func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height


func _render_tilemap() -> void:
	tilemap.clear()
	for y in range(height):
		for x in range(width):
			var tile: int = _tile_types[y * width + x]
			tilemap.set_cell(Vector2i(x, y), tile, Vector2i(0, 0))


func _populate_nav_grid() -> void:
	# Ground movement passability (movement_type = 0)
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			nav_grid.set_cell_walkable(cell.x, cell.y, is_passable(cell, 0))


## Builds a TileSet with solid-color placeholder tiles for each TileType.
## No art required — uses CanvasTexture + AtlasTexture pattern for Phase 0.
func _build_placeholder_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var colors: Array[Color] = [
		Color("#4a7c59"),  # GRASS
		Color("#2d6a9f"),  # WATER
		Color("#8b7355"),  # CLIFF
		Color("#a0856c"),  # BRIDGE
		Color("#6e9b78"),  # FORD (slightly lighter green)
	]

	for i in range(colors.size()):
		var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGB8)
		img.fill(colors[i])
		var tex := ImageTexture.create_from_image(img)

		var source := TileSetAtlasSource.new()
		source.texture = tex
		source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		source.create_tile(Vector2i(0, 0))

		ts.add_source(source, i)   # source_id == TileType enum value

	tilemap.tile_set = ts
