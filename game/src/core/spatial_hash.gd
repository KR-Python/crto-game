class_name SpatialHash

# Grid-based spatial hash for O(1) range queries.
# CELL_SIZE should be ≥ max query radius for best results.

const CELL_SIZE: float = 64.0  # 2 tiles × 32px

var _cells: Dictionary = {}          # Vector2i → Array[int]
var _entity_cells: Dictionary = {}   # int → Vector2i (current cell per entity)

# -- Mutation ------------------------------------------------------------------

func insert(entity_id: int, position: Vector2) -> void:
	var cell: Vector2i = _world_to_cell(position)
	if not _cells.has(cell):
		_cells[cell] = []
	_cells[cell].append(entity_id)
	_entity_cells[entity_id] = cell


func remove(entity_id: int, position: Vector2) -> void:
	var cell: Vector2i = _world_to_cell(position)
	if _cells.has(cell):
		_cells[cell].erase(entity_id)
		if _cells[cell].is_empty():
			_cells.erase(cell)
	_entity_cells.erase(entity_id)


func update(entity_id: int, old_pos: Vector2, new_pos: Vector2) -> void:
	var old_cell: Vector2i = _world_to_cell(old_pos)
	var new_cell: Vector2i = _world_to_cell(new_pos)
	if old_cell == new_cell:
		return
	# Remove from old
	if _cells.has(old_cell):
		_cells[old_cell].erase(entity_id)
		if _cells[old_cell].is_empty():
			_cells.erase(old_cell)
	# Insert into new
	if not _cells.has(new_cell):
		_cells[new_cell] = []
	_cells[new_cell].append(entity_id)
	_entity_cells[entity_id] = new_cell


func clear() -> void:
	_cells.clear()
	_entity_cells.clear()


func cell_count() -> int:
	return _cells.size()


# -- Queries -------------------------------------------------------------------

func query_radius(center: Vector2, radius: float) -> Array:
	var result: Array = []
	var r_sq: float = radius * radius
	var cells: Array = _cells_in_radius(center, radius)
	for cell in cells:
		if _cells.has(cell):
			for eid in _cells[cell]:
				result.append(eid)
	return result


func query_rect(rect: Rect2) -> Array:
	var result: Array = []
	var min_cell: Vector2i = _world_to_cell(rect.position)
	var max_cell: Vector2i = _world_to_cell(rect.position + rect.size)
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var cell := Vector2i(x, y)
			if _cells.has(cell):
				result.append_array(_cells[cell])
	return result


# -- Internal ------------------------------------------------------------------

func _world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / CELL_SIZE)), int(floor(pos.y / CELL_SIZE)))


func _cells_in_radius(center: Vector2, radius: float) -> Array:
	var min_cell: Vector2i = _world_to_cell(center - Vector2(radius, radius))
	var max_cell: Vector2i = _world_to_cell(center + Vector2(radius, radius))
	var result: Array = []
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			result.append(Vector2i(x, y))
	return result
