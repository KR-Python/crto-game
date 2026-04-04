class_name TestFactionMechanics
extends Node

# Tests for ShieldSystem (AEGIS) and TunnelSystem (FORGE).
# Run via GDUnit or the project's custom test runner.
# Uses assert() per project test convention (only in tests).

const PLAYER_FACTION: int = 1
const ENEMY_FACTION: int = 2

# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_ecs() -> ECS:
	return ECS.new()


func _add_structure(ecs: ECS, x: float, y: float, hp: float = 200.0) -> int:
	var id: int = ecs.create_entity()
	ecs.add_component(id, "Structure", {"built": true})
	ecs.add_component(id, "Position", {"x": x, "y": y})
	ecs.add_component(id, "Health", {"current": hp, "max": hp})
	return id


func _add_generator(ecs: ECS, faction_id: int, x: float, y: float,
		hp: int = 100, radius: float = 10.0, recharge_rate: float = 1.0) -> int:
	var id: int = ecs.create_entity()
	ecs.add_component(id, "FactionComponent", {"faction_id": faction_id})
	ecs.add_component(id, "Position", {"x": x, "y": y})
	ecs.add_component(id, "ShieldBubble", ShieldSystem.shield_bubble(id, hp, hp, radius, recharge_rate))
	return id


func _add_unit(ecs: ECS, faction_id: int, x: float, y: float) -> int:
	var id: int = ecs.create_entity()
	ecs.add_component(id, "FactionComponent", {"faction_id": faction_id})
	ecs.add_component(id, "Position", {"x": x, "y": y})
	ecs.add_component(id, "Health", {"current": 100.0, "max": 100.0})
	return id


func _add_spec_ops(ecs: ECS, faction_id: int, x: float, y: float) -> int:
	var id: int = _add_unit(ecs, faction_id, x, y)
	ecs.add_component(id, "UnitType", {"type": "spec_ops"})
	return id


func _add_tunnel(ecs: ECS, network_id: int, faction_id: int, x: float, y: float) -> int:
	var id: int = ecs.create_entity()
	ecs.add_component(id, "TunnelEntrance", TunnelSystem.tunnel_entrance(network_id, faction_id))
	ecs.add_component(id, "Position", {"x": x, "y": y})
	return id


# ── Shield Tests ──────────────────────────────────────────────────────────────

# Test 1: Shield absorbs damage before structure HP
func test_shield_absorbs_damage_before_structure_hp() -> void:
	var ecs := _make_ecs()
	var system := ShieldSystem.new()

	var structure_id: int = _add_structure(ecs, 0.0, 0.0, 200.0)
	var gen_id: int = _add_generator(ecs, PLAYER_FACTION, 0.0, 0.0, 100, 10.0)

	system.tick(ecs, 0)  # Apply coverage

	var remaining: float = system.absorb_damage(structure_id, 50.0, ecs, 0)

	var bubble: Dictionary = ecs.get_component(gen_id, "ShieldBubble")
	var struct_health: Dictionary = ecs.get_component(structure_id, "Health")

	assert(remaining == 0.0, "Shield should absorb all 50 dmg, 0 remaining")
	assert(bubble["hp_current"] == 50, "Shield HP should be 50 after absorbing 50")
	assert(struct_health["current"] == 200.0, "Structure HP must be untouched")


# Test 2: Shield depletes → remaining damage reaches structure
func test_shield_depletes_and_damage_bleeds_through() -> void:
	var ecs := _make_ecs()
	var system := ShieldSystem.new()

	var structure_id: int = _add_structure(ecs, 0.0, 0.0, 200.0)
	var gen_id: int = _add_generator(ecs, PLAYER_FACTION, 0.0, 0.0, 40, 10.0)

	system.tick(ecs, 0)

	# Apply 100 damage; shield has only 40 HP → 60 bleeds through
	var remaining: float = system.absorb_damage(structure_id, 100.0, ecs, 0)

	var bubble: Dictionary = ecs.get_component(gen_id, "ShieldBubble")
	assert(bubble["depleted"] == true, "Shield should be depleted")
	assert(bubble["hp_current"] == 0, "Shield HP should be 0")
	assert(absf(remaining - 60.0) < 0.01, "60 damage should bleed through")


