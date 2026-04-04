class_name TestFlowfield
extends RefCounted

## Unit tests for Flowfield and CommandProcessingSystem flowfield integration.
## Run via GUT or manual invocation.

var _results: Array = []


func run_all() -> Array:
	_results.clear()
	test_open_grid_all_valid_directions()
	test_direction_points_toward_goal()
	test_impassable_cells_zero_direction()
	test_goal_cell_zero_direction()
	test_group_above_threshold_uses_flowfield()
	test_cache_returns_same_object()
	return _results


# -- Helpers -------------------------------------------------------------------

func _assert(condition: bool, test_name: String) -> void:
	_results.append({"name": test_name, "passed": condition})
	if not condition:
		push_warning("FAIL: %s" % test_name)


# -- Tests ---------------------------------------------------------------------

## 1. Build flowfield on open grid — all cells have valid directions (except goal)
func test_open_grid_all_valid_directions() -> void:
	var grid: NavGrid = NavGrid.create_open(10, 10, 64)
	var ff: Flowfield = Flowfield.new(grid)
	ff.build(Vector2(5 * 64 + 32, 5 * 64 + 32))  # goal at cell (5,5)

	var all_valid: bool = true
	for y: int in 10:
		for x: int in 10:
			if x == 5 and y == 5:
				continue  # goal cell — zero is OK
			var dir: Vector2 = ff.get_direction(Vector2(x * 64 + 32, y * 64 + 32))
			if dir == Vector2.ZERO:
				all_valid = false
				break
		if not all_valid:
			break
	_assert(all_valid, "open_grid_all_valid_directions")


## 2. Direction points toward goal from several sample positions
func test_direction_points_toward_goal() -> void:
	var grid: NavGrid = NavGrid.create_open(10, 10, 64)
	var ff: Flowfield = Flowfield.new(grid)
	ff.build(Vector2(5 * 64 + 32, 5 * 64 + 32))  # goal at (5,5)

	# From (0,5) — should point rightward (positive x)
	var dir_right: Vector2 = ff.get_direction(Vector2(0 * 64 + 32, 5 * 64 + 32))
	var right_ok: bool = dir_right.x > 0.0

	# From (5,0) — should point downward (positive y)
	var dir_down: Vector2 = ff.get_direction(Vector2(5 * 64 + 32, 0 * 64 + 32))
	var down_ok: bool = dir_down.y > 0.0

	# From (9,9) — should point toward goal (negative x and y)
	var dir_diag: Vector2 = ff.get_direction(Vector2(9 * 64 + 32, 9 * 64 + 32))
	var diag_ok: bool = dir_diag.x < 0.0 and dir_diag.y < 0.0

	_assert(right_ok and down_ok and diag_ok, "direction_points_toward_goal")


## 3. Impassable cells have zero direction
func test_impassable_cells_zero_direction() -> void:
	var grid: NavGrid = NavGrid.create_open(10, 10, 64)
	grid.set_blocked(3, 3)
	var ff: Flowfield = Flowfield.new(grid)
	ff.build(Vector2(5 * 64 + 32, 5 * 64 + 32))

	var dir: Vector2 = ff.get_direction(Vector2(3 * 64 + 32, 3 * 64 + 32))
	_assert(dir == Vector2.ZERO, "impassable_cells_zero_direction")


## 4. Goal cell has zero direction (already there)
func test_goal_cell_zero_direction() -> void:
	var grid: NavGrid = NavGrid.create_open(10, 10, 64)
	var ff: Flowfield = Flowfield.new(grid)
	ff.build(Vector2(5 * 64 + 32, 5 * 64 + 32))

	var dir: Vector2 = ff.get_direction(Vector2(5 * 64 + 32, 5 * 64 + 32))
	_assert(dir == Vector2.ZERO, "goal_cell_zero_direction")


## 5. Group of 6 units to same destination uses flowfield (not individual A*)
func test_group_above_threshold_uses_flowfield() -> void:
	var grid: NavGrid = NavGrid.create_open(20, 20, 64)
	var system: CommandProcessingSystem = CommandProcessingSystem.new(grid)

	# Build a mock ECS that returns 6 units targeting the same destination
	var mock_ecs: MockECS = MockECS.new()
	for i: int in 6:
		mock_ecs.add_unit(i, Vector2((i + 1) * 64 + 32, 5 * 64 + 32), Vector2(15 * 64 + 32, 15 * 64 + 32))

	var directions: Dictionary = system.process_move_commands(mock_ecs, 0)

	# All 6 units should get a direction
	var all_have_dirs: bool = directions.size() == 6
	# A flowfield should have been cached
	var dest_cell: Vector2i = grid.world_to_cell(Vector2(15 * 64 + 32, 15 * 64 + 32))
	var cache_key: String = "%d,%d" % [dest_cell.x, dest_cell.y]
	var cached: bool = system._flowfield_cache.has(cache_key)

	_assert(all_have_dirs and cached, "group_above_threshold_uses_flowfield")


## 6. Cache hit: same destination → same flowfield object returned
func test_cache_returns_same_object() -> void:
	var grid: NavGrid = NavGrid.create_open(10, 10, 64)
	var system: CommandProcessingSystem = CommandProcessingSystem.new(grid)

	var dest: Vector2 = Vector2(5 * 64 + 32, 5 * 64 + 32)
	var ff1: Flowfield = system.get_or_build_flowfield(dest)
	var ff2: Flowfield = system.get_or_build_flowfield(dest)

	_assert(ff1 == ff2, "cache_returns_same_object")


# -- Mock ECS ------------------------------------------------------------------

class MockECS:
	extends RefCounted

	var _units: Array = []

	func add_unit(eid: int, pos: Vector2, dest: Vector2) -> void:
		_units.append({"entity_id": eid, "position": pos, "destination": dest})

	func get_entities_with_move_command() -> Array:
		return _units
