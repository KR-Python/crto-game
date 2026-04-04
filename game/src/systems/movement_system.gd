class_name MovementSystem
## Tick pipeline step 8.
## Moves entities along PathState waypoints, falls back to straight-line if no path,
## applies separation steering, clamps positions to map bounds, and writes Velocity.

const TICKS_PER_SECOND: float = 15.0
const TICK_DURATION: float = 1.0 / TICKS_PER_SECOND
const SEPARATION_RADIUS: float = 2.0
const SEPARATION_WEIGHT: float = 0.3
const ARRIVAL_THRESHOLD: float = 0.5
const DIRECT_ARRIVAL_THRESHOLD: float = 1.0

# Map bounds — set by game_loop after map is loaded.
var map_bounds: Rect2 = Rect2(0.0, 0.0, 128.0, 96.0)


func tick(ecs: ECS, tick_count: int) -> void:
	# Collect all movable entities and their pre-tick positions
	var moving_entities: Array = ecs.query(["Position", "MoveSpeed"])

	# --- Phase 1: Compute raw velocity for each entity ---
	var velocities: Dictionary = {}  # entity_id -> Vector2 (velocity after path logic)
	var positions: Dictionary = {}   # entity_id -> current Vector2 position

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
			# --- Path following ---
			velocity = _follow_path(ecs, entity_id, pos, speed, path_state)
		elif not move_cmd.is_empty():
			# --- Straight-line fallback ---
			velocity = _direct_move(ecs, entity_id, pos, speed, move_cmd)
		# else: no command, no path — velocity stays zero

		velocities[entity_id] = velocity

	# --- Phase 2: Apply separation steering ---
	var all_ids: Array = positions.keys()
	for entity_id in all_ids:
		if not velocities.has(entity_id):
			continue

		var vel: Vector2 = velocities[entity_id]
		if vel.is_zero_approx():
			continue  # stationary — don't push stationary units (only moving ones steer)

		var flying_comp: Dictionary = ecs.get_component(entity_id, "Flying")
		var is_flying: bool = not flying_comp.is_empty()
		var my_pos: Vector2 = positions[entity_id]

		var separation: Vector2 = Vector2.ZERO
		for other_id in all_ids:
			if other_id == entity_id:
				continue
			# Flying units only avoid other flyers
			var other_flying: Dictionary = ecs.get_component(other_id, "Flying")
			var other_is_flying: bool = not other_flying.is_empty()
			if is_flying != other_is_flying:
				continue

			var other_pos: Vector2 = positions[other_id]
			var delta: Vector2 = my_pos - other_pos
			var dist: float = delta.length()
			if dist < SEPARATION_RADIUS and dist > 0.001:
				separation += delta.normalized() / dist

		if not separation.is_zero_approx():
			vel += separation * SEPARATION_WEIGHT

		velocities[entity_id] = vel

	# --- Phase 3: Write Position and Velocity ---
	for entity_id in all_ids:
		if not velocities.has(entity_id):
			continue

		var vel: Vector2 = velocities[entity_id]
		var pos: Vector2 = positions[entity_id]
		var new_pos: Vector2 = pos + vel * TICK_DURATION

		# Clamp to map bounds
		new_pos.x = clampf(new_pos.x, map_bounds.position.x, map_bounds.position.x + map_bounds.size.x)
		new_pos.y = clampf(new_pos.y, map_bounds.position.y, map_bounds.position.y + map_bounds.size.y)

		ecs.set_component(entity_id, "Position", {"x": new_pos.x, "y": new_pos.y})
		ecs.set_component(entity_id, "Velocity", {"x": vel.x, "y": vel.y})


func _follow_path(ecs: ECS, entity_id: int, pos: Vector2, speed: float, path_state: Dictionary) -> Vector2:
	var path: Array = path_state.path
	var current_index: int = path_state.current_index

	if current_index >= path.size():
		# Arrived — clear PathState and MoveCommand
		ecs.remove_component(entity_id, "PathState")
		ecs.remove_component(entity_id, "MoveCommand")
		ecs.set_component(entity_id, "Velocity", {"x": 0.0, "y": 0.0})
		return Vector2.ZERO

	var waypoint: Vector2 = path[current_index]
	var to_waypoint: Vector2 = waypoint - pos
	var dist: float = to_waypoint.length()
	var step_size: float = speed / TICKS_PER_SECOND

	if dist <= ARRIVAL_THRESHOLD or dist <= step_size:
		# Advance to next waypoint
		current_index += 1
		path_state = path_state.duplicate()
		path_state.current_index = current_index
		if current_index >= path.size():
			# Fully arrived
			ecs.remove_component(entity_id, "PathState")
			ecs.remove_component(entity_id, "MoveCommand")
			return Vector2.ZERO
		else:
			ecs.set_component(entity_id, "PathState", path_state)
			# Move toward the new waypoint this tick
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
		# Arrived
		ecs.remove_component(entity_id, "MoveCommand")
		ecs.remove_component(entity_id, "PathState")
		return Vector2.ZERO

	if dist < 0.001:
		return Vector2.ZERO

	return (to_dest / dist) * speed
