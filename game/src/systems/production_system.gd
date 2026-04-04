class_name ProductionSystem
## Tick pipeline step 5.
## Advances production queues, spawns completed units, handles refund policy.
##
## Reads:  ProductionQueue, FactionComponent, RallyPoint, PoweredOff, Structure
## Writes: ProductionQueue (progress, dequeue), new entity spawns via EntityFactory
## Depends on: EconomySystem (spend/refund), EntityFactory

const TICKS_PER_SECOND: float = 15.0
const MAX_QUEUE_DEPTH: int = 5
const SPAWN_OFFSET: float = 32.0  # pixels — unit spawns this far from building center

## Unit definition cache: unit_type -> {cost_primary, cost_secondary, build_time}
## In production, this would be loaded from YAML data files.
var _unit_definitions: Dictionary = {}

## EconomySystem reference — injected at init.
var economy_system: Object = null  # EconomySystem


# ── Public API ────────────────────────────────────────────────────────────────

## Attempt to enqueue a unit for production.
## Returns false if queue is full, building has no power, or insufficient resources.
func queue_unit(factory_entity: int, unit_type: String, ecs: ECS) -> bool:
	var queue: Dictionary = ecs.get_component(factory_entity, "ProductionQueue")
	if queue.is_empty():
		push_warning("ProductionSystem.queue_unit: entity %d has no ProductionQueue" % factory_entity)
		return false

	if ecs.has_component(factory_entity, "PoweredOff"):
		return false

	if queue["queue"].size() >= MAX_QUEUE_DEPTH:
		return false

	var unit_def: Dictionary = _get_unit_definition(unit_type)
	if unit_def.is_empty():
		push_warning("ProductionSystem.queue_unit: unknown unit type '%s'" % unit_type)
		return false

	var faction: Dictionary = ecs.get_component(factory_entity, "FactionComponent")
	if faction.is_empty():
		push_warning("ProductionSystem.queue_unit: entity %d has no FactionComponent" % factory_entity)
		return false

	# Deduct resources upfront
	if economy_system != null:
		var spent: bool = economy_system.spend(
			faction["faction_id"],
			unit_def.get("cost_primary", 0.0),
			unit_def.get("cost_secondary", 0.0)
		)
		if not spent:
			return false

	queue["queue"].append(unit_type)
	return true


## Cancel a queued unit by index. Index 0 = currently building.
## Refunds 100% of unit cost.
func cancel_unit(factory_entity: int, queue_index: int, ecs: ECS) -> void:
	var queue: Dictionary = ecs.get_component(factory_entity, "ProductionQueue")
	if queue.is_empty():
		return

	var unit_queue: Array = queue["queue"]
	if queue_index < 0 or queue_index >= unit_queue.size():
		push_warning("ProductionSystem.cancel_unit: invalid index %d (queue size %d)" % [queue_index, unit_queue.size()])
		return

	var unit_type: String = unit_queue[queue_index]
	var unit_def: Dictionary = _get_unit_definition(unit_type)

	var faction: Dictionary = ecs.get_component(factory_entity, "FactionComponent")

	# Refund 100%
	if not unit_def.is_empty() and not faction.is_empty() and economy_system != null:
		economy_system.refund(
			faction["faction_id"],
			unit_def.get("cost_primary", 0.0),
			unit_def.get("cost_secondary", 0.0)
		)

	unit_queue.remove_at(queue_index)

	# If cancelling the currently-building item (index 0), reset progress
	if queue_index == 0:
		queue["progress"] = 0.0


## Returns queue status for UI display.
## Each entry: {unit_type, progress_pct, eta_ticks}
func get_queue_status(factory_entity: int, ecs: ECS) -> Array:
	var queue: Dictionary = ecs.get_component(factory_entity, "ProductionQueue")
	if queue.is_empty():
		return []

	var result: Array = []
	var unit_queue: Array = queue["queue"]
	var rate: float = queue.get("rate", 1.0)
	var progress: float = queue.get("progress", 0.0)

	for i in range(unit_queue.size()):
		var unit_type: String = unit_queue[i]
		var unit_def: Dictionary = _get_unit_definition(unit_type)
		var build_time: float = unit_def.get("build_time", 1.0)

		var progress_pct: float = 0.0
		var eta_ticks: int = 0

		if i == 0:
			# Currently building
			progress_pct = clampf(progress / build_time, 0.0, 1.0)
			var remaining: float = build_time - progress
			var ticks_per_sec: float = TICKS_PER_SECOND
			var rate_per_tick: float = rate / ticks_per_sec
			eta_ticks = int(ceil(remaining / rate_per_tick)) if rate_per_tick > 0.0 else 9999
		else:
			# Waiting in queue — ETA includes all items before it
			var wait_time: float = build_time  # own build time
			# Add remaining time for item before
			for j in range(i):
				var prev_def: Dictionary = _get_unit_definition(unit_queue[j])
				var prev_bt: float = prev_def.get("build_time", 1.0)
				if j == 0:
					wait_time += prev_bt - progress
				else:
					wait_time += prev_bt

			var ticks_per_sec: float = TICKS_PER_SECOND
			var rate_per_tick: float = rate / ticks_per_sec
			eta_ticks = int(ceil(wait_time / rate_per_tick)) if rate_per_tick > 0.0 else 9999

		result.append({
			"unit_type": unit_type,
			"progress_pct": progress_pct,
			"eta_ticks": eta_ticks,
		})

	return result


