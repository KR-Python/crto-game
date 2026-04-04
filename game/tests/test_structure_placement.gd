class_name TestStructurePlacement
extends Node

# Structure placement system tests.
# Run via: godot --headless --script game/tests/test_structure_placement.gd

var _structure_system: StructureSystem
var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	_structure_system = StructureSystem.new()

	test_1_valid_placement()
	test_2_insufficient_resources()
	test_3_overlapping_placement()
	test_4_build_progress_advances()
	test_5_cancel_before_complete()
	test_6_destroy_unblocks_navgrid()
	test_7_build_requirements_not_met()

	print("\n=== Structure Placement Tests: %d passed, %d failed ===" % [_passed, _failed])
	if _failed > 0:
		push_error("TESTS FAILED")
	get_tree().quit(1 if _failed > 0 else 0)


# ── Test Cases ────────────────────────────────────────────────────────────────

func test_1_valid_placement() -> void:
	print("\nTest 1: Valid placement — structure entity created, cost deducted")
	var ecs := _make_ecs()
	var economy := _make_economy({0: {primary = 2000.0, secondary = 0.0}})
	var nav_grid := _make_nav_grid(32, 32)

	_structure_system.economy_system = economy
	_structure_system.nav_grid = nav_grid
	_structure_system.entity_factory = null  # use internal fallback

	var result: Dictionary = _structure_system.place_structure(0, "aegis_barracks", Vector2(5.0, 5.0), ecs)

	_assert_true(result["success"], "placement succeeded")
	_assert_true(result["entity_id"] > 0, "entity_id is valid")
	_assert_eq(result["error"], "", "no error")

	# Entity exists with Structure component
	_assert_true(ecs.entity_exists(result["entity_id"]), "entity exists in ECS")
	var structure: Dictionary = ecs.get_component(result["entity_id"], "Structure")
	_assert_true(not structure.is_empty(), "Structure component present")
	_assert_true(not structure.get("built", true), "structure not yet built")
	_assert_eq(structure.get("build_progress", -1.0), 0.0, "build_progress starts at 0")

	# Cost was deducted
	_assert_true(economy.was_spent(0, 600.0, 0.0), "cost deducted from faction resources")


func test_2_insufficient_resources() -> void:
	print("\nTest 2: Insufficient resources — placement rejected")
	var ecs := _make_ecs()
	var economy := _make_economy({0: {primary = 100.0, secondary = 0.0}})  # only 100, need 600
	var nav_grid := _make_nav_grid(32, 32)

	_structure_system.economy_system = economy
	_structure_system.nav_grid = nav_grid

	var result: Dictionary = _structure_system.place_structure(0, "aegis_barracks", Vector2(5.0, 5.0), ecs)

	_assert_true(not result["success"], "placement rejected")
	_assert_eq(result["error"], "INSUFFICIENT_RESOURCES", "correct error code")
	_assert_eq(result["entity_id"], -1, "no entity id on failure")

	# No entity was created
	var structs: Array = ecs.query(["Structure"])
	_assert_eq(structs.size(), 0, "no structure entity created")

	# No cost deducted
	_assert_true(not economy.was_spent(0, 600.0, 0.0), "no cost deducted")


func test_3_overlapping_placement() -> void:
	print("\nTest 3: Overlapping placement — rejected")
	var ecs := _make_ecs()
	var economy := _make_economy({0: {primary = 5000.0, secondary = 0.0}})
	var nav_grid := _make_nav_grid(32, 32)

	_structure_system.economy_system = economy
	_structure_system.nav_grid = nav_grid

	# Place first barracks at (5, 5) — footprint 2x2
	var result1: Dictionary = _structure_system.place_structure(0, "aegis_barracks", Vector2(5.0, 5.0), ecs)
	_assert_true(result1["success"], "first placement succeeds")

	# Try to place second barracks overlapping (footprint 2x2, overlaps at 6,6)
	var result2: Dictionary = _structure_system.place_structure(0, "aegis_barracks", Vector2(5.0, 5.0), ecs)
	_assert_true(not result2["success"], "overlapping placement rejected")
	_assert_eq(result2["error"], "OVERLAPPING_STRUCTURE", "correct error code")

	# Only 1 structure in ECS
	var structs: Array = ecs.query(["Structure"])
	_assert_eq(structs.size(), 1, "only one structure entity created")


