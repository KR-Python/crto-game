## command_protocol.gd
## Serialization, deserialization, and validation for all player commands.
## Phase 2: JSON-based. Binary optimization deferred to Phase 5.
class_name CommandProtocol

# ---------------------------------------------------------------------------
# CommandAction constants
# ---------------------------------------------------------------------------

const ACTION_MOVE_UNITS := "MoveUnits"
const ACTION_ATTACK_TARGET := "AttackTarget"
const ACTION_ATTACK_MOVE := "AttackMove"
const ACTION_PATROL := "Patrol"
const ACTION_GUARD := "Guard"
const ACTION_STOP := "Stop"
const ACTION_HOLD_POSITION := "HoldPosition"
const ACTION_SET_FORMATION := "SetFormation"
const ACTION_PLACE_STRUCTURE := "PlaceStructure"
const ACTION_CANCEL_STRUCTURE := "CancelStructure"
const ACTION_QUEUE_PRODUCTION := "QueueProduction"
const ACTION_CANCEL_PRODUCTION := "CancelProduction"
const ACTION_SET_RALLY_POINT := "SetRallyPoint"
const ACTION_RESEARCH := "Research"
const ACTION_CANCEL_RESEARCH := "CancelResearch"
const ACTION_PING_MAP := "PingMap"
const ACTION_REQUEST_FROM_ROLE := "RequestFromRole"
const ACTION_APPROVE_SUPERWEAPON := "ApproveSuperweapon"
const ACTION_TRANSFER_CONTROL := "TransferControl"
const ACTION_TOGGLE_POWER := "TogglePower"
const ACTION_INFILTRATE := "Infiltrate"
const ACTION_SABOTAGE := "Sabotage"
const ACTION_MARK_TARGET := "MarkTarget"
const ACTION_REPAIR_STRUCTURE := "RepairStructure"
const ACTION_REPAIR_VEHICLE := "RepairVehicle"
const ACTION_PLACE_WALL := "PlaceWall"
const ACTION_PLACE_MINE := "PlaceMine"
const ACTION_BOMBING_RUN := "BombingRun"
const ACTION_PARADROP := "Paradrop"

## All valid action strings for quick lookup.
const VALID_ACTIONS: Array[String] = [
	ACTION_MOVE_UNITS, ACTION_ATTACK_TARGET, ACTION_ATTACK_MOVE, ACTION_PATROL,
	ACTION_GUARD, ACTION_STOP, ACTION_HOLD_POSITION, ACTION_SET_FORMATION,
	ACTION_PLACE_STRUCTURE, ACTION_CANCEL_STRUCTURE,
	ACTION_QUEUE_PRODUCTION, ACTION_CANCEL_PRODUCTION, ACTION_SET_RALLY_POINT,
	ACTION_RESEARCH, ACTION_CANCEL_RESEARCH,
	ACTION_PING_MAP, ACTION_REQUEST_FROM_ROLE,
	ACTION_APPROVE_SUPERWEAPON, ACTION_TRANSFER_CONTROL, ACTION_TOGGLE_POWER,
	ACTION_INFILTRATE, ACTION_SABOTAGE, ACTION_MARK_TARGET,
	ACTION_REPAIR_STRUCTURE, ACTION_REPAIR_VEHICLE,
	ACTION_PLACE_WALL, ACTION_PLACE_MINE,
	ACTION_BOMBING_RUN, ACTION_PARADROP,
]

## Required param keys per action.
const _REQUIRED_PARAMS: Dictionary = {
	ACTION_MOVE_UNITS: ["unit_ids", "destination"],
	ACTION_ATTACK_TARGET: ["unit_ids", "target_id"],
	ACTION_ATTACK_MOVE: ["unit_ids", "destination"],
	ACTION_PATROL: ["unit_ids", "waypoints"],
	ACTION_GUARD: ["unit_ids", "guard_target_id"],
	ACTION_STOP: ["unit_ids"],
	ACTION_HOLD_POSITION: ["unit_ids"],
	ACTION_SET_FORMATION: ["unit_ids", "formation"],
	ACTION_PLACE_STRUCTURE: ["structure_type", "position"],
	ACTION_CANCEL_STRUCTURE: ["structure_id"],
	ACTION_QUEUE_PRODUCTION: ["factory_id", "unit_type"],
	ACTION_CANCEL_PRODUCTION: ["factory_id", "queue_index"],
	ACTION_SET_RALLY_POINT: ["factory_id", "position"],
	ACTION_RESEARCH: ["lab_id", "tech_id"],
	ACTION_CANCEL_RESEARCH: ["lab_id"],
	ACTION_PING_MAP: ["position", "ping_type"],
	ACTION_REQUEST_FROM_ROLE: ["target_role", "request"],
	ACTION_APPROVE_SUPERWEAPON: ["weapon_id", "confirmed"],
	ACTION_TRANSFER_CONTROL: ["entity_id", "to_role"],
	ACTION_TOGGLE_POWER: ["building_id"],
	ACTION_INFILTRATE: ["unit_id", "target_id"],
	ACTION_SABOTAGE: ["unit_id", "target_id"],
	ACTION_MARK_TARGET: ["unit_id", "target_id"],
	ACTION_REPAIR_STRUCTURE: ["engineer_id", "target_id"],
	ACTION_REPAIR_VEHICLE: ["engineer_id", "target_id"],
	ACTION_PLACE_WALL: ["positions"],
	ACTION_PLACE_MINE: ["position"],
	ACTION_BOMBING_RUN: ["unit_ids", "target_position"],
	ACTION_PARADROP: ["transport_id", "drop_position"],
}

# ---------------------------------------------------------------------------
# Serialization — JSON for Phase 2
# ---------------------------------------------------------------------------

## Serialize a command dict to bytes for network transmission.
static func serialize(command: Dictionary) -> PackedByteArray:
	return JSON.stringify(command).to_utf8_buffer()


## Deserialize bytes back to command dict.
static func deserialize(data: PackedByteArray) -> Dictionary:
	var json := JSON.new()
	var err := json.parse(data.get_string_from_utf8())
	if err != OK:
		push_error("CommandProtocol.deserialize: JSON parse error: %s" % json.get_error_message())
		return {}
	var result = json.get_data()
	if result is Dictionary:
		return result
	push_error("CommandProtocol.deserialize: expected Dictionary, got %s" % typeof(result))
	return {}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

## Validate command structure. Returns {valid: bool, error: String}.
static func validate(command: Dictionary) -> Dictionary:
	for key: String in ["player_id", "role", "tick", "action", "params"]:
		if not command.has(key):
			return {"valid": false, "error": "Missing required field: %s" % key}

	if not (command["player_id"] is int or command["player_id"] is float):
		return {"valid": false, "error": "player_id must be numeric"}
	if not command["role"] is String:
		return {"valid": false, "error": "role must be a String"}
	if not (command["tick"] is int or command["tick"] is float):
		return {"valid": false, "error": "tick must be numeric"}
	if not command["action"] is String:
		return {"valid": false, "error": "action must be a String"}
	if not command["params"] is Dictionary:
		return {"valid": false, "error": "params must be a Dictionary"}

	var action: String = command["action"]
	if action not in VALID_ACTIONS:
		return {"valid": false, "error": "Unknown action: %s" % action}

	if action in _REQUIRED_PARAMS:
		var required: Array = _REQUIRED_PARAMS[action]
		var params: Dictionary = command["params"]
		for param_key: String in required:
			if not params.has(param_key):
				return {"valid": false, "error": "Action %s missing param: %s" % [action, param_key]}

	return {"valid": true, "error": ""}
