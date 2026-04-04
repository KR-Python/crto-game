class_name CombatSystem

# Tick pipeline step 9: Target acquisition, damage calculation, weapon cooldowns.
# Does NOT handle death -- DeathSystem (step 10) handles entity removal.
#
# Phase 6 optimization: uses SpatialHash for auto-acquire target search
# instead of iterating all attackable entities. AoE also uses spatial hash.
#
# Reads: Position, Weapon, Health, AttackCommand, FactionComponent, Attackable,
#         Flying, Structure, PoweredOff
# Writes: Health.current (damage), Weapon.cooldown_remaining

const TICKS_PER_SECOND: float = 15.0
const TICK_DURATION: float = 1.0 / TICKS_PER_SECOND

var _armor_matrix: Dictionary = {}
var _spatial_hash: SpatialHash = null


func _init() -> void:
	_load_armor_matrix()


func set_spatial_hash(sh: SpatialHash) -> void:
	_spatial_hash = sh


func _load_armor_matrix() -> void:
	var file := FileAccess.open("res://data/balance/damage_armor_matrix.json", FileAccess.READ)
	if file == null:
		_armor_matrix = _get_default_armor_matrix()
		return
	var json_text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(json_text)
	if parsed is Dictionary and parsed.has("matrix"):
		_armor_matrix = parsed["matrix"]
	else:
		_armor_matrix = _get_default_armor_matrix()


func _parse_yaml(text: String) -> Variant:
	var result: Dictionary = {}
	var current_section: String = ""
	var current_dict: Dictionary = {}
	for line in text.split("\n"):
		var stripped := line.strip_edges()
		if stripped.is_empty() or stripped.begins_with("#"):
			continue
		if stripped == "matrix:":
			continue
		var indent := line.length() - line.lstrip(" ").length()
		if indent == 2 and stripped.ends_with(":"):
			if not current_section.is_empty():
				result[current_section] = current_dict
			current_section = stripped.trim_suffix(":")
			current_dict = {}
		elif indent == 4 and ":" in stripped:
			var parts := stripped.split(":")
			var key := parts[0].strip_edges()
			var val := parts[1].strip_edges()
			current_dict[key] = float(val)
	if not current_section.is_empty():
		result[current_section] = current_dict
	return {"matrix": result}


func _get_default_armor_matrix() -> Dictionary:
	return {
		"kinetic":   {"light": 1.0, "medium": 0.75, "heavy": 0.5, "building": 0.25},
		"explosive": {"light": 1.5, "medium": 1.0,  "heavy": 0.75, "building": 1.5},
		"energy":    {"light": 0.75, "medium": 1.0,  "heavy": 1.25, "building": 1.0},
		"chemical":  {"light": 1.5, "medium": 1.25, "heavy": 0.5, "building": 0.25},
		"fire":      {"light": 1.75, "medium": 1.0,  "heavy": 0.25, "building": 1.5},
	}


func _get_armor_matrix() -> Dictionary:
	return _armor_matrix


func tick(ecs: ECS, tick_count: int) -> void:
	var weapon_entities: Array = ecs.query(["Weapon", "Position"])
	for entity_id in weapon_entities:
		var weapon: Dictionary = ecs.get_component(entity_id, "Weapon")
		var position: Dictionary = ecs.get_component(entity_id, "Position")

		# 1. Cooldown tick
		weapon["cooldown_remaining"] = maxf(weapon.get("cooldown_remaining", 0.0) - TICK_DURATION, 0.0)
		ecs.set_component(entity_id, "Weapon", weapon)

		# 2. Skip if on cooldown
		if weapon["cooldown_remaining"] > 0.0:
			continue

		# 3. Skip if powered off
		if ecs.has_component(entity_id, "PoweredOff"):
			continue

		# 4. Target acquisition (spatial hash accelerated)
		var target_id: int = _acquire_target(ecs, entity_id, weapon, position)
		if target_id < 0:
			continue

		# 5. Validate target is alive
		if not ecs.entity_exists(target_id):
			_clear_attack_command(ecs, entity_id)
			continue
		var target_health: Dictionary = ecs.get_component(target_id, "Health")
		if target_health.is_empty() or target_health.get("current", 0.0) <= 0.0:
			_clear_attack_command(ecs, entity_id)
			continue

		# 6. Range check
		var target_pos: Dictionary = ecs.get_component(target_id, "Position")
		var dist: float = _distance(position, target_pos)
		if dist > weapon.get("range", 0.0):
			continue

		# 7. Fire -- apply damage
		var damage: float = _calculate_damage(weapon, target_health)
		target_health["current"] = maxf(target_health["current"] - damage, 0.0)
		ecs.set_component(target_id, "Health", target_health)

		# 8. AoE damage (spatial hash accelerated)
		var aoe: float = weapon.get("area_of_effect", 0.0)
		if aoe > 0.0:
			_apply_aoe_damage(ecs, entity_id, target_id, target_pos, weapon, aoe)

		# 9. Reset cooldown
		weapon["cooldown_remaining"] = weapon.get("cooldown", 1.0)
		ecs.set_component(entity_id, "Weapon", weapon)


