extends Node
## Tests for CommanderAI and SpecOpsAI partner controllers.
## Run via GUT test framework.


func test_build_order_executes_at_correct_tick() -> void:
	var cmd := CommanderAI.new()
	cmd.initialize_base(Vector2(100, 100), 0)

	# Tick 0 — first build order item (power_plant at tick_offset 0)
	cmd._ai_tick(0)
	var cmds: Array = cmd.consume_commands()
	assert(cmds.size() >= 1, "Should emit at least 1 command at tick 0")
	assert(cmds[0]["params"]["structure_type"] == "power_plant",
		"First build should be power_plant")

	# Tick 30 — barracks (tick_offset 30, elapsed 30)
	cmd._ai_tick(30)
	cmds = cmd.consume_commands()
	assert(cmds.size() >= 1, "Should emit barracks at tick 30")
	assert(cmds[0]["params"]["structure_type"] == "barracks",
		"Second build should be barracks")

	# Tick 60 — not yet time for refinery (tick_offset 75)
	cmd._ai_tick(60)
	cmds = cmd.consume_commands()
	assert(cmds.size() == 0, "No build at tick 60 — refinery not due until 75")


func test_commander_responds_to_build_here_ping() -> void:
	var cmd := CommanderAI.new()
	cmd.initialize_base(Vector2(100, 100), 0)
	cmd.recent_pings = [{"type": "build_here", "position": Vector2(200, 200), "tick": 0}]

	cmd._ai_tick(0)
	var cmds: Array = cmd.consume_commands()

	var turret_found := false
	for c in cmds:
		if c["params"].get("structure_type") == "turret":
			assert(c["params"]["position"] == Vector2(200, 200),
				"Turret should be at pinged position")
			turret_found = true
	assert(turret_found, "Should place turret in response to build_here ping")


func test_commander_responds_to_expand_ping() -> void:
	var cmd := CommanderAI.new()
	cmd.initialize_base(Vector2(100, 100), 0)
	cmd.recent_pings = [{"type": "expand", "position": Vector2(500, 500), "tick": 0}]

	cmd._ai_tick(0)
	var cmds: Array = cmd.consume_commands()

	var refinery_found := false
	for c in cmds:
		if c["params"].get("structure_type") == "refinery" and c["params"]["position"] == Vector2(500, 500):
			refinery_found = true
	assert(refinery_found, "Should place refinery in response to expand ping")


func test_power_management_queues_power_plant() -> void:
	var cmd := CommanderAI.new()
	cmd.initialize_base(Vector2(100, 100), 0)
	cmd.set_power_net(-10.0)

	cmd._ai_tick(0)
	var cmds: Array = cmd.consume_commands()

	var power_plant_found := false
	for c in cmds:
		if c["type"] == "PlaceStructure" and c["params"]["structure_type"] == "power_plant":
			power_plant_found = true
	assert(power_plant_found, "Should queue power plant when power net is negative")


func test_build_order_is_idempotent() -> void:
	var cmd := CommanderAI.new()
	cmd.initialize_base(Vector2(100, 100), 0)

	# Pre-mark power_plant as already built
	cmd._built_structures = ["power_plant"]

	cmd._ai_tick(0)
	var cmds: Array = cmd.consume_commands()

	for c in cmds:
		if c["type"] == "PlaceStructure":
			assert(c["params"]["structure_type"] != "power_plant",
				"Should not re-build power_plant already in built list")


func test_spec_ops_sends_scout() -> void:
	var so := SpecOpsAI.new()
	so.set_available_units(["scout_1", "scout_2"])

	so._ai_tick(0)
	var cmds: Array = so.consume_commands()

	var scout_found := false
	for c in cmds:
		if c["type"] == "Scout":
			scout_found = true
	assert(scout_found, "Spec Ops should send at least 1 scout when units available")


func test_status_rate_limiting() -> void:
	var cmd := CommanderAI.new()
	cmd.initialize_base(Vector2(100, 100), 0)

	# First status at tick 0
	cmd.send_status("Test 1", 0)
	var msgs: Array = cmd.consume_status_messages()
	assert(msgs.size() == 1, "First status should go through")

	# Second status at tick 10 — should be rate-limited (cooldown is 150)
	cmd.send_status("Test 2", 10)
	msgs = cmd.consume_status_messages()
	assert(msgs.size() == 0, "Second status within cooldown should be blocked")

	# Third status at tick 200 — should go through
	cmd.send_status("Test 3", 200)
	msgs = cmd.consume_status_messages()
	assert(msgs.size() == 1, "Status after cooldown should go through")
