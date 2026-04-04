class_name TestCombat
extends Node

# Combat system deterministic tests.
# Run via: godot --headless --script game/tests/test_combat.gd

var _combat_system: CombatSystem
var _death_system: DeathSystem
var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	_combat_system = CombatSystem.new()
	_death_system = DeathSystem.new()

	test_kinetic_vs_heavy_armor()
	test_explosive_vs_light_armor()
	test_aoe_friendly_fire()
	test_cooldown_no_double_fire()
	test_auto_acquire_enemy_in_range()
	test_attack_command_overrides_auto()
	test_target_dies_mid_attack()
	test_no_valid_targets_does_nothing()

	print("\n=== Combat Tests: %d passed, %d failed ===" % [_passed, _failed])
	if _failed > 0:
		push_error("TESTS FAILED")
	get_tree().quit(1 if _failed > 0 else 0)


# --- Helper: create a minimal mock ECS ---

func _make_ecs() -> MockECS:
	return MockECS.new()


func _spawn_unit(ecs: MockECS, id: int, x: float, y: float, faction: int,
		health_max: float = 100.0, armor_type: String = "medium") -> void:
	ecs.add_entity(id)
	ecs.set_component(id, "Position", {"x": x, "y": y})
	ecs.set_component(id, "FactionComponent", {"faction_id": faction})
	ecs.set_component(id, "Health", {"current": health_max, "max": health_max, "armor_type": armor_type})
	ecs.set_component(id, "Attackable", {})


func _arm_unit(ecs: MockECS, id: int, damage: float, range_val: float,
		cooldown: float, damage_type: String = "kinetic",
		targets: Array = ["ground"], aoe: float = 0.0) -> void:
	ecs.set_component(id, "Weapon", {
		"damage": damage,
		"range": range_val,
		"cooldown": cooldown,
		"cooldown_remaining": 0.0,
		"damage_type": damage_type,
		"targets": targets,
		"area_of_effect": aoe,
	})


func _assert_approx(actual: float, expected: float, test_name: String, tolerance: float = 0.01) -> void:
	if absf(actual - expected) <= tolerance:
		_passed += 1
		print("  PASS: %s (%.2f ≈ %.2f)" % [test_name, actual, expected])
	else:
		_failed += 1
		print("  FAIL: %s (got %.2f, expected %.2f)" % [test_name, actual, expected])


func _assert_true(condition: bool, test_name: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % test_name)
	else:
		_failed += 1
		print("  FAIL: %s" % test_name)


# --- Tests ---

func test_kinetic_vs_heavy_armor() -> void:
	print("\nTest 1: Kinetic vs heavy armor (0.5x)")
	var ecs := _make_ecs()
	_spawn_unit(ecs, 1, 0.0, 0.0, 0)  # attacker
	_arm_unit(ecs, 1, 85.0, 7.0, 2.0, "kinetic", ["ground"])
	_spawn_unit(ecs, 2, 5.0, 0.0, 1, 450.0, "heavy")  # target

	_combat_system.tick(ecs, 0)

	var hp: float = ecs.get_component(2, "Health")["current"]
	# 85 * 0.5 = 42.5 → 450 - 42.5 = 407.5
	_assert_approx(hp, 407.5, "target health after kinetic vs heavy")


func test_explosive_vs_light_armor() -> void:
	print("\nTest 2: Explosive vs light armor (1.5x)")
	var ecs := _make_ecs()
	_spawn_unit(ecs, 1, 0.0, 0.0, 0)
	_arm_unit(ecs, 1, 100.0, 10.0, 1.0, "explosive", ["ground"])
	_spawn_unit(ecs, 2, 5.0, 0.0, 1, 500.0, "light")

	_combat_system.tick(ecs, 0)

	var hp: float = ecs.get_component(2, "Health")["current"]
	# 100 * 1.5 = 150 → 500 - 150 = 350
	_assert_approx(hp, 350.0, "target health after explosive vs light")


func test_aoe_friendly_fire() -> void:
	print("\nTest 3: AoE — enemies 100%, friendlies 50%")
	var ecs := _make_ecs()
	# Attacker: faction 0, explosive AoE weapon
	_spawn_unit(ecs, 1, 0.0, 0.0, 0)
	_arm_unit(ecs, 1, 100.0, 15.0, 1.0, "explosive", ["ground"], 3.0)
	# Primary target: faction 1 at (10, 0), medium armor
	_spawn_unit(ecs, 2, 10.0, 0.0, 1, 500.0, "medium")
	# Enemy in AoE: faction 1 at (11, 0) — 1 unit from target
	_spawn_unit(ecs, 3, 11.0, 0.0, 1, 500.0, "medium")
	# Friendly in AoE: faction 0 at (12, 0) — 2 units from target
	_spawn_unit(ecs, 4, 12.0, 0.0, 0, 500.0, "medium")

	_combat_system.tick(ecs, 0)

	var hp2: float = ecs.get_component(2, "Health")["current"]
	var hp3: float = ecs.get_component(3, "Health")["current"]
	var hp4: float = ecs.get_component(4, "Health")["current"]

	# Primary: 100 * 1.0 (explosive vs medium) = 100 → 400
	_assert_approx(hp2, 400.0, "primary target takes full damage")
	# Enemy in AoE: 100 * 1.0 * 1.0 (enemy) = 100 → 400
	_assert_approx(hp3, 400.0, "enemy in AoE takes 100% splash")
	# Friendly in AoE: 100 * 1.0 * 0.5 (friendly) = 50 → 450
	_assert_approx(hp4, 450.0, "friendly in AoE takes 50% splash")


