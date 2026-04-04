class_name TestStealth
extends Node

# Tests for StealthSystem and AbilitySystem (stealth-related abilities).
# Run via GDUnit or the project's custom test runner.
# Uses assert() as per project test convention (never in production code).

const PLAYER_FACTION: int = 1
const ENEMY_FACTION: int = 2


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_ecs() -> ECS:
	return ECS.new()


func _add_unit(ecs: ECS, faction_id: int, x: float, y: float, hp: float = 100.0) -> int:
	var id: int = ecs.create_entity()
	ecs.add_component(id, "Position", {"x": x, "y": y})
	ecs.add_component(id, "Health", {"current": hp, "max": hp})
	ecs.add_component(id, "FactionComponent", {"faction_id": faction_id})
	ecs.add_component(id, "Attackable", {})
	return id


func _add_structure(ecs: ECS, faction_id: int, x: float, y: float, hp: float = 500.0) -> int:
	var id: int = ecs.create_entity()
	ecs.add_component(id, "Position", {"x": x, "y": y})
	ecs.add_component(id, "Health", {"current": hp, "max": hp})
	ecs.add_component(id, "FactionComponent", {"faction_id": faction_id})
	ecs.add_component(id, "Structure", {"built": true})
	ecs.add_component(id, "Attackable", {})
	return id


# ── Test 1: Stealthed unit not visible without Detector ──────────────────────

func test_stealthed_not_visible_without_detector() -> void:
	var ecs := _make_ecs()
	var system := StealthSystem.new()

	var spy: int = _add_unit(ecs, PLAYER_FACTION, 0.0, 0.0)
	ecs.add_component(spy, "Stealthed", Components.stealthed(1.5))

	# Enemy nearby but no Detector component
	var enemy: int = _add_unit(ecs, ENEMY_FACTION, 1.0, 0.0)
	# enemy has no Detector

	system.tick(ecs, 1)

	# Spy should NOT be revealed
	assert(not ecs.has_component(spy, "Revealed"),
		"Spy should not be revealed without enemy Detector")

	# Enemy entity unused — suppress lint warning
	var _e: int = enemy


# ── Test 2: Detector reveals stealthed unit ───────────────────────────────────

func test_detector_reveals_stealthed_unit() -> void:
	var ecs := _make_ecs()
	var system := StealthSystem.new()

	var spy: int = _add_unit(ecs, PLAYER_FACTION, 0.0, 0.0)
	ecs.add_component(spy, "Stealthed", Components.stealthed(2.0))

	# Enemy has a Detector within range
	var enemy_detector: int = _add_unit(ecs, ENEMY_FACTION, 1.5, 0.0)
	ecs.add_component(enemy_detector, "Detector", Components.detector(3.0))

	system.tick(ecs, 10)

	assert(ecs.has_component(spy, "Revealed"),
		"Spy should be revealed when enemy Detector is within range")

	var revealed: Dictionary = ecs.get_component(spy, "Revealed")
	assert(revealed.get("revealed_until_tick", 0) == 10 + 150,
		"Revealed duration should be now + 150 ticks")


# ── Test 3: Revealed tag expires ─────────────────────────────────────────────

func test_revealed_tag_expires() -> void:
	var ecs := _make_ecs()
	var system := StealthSystem.new()

	var spy: int = _add_unit(ecs, PLAYER_FACTION, 5.0, 5.0)
	# Manually apply Revealed — set to expire at tick 50
	ecs.add_component(spy, "Revealed", Components.revealed(50))

	# Tick before expiry — still revealed
	system.tick(ecs, 49)
	assert(ecs.has_component(spy, "Revealed"),
		"Revealed should not expire before until_tick")

	# Tick at expiry
	system.tick(ecs, 50)
	assert(not ecs.has_component(spy, "Revealed"),
		"Revealed should be removed at or after revealed_until_tick")


# ── Test 4: Plant C4 succeeds when adjacent ───────────────────────────────────

func test_plant_c4_succeeds_when_adjacent() -> void:
	var ecs := _make_ecs()
	var system := AbilitySystem.new()

	var spy: int = _add_unit(ecs, PLAYER_FACTION, 0.0, 0.0)
	var structure: int = _add_structure(ecs, ENEMY_FACTION, 1.0, 0.0)

	var result: Dictionary = system.activate_ability(spy, "plant_c4", structure, ecs, 100)

	assert(result.get("ok", false),
		"plant_c4 should succeed when spy is within 1.5 tiles of structure")

	var c4_entity: int = result.get("c4_entity", -1)
	assert(c4_entity != -1, "Result should include c4_entity id")
	assert(ecs.has_component(c4_entity, "C4Charge"),
		"C4 entity should have C4Charge component")

	var charge: Dictionary = ecs.get_component(c4_entity, "C4Charge")
	assert(charge.get("damage", 0) == 200, "C4 damage should be 200")
	assert(charge.get("detonation_tick", 0) == 100 + 75,
		"Detonation tick should be now + 75")
	assert(charge.get("placed_by", -1) == spy, "placed_by should be spy entity id")


# ── Test 5: C4 detonates at correct tick ─────────────────────────────────────

