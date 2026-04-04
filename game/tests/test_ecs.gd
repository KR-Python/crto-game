class_name TestECS
## Deterministic ECS tests — simple runner, no external framework.


static func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var errors: Array[String] = []

	var tests: Array[String] = [
		"test_entity_create_destroy",
		"test_add_get_remove_component",
		"test_query_single_component",
		"test_query_multiple_components",
		"test_destroyed_entity_not_in_query",
		"test_component_signals",
		"test_query_performance_500_entities",
		"test_set_component",
		"test_query_with_data",
	]

	var instance := TestECS.new()
	for test_name in tests:
		var result: String = instance.call(test_name)
		if result == "":
			passed += 1
		else:
			failed += 1
			errors.append("%s: %s" % [test_name, result])

	return {"passed": passed, "failed": failed, "errors": errors}


# --- Individual tests return "" on pass, error string on failure ---


func test_entity_create_destroy() -> String:
	var ecs := ECS.new()
	var e1 := ecs.create_entity()
	var e2 := ecs.create_entity()
	if e1 == e2:
		return "IDs should be unique"
	if not ecs.is_alive(e1):
		return "e1 should be alive"
	ecs.destroy_entity(e1)
	if ecs.is_alive(e1):
		return "e1 should be dead after destroy"
	if not ecs.is_alive(e2):
		return "e2 should still be alive"
	return ""


func test_add_get_remove_component() -> String:
	var ecs := ECS.new()
	var e := ecs.create_entity()
	ecs.add_component(e, "position", {"x": 1.0, "y": 2.0})
	if not ecs.has_component(e, "position"):
		return "should have position"
	var pos := ecs.get_component(e, "position")
	if pos.get("x") != 1.0 or pos.get("y") != 2.0:
		return "position data mismatch"
	ecs.remove_component(e, "position")
	if ecs.has_component(e, "position"):
		return "position should be removed"
	return ""


func test_query_single_component() -> String:
	var ecs := ECS.new()
	var e1 := ecs.create_entity()
	var e2 := ecs.create_entity()
	var e3 := ecs.create_entity()
	ecs.add_component(e1, "position", {"x": 0.0, "y": 0.0})
	ecs.add_component(e2, "position", {"x": 1.0, "y": 1.0})
	# e3 has no position
	var required: Array[String] = ["position"]
	var result := ecs.query(required)
	if result.size() != 2:
		return "expected 2 entities, got %d" % result.size()
	if e1 not in result or e2 not in result:
		return "missing expected entities"
	return ""


func test_query_multiple_components() -> String:
	var ecs := ECS.new()
	var e1 := ecs.create_entity()
	var e2 := ecs.create_entity()
	var e3 := ecs.create_entity()
	ecs.add_component(e1, "position", {"x": 0.0, "y": 0.0})
	ecs.add_component(e1, "health", {"current": 100.0, "max": 100.0})
	ecs.add_component(e2, "position", {"x": 1.0, "y": 1.0})
	# e2 has no health
	ecs.add_component(e3, "health", {"current": 50.0, "max": 50.0})
	# e3 has no position
	var required: Array[String] = ["position", "health"]
	var result := ecs.query(required)
	if result.size() != 1:
		return "expected 1 entity, got %d" % result.size()
	if result[0] != e1:
		return "expected e1 in intersection"
	return ""


func test_destroyed_entity_not_in_query() -> String:
	var ecs := ECS.new()
	var e1 := ecs.create_entity()
	var e2 := ecs.create_entity()
	ecs.add_component(e1, "position", {"x": 0.0, "y": 0.0})
	ecs.add_component(e2, "position", {"x": 1.0, "y": 1.0})
	ecs.destroy_entity(e1)
	var required: Array[String] = ["position"]
	var result := ecs.query(required)
	if result.size() != 1:
		return "expected 1 entity after destroy, got %d" % result.size()
	if result[0] != e2:
		return "wrong entity survived"
	return ""


func test_component_signals() -> String:
	var ecs := ECS.new()
	var signals_fired: Dictionary = {
		"entity_created": 0,
		"entity_destroyed": 0,
		"component_added": 0,
		"component_removed": 0,
	}
	# Use lambdas to track signal emissions
	ecs.entity_created.connect(func(_id): signals_fired["entity_created"] += 1)
	ecs.entity_destroyed.connect(func(_id): signals_fired["entity_destroyed"] += 1)
	ecs.component_added.connect(func(_id, _name): signals_fired["component_added"] += 1)
	ecs.component_removed.connect(func(_id, _name): signals_fired["component_removed"] += 1)

	var e := ecs.create_entity()
	if signals_fired["entity_created"] != 1:
		return "entity_created should fire once"
	ecs.add_component(e, "pos", {"x": 0.0})
	if signals_fired["component_added"] != 1:
		return "component_added should fire once"
	ecs.remove_component(e, "pos")
	if signals_fired["component_removed"] != 1:
		return "component_removed should fire once"
	ecs.destroy_entity(e)
	if signals_fired["entity_destroyed"] != 1:
		return "entity_destroyed should fire once"
	return ""


func test_query_performance_500_entities() -> String:
	var ecs := ECS.new()
	var comp_names: Array[String] = ["position", "velocity", "health", "faction", "vision_range"]
	# Create 500 entities with 5 components each
	for i in range(500):
		var e := ecs.create_entity()
		for cn in comp_names:
			ecs.add_component(e, cn, {"value": i})

	# Time a query with 3 required components
	var required: Array[String] = ["position", "velocity", "health"]
	var start := Time.get_ticks_usec()
	var result := ecs.query(required)
	var elapsed_us := Time.get_ticks_usec() - start
	var elapsed_ms := elapsed_us / 1000.0

	if result.size() != 500:
		return "expected 500 results, got %d" % result.size()
	if elapsed_ms > 5.0:
		return "query took %.2f ms, expected < 5ms" % elapsed_ms
	return ""


func test_set_component() -> String:
	var ecs := ECS.new()
	var e := ecs.create_entity()
	ecs.add_component(e, "health", {"current": 100.0, "max": 100.0})
	ecs.set_component(e, "health", {"current": 50.0, "max": 100.0})
	var h := ecs.get_component(e, "health")
	if h.get("current") != 50.0:
		return "set_component should update data"
	return ""


func test_query_with_data() -> String:
	var ecs := ECS.new()
	var e := ecs.create_entity()
	ecs.add_component(e, "position", {"x": 5.0, "y": 10.0})
	ecs.add_component(e, "health", {"current": 100.0, "max": 100.0})
	var required: Array[String] = ["position", "health"]
	var result := ecs.query_with_data(required)
	if result.size() != 1:
		return "expected 1 result"
	var entry: Dictionary = result[0]
	if entry.get("entity_id") != e:
		return "wrong entity_id in result"
	if entry.get("position", {}).get("x") != 5.0:
		return "position data missing in query_with_data"
	return ""
