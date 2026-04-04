class_name TechTreeSystem

# Manages research and tech unlocks per faction.
# Reads: FactionComponent, Health, PoweredBuilding, FactionResearch
# Writes: FactionResearch, Health (via stat_modifier effects)
#
# Per-faction research state is held in-memory (not in ECS) for O(1) access.
# ECS FactionResearch component is kept in sync as the authoritative store.

signal research_completed(faction_id: int, tech_id: String)
signal research_started(faction_id: int, tech_id: String, eta_ticks: int)

# { faction_id: { "researched": Array[String], "active_research": Dictionary } }
# active_research: { "tech_id": String, "progress": float, "lab_entity_id": int, "cost": Dictionary }
var _faction_research: Dictionary = {}


# ---------------------------------------------------------------------------
# Tick
# ---------------------------------------------------------------------------

func tick(ecs: ECS, tick_count: int) -> void:
	for faction_id: int in _faction_research.keys():
		var state: Dictionary = _faction_research[faction_id]
		var active: Dictionary = state.get("active_research", {})
		if active.is_empty():
			continue
		if not _is_lab_powered(active.get("lab_entity_id", -1), ecs):
			continue  # Lab unpowered — research pauses

		var research_data: Dictionary = active.get("research_data", {})
		var total_ticks: float = _time_to_ticks(research_data.get("time", 60.0))
		active["progress"] = active.get("progress", 0.0) + 1.0

		if active["progress"] >= total_ticks:
			_complete_research(faction_id, active, ecs)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Start research for a faction. Returns { "success": bool, "error": String }.
## Deducts cost immediately on success.
func start_research(faction_id: int, tech_id: String, lab_entity_id: int, ecs: ECS) -> Dictionary:
	var state: Dictionary = _ensure_faction_state(faction_id)

	# Already researching?
	if not state.get("active_research", {}).is_empty():
		return {"success": false, "error": "research_already_active"}

	# Already researched?
	if is_researched(faction_id, tech_id):
		return {"success": false, "error": "already_researched"}

	# Lab must exist
	if not ecs.has_component(lab_entity_id, "TechLab"):
		return {"success": false, "error": "no_tech_lab"}

	# Lab must be powered
	if not _is_lab_powered(lab_entity_id, ecs):
		return {"success": false, "error": "lab_not_powered"}

	# Load research data from a data loader or FactionResearchData component
	var research_data: Dictionary = _find_research_data(tech_id, ecs)
	if research_data.is_empty():
		return {"success": false, "error": "unknown_tech_id"}

	# Requirements check
	var requires: Array = research_data.get("requires", [])
	for req: String in requires:
		# Requirements can be structure tags or other research IDs
		if not _requirement_met(faction_id, req, ecs):
			return {"success": false, "error": "requirements_not_met"}

	# Resource check and deduction
	var cost: Dictionary = research_data.get("cost", {})
	if not _deduct_resources(faction_id, cost, ecs):
		return {"success": false, "error": "insufficient_resources"}

	# Start research
	var total_ticks: float = _time_to_ticks(research_data.get("time", 60.0))
	state["active_research"] = {
		"tech_id": tech_id,
		"progress": 0.0,
		"lab_entity_id": lab_entity_id,
		"cost": cost.duplicate(),
		"research_data": research_data.duplicate(true),
	}

	research_started.emit(faction_id, tech_id, int(total_ticks))
	return {"success": true, "error": ""}


## Cancel active research and issue a full refund.
func cancel_research(faction_id: int) -> void:
	var state: Dictionary = _ensure_faction_state(faction_id)
	var active: Dictionary = state.get("active_research", {})
	if active.is_empty():
		return

	# Full refund — stored cost at time of deduction
	var cost: Dictionary = active.get("cost", {})
	if not cost.is_empty():
		_refund_resources(faction_id, cost)

	state["active_research"] = {}


func is_researched(faction_id: int, tech_id: String) -> bool:
	var state: Dictionary = _ensure_faction_state(faction_id)
	return state.get("researched", []).has(tech_id)


## Returns all research entries whose requirements are met and not yet researched.
func get_available_research(faction_id: int, data_loader) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	if data_loader == null:
		return available

	var all_research: Array = data_loader.get_all_research(faction_id)
	for entry: Dictionary in all_research:
		var tech_id: String = entry.get("research_id", "")
		if is_researched(faction_id, tech_id):
			continue
		var requires: Array = entry.get("requires", [])
		var reqs_met: bool = true
		for req: String in requires:
			if not is_researched(faction_id, req):
				reqs_met = false
				break
		if reqs_met:
			available.append(entry)
	return available