# Test 3: Shield recharges after depletion cooldown
func test_shield_recharges_after_cooldown() -> void:
	var ecs := _make_ecs()
	var system := ShieldSystem.new()

	var structure_id: int = _add_structure(ecs, 0.0, 0.0, 200.0)
	var gen_id: int = _add_generator(ecs, PLAYER_FACTION, 0.0, 0.0, 30, 10.0, 1.0)

	system.tick(ecs, 0)
	system.absorb_damage(structure_id, 50.0, ecs, 0)  # Deplete shield

	var bubble_after_deplete: Dictionary = ecs.get_component(gen_id, "ShieldBubble")
	assert(bubble_after_deplete["depleted"] == true, "Shield must be depleted first")

	# Tick just before cooldown ends — still depleted
	system.tick(ecs, ShieldSystem.RECHARGE_COOLDOWN_TICKS - 1)
	var bubble_mid: Dictionary = ecs.get_component(gen_id, "ShieldBubble")
	assert(bubble_mid["depleted"] == true, "Should still be depleted before cooldown")

	# Tick at cooldown expiry — recharged
	system.tick(ecs, ShieldSystem.RECHARGE_COOLDOWN_TICKS)
	var bubble_recharged: Dictionary = ecs.get_component(gen_id, "ShieldBubble")
	assert(bubble_recharged["depleted"] == false, "Shield should be recharged")
	assert(bubble_recharged["hp_current"] == bubble_recharged["hp_max"], "HP must be fully restored")


# Test 4: Hardened Shields research increases radius by 1.5x
func test_hardened_shields_research_increases_radius() -> void:
	var ecs := _make_ecs()
	var system := ShieldSystem.new()

	# Structure at radius=10 — should NOT be covered without research
	var far_structure_id: int = _add_structure(ecs, 12.0, 0.0, 200.0)
	var gen_id: int = _add_generator(ecs, PLAYER_FACTION, 0.0, 0.0, 100, 10.0)

	# Tick without research — structure at distance 12 is outside radius 10
	system.tick(ecs, 0)
	assert(not ecs.has_component(far_structure_id, "ShieldedBy"),
		"Structure at distance 12 should NOT be covered by radius 10")

	# Add Hardened Shields research for PLAYER_FACTION
	var research_id: int = ecs.create_entity()
	ecs.add_component(research_id, "Research", {"completed": ["hardened_shields"]})
	ecs.add_component(research_id, "FactionComponent", {"faction_id": PLAYER_FACTION})

	# Tick again — radius is now 10 × 1.5 = 15, covers distance 12
	system.tick(ecs, 1)
	assert(ecs.has_component(far_structure_id, "ShieldedBy"),
		"Structure at distance 12 SHOULD be covered by research-boosted radius 15")


# ── Tunnel Tests ──────────────────────────────────────────────────────────────

# Test 5: Unit enters tunnel, teleports to exit on next tick
func test_tunnel_unit_teleports_next_tick() -> void:
	var ecs := _make_ecs()
	var system := TunnelSystem.new()

	var entrance_id: int = _add_tunnel(ecs, 1, PLAYER_FACTION, 0.0, 0.0)
	var exit_id: int = _add_tunnel(ecs, 1, PLAYER_FACTION, 50.0, 50.0)
	var unit_id: int = _add_unit(ecs, PLAYER_FACTION, 0.0, 0.0)

	var entered: bool = system.enter_tunnel_at_tick(unit_id, entrance_id, exit_id, ecs, 0)
	assert(entered == true, "Unit should enter tunnel successfully")
	assert(ecs.has_component(unit_id, "InTransit"), "Unit should be InTransit")

	# Tick 0: not yet arrived (arrive_tick = 1)
	system.tick(ecs, 0)
	assert(ecs.has_component(unit_id, "InTransit"), "Unit still in transit at tick 0")

	# Tick 1: arrives
	system.tick(ecs, 1)
	assert(not ecs.has_component(unit_id, "InTransit"), "Unit should no longer be InTransit")
	var pos: Dictionary = ecs.get_component(unit_id, "Position")
	assert(pos["x"] == 50.0 and pos["y"] == 50.0, "Unit should be at exit position")


