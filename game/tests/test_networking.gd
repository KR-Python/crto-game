## test_networking.gd
## Tests for Phase 2 networking: command protocol, state sync, fog masking, checksums.
extends GutTest


func _make_command(action: String, params: Dictionary = {}) -> Dictionary:
	return {"player_id": 1, "role": "FieldMarshal", "tick": 10, "action": action, "params": params}


func _make_ecs_with_entities() -> ECS:
	var ecs := ECS.new()
	var e1: int = ecs.create_entity()
	ecs.add_component(e1, "FactionComponent", {"faction_id": 1})
	ecs.add_component(e1, "Position", {"x": 10.0, "y": 10.0})
	ecs.add_component(e1, "Health", {"current": 100.0, "max": 100.0})
	var e2: int = ecs.create_entity()
	ecs.add_component(e2, "FactionComponent", {"faction_id": 2})
	ecs.add_component(e2, "Position", {"x": 50.0, "y": 50.0})
	ecs.add_component(e2, "Health", {"current": 80.0, "max": 100.0})
	return ecs


func _make_vision_system(visible_positions: Array[Vector2] = []) -> VisionSystem:
	var vs := VisionSystem.new()
	vs.register_faction_team(1, 0)
	vs.register_faction_team(2, 1)
	for pos: Vector2 in visible_positions:
		var col: int = int(pos.x / VisionSystem.CELL_SIZE)
		var row: int = int(pos.y / VisionSystem.CELL_SIZE)
		if col >= 0 and col < VisionSystem.FOG_COLS and row >= 0 and row < VisionSystem.FOG_ROWS:
			vs._fog[0][row * VisionSystem.FOG_COLS + col] = VisionSystem.VISIBLE
	return vs


# 1. Command serialize → deserialize roundtrip (all action types)
func test_command_roundtrip_all_actions() -> void:
	var test_params: Dictionary = {
		CommandProtocol.ACTION_MOVE_UNITS: {"unit_ids": [1, 2], "destination": {"x": 5.0, "y": 10.0}},
		CommandProtocol.ACTION_ATTACK_TARGET: {"unit_ids": [1], "target_id": 3},
		CommandProtocol.ACTION_PLACE_STRUCTURE: {"structure_type": "Barracks", "position": {"x": 20.0, "y": 30.0}},
		CommandProtocol.ACTION_QUEUE_PRODUCTION: {"factory_id": 5, "unit_type": "Rifleman"},
		CommandProtocol.ACTION_CANCEL_PRODUCTION: {"factory_id": 5, "queue_index": 0},
		CommandProtocol.ACTION_SET_RALLY_POINT: {"factory_id": 5, "position": {"x": 25.0, "y": 25.0}},
		CommandProtocol.ACTION_RESEARCH: {"lab_id": 7, "tech_id": "armor_upgrade"},
		CommandProtocol.ACTION_PING_MAP: {"position": {"x": 40.0, "y": 40.0}, "ping_type": "attack"},
		CommandProtocol.ACTION_REQUEST_FROM_ROLE: {"target_role": "Quartermaster", "request": {"type": "units"}},
		CommandProtocol.ACTION_APPROVE_SUPERWEAPON: {"weapon_id": 1, "confirmed": true},
		CommandProtocol.ACTION_TRANSFER_CONTROL: {"entity_id": 10, "to_role": "FieldMarshal"},
		CommandProtocol.ACTION_CANCEL_STRUCTURE: {"structure_id": 15},
	}
	for action: String in test_params:
		var cmd: Dictionary = _make_command(action, test_params[action])
		var bytes: PackedByteArray = CommandProtocol.serialize(cmd)
		var restored: Dictionary = CommandProtocol.deserialize(bytes)
		assert_eq(restored["action"], cmd["action"], "Roundtrip failed: %s" % action)
		assert_eq(restored["player_id"], cmd["player_id"])
		assert_eq(restored["tick"], cmd["tick"])


