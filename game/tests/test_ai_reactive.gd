class_name TestAIReactive
extends RefCounted
## Unit tests for ReactiveAI and PersonalityDriver.
## Run via: GDScript test runner or manual invocation.

var _passed: int = 0
var _failed: int = 0


func run_all() -> Dictionary:
	_passed = 0
	_failed = 0

	test_attack_when_strength_exceeds_threshold()
	test_defend_when_base_under_attack()
	test_tech_when_resources_high_enemy_t1()
	test_scouting_updates_enemy_tech_tier()
	test_retreat_when_army_drops_below_40_percent()
	test_personality_driver_applies_attack_weight()
	test_no_attack_before_first_attack_tick()

	return {"passed": _passed, "failed": _failed, "total": _passed + _failed}


## 1. ReactiveAI switches to "attack" when army_ratio > threshold
func test_attack_when_strength_exceeds_threshold() -> void:
	var ai := ReactiveAI.new()
	ai._first_attack_tick = 0  # allow attacks immediately
	# Give AI a strong army (strength >> 300 base estimate * 1.3)
	ai.army_entities = _make_units(10, 200.0, 30.0)  # strength ~600
	ai.economy_resources = {"primary": 500, "secondary": 100}

	ai._evaluate_situation(100)
	_assert_eq(ai.get_strategic_goal(), "attack", "Should attack when strength ratio > threshold")


## 2. ReactiveAI switches to "defend" when base under attack
func test_defend_when_base_under_attack() -> void:
	var ai := ReactiveAI.new()
	ai.set_under_attack(true)
	ai.army_entities = _make_units(5, 100.0, 10.0)
	ai.economy_resources = {"primary": 500, "secondary": 100}

	ai._evaluate_situation(100)
	_assert_eq(ai.get_strategic_goal(), "defend", "Should defend when base under attack")


## 3. ReactiveAI switches to "tech" when resources high + enemy is T1
func test_tech_when_resources_high_enemy_t1() -> void:
	var ai := ReactiveAI.new()
	ai._first_attack_tick = 99999  # prevent attack
	ai.army_entities = []  # weak army → won't attack
	ai.economy_resources = {"primary": 3000, "secondary": 500}
	ai._enemy_tech_tier = 1

	ai._evaluate_situation(100)
	_assert_eq(ai.get_strategic_goal(), "tech", "Should tech when resources high and enemy T1")


## 4. Scouting updates enemy_tech_tier when tech structure detected
func test_scouting_updates_enemy_tech_tier() -> void:
	var ai := ReactiveAI.new()
	_assert_eq(ai._enemy_tech_tier, 1, "Should start at T1")

	ai.add_scouted_structure(100, {"structure_type": "tech_lab", "position": Vector2(500, 500)})
	ai._update_scouting(50)
	_assert_eq(ai._enemy_tech_tier, 2, "Should update to T2 after seeing tech_lab")


## 5. Retreat triggered when army drops below 40% of attack-start strength
func test_retreat_when_army_drops_below_40_percent() -> void:
	var ai := ReactiveAI.new()
	ai._first_attack_tick = 0
	ai.base_position = Vector2(100, 100)
	ai.attack_target = Vector2(500, 500)

	# Start attack with strong army
	ai.army_entities = _make_units(10, 200.0, 30.0)
	ai.economy_resources = {"primary": 500, "secondary": 100}
	ai._evaluate_situation(100)
	_assert_eq(ai.get_strategic_goal(), "attack", "Should be attacking")

	var start_strength: float = ai._attack_start_strength
	_assert_true(start_strength > 0.0, "Attack start strength should be recorded")

	# Decimate army — drop to ~20% of original
	ai.army_entities = _make_units(2, 100.0, 10.0)
	ai._run_attack(200)

	# After retreat, goal should switch away from attack
	_assert_eq(ai.get_strategic_goal(), "build", "Should retreat to build after heavy losses")

	# Should have issued a Retreat command
	var cmds := ai.get_commands()
	var has_retreat := false
	for cmd in cmds:
		if cmd["type"] == "Retreat":
			has_retreat = true
			break
	_assert_true(has_retreat, "Should emit Retreat command")


## 6. PersonalityDriver applies attack weight (Volkov: 1.8 → lower threshold)
func test_personality_driver_applies_attack_weight() -> void:
	var volkov_config := {
		"strategy_weights": {"attack": 1.8, "defend": 0.4},
		"behavior": {
			"first_attack_tick": 600,
			"retreat_threshold": 0.3,
			"preferred_composition": {"vehicles": 0.6, "infantry": 0.3, "air": 0.1},
		},
		"difficulty_modifiers": {
			"reaction_time_ticks": 5,
			"multi_prong_attacks": true,
		},
	}

	var driver := PersonalityDriver.new(volkov_config)
	var ai := ReactiveAI.new()
	driver.apply_to_ai(ai)

	# 1.3 / 1.8 ≈ 0.722
	_assert_true(ai._attack_threshold_ratio < 1.0, "Volkov should have low attack threshold")
	_assert_eq(ai._first_attack_tick, 600, "First attack tick from personality")
	_assert_true(ai._retreat_threshold < 0.4, "Volkov retreats later (0.3)")
	_assert_true(driver.should_multi_prong(), "Volkov does multi-prong")


## 7. ReactiveAI doesn't attack before first_attack_tick
func test_no_attack_before_first_attack_tick() -> void:
	var ai := ReactiveAI.new()
	ai._first_attack_tick = 900
	ai.army_entities = _make_units(10, 200.0, 30.0)  # very strong
	ai.economy_resources = {"primary": 500, "secondary": 100}

	# Evaluate at tick 100 (before first_attack_tick)
	ai._evaluate_situation(100)
	_assert_true(ai.get_strategic_goal() != "attack", "Should NOT attack before first_attack_tick")

	# Evaluate at tick 1000 (after first_attack_tick)
	ai._evaluate_situation(1000)
	_assert_eq(ai.get_strategic_goal(), "attack", "Should attack after first_attack_tick")


# ===========================================================================
# Helpers
# ===========================================================================

func _make_units(count: int, health: float, dps: float) -> Array:
	var units: Array = []
	for i in count:
		units.append({"health": health, "dps": dps, "type": "infantry"})
	return units


func _assert_eq(actual, expected, msg: String) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		push_error("FAIL: %s — expected '%s', got '%s'" % [msg, str(expected), str(actual)])


func _assert_true(condition: bool, msg: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		push_error("FAIL: %s" % msg)
