class_name IntelOverlay
extends Node2D

## Spec Ops intel overlay — draws in world-space over the game world.
## Shows last-known enemy positions, scouted structure outlines,
## detection radius rings, and patrol route hints.
## Updated whenever VisionSystem reveals new intel.

const FADE_COLOR_UNIT := Color(1.0, 0.3, 0.3, 0.6)
const FADE_COLOR_STRUCTURE := Color(1.0, 0.5, 0.0, 0.5)
const DETECTION_RING_COLOR := Color(1.0, 0.0, 0.0, 0.25)
const PATROL_HINT_COLOR := Color(1.0, 1.0, 0.0, 0.4)
const LABEL_COLOR := Color(1.0, 1.0, 1.0, 0.75)

const UNIT_ICON_RADIUS := 12.0
const STRUCTURE_OUTLINE_HALF := Vector2(24.0, 24.0)
const DETECTION_RING_WIDTH := 2.0
const PATROL_LINE_WIDTH := 2.0
const LABEL_OFFSET := Vector2(14.0, -14.0)

# Detection radii keyed by structure type (design data placeholder)
const DETECTION_RADII: Dictionary = {
	"sensor": 200.0,
	"turret": 150.0,
	"gate": 80.0,
}

# Snapshot of last-known intel, set by update_intel().
# Units: entity_id -> { "pos": Vector2, "tick": int, "unit_type": String }
var _scouted_units: Dictionary = {}

# Structures: entity_id -> { "pos": Vector2, "size": Vector2, "structure_type": String,
#                             "has_detection": bool, "patrol_route": Array[Vector2] }
var _scouted_structures: Dictionary = {}

var _current_tick: int = 0


func _ready() -> void:
	# World-space drawing — z_index places overlay above terrain, below selection rings.
	z_index = 10


func _process(_delta: float) -> void:
	queue_redraw()


# Called by VisionSystem when scout data changes.
func update_intel(scouted_units: Dictionary, scouted_structures: Dictionary) -> void:
	_scouted_units = scouted_units
	_scouted_structures = scouted_structures
	queue_redraw()


# Tick must be advanced externally (e.g., by the sim loop) so the overlay can
# compute "last seen X ticks ago" labels.
func advance_tick(tick: int) -> void:
	_current_tick = tick


func _draw() -> void:
	_draw_patrol_routes()
	_draw_structure_outlines()
	_draw_detection_rings()
	_draw_unit_markers()


# ── Private drawing helpers ────────────────────────────────────────────────


func _draw_unit_markers() -> void:
	for entity_id: int in _scouted_units:
		var data: Dictionary = _scouted_units[entity_id]
		var pos: Vector2 = data.get("pos", Vector2.ZERO)
		var sighted_tick: int = data.get("tick", _current_tick)
		var age: int = _current_tick - sighted_tick

		# Fade alpha based on age (fully faded after 600 ticks ~10 s at 60 tps)
		var alpha: float = clampf(1.0 - float(age) / 600.0, 0.15, 0.85)
		var color := Color(FADE_COLOR_UNIT.r, FADE_COLOR_UNIT.g, FADE_COLOR_UNIT.b, alpha)

		draw_circle(pos, UNIT_ICON_RADIUS, color)
		_draw_dashed_circle(pos, UNIT_ICON_RADIUS + 4.0, color * 0.7)

		# "Last seen X ticks ago" label
		var label := "?" if age == 0 else ("~%d" % age)
		draw_string(
			ThemeDB.fallback_font,
			pos + LABEL_OFFSET,
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			Color(LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b, alpha)
		)


func _draw_structure_outlines() -> void:
	for entity_id: int in _scouted_structures:
		var data: Dictionary = _scouted_structures[entity_id]
		var pos: Vector2 = data.get("pos", Vector2.ZERO)
		var half: Vector2 = data.get("size", STRUCTURE_OUTLINE_HALF) * 0.5
		var rect := Rect2(pos - half, half * 2.0)
		draw_rect(rect, FADE_COLOR_STRUCTURE, false, 2.0)


func _draw_detection_rings() -> void:
	for entity_id: int in _scouted_structures:
		var data: Dictionary = _scouted_structures[entity_id]
		if not data.get("has_detection", false):
			continue
		var pos: Vector2 = data.get("pos", Vector2.ZERO)
		var stype: String = data.get("structure_type", "")
		var radius: float = DETECTION_RADII.get(stype, 120.0)
		# Outer solid ring
		_draw_dashed_circle(pos, radius, DETECTION_RING_COLOR, DETECTION_RING_WIDTH)
		# Inner fill hint (very transparent)
		draw_circle(pos, radius, Color(DETECTION_RING_COLOR.r, DETECTION_RING_COLOR.g,
			DETECTION_RING_COLOR.b, 0.06))


func _draw_patrol_routes() -> void:
	for entity_id: int in _scouted_structures:
		var data: Dictionary = _scouted_structures[entity_id]
		var route: Array = data.get("patrol_route", [])
		if route.size() < 2:
			continue
		for i: int in range(route.size() - 1):
			draw_line(route[i], route[i + 1], PATROL_HINT_COLOR, PATROL_LINE_WIDTH)
		# Close the loop
		draw_line(route[route.size() - 1], route[0], PATROL_HINT_COLOR, PATROL_LINE_WIDTH)


# Approximates a dashed circle using short line segments.
func _draw_dashed_circle(
		center: Vector2, radius: float, color: Color, width: float = 1.0,
		segments: int = 32, dash_ratio: float = 0.6) -> void:
	var step: float = TAU / float(segments)
	for i: int in range(segments):
		# Only draw the "dash" portion of each segment
		if float(i % 2) > dash_ratio:
			continue
		var a0: float = i * step
		var a1: float = a0 + step * dash_ratio
		draw_line(
			center + Vector2(cos(a0), sin(a0)) * radius,
			center + Vector2(cos(a1), sin(a1)) * radius,
			color, width
		)