func _acquire_target(ecs: ECS, entity_id: int, weapon: Dictionary, position: Dictionary) -> int:
	# Explicit AttackCommand takes priority
	if ecs.has_component(entity_id, "AttackCommand"):
		var cmd: Dictionary = ecs.get_component(entity_id, "AttackCommand")
		var target: int = cmd.get("target", -1)
		if target >= 0 and ecs.entity_exists(target):
			return target
		_clear_attack_command(ecs, entity_id)

	# Auto-acquire: use spatial hash for candidates within range
	var my_faction: int = _get_faction(ecs, entity_id)
	var weapon_range: float = weapon.get("range", 0.0)
	var targets_mask: Variant = weapon.get("targets", [])
	var pos := Vector2(position.get("x", 0.0), position.get("y", 0.0))

	var candidates: Array
	if _spatial_hash != null:
		candidates = _spatial_hash.query_radius(pos, weapon_range)
	else:
		candidates = ecs.query(["Attackable", "Position", "Health", "FactionComponent"])

	var best_id: int = -1
	var best_dist: float = INF

	for candidate_id in candidates:
		if candidate_id == entity_id:
			continue
		if not ecs.has_component(candidate_id, "Attackable"):
			continue
		if not ecs.has_component(candidate_id, "Health"):
			continue
		var candidate_faction: int = _get_faction(ecs, candidate_id)
		if candidate_faction == my_faction:
			continue
		var candidate_health: Dictionary = ecs.get_component(candidate_id, "Health")
		if candidate_health.get("current", 0.0) <= 0.0:
			continue
		if not _matches_target_mask(ecs, candidate_id, targets_mask):
			continue
		var candidate_pos: Dictionary = ecs.get_component(candidate_id, "Position")
		var dist: float = _distance(position, candidate_pos)
		if dist > weapon_range:
			continue
		if dist < best_dist or (dist == best_dist and candidate_id < best_id):
			best_dist = dist
			best_id = candidate_id

	return best_id


func _matches_target_mask(ecs: ECS, candidate_id: int, targets_mask: Variant) -> bool:
	if targets_mask is not Array:
		return true
	if targets_mask.is_empty():
		return true
	var is_flying: bool = ecs.has_component(candidate_id, "Flying")
	var is_structure: bool = ecs.has_component(candidate_id, "Structure")
	for target_type in targets_mask:
		match target_type:
			"ground":
				if not is_flying and not is_structure:
					return true
			"air":
				if is_flying:
					return true
			"structure":
				if is_structure:
					return true
	return false


func _calculate_damage(weapon: Dictionary, target_health: Dictionary) -> float:
	var matrix: Dictionary = _get_armor_matrix()
	var damage_type: String = weapon.get("damage_type", "kinetic")
	var armor_type: String = target_health.get("armor_type", "medium")
	var multiplier: float = 1.0
	if matrix.has(damage_type) and matrix[damage_type].has(armor_type):
		multiplier = matrix[damage_type][armor_type]
	return weapon.get("damage", 0.0) * multiplier


func _apply_aoe_damage(ecs: ECS, attacker_id: int, primary_target_id: int,
		target_pos: Dictionary, weapon: Dictionary, aoe_radius: float) -> void:
	var attacker_faction: int = _get_faction(ecs, attacker_id)
	var center := Vector2(target_pos.get("x", 0.0), target_pos.get("y", 0.0))

	var candidates: Array
	if _spatial_hash != null:
		candidates = _spatial_hash.query_radius(center, aoe_radius)
	else:
		candidates = ecs.query(["Attackable", "Position", "Health"])

	for candidate_id in candidates:
		if candidate_id == primary_target_id or candidate_id == attacker_id:
			continue
		if not ecs.has_component(candidate_id, "Attackable"):
			continue
		var candidate_pos: Dictionary = ecs.get_component(candidate_id, "Position")
		var dist: float = _distance(target_pos, candidate_pos)
		if dist > aoe_radius:
			continue
		var candidate_health: Dictionary = ecs.get_component(candidate_id, "Health")
		if candidate_health.get("current", 0.0) <= 0.0:
			continue
		var base_damage: float = _calculate_damage(weapon, candidate_health)
		var candidate_faction: int = _get_faction(ecs, candidate_id)
		var damage_mult: float = 0.5 if candidate_faction == attacker_faction else 1.0
		candidate_health["current"] = maxf(candidate_health["current"] - base_damage * damage_mult, 0.0)
		ecs.set_component(candidate_id, "Health", candidate_health)


func _get_faction(ecs: ECS, entity_id: int) -> int:
	if ecs.has_component(entity_id, "FactionComponent"):
		var faction: Dictionary = ecs.get_component(entity_id, "FactionComponent")
		return faction.get("faction_id", -1)
	return -1


func _clear_attack_command(ecs: ECS, entity_id: int) -> void:
	if ecs.has_component(entity_id, "AttackCommand"):
		ecs.remove_component(entity_id, "AttackCommand")


func _distance(a: Dictionary, b: Dictionary) -> float:
	var dx: float = a.get("x", 0.0) - b.get("x", 0.0)
	var dy: float = a.get("y", 0.0) - b.get("y", 0.0)
	return sqrt(dx * dx + dy * dy)
