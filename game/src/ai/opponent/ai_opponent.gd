class_name AIOpponent
extends RefCounted
## Base class for AI opponents. Provides shared infrastructure for economy
## access, command emission, and the per-tick loop.

var faction_id: int = 0
var ecs: Dictionary = {}
var army_entities: Array = []
var economy_resources: Dictionary = {"primary": 0, "secondary": 0}
var attack_target: Vector2 = Vector2.ZERO
var base_position: Vector2 = Vector2.ZERO
var _commands: Array = []


func tick(tick_count: int) -> void:
	_commands.clear()
	_ai_tick(tick_count)


func _ai_tick(_tick_count: int) -> void:
	pass


func _emit_command(command_type: String, params: Dictionary) -> void:
	_commands.append({"type": command_type, "params": params})


func get_commands() -> Array:
	return _commands


func get_resources() -> Dictionary:
	return economy_resources
