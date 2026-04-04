class_name NavGrid
## Navigation grid storing walkability and movement type masks per cell.
## Cell size: 1 tile = 1 cell. Buildings occupy multiple cells (set as impassable).

# Movement type bitmask constants
const MOVE_FOOT: int = 1
const MOVE_WHEELED: int = 2
const MOVE_TRACKED: int = 4
const MOVE_HOVER: int = 8
const MOVE_FLYING: int = 16
const MOVE_ALL: int = 0xFF

# Cell size in world units (1 tile = 1 cell)
const CELL_SIZE: float = 32.0  # 1 tile = 32px

var width: int
var height: int
var _walkable: PackedByteArray        # 1 = walkable, 0 = blocked
var _movement_type_mask: PackedByteArray  # bitmask per cell


func _init(w: int, h: int) -> void:
	width = w
	height = h
	var total: int = w * h
	_walkable = PackedByteArray()
	_walkable.resize(total)
	_walkable.fill(1)  # all walkable by default
	_movement_type_mask = PackedByteArray()
	_movement_type_mask.resize(total)
	_movement_type_mask.fill(MOVE_ALL)


func _index(x: int, y: int) -> int:
	return y * width + x


func is_in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


func set_cell_walkable(x: int, y: int, walkable: bool, movement_types: int = MOVE_ALL) -> void:
	if not is_in_bounds(x, y):
		return
	var idx: int = _index(x, y)
	_walkable[idx] = 1 if walkable else 0
	_movement_type_mask[idx] = movement_types


func is_walkable(x: int, y: int, movement_type: int = MOVE_FOOT) -> bool:
	if not is_in_bounds(x, y):
		return false
	# Flying units ignore terrain — always walkable
	if movement_type == MOVE_FLYING:
		return true
	var idx: int = _index(x, y)
	if _walkable[idx] == 0:
		return false
	return (_movement_type_mask[idx] & movement_type) != 0


func set_rect_blocked(rect: Rect2i, movement_types: int = 0) -> void:
	## Block a rectangular region. movement_types=0 means fully impassable.
	for yy in range(rect.position.y, rect.position.y + rect.size.y):
		for xx in range(rect.position.x, rect.position.x + rect.size.x):
			if is_in_bounds(xx, yy):
				var idx: int = _index(xx, yy)
				if movement_types == 0:
					_walkable[idx] = 0
					_movement_type_mask[idx] = 0
				else:
					_movement_type_mask[idx] = movement_types


func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / CELL_SIZE), int(world_pos.y / CELL_SIZE))


func cell_to_world(cell: Vector2i) -> Vector2:
	## Returns cell center in world coordinates.
	return Vector2(float(cell.x) * CELL_SIZE + CELL_SIZE * 0.5,
			float(cell.y) * CELL_SIZE + CELL_SIZE * 0.5)
