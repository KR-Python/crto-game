## test_permissions.gd
## Permission system tests — 5 PERMISSION_DENIED + 5 allowed scenarios.
## Uses stub classes to avoid requiring a full Godot scene tree.
class_name TestPermissions

# ---------------------------------------------------------------------------
# Stub definitions class (mirrors RoleDefinitions defaults)
# ---------------------------------------------------------------------------
class StubRoleDefinitions:
	const ALL_ROLES: Array = [
		"commander", "quartermaster", "field_marshal",
		"spec_ops", "chief_engineer", "air_marshal"
	]

	const _ACTIONS: Dictionary = {
		"commander": [
			"PLACE_STRUCTURE", "CANCEL_STRUCTURE", "RESEARCH", "CANCEL_RESEARCH",
			"PING_MAP", "REQUEST_FROM_ROLE", "APPROVE_SUPERWEAPON",
			"TOGGLE_POWER", "TRANSFER_CONTROL",
		],
		"quartermaster": [
			"QUEUE_PRODUCTION", "CANCEL_PRODUCTION", "SET_RALLY_POINT",
			"MOVE_UNITS", "STOP", "TOGGLE_POWER", "PING_MAP", "REQUEST_FROM_ROLE",
		],
		"field_marshal": [
			"MOVE_UNITS", "ATTACK_TARGET", "ATTACK_MOVE", "PATROL", "GUARD",
			"STOP", "HOLD_POSITION", "SET_FORMATION",
			"PING_MAP", "REQUEST_FROM_ROLE", "APPROVE_SUPERWEAPON",
		],
		"spec_ops": [
			"MOVE_UNITS", "ATTACK_TARGET", "INFILTRATE", "SABOTAGE", "MARK_TARGET",
			"STOP", "PING_MAP", "REQUEST_FROM_ROLE",
		],
		"chief_engineer": [
			"PLACE_STRUCTURE", "PLACE_WALL", "PLACE_MINE",
			"REPAIR_STRUCTURE", "REPAIR_VEHICLE",
			"MOVE_UNITS", "STOP", "PING_MAP", "REQUEST_FROM_ROLE",
		],
		"air_marshal": [
			"MOVE_UNITS", "ATTACK_TARGET", "PATROL", "BOMBING_RUN", "PARADROP",
			"STOP", "PING_MAP", "REQUEST_FROM_ROLE",
		],
	}

	const _CAPS: Dictionary = {
		"spec_ops": 15,
	}

	const _MERGE_RULES: Dictionary = {
		2: [
			{"role": "commander", "absorbs": ["quartermaster", "chief_engineer"]},
			{"role": "field_marshal", "absorbs": ["spec_ops", "air_marshal"]},
		],
		3: [
			{"role": "commander", "absorbs": ["chief_engineer"]},
			{"role": "field_marshal", "absorbs": ["spec_ops", "air_marshal"]},
		],
		4: [
			{"role": "commander", "absorbs": ["chief_engineer"]},
			{"role": "field_marshal", "absorbs": ["air_marshal"]},
		],
	}

	func get_allowed_actions(role: String) -> Array[String]:
		return _ACTIONS.get(role, []) as Array[String]

	func get_unit_cap(role: String) -> int:
		return _CAPS.get(role, -1)

	func get_merge_rules(player_count: int) -> Array:
		if player_count >= 5:
			return []
		return _MERGE_RULES.get(min(player_count, 4), [])

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _cmd(player_id: int, role: String, action: String, params: Dictionary = {}) -> Dictionary:
	return {"player_id": player_id, "role": role, "tick": 1, "action": action, "params": params}

func _assert(condition: bool, test_name: String, detail: String = "") -> void:
	if condition:
		print("  ✓ PASS: %s" % test_name)
	else:
		var msg: String = "  ✗ FAIL: %s%s" % [test_name, (" — " + detail if detail != "" else "")]
		push_error(msg)
		print(msg)

func _setup(player_count: int = 6) -> Dictionary:
	var defs := StubRoleDefinitions.new()
	var rm := RoleManager.new(defs)
	var cq := CommandQueue.new()
	var ps := PermissionSystem.new(rm, cq)
	return {"rm": rm, "cq": cq, "ps": ps}

