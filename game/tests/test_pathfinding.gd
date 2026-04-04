class_name TestPathfinding
## Tests for NavGrid and Pathfinder.


static func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var errors: Array = []

	# --- Test 1: Simple diagonal path on open grid ---
	var grid: NavGrid = NavGrid.new(20, 20)
	var pf: Pathfinder = Pathfinder.new(grid)
	var path: Array[Vector2] = pf.find_path(Vector2(0.5, 0.5), Vector2(10.5, 10.5))
	if path.size() >= 2 and path[path.size() - 1].is_equal_approx(grid.cell_to_world(Vector2i(10, 10))):
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 FAIL: simple diagonal path — got %d points" % path.size())

	# --- Test 2: Path around obstacle ---
	grid = NavGrid.new(20, 20)
	# Wall from (5,0) to (5,9) blocking direct route
	for yy in range(10):
		grid.set_cell_walkable(5, yy, false)
	pf = Pathfinder.new(grid)
	path = pf.find_path(Vector2(0.5, 0.5), Vector2(10.5, 0.5))
	if path.size() >= 2 and path[path.size() - 1].is_equal_approx(grid.cell_to_world(Vector2i(10, 0))):
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 FAIL: path around obstacle — got %d points" % path.size())

	# --- Test 3: No path — blocked destination ---
	grid = NavGrid.new(10, 10)
	# Surround cell (5,5)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx != 0 or dy != 0:
				grid.set_cell_walkable(5 + dx, 5 + dy, false)
	grid.set_cell_walkable(5, 5, false)
	pf = Pathfinder.new(grid)
	path = pf.find_path(Vector2(0.5, 0.5), Vector2(5.5, 5.5))
	if path.size() == 0:
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 FAIL: expected empty path for blocked dest, got %d" % path.size())

	# --- Test 4: Movement type — wheeled can't cross foot-only ford ---
	grid = NavGrid.new(20, 20)
	# Row 5 is foot-only
	for xx in range(20):
		grid.set_cell_walkable(xx, 5, true, NavGrid.MOVE_FOOT)
	pf = Pathfinder.new(grid)
	# Foot unit should pass
	var foot_path: Array[Vector2] = pf.find_path(Vector2(0.5, 0.5), Vector2(0.5, 9.5), NavGrid.MOVE_FOOT)
	# Wheeled should fail (row 5 blocks, and we need to make rows 4/6 also relevant)
	# Actually wheeled can go around — let's make a full wall of foot-only across the grid
	grid = NavGrid.new(20, 20)
	for xx in range(20):
		grid.set_cell_walkable(xx, 5, true, NavGrid.MOVE_FOOT)
		# Also block diagonals around row 5
		grid.set_cell_walkable(xx, 4, true, NavGrid.MOVE_FOOT)
		grid.set_cell_walkable(xx, 6, true, NavGrid.MOVE_FOOT)
	pf = Pathfinder.new(grid)
	foot_path = pf.find_path(Vector2(0.5, 0.5), Vector2(0.5, 9.5), NavGrid.MOVE_FOOT)
	var wheeled_path: Array[Vector2] = pf.find_path(Vector2(0.5, 0.5), Vector2(0.5, 9.5), NavGrid.MOVE_WHEELED)
	if foot_path.size() > 0 and wheeled_path.size() == 0:
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 FAIL: foot=%d wheeled=%d (expected foot>0, wheeled=0)" % [foot_path.size(), wheeled_path.size()])

	# --- Test 5: Flying unit ignores terrain ---
	grid = NavGrid.new(20, 20)
	# Block everything except start and end
	for yy in range(20):
		for xx in range(20):
			grid.set_cell_walkable(xx, yy, false)
	pf = Pathfinder.new(grid)
	var fly_path: Array[Vector2] = pf.find_path(Vector2(0.5, 0.5), Vector2(10.5, 10.5), NavGrid.MOVE_FLYING)
	if fly_path.size() >= 2:
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 FAIL: flying path — got %d points" % fly_path.size())

	# --- Test 6: Performance — 50 paths on 128x96 grid ---
	grid = NavGrid.new(128, 96)
	pf = Pathfinder.new(grid)
	var start_time: int = Time.get_ticks_msec()
	for i in range(50):
		pf.find_path(
			Vector2(float(i % 10) + 0.5, 0.5),
			Vector2(120.5, 90.5)
		)
	var elapsed: int = Time.get_ticks_msec() - start_time
	if elapsed < 100:
		passed += 1
	else:
		failed += 1
		errors.append("Test 6 FAIL: 50 paths took %dms (limit 100ms)" % elapsed)

	# --- Test 7: Cache hit — second call faster ---
	grid = NavGrid.new(128, 96)
	pf = Pathfinder.new(grid)
	start_time = Time.get_ticks_msec()
	pf.find_path(Vector2(0.5, 0.5), Vector2(100.5, 80.5))
	var first_time: int = Time.get_ticks_msec() - start_time
	start_time = Time.get_ticks_msec()
	pf.find_path(Vector2(0.5, 0.5), Vector2(100.5, 80.5))
	var second_time: int = Time.get_ticks_msec() - start_time
	# Cache hit should be near-instant (0ms or 1ms at most)
	if second_time <= first_time:
		passed += 1
	else:
		failed += 1
		errors.append("Test 7 FAIL: cache miss — first=%dms second=%dms" % [first_time, second_time])

	# --- Test 8: Cache invalidation ---
	grid = NavGrid.new(20, 20)
	pf = Pathfinder.new(grid)
	var path_before: Array[Vector2] = pf.find_path(Vector2(0.5, 0.5), Vector2(10.5, 0.5))
	# Place building blocking the path
	grid.set_rect_blocked(Rect2i(5, 0, 1, 5))
	pf.invalidate_region(Rect2i(5, 0, 1, 5))
	var path_after: Array[Vector2] = pf.find_path(Vector2(0.5, 0.5), Vector2(10.5, 0.5))
	# Path should be different (longer, going around)
	if path_after.size() > 0 and path_after.size() != path_before.size():
		passed += 1
	else:
		failed += 1
		errors.append("Test 8 FAIL: cache invalidation — before=%d after=%d" % [path_before.size(), path_after.size()])

	return {"passed": passed, "failed": failed, "errors": errors}