# Test 6: Multiple exits — player can choose destination
func test_tunnel_multiple_exits_player_chooses() -> void:
	var ecs := _make_ecs()
	var system := TunnelSystem.new()

	var entrance_id: int = _add_tunnel(ecs, 1, PLAYER_FACTION, 0.0, 0.0)
	var exit_a: int = _add_tunnel(ecs, 1, PLAYER_FACTION, 20.0, 0.0)
	var exit_b: int = _add_tunnel(ecs, 1, PLAYER_FACTION, 40.0, 0.0)

	var exits: Array[int] = system.get_available_exits(entrance_id, PLAYER_FACTION, ecs)
	assert(exits.size() == 2, "Should have 2 available exits")
	assert(exit_a in exits, "Exit A should be available")
	assert(exit_b in exits, "Exit B should be available")

	# Unit chooses exit_b
	var unit_id: int = _add_unit(ecs, PLAYER_FACTION, 0.0, 0.0)
	system.enter_tunnel_at_tick(unit_id, entrance_id, exit_b, ecs, 0)
	system.tick(ecs, 1)

	var pos: Dictionary = ecs.get_component(unit_id, "Position")
	assert(pos["x"] == 40.0, "Unit should arrive at chosen exit B (x=40)")


# Test 7: Tunnel destroyed with unit in transit → nearest safe exit
func test_tunnel_destroyed_during_transit_reroutes_unit() -> void:
	var ecs := _make_ecs()
	var system := TunnelSystem.new()

	var entrance_id: int = _add_tunnel(ecs, 1, PLAYER_FACTION, 0.0, 0.0)
	var exit_primary: int = _add_tunnel(ecs, 1, PLAYER_FACTION, 100.0, 0.0)
	var exit_safe: int = _add_tunnel(ecs, 1, PLAYER_FACTION, 90.0, 0.0)  # Closer safe exit

	# Unit enters heading for exit_primary
	var unit_id: int = _add_unit(ecs, PLAYER_FACTION, 0.0, 0.0)
	system.enter_tunnel_at_tick(unit_id, entrance_id, exit_primary, ecs, 0)

	# Destroy the primary exit before arrival
	var exit_data: Dictionary = ecs.get_component(exit_primary, "TunnelEntrance")
	exit_data["destroyed"] = true
	ecs.add_component(exit_primary, "TunnelEntrance", exit_data)

	# Tick 1: arrival — should reroute to exit_safe
	system.tick(ecs, 1)

	assert(not ecs.has_component(unit_id, "InTransit"), "Unit should no longer be InTransit")
	var pos: Dictionary = ecs.get_component(unit_id, "Position")
	assert(pos["x"] == 90.0, "Unit should be rerouted to the nearest safe exit (x=90)")


# Test 8: Spec Ops can use enemy tunnel (no faction check — infiltration)
func test_spec_ops_can_enter_enemy_tunnel() -> void:
	var ecs := _make_ecs()
	var system := TunnelSystem.new()

	# Enemy tunnels — network belongs to ENEMY_FACTION
	var enemy_entrance: int = _add_tunnel(ecs, 1, ENEMY_FACTION, 0.0, 0.0)
	var enemy_exit: int = _add_tunnel(ecs, 1, ENEMY_FACTION, 30.0, 0.0)

	# Spec Ops unit from PLAYER_FACTION
	var spec_ops_id: int = _add_spec_ops(ecs, PLAYER_FACTION, 0.0, 0.0)

	# Spec Ops uses the infiltration API — should see enemy exit
	var infiltration_exits: Array[int] = system.get_available_exits_spec_ops(enemy_entrance, ecs)
	assert(enemy_exit in infiltration_exits,
		"Spec Ops should see enemy exit via infiltration access")

	# Standard faction exit check should NOT include enemy exit
	var standard_exits: Array[int] = system.get_available_exits(enemy_entrance, PLAYER_FACTION, ecs)
	assert(enemy_exit not in standard_exits,
		"Standard faction check should NOT expose enemy exit to player faction")

	# Spec Ops can enter and teleport through enemy tunnel
	var entered: bool = system.enter_tunnel_at_tick(spec_ops_id, enemy_entrance, enemy_exit, ecs, 0)
	assert(entered == true, "Spec Ops should successfully enter enemy tunnel")

	system.tick(ecs, 1)

	assert(not ecs.has_component(spec_ops_id, "InTransit"), "Spec Ops should have arrived")
	var pos: Dictionary = ecs.get_component(spec_ops_id, "Position")
	assert(pos["x"] == 30.0, "Spec Ops should emerge at enemy exit (x=30)")
