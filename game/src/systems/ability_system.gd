class_name AbilitySystem

# Handles Spec Ops active abilities and passive tick effects.
# Reads/Writes: Stealthed, AbilityCooldown, C4Charge, Health, Research, FactionComponent, Position
#
# Ability IDs:
#   "cloak"       – add Stealthed, 300 tick duration, 600 tick cooldown
#   "plant_c4"    – place C4 within 1.5 tiles of a structure, 200 dmg, 75 tick fuse, cd 450
#   "steal_tech"  – adjacent enemy tech lab → grant T2 research to own faction, destroy spy (one-time)
#   "heal_aura"   – passive tick: +5 HP to nearby friendlies within 3 tiles

const CLOAK_DETECTION_RANGE: float = 1.5
const CLOAK_DURATION: int = 300
const CLOAK_COOLDOWN: int = 600

const PLANT_C4_RANGE: float = 1.5
const C4_DAMAGE: int = 200
const C4_FUSE: int = 75
const PLANT_C4_COOLDOWN: int = 450

const STEAL_TECH_RANGE: float = 1.5

const HEAL_AURA_RANGE: float = 3.0
const HEAL_AURA_HP_PER_TICK: float = 5.0

# T2 research options granted by steal_tech
const T2_RESEARCH_OPTIONS: Array[String] = [
	"advanced_infantry", "composite_armor", "rapid_fire",
	"energy_shields", "stealth_detection", "long_range_artillery",
]


func tick(ecs: ECS, tick_count: int) -> void:
	_tick_cooldowns(ecs, tick_count)
	_detonate_c4(ecs, tick_count)
	_tick_heal_aura(ecs, tick_count)
	_expire_cloak(ecs, tick_count)


func activate_ability(
	entity_id: int,
	ability_id: String,
	target,
	ecs: ECS,
	tick_count: int
) -> Dictionary:
	# Returns { "ok": bool, "error": String } or { "ok": bool, "result": Variant }
	match ability_id:
		"cloak":
			return _activate_cloak(entity_id, ecs, tick_count)
		"plant_c4":
			return _activate_plant_c4(entity_id, target, ecs, tick_count)
		"steal_tech":
			return _activate_steal_tech(entity_id, ecs, tick_count)
		_:
			push_warning("AbilitySystem: unknown ability '%s'" % ability_id)
			return {"ok": false, "error": "unknown_ability"}


# -- Cloak ---------------------------------------------------------------------

func _activate_cloak(entity_id: int, ecs: ECS, tick_count: int) -> Dictionary:
	if _is_on_cooldown(entity_id, "cloak", tick_count, ecs):
		return {"ok": false, "error": "on_cooldown"}

	ecs.add_component(entity_id, "Stealthed", {
		"detection_range": CLOAK_DETECTION_RANGE,
		"cloak_until_tick": tick_count + CLOAK_DURATION,
	})
	_set_cooldown(entity_id, "cloak", tick_count + CLOAK_COOLDOWN, ecs)
	return {"ok": true}


func _expire_cloak(ecs: ECS, tick_count: int) -> void:
	var cloaked: Array[int] = ecs.query(["Stealthed"])
	for entity_id: int in cloaked:
		var comp: Dictionary = ecs.get_component(entity_id, "Stealthed")
		var until: int = comp.get("cloak_until_tick", 0)
		if until > 0 and tick_count >= until:
			ecs.remove_component(entity_id, "Stealthed")


# -- Plant C4 ------------------------------------------------------------------

