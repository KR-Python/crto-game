class_name ScriptedAI
extends AIOpponent
## Iteration 1 scripted AI — hardcoded build order and attack timing.
## Uses FORGE faction by default (aggressive, suits scripted early pressure).
## No adaptation, no scouting, no retreat. Just build and attack on schedule.

var build_order_index: int = 0

const BUILD_ORDER: Array[Dictionary] = [
	{"tick": 0,   "action": "place_structure", "type": "barracks",    "offset": Vector2(3, 0)},
	{"tick": 75,  "action": "place_structure", "type": "refinery",    "offset": Vector2(-3, 0)},
	{"tick": 150, "action": "queue_production", "unit": "conscript",  "count": 3},
	{"tick": 225, "action": "place_structure", "type": "barracks",    "offset": Vector2(5, 0)},
	{"tick": 300, "action": "queue_production", "unit": "conscript",  "count": 3},
	{"tick": 450, "action": "queue_production", "unit": "attack_bike", "count": 2},
	{"tick": 600, "action": "attack"},
	{"tick": 750, "action": "queue_production", "unit": "conscript",  "count": 5},
	{"tick": 900, "action": "attack"},
]


func _run_build_order(tick_count: int) -> void:
	while build_order_index < BUILD_ORDER.size():
		var order: Dictionary = BUILD_ORDER[build_order_index]
		if tick_count < order["tick"]:
			break
		_execute_order(order)
		build_order_index += 1


func _run_attack_logic(_tick_count: int) -> void:
	# Attack waves are triggered by _execute_order when action == "attack".
	# No retreat logic in iteration 1.
	pass


func _execute_order(order: Dictionary) -> void:
	match order["action"]:
		"place_structure":
			var base_pos: Vector2 = _get_base_position()
			var offset: Vector2 = order.get("offset", Vector2.ZERO)
			_emit_command("PlaceStructure", {
				"structure_type": order["type"],
				"position": base_pos + offset * 32.0,
			})
		"queue_production":
			var factories: Array[int] = _get_production_buildings()
			var count: int = order.get("count", 1)
			for i in mini(count, factories.size()):
				_emit_command("QueueProduction", {
					"factory_id": factories[i],
					"unit_type": order["unit"],
				})
		"attack":
			_issue_attack_wave()


func _issue_attack_wave() -> void:
	for entity_id in army_entities:
		_emit_command("MoveUnits", {
			"unit_ids": [entity_id],
			"destination": attack_target,
		})


func _get_base_position() -> Vector2:
	return Vector2.ZERO


func _get_production_buildings() -> Array[int]:
	return []
