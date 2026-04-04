class_name SpecOpsAI
extends AIPartner
## Spec Ops AI partner — handles scouting, sabotage opportunities, and
## marking high-value targets for the Field Marshal.

const TICK_INTERVAL: int = 15  # run every 1 second at 15 ticks/s
const MIN_UNITS_FOR_SABOTAGE: int = 3
const SABOTAGE_SUCCESS_THRESHOLD: float = 0.6

## High-value structure types worth sabotaging.
const SABOTAGE_TARGETS: Array = ["power_plant", "refinery", "tech_lab"]

var _scouting_active: bool = false
var _known_enemy_positions: Array = []  # [{type: String, position: Vector2}]
var _available_units: Array = []  # set externally via game state


func _init() -> void:
	role = "spec_ops"


func set_available_units(units: Array) -> void:
	_available_units = units


func set_known_enemies(enemies: Array) -> void:
	_known_enemy_positions = enemies


func _ai_tick(tick_count: int) -> void:
	if tick_count % TICK_INTERVAL != 0:
		return

	var units: Array = _get_spec_ops_units()

	# 1. Respond to human pings first
	_respond_to_pings(tick_count)

	# 2. Always maintain at least 1 scout
	_ensure_scouting(units, tick_count)

	# 3. Look for sabotage opportunities
	if units.size() >= MIN_UNITS_FOR_SABOTAGE:
		_look_for_sabotage(tick_count)

	# 4. Mark high-value targets for FM
	_mark_priority_targets(tick_count)


func _get_spec_ops_units() -> Array:
	return _available_units


func _respond_to_pings(tick_count: int) -> void:
	for ping in recent_pings:
		match ping["type"]:
			"scout":
				_emit_command("MoveUnit", {
					"unit_type": "scout",
					"position": ping["position"],
				})
				send_status("Scouting pinged location", tick_count)
			"sabotage":
				_emit_command("Sabotage", {
					"position": ping["position"],
				})
				send_status("Attempting sabotage at ping", tick_count)
	recent_pings.clear()


func _ensure_scouting(units: Array, tick_count: int) -> void:
	if units.is_empty():
		return
	if _scouting_active:
		return
	_emit_command("Scout", {
		"unit_index": 0,
		"direction": "unexplored",
	})
	_scouting_active = true
	send_status("Sending scout to unexplored area", tick_count)


func _look_for_sabotage(tick_count: int) -> void:
	for enemy in _known_enemy_positions:
		if not enemy.has("type"):
			continue
		if not SABOTAGE_TARGETS.has(enemy["type"]):
			continue
		var estimated_success: float = _estimate_sabotage_success(enemy)
		if estimated_success > SABOTAGE_SUCCESS_THRESHOLD:
			_emit_command("Sabotage", {
				"target_type": enemy["type"],
				"position": enemy["position"],
			})
			send_status("Going for sabotage on their " + enemy["type"], tick_count)
			break  # one sabotage attempt per tick


func _estimate_sabotage_success(target: Dictionary) -> float:
	var nearby_defenders: int = 0
	var target_pos: Vector2 = target["position"]
	for enemy in _known_enemy_positions:
		if not enemy.has("position"):
			continue
		if enemy == target:
			continue
		if target_pos.distance_to(enemy["position"]) < 256.0:
			nearby_defenders += 1
	return maxf(0.0, 0.9 - nearby_defenders * 0.15)


func _mark_priority_targets(_tick_count: int) -> void:
	for enemy in _known_enemy_positions:
		if not enemy.has("type"):
			continue
		if enemy["type"] in ["artillery", "support", "power_plant", "tech_lab"]:
			_emit_command("MarkTarget", {
				"target_type": enemy["type"],
				"position": enemy["position"],
			})
