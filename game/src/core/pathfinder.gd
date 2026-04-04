class_name Pathfinder
## A* pathfinder operating on a NavGrid.
## 8-directional movement, octile heuristic, path smoothing, simple cache.

const SQRT2: float = 1.41421356
const MAX_NODES: int = 512
const CACHE_LIMIT: int = 256

# 8-directional neighbor offsets: cardinal + diagonal
const _DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]
const _COSTS: Array[float] = [1.0, 1.0, 1.0, 1.0, SQRT2, SQRT2, SQRT2, SQRT2]

var nav_grid: NavGrid
var _cache: Dictionary = {}  # cache_key -> Array[Vector2]
var _cache_keys: Array = []  # insertion order for LRU-like eviction


func _init(grid: NavGrid) -> void:
	nav_grid = grid


func _octile_heuristic(a: Vector2i, b: Vector2i) -> float:
	var dx: int = absi(a.x - b.x)
	var dy: int = absi(a.y - b.y)
	if dx < dy:
		return SQRT2 * dx + (dy - dx)
	return SQRT2 * dy + (dx - dy)


func _make_cache_key(start_cell: Vector2i, end_cell: Vector2i, movement_type: int) -> int:
	# Pack into a single int: x values 0-65535, y values 0-65535
	return start_cell.x + start_cell.y * 65536 + end_cell.x * 65536 * 65536 + movement_type * 17


func find_path(start: Vector2, end: Vector2, movement_type: int = NavGrid.MOVE_FOOT) -> Array[Vector2]:
	var start_cell: Vector2i = nav_grid.world_to_cell(start)
	var end_cell: Vector2i = nav_grid.world_to_cell(end)

	if not nav_grid.is_in_bounds(start_cell.x, start_cell.y):
		return []
	if not nav_grid.is_in_bounds(end_cell.x, end_cell.y):
		return []
	if not nav_grid.is_walkable(end_cell.x, end_cell.y, movement_type):
		return []

	if start_cell == end_cell:
		var result: Array[Vector2] = []
		result.append(nav_grid.cell_to_world(end_cell))
		return result

	# Check cache
	var cache_key: int = _make_cache_key(start_cell, end_cell, movement_type)
	if _cache.has(cache_key):
		return _cache[cache_key].duplicate()

	var path: Array[Vector2] = _astar(start_cell, end_cell, movement_type)

	# Cache result
	if path.size() > 0:
		if _cache_keys.size() >= CACHE_LIMIT:
			_cache.clear()
			_cache_keys.clear()
		_cache[cache_key] = path.duplicate()
		_cache_keys.append(cache_key)

	return path


func _astar(start_cell: Vector2i, end_cell: Vector2i, movement_type: int) -> Array[Vector2]:
	# Open set as array-based binary heap: [f_score, g_score, cell_x, cell_y]
	# Using Dictionary for came_from and g_score lookup
	var g_score: Dictionary = {}
	var came_from: Dictionary = {}
	var closed: Dictionary = {}

	var start_key: int = start_cell.x + start_cell.y * 65536
	g_score[start_key] = 0.0
	var h: float = _octile_heuristic(start_cell, end_cell)

	# Simple priority queue using sorted insert (adequate for GDScript perf)
	# Each entry: [f, g, x, y]
	var open: Array = [[h, 0.0, start_cell.x, start_cell.y]]
	var nodes_visited: int = 0

	while open.size() > 0:
		# Pop lowest f-score (front of sorted array)
		var current: Array = open.pop_front()
		var cx: int = current[2]
		var cy: int = current[3]
		var cg: float = current[1]
		var c_key: int = cx + cy * 65536

		if closed.has(c_key):
			continue
		closed[c_key] = true

		nodes_visited += 1
		if nodes_visited > MAX_NODES:
			return []

		if cx == end_cell.x and cy == end_cell.y:
			return _reconstruct_path(came_from, end_cell)

		for i in range(8):
			var nx: int = cx + _DIRS[i].x
			var ny: int = cy + _DIRS[i].y
			var n_key: int = nx + ny * 65536

			if closed.has(n_key):
				continue
			if not nav_grid.is_walkable(nx, ny, movement_type):
				continue

			# Diagonal: check both cardinal neighbors to prevent corner-cutting
			if i >= 4:
				if not nav_grid.is_walkable(cx + _DIRS[i].x, cy, movement_type):
					continue
				if not nav_grid.is_walkable(cx, cy + _DIRS[i].y, movement_type):
					continue

			var tentative_g: float = cg + _COSTS[i]
			if g_score.has(n_key) and tentative_g >= g_score[n_key]:
				continue

			g_score[n_key] = tentative_g
			came_from[n_key] = c_key
			var f: float = tentative_g + _octile_heuristic(Vector2i(nx, ny), end_cell)

			# Binary search insert to keep open sorted by f
			var idx: int = _bisect_insert_idx(open, f)
			open.insert(idx, [f, tentative_g, nx, ny])

	return []


func _bisect_insert_idx(arr: Array, f: float) -> int:
	var lo: int = 0
	var hi: int = arr.size()
	while lo < hi:
		var mid: int = (lo + hi) >> 1
		if arr[mid][0] < f:
			lo = mid + 1
		else:
			hi = mid
	return lo


func _reconstruct_path(came_from: Dictionary, end_cell: Vector2i) -> Array[Vector2]:
	var cells: Array[Vector2i] = []
	var key: int = end_cell.x + end_cell.y * 65536
	while came_from.has(key):
		var cx: int = key % 65536
		var cy: int = key / 65536
		cells.append(Vector2i(cx, cy))
		key = came_from[key]
	# Add start
	var sx: int = key % 65536
	var sy: int = key / 65536
	cells.append(Vector2i(sx, sy))
	cells.reverse()

	# Path smoothing: remove collinear intermediate points
	cells = _smooth_path(cells)

	# Convert to world positions
	var result: Array[Vector2] = []
	for cell in cells:
		result.append(nav_grid.cell_to_world(cell))
	return result


func _smooth_path(cells: Array[Vector2i]) -> Array[Vector2i]:
	if cells.size() <= 2:
		return cells
	var smoothed: Array[Vector2i] = [cells[0]]
	for i in range(1, cells.size() - 1):
		var prev: Vector2i = smoothed[smoothed.size() - 1]
		var curr: Vector2i = cells[i]
		var next: Vector2i = cells[i + 1]
		var dx1: int = curr.x - prev.x
		var dy1: int = curr.y - prev.y
		var dx2: int = next.x - curr.x
		var dy2: int = next.y - curr.y
		# Keep point if direction changes
		if dx1 != dx2 or dy1 != dy2:
			smoothed.append(curr)
	smoothed.append(cells[cells.size() - 1])
	return smoothed


func find_paths_batch(starts: Array[Vector2], end: Vector2, movement_type: int = NavGrid.MOVE_FOOT) -> Array:
	## Find paths for multiple units to the same destination.
	var results: Array = []
	for s in starts:
		results.append(find_path(s, end, movement_type))
	return results


func is_reachable(start: Vector2, end: Vector2, movement_type: int = NavGrid.MOVE_FOOT) -> bool:
	return find_path(start, end, movement_type).size() > 0


func invalidate_region(rect: Rect2i) -> void:
	## Clear all cached paths that might pass through the given region.
	## Simple approach: clear entire cache (correct, fast enough for now).
	_cache.clear()
	_cache_keys.clear()
