class_name TestEndlessDefense
extends RefCounted
## Unit tests for EndlessDefenseSystem.
## Run via: GDScript test runner or manual invocation.

var _passed: int = 0
var _failed: int = 0


func run_all() -> Dictionary:
	_passed = 0
	_failed = 0

	test_wave_1_composition_only_t1_units()
	test_wave_10_composition_includes_t3_units()
	test_budget_scales_per_wave_formula()
	test_wave_complete_triggers_when_all_enemies_dead()
	test_game_over_when_construction_yard_destroyed()

	return {"passed": _passed, "failed": _failed, "total": _passed + _failed}


# ── Test 1 ────────────────────────────────────────────────────────────────────
## Wave 1 composition must contain only T1 units (conscripts, attack bikes).
func test_wave_1_composition_only_t1_units() -> void:
	var system := _make_system()
	var composition: Array = system._generate_wave_composition(1)

	_assert_false(composition.is_empty(), "Wave 1 composition should not be empty")

	var t1_types: Array = [
		EndlessDefenseSystem.UNIT_CONSCRIPT,
		EndlessDefenseSystem.UNIT_ATTACK_BIKE,
	]
	for entry in composition:
		_assert_true(
			entry.type in t1_types,
			"Wave 1 should only contain T1 units, got: %s" % entry.type
		)


# ── Test 2 ────────────────────────────────────────────────────────────────────
## Wave 10 composition must include at least one T3 or T4 unit.
func test_wave_10_composition_includes_t3_units() -> void:
	var system := _make_system()
	var composition: Array = system._generate_wave_composition(10)

	var t3_or_t4_types: Array = [
		EndlessDefenseSystem.UNIT_ROCKET_BUGGY,
		EndlessDefenseSystem.UNIT_HELICOPTER,
		EndlessDefenseSystem.UNIT_MAMMOTH_TANK,
		EndlessDefenseSystem.UNIT_CHEM_TROOPER,
	]

	var found_advanced: bool = false
	for entry in composition:
		if entry.type in t3_or_t4_types:
			found_advanced = true
			break

	_assert_true(found_advanced, "Wave 10 composition should include T3+ units")


# ── Test 3 ────────────────────────────────────────────────────────────────────
## Budget used in _fill_budget must match 500 + (wave * 200) formula.
func test_budget_scales_per_wave_formula() -> void:
	var cases: Dictionary = {1: 700, 5: 1500, 10: 2500, 20: 4500}

	for wave in cases:
		var expected_budget: int = cases[wave]
		var actual_budget: int   = 500 + (wave * 200)
		_assert_eq(
			actual_budget,
			expected_budget,
			"Budget for wave %d should be %d, got %d" % [wave, expected_budget, actual_budget]
		)

	# Also verify the composition total cost does not exceed the budget.
	var system := _make_system()
	for wave in [1, 5, 10]:
		var budget: int      = 500 + (wave * 200)
		var composition      = system._generate_wave_composition(wave)
		var total_cost: int  = 0
		for entry in composition:
			total_cost += EndlessDefenseSystem.UNIT_COST[entry.type] * entry.count
		_assert_true(
			total_cost <= budget,
			"Wave %d total cost %d must not exceed budget %d" % [wave, total_cost, budget]
		)


# ── Test 4 ────────────────────────────────────────────────────────────────────
## wave_defeated signal fires when ECS reports zero enemy faction entities.
func test_wave_complete_triggers_when_all_enemies_dead() -> void:
	var system := _make_system()
	system.current_wave     = 3
	system.wave_in_progress = true

	# Capture signal emissions.
	var defeated_wave: int       = -1
	var defeated_resources: int  = -1
	system.wave_defeated.connect(func(w, r): defeated_wave = w; defeated_resources = r)

	# ECS stub — no enemy faction entities remaining.
	var ecs := _make_ecs_stub([])
	system._check_wave_complete(ecs)

	_assert_eq(defeated_wave, 3, "wave_defeated should fire with current wave number")
	_assert_true(defeated_resources > 0, "wave_defeated should report positive resource reward")
	_assert_false(system.wave_in_progress, "wave_in_progress should be false after completion")


# ── Test 5 ────────────────────────────────────────────────────────────────────
## game_over signal fires when no Construction Yard with faction_id=0 exists.
func test_game_over_when_construction_yard_destroyed() -> void:
	var system := _make_system()
	system.current_wave = 7

	var game_over_waves: int = -1
	system.game_over.connect(func(w): game_over_waves = w)

	# ECS stub — no construction yard for faction 0.
	var ecs := _make_ecs_stub_no_cy()
	system.check_game_over(ecs)

	_assert_eq(game_over_waves, 7, "game_over should fire with current wave count when CY is gone")


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_system() -> EndlessDefenseSystem:
	var system := EndlessDefenseSystem.new()
	var rng    := RandomNumberGenerator.new()
	rng.seed = 12345
	system.init_seed(12345)
	return system


## ECS stub whose query() returns entity mocks representing enemy faction units.
## entity_list: Array of Dictionaries {faction_id, has_health, building_type?}
func _make_ecs_stub(entity_list: Array) -> Object:
	return _ECSStub.new(entity_list)


## ECS stub with no construction yard for faction 0.
func _make_ecs_stub_no_cy() -> Object:
	# One enemy unit present, but no player CY.
	return _ECSStubNoCY.new()


# ── ECS stub implementations ─────────────────────────────────────────────────

class _ECSStub extends RefCounted:
	var _entities: Array

	func _init(entities: Array) -> void:
		_entities = entities

	func query(_components: Array) -> Array:
		# Return sequential fake IDs.
		var ids: Array = []
		for i in range(_entities.size()):
			ids.append(i)
		return ids

	func get_component(entity_id: int, component: String) -> Object:
		var data: Dictionary = _entities[entity_id]
		if component == "faction":
			return _FactionComp.new(data.get("faction_id", 1))
		if component == "health":
			return _HealthComp.new()
		if component == "building_type":
			return _BuildingComp.new(data.get("building_type", ""))
		return null

	func has_global(_key: String) -> bool:
		return false


class _ECSStubNoCY extends RefCounted:
	## Simulates a state where the player CY has been destroyed.
	## building_type + faction queries return nothing for faction 0.

	func query(components: Array) -> Array:
		if "building_type" in components:
			return []   # no buildings with faction component
		return []

	func get_component(_id: int, _comp: String) -> Object:
		return null

	func has_global(_key: String) -> bool:
		return false


class _FactionComp extends RefCounted:
	var faction_id: int
	func _init(id: int) -> void:
		faction_id = id


class _HealthComp extends RefCounted:
	pass


class _BuildingComp extends RefCounted:
	var type_id: String
	func _init(t: String) -> void:
		type_id = t


# ── Assertion helpers ─────────────────────────────────────────────────────────

func _assert_eq(actual, expected, msg: String) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		push_error("FAIL: %s\n  expected: %s\n  actual:   %s" % [msg, str(expected), str(actual)])


func _assert_true(condition: bool, msg: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		push_error("FAIL: %s" % msg)


func _assert_false(condition: bool, msg: String) -> void:
	_assert_true(not condition, msg)