# ── Tick ──────────────────────────────────────────────────────────────────────

## Main tick — advance all production queues, spawn completed units.
func tick(ecs: ECS, tick_count: int) -> void:
	var entities: Array = ecs.get_entities_with_component("ProductionQueue")

	for entity_id in entities:
		_process_factory(entity_id, ecs)


## Handle building death — refund 50% of all queued unit costs.
## Should be called by DeathSystem when a structure with a ProductionQueue dies.
func on_building_destroyed(factory_entity: int, ecs: ECS) -> void:
	var queue: Dictionary = ecs.get_component(factory_entity, "ProductionQueue")
	if queue.is_empty():
		return

	var unit_queue: Array = queue["queue"]
	if unit_queue.is_empty():
		return

	var faction: Dictionary = ecs.get_component(factory_entity, "FactionComponent")
	if faction.is_empty():
		return

	if economy_system == null:
		return

	for unit_type in unit_queue:
		var unit_def: Dictionary = _get_unit_definition(unit_type)
		if unit_def.is_empty():
			continue
		# 50% refund on destruction
		economy_system.refund(
			faction["faction_id"],
			unit_def.get("cost_primary", 0.0) * 0.5,
			unit_def.get("cost_secondary", 0.0) * 0.5
		)

	queue["queue"] = []
	queue["progress"] = 0.0


# ── Unit Definitions ──────────────────────────────────────────────────────────

## Register a unit type definition for production cost/time lookups.
## In production, this is loaded from YAML at startup.
func register_unit_definition(unit_type: String, cost_primary: float, cost_secondary: float, build_time: float) -> void:
	_unit_definitions[unit_type] = {
		"cost_primary": cost_primary,
		"cost_secondary": cost_secondary,
		"build_time": build_time,
	}


# ── Internal ──────────────────────────────────────────────────────────────────

func _process_factory(factory_id: int, ecs: ECS) -> void:
	# Skip powered-off buildings
	if ecs.has_component(factory_id, "PoweredOff"):
		return

	var queue: Dictionary = ecs.get_component(factory_id, "ProductionQueue")
	if queue["queue"].is_empty():
		return

	var rate: float = queue.get("rate", 1.0)
	var delta: float = rate / TICKS_PER_SECOND
	queue["progress"] = queue.get("progress", 0.0) + delta

	var current_unit_type: String = queue["queue"][0]
	var unit_def: Dictionary = _get_unit_definition(current_unit_type)
	var build_time: float = unit_def.get("build_time", 1.0)

	if queue["progress"] >= build_time:
		var excess: float = queue["progress"] - build_time
		queue["queue"].remove_at(0)
		queue["progress"] = excess  # carry over excess to next item

		_spawn_unit(factory_id, current_unit_type, ecs)


func _spawn_unit(factory_id: int, unit_type: String, ecs: ECS) -> void:
	var pos_comp: Dictionary = ecs.get_component(factory_id, "Position")
	var spawn_pos: Vector2 = Vector2.ZERO

	if not pos_comp.is_empty():
		spawn_pos = Vector2(pos_comp["x"], pos_comp["y"]) + Vector2(SPAWN_OFFSET, 0.0)

	# Spawn the unit entity
	var factory := EntityFactory.new(ecs)
	var unit_id: int = factory.create_from_definition(unit_type, spawn_pos)

	# Issue move command to rally point if set
	var rally: Dictionary = ecs.get_component(factory_id, "RallyPoint")
	if not rally.is_empty():
		var rally_pos: Vector2 = rally.get("position", Vector2.ZERO)
		# Only issue command if rally differs from spawn pos
		if not rally_pos.is_equal_approx(spawn_pos):
			var move_command: Dictionary = {
				"destination": rally_pos,
				"queued": false,
			}
			ecs.set_component(unit_id, "MoveCommand", move_command)

	# Auto-assign ownership based on unit tags
	var tag_comp: Dictionary = ecs.get_component(unit_id, "Tags")
	var tags: Array = tag_comp.get("tags", []) if not tag_comp.is_empty() else []
	var faction_comp: Dictionary = ecs.get_component(factory_id, "FactionComponent")
	if not faction_comp.is_empty():
		ecs.set_component(unit_id, "FactionComponent", faction_comp.duplicate())

	_assign_ownership(unit_id, tags, ecs)


func _assign_ownership(unit_id: int, tags: Array, ecs: ECS) -> void:
	# Assign based on unit tags per architecture spec
	if "air" in tags:
		ecs.set_component(unit_id, "AirMarshalControlled", {})
	elif "spec_ops" in tags or "hero" in tags:
		ecs.set_component(unit_id, "SpecOpsControlled", {})
	elif "engineer" in tags:
		ecs.set_component(unit_id, "ChiefEngineerControlled", {})
	elif "harvester" in tags:
		ecs.set_component(unit_id, "QuartermasterControlled", {})
	else:
		ecs.set_component(unit_id, "FieldMarshalControlled", {})


func _get_unit_definition(unit_type: String) -> Dictionary:
	return _unit_definitions.get(unit_type, {})
