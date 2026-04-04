class_name TestTechTree

# 6 tests for TechTreeSystem.
# Uses a minimal MockECS that stores components in a Dictionary.

# ---------------------------------------------------------------------------
# Mock ECS
# ---------------------------------------------------------------------------

class MockECS:
	var _components: Dictionary = {}  # { entity_id: { component_name: data } }
	var _next_id: int = 1

	func create_entity() -> int:
		var id: int = _next_id
		_next_id += 1
		_components[id] = {}
		return id

	func destroy_entity(id: int) -> void:
		_components.erase(id)

	func add_component(entity_id: int, component_name: String, data: Dictionary) -> void:
		if not _components.has(entity_id):
			_components[entity_id] = {}
		_components[entity_id][component_name] = data

	func get_component(entity_id: int, component_name: String) -> Dictionary:
		return _components.get(entity_id, {}).get(component_name, {})

	func has_component(entity_id: int, component_name: String) -> bool:
		return _components.get(entity_id, {}).has(component_name)

	func remove_component(entity_id: int, component_name: String) -> void:
		if _components.has(entity_id):
			_components[entity_id].erase(component_name)

	func query(required_components: Array[String]) -> Array[int]:
		var result: Array[int] = []
		for entity_id: int in _components.keys():
			var has_all: bool = true
			for comp: String in required_components:
				if not _components[entity_id].has(comp):
					has_all = false
					break
			if has_all:
				result.append(entity_id)
		return result


# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------

func _make_ecs_with_lab(powered: bool = true) -> Array:
	var ecs := MockECS.new()

	# Faction economy entity
	var eco_id: int = ecs.create_entity()
	ecs.add_component(eco_id, "FactionComponent", {"faction_id": 1})
	ecs.add_component(eco_id, "FactionEconomy", {"primary": 5000, "secondary": 2000})

	# Tech lab entity
	var lab_id: int = ecs.create_entity()
	ecs.add_component(lab_id, "TechLab", {})
	ecs.add_component(lab_id, "FactionComponent", {"faction_id": 1})
	ecs.add_component(lab_id, "PoweredBuilding", {"powered": powered})

	# Research registry
	var reg_id: int = ecs.create_entity()
	ecs.add_component(reg_id, "ResearchRegistry", {
		"entries": [
			{
				"research_id": "aegis_advanced_armor",
				"tier": 2,
				"cost": {"primary": 1500, "secondary": 500},
				"time": 10.0,
				"requires": [],
				"effect": {
					"type": "stat_modifier",
					"target": {"category": "vehicle"},
					"modifier": {"health.max": 1.25},
				},
			},
			{
				"research_id": "aegis_t3_supertech",
				"tier": 3,
				"cost": {"primary": 3000, "secondary": 1000},
				"time": 30.0,
				"requires": [],
				"effect": {"type": "unlock"},
			},
		]
	})

	return [ecs, lab_id, eco_id]


# ---------------------------------------------------------------------------
# Test 1: Research starts — active_research set, cost deducted
# ---------------------------------------------------------------------------

func test_research_starts_and_deducts_cost() -> String:
	var result: Array = _make_ecs_with_lab()
	var ecs: MockECS = result[0]
	var lab_id: int = result[1]
	var eco_id: int = result[2]

	var system := TechTreeSystem.new()
	var ret: Dictionary = system.start_research(1, "aegis_advanced_armor", lab_id, ecs)

	assert(ret.get("success") == true, "start_research should succeed")

	# active_research should be set
	var state: Dictionary = system._faction_research.get(1, {})
	var active: Dictionary = state.get("active_research", {})
	assert(active.get("tech_id") == "aegis_advanced_armor", "active tech_id mismatch")
	assert(active.get("progress", -1) == 0.0, "progress should start at 0")

	# Cost deducted
	var economy: Dictionary = ecs.get_component(eco_id, "FactionEconomy")
	assert(economy.get("primary") == 3500, "primary should be 5000 - 1500 = 3500")
	assert(economy.get("secondary") == 1500, "secondary should be 2000 - 500 = 1500")

	return "PASS"