func test_c4_detonates_at_correct_tick() -> void:
	var ecs := _make_ecs()
	var system := AbilitySystem.new()

	var spy: int = _add_unit(ecs, PLAYER_FACTION, 0.0, 0.0)
	var structure: int = _add_structure(ecs, ENEMY_FACTION, 0.5, 0.0)

	# Plant C4 at tick 0 — detonates at tick 75
	var result: Dictionary = system.activate_ability(spy, "plant_c4", structure, ecs, 0)
	assert(result.get("ok", false), "plant_c4 should succeed")

	var c4_entity: int = result.get("c4_entity", -1)

	# Tick 74 — structure still alive
	system.tick(ecs, 74)
	assert(ecs.has_component(structure, "Health"), "Structure should still exist at tick 74")
	var hp_before: float = ecs.get_component(structure, "Health").get("current", 0.0)
	assert(hp_before == 500.0, "Structure HP should be untouched before detonation")

	# Tick 75 — detonation
	system.tick(ecs, 75)

	# C4 entity should be destroyed
	assert(not ecs.has_component(c4_entity, "C4Charge"),
		"C4Charge should be removed after detonation")

	# Structure should have taken damage
	var hp_after: float = ecs.get_component(structure, "Health").get("current", 0.0)
	assert(hp_after < 500.0, "Structure should have taken damage from C4 detonation")
	assert(hp_after == 300.0, "Structure should have 300 HP remaining (500 - 200)")


# ── Test 6: Cloak adds Stealthed component ────────────────────────────────────

func test_cloak_adds_stealthed_component() -> void:
	var ecs := _make_ecs()
	var system := AbilitySystem.new()

	var spy: int = _add_unit(ecs, PLAYER_FACTION, 0.0, 0.0)

	var result: Dictionary = system.activate_ability(spy, "cloak", null, ecs, 0)
	assert(result.get("ok", false), "cloak should succeed")

	assert(ecs.has_component(spy, "Stealthed"),
		"Spy should have Stealthed component after cloak")

	var stealthed: Dictionary = ecs.get_component(spy, "Stealthed")
	assert(stealthed.get("detection_range", 0.0) == 1.5,
		"Stealthed detection_range should be 1.5")
	assert(stealthed.get("cloak_until_tick", 0) == 300,
		"Cloak should last 300 ticks from tick 0")

	# Cooldown should be set
	assert(ecs.has_component(spy, "AbilityCooldown"),
		"AbilityCooldown should be set after cloak")


# ── Test 7: Stealth breaks on attack ─────────────────────────────────────────

func test_stealth_breaks_on_attack() -> void:
	var ecs := _make_ecs()
	var system := StealthSystem.new()

	var spy: int = _add_unit(ecs, PLAYER_FACTION, 0.0, 0.0)
	ecs.add_component(spy, "Stealthed", Components.stealthed(1.5))

	# Simulate spy attacking — CombatSystem would call this
	system.on_unit_attacked(spy, 100, ecs)

	assert(not ecs.has_component(spy, "Stealthed"),
		"Stealthed should be removed when unit attacks")
	assert(ecs.has_component(spy, "Revealed"),
		"Spy should be Revealed immediately after attacking")
	assert(ecs.has_component(spy, "BreakStealth"),
		"BreakStealth marker should be added after attacking")

	var revealed: Dictionary = ecs.get_component(spy, "Revealed")
	assert(revealed.get("revealed_until_tick", 0) == 250,
		"Revealed should last until tick 100 + 150 = 250")


# ── Test 8: Steal tech destroys spy, grants research ─────────────────────────

func test_steal_tech_destroys_spy_grants_research() -> void:
	var ecs := _make_ecs()
	var system := AbilitySystem.new()

	var spy: int = _add_unit(ecs, PLAYER_FACTION, 0.0, 0.0)

	# Adjacent enemy tech lab
	var tech_lab: int = ecs.create_entity()
	ecs.add_component(tech_lab, "Position", {"x": 1.0, "y": 0.0})
	ecs.add_component(tech_lab, "FactionComponent", {"faction_id": ENEMY_FACTION})
	ecs.add_component(tech_lab, "TechLab", {})
	ecs.add_component(tech_lab, "Structure", {"built": true})

	# Tick 300 → index 300 % 6 = 0 → "advanced_infantry"
	var result: Dictionary = system.activate_ability(spy, "steal_tech", null, ecs, 300)

	assert(result.get("ok", false), "steal_tech should succeed when adjacent to enemy tech lab")
	assert(result.get("research_granted", "") == "advanced_infantry",
		"Should grant 'advanced_infantry' (tick 300 % 6 = 0)")

	# Spy should be destroyed
	assert(not ecs.has_component(spy, "Position"),
		"Spy entity should be destroyed after steal_tech")

	# Player faction should have the research
	var research_entities: Array[int] = ecs.query(["FactionResearch", "FactionComponent"])
	var found: bool = false
	for r_id: int in research_entities:
		var r_faction: Dictionary = ecs.get_component(r_id, "FactionComponent")
		if r_faction.get("faction_id", -1) == PLAYER_FACTION:
			var research: Dictionary = ecs.get_component(r_id, "FactionResearch")
			var unlocked: Array = research.get("unlocked", [])
			if unlocked.has("advanced_infantry"):
				found = true
				break
	assert(found, "Player faction should have 'advanced_infantry' in FactionResearch after steal_tech")
