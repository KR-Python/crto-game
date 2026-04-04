class_name RepairSystem

# Chief Engineer repair mechanics.
# Reads: EngineerUnit, RepairCommand, Position, Health, FactionComponent, Wreckage
# Writes: Health, RepairCommand (removes on completion), FactionEconomy (reclaim value)

const REPAIR_RATE: float = 15.0  # HP per tick (1 HP/tick at 15 ticks/sec = 15 HP/s)
const REPAIR_RANGE: float = 2.5  # tiles


func tick(ecs: ECS, tick_count: int) -> void:
	var engineers: Array[int] = ecs.query(["EngineerUnit", "RepairCommand", "Position"])
	for engineer_id: int in engineers:
		_process_engineer(engineer_id, ecs)


func repair_structure(engineer_id: int, target_id: int, ecs: ECS) -> void:
	if not ecs.has_component(target_id, "Structure"):
		push_warning("RepairSystem: target %d is not a structure" % target_id)
		return
	ecs.add_component(engineer_id, "RepairCommand", Components.repair_command(target_id))


func repair_vehicle(engineer_id: int, target_id: int, ecs: ECS) -> void:
	if not ecs.has_component(target_id, "Vehicle"):
		push_warning("RepairSystem: target %d is not a vehicle" % target_id)
		return
	ecs.add_component(engineer_id, "RepairCommand", Components.repair_command(target_id))


func reclaim_wreckage(engineer_id: int, wreck_position: Vector2, ecs: ECS) -> void:
	# Find wreckage entity at position
	var wrecks: Array[int] = ecs.query(["Wreckage", "Position"])
	for wreck_id: int in wrecks:
		var pos: Dictionary = ecs.get_component(wreck_id, "Position")
		if abs(pos.get("x", 0.0) - wreck_position.x) < 0.5 and abs(pos.get("y", 0.0) - wreck_position.y) < 0.5:
			_do_reclaim(engineer_id, wreck_id, ecs)
			return
	push_warning("RepairSystem: no wreckage found at (%s, %s)" % [wreck_position.x, wreck_position.y])


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _process_engineer(engineer_id: int, ecs: ECS) -> void:
	var cmd: Dictionary = ecs.get_component(engineer_id, "RepairCommand")
	var target_id: int = cmd.get("target_entity", -1)
	if target_id < 0:
		ecs.remove_component(engineer_id, "RepairCommand")
		return

	if not ecs.has_component(target_id, "Health"):
		# Target gone or invalid
		ecs.remove_component(engineer_id, "RepairCommand")
		return

	var health: Dictionary = ecs.get_component(target_id, "Health")
	var current_hp: float = health.get("current", 0.0)
	var max_hp: float = health.get("max", 100.0)

	# Already at full HP — stop
	if current_hp >= max_hp:
		ecs.remove_component(engineer_id, "RepairCommand")
		return

	# Range check
	if not ecs.has_component(engineer_id, "Position") or not ecs.has_component(target_id, "Position"):
		return

	var eng_pos: Dictionary = ecs.get_component(engineer_id, "Position")
	var tgt_pos: Dictionary = ecs.get_component(target_id, "Position")
	var dist: float = _distance(eng_pos, tgt_pos)

	if dist > REPAIR_RANGE:
		# Issue move command toward target
		_move_toward(engineer_id, tgt_pos, ecs)
		return

	# In range — apply repair
	var new_hp: float = minf(current_hp + REPAIR_RATE, max_hp)
	health["current"] = new_hp
	ecs.add_component(target_id, "Health", health)

	# Done when full
	if new_hp >= max_hp:
		ecs.remove_component(engineer_id, "RepairCommand")


func _do_reclaim(engineer_id: int, wreck_id: int, ecs: ECS) -> void:
	var eng_pos: Dictionary = ecs.get_component(engineer_id, "Position")
	var wreck_pos: Dictionary = ecs.get_component(wreck_id, "Position")

	if _distance(eng_pos, wreck_pos) > REPAIR_RANGE:
		_move_toward(engineer_id, wreck_pos, ecs)
		return

	var wreckage: Dictionary = ecs.get_component(wreck_id, "Wreckage")
	var reclaim_value: int = wreckage.get("reclaim_value", 0)

	# Credit resources to engineer's faction
	if ecs.has_component(engineer_id, "FactionComponent"):
		var faction: Dictionary = ecs.get_component(engineer_id, "FactionComponent")
		var faction_id: int = faction.get("faction_id", -1)
		_credit_resources(faction_id, reclaim_value, ecs)

	ecs.destroy_entity(wreck_id)


func _credit_resources(faction_id: int, amount: int, ecs: ECS) -> void:
	var economy_entities: Array[int] = ecs.query(["FactionEconomy", "FactionComponent"])
	for e_id: int in economy_entities:
		var f: Dictionary = ecs.get_component(e_id, "FactionComponent")
		if f.get("faction_id", -1) != faction_id:
			continue
		var economy: Dictionary = ecs.get_component(e_id, "FactionEconomy").duplicate()
		economy["primary"] = economy.get("primary", 0) + amount
		ecs.add_component(e_id, "FactionEconomy", economy)
		return


func _move_toward(engineer_id: int, target_pos: Dictionary, ecs: ECS) -> void:
	# Issue a MoveCommand pointing toward target; movement system handles locomotion
	ecs.add_component(engineer_id, "MoveCommand", {
		"destination_x": target_pos.get("x", 0.0),
		"destination_y": target_pos.get("y", 0.0),
	})


static func _distance(a: Dictionary, b: Dictionary) -> float:
	var dx: float = a.get("x", 0.0) - b.get("x", 0.0)
	var dy: float = a.get("y", 0.0) - b.get("y", 0.0)
	return sqrt(dx * dx + dy * dy)
