class_name TestPerformance
extends Node

# Performance regression tests for Phase 6.
# Run via: godot --headless --script game/tests/test_performance.gd
#
# Thresholds:
#   1. 500 entities query (Position + Health + FactionComponent): < 5ms
#   2. SpatialHash radius query (300 entities, r=5 tiles): < 1ms
#   3. Full sim tick (300 entities, all systems): < 15ms
#   4. Vision system (200 units): < 3ms

var _pass_count: int = 0
var _fail_count: int = 0


func _ready() -> void:
	_run_tests()
	var status: String = "PASS" if _fail_count == 0 else "FAIL"
	push_warning("Performance tests: %d passed, %d failed -- %s" % [_pass_count, _fail_count, status])
	get_tree().quit(0 if _fail_count == 0 else 1)


func _run_tests() -> void:
	test_ecs_query_500_entities()
	test_spatial_hash_radius_300()
	test_full_tick_300_entities()
	test_vision_200_units()


func test_ecs_query_500_entities() -> void:
	var ecs := ECS.new()
	for i in range(500):
		var eid: int = ecs.create_entity()
		ecs.add_component(eid, "Position", {"x": randf() * 10000.0, "y": randf() * 10000.0})
		ecs.add_component(eid, "Health", {"current": 100.0, "max": 100.0})
		ecs.add_component(eid, "FactionComponent", {"faction_id": i % 3})

	var start: int = Time.get_ticks_usec()
	for _i in range(10):
		ecs.begin_tick()
		var _result: Array = ecs.query(["Position", "Health", "FactionComponent"])
	var elapsed_ms: float = (Time.get_ticks_usec() - start) / 1000.0 / 10.0
	_check("ECS query 500 entities (3 components)", elapsed_ms, 5.0)


func test_spatial_hash_radius_300() -> void:
	var sh := SpatialHash.new()
	for i in range(300):
		sh.insert(i, Vector2(randf() * 5000.0, randf() * 5000.0))

	var start: int = Time.get_ticks_usec()
	for _i in range(100):
		var _result: Array = sh.query_radius(Vector2(2500.0, 2500.0), 5.0 * 32.0)
	var elapsed_ms: float = (Time.get_ticks_usec() - start) / 1000.0 / 100.0
	_check("SpatialHash radius query (300 entities, r=5 tiles)", elapsed_ms, 1.0)


func test_full_tick_300_entities() -> void:
	var ecs := ECS.new()
	var sh := SpatialHash.new()
	var combat := CombatSystem.new()
	var movement := MovementSystem.new()
	var vision := VisionSystem.new()

	combat.set_spatial_hash(sh)
	movement.set_spatial_hash(sh)
	movement.set_on_entity_moved(vision.mark_dirty)
	vision.set_spatial_hash(sh)

	for i in range(300):
		var eid: int = ecs.create_entity()
		var px: float = randf() * 5000.0
		var py: float = randf() * 5000.0
		ecs.add_component(eid, "Position", {"x": px, "y": py})
		ecs.add_component(eid, "Health", {"current": 100.0, "max": 100.0, "armor_type": "medium"})
		ecs.add_component(eid, "FactionComponent", {"faction_id": i % 2})
		ecs.add_component(eid, "Faction", {"faction_id": i % 2})
		ecs.add_component(eid, "MoveSpeed", {"speed": 2.0})
		ecs.add_component(eid, "VisionRange", {"range": 128.0})
		ecs.add_component(eid, "Attackable", {})
		ecs.add_component(eid, "MoveCommand", {"destination": Vector2(randf() * 5000.0, randf() * 5000.0)})
		sh.insert(eid, Vector2(px, py))

	for i in range(1, 50):
		if ecs.entity_exists(i):
			ecs.add_component(i, "Weapon", {"damage": 10.0, "range": 128.0, "cooldown": 1.0, "damage_type": "kinetic"})
			ecs.add_component(i, "AttackCommand", {"target": i + 150})

	vision.request_full_rebuild()
	movement.map_bounds = Rect2(0, 0, 5000, 5000)

	var start: int = Time.get_ticks_usec()
	for tick in range(10):
		ecs.begin_tick()
		movement.tick(ecs, tick)
		combat.tick(ecs, tick)
		vision.tick(ecs, tick)
	var elapsed_ms: float = (Time.get_ticks_usec() - start) / 1000.0 / 10.0
	_check("Full sim tick (300 entities, all systems)", elapsed_ms, 15.0)


func test_vision_200_units() -> void:
	var ecs := ECS.new()
	var sh := SpatialHash.new()
	var vision := VisionSystem.new()
	vision.set_spatial_hash(sh)

	for i in range(200):
		var eid: int = ecs.create_entity()
		var px: float = randf() * 3000.0
		var py: float = randf() * 3000.0
		ecs.add_component(eid, "Position", {"x": px, "y": py})
		ecs.add_component(eid, "VisionRange", {"range": 96.0})
		ecs.add_component(eid, "Faction", {"faction_id": i % 2})
		sh.insert(eid, Vector2(px, py))

	vision.request_full_rebuild()

	var start: int = Time.get_ticks_usec()
	for tick in range(10):
		ecs.begin_tick()
		for j in range(20):
			vision.mark_dirty(Vector2(randf() * 3000.0, randf() * 3000.0))
		vision.tick(ecs, tick)
	var elapsed_ms: float = (Time.get_ticks_usec() - start) / 1000.0 / 10.0
	_check("Vision system (200 units)", elapsed_ms, 3.0)


func _check(name: String, actual_ms: float, threshold_ms: float) -> void:
	if actual_ms <= threshold_ms:
		_pass_count += 1
		push_warning("  PASS  %s: %.2fms (< %.1fms)" % [name, actual_ms, threshold_ms])
	else:
		_fail_count += 1
		push_warning("  FAIL  %s: %.2fms (> %.1fms)" % [name, actual_ms, threshold_ms])
