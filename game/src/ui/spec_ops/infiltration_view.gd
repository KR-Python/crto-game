class_name InfiltrationView
extends Node2D

## Detection radius visualization for Spec Ops stealth movement.
## When a Spec Ops unit is selected, this overlay draws:
##   - Red filled/outlined circles for every enemy unit or structure that can
##     detect stealth within a relevant range.
##   - Thin green path segments indicating corridors that are currently safe
##     (i.e., outside all detection radii).
## Updates live as the selected unit moves.

const DETECTION_COLOR_FILL := Color(1.0, 0.1, 0.1, 0.08)
const DETECTION_COLOR_RING := Color(1.0, 0.1, 0.1, 0.55)
const SAFE_PATH_COLOR := Color(0.2, 1.0, 0.4, 0.65)
const SELECTED_UNIT_COLOR := Color(0.3, 0.8, 1.0, 0.85)

const RING_WIDTH := 2.0
const SAFE_LINE_WIDTH := 3.0
const SCAN_RADIUS := 500.0      # How far from selected unit we look for threats
const PATH_SEGMENT_LEN := 32.0  # Resolution for safe corridor sampling
const UNIT_MARKER_RADIUS := 8.0

# Default detection radius used when a threat has no explicit one
const DEFAULT_DETECT_RADIUS := 120.0

# Set by the owning UI controller.
var selected_unit_id: int = -1

# Cached world-position of the selected unit (refreshed each update_for_unit call).
var _selected_pos: Vector2 = Vector2.ZERO

# List of { "pos": Vector2, "radius": float } for every nearby threat.
var _nearby_threats: Array[Dictionary] = []

# Pre-computed safe path points drawn as polyline.
var _safe_path_points: Array[Vector2] = []


func _ready() -> void:
	# Render above terrain/units but below selection indicators.
	z_index = 9


func _process(_delta: float) -> void:
	queue_redraw()


## Called by the selection system whenever the selected Spec Ops unit changes or moves.
## `entity_id` — ECS entity id of the selected unit (-1 to clear)
## `ecs`        — reference to the ECS world so we can read components
func update_for_unit(entity_id: int, ecs: ECS) -> void:
	selected_unit_id = entity_id
	_nearby_threats.clear()
	_safe_path_points.clear()

	if entity_id == -1:
		queue_redraw()
		return

	# Read the unit's current position from the ECS PositionComponent.
	_selected_pos = _read_unit_position(entity_id, ecs)

	# Gather all enemy entities that have a DetectionComponent and are within SCAN_RADIUS.
	_nearby_threats = _collect_nearby_threats(ecs)

	# Compute safe-corridor hints around the selected unit's position.
	_safe_path_points = _compute_safe_path()

	queue_redraw()


func _draw() -> void:
	if selected_unit_id == -1:
		return

	_draw_detection_radii()
	_draw_safe_corridors()
	_draw_selected_unit_marker()


# ── Private helpers ────────────────────────────────────────────────────────


func _read_unit_position(entity_id: int, ecs: ECS) -> Vector2:
	# Access PositionComponent via ECS. Returns ZERO if component missing.
	if not ecs.has_component(entity_id, "PositionComponent"):
		return Vector2.ZERO
	var comp: Dictionary = ecs.get_component(entity_id, "PositionComponent")
	return comp.get("world_pos", Vector2.ZERO)


func _collect_nearby_threats(ecs: ECS) -> Array[Dictionary]:
	var threats: Array[Dictionary] = []
	# Iterate entities that have DetectionComponent.
	# ECS.query() returns an Array of entity IDs matching a component mask.
	var candidates: Array = ecs.query(["DetectionComponent", "PositionComponent", "TeamComponent"])
	for eid: int in candidates:
		var team_comp: Dictionary = ecs.get_component(eid, "TeamComponent")
		# Only enemy entities matter (team != selected unit's team — simplified here).
		if team_comp.get("team_id", -1) == 0:
			continue
		var pos_comp: Dictionary = ecs.get_component(eid, "PositionComponent")
		var pos: Vector2 = pos_comp.get("world_pos", Vector2.ZERO)
		if pos.distance_to(_selected_pos) > SCAN_RADIUS:
			continue
		var det_comp: Dictionary = ecs.get_component(eid, "DetectionComponent")
		threats.append({
			"pos": pos,
			"radius": det_comp.get("stealth_detect_radius", DEFAULT_DETECT_RADIUS),
		})
	return threats


# Samples points in a ring around the selected unit and keeps those outside
# all detection radii — these form "safe corridor hints".
func _compute_safe_path() -> Array[Vector2]:
	var safe: Array[Vector2] = []
	var ring_radius: float = 80.0   # Show hints on a ring around the unit
	var steps: int = 32
	for i: int in range(steps):
		var angle: float = TAU * float(i) / float(steps)
		var candidate: Vector2 = _selected_pos + Vector2(cos(angle), sin(angle)) * ring_radius
		if _is_position_safe(candidate):
			safe.append(candidate)
	return safe


func _is_position_safe(pos: Vector2) -> bool:
	for threat: Dictionary in _nearby_threats:
		if pos.distance_to(threat["pos"]) < threat["radius"]:
			return false
	return true


func _draw_detection_radii() -> void:
	for threat: Dictionary in _nearby_threats:
		var pos: Vector2 = threat["pos"]
		var radius: float = threat["radius"]
		# Semi-transparent fill
		draw_circle(pos, radius, DETECTION_COLOR_FILL)
		# Crisp ring outline
		_draw_smooth_circle(pos, radius, DETECTION_COLOR_RING, RING_WIDTH)


func _draw_safe_corridors() -> void:
	# Draw individual dots at safe sample points (corridors are non-contiguous arcs).
	for pt: Vector2 in _safe_path_points:
		draw_circle(pt, 4.0, SAFE_PATH_COLOR)


func _draw_selected_unit_marker() -> void:
	draw_circle(_selected_pos, UNIT_MARKER_RADIUS, SELECTED_UNIT_COLOR)
	_draw_smooth_circle(_selected_pos, UNIT_MARKER_RADIUS + 4.0,
		Color(SELECTED_UNIT_COLOR.r, SELECTED_UNIT_COLOR.g, SELECTED_UNIT_COLOR.b, 0.4), 1.5)


func _draw_smooth_circle(
		center: Vector2, radius: float, color: Color,
		width: float = 1.0, segments: int = 48) -> void:
	var step: float = TAU / float(segments)
	for i: int in range(segments):
		var a0: float = i * step
		var a1: float = a0 + step
		draw_line(
			center + Vector2(cos(a0), sin(a0)) * radius,
			center + Vector2(cos(a1), sin(a1)) * radius,
			color, width
		)
