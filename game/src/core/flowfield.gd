class_name Flowfield
extends RefCounted

## Flowfield: a 2D grid where each cell stores a direction vector pointing
## toward the goal. Built once per destination via Dijkstra, then shared by
## all units moving to the same area.

var nav_grid: NavGrid
var width: int
var height: int
var goal_cell: Vector2i
var movement_type: int

var _cost_field: PackedFloat32Array
var _flow_vectors: Array  # Array of Vector2, one per cell


func _init(grid: NavGrid) -> void:
	nav_grid = grid
	width = grid.width
	height = grid.height
	_flow_vectors = []


func build(goal_world_pos: Vector2, move_type: int = NavGrid.MOVE_TRACKED) -> void:
	goal_cell = nav_grid.world_to_cell(goal_world_pos)
	movement_type = move_type
	_compute_cost_field()
	_compute_flow_vectors()


func get_direction(world_pos: Vector2) -> Vector2:
	var cell: Vector2i = nav_grid.world_to_cell(world_pos)
	if not nav_grid.is_in_bounds(cell.x, cell.y):
		return Vector2.ZERO
	var idx: int = cell.y * width + cell.x
	return _flow_vectors[idx]


func is_valid() -> bool:
	return _flow_vectors.size() > 0


# -- Private -------------------------------------------------------------------

func _compute_cost_field() -> void:
	var total: int = width * height
	_cost_field = PackedFloat32Array()
	_cost_field.resize(total)
	_cost_field.fill(INF)

	var goal_idx: int = goal_cell.y * width + goal_cell.x
	if goal_idx < 0 or goal_idx >= total:
		return
	_cost_field[goal_idx] = 0.0

	# Simple Dijkstra with sorted open list (adequate for GDScript prototype)
	var open: Array = [[0.0, goal_cell.x, goal_cell.y]]

	while open.size() > 0:
		open.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var current: Array = open.pop_front()
		var cx: int = current[1]
		var cy: int = current[2]
		var c_cost: float = _cost_field[cy * width + cx]

		# Skip stale entries (cost already improved)
		if current[0] > c_cost:
			continue

		for neighbor: Array in _get_neighbors(cx, cy):
			var nx: int = neighbor[0]
			var ny: int = neighbor[1]
			var step_cost: float = neighbor[2]
			if not nav_grid.is_walkable(nx, ny, movement_type):
				continue
			var new_cost: float = c_cost + step_cost
			var n_idx: int = ny * width + nx
			if new_cost < _cost_field[n_idx]:
				_cost_field[n_idx] = new_cost
				open.append([new_cost, nx, ny])


func _compute_flow_vectors() -> void:
	var total: int = width * height
	_flow_vectors.resize(total)
	for y: int in height:
		for x: int in width:
			_flow_vectors[y * width + x] = _best_direction(x, y)


func _best_direction(x: int, y: int) -> Vector2:
	var idx: int = y * width + x
	var best_cost: float = _cost_field[idx]
	if best_cost == INF:
		return Vector2.ZERO  # unreachable cell
	var best_dir: Vector2 = Vector2.ZERO
	for neighbor: Array in _get_neighbors(x, y):
		var n_idx: int = neighbor[1] * width + neighbor[0]
		var n_cost: float = _cost_field[n_idx]
		if n_cost < best_cost:
			best_cost = n_cost
			best_dir = Vector2(neighbor[0] - x, neighbor[1] - y).normalized()
	return best_dir


func _get_neighbors(x: int, y: int) -> Array:
	var result: Array = []
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if nav_grid.is_in_bounds(nx, ny):
				var cost: float = 1.414 if (dx != 0 and dy != 0) else 1.0
				result.append([nx, ny, cost])
	return result
