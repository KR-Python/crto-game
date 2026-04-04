class_name TestProduction
## Tests for ProductionSystem.
## Uses inline MockECS and MockEconomySystem to run without Godot scene tree.

# ─────────────────────────────────────────────────────────────────────────────
# Mock ECS
# ─────────────────────────────────────────────────────────────────────────────

class MockECS:
	var _components: Dictionary = {}
	var _next_id: int = 1

	func create_entity() -> int:
		var id: int = _next_id
		_next_id += 1
		_components[id] = {}
		return id

	func get_component(entity_id: int, component_name: String) -> Dictionary:
		if not _components.has(entity_id):
			return {}
		return _components[entity_id].get(component_name, {})

	func set_component(entity_id: int, component_name: String, data: Dictionary) -> void:
		if not _components.has(entity_id):
			_components[entity_id] = {}
		_components[entity_id][component_name] = data

	func has_component(entity_id: int, component_name: String) -> bool:
		if not _components.has(entity_id):
			return false
		return _components[entity_id].has(component_name)

	func remove_component(entity_id: int, component_name: String) -> void:
		if _components.has(entity_id):
			_components[entity_id].erase(component_name)

	func get_entities_with_component(component_name: String) -> Array:
		var result: Array = []
		for id in _components:
			if _components[id].has(component_name):
				result.append(id)
		return result

	func get_all_entities() -> Array:
		return _components.keys()


# ─────────────────────────────────────────────────────────────────────────────
# Mock EconomySystem
# ─────────────────────────────────────────────────────────────────────────────

class MockEconomySystem:
	var resources: Dictionary = {}

	func init_faction(faction_id: int, primary: float = 1000.0, secondary: float = 1000.0) -> void:
		resources[faction_id] = {"primary": primary, "secondary": secondary}

	func spend(faction_id: int, primary: float, secondary: float) -> bool:
		if not resources.has(faction_id):
			return false
		if resources[faction_id]["primary"] < primary or resources[faction_id]["secondary"] < secondary:
			return false
		resources[faction_id]["primary"] -= primary
		resources[faction_id]["secondary"] -= secondary
		return true

	func refund(faction_id: int, primary: float, secondary: float) -> void:
		if not resources.has(faction_id):
			resources[faction_id] = {"primary": 0.0, "secondary": 0.0}
		resources[faction_id]["primary"] += primary
		resources[faction_id]["secondary"] += secondary


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

static func _make_factory(ecs: MockECS, rate: float = 1.0, faction_id: int = 0) -> int:
	var id: int = ecs.create_entity()
	ecs.set_component(id, "ProductionQueue", {"queue": [], "progress": 0.0, "rate": rate})
	ecs.set_component(id, "Position", {"x": 100.0, "y": 100.0})
	ecs.set_component(id, "FactionComponent", {"faction_id": faction_id})
	ecs.set_component(id, "Structure", {"built": true, "build_progress": 1.0})
	return id


static func _make_production_system(ecs: MockECS, economy: MockEconomySystem) -> ProductionSystem:
	var sys: ProductionSystem = ProductionSystem.new()
	sys.economy_system = economy
	sys.register_unit_definition("medium_tank", 100.0, 0.0, 12.0)
	sys.register_unit_definition("rifleman", 50.0, 0.0, 5.0)
	return sys


# ─────────────────────────────────────────────────────────────────────────────
# Tests
# ─────────────────────────────────────────────────────────────────────────────

