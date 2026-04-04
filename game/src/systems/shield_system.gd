class_name ShieldSystem

# Tick pipeline step: AEGIS faction shield generator mechanic.
# Shield generators emit protective bubbles covering nearby structures.
# ShieldBubble absorbs incoming damage before the structure's own Health.
# Depleted shields enter a 30-second recharge cooldown before recovering.
# Research "Hardened Shields" increases bubble radius (1.5x) and recharge rate (2x).
#
# Reads:  ShieldBubble, Position (generator + structure), Research
# Writes: ShieldBubble, ShieldedBy (on covered structures)

const RECHARGE_COOLDOWN_TICKS: int = 450  # 30 s × 15 TPS
const HARDENED_SHIELDS_RESEARCH: String = "hardened_shields"
const HARDENED_RADIUS_MULTIPLIER: float = 1.5
const HARDENED_RECHARGE_MULTIPLIER: float = 2.0

# Tracks recharge cooldown start tick per generator entity.
# { generator_entity_id: tick_when_depletion_occurred }
var _depleted_at: Dictionary = {}

signal shield_depleted(generator_id: int)
signal shield_recharged(generator_id: int)


# ── Component constructors ────────────────────────────────────────────────────

static func shield_bubble(
	generator_id: int,
	hp: int,
	max_hp: int,
	radius: float,
	recharge_rate: float
) -> Dictionary:
	return {
		"generator_id": generator_id,
		"hp_current": hp,
		"hp_max": max_hp,
		"radius": radius,
		"recharge_rate": recharge_rate,
		"depleted": false,
	}


static func shielded_by(generator_id: int) -> Dictionary:
	# Applied to a structure entity when it is within a generator's bubble.
	return {"generator_id": generator_id}


# ── Tick ──────────────────────────────────────────────────────────────────────

func tick(ecs: ECS, tick_count: int) -> void:
	_recharge_depleted_shields(ecs, tick_count)
	_update_coverage(ecs)


# ── Damage interception (called by CombatSystem before applying to Health) ────

func absorb_damage(entity_id: int, damage: float, ecs: ECS, tick_count: int) -> float:
	# Returns remaining damage after the shield absorbs what it can.
	# If the entity has no ShieldedBy component, returns damage unchanged.
	if not ecs.has_component(entity_id, "ShieldedBy"):
		return damage

	var shielded: Dictionary = ecs.get_component(entity_id, "ShieldedBy")
	var generator_id: int = shielded.get("generator_id", -1)
	if generator_id < 0:
		return damage

	if not ecs.has_component(generator_id, "ShieldBubble"):
		return damage

	var bubble: Dictionary = ecs.get_component(generator_id, "ShieldBubble")
	if bubble.get("depleted", true):
		# Shield is recharging — no protection
		return damage

	var hp: float = float(bubble.get("hp_current", 0))
	if hp <= 0.0:
		return damage

	var absorbed: float = minf(hp, damage)
	var remaining: float = damage - absorbed
	bubble["hp_current"] = int(maxf(0.0, hp - absorbed))

	if bubble["hp_current"] <= 0:
		bubble["depleted"] = true
		_depleted_at[generator_id] = tick_count
		ecs.add_component(generator_id, "ShieldBubble", bubble)
		shield_depleted.emit(generator_id)
	else:
		ecs.add_component(generator_id, "ShieldBubble", bubble)

	return remaining


# ── Internal helpers ──────────────────────────────────────────────────────────

func _recharge_depleted_shields(ecs: ECS, tick_count: int) -> void:
	var recovered: Array[int] = []
	for generator_id: int in _depleted_at:
		var depleted_tick: int = _depleted_at[generator_id]
		if not ecs.has_component(generator_id, "ShieldBubble"):
			recovered.append(generator_id)
			continue

		var bubble: Dictionary = ecs.get_component(generator_id, "ShieldBubble")
		var recharge_rate: float = bubble.get("recharge_rate", 1.0)

		# Apply research multiplier if present
		var faction_id: int = _get_faction(generator_id, ecs)
		if _has_research(faction_id, HARDENED_SHIELDS_RESEARCH, ecs):
			recharge_rate *= HARDENED_RECHARGE_MULTIPLIER

		var cooldown: int = int(float(RECHARGE_COOLDOWN_TICKS) / recharge_rate)
		if tick_count - depleted_tick >= cooldown:
			bubble["hp_current"] = bubble.get("hp_max", bubble.get("hp_current", 0))
			bubble["depleted"] = false
			ecs.add_component(generator_id, "ShieldBubble", bubble)
			recovered.append(generator_id)
			shield_recharged.emit(generator_id)

	for generator_id: int in recovered:
		_depleted_at.erase(generator_id)


func _update_coverage(ecs: ECS) -> void:
	# Remove stale ShieldedBy components from all structures.
	var structures: Array[int] = ecs.query(["Structure", "Position"])
	for entity_id: int in structures:
		if ecs.has_component(entity_id, "ShieldedBy"):
			ecs.remove_component(entity_id, "ShieldedBy")

	# Re-apply coverage based on current generator positions and radii.
	var generators: Array[int] = ecs.query(["ShieldBubble", "Position"])
	for generator_id: int in generators:
		var bubble: Dictionary = ecs.get_component(generator_id, "ShieldBubble")
		var gen_pos: Dictionary = ecs.get_component(generator_id, "Position")
		var gx: float = gen_pos.get("x", 0.0)
		var gy: float = gen_pos.get("y", 0.0)
		var radius: float = bubble.get("radius", 0.0)

		# Apply Hardened Shields research radius bonus
		var faction_id: int = _get_faction(generator_id, ecs)
		if _has_research(faction_id, HARDENED_SHIELDS_RESEARCH, ecs):
			radius *= HARDENED_RADIUS_MULTIPLIER

		for entity_id: int in structures:
			var pos: Dictionary = ecs.get_component(entity_id, "Position")
			var dx: float = pos.get("x", 0.0) - gx
			var dy: float = pos.get("y", 0.0) - gy
			if dx * dx + dy * dy <= radius * radius:
				ecs.add_component(entity_id, "ShieldedBy", shielded_by(generator_id))


func _get_faction(entity_id: int, ecs: ECS) -> int:
	if not ecs.has_component(entity_id, "FactionComponent"):
		return -1
	return ecs.get_component(entity_id, "FactionComponent").get("faction_id", -1)


func _has_research(faction_id: int, research_key: String, ecs: ECS) -> bool:
	if faction_id < 0:
		return false
	var research_entities: Array[int] = ecs.query(["Research", "FactionComponent"])
	for rid: int in research_entities:
		var fc: Dictionary = ecs.get_component(rid, "FactionComponent")
		if fc.get("faction_id", -1) != faction_id:
			continue
		var research: Dictionary = ecs.get_component(rid, "Research")
		var completed: Array = research.get("completed", [])
		if research_key in completed:
			return true
	return false