func test_cooldown_no_double_fire() -> void:
	print("\nTest 4: Cooldown prevents double fire in same tick")
	var ecs := _make_ecs()
	_spawn_unit(ecs, 1, 0.0, 0.0, 0)
	_arm_unit(ecs, 1, 100.0, 10.0, 2.0, "kinetic", ["ground"])
	_spawn_unit(ecs, 2, 5.0, 0.0, 1, 1000.0, "medium")

	# First tick: fires (cooldown was 0)
	_combat_system.tick(ecs, 0)
	var hp_after_1: float = ecs.get_component(2, "Health")["current"]
	# 100 * 0.75 = 75 → 925
	_assert_approx(hp_after_1, 925.0, "fires on first tick")

	# Second tick: should NOT fire (cooldown = 2.0, only 1/15 elapsed)
	_combat_system.tick(ecs, 1)
	var hp_after_2: float = ecs.get_component(2, "Health")["current"]
	_assert_approx(hp_after_2, 925.0, "does not fire on second tick (cooldown)")


func test_auto_acquire_enemy_in_range() -> void:
	print("\nTest 5: Auto-acquire enemy entering range")
	var ecs := _make_ecs()
	_spawn_unit(ecs, 1, 0.0, 0.0, 0)
	_arm_unit(ecs, 1, 50.0, 8.0, 1.0, "kinetic", ["ground"])
	# Enemy within range
	_spawn_unit(ecs, 2, 7.0, 0.0, 1, 200.0, "medium")

	# No AttackCommand — should auto-acquire
	_combat_system.tick(ecs, 0)
	var hp: float = ecs.get_component(2, "Health")["current"]
	# 50 * 0.75 = 37.5 → 162.5
	_assert_approx(hp, 162.5, "auto-acquired and attacked enemy")


func test_attack_command_overrides_auto() -> void:
	print("\nTest 6: AttackCommand overrides auto-acquire")
	var ecs := _make_ecs()
	_spawn_unit(ecs, 1, 0.0, 0.0, 0)
	_arm_unit(ecs, 1, 50.0, 10.0, 1.0, "kinetic", ["ground"])
	# Closer enemy
	_spawn_unit(ecs, 2, 3.0, 0.0, 1, 200.0, "medium")
	# Farther enemy — explicitly targeted
	_spawn_unit(ecs, 3, 8.0, 0.0, 1, 200.0, "medium")
	ecs.set_component(1, "AttackCommand", {"target": 3})

	_combat_system.tick(ecs, 0)

	var hp2: float = ecs.get_component(2, "Health")["current"]
	var hp3: float = ecs.get_component(3, "Health")["current"]
	# Should attack entity 3 (commanded), not entity 2 (closer)
	_assert_approx(hp2, 200.0, "closer enemy NOT attacked")
	_assert_approx(hp3, 162.5, "commanded target attacked")


func test_target_dies_mid_attack() -> void:
	print("\nTest 7: Target dies mid-attack — graceful clear")
	var ecs := _make_ecs()
	_spawn_unit(ecs, 1, 0.0, 0.0, 0)
	_arm_unit(ecs, 1, 100.0, 10.0, 1.0, "kinetic", ["ground"])
	# Target with very low health
	_spawn_unit(ecs, 2, 5.0, 0.0, 1, 10.0, "medium")
	ecs.set_component(1, "AttackCommand", {"target": 2})

	# Kill the target before combat tick
	var health: Dictionary = ecs.get_component(2, "Health")
	health["current"] = 0.0
	ecs.set_component(2, "Health", health)

	# Should not crash — clears command gracefully
	_combat_system.tick(ecs, 0)
	_assert_true(not ecs.has_component(1, "AttackCommand"), "AttackCommand cleared on dead target")


func test_no_valid_targets_does_nothing() -> void:
	print("\nTest 8: No valid targets in range — does nothing")
	var ecs := _make_ecs()
	_spawn_unit(ecs, 1, 0.0, 0.0, 0)
	_arm_unit(ecs, 1, 50.0, 5.0, 1.0, "kinetic", ["ground"])
	# Enemy out of range
	_spawn_unit(ecs, 2, 20.0, 0.0, 1, 200.0, "medium")

	_combat_system.tick(ecs, 0)
	var hp: float = ecs.get_component(2, "Health")["current"]
	_assert_approx(hp, 200.0, "out-of-range enemy untouched")


# --- Mock ECS ---
# Minimal in-memory ECS for testing without the full engine.

class MockECS:
	extends RefCounted

	var _entities: Dictionary = {}  # entity_id -> {component_name -> data}
	var _removed: Array = []

	func add_entity(id: int) -> void:
		_entities[id] = {}

	func entity_exists(id: int) -> bool:
		return _entities.has(id)

	func remove_entity(id: int) -> void:
		_entities.erase(id)
		_removed.append(id)

	func set_component(entity_id: int, component_name: String, data: Dictionary) -> void:
		if not _entities.has(entity_id):
			return
		_entities[entity_id][component_name] = data

	func get_component(entity_id: int, component_name: String) -> Dictionary:
		if not _entities.has(entity_id):
			return {}
		if not _entities[entity_id].has(component_name):
			return {}
		return _entities[entity_id][component_name]

	func has_component(entity_id: int, component_name: String) -> bool:
		if not _entities.has(entity_id):
			return false
		return _entities[entity_id].has(component_name)

	func remove_component(entity_id: int, component_name: String) -> void:
		if _entities.has(entity_id):
			_entities[entity_id].erase(component_name)

	func query(required_components: Array) -> Array:
		var result: Array = []
		for entity_id in _entities:
			var has_all := true
			for comp_name in required_components:
				if not _entities[entity_id].has(comp_name):
					has_all = false
					break
			if has_all:
				result.append(entity_id)
		return result