## Returns current tech tier (1, 2, or 3) for a faction based on completed research.
func get_tech_tier(faction_id: int, data_loader) -> int:
	if data_loader == null:
		return 1

	var max_tier: int = 1
	var researched: Array = _ensure_faction_state(faction_id).get("researched", [])
	for tech_id: String in researched:
		var entry: Dictionary = data_loader.get_research_by_id(tech_id)
		var tier: int = entry.get("tier", 1)
		if tier > max_tier:
			max_tier = tier
	return max_tier


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _complete_research(faction_id: int, active: Dictionary, ecs: ECS) -> void:
	var tech_id: String = active.get("tech_id", "")
	var state: Dictionary = _ensure_faction_state(faction_id)
	var researched: Array = state.get("researched", [])
	if not researched.has(tech_id):
		researched.append(tech_id)
	state["researched"] = researched
	state["active_research"] = {}

	_sync_to_ecs(faction_id, ecs)
	_apply_research_effect(faction_id, active.get("research_data", {}), ecs)
	research_completed.emit(faction_id, tech_id)


func _apply_research_effect(faction_id: int, research_data: Dictionary, ecs: ECS) -> void:
	var effect: Dictionary = research_data.get("effect", {})
	if effect.is_empty():
		return

	match effect.get("type", ""):
		"stat_modifier":
			_apply_stat_modifier(faction_id, effect, ecs)
		"ability_upgrade":
			_apply_ability_upgrade(effect, ecs)
		"unlock":
			# Mark as researched — already done in _complete_research
			pass
		_:
			push_warning("TechTreeSystem: unknown effect type '%s'" % effect.get("type", ""))


func _apply_stat_modifier(faction_id: int, effect: Dictionary, ecs: ECS) -> void:
	var target_filter: Dictionary = effect.get("target", {})
	var modifier: Dictionary = effect.get("modifier", {})
	if modifier.is_empty():
		return

	# Find all entities matching the filter
	var candidates: Array[int] = ecs.query(["FactionComponent", "Health"])
	for entity_id: int in candidates:
		if not _entity_matches_filter(entity_id, faction_id, target_filter, ecs):
			continue
		_apply_modifier_to_entity(entity_id, modifier, ecs)


func _apply_ability_upgrade(effect: Dictionary, ecs: ECS) -> void:
	var target_structure: String = effect.get("target", "")
	var modifier: Dictionary = effect.get("modifier", {})
	if target_structure.is_empty() or modifier.is_empty():
		return

	# Update all matching structures
	var candidates: Array[int] = ecs.query(["Structure", "AbilityParams"])
	for entity_id: int in candidates:
		var structure: Dictionary = ecs.get_component(entity_id, "Structure")
		if structure.get("structure_id", "") != target_structure:
			continue
		var params: Dictionary = ecs.get_component(entity_id, "AbilityParams").duplicate()
		for key: String in modifier.keys():
			var current: float = params.get(key, 1.0)
			params[key] = current * float(modifier[key])
		ecs.add_component(entity_id, "AbilityParams", params)


func _entity_matches_filter(entity_id: int, faction_id: int, filter: Dictionary, ecs: ECS) -> bool:
	# Faction check
	if not ecs.has_component(entity_id, "FactionComponent"):
		return false
	var f: Dictionary = ecs.get_component(entity_id, "FactionComponent")
	if f.get("faction_id", -1) != faction_id:
		return false

	# Category filter
	if filter.has("category"):
		if not ecs.has_component(entity_id, "UnitCategory"):
			return false
		var cat: Dictionary = ecs.get_component(entity_id, "UnitCategory")
		if cat.get("category", "") != filter["category"]:
			return false

	# Damage type filter (for weapon upgrades)
	if filter.has("weapon.damage_type"):
		if not ecs.has_component(entity_id, "WeaponComponent"):
			return false
		var w: Dictionary = ecs.get_component(entity_id, "WeaponComponent")
		if w.get("damage_type", "") != filter["weapon.damage_type"]:
			return false

	return true


func _apply_modifier_to_entity(entity_id: int, modifier: Dictionary, ecs: ECS) -> void:
	for key: String in modifier.keys():
		var parts: PackedStringArray = key.split(".")
		match parts[0]:
			"health":
				if ecs.has_component(entity_id, "Health"):
					var health: Dictionary = ecs.get_component(entity_id, "Health").duplicate()
					var field: String = parts[1] if parts.size() > 1 else "max"
					health[field] = health.get(field, 100.0) * float(modifier[key])
					ecs.add_component(entity_id, "Health", health)
			"weapons":
				if ecs.has_component(entity_id, "WeaponComponent"):
					var weapon: Dictionary = ecs.get_component(entity_id, "WeaponComponent").duplicate()
					var field: String = parts[1] if parts.size() > 1 else "damage"
					weapon[field] = weapon.get(field, 1.0) * float(modifier[key])
					ecs.add_component(entity_id, "WeaponComponent", weapon)
			_:
				push_warning("TechTreeSystem: unsupported modifier key '%s'" % key)