func _activate_plant_c4(
	entity_id: int,
	target_structure_id: int,
	ecs: ECS,
	tick_count: int
) -> Dictionary:
	if _is_on_cooldown(entity_id, "plant_c4", tick_count, ecs):
		return {"ok": false, "error": "on_cooldown"}

	if not ecs.has_component(entity_id, "Position"):
		return {"ok": false, "error": "no_position"}
	if not ecs.has_component(target_structure_id, "Position"):
		return {"ok": false, "error": "target_no_position"}
	if not ecs.has_component(target_structure_id, "Structure"):
		return {"ok": false, "error": "target_not_structure"}

	var my_pos: Dictionary = ecs.get_component(entity_id, "Position")
	var target_pos: Dictionary = ecs.get_component(target_structure_id, "Position")
	if _distance(my_pos, target_pos) > PLANT_C4_RANGE:
		return {"ok": false, "error": "out_of_range"}

	# Create C4 entity placed on the structure
	var c4_entity: int = ecs.create_entity()
	ecs.add_component(c4_entity, "Position", target_pos.duplicate())
	ecs.add_component(c4_entity, "C4Charge",
		Components.c4_charge(C4_DAMAGE, tick_count + C4_FUSE, entity_id))

	_set_cooldown(entity_id, "plant_c4", tick_count + PLANT_C4_COOLDOWN, ecs)
	return {"ok": true, "c4_entity": c4_entity}


func _detonate_c4(ecs: ECS, tick_count: int) -> void:
	var charges: Array[int] = ecs.query(["C4Charge", "Position"])
	var to_detonate: Array[int] = []

	for charge_id: int in charges:
		var comp: Dictionary = ecs.get_component(charge_id, "C4Charge")
		if tick_count >= comp.get("detonation_tick", 0):
			to_detonate.append(charge_id)

	for charge_id: int in to_detonate:
		_explode_c4(charge_id, ecs)


func _explode_c4(charge_id: int, ecs: ECS) -> void:
	var comp: Dictionary = ecs.get_component(charge_id, "C4Charge")
	var damage: float = float(comp.get("damage", C4_DAMAGE))
	var pos: Dictionary = ecs.get_component(charge_id, "Position")

	# Damage all entities with Health at the same position (direct placement)
	var targets: Array[int] = ecs.query(["Health", "Position", "Attackable"])
	for target_id: int in targets:
		if target_id == charge_id:
			continue
		var t_pos: Dictionary = ecs.get_component(target_id, "Position")
		# C4 is placed directly on structure — use a small blast radius (1.0 tile)
		if _distance(pos, t_pos) <= 1.0:
			var health: Dictionary = ecs.get_component(target_id, "Health")
			health["current"] = maxf(0.0, health.get("current", 0.0) - damage)
			ecs.add_component(target_id, "Health", health)

	ecs.destroy_entity(charge_id)


# -- Steal Tech ----------------------------------------------------------------

func _activate_steal_tech(entity_id: int, ecs: ECS, tick_count: int) -> Dictionary:
	if not ecs.has_component(entity_id, "Position"):
		return {"ok": false, "error": "no_position"}
	if not ecs.has_component(entity_id, "FactionComponent"):
		return {"ok": false, "error": "no_faction"}

	var spy_pos: Dictionary = ecs.get_component(entity_id, "Position")
	var spy_faction: Dictionary = ecs.get_component(entity_id, "FactionComponent")
	var spy_faction_id: int = spy_faction.get("faction_id", -1)

	# Find adjacent enemy tech labs
	var candidates: Array[int] = ecs.query(["TechLab", "Position", "FactionComponent"])
	var target_lab: int = -1

	for lab_id: int in candidates:
		var lab_faction: Dictionary = ecs.get_component(lab_id, "FactionComponent")
		if lab_faction.get("faction_id", -1) == spy_faction_id:
			continue  # Own faction lab — skip
		var lab_pos: Dictionary = ecs.get_component(lab_id, "Position")
		if _distance(spy_pos, lab_pos) <= STEAL_TECH_RANGE:
			target_lab = lab_id
			break

	if target_lab == -1:
		return {"ok": false, "error": "no_adjacent_tech_lab"}

	# Grant random T2 research to spy's faction
	var research_id: String = _pick_research(tick_count)
	_grant_research(spy_faction_id, research_id, ecs)

	# Destroy spy (one-time use)
	ecs.destroy_entity(entity_id)

	return {"ok": true, "research_granted": research_id}