# ---------------------------------------------------------------------------
# Test runner
# ---------------------------------------------------------------------------

func run_all() -> void:
	print("=== TestPermissions ===")
	print("--- DENIED ---")
	test_commander_cannot_move_combat_units()
	test_field_marshal_cannot_place_structures()
	test_field_marshal_cannot_move_spec_ops_units_4p()
	test_quartermaster_cannot_research()
	test_spec_ops_unit_cap_exceeded()
	print("--- ALLOWED ---")
	test_commander_2p_absorbs_qm_queue_production()
	test_field_marshal_can_attack_own_unit()
	test_commander_can_place_structure()
	test_quartermaster_can_set_rally_point()
	test_spec_ops_can_sabotage_own_unit()
	print("=== Done ===")

# ---------------------------------------------------------------------------
# DENIED 1: Commander cannot move combat units
# ---------------------------------------------------------------------------
func test_commander_cannot_move_combat_units() -> void:
	var s := _setup()
	var rm: RoleManager = s["rm"]
	var ps: PermissionSystem = s["ps"]
	rm.assign_role(1, "commander")
	rm.assign_entity(100, "field_marshal")

	var result := ps.can_execute(1, _cmd(1, "commander", "MOVE_UNITS", {"unit_ids": [100], "destination": Vector2.ZERO}))
	_assert(not result["allowed"], "Commander cannot move units — PERMISSION_DENIED")
	_assert(result["error_code"] == PermissionSystem.CommandError.PERMISSION_DENIED, "Error code == PERMISSION_DENIED")

# ---------------------------------------------------------------------------
# DENIED 2: FieldMarshal cannot place structures
# ---------------------------------------------------------------------------
func test_field_marshal_cannot_place_structures() -> void:
	var s := _setup()
	var rm: RoleManager = s["rm"]
	var ps: PermissionSystem = s["ps"]
	rm.assign_role(2, "field_marshal")

	var result := ps.can_execute(2, _cmd(2, "field_marshal", "PLACE_STRUCTURE", {"structure_type": "barracks", "position": Vector2.ZERO}))
	_assert(not result["allowed"], "FieldMarshal cannot place structures — PERMISSION_DENIED")
	_assert(result["error_code"] == PermissionSystem.CommandError.PERMISSION_DENIED, "Error code == PERMISSION_DENIED")

# ---------------------------------------------------------------------------
# DENIED 3: FieldMarshal cannot move spec_ops units in 4-player game
# ---------------------------------------------------------------------------
func test_field_marshal_cannot_move_spec_ops_units_4p() -> void:
	var s := _setup(4)
	var rm: RoleManager = s["rm"]
	var ps: PermissionSystem = s["ps"]
	rm.assign_role(2, "field_marshal")
	rm.assign_role(3, "spec_ops")
	rm.apply_merge_rules(4)  # FM absorbs AirMarshal only — spec_ops remains separate
	rm.assign_entity(200, "spec_ops")

	var result := ps.can_execute(2, _cmd(2, "field_marshal", "MOVE_UNITS", {"unit_ids": [200], "destination": Vector2.ZERO}))
	_assert(not result["allowed"], "FieldMarshal cannot move spec_ops units in 4p — ENTITY_NOT_OWNED")
	_assert(result["error_code"] == PermissionSystem.CommandError.ENTITY_NOT_OWNED, "Error code == ENTITY_NOT_OWNED")

# ---------------------------------------------------------------------------
# DENIED 4: Quartermaster cannot research
# ---------------------------------------------------------------------------
func test_quartermaster_cannot_research() -> void:
	var s := _setup()
	var rm: RoleManager = s["rm"]
	var ps: PermissionSystem = s["ps"]
	rm.assign_role(3, "quartermaster")

	var result := ps.can_execute(3, _cmd(3, "quartermaster", "RESEARCH", {"lab_id": 300, "tech_id": "aegis_advanced_armor"}))
	_assert(not result["allowed"], "Quartermaster cannot research — PERMISSION_DENIED")
	_assert(result["error_code"] == PermissionSystem.CommandError.PERMISSION_DENIED, "Error code == PERMISSION_DENIED")