func test_4_build_progress_advances() -> void:
	print("\nTest 4: Build progress advances each tick until complete")
	var ecs := _make_ecs()
	var economy := _make_economy({0: {primary = 5000.0, secondary = 0.0}})
	var nav_grid := _make_nav_grid(32, 32)

	_structure_system.economy_system = economy
	_structure_system.nav_grid = nav_grid

	# Place aegis_barracks: build_time = 12.0 seconds = 180 ticks
	var result: Dictionary = _structure_system.place_structure(0, "aegis_barracks", Vector2(5.0, 5.0), ecs)
	_assert_true(result["success"], "placement succeeded")
	var entity_id: int = result["entity_id"]

	# Tick 89 times — not yet complete (180 ticks needed)
	for i in range(89):
		_structure_system.tick(ecs, i)

	var structure: Dictionary = ecs.get_component(entity_id, "Structure")
	_assert_true(not structure.get("built", true), "not yet built at tick 89")
	_assert_true(structure.get("build_progress", 0.0) > 0.0, "build_progress > 0")

	# Tick until complete (total 180 ticks)
	for i in range(89, 180):
		_structure_system.tick(ecs, i)

	structure = ecs.get_component(entity_id, "Structure")
	_assert_true(structure.get("built", false), "structure built after 180 ticks")

	# PowerConsumer should now be added (barracks has drain=20)
	_assert_true(ecs.has_component(entity_id, "PowerConsumer"), "PowerConsumer added after build")


func test_5_cancel_before_complete() -> void:
	print("\nTest 5: Cancel before complete — full refund, entity removed")
	var ecs := _make_ecs()
	var economy := _make_economy({0: {primary = 5000.0, secondary = 0.0}})
	var nav_grid := _make_nav_grid(32, 32)

	_structure_system.economy_system = economy
	_structure_system.nav_grid = nav_grid

	var result: Dictionary = _structure_system.place_structure(0, "aegis_barracks", Vector2(5.0, 5.0), ecs)
	_assert_true(result["success"], "placement succeeded")
	var entity_id: int = result["entity_id"]

	# Advance partway through build
	for i in range(30):
		_structure_system.tick(ecs, i)

	var structure: Dictionary = ecs.get_component(entity_id, "Structure")
	_assert_true(not structure.get("built", true), "not yet built")

	# Cancel — expect full refund
	_structure_system.cancel_structure(entity_id, ecs)

	_assert_true(not ecs.entity_exists(entity_id), "entity removed after cancel")
	_assert_true(economy.was_refunded(0, 600.0, 0.0), "full refund issued")

	# NavGrid cells should be unblocked
	var cell := nav_grid.world_to_cell(Vector2(5.0, 5.0))
	_assert_true(nav_grid.is_walkable(cell.x, cell.y, NavGrid.MOVE_FOOT), "NavGrid cell unblocked after cancel")


func test_6_destroy_unblocks_navgrid() -> void:
	print("\nTest 6: Structure destroyed — NavGrid cells unblocked")
	var ecs := _make_ecs()
	var economy := _make_economy({0: {primary = 5000.0, secondary = 0.0}})
	var nav_grid := _make_nav_grid(32, 32)

	_structure_system.economy_system = economy
	_structure_system.nav_grid = nav_grid

	var result: Dictionary = _structure_system.place_structure(0, "aegis_barracks", Vector2(4.0, 4.0), ecs)
	_assert_true(result["success"], "placement succeeded")
	var entity_id: int = result["entity_id"]

	# Verify cells are blocked before destroy
	var cell := nav_grid.world_to_cell(Vector2(4.0, 4.0))
	_assert_true(not nav_grid.is_walkable(cell.x, cell.y, NavGrid.MOVE_FOOT), "NavGrid cell blocked after placement")

	# Destroy
	var destroyed_emitted: bool = false
	_structure_system.structure_destroyed.connect(func(_eid, _st, _pos): destroyed_emitted = true)
	_structure_system.destroy_structure(entity_id, ecs)

	_assert_true(not ecs.entity_exists(entity_id), "entity removed after destroy")
	_assert_true(destroyed_emitted, "structure_destroyed signal emitted")
	_assert_true(nav_grid.is_walkable(cell.x, cell.y, NavGrid.MOVE_FOOT), "NavGrid cell unblocked after destroy")
	# No refund on destroy
	_assert_true(not economy.was_refunded(0, 600.0, 0.0), "no refund on destroy")