func _pick_research(tick_count: int) -> String:
	# Deterministic pick seeded by tick_count — no randf() in simulation
	var idx: int = tick_count % T2_RESEARCH_OPTIONS.size()
	return T2_RESEARCH_OPTIONS[idx]


func _grant_research(faction_id: int, research_id: String, ecs: ECS) -> void:
	# Find FactionResearch entity for this faction, or create one
	var research_entities: Array[int] = ecs.query(["FactionResearch", "FactionComponent"])
	for r_entity: int in research_entities:
		var r_faction: Dictionary = ecs.get_component(r_entity, "FactionComponent")
		if r_faction.get("faction_id", -1) == faction_id:
			var research: Dictionary = ecs.get_component(r_entity, "FactionResearch")
			var unlocked: Array = research.get("unlocked", [])
			if not unlocked.has(research_id):
				unlocked.append(research_id)
				research["unlocked"] = unlocked
				ecs.add_component(r_entity, "FactionResearch", research)
			return

	# No existing research entity — create one
	var new_entity: int = ecs.create_entity()
	ecs.add_component(new_entity, "FactionComponent", {"faction_id": faction_id})
	ecs.add_component(new_entity, "FactionResearch", {"unlocked": [research_id]})


# -- Heal Aura (passive) -------------------------------------------------------

func _tick_heal_aura(ecs: ECS, tick_count: int) -> void:
	var healers: Array[int] = ecs.query(["HealAura", "Position", "FactionComponent"])
	for healer_id: int in healers:
		var h_pos: Dictionary = ecs.get_component(healer_id, "Position")
		var h_faction: Dictionary = ecs.get_component(healer_id, "FactionComponent")
		var healer_faction_id: int = h_faction.get("faction_id", -1)

		var nearby: Array[int] = ecs.query(["Health", "Position", "FactionComponent"])
		for target_id: int in nearby:
			if target_id == healer_id:
				continue
			var t_faction: Dictionary = ecs.get_component(target_id, "FactionComponent")
			if t_faction.get("faction_id", -1) != healer_faction_id:
				continue
			var t_pos: Dictionary = ecs.get_component(target_id, "Position")
			if _distance(h_pos, t_pos) > HEAL_AURA_RANGE:
				continue
			var health: Dictionary = ecs.get_component(target_id, "Health")
			var max_hp: float = health.get("max", 100.0)
			var new_hp: float = minf(health.get("current", 0.0) + HEAL_AURA_HP_PER_TICK, max_hp)
			health["current"] = new_hp
			ecs.add_component(target_id, "Health", health)


# -- Cooldown Helpers ----------------------------------------------------------

func _is_on_cooldown(entity_id: int, ability_id: String, tick_count: int, ecs: ECS) -> bool:
	if not ecs.has_component(entity_id, "AbilityCooldown"):
		return false
	var cooldowns: Dictionary = ecs.get_component(entity_id, "AbilityCooldown")
	var ready_at: int = cooldowns.get(ability_id, {}).get("ready_at_tick", 0)
	return tick_count < ready_at


func _set_cooldown(entity_id: int, ability_id: String, ready_at_tick: int, ecs: ECS) -> void:
	var cooldowns: Dictionary = {}
	if ecs.has_component(entity_id, "AbilityCooldown"):
		cooldowns = ecs.get_component(entity_id, "AbilityCooldown").duplicate()
	cooldowns[ability_id] = Components.ability_cooldown(ability_id, ready_at_tick)
	ecs.add_component(entity_id, "AbilityCooldown", cooldowns)


func _tick_cooldowns(_ecs: ECS, _tick_count: int) -> void:
	# Cooldowns are passive — they're read on demand via _is_on_cooldown.
	# No per-tick cleanup needed; expired cooldowns are ignored naturally.
	pass


# -- Helpers -------------------------------------------------------------------

func _distance(a: Dictionary, b: Dictionary) -> float:
	var dx: float = a.get("x", 0.0) - b.get("x", 0.0)
	var dy: float = a.get("y", 0.0) - b.get("y", 0.0)
	return sqrt(dx * dx + dy * dy)
