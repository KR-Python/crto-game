class_name TestEconomy
extends Node

# Tests for EconomySystem — 8 deterministic tests.
# Run via: godot --headless --script game/tests/test_economy.gd

var _ecs: ECS
var _system: EconomySystem
var _pass_count: int = 0
var _fail_count: int = 0


func _ready() -> void:
	run_all_tests()
	print("\n=== Results: %d passed, %d failed ===" % [_pass_count, _fail_count])
	get_tree().quit(0 if _fail_count == 0 else 1)


func run_all_tests() -> void:
	test_harvester_full_cycle()
	test_resource_node_depletion()
	test_spend_success()
	test_spend_fail_no_partial()
	test_power_grid_offline_and_restore()
	test_power_shutdown_priority_order()
	test_harvester_refinery_destroyed()
	test_two_harvesters_same_node()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _setup() -> void:
	_ecs = ECS.new()
	_system = EconomySystem.new()


func _assert(condition: bool, test_name: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % test_name)
	else:
		_fail_count += 1
		print("  FAIL: %s" % test_name)


func _create_refinery(faction_id: int, x: float, y: float) -> int:
	var eid: int = _ecs.create_entity()
	_ecs.add_component(eid, "Structure", {"built": true, "is_refinery": true})
	_ecs.add_component(eid, "FactionComponent", {"faction_id": faction_id})
	_ecs.add_component(eid, "Position", {"x": x, "y": y})
	return eid


func _create_resource_node(x: float, y: float, remaining: int, type: String = "primary") -> int:
	var eid: int = _ecs.create_entity()
	_ecs.add_component(eid, "ResourceNode", {"type": type, "remaining": remaining})
	_ecs.add_component(eid, "Position", {"x": x, "y": y})
	return eid


func _create_harvester(faction_id: int, x: float, y: float, refinery_id: int, capacity: int = 100, harvest_rate: float = 10.0) -> int:
	var eid: int = _ecs.create_entity()
	_ecs.add_component(eid, "Harvester", {
		"capacity": capacity,
		"current_load": 0,
		"resource_type": "primary",
		"state": "idle",
		"target_node": -1,
		"home_refinery": refinery_id,
		"harvest_rate": harvest_rate,
	})
	_ecs.add_component(eid, "FactionComponent", {"faction_id": faction_id})
	_ecs.add_component(eid, "Position", {"x": x, "y": y})
	_ecs.add_component(eid, "MoveSpeed", {"speed": 3.5})
	return eid


## Simulates movement: teleport harvester to MoveCommand destination.
## In the real game, MovementSystem handles this. For tests we shortcut.
func _simulate_movement(eid: int) -> void:
	if not _ecs.has_component(eid, "MoveCommand"):
		return
	var cmd: Dictionary = _ecs.get_component(eid, "MoveCommand")
	_ecs.add_component(eid, "Position", {
		"x": cmd.destination_x,
		"y": cmd.destination_y,
	})


func _simulate_movement_all() -> void:
	for eid: int in _ecs.query(["MoveCommand", "Position"] as Array[String]):
		_simulate_movement(eid)


# ── Test 1: Harvester full cycle ──────────────────────────────────────────────

func test_harvester_full_cycle() -> void:
	print("\nTest 1: Harvester full cycle")
	_setup()
	var refinery: int = _create_refinery(1, 0.0, 0.0)
	var node: int = _create_resource_node(30.0, 0.0, 500)
	var harvester: int = _create_harvester(1, 0.0, 0.0, refinery)

	# Tick 1: idle -> moving_to_node
	_system.tick(_ecs, 1)
	var h: Dictionary = _ecs.get_component(harvester, "Harvester")
	_assert(h.state == "moving_to_node", "state transitions to moving_to_node")

	# Simulate movement to node
	_simulate_movement(harvester)

	# Tick 2: at node -> harvesting
	_system.tick(_ecs, 2)
	h = _ecs.get_component(harvester, "Harvester")
	_assert(h.state == "harvesting", "state transitions to harvesting at node")

	# Tick enough to fill capacity (100 capacity, 1/tick min = 100 ticks)
	for i in range(100):
		_system.tick(_ecs, 3 + i)

	h = _ecs.get_component(harvester, "Harvester")
	_assert(h.state == "returning", "state transitions to returning when full")

	# Simulate movement to refinery
	_simulate_movement(harvester)

	# Tick: deposit
	_system.tick(_ecs, 200)
	h = _ecs.get_component(harvester, "Harvester")
	_assert(h.state == "idle", "state back to idle after deposit")
	_assert(int(h.current_load) == 0, "load reset to 0")

	var res: Dictionary = _system.get_resources(1)
	_assert(res.primary > 0, "faction gained resources")


