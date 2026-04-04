class_name FormationSystem

# Formation movement for Field Marshal units.
# Calculates per-unit offset positions and issues individual MoveCommands.
# All math is deterministic — no randf().

enum Formation { LINE, WEDGE, COLUMN, SPREAD }

# Spacing between units in tiles
const LINE_SPACING: float = 1.5
const WEDGE_SPACING: float = 1.5
const COLUMN_SPACING: float = 1.5
const SPREAD_SPACING: float = 2.5


func apply_formation(unit_ids: Array[int], formation: Formation, destination: Vector2, ecs: ECS) -> void:
	if unit_ids.is_empty():
		return

	# Compute average current position as formation anchor
	var center: Vector2 = _average_position(unit_ids, ecs)
	var direction: Vector2 = (destination - center).normalized()
	if direction.length_squared() < 0.001:
		direction = Vector2(1.0, 0.0)

	var offsets: Array[Vector2] = _calculate_offsets(unit_ids.size(), formation, direction)

	for i: int in range(unit_ids.size()):
		var unit_id: int = unit_ids[i]
		var offset: Vector2 = offsets[i] if i < offsets.size() else Vector2.ZERO
		var target: Vector2 = destination + offset
		ecs.add_component(unit_id, "MoveCommand", {
			"destination_x": target.x,
			"destination_y": target.y,
		})


func _calculate_offsets(count: int, formation: Formation, direction: Vector2) -> Array[Vector2]:
	match formation:
		Formation.LINE:
			return _line_offsets(count, direction)
		Formation.WEDGE:
			return _wedge_offsets(count, direction)
		Formation.COLUMN:
			return _column_offsets(count, direction)
		Formation.SPREAD:
			return _spread_offsets(count, direction)
	return []


# ---------------------------------------------------------------------------
# Formation layouts
# ---------------------------------------------------------------------------

# LINE: units spread horizontally perpendicular to movement direction
func _line_offsets(count: int, direction: Vector2) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	# Perpendicular axis
	var perp: Vector2 = Vector2(-direction.y, direction.x)
	var half: float = (count - 1) * LINE_SPACING * 0.5
	for i: int in range(count):
		var lateral: float = i * LINE_SPACING - half
		offsets.append(perp * lateral)
	return offsets


# WEDGE: V-shape — leader at front, pairs fanning back on each side
func _wedge_offsets(count: int, direction: Vector2) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	var perp: Vector2 = Vector2(-direction.y, direction.x)
	# Leader at front (offset 0)
	offsets.append(Vector2.ZERO)
	var row: int = 1
	var placed: int = 1
	while placed < count:
		# Left wing
		if placed < count:
			offsets.append(-direction * (row * WEDGE_SPACING) + perp * (row * WEDGE_SPACING))
			placed += 1
		# Right wing
		if placed < count:
			offsets.append(-direction * (row * WEDGE_SPACING) - perp * (row * WEDGE_SPACING))
			placed += 1
		row += 1
	return offsets


# COLUMN: single file along movement direction
func _column_offsets(count: int, direction: Vector2) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	for i: int in range(count):
		offsets.append(-direction * (i * COLUMN_SPACING))
	return offsets


# SPREAD: loose grid pattern, roughly square
func _spread_offsets(count: int, _direction: Vector2) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	# Use a deterministic grid-based scatter
	var cols: int = max(1, int(ceil(sqrt(float(count)))))
	for i: int in range(count):
		var col: int = i % cols
		var row: int = i / cols
		# Center the grid
		var cols_in_row: int = cols if (i + cols) <= count else (count % cols)
		if cols_in_row == 0:
			cols_in_row = cols
		var x_offset: float = (col - (cols_in_row - 1) * 0.5) * SPREAD_SPACING
		var y_offset: float = row * SPREAD_SPACING
		offsets.append(Vector2(x_offset, y_offset))
	return offsets


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _average_position(unit_ids: Array[int], ecs: ECS) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	var valid: int = 0
	for uid: int in unit_ids:
		if ecs.has_component(uid, "Position"):
			var pos: Dictionary = ecs.get_component(uid, "Position")
			sum += Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
			valid += 1
	if valid == 0:
		return Vector2.ZERO
	return sum / float(valid)
