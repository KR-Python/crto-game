class_name TestVision
## Tests for VisionSystem.
## Uses inline MockECS to run without Godot scene tree.

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
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

static func _add_unit(ecs: MockECS, pos: Vector2, faction_id: int, vision_range: float = 0.0) -> int:
	var id: int = ecs.create_entity()
	ecs.set_component(id, "Position", {"x": pos.x, "y": pos.y})
	ecs.set_component(id, "FactionComponent", {"faction_id": faction_id})
	if vision_range > 0.0:
		ecs.set_component(id, "VisionRange", {"range": vision_range})
	return id


static func _make_vision_system() -> VisionSystem:
	var sys: VisionSystem = VisionSystem.new()
	# Faction 0 and 1 share team 0; faction 2 is on team 1
	sys.register_faction_team(0, 0)
	sys.register_faction_team(1, 0)
	sys.register_faction_team(2, 1)
	return sys


# ─────────────────────────────────────────────────────────────────────────────
# Tests
# ─────────────────────────────────────────────────────────────────────────────

static func run_all() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var errors: Array = []

	# ── Test 1: Unit in range → fog cell VISIBLE ───────────────────────────
	# Unit at (10,10), VisionRange=8. fog_range=ceil(8/2)=4 cells.
	# Cell at (14,10) is 2 fog cells away (within 4-cell radius).
	var ecs1: MockECS = MockECS.new()
	var sys1: VisionSystem = _make_vision_system()
	_add_unit(ecs1, Vector2(10.0, 10.0), 0, 8.0)

	sys1.tick(ecs1, 0)

	var state_center: int = sys1.get_fog_state(Vector2(10.0, 10.0), 0)
	var state_nearby: int = sys1.get_fog_state(Vector2(14.0, 10.0), 0)
	var state_far: int = sys1.get_fog_state(Vector2(30.0, 10.0), 0)

	if state_center == VisionSystem.VISIBLE and state_nearby == VisionSystem.VISIBLE and state_far != VisionSystem.VISIBLE:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 FAIL: center=%d nearby=%d far=%d (expected 2,2,not-2)" % [state_center, state_nearby, state_far])

	# ── Test 2: Unit moves out → cell becomes SEEN (not UNEXPLORED) ────────
	var ecs2: MockECS = MockECS.new()
	var sys2: VisionSystem = _make_vision_system()
	var unit2: int = _add_unit(ecs2, Vector2(10.0, 10.0), 0, 8.0)

	sys2.tick(ecs2, 0)
	var was_visible: bool = sys2.get_fog_state(Vector2(10.0, 10.0), 0) == VisionSystem.VISIBLE

	ecs2.set_component(unit2, "Position", {"x": 200.0, "y": 200.0})
	sys2.tick(ecs2, 1)

	var state_after: int = sys2.get_fog_state(Vector2(10.0, 10.0), 0)

	if was_visible and state_after == VisionSystem.SEEN:
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 FAIL: was_visible=%s state_after=%d (expected SEEN=1)" % [str(was_visible), state_after])

	# ── Test 3: Stealth unit not visible outside detection range ───────────
	# Stealthed at (20,10), detection_range=2. No detector from team 0 nearby.
	var ecs3: MockECS = MockECS.new()
	var sys3: VisionSystem = _make_vision_system()

	_add_unit(ecs3, Vector2(10.0, 10.0), 0, 8.0)
	var stealthed3: int = _add_unit(ecs3, Vector2(20.0, 10.0), 2, 0.0)
	ecs3.set_component(stealthed3, "Stealthed", {"detection_range": 2.0})

	sys3.tick(ecs3, 0)

	var detectable3: bool = sys3.is_entity_detectable(stealthed3, 0, ecs3)

	if not detectable3:
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 FAIL: stealth incorrectly detected at distance 10 (expected false)")

	# ── Test 4: Detector reveals stealth within range ──────────────────────
	# Detector at (10,10) range=6. Stealthed at (14,10) distance=4 → detected.
	var ecs4: MockECS = MockECS.new()
	var sys4: VisionSystem = _make_vision_system()

	var detector4: int = _add_unit(ecs4, Vector2(10.0, 10.0), 0, 8.0)
	ecs4.set_component(detector4, "Detector", {"range": 6.0})

	var stealthed4: int = _add_unit(ecs4, Vector2(14.0, 10.0), 2, 0.0)
	ecs4.set_component(stealthed4, "Stealthed", {"detection_range": 2.0})

	sys4.tick(ecs4, 0)

	var detected4: bool = sys4.is_entity_detectable(stealthed4, 0, ecs4)

	if detected4:
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 FAIL: detector range=6 should reveal stealth at distance=4")

	# ── Test 5: Team vision — factions on same team share fog state ────────
	# Faction 0 lights up (10,10). Faction 1 (same team) should see it. Faction 2 (enemy) should not.
	var ecs5: MockECS = MockECS.new()
	var sys5: VisionSystem = _make_vision_system()

	_add_unit(ecs5, Vector2(10.0, 10.0), 0, 8.0)
	sys5.tick(ecs5, 0)

	var state_f0: int = sys5.get_fog_state(Vector2(10.0, 10.0), 0)
	var state_f1: int = sys5.get_fog_state(Vector2(10.0, 10.0), 1)
	var state_f2: int = sys5.get_fog_state(Vector2(10.0, 10.0), 2)

	if state_f0 == VisionSystem.VISIBLE and state_f1 == VisionSystem.VISIBLE and state_f2 != VisionSystem.VISIBLE:
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 FAIL: faction0=%d faction1=%d faction2=%d (expected 2,2,not-2)" % [state_f0, state_f1, state_f2])

	return {"passed": passed, "failed": failed, "errors": errors}
