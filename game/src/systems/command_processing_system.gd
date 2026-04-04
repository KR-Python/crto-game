class_name CommandProcessingSystem
## Tick pipeline step 6.
## Converts MoveCommand into a pathfinding request and writes PathState.
## Flying entities use NavGrid.MOVE_FLYING (ignores terrain).
## Non-queued commands are consumed after processing.

var pathfinder: Pathfinder  # injected at game start
var nav_grid: NavGrid       # injected at game start


func tick(ecs: ECS, tick_count: int) -> void:
	# Query all entities that have a MoveCommand
	var entities: Array = ecs.query_with_components(["MoveCommand", "Position"])
	for entity_id in entities:
		var move_cmd: Dictionary = ecs.get_component(entity_id, "MoveCommand")
		if move_cmd.is_empty():
			continue

		var pos_comp: Dictionary = ecs.get_component(entity_id, "Position")
		var current_pos: Vector2 = Vector2(pos_comp.x, pos_comp.y)
		var destination: Vector2 = move_cmd.destination

		# Determine if PathState is already valid for this destination
		var existing_path: Dictionary = ecs.get_component(entity_id, "PathState")
		if not existing_path.is_empty() and existing_path.has("destination"):
			if existing_path.destination.is_equal_approx(destination):
				# Path already computed for this destination — skip
				if not move_cmd.get("queued", false):
					ecs.remove_component(entity_id, "MoveCommand")
				continue

		# Determine movement type
		var movement_type: int = NavGrid.MOVE_FOOT
		var flying_comp: Dictionary = ecs.get_component(entity_id, "Flying")
		if not flying_comp.is_empty():
			movement_type = NavGrid.MOVE_FLYING

		# Request path — returns Array[Vector2] or empty if no path found
		var path: Array[Vector2] = pathfinder.find_path(current_pos, destination, movement_type)

		# Write PathState regardless — empty path triggers straight-line fallback in MovementSystem
		ecs.set_component(entity_id, "PathState", {
			"path": path,
			"current_index": 0,
			"destination": destination,
		})

		# Non-queued commands: keep MoveCommand on entity so MovementSystem can read destination
		# for straight-line fallback, but mark it as processed to avoid re-pathing next tick.
		# Queued commands are left intact; they are cleared by MovementSystem on arrival.
		if not move_cmd.get("queued", false):
			# Leave MoveCommand so MovementSystem has destination for fallback,
			# but tag it as processed so we don't re-path every tick.
			ecs.set_component(entity_id, "MoveCommand", {
				"destination": destination,
				"queued": false,
				"path_requested": true,
			})
