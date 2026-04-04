## permission_system.gd
## Tick pipeline step 2 — validates all commands before execution.
class_name PermissionSystem

var role_manager: RoleManager
var command_queue: CommandQueue

var validated_commands: Array[Dictionary] = []
var rejected_commands: Array[Dictionary] = []

enum CommandError {
	PERMISSION_DENIED,
	ENTITY_NOT_OWNED,
	INVALID_TARGET,
	TECH_NOT_RESEARCHED,
	INSUFFICIENT_RESOURCES,
	INVALID_PLACEMENT,
	QUEUE_FULL,
	UNIT_CAP_REACHED,
	INVALID_COMMAND,
	TICK_EXPIRED,
	WRONG_ROLE,
	PREREQUISITE_NOT_MET,
}

const DEFENSE_STRUCTURE_KEYWORDS: Array = [
	"turret", "wall", "gate", "mine", "sensor", "bunker", "defense"
]

func _init(rm: RoleManager = null, cq: CommandQueue = null) -> void:
	role_manager = rm
	command_queue = cq

func tick(ecs: ECS, tick_count: int) -> void:
	validated_commands.clear()
	rejected_commands.clear()
	if command_queue == null:
		return
	command_queue.clear_expired(tick_count)
	var commands: Array[Dictionary] = command_queue.get_commands_for_tick(tick_count)
	for command in commands:
		var result: Dictionary = can_execute_full(ecs, command)
		if result["allowed"]:
			validated_commands.append(command)
		else:
			var rejection: Dictionary = command.duplicate()
			rejection["error_code"] = result["error_code"]
			rejection["error_name"] = CommandError.keys()[result["error_code"]]
			rejected_commands.append(rejection)
	command_queue.clear_tick(tick_count)

func can_execute(player_id: int, command: Dictionary) -> Dictionary:
	return can_execute_full({}, command, player_id)

func can_execute_full(ecs: Dictionary, command: Dictionary, override_player_id: int = -1) -> Dictionary:
	var player_id: int = override_player_id if override_player_id >= 0 else command.get("player_id", -1)
	if not _command_is_valid_shape(command):
		return _deny(CommandError.INVALID_COMMAND)
	var action: String = command["action"]
	var claimed_role: String = command["role"]
	var actual_role: String = role_manager.get_player_role(player_id)
	if actual_role == "":
		return _deny(CommandError.WRONG_ROLE)
	if not _player_can_act_as(actual_role, claimed_role):
		return _deny(CommandError.WRONG_ROLE)
	var allowed_actions: Array[String] = role_manager.get_all_allowed_actions(actual_role)
	if action not in allowed_actions:
		return _deny(CommandError.PERMISSION_DENIED)
	var entity_check: Dictionary = _check_entity_ownership(command, actual_role, ecs)
	if not entity_check["allowed"]:
		return entity_check
	var sub_check: Dictionary = _check_sub_role_restrictions(command, actual_role, ecs)
	if not sub_check["allowed"]:
		return sub_check
	var cap_check: Dictionary = _check_unit_cap(actual_role)
	if not cap_check["allowed"]:
		return cap_check
	return _allow()

func _deny(error: CommandError) -> Dictionary:
	return {"allowed": false, "error_code": error}

func _allow() -> Dictionary:
	return {"allowed": true, "error_code": -1}

func _command_is_valid_shape(cmd: Dictionary) -> bool:
	return cmd.has("player_id") and cmd.has("role") and cmd.has("action") and cmd.has("params")

func _player_can_act_as(actual_role: String, claimed_role: String) -> bool:
	if actual_role == claimed_role:
		return true
	var effective_claimed: String = role_manager.get_effective_role(claimed_role)
	return effective_claimed == actual_role

func _check_entity_ownership(command: Dictionary, role: String, ecs: Dictionary) -> Dictionary:
	var action: String = command["action"]
	var params: Dictionary = command.get("params", {})
	var unit_array_actions: Array = [
		"MOVE_UNITS", "ATTACK_TARGET", "ATTACK_MOVE", "PATROL",
		"GUARD", "STOP", "HOLD_POSITION", "SET_FORMATION", "BOMBING_RUN"
	]
	if action in unit_array_actions:
		var unit_ids = params.get("unit_ids", [])
		for uid in unit_ids:
			var check: Dictionary = _check_owns_entity(uid, role, ecs)
			if not check["allowed"]:
				return check
	var single_unit_actions: Array = ["INFILTRATE", "SABOTAGE", "MARK_TARGET",
		"REPAIR_STRUCTURE", "REPAIR_VEHICLE"]
	if action in single_unit_actions:
		var uid: int = params.get("unit_id", -1)
		if uid == -1:
			return _deny(CommandError.INVALID_COMMAND)
		var check: Dictionary = _check_owns_entity(uid, role, ecs)
		if not check["allowed"]:
			return check
	var factory_actions: Array = ["QUEUE_PRODUCTION", "CANCEL_PRODUCTION", "SET_RALLY_POINT"]
	if action in factory_actions:
		var factory_id: int = params.get("factory_id", -1)
		if factory_id == -1:
			return _deny(CommandError.INVALID_COMMAND)
		var check: Dictionary = _check_owns_entity(factory_id, role, ecs)
		if not check["allowed"]:
			return check
	return _allow()

func _check_owns_entity(entity_id: int, role: String, ecs: Dictionary) -> Dictionary:
	var owner: String = role_manager.get_entity_role(entity_id)
	if owner == "" and not ecs.is_empty():
		return _deny(CommandError.INVALID_TARGET)
	if owner == "":
		return _allow()
	if owner == role:
		return _allow()
	var effective_owner: String = role_manager.get_effective_role(owner)
	var effective_role: String = role_manager.get_effective_role(role)
	if effective_owner == effective_role or effective_owner == role:
		return _allow()
	return _deny(CommandError.ENTITY_NOT_OWNED)

func _check_sub_role_restrictions(command: Dictionary, role: String, ecs: Dictionary) -> Dictionary:
	var action: String = command["action"]
	var params: Dictionary = command.get("params", {})
	if action == "PLACE_STRUCTURE" and role == "chief_engineer":
		var structure_type: String = params.get("structure_type", "")
		if not _is_defense_structure(structure_type):
			return _deny(CommandError.PERMISSION_DENIED)
	return _allow()

func _check_unit_cap(role: String) -> Dictionary:
	var cap: int = role_manager._definitions.get_unit_cap(role)
	if cap == -1:
		return _allow()
	var current_count: int = role_manager.get_role_entities(role).size()
	if current_count > cap:
		return _deny(CommandError.UNIT_CAP_REACHED)
	return _allow()

func _is_defense_structure(structure_type: String) -> bool:
	var lower: String = structure_type.to_lower()
	for kw in DEFENSE_STRUCTURE_KEYWORDS:
		if lower.contains(kw):
			return true
	return false