# ── Test 2: Resource node depletion ───────────────────────────────────────────

func test_resource_node_depletion() -> void:
	print("\nTest 2: Resource node depletion — harvester seeks new node")
	_setup()
	var refinery: int = _create_refinery(1, 0.0, 0.0)
	var node1: int = _create_resource_node(30.0, 0.0, 20)
	var node2: int = _create_resource_node(60.0, 0.0, 500)
	var harvester: int = _create_harvester(1, 0.0, 0.0, refinery)

	# idle -> move to node1
	_system.tick(_ecs, 1)
	_simulate_movement(harvester)

	# Harvest until node1 depleted (20 resources at 1/tick = 20 ticks)
	for i in range(25):
		_system.tick(_ecs, 2 + i)

	var n1: Dictionary = _ecs.get_component(node1, "ResourceNode")
	_assert(int(n1.remaining) == 0, "node1 depleted")

	# Harvester should go idle then find node2 on next tick
	_system.tick(_ecs, 30)
	var h: Dictionary = _ecs.get_component(harvester, "Harvester")
	# Could be returning (had load) or moving_to_node (found node2)
	var seeking_new: bool = h.state == "moving_to_node" or h.state == "returning"
	_assert(seeking_new, "harvester seeks new node or returns with partial load")
	if h.state == "moving_to_node":
		_assert(h.target_node == node2, "targets node2 after node1 depleted")


# ── Test 3: spend() success ──────────────────────────────────────────────────

func test_spend_success() -> void:
	print("\nTest 3: spend() with sufficient resources")
	_setup()
	_system.add_income(1, 500, "primary")
	_system.add_income(1, 200, "secondary")
	var ok: bool = _system.spend(1, 300, 100)
	_assert(ok == true, "spend returns true")
	var res: Dictionary = _system.get_resources(1)
	_assert(res.primary == 200, "primary deducted correctly")
	_assert(res.secondary == 100, "secondary deducted correctly")


# ── Test 4: spend() fail — no partial deduction ──────────────────────────────

func test_spend_fail_no_partial() -> void:
	print("\nTest 4: spend() fails — no partial deduction")
	_setup()
	_system.add_income(1, 500, "primary")
	_system.add_income(1, 50, "secondary")
	var ok: bool = _system.spend(1, 300, 100)  # not enough secondary
	_assert(ok == false, "spend returns false")
	var res: Dictionary = _system.get_resources(1)
	_assert(res.primary == 500, "primary unchanged")
	_assert(res.secondary == 50, "secondary unchanged")


# ── Test 5: Power grid offline and restore ────────────────────────────────────

func test_power_grid_offline_and_restore() -> void:
	print("\nTest 5: Power grid — buildings offline when negative, restore when positive")
	_setup()

	# Power producer: 30 output
	var pp: int = _ecs.create_entity()
	_ecs.add_component(pp, "PowerProducer", {"output": 30})
	_ecs.add_component(pp, "FactionComponent", {"faction_id": 1})

	# Consumers: radar(10,p1), barracks(20,p2), turret(15,p4) = 45, deficit 15
	var radar: int = _ecs.create_entity()
	_ecs.add_component(radar, "PowerConsumer", {"drain": 10, "priority": 1})
	_ecs.add_component(radar, "FactionComponent", {"faction_id": 1})

	var barracks: int = _ecs.create_entity()
	_ecs.add_component(barracks, "PowerConsumer", {"drain": 20, "priority": 2})
	_ecs.add_component(barracks, "FactionComponent", {"faction_id": 1})

	var turret: int = _ecs.create_entity()
	_ecs.add_component(turret, "PowerConsumer", {"drain": 15, "priority": 4})
	_ecs.add_component(turret, "FactionComponent", {"faction_id": 1})

	_system.tick(_ecs, 1)

	_assert(_ecs.has_component(radar, "PoweredOff"), "radar offline (priority 1)")
	_assert(_ecs.has_component(barracks, "PoweredOff"), "barracks offline (priority 2)")
	_assert(not _ecs.has_component(turret, "PoweredOff"), "turret stays online (priority 4)")

	# Add more power: 50 total, 45 consumed -> net positive
	var pp2: int = _ecs.create_entity()
	_ecs.add_component(pp2, "PowerProducer", {"output": 20})
	_ecs.add_component(pp2, "FactionComponent", {"faction_id": 1})

	_system.tick(_ecs, 2)

	_assert(not _ecs.has_component(radar, "PoweredOff"), "radar restored")
	_assert(not _ecs.has_component(barracks, "PoweredOff"), "barracks restored")
	_assert(not _ecs.has_component(turret, "PoweredOff"), "turret still online")


