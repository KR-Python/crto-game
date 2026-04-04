class_name StealthSystem

# Tick pipeline companion to VisionSystem.
# Handles stealth detection, revelation, and stealth-break expiry.
#
# Reads:  Stealthed, Position, FactionComponent, Detector, Revealed, BreakStealth
# Writes: Revealed, Stealthed (removal)

const REVEAL_DURATION: int = 150       # ticks a unit stays Revealed after detection
const STEALTH_BREAK_CHECK: String = "BreakStealth"


func tick(ecs: ECS, tick_count: int) -> void:
	_expire_revealed(ecs, tick_count)
	_expire_break_stealth(ecs, tick_count)
	_detect_stealthed(ecs, tick_count)


# -- Detection -----------------------------------------------------------------

func _detect_stealthed(ecs: ECS, tick_count: int) -> void:
	var stealthed: Array[int] = ecs.query(["Stealthed", "Position", "FactionComponent"])
	if stealthed.is_empty():
		return

	for stealth_entity: int in stealthed:
		var s_pos: Dictionary = ecs.get_component(stealth_entity, "Position")
		var s_faction: Dictionary = ecs.get_component(stealth_entity, "FactionComponent")
		var stealth_data: Dictionary = ecs.get_component(stealth_entity, "Stealthed")
		var detection_range: float = stealth_data.get("detection_range", 2.0)

		# Skip if already revealed
		if ecs.has_component(stealth_entity, "Revealed"):
			continue

		if _is_detected_by_enemy(stealth_entity, s_pos, s_faction, detection_range, ecs):
			var revealed_comp: Dictionary = Components.revealed(tick_count + REVEAL_DURATION)
			ecs.add_component(stealth_entity, "Revealed", revealed_comp)


func _is_detected_by_enemy(
	stealth_entity: int,
	s_pos: Dictionary,
	s_faction: Dictionary,
	detection_range: float,
	ecs: ECS
) -> bool:
	var enemy_faction_id: int = s_faction.get("faction_id", -1)
	var detectors: Array[int] = ecs.query(["Detector", "Position", "FactionComponent"])

	for detector_id: int in detectors:
		if detector_id == stealth_entity:
			continue

		var d_faction: Dictionary = ecs.get_component(detector_id, "FactionComponent")
		# Only enemy detectors reveal stealthed units
		if d_faction.get("faction_id", -1) == enemy_faction_id:
			continue

		var d_pos: Dictionary = ecs.get_component(detector_id, "Position")
		var detector_data: Dictionary = ecs.get_component(detector_id, "Detector")
		var detector_radius: float = detector_data.get("radius", 3.0)

		if _distance(s_pos, d_pos) <= detector_radius:
			return true

	return false


# -- Expiry --------------------------------------------------------------------

func _expire_revealed(ecs: ECS, tick_count: int) -> void:
	var revealed_entities: Array[int] = ecs.query(["Revealed"])
	for entity_id: int in revealed_entities:
		var comp: Dictionary = ecs.get_component(entity_id, "Revealed")
		if tick_count >= comp.get("revealed_until_tick", 0):
			ecs.remove_component(entity_id, "Revealed")


func _expire_break_stealth(ecs: ECS, tick_count: int) -> void:
	var breaking: Array[int] = ecs.query([STEALTH_BREAK_CHECK])
	for entity_id: int in breaking:
		var comp: Dictionary = ecs.get_component(entity_id, STEALTH_BREAK_CHECK)
		if tick_count >= comp.get("break_until_tick", 0):
			ecs.remove_component(entity_id, STEALTH_BREAK_CHECK)
			# Remove stealth too — break window has elapsed, unit re-cloaks via AbilitySystem
			# Only remove Stealthed if a new cloak hasn't been applied
			# (AbilitySystem handles re-application; here we just clean break marker)


func on_unit_attacked(entity_id: int, tick_count: int, ecs: ECS) -> void:
	# Called externally (e.g. CombatSystem) when a stealthed unit attacks.
	if not ecs.has_component(entity_id, "Stealthed"):
		return
	ecs.remove_component(entity_id, "Stealthed")
	ecs.add_component(entity_id, STEALTH_BREAK_CHECK,
		Components.break_stealth(tick_count + 60))
	# Immediately reveal
	ecs.add_component(entity_id, "Revealed",
		Components.revealed(tick_count + REVEAL_DURATION))


func on_unit_damaged(entity_id: int, tick_count: int, ecs: ECS) -> void:
	# Called externally when a stealthed unit takes damage.
	if not ecs.has_component(entity_id, "Stealthed"):
		return
	ecs.remove_component(entity_id, "Stealthed")
	ecs.add_component(entity_id, STEALTH_BREAK_CHECK,
		Components.break_stealth(tick_count + 60))
	ecs.add_component(entity_id, "Revealed",
		Components.revealed(tick_count + REVEAL_DURATION))


# -- Helpers -------------------------------------------------------------------

func _distance(a: Dictionary, b: Dictionary) -> float:
	var dx: float = a.get("x", 0.0) - b.get("x", 0.0)
	var dy: float = a.get("y", 0.0) - b.get("y", 0.0)
	return sqrt(dx * dx + dy * dy)
