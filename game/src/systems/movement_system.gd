class_name MovementSystem
## Tick pipeline step 8.
## Moves entities along PathState waypoints, falls back to straight-line if no path,
## applies separation steering, clamps positions to map bounds, and writes Velocity.
##
## Phase 6 optimization:
## - SpatialHash integration: updates entity positions in spatial hash on move
## - SpatialHash-accelerated separation steering (only check nearby entities)
## - Notifies VisionSystem of moved positions via callback

const TICKS_PER_SECOND: float = 15.0
const TICK_DURATION: float = 1.0 / TICKS_PER_SECOND
const SEPARATION_RADIUS: float = 2.0
const SEPARATION_WEIGHT: float = 0.3
const ARRIVAL_THRESHOLD: float = 0.5
const DIRECT_ARRIVAL_THRESHOLD: float = 1.0

var map_bounds: Rect2 = Rect2(0.0, 0.0, 128.0, 96.0)
var _spatial_hash: SpatialHash = null
var _on_entity_moved: Callable = Callable()


func set_spatial_hash(sh: SpatialHash) -> void:
	_spatial_hash = sh


func set_on_entity_moved(callback: Callable) -> void:
	_on_entity_moved = callback


func tick(ecs: ECS, tick_count: int) -> void:
	var moving_entities: Array = ecs.query(["Position", "MoveSpeed"])

	var velocities: Dictionary = {}
	var positions: Dictionary = {}

	for entity_id in moving_entities:
		var pos_comp: Dictionary = ecs.get_component(entity_id, "Position")
		var speed_comp: Dictionary = ecs.get_component(entity_id, "MoveSpeed")
		if pos_comp.is_empty() or speed_comp.is_empty():
			continue

		var pos: Vector2 = Vector2(pos_comp.get("x", 0.0), pos_comp.get("y", 0.0))
		var speed: float = speed_comp.get("speed", 0.0)
		positions[entity_id] = pos

		var move_cmd: Dictionary = ecs.get_component(entity_id, "MoveCommand")
		var path_state: Dictionary = ecs.get_component(entity_id, "PathState")

		var velocity: Vector2 = Vector2.ZERO

		if not path_state.is_empty() and path_state.get("path", []).size() > 0:
			velocity = _follow_path(ecs, entity_id, pos, speed, path_state)
		elif not move_cmd.is_empty():
			velocity = _direct_move(ecs, entity_id, pos, speed, move_cmd)

		velocities[entity_id] = velocity

	# Phase 2: Separation steering (spatial hash accelerated)
	var all_ids: Array = positions.keys()
	for entity_id in all_ids:
		if not velocities.has(entity_id):
			continue
		var vel: Vector2 = velocities[entity_id]
		if vel.is_zero_approx():
			continue

		var flying_comp: Dictionary = ecs.get_component(entity_id, "Flying")
		var is_flying: bool = not flying_comp.is_empty()
		var my_pos: Vector2 = positions[entity_id]

		var nearby: Array
		if _spatial_hash != null:
			nearby = _spatial_hash.query_radius(my_pos, SEPARATION_RADIUS * 2.0)
		else:
			nearby = all_ids

		var separation: Vector2 = Vector2.ZERO
		for other_id in nearby:
			if other_id == entity_id:
				continue
			var other_flying: Dictionary = ecs.get_component(other_id, "Flying")
			var other_is_flying: bool = not other_flying.is_empty()
			if is_flying != other_is_flying:
				continue

			var other_pos: Vector2
			if positions.has(other_id):
				other_pos = positions[other_id]
			else:
				var op: Dictionary = ecs.get_component(other_id, "Position")
				if op.is_empty():
					continue
				other_pos = Vector2(op.get("x", 0.0), op.get("y", 0.0))

			var delta: Vector2 = my_pos - other_pos
			var dist: float = delta.length()
			if dist < SEPARATION_RADIUS and dist > 0.001:
				separation += delta.normalized() / dist

		if not separation.is_zero_approx():
			vel += separation * SEPARATION_WEIGHT
		velocities[entity_id] = vel

	# Phase 3: Write Position and Velocity, update spatial hash
	for entity_id in all_ids:
		if not velocities.has(entity_id):
			continue

		var vel: Vector2 = velocities[entity_id]
		var old_pos: Vector2 = positions[entity_id]
		var new_pos: Vector2 = old_pos + vel * TICK_DURATION

		new_pos.x = clampf(new_pos.x, map_bounds.position.x, map_bounds.position.x + map_bounds.size.x)
		new_pos.y = clampf(new_pos.y, map_bounds.position.y, map_bounds.position.y + map_bounds.size.y)

		ecs.set_component(entity_id, "Position", {"x": new_pos.x, "y": new_pos.y})
		ecs.set_component(entity_id, "Velocity", {"x": vel.x, "y": vel.y})

		if _spatial_hash != null and not vel.is_zero_approx():
			_spatial_hash.update(entity_id, old_pos, new_pos)

		if _on_entity_moved.is_valid() and not vel.is_zero_approx():
			_on_entity_moved.call(new_pos)


func _follow_path(ecs: ECS, entity_id: int, pos: Vector2, speed: float, path_state: Dictionary) -> Vector2:
	var path: Array = path_state.path
	var current_index: int = path_state.current_index

	if current_index >= path.size():
		ecs.remove_component(entity_id, "PathState")
		ecs.remove_component(entity_id, "MoveCommand")
		ecs.set_component(entity_id, "Velocity", {"x": 0.0, "y": 0.0})
		return Vector2.ZERO

	var waypoint: Vector2 = path[current_index]
	var to_waypoint: Vector2 = waypoint - pos
	var dist: float = to_waypoint.length()
	var step_size: float = speed / TICKS_PER_SECOND

	if dist <= ARRIVAL_THRESHOLD or dist <= step_size:
		current_index += 1
		path_state = path_state.duplicate()
		path_state.current_index = current_index
		if current_index >= path.size():
			ecs.remove_component(entity_id, "PathState")
			ecs.remove_component(entity_id, "MoveCommand")
			return Vector2.ZERO
		else:
			ecs.set_component(entity_id, "PathState", path_state)
			waypoint = path[current_index]
			to_waypoint = waypoint - pos
			dist = to_waypoint.length()

	if dist < 0.001:
		return Vector2.ZERO

	var direction: Vector2 = to_waypoint / dist
	return direction * speed


func _direct_move(ecs: ECS, entity_id: int, pos: Vector2, speed: float, move_cmd: Dictionary) -> Vector2:
	var destination: Vector2 = move_cmd.destination
	var to_dest: Vector2 = destination - pos
	var dist: float = to_dest.length()

	if dist <= DIRECT_ARRIVAL_THRESHOLD:
		ecs.remove_component(entity_id, "MoveCommand")
		ecs.remove_component(entity_id, "PathState")
		return Vector2.ZERO

	if dist < 0.001:
		return Vector2.ZERO

	return (to_dest / dist) * speed