static func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var errors: Array = []

	# ── Test 1: Unit queued → spawns after correct number of ticks ─────────
	# medium_tank: build_time=12s, rate=1.0, 15 ticks/sec → 180 ticks
	var ecs1: MockECS = MockECS.new()
	var eco1: MockEconomySystem = MockEconomySystem.new()
	eco1.init_faction(0, 1000.0, 1000.0)
	var sys1: ProductionSystem = _make_production_system(ecs1, eco1)
	var factory1: int = _make_factory(ecs1, 1.0, 0)

	var queued: bool = sys1.queue_unit(factory1, "medium_tank", ecs1)
	if not queued:
		failed += 1
		errors.append("Test 1 FAIL: queue_unit returned false")
	else:
		for _t in range(179):
			sys1.tick(ecs1, _t)

		var q_before: Dictionary = ecs1.get_component(factory1, "ProductionQueue")
		var still_queued: bool = q_before["queue"].size() > 0

		sys1.tick(ecs1, 179)

		var q_after: Dictionary = ecs1.get_component(factory1, "ProductionQueue")
		var queue_empty: bool = q_after["queue"].size() == 0

		if still_queued and queue_empty:
			passed += 1
		else:
			failed += 1
			errors.append("Test 1 FAIL: still_queued=%s queue_empty=%s" % [str(still_queued), str(queue_empty)])

	# ── Test 2: Cancel mid-production → 100% refund ────────────────────────
	var ecs2: MockECS = MockECS.new()
	var eco2: MockEconomySystem = MockEconomySystem.new()
	eco2.init_faction(0, 1000.0, 0.0)
	var sys2: ProductionSystem = _make_production_system(ecs2, eco2)
	var factory2: int = _make_factory(ecs2, 1.0, 0)

	sys2.queue_unit(factory2, "medium_tank", ecs2)  # spends 100
	sys2.queue_unit(factory2, "rifleman", ecs2)      # spends 50

	for _t in range(90):
		sys2.tick(ecs2, _t)

	var res_before: float = eco2.resources[0]["primary"]
	sys2.cancel_unit(factory2, 0, ecs2)
	var refund_got: float = eco2.resources[0]["primary"] - res_before

	var q2: Dictionary = ecs2.get_component(factory2, "ProductionQueue")
	var full_refund: bool = absf(refund_got - 100.0) < 0.01
	var progress_reset: bool = q2["progress"] == 0.0
	var next_is_rifleman: bool = q2["queue"].size() == 1 and q2["queue"][0] == "rifleman"

	if full_refund and progress_reset and next_is_rifleman:
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 FAIL: full_refund=%s progress_reset=%s next_rifleman=%s refund=%.1f" % [str(full_refund), str(progress_reset), str(next_is_rifleman), refund_got])

	# ── Test 3: Building destroyed → 50% refund on all queued items ────────
	var ecs3: MockECS = MockECS.new()
	var eco3: MockEconomySystem = MockEconomySystem.new()
	eco3.init_faction(0, 1000.0, 0.0)
	var sys3: ProductionSystem = _make_production_system(ecs3, eco3)
	var factory3: int = _make_factory(ecs3, 1.0, 0)

	sys3.queue_unit(factory3, "medium_tank", ecs3)  # cost 100
	sys3.queue_unit(factory3, "rifleman", ecs3)      # cost 50
	sys3.queue_unit(factory3, "rifleman", ecs3)      # cost 50

	var res_before_death: float = eco3.resources[0]["primary"]
	sys3.on_building_destroyed(factory3, ecs3)
	var total_refund: float = eco3.resources[0]["primary"] - res_before_death

	var q3: Dictionary = ecs3.get_component(factory3, "ProductionQueue")
	var queue_cleared: bool = q3["queue"].size() == 0

	# 50% of (100 + 50 + 50) = 100
	if absf(total_refund - 100.0) < 0.01 and queue_cleared:
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 FAIL: expected refund=100.0 got=%.1f queue_cleared=%s" % [total_refund, str(queue_cleared)])

	# ── Test 4: Rally point — spawned unit gets MoveCommand ────────────────
	var ecs4: MockECS = MockECS.new()
	var eco4: MockEconomySystem = MockEconomySystem.new()
	eco4.init_faction(0, 1000.0, 0.0)
	var sys4: ProductionSystem = _make_production_system(ecs4, eco4)
	var factory4: int = _make_factory(ecs4, 1.0, 0)

	var rally_pos: Vector2 = Vector2(200.0, 200.0)
	ecs4.set_component(factory4, "RallyPoint", {"position": rally_pos})
	sys4.queue_unit(factory4, "rifleman", ecs4)

	# rifleman: build_time=5s × 15 ticks/sec = 75 ticks
	for _t in range(75):
		sys4.tick(ecs4, _t)

	var found_rally_move: bool = false
	for entity_id in ecs4.get_all_entities():
		if entity_id == factory4:
			continue
		var mc: Dictionary = ecs4.get_component(entity_id, "MoveCommand")
		if not mc.is_empty() and mc.get("destination", Vector2.ZERO).is_equal_approx(rally_pos):
			found_rally_move = true
			break

	var q4: Dictionary = ecs4.get_component(factory4, "ProductionQueue")
	if found_rally_move and q4["queue"].size() == 0:
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 FAIL: found_rally_move=%s queue_size=%d" % [str(found_rally_move), q4["queue"].size()])

	# ── Test 5: PoweredOff → production paused; resumes on power restore ───
	var ecs5: MockECS = MockECS.new()
	var eco5: MockEconomySystem = MockEconomySystem.new()
	eco5.init_faction(0, 1000.0, 0.0)
	var sys5: ProductionSystem = _make_production_system(ecs5, eco5)
	var factory5: int = _make_factory(ecs5, 1.0, 0)

	sys5.queue_unit(factory5, "medium_tank", ecs5)

	ecs5.set_component(factory5, "PoweredOff", {})
	for _t in range(90):
		sys5.tick(ecs5, _t)

	var q5_off: Dictionary = ecs5.get_component(factory5, "ProductionQueue")
	var progress_while_off: float = q5_off.get("progress", 0.0)
	var still_in_queue: bool = q5_off["queue"].size() > 0

	ecs5.remove_component(factory5, "PoweredOff")
	for _t in range(180):
		sys5.tick(ecs5, 90 + _t)

	var q5_on: Dictionary = ecs5.get_component(factory5, "ProductionQueue")
	var spawned_after_restore: bool = q5_on["queue"].size() == 0

	if absf(progress_while_off) < 0.01 and still_in_queue and spawned_after_restore:
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 FAIL: progress_while_off=%.2f still_in_queue=%s spawned_after=%s" % [progress_while_off, str(still_in_queue), str(spawned_after_restore)])

	return {"passed": passed, "failed": failed, "errors": errors}
