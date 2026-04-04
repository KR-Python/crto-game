class_name TestSuperweapon
extends Node

# Tests for SuperweaponSystem and VictorySystem.
# Run via GDUnit or the project's custom test runner.
# Uses assert() as per project test convention (never in production code).

const PLAYER_FACTION: int = 1
const ENEMY_FACTION: int = 2

# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_ecs() -> ECS:
	var ecs := ECS.new()
	return ecs


func _add_superweapon(ecs: ECS, faction_id: int, damage: float = 1000.0, radius: float = 10.0) -> int:
	var entity_id: int = ecs.create_entity()
	ecs.add_component(entity_id, "Structure", {"built": true, "build_progress": 1.0})
	ecs.add_component(entity_id, "FactionComponent", {"faction_id": faction_id})
	ecs.add_component(entity_id, "SuperweaponStats", {
		"damage": damage,
		"radius": radius,
		"effect_type": "orbital_strike",
	})
	return entity_id


func _add_unit(ecs: ECS, faction_id: int, x: float, y: float, hp: float = 100.0) -> int:
	var entity_id: int = ecs.create_entity()
	ecs.add_component(entity_id, "Position", {"x": x, "y": y})
	ecs.add_component(entity_id, "Health", {"current": hp, "max": hp})
	ecs.add_component(entity_id, "FactionComponent", {"faction_id": faction_id})
	ecs.add_component(entity_id, "Attackable", {})
	return entity_id


func _add_construction_yard(ecs: ECS, faction_id: int, hp: float = 500.0) -> int:
	var entity_id: int = ecs.create_entity()
	ecs.add_component(entity_id, "Structure", {"built": true, "build_progress": 1.0})
	ecs.add_component(entity_id, "ConstructionYard", {})
	ecs.add_component(entity_id, "FactionComponent", {"faction_id": faction_id})
	ecs.add_component(entity_id, "Health", {"current": hp, "max": hp})
	ecs.add_component(entity_id, "Attackable", {})
	return entity_id


# ── Test 1: Single confirmation — weapon must NOT fire ────────────────────────

func test_single_confirmation_does_not_fire() -> void:
	var ecs := _make_ecs()
	var system := SuperweaponSystem.new()

	var weapon_id: int = _add_superweapon(ecs, PLAYER_FACTION)
	var fired: bool = false
	system.superweapon_fired.connect(func(_wid, _t, _e): fired = true)

	system.initiate_targeting(weapon_id, Vector2(50, 50), 0)
	system.tick(ecs, 1)  # Only commander confirmed

	assert(not fired, "FAIL test_single_confirmation_does_not_fire: weapon fired with only one confirm")
	print("PASS test_single_confirmation_does_not_fire")


# ── Test 2: Both confirmations within window — weapon fires ───────────────────

func test_both_confirmations_fires_weapon() -> void:
	var ecs := _make_ecs()
	var system := SuperweaponSystem.new()

	var weapon_id: int = _add_superweapon(ecs, PLAYER_FACTION)
	var fired: bool = false
	system.superweapon_fired.connect(func(_wid, _t, _e): fired = true)

	system.initiate_targeting(weapon_id, Vector2(50, 50), 0)
	var result: bool = system.confirm(weapon_id, "field_marshal", 5)

	# confirm() returns true immediately once both confirmed
	assert(result, "FAIL test_both_confirmations_fires_weapon: confirm() should return true")

	system.tick(ecs, 6)  # tick should emit the signal and fire
	assert(fired, "FAIL test_both_confirmations_fires_weapon: superweapon_fired not emitted")
	print("PASS test_both_confirmations_fires_weapon")


# ── Test 3: Confirmation window expires — no fire, state cleared ──────────────

