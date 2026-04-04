class_name SuperweaponSystem

# Tick pipeline step: Dual-confirm superweapon protocol.
# Commander initiates targeting; Field Marshal confirms (or vice versa).
# Both must confirm within CONFIRMATION_WINDOW ticks or the window expires.
#
# Reads:  Structure, FactionComponent, Health (to verify weapon still alive)
# Writes: Health (AoE damage on fire), emits signals for UI/effects

const CONFIRMATION_WINDOW: int = 30  # ticks (~2 seconds at 15 TPS)

# { weapon_entity_id: {
#     commander_confirmed: bool,
#     fm_confirmed: bool,
#     confirm_tick: int,       # tick when FIRST confirmation arrived
#     target: Vector2
# } }
var _pending_confirmations: Dictionary = {}

signal superweapon_fired(weapon_id: int, target: Vector2, effect_type: String)
signal confirmation_pending(weapon_id: int, waiting_for: String)  # "field_marshal" or "commander"
signal confirmation_expired(weapon_id: int)


func tick(ecs: ECS, tick_count: int) -> void:
	_expire_stale_windows(tick_count)
	_fire_ready_weapons(ecs, tick_count)


func initiate_targeting(weapon_entity_id: int, target: Vector2, tick_count: int) -> void:
	# Commander opens a confirmation window for the given weapon + target.
	if not _pending_confirmations.has(weapon_entity_id):
		_pending_confirmations[weapon_entity_id] = {
			"commander_confirmed": true,
			"fm_confirmed": false,
			"confirm_tick": tick_count,
			"target": target,
		}
	else:
		# Update target if already pending (Commander changed their mind)
		var entry: Dictionary = _pending_confirmations[weapon_entity_id]
		entry["target"] = target
		entry["commander_confirmed"] = true

	confirmation_pending.emit(weapon_entity_id, "field_marshal")


func confirm(weapon_entity_id: int, role: String, tick_count: int) -> bool:
	# Returns true if the weapon fired (both roles confirmed within window).
	if not _pending_confirmations.has(weapon_entity_id):
		push_warning("SuperweaponSystem.confirm: no pending entry for weapon %d" % weapon_entity_id)
		return false

	var entry: Dictionary = _pending_confirmations[weapon_entity_id]

	# Check window has not already expired
	if tick_count - entry["confirm_tick"] > CONFIRMATION_WINDOW:
		_expire_entry(weapon_entity_id)
		return false

	if role == "commander":
		entry["commander_confirmed"] = true
		if not entry["fm_confirmed"]:
			confirmation_pending.emit(weapon_entity_id, "field_marshal")
	elif role == "field_marshal":
		entry["fm_confirmed"] = true
		if not entry["commander_confirmed"]:
			confirmation_pending.emit(weapon_entity_id, "commander")
	else:
		push_warning("SuperweaponSystem.confirm: unknown role '%s'" % role)
		return false

	# Both confirmed — weapon fires on next tick() call; return true now.
	if entry["commander_confirmed"] and entry["fm_confirmed"]:
		return true

	return false


func _fire_ready_weapons(ecs: ECS, tick_count: int) -> void:
	var to_fire: Array[int] = []
	for weapon_id: int in _pending_confirmations:
		var entry: Dictionary = _pending_confirmations[weapon_id]
		if entry["commander_confirmed"] and entry["fm_confirmed"]:
			to_fire.append(weapon_id)

	for weapon_id: int in to_fire:
		var entry: Dictionary = _pending_confirmations[weapon_id]
		_fire_weapon(weapon_id, entry["target"], ecs)
		_pending_confirmations.erase(weapon_id)


func _expire_stale_windows(tick_count: int) -> void:
	var expired: Array[int] = []
	for weapon_id: int in _pending_confirmations:
		var entry: Dictionary = _pending_confirmations[weapon_id]
		# Only expire if not yet both confirmed
		var both: bool = entry["commander_confirmed"] and entry["fm_confirmed"]
		if not both and tick_count - entry["confirm_tick"] > CONFIRMATION_WINDOW:
			expired.append(weapon_id)

	for weapon_id: int in expired:
		_expire_entry(weapon_id)


func _expire_entry(weapon_id: int) -> void:
	_pending_confirmations.erase(weapon_id)
	confirmation_expired.emit(weapon_id)


func _fire_weapon(weapon_entity_id: int, target: Vector2, ecs: ECS) -> void:
	# Resolve weapon stats from the structure's definition component.
	var damage: float = 2000.0
	var radius: float = 15.0
	var effect_type: String = "explosion"

	if ecs.has_component(weapon_entity_id, "SuperweaponStats"):
		var stats: Dictionary = ecs.get_component(weapon_entity_id, "SuperweaponStats")
		damage = stats.get("damage", damage)
		radius = stats.get("radius", radius)
		effect_type = stats.get("effect_type", effect_type)

	# Apply AoE damage to all Attackable entities within radius.
	var targets: Array[int] = ecs.query(["Position", "Health", "Attackable"])
	for entity_id: int in targets:
		if entity_id == weapon_entity_id:
			continue
		var pos: Dictionary = ecs.get_component(entity_id, "Position")
		var dx: float = pos.get("x", 0.0) - target.x
		var dy: float = pos.get("y", 0.0) - target.y
		var dist_sq: float = dx * dx + dy * dy
		if dist_sq <= radius * radius:
			var health: Dictionary = ecs.get_component(entity_id, "Health")
			var new_hp: float = maxf(0.0, health.get("current", 0.0) - damage)
			health["current"] = new_hp
			ecs.add_component(entity_id, "Health", health)

	superweapon_fired.emit(weapon_entity_id, target, effect_type)