func _find_research_data(tech_id: String, ecs: ECS) -> Dictionary:
	# Look up research definition from a ResearchRegistry entity in the ECS
	var registries: Array[int] = ecs.query(["ResearchRegistry"])
	for reg_id: int in registries:
		var registry: Dictionary = ecs.get_component(reg_id, "ResearchRegistry")
		var entries: Array = registry.get("entries", [])
		for entry: Dictionary in entries:
			if entry.get("research_id", "") == tech_id:
				return entry
	return {}


func _requirement_met(faction_id: int, req: String, ecs: ECS) -> bool:
	# Requirement can be a completed research or a structure tag
	if is_researched(faction_id, req):
		return true
	# Check if faction has a structure with this ID
	var structures: Array[int] = ecs.query(["Structure", "FactionComponent"])
	for s_id: int in structures:
		var faction: Dictionary = ecs.get_component(s_id, "FactionComponent")
		if faction.get("faction_id", -1) != faction_id:
			continue
		var structure: Dictionary = ecs.get_component(s_id, "Structure")
		if structure.get("structure_id", "") == req:
			return true
	return false


func _is_lab_powered(lab_entity_id: int, ecs: ECS) -> bool:
	if lab_entity_id < 0:
		return false
	if not ecs.has_component(lab_entity_id, "TechLab"):
		return false
	if ecs.has_component(lab_entity_id, "PoweredBuilding"):
		var powered: Dictionary = ecs.get_component(lab_entity_id, "PoweredBuilding")
		return powered.get("powered", false)
	# If no PoweredBuilding component, assume powered
	return true


func _deduct_resources(faction_id: int, cost: Dictionary, ecs: ECS) -> bool:
	var economy_entities: Array[int] = ecs.query(["FactionEconomy", "FactionComponent"])
	for e_id: int in economy_entities:
		var e_faction: Dictionary = ecs.get_component(e_id, "FactionComponent")
		if e_faction.get("faction_id", -1) != faction_id:
			continue
		var economy: Dictionary = ecs.get_component(e_id, "FactionEconomy").duplicate()
		var primary_cost: int = cost.get("primary", 0)
		var secondary_cost: int = cost.get("secondary", 0)
		if economy.get("primary", 0) < primary_cost:
			return false
		if economy.get("secondary", 0) < secondary_cost:
			return false
		economy["primary"] = economy.get("primary", 0) - primary_cost
		economy["secondary"] = economy.get("secondary", 0) - secondary_cost
		ecs.add_component(e_id, "FactionEconomy", economy)
		return true
	return false


func _refund_resources(faction_id: int, cost: Dictionary) -> void:
	# Store pending refund — actual credit applied on next tick via ECS access.
	# For simplicity we track refunds in faction state; the economy system
	# should read and apply PendingRefund components each tick.
	if not _faction_research.has(faction_id):
		return
	var state: Dictionary = _faction_research[faction_id]
	var pending: Dictionary = state.get("pending_refund", {})
	pending["primary"] = pending.get("primary", 0) + cost.get("primary", 0)
	pending["secondary"] = pending.get("secondary", 0) + cost.get("secondary", 0)
	state["pending_refund"] = pending


func _sync_to_ecs(faction_id: int, ecs: ECS) -> void:
	var researched: Array = _ensure_faction_state(faction_id).get("researched", [])
	var research_entities: Array[int] = ecs.query(["FactionResearch", "FactionComponent"])
	for r_id: int in research_entities:
		var f: Dictionary = ecs.get_component(r_id, "FactionComponent")
		if f.get("faction_id", -1) == faction_id:
			var comp: Dictionary = ecs.get_component(r_id, "FactionResearch").duplicate()
			comp["unlocked"] = researched.duplicate()
			ecs.add_component(r_id, "FactionResearch", comp)
			return
	# Create new
	var new_entity: int = ecs.create_entity()
	ecs.add_component(new_entity, "FactionComponent", {"faction_id": faction_id})
	ecs.add_component(new_entity, "FactionResearch", {"unlocked": researched.duplicate()})


func _ensure_faction_state(faction_id: int) -> Dictionary:
	if not _faction_research.has(faction_id):
		_faction_research[faction_id] = {"researched": [], "active_research": {}}
	return _faction_research[faction_id]


static func _time_to_ticks(seconds: float) -> float:
	# 15 ticks per second (as per REPAIR_RATE constant pattern in sibling systems)
	return seconds * 15.0
