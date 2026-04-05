class_name AIPartner
extends Node
## Base class for all AI partner controllers.
## Partners emit commands via _emit_command() and communicate via send_status().

var role: String = ""
var recent_pings: Array = []  # [{type: String, position: Vector2, tick: int}]
var _commands: Array = []  # emitted commands buffer
var _status_messages: Array = []  # [{message: String, tick: int}]
var _status_cooldown_ticks: int = 150  # ~10 seconds at 15 ticks/s
var _last_status_tick: int = -9999


func _ai_tick(_tick_count: int) -> void:
	pass


func _emit_command(command_type: String, params: Dictionary) -> void:
	_commands.append({"type": command_type, "params": params})


func send_status(message: String, tick_count: int) -> void:
	if tick_count - _last_status_tick < _status_cooldown_ticks:
		return
	_last_status_tick = tick_count
	_status_messages.append({"message": message, "tick": tick_count})


func consume_commands() -> Array:
	var cmds := _commands.duplicate()
	_commands.clear()
	return cmds


func consume_status_messages() -> Array:
	var msgs := _status_messages.duplicate()
	_status_messages.clear()
	return msgs


func clear_pings() -> void:
	recent_pings.clear()