# ---------------------------------------------------------------------------
# DENIED 5: SpecOps unit cap exceeded
# ---------------------------------------------------------------------------
func test_spec_ops_unit_cap_exceeded() -> void:
	var s := _setup()
	var rm: RoleManager = s["rm"]
	var ps: PermissionSystem = s["ps"]
	rm.assign_role(4, "spec_ops")
	for i in range(16):  # 16 units — cap is 15
		rm.assign_entity(400 + i, "spec_ops")

	var result := ps.can_execute(4, _cmd(4, "spec_ops", "MOVE_UNITS", {"unit_ids": [400], "destination": Vector2.ZERO}))
	_assert(not result["allowed"], "SpecOps unit cap exceeded — UNIT_CAP_REACHED")
	_assert(result["error_code"] == PermissionSystem.CommandError.UNIT_CAP_REACHED, "Error code == UNIT_CAP_REACHED")

# ---------------------------------------------------------------------------
# ALLOWED 1: Commander in 2p game can queue production via QM merge
# ---------------------------------------------------------------------------
func test_commander_2p_absorbs_qm_queue_production() -> void:
	var s := _setup(2)
	var rm: RoleManager = s["rm"]
	var ps: PermissionSystem = s["ps"]
	rm.assign_role(1, "commander")
	rm.apply_merge_rules(2)
	rm.assign_entity(500, "quartermaster")

	var result := ps.can_execute(1, _cmd(1, "commander", "QUEUE_PRODUCTION", {"factory_id": 500, "unit_type": "aegis_medium_tank"}))
	_assert(result["allowed"], "Commander (2p, absorbed QM) can queue production")

# ---------------------------------------------------------------------------
# ALLOWED 2: FieldMarshal can attack with own unit
# ---------------------------------------------------------------------------
func test_field_marshal_can_attack_own_unit() -> void:
	var s := _setup()
	var rm: RoleManager = s["rm"]
	var ps: PermissionSystem = s["ps"]
	rm.assign_role(2, "field_marshal")
	rm.assign_entity(600, "field_marshal")

	var result := ps.can_execute(2, _cmd(2, "field_marshal", "ATTACK_TARGET", {"unit_ids": [600], "target_id": 999}))
	_assert(result["allowed"], "FieldMarshal can attack with own unit")

# ---------------------------------------------------------------------------
# ALLOWED 3: Commander can place structure
# ---------------------------------------------------------------------------
func test_commander_can_place_structure() -> void:
	var s := _setup()
	var rm: RoleManager = s["rm"]
	var ps: PermissionSystem = s["ps"]
	rm.assign_role(1, "commander")

	var result := ps.can_execute(1, _cmd(1, "commander", "PLACE_STRUCTURE", {"structure_type": "barracks", "position": Vector2.ZERO}))
	_assert(result["allowed"], "Commander can place structure")

# ---------------------------------------------------------------------------
# ALLOWED 4: Quartermaster can set rally point on own factory
# ---------------------------------------------------------------------------
func test_quartermaster_can_set_rally_point() -> void:
	var s := _setup()
	var rm: RoleManager = s["rm"]
	var ps: PermissionSystem = s["ps"]
	rm.assign_role(3, "quartermaster")
	rm.assign_entity(700, "quartermaster")

	var result := ps.can_execute(3, _cmd(3, "quartermaster", "SET_RALLY_POINT", {"factory_id": 700, "position": Vector2(15, 15)}))
	_assert(result["allowed"], "Quartermaster can set rally point on own factory")

# ---------------------------------------------------------------------------
# ALLOWED 5: SpecOps can sabotage with own unit
# ---------------------------------------------------------------------------
func test_spec_ops_can_sabotage_own_unit() -> void:
	var s := _setup()
	var rm: RoleManager = s["rm"]
	var ps: PermissionSystem = s["ps"]
	rm.assign_role(4, "spec_ops")
	rm.assign_entity(800, "spec_ops")

	var result := ps.can_execute(4, _cmd(4, "spec_ops", "SABOTAGE", {"unit_id": 800, "target_id": 9001}))
	_assert(result["allowed"], "SpecOps can sabotage with own unit")