func test_7_build_requirements_not_met() -> void:
	print("\nTest 7: Build requirements not met — rejected (war factory needs barracks)")
	var ecs := _make_ecs()
	var economy := _make_economy({0: {primary = 5000.0, secondary = 0.0}})
	var nav_grid := _make_nav_grid(32, 32)

	_structure_system.economy_system = economy
	_structure_system.nav_grid = nav_grid

	# Try placing war factory without a barracks
	var result: Dictionary = _structure_system.place_structure(0, "aegis_war_factory", Vector2(5.0, 5.0), ecs)
	_assert_true(not result["success"], "placement rejected without barracks")
	_assert_eq(result["error"], "BUILD_REQUIREMENTS_NOT_MET", "correct error code")

	# Now add a built barracks to the ECS and try again
	var barracks_id: int = ecs.create_entity()
	ecs.add_component(barracks_id, "Structure", {
		"structure_type": "aegis_barracks",
		"built": true,
		"build_progress": 180.0,
	})
	ecs.add_component(barracks_id, "FactionComponent", {"faction_id": 0})
	ecs.add_component(barracks_id, "Position", {"x": 0.0, "y": 0.0})
	ecs.add_component(barracks_id, "Footprint", {"width": 2, "height": 2})

	var result2: Dictionary = _structure_system.place_structure(0, "aegis_war_factory", Vector2(5.0, 5.0), ecs)
	_assert_true(result2["success"], "placement succeeds after barracks built")


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_ecs() -> ECS:
	return ECS.new()


func _make_nav_grid(w: int, h: int) -> NavGrid:
	return NavGrid.new(w, h)


func _make_economy(faction_resources: Dictionary) -> MockEconomy:
	var eco := MockEconomy.new()
	for faction_id in faction_resources:
		eco.set_resources(faction_id, faction_resources[faction_id])
	return eco


func _assert_true(condition: bool, msg: String) -> void:
	if condition:
		_passed += 1
		print("  ✓ %s" % msg)
	else:
		_failed += 1
		print("  ✗ FAIL: %s" % msg)


func _assert_eq(a: Variant, b: Variant, msg: String) -> void:
	if a == b:
		_passed += 1
		print("  ✓ %s" % msg)
	else:
		_failed += 1
		print("  ✗ FAIL: %s — expected %s, got %s" % [msg, str(b), str(a)])


# ── Mock Economy ──────────────────────────────────────────────────────────────

class MockEconomy:
	extends RefCounted

	# faction_id -> {primary, secondary}
	var _resources: Dictionary = {}
	# list of {faction_id, primary, secondary} spent calls
	var _spends: Array = []
	# list of {faction_id, primary, secondary} refund calls
	var _refunds: Array = []

	func set_resources(faction_id: int, res: Dictionary) -> void:
		_resources[faction_id] = {
			"primary": res.get("primary", 0.0),
			"secondary": res.get("secondary", 0.0),
		}

	func get_resources(faction_id: int) -> Dictionary:
		if not _resources.has(faction_id):
			return {"primary": 0.0, "secondary": 0.0, "income_rate": 0.0, "spend_rate": 0.0, "power_balance": 0.0}
		var r: Dictionary = _resources[faction_id]
		return {
			"primary": r.get("primary", 0.0),
			"secondary": r.get("secondary", 0.0),
			"income_rate": 0.0,
			"spend_rate": 0.0,
			"power_balance": 0.0,
		}

	func spend(faction_id: int, primary: float, secondary: float) -> bool:
		if not _resources.has(faction_id):
			return false
		var r: Dictionary = _resources[faction_id]
		if r.get("primary", 0.0) < primary or r.get("secondary", 0.0) < secondary:
			return false
		r["primary"] -= primary
		r["secondary"] -= secondary
		_spends.append({"faction_id": faction_id, "primary": primary, "secondary": secondary})
		return true

	func refund(faction_id: int, primary: float, secondary: float) -> void:
		if _resources.has(faction_id):
			_resources[faction_id]["primary"] += primary
			_resources[faction_id]["secondary"] += secondary
		_refunds.append({"faction_id": faction_id, "primary": primary, "secondary": secondary})

	func was_spent(faction_id: int, primary: float, secondary: float) -> bool:
		for s in _spends:
			if s["faction_id"] == faction_id and absf(s["primary"] - primary) < 0.01 and absf(s["secondary"] - secondary) < 0.01:
				return true
		return false

	func was_refunded(faction_id: int, primary: float, secondary: float) -> bool:
		for r in _refunds:
			if r["faction_id"] == faction_id and absf(r["primary"] - primary) < 0.01 and absf(r["secondary"] - secondary) < 0.01:
				return true
		return false