# 2. Command validation rejects missing required fields
func test_validation_rejects_missing_fields() -> void:
	var bad_cmd: Dictionary = {"player_id": 1, "role": "FM", "action": "MoveUnits", "params": {}}
	var result: Dictionary = CommandProtocol.validate(bad_cmd)
	assert_false(result["valid"])
	assert_string_contains(result["error"], "tick")

	var bad_params: Dictionary = _make_command(CommandProtocol.ACTION_MOVE_UNITS, {"unit_ids": [1]})
	result = CommandProtocol.validate(bad_params)
	assert_false(result["valid"])
	assert_string_contains(result["error"], "destination")

	var good_cmd: Dictionary = _make_command(CommandProtocol.ACTION_MOVE_UNITS, {"unit_ids": [1], "destination": {"x": 5.0, "y": 5.0}})
	result = CommandProtocol.validate(good_cmd)
	assert_true(result["valid"])


# 3. Full snapshot: entity count matches
func test_full_snapshot_entity_count() -> void:
	var ecs: ECS = _make_ecs_with_entities()
	var vs: VisionSystem = _make_vision_system([Vector2(10.0, 10.0), Vector2(50.0, 50.0)])
	var sync := StateSync.new()
	var snapshot: Dictionary = sync.generate_full_snapshot(ecs, 1, vs)
	assert_eq(snapshot.size(), 2, "Snapshot should contain 2 entities")


# 4. Delta: unchanged entity not included
func test_delta_unchanged_excluded() -> void:
	var ecs: ECS = _make_ecs_with_entities()
	var vs: VisionSystem = _make_vision_system([Vector2(10.0, 10.0), Vector2(50.0, 50.0)])
	var sync := StateSync.new()
	sync.generate_full_snapshot(ecs, 1, vs)
	var delta: Dictionary = sync.generate_delta(ecs, 1, vs)
	assert_eq(delta["added"].size(), 0)
	assert_eq(delta["changed"].size(), 0)
	assert_eq(delta["removed"].size(), 0)


# 5. Delta: changed component IS included
func test_delta_changed_included() -> void:
	var ecs: ECS = _make_ecs_with_entities()
	var vs: VisionSystem = _make_vision_system([Vector2(10.0, 10.0), Vector2(50.0, 50.0)])
	var sync := StateSync.new()
	sync.generate_full_snapshot(ecs, 1, vs)
	ecs.set_component(1, "Health", {"current": 50.0, "max": 100.0})
	var delta: Dictionary = sync.generate_delta(ecs, 1, vs)
	assert_true(delta["changed"].has("1"), "Changed entity should be in delta")


# 6. Fog masking: enemy outside vision excluded
func test_fog_masking_excludes_enemy() -> void:
	var ecs: ECS = _make_ecs_with_entities()
	var vs: VisionSystem = _make_vision_system([Vector2(10.0, 10.0)])
	var sync := StateSync.new()
	var snapshot: Dictionary = sync.generate_full_snapshot(ecs, 1, vs)
	assert_eq(snapshot.size(), 1, "Only friendly entity should be visible")
	assert_true(snapshot.has("1"))
	assert_false(snapshot.has("2"), "Enemy outside fog must be excluded")


# 7. Checksum: same state = same checksum
func test_checksum_deterministic() -> void:
	var ecs: ECS = _make_ecs_with_entities()
	assert_eq(StateSync.compute_checksum(ecs), StateSync.compute_checksum(ecs))


# 8. Checksum: different state = different checksum
func test_checksum_changes_with_state() -> void:
	var ecs: ECS = _make_ecs_with_entities()
	var c1: int = StateSync.compute_checksum(ecs)
	ecs.set_component(1, "Position", {"x": 99.0, "y": 99.0})
	assert_ne(c1, StateSync.compute_checksum(ecs))


# Host migration tests
func test_host_migration_selects_lowest_connected() -> void:
	var p: Dictionary = {1: {"connected": false, "is_ai": false}, 3: {"connected": true, "is_ai": false}, 5: {"connected": true, "is_ai": false}}
	assert_eq(HostMigration.select_new_host(p), 3)

func test_host_migration_skips_ai() -> void:
	var p: Dictionary = {2: {"connected": true, "is_ai": true}, 4: {"connected": true, "is_ai": false}}
	assert_eq(HostMigration.select_new_host(p), 4)

func test_host_migration_no_candidates() -> void:
	var p: Dictionary = {1: {"connected": false, "is_ai": false}, 2: {"connected": true, "is_ai": true}}
	assert_eq(HostMigration.select_new_host(p), -1)
