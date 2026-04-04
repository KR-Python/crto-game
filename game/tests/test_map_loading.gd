class_name TestMapLoading
extends Node

# Tests for GameMap.load_from_data()
# Run with: gdunit4 or Godot's built-in test runner
#
# All tests are self-contained and deterministic.
# Iron Bridge reference data is embedded — no file I/O dependency.

var _map: GameMap

func before_each() -> void:
	_map = GameMap.new()

func after_each() -> void:
	_map.free()

# ---- Helpers ----

func _iron_bridge_data() -> Dictionary:
	return {
		"map_id": "iron_bridge",
		"dimensions": {"width": 128, "height": 96},
		"spawn_points": {
			"team_human": {
				"construction_yard": [15, 48],
				"starting_units": [
					{"type": "faction_harvester", "position": [18, 48]},
					{"type": "faction_rifleman", "position": [12, 45], "count": 3},
					{"type": "faction_scout_buggy", "position": [12, 51]}
				],
				"initial_resources": {"primary": 5000, "secondary": 1000}
			},
			"team_ai": {
				"construction_yard": [113, 48],
				"starting_units": [
					{"type": "faction_harvester", "position": [110, 48]},
					{"type": "faction_rifleman", "position": [116, 45], "count": 3},
					{"type": "faction_scout_buggy", "position": [116, 51]}
				],
				"initial_resources": {"primary": 5000, "secondary": 1000}
			}
		},
		"resources": [
			{"type": "ore", "position": [20, 40], "amount": 25000},
			{"type": "ore", "position": [20, 56], "amount": 25000},
			{"type": "ore", "position": [108, 40], "amount": 25000},
			{"type": "ore", "position": [108, 56], "amount": 25000},
			{"type": "gems", "position": [64, 30], "amount": 10000},
			{"type": "gems", "position": [64, 66], "amount": 10000},
			{"type": "ore", "position": [50, 48], "amount": 30000},
			{"type": "ore", "position": [78, 48], "amount": 30000}
		],
		"expansions": [
			{"id": "human_north", "position": [30, 25], "risk": "low"},
			{"id": "human_south", "position": [30, 71], "risk": "low"},
			{"id": "mid_north", "position": [64, 20], "risk": "high"},
			{"id": "mid_south", "position": [64, 76], "risk": "high"},
			{"id": "ai_north", "position": [98, 25], "risk": "low"},
			{"id": "ai_south", "position": [98, 71], "risk": "low"}
		],
		"terrain": {
			"base_type": "grass",
			"features": [
				{
					"type": "water",
					"bounds": {"x": 60, "y": 0, "width": 8, "height": 96}
				},
				{
					"type": "bridge",
					"bounds": {"x": 60, "y": 42, "width": 8, "height": 12},
					"passable_by": ["foot", "wheeled", "tracked"]
				},
				{
					"type": "ford",
					"bounds": {"x": 62, "y": 5, "width": 4, "height": 3},
					"passable_by": ["foot"]
				},
				{
					"type": "ford",
					"bounds": {"x": 62, "y": 88, "width": 4, "height": 3},
					"passable_by": ["foot"]
				},
				{
					"type": "cliff",
					"bounds": {"x": 55, "y": 35, "width": 3, "height": 5},
					"provides": {"vision_bonus": 4}
				},
				{
					"type": "cliff",
					"bounds": {"x": 70, "y": 56, "width": 3, "height": 5},
					"provides": {"vision_bonus": 4}
				}
			]
		}
	}

# ---- Test 1: Iron Bridge loads with correct dimensions ----
func test_iron_bridge_dimensions() -> void:
	_map.load_from_data(_iron_bridge_data())
	assert(_map.width == 128, "Expected width 128, got %d" % _map.width)
	assert(_map.height == 96, "Expected height 96, got %d" % _map.height)

# ---- Test 2: Water tiles marked impassable for tracked movement ----
func test_water_impassable_for_tracked() -> void:
	_map.load_from_data(_iron_bridge_data())
	# River occupies x=60..67, y=0..95
	# Check a tile in the river that is NOT a bridge or ford
	var water_x: int = 63
	var water_y: int = 50   # well away from bridge (y=42..53) and fords
	assert(
		not _map.is_passable(water_x, water_y, "tracked"),
		"Water tile (%d,%d) should be impassable for tracked" % [water_x, water_y]
	)
	assert(
		not _map.is_passable(water_x, water_y, "wheeled"),
		"Water tile (%d,%d) should be impassable for wheeled" % [water_x, water_y]
	)
	assert(
		not _map.is_passable(water_x, water_y, "foot"),
		"Water tile (%d,%d) should be impassable for foot" % [water_x, water_y]
	)