# ---------------------------------------------------------------------------
# Test 2: Research completes after correct number of ticks
# ---------------------------------------------------------------------------

func test_research_completes_after_correct_ticks() -> String:
	var result: Array = _make_ecs_with_lab()
	var ecs: MockECS = result[0]
	var lab_id: int = result[1]

	var system := TechTreeSystem.new()
	system.start_research(1, "aegis_advanced_armor", lab_id, ecs)

	# 10 seconds * 15 ticks/sec = 150 ticks
	var expected_ticks: int = 150
	var completed: bool = false
	system.research_completed.connect(func(_fid, _tid): completed = true)

	for t: int in range(expected_ticks - 1):
		system.tick(ecs, t)
		assert(not completed, "should not complete before tick %d" % expected_ticks)

	system.tick(ecs, expected_ticks - 1)
	assert(completed, "research should complete at tick %d" % expected_ticks)
	assert(system.is_researched(1, "aegis_advanced_armor"), "tech should be marked researched")

	return "PASS"


# ---------------------------------------------------------------------------
# Test 3: Research requires lab — rejected without lab entity
# ---------------------------------------------------------------------------

func test_research_rejected_without_lab() -> String:
	var ecs := MockECS.new()

	# Economy entity only, no lab
	var eco_id: int = ecs.create_entity()
	ecs.add_component(eco_id, "FactionComponent", {"faction_id": 1})
	ecs.add_component(eco_id, "FactionEconomy", {"primary": 5000, "secondary": 2000})

	var reg_id: int = ecs.create_entity()
	ecs.add_component(reg_id, "ResearchRegistry", {
		"entries": [{"research_id": "aegis_advanced_armor", "tier": 2, "cost": {"primary": 100, "secondary": 0}, "time": 5.0, "requires": [], "effect": {}}]
	})

	var system := TechTreeSystem.new()
	# Pass a fake lab_entity_id that has no TechLab component
	var ret: Dictionary = system.start_research(1, "aegis_advanced_armor", 9999, ecs)

	assert(ret.get("success") == false, "should fail without lab")
	assert(ret.get("error") == "no_tech_lab", "error should be no_tech_lab")

	return "PASS"


# ---------------------------------------------------------------------------
# Test 4: stat_modifier effect applied to all matching entities
# ---------------------------------------------------------------------------

func test_stat_modifier_applied_to_matching_entities() -> String:
	var result: Array = _make_ecs_with_lab()
	var ecs: MockECS = result[0]
	var lab_id: int = result[1]

	# Add two vehicle entities for faction 1
	var v1: int = ecs.create_entity()
	ecs.add_component(v1, "FactionComponent", {"faction_id": 1})
	ecs.add_component(v1, "UnitCategory", {"category": "vehicle"})
	ecs.add_component(v1, "Health", {"current": 400.0, "max": 400.0})

	var v2: int = ecs.create_entity()
	ecs.add_component(v2, "FactionComponent", {"faction_id": 1})
	ecs.add_component(v2, "UnitCategory", {"category": "vehicle"})
	ecs.add_component(v2, "Health", {"current": 200.0, "max": 200.0})

	# Non-matching entity (different faction)
	var other: int = ecs.create_entity()
	ecs.add_component(other, "FactionComponent", {"faction_id": 2})
	ecs.add_component(other, "UnitCategory", {"category": "vehicle"})
	ecs.add_component(other, "Health", {"current": 300.0, "max": 300.0})

	var system := TechTreeSystem.new()
	system.start_research(1, "aegis_advanced_armor", lab_id, ecs)

	# Fast-forward to completion
	for t: int in range(150):
		system.tick(ecs, t)

	# v1 and v2 max HP should be multiplied by 1.25
	var h1: Dictionary = ecs.get_component(v1, "Health")
	var h2: Dictionary = ecs.get_component(v2, "Health")
	var ho: Dictionary = ecs.get_component(other, "Health")

	assert(abs(h1.get("max", 0.0) - 500.0) < 0.01, "v1 max HP should be 500 (400 * 1.25)")
	assert(abs(h2.get("max", 0.0) - 250.0) < 0.01, "v2 max HP should be 250 (200 * 1.25)")
	assert(abs(ho.get("max", 0.0) - 300.0) < 0.01, "other faction entity should be unchanged")

	return "PASS"