# ── Test 6: Power shutdown cascade priority order ─────────────────────────────

func test_power_shutdown_priority_order() -> void:
	print("\nTest 6: Power shutdown cascade — correct priority order")
	_setup()

	var pp: int = _ecs.create_entity()
	_ecs.add_component(pp, "PowerProducer", {"output": 20})
	_ecs.add_component(pp, "FactionComponent", {"faction_id": 1})

	# 4 consumers total=50, produced=20, deficit=30
	# Shut off p1(10)+p2(10)+p3(10)=30 -> turret(p5,20) stays on
	var sensor: int = _ecs.create_entity()
	_ecs.add_component(sensor, "PowerConsumer", {"drain": 10, "priority": 1})
	_ecs.add_component(sensor, "FactionComponent", {"faction_id": 1})

	var prod_bldg: int = _ecs.create_entity()
	_ecs.add_component(prod_bldg, "PowerConsumer", {"drain": 10, "priority": 2})
	_ecs.add_component(prod_bldg, "FactionComponent", {"faction_id": 1})

	var tech_bldg: int = _ecs.create_entity()
	_ecs.add_component(tech_bldg, "PowerConsumer", {"drain": 10, "priority": 3})
	_ecs.add_component(tech_bldg, "FactionComponent", {"faction_id": 1})

	var turret: int = _ecs.create_entity()
	_ecs.add_component(turret, "PowerConsumer", {"drain": 20, "priority": 5})
	_ecs.add_component(turret, "FactionComponent", {"faction_id": 1})

	_system.tick(_ecs, 1)

	_assert(_ecs.has_component(sensor, "PoweredOff"), "sensor off first (p1)")
	_assert(_ecs.has_component(prod_bldg, "PoweredOff"), "production off second (p2)")
	_assert(_ecs.has_component(tech_bldg, "PoweredOff"), "tech off third (p3)")
	_assert(not _ecs.has_component(turret, "PoweredOff"), "turret stays on (p5, highest)")


# ── Test 7: Harvester home refinery destroyed ─────────────────────────────────

func test_harvester_refinery_destroyed() -> void:
	print("\nTest 7: Harvester home_refinery destroyed — graceful fallback")
	_setup()
	var ref1: int = _create_refinery(1, 0.0, 0.0)
	var ref2: int = _create_refinery(1, 100.0, 0.0)
	var node: int = _create_resource_node(30.0, 0.0, 500)
	var harvester: int = _create_harvester(1, 0.0, 0.0, ref1)

	# Get to returning state
	_system.tick(_ecs, 1)  # idle -> moving_to_node
	_simulate_movement(harvester)
	_system.tick(_ecs, 2)  # at node -> harvesting

	for i in range(100):
		_system.tick(_ecs, 3 + i)

	var h: Dictionary = _ecs.get_component(harvester, "Harvester")
	_assert(h.state == "returning", "harvester returning with load")

	# Destroy home refinery
	_ecs.destroy_entity(ref1)

	# Next tick: should find ref2
	_system.tick(_ecs, 200)
	h = _ecs.get_component(harvester, "Harvester")
	_assert(h.home_refinery == ref2, "reassigned to ref2")


# ── Test 8: Two harvesters same node ──────────────────────────────────────────

func test_two_harvesters_same_node() -> void:
	print("\nTest 8: Two harvesters competing for same node")
	_setup()
	var refinery: int = _create_refinery(1, 0.0, 0.0)
	var node: int = _create_resource_node(30.0, 0.0, 200)
	var h1: int = _create_harvester(1, 0.0, 0.0, refinery, 50)
	var h2: int = _create_harvester(1, 0.0, 5.0, refinery, 50)

	# Both go to node
	_system.tick(_ecs, 1)
	_simulate_movement_all()

	# Both harvest
	for i in range(60):
		_system.tick(_ecs, 2 + i)

	# Both should return and deposit
	_simulate_movement_all()
	_system.tick(_ecs, 100)

	var res: Dictionary = _system.get_resources(1)
	_assert(res.primary > 0, "faction has resources from both harvesters")

	# Both harvesters should still be functional
	var hc1: Dictionary = _ecs.get_component(h1, "Harvester")
	var hc2: Dictionary = _ecs.get_component(h2, "Harvester")
	var both_ok: bool = (hc1.state == "idle" or hc1.state == "moving_to_node" or hc1.state == "returning") and \
		(hc2.state == "idle" or hc2.state == "moving_to_node" or hc2.state == "returning")
	_assert(both_ok, "both harvesters functional — no conflict")
