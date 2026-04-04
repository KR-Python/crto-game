## role_manager.gd
## Manages player-to-role and entity-to-role assignments.
## Handles role merging for sub-max-player sessions.
class_name RoleManager

const RoleDefs = preload("res://src/roles/role_definitions.gd")

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------
var _definitions: RoleDefinitions

## player_id → role name
var _player_roles: Dictionary = {}

## role name → player_id (-1 if AI-controlled)
var _role_players: Dictionary = {}

## entity_id → role name
var _entity_roles: Dictionary = {}

## role name → Array[int] entity_ids
var _role_entities: Dictionary = {}

## role name → effective role name (what role absorbed it; empty = not absorbed)
var _merge_map: Dictionary = {}

## role name → Array[String] extra allowed actions gained from absorbed roles
var _merged_permissions: Dictionary = {}

# Pending transfer confirmations: {transfer_id: {entity_id, from_role, to_role}}
var _pending_transfers: Dictionary = {}
var _transfer_id_counter: int = 0

# Signal emitted when entity ownership changes
signal entity_transferred(entity_id: int, from_role: String, to_role: String)

func _init(definitions: RoleDefinitions = null) -> void:
	_definitions = definitions if definitions != null else RoleDefinitions.new()
	_reset_role_entities()

func _reset_role_entities() -> void:
	for role in RoleDefinitions.ALL_ROLES:
		_role_entities[role] = []
		_merge_map[role] = ""
		_merged_permissions[role] = []

# ---------------------------------------------------------------------------
# Player ↔ Role
# ---------------------------------------------------------------------------

## Assign a player to a role. Returns false if role already taken by another human.
func assign_role(player_id: int, role: String) -> bool:
	if not role in RoleDefinitions.ALL_ROLES:
		push_error("RoleManager.assign_role: unknown role '%s'" % role)
		return false
	var current_owner: int = _role_players.get(role, -1)
	if current_owner != -1 and current_owner != player_id:
		push_warning("RoleManager.assign_role: role '%s' already owned by player %d" % [role, current_owner])
		return false
	# Remove player from any previous role
	var prev_role: String = _player_roles.get(player_id, "")
	if prev_role != "" and prev_role != role:
		_role_players[prev_role] = -1
	_player_roles[player_id] = role
	_role_players[role] = player_id
	return true

## Returns the role name for a player, or "" if not assigned.
func get_player_role(player_id: int) -> String:
	return _player_roles.get(player_id, "")

## Returns the player_id for a role, or -1 if AI-controlled / unassigned.
func get_role_player(role: String) -> int:
	return _role_players.get(role, -1)

# ---------------------------------------------------------------------------
# Entity ↔ Role
# ---------------------------------------------------------------------------

## Assign an entity to a role.
func assign_entity(entity_id: int, role: String) -> void:
	if not role in RoleDefinitions.ALL_ROLES:
		push_error("RoleManager.assign_entity: unknown role '%s'" % role)
		return
	# Remove from old role if present
	var old_role: String = _entity_roles.get(entity_id, "")
	if old_role != "" and old_role != role:
		_role_entities[old_role].erase(entity_id)
	_entity_roles[entity_id] = role
	if entity_id not in _role_entities[role]:
		_role_entities[role].append(entity_id)

## Returns the role that owns entity_id, or "" if unowned.
func get_entity_role(entity_id: int) -> String:
	return _entity_roles.get(entity_id, "")

## Returns all entity IDs owned by a role.
func get_role_entities(role: String) -> Array[int]:
	return _role_entities.get(role, []) as Array[int]

## Transfer entity from one role to another.
## If requires_confirm is true, adds to pending queue and returns false until confirmed.
## Both roles must exist and from_role must currently own the entity.
func transfer_entity(entity_id: int, from_role: String, to_role: String, requires_confirm: bool = true) -> bool:
	if _entity_roles.get(entity_id, "") != from_role:
		push_warning("RoleManager.transfer_entity: entity %d not owned by '%s'" % [entity_id, from_role])
		return false
	if not from_role in RoleDefinitions.ALL_ROLES or not to_role in RoleDefinitions.ALL_ROLES:
		push_error("RoleManager.transfer_entity: unknown role in transfer %s → %s" % [from_role, to_role])
		return false
	if requires_confirm:
		_transfer_id_counter += 1
		_pending_transfers[_transfer_id_counter] = {
			"entity_id": entity_id,
			"from_role": from_role,
			"to_role": to_role,
		}
		return false  # Caller must call confirm_transfer()
	_do_transfer(entity_id, from_role, to_role)
	return true

## Confirm a pending transfer by its ID. Returns false if ID unknown.
func confirm_transfer(transfer_id: int) -> bool:
	if not transfer_id in _pending_transfers:
		return false
	var t: Dictionary = _pending_transfers[transfer_id]
	_pending_transfers.erase(transfer_id)
	_do_transfer(t["entity_id"], t["from_role"], t["to_role"])
	return true

func _do_transfer(entity_id: int, from_role: String, to_role: String) -> void:
	_role_entities[from_role].erase(entity_id)
	_entity_roles[entity_id] = to_role
	if entity_id not in _role_entities[to_role]:
		_role_entities[to_role].append(entity_id)
	entity_transferred.emit(entity_id, from_role, to_role)

# ---------------------------------------------------------------------------
# Role merging
# ---------------------------------------------------------------------------

## Apply merge rules for the given player count.
## The absorbing role gains all permissions of absorbed roles.
func apply_merge_rules(player_count: int) -> void:
	# Reset any existing merge state
	for role in RoleDefinitions.ALL_ROLES:
		_merge_map[role] = ""
		_merged_permissions[role] = []

	var rules: Array = _definitions.get_merge_rules(player_count)
	for rule in rules:
		var absorber: String = rule["role"]
		var absorbed_list: Array = rule["absorbs"]
		for absorbed in absorbed_list:
			_merge_map[absorbed] = absorber
			# Copy allowed actions from absorbed into absorber's merged permissions
			var extra_actions: Array[String] = _definitions.get_allowed_actions(absorbed)
			for action in extra_actions:
				if action not in _merged_permissions[absorber]:
					_merged_permissions[absorber].append(action)

## Returns the role name that has effectively absorbed the given role.
## Returns the role itself if it was not absorbed (i.e., it's the active role).
func get_effective_role(role: String) -> String:
	var absorber: String = _merge_map.get(role, "")
	if absorber == "":
		return role
	return absorber

## Returns true if a role has been absorbed by another role.
func is_role_absorbed(role: String) -> bool:
	return _merge_map.get(role, "") != ""

## Returns all extra allowed actions granted to a role via merging.
func get_merged_actions(role: String) -> Array[String]:
	return _merged_permissions.get(role, []) as Array[String]

## Returns ALL allowed actions for a role (own + merged).
func get_all_allowed_actions(role: String) -> Array[String]:
	var own: Array[String] = _definitions.get_allowed_actions(role)
	var merged: Array[String] = get_merged_actions(role)
	var result: Array[String] = own.duplicate()
	for action in merged:
		if action not in result:
			result.append(action)
	return result