# ---------------------------------------------------------------------------
# Test 5: Cancel research — full refund, active_research cleared
# ---------------------------------------------------------------------------

func test_cancel_research_refunds_and_clears() -> String:
	var result: Array = _make_ecs_with_lab()
	var ecs: MockECS = result[0]
	var lab_id: int = result[1]

	var system := TechTreeSystem.new()
	system.start_research(1, "aegis_advanced_armor", lab_id, ecs)

	# Advance partway
	for t: int in range(50):
		system.tick(ecs, t)

	system.cancel_research(1)

	var state: Dictionary = system._faction_research.get(1, {})
	assert(state.get("active_research", {}).is_empty(), "active_research should be cleared")

	# Refund recorded in pending_refund
	var pending: Dictionary = state.get("pending_refund", {})
	assert(pending.get("primary", 0) == 1500, "primary refund should be 1500")
	assert(pending.get("secondary", 0) == 500, "secondary refund should be 500")

	return "PASS"


# ---------------------------------------------------------------------------
# Test 6: get_tech_tier — returns 2 when any T2 research completed
# ---------------------------------------------------------------------------

func test_get_tech_tier_returns_2_for_t2_research() -> String:
	var result: Array = _make_ecs_with_lab()
	var ecs: MockECS = result[0]
	var lab_id: int = result[1]

	var system := TechTreeSystem.new()

	# Mock data loader
	var data_loader := MockDataLoader.new()

	# Before any research — should be tier 1
	assert(system.get_tech_tier(1, data_loader) == 1, "tier should be 1 before any research")

	# Complete T2 research
	system.start_research(1, "aegis_advanced_armor", lab_id, ecs)
	for t: int in range(150):
		system.tick(ecs, t)

	assert(system.is_researched(1, "aegis_advanced_armor"), "aegis_advanced_armor should be researched")
	var tier: int = system.get_tech_tier(1, data_loader)
	assert(tier == 2, "tier should be 2 after completing T2 research, got %d" % tier)

	return "PASS"


# ---------------------------------------------------------------------------
# Mock DataLoader (used by tests 6)
# ---------------------------------------------------------------------------

class MockDataLoader:
	func get_all_research(_faction_id: int) -> Array:
		return [
			{"research_id": "aegis_advanced_armor", "tier": 2},
			{"research_id": "aegis_t3_supertech", "tier": 3},
		]

	func get_research_by_id(tech_id: String) -> Dictionary:
		var all: Array = get_all_research(0)
		for entry: Dictionary in all:
			if entry.get("research_id", "") == tech_id:
				return entry
		return {}


# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------

func run_all() -> void:
	var tests: Array[Callable] = [
		test_research_starts_and_deducts_cost,
		test_research_completes_after_correct_ticks,
		test_research_rejected_without_lab,
		test_stat_modifier_applied_to_matching_entities,
		test_cancel_research_refunds_and_clears,
		test_get_tech_tier_returns_2_for_t2_research,
	]

	var passed: int = 0
	var failed: int = 0

	for test: Callable in tests:
		var test_name: String = test.get_method()
		var outcome: String = test.call()
		if outcome == "PASS":
			print("[PASS] %s" % test_name)
			passed += 1
		else:
			push_error("[FAIL] %s — %s" % [test_name, outcome])
			failed += 1

	print("Results: %d passed, %d failed" % [passed, failed])