func test_confirmation_window_expires() -> void:
	var ecs := _make_ecs()
	var system := SuperweaponSystem.new()

	var weapon_id: int = _add_superweapon(ecs, PLAYER_FACTION)
	var fired: bool = false
	var expired: bool = false
	system.superweapon_fired.connect(func(_wid, _t, _e): fired = true)
	system.confirmation_expired.connect(func(_wid): expired = true)

	system.initiate_targeting(weapon_id, Vector2(50, 50), 0)
	# Advance past window without second confirmation
	system.tick(ecs, SuperweaponSystem.CONFIRMATION_WINDOW + 1)

	assert(not fired, "FAIL test_confirmation_window_expires: weapon should not have fired")
	assert(expired, "FAIL test_confirmation_window_expires: confirmation_expired not emitted")
	print("PASS test_confirmation_window_expires")


# ── Test 4: AoE damage applied to entities in radius ─────────────────────────

func test_aoe_damage_in_radius() -> void:
	var ecs := _make_ecs()
	var system := SuperweaponSystem.new()

	var weapon_id: int = _add_superweapon(ecs, PLAYER_FACTION, 500.0, 10.0)
	var target := Vector2(0.0, 0.0)

	# Unit inside radius (5 units away)
	var inside_id: int = _add_unit(ecs, ENEMY_FACTION, 5.0, 0.0, 200.0)
	# Unit outside radius (15 units away)
	var outside_id: int = _add_unit(ecs, ENEMY_FACTION, 15.0, 0.0, 200.0)

	# Fire directly
	system._fire_weapon(weapon_id, target, ecs)

	var inside_hp: float = ecs.get_component(inside_id, "Health").get("current", 200.0)
	var outside_hp: float = ecs.get_component(outside_id, "Health").get("current", 200.0)

	assert(inside_hp < 200.0, "FAIL test_aoe_damage_in_radius: unit inside radius not damaged")
	assert(outside_hp == 200.0, "FAIL test_aoe_damage_in_radius: unit outside radius was damaged")
	print("PASS test_aoe_damage_in_radius")


# ── Test 5: Victory — enemy CY destroyed → game_won emitted ──────────────────

func test_victory_enemy_cy_destroyed() -> void:
	var ecs := _make_ecs()
	var system := VictorySystem.new()
	system.player_faction_id = PLAYER_FACTION

	# Own CY alive
	_add_construction_yard(ecs, PLAYER_FACTION, 500.0)
	# Enemy CY with 0 HP (destroyed)
	var enemy_cy: int = _add_construction_yard(ecs, ENEMY_FACTION, 0.0)
	# Explicitly zero it out
	ecs.add_component(enemy_cy, "Health", {"current": 0.0, "max": 500.0})

	var won: bool = false
	system.game_won.connect(func(_f, _t): won = true)

	system.tick(ecs, 100)
	assert(won, "FAIL test_victory_enemy_cy_destroyed: game_won not emitted")
	print("PASS test_victory_enemy_cy_destroyed")


# ── Test 6: Loss — own CY destroyed → game_lost emitted ──────────────────────

func test_loss_own_cy_destroyed() -> void:
	var ecs := _make_ecs()
	var system := VictorySystem.new()
	system.player_faction_id = PLAYER_FACTION

	# Own CY with 0 HP (destroyed)
	var own_cy: int = _add_construction_yard(ecs, PLAYER_FACTION, 0.0)
	ecs.add_component(own_cy, "Health", {"current": 0.0, "max": 500.0})
	# Enemy CY still alive
	_add_construction_yard(ecs, ENEMY_FACTION, 500.0)

	var lost: bool = false
	system.game_lost.connect(func(_f, _t): lost = true)

	system.tick(ecs, 100)
	assert(lost, "FAIL test_loss_own_cy_destroyed: game_lost not emitted")
	print("PASS test_loss_own_cy_destroyed")


# ── Runner ────────────────────────────────────────────────────────────────────

func run_all() -> void:
	print("=== SuperweaponSystem + VictorySystem Tests ===")
	test_single_confirmation_does_not_fire()
	test_both_confirmations_fires_weapon()
	test_confirmation_window_expires()
	test_aoe_damage_in_radius()
	test_victory_enemy_cy_destroyed()
	test_loss_own_cy_destroyed()
	print("=== All tests passed ===")
