extends GutTest
## Tests for ScriptedAI — verifies build order execution, attack timing, and army tracking.


# --- Test helpers ---

var _ai: ScriptedAI
var _commands: Array[Dictionary]


class MockECS:
	var entities_with_components: Dictionary = {}
	var component_data: Dictionary = {}

	func get_entities_with_components(components: Array) -> Array:
		var key: String = ",".join(components)
		return entities_with_components.get(key, [])

	func get_component(entity_id: int, component_name: String) -> Dictionary:
		var key: String = "%d:%s" % [entity_id, component_name]
		return component_data.get(key, {})


class MockCommandQueue:
	var commands: Array[Dictionary] = []

	func enqueue(cmd: Dictionary) -> void:
		commands.append(cmd)


func before_each() -> void:
	_ai = ScriptedAI.new()
	var mock_queue := MockCommandQueue.new()
	_ai.command_queue = mock_queue
	_ai.initialize(1, Vector2(1000, 1000))
	_commands = mock_queue.commands

	# Set up mock ECS with a base structure
	var mock_ecs := MockECS.new()
	mock_ecs.entities_with_components["FactionComponent,Structure"] = [100]
	mock_ecs.component_data["100:FactionComponent"] = {"faction_id": 1}
	mock_ecs.component_data["100:Position"] = {"x": 500.0, "y": 500.0}
	# Production building for queue_production orders
	mock_ecs.entities_with_components["FactionComponent,ProductionQueue"] = [101, 102, 103]
	mock_ecs.component_data["101:FactionComponent"] = {"faction_id": 1}
	mock_ecs.component_data["102:FactionComponent"] = {"faction_id": 1}
	mock_ecs.component_data["103:FactionComponent"] = {"faction_id": 1}
	# No army initially
	mock_ecs.entities_with_components["FactionComponent,MoveSpeed,Weapon"] = []
	_ai.ecs = mock_ecs


# --- Tests ---


func test_build_order_tick_zero_places_barracks() -> void:
	_ai.tick(_ai.ecs, 0)
	assert_eq(_commands.size(), 1, "Tick 0 should issue exactly one command")
	assert_eq(_commands[0]["action"], "PlaceStructure")
	assert_eq(_commands[0]["params"]["structure_type"], "barracks")


func test_no_commands_before_tick_zero() -> void:
	# Tick -1 should produce nothing (all orders have tick >= 0)
	_ai.tick(_ai.ecs, -1)
	assert_eq(_commands.size(), 0, "No commands should be issued before tick 0")


func test_attack_issued_at_tick_600() -> void:
	# Add army units to the mock ECS
	var mock_ecs: MockECS = _ai.ecs
	mock_ecs.entities_with_components["FactionComponent,MoveSpeed,Weapon"] = [200, 201]
	mock_ecs.component_data["200:FactionComponent"] = {"faction_id": 1}
	mock_ecs.component_data["201:FactionComponent"] = {"faction_id": 1}

	# Run up to tick 600 — processes all orders up to and including the attack
	_ai.tick(mock_ecs, 600)

	# Find MoveUnits commands (the attack wave)
	var move_cmds: Array[Dictionary] = []
	for cmd in _commands:
		if cmd["action"] == "MoveUnits":
			move_cmds.append(cmd)

	assert_gt(move_cmds.size(), 0, "Attack wave should issue MoveUnits commands at tick 600")
	assert_eq(move_cmds[0]["params"]["destination"], Vector2(1000, 1000),
		"Attack should target the enemy base position")


func test_army_list_updates_with_spawned_units() -> void:
	assert_eq(_ai.army_entities.size(), 0, "Army should start empty")

	# Simulate units spawning
	var mock_ecs: MockECS = _ai.ecs
	mock_ecs.entities_with_components["FactionComponent,MoveSpeed,Weapon"] = [200, 201, 202]
	mock_ecs.component_data["200:FactionComponent"] = {"faction_id": 1}
	mock_ecs.component_data["201:FactionComponent"] = {"faction_id": 1}
	mock_ecs.component_data["202:FactionComponent"] = {"faction_id": 1}

	_ai.tick(mock_ecs, 0)

	assert_eq(_ai.army_entities.size(), 3, "Army list should contain 3 units after tick")


func test_build_order_completes_in_sequence() -> void:
	# Add army so attack waves have something to command
	var mock_ecs: MockECS = _ai.ecs
	mock_ecs.entities_with_components["FactionComponent,MoveSpeed,Weapon"] = [200]
	mock_ecs.component_data["200:FactionComponent"] = {"faction_id": 1}

	# Run past all build order ticks
	_ai.tick(mock_ecs, 1000)

	assert_eq(_ai.build_order_index, ScriptedAI.BUILD_ORDER.size(),
		"All build orders should be processed by tick 1000")

	# Verify we got a mix of command types
	var action_set: Dictionary = {}
	for cmd in _commands:
		action_set[cmd["action"]] = true

	assert_true(action_set.has("PlaceStructure"), "Should have PlaceStructure commands")
	assert_true(action_set.has("QueueProduction"), "Should have QueueProduction commands")
	assert_true(action_set.has("MoveUnits"), "Should have MoveUnits commands (attack waves)")