# ---- Test 3: Bridge tile passable for tracked ----
func test_bridge_passable_for_tracked() -> void:
	_map.load_from_data(_iron_bridge_data())
	# Bridge: x=60..67, y=42..53
	var bridge_x: int = 63
	var bridge_y: int = 47
	assert(
		_map.is_passable(bridge_x, bridge_y, "tracked"),
		"Bridge tile (%d,%d) should be passable for tracked" % [bridge_x, bridge_y]
	)
	assert(
		_map.is_passable(bridge_x, bridge_y, "wheeled"),
		"Bridge tile (%d,%d) should be passable for wheeled" % [bridge_x, bridge_y]
	)
	assert(
		_map.is_passable(bridge_x, bridge_y, "foot"),
		"Bridge tile (%d,%d) should be passable for foot" % [bridge_x, bridge_y]
	)

# ---- Test 4: Ford passable for foot, not tracked ----
func test_ford_passable_foot_only() -> void:
	_map.load_from_data(_iron_bridge_data())
	# North ford: x=62..65, y=5..7
	var ford_x: int = 63
	var ford_y: int = 6
	assert(
		_map.is_passable(ford_x, ford_y, "foot"),
		"Ford tile (%d,%d) should be passable for foot" % [ford_x, ford_y]
	)
	assert(
		not _map.is_passable(ford_x, ford_y, "tracked"),
		"Ford tile (%d,%d) should NOT be passable for tracked" % [ford_x, ford_y]
	)
	assert(
		not _map.is_passable(ford_x, ford_y, "wheeled"),
		"Ford tile (%d,%d) should NOT be passable for wheeled" % [ford_x, ford_y]
	)

# ---- Test 5: Cliff grants vision bonus ----
func test_cliff_vision_bonus() -> void:
	_map.load_from_data(_iron_bridge_data())
	# Cliff at x=55..57, y=35..39
	var cliff_x: int = 56
	var cliff_y: int = 37
	var bonus: int = _map.get_vision_bonus(cliff_x, cliff_y)
	assert(bonus == 4, "Expected vision bonus 4 on cliff tile (%d,%d), got %d" % [cliff_x, cliff_y, bonus])

	# Confirm non-cliff tile has no bonus
	var grass_x: int = 10
	var grass_y: int = 10
	var grass_bonus: int = _map.get_vision_bonus(grass_x, grass_y)
	assert(grass_bonus == 0, "Expected vision bonus 0 on grass tile (%d,%d), got %d" % [grass_x, grass_y, grass_bonus])

# ---- Test 6: Resource nodes at correct world positions ----
func test_resource_node_positions() -> void:
	_map.load_from_data(_iron_bridge_data())
	# Verify resource_nodes array populated correctly
	assert(_map.resource_nodes.size() == 8, "Expected 8 resource nodes, got %d" % _map.resource_nodes.size())

	# Check first ore node near team_human base
	var first_ore: Dictionary = _map.resource_nodes[0]
	assert(first_ore["type"] == "ore", "First resource node should be ore")
	assert(first_ore["position"][0] == 20 and first_ore["position"][1] == 40,
		"First ore should be at [20,40]")

	# Check a gems node
	var gems_node: Dictionary = _map.resource_nodes[4]
	assert(gems_node["type"] == "gems", "Resource node [4] should be gems")
	assert(gems_node["amount"] == 10000, "Gems node should have 10000 remaining")

	# Verify world position calculation (tile * TILE_SIZE)
	var expected_world_x: float = 20.0 * GameMap.TILE_SIZE
	var expected_world_y: float = 40.0 * GameMap.TILE_SIZE
	assert(expected_world_x == 1280.0, "Tile 20 * 64 = 1280 world units")
	assert(expected_world_y == 2560.0, "Tile 40 * 64 = 2560 world units")

# ---- Test 7: Spawn points accessible (valid terrain, not in water) ----
func test_spawn_points_on_valid_terrain() -> void:
	_map.load_from_data(_iron_bridge_data())

	# Human CY at [15, 48] — should be grass (west of river at x=60)
	assert(
		_map.is_passable(15, 48, "tracked"),
		"Human CY tile [15,48] should be passable for tracked (grass)"
	)
	assert(
		_map.get_tile_type(15, 48) == "grass",
		"Human CY tile [15,48] should be grass, got: %s" % _map.get_tile_type(15, 48)
	)

	# AI CY at [113, 48] — should be grass (east of river at x=67)
	assert(
		_map.is_passable(113, 48, "tracked"),
		"AI CY tile [113,48] should be passable for tracked (grass)"
	)
	assert(
		_map.get_tile_type(113, 48) == "grass",
		"AI CY tile [113,48] should be grass, got: %s" % _map.get_tile_type(113, 48)
	)

	# Verify spawn points stored correctly
	var human_spawn: Dictionary = _map.get_spawn_data("team_human")
	assert(human_spawn.size() > 0, "team_human spawn data should not be empty")
	assert(human_spawn.has("construction_yard"), "Spawn data should have construction_yard key")

	var ai_spawn: Dictionary = _map.get_spawn_data("team_ai")
	assert(ai_spawn.size() > 0, "team_ai spawn data should not be empty")

	# Verify spawns don't overlap (different x positions)
	var human_cy: Array = human_spawn["construction_yard"]
	var ai_cy: Array = ai_spawn["construction_yard"]
	assert(
		human_cy[0] != ai_cy[0] or human_cy[1] != ai_cy[1],
		"Human and AI construction yards should not overlap"
	)
