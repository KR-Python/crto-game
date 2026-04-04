class_name PingSystem
extends Node2D

## Map ping display — animated circles that fade over 3 seconds.
##
## Pings are drawn in world space (add PingSystem as a child of the
## game world layer, NOT the UI CanvasLayer).
##
## Alt+click triggers a ping via InputHandler → command_issued →
## PING_MAP command → server broadcasts → all team members call add_ping().
##
## Ping types mirror the design doc communication system.

# ------------------------------------------------------------------
# Enum
# ------------------------------------------------------------------

enum PingType { DANGER, ATTACK, DEFEND, SCOUT, EXPAND }

# ------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------

const PING_DURATION_SEC: float = 3.0
const PING_MAX_RADIUS:   float = 24.0
const PING_MIN_RADIUS:   float = 6.0
const PING_RING_WIDTH:   float = 2.5

## Colour per ping type.
const PING_COLORS: Dictionary = {
	PingType.DANGER:  Color(1.0, 0.15, 0.15),
	PingType.ATTACK:  Color(1.0, 0.5,  0.0),
	PingType.DEFEND:  Color(0.2, 0.6,  1.0),
	PingType.SCOUT:   Color(0.9, 0.9,  0.2),
	PingType.EXPAND:  Color(0.2, 0.9,  0.4),
}

## Short label shown above the ping dot.
const PING_LABELS: Dictionary = {
	PingType.DANGER:  "!",
	PingType.ATTACK:  "⚔",
	PingType.DEFEND:  "🛡",
	PingType.SCOUT:   "👁",
	PingType.EXPAND:  "+",
}

# ------------------------------------------------------------------
# Internal state
# ------------------------------------------------------------------

## Each active ping is a Dictionary:
##   { pos, type, player_id, age, color, label }
var _pings: Array[Dictionary] = []

## Whether to show owner labels.  Toggle via settings later.
var show_labels: bool = true

# ------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------

func _process(delta: float) -> void:
	if _pings.is_empty():
		return
	var expired: Array[Dictionary] = []
	for ping in _pings:
		ping["age"] += delta
		if ping["age"] >= PING_DURATION_SEC:
			expired.append(ping)
	for ping in expired:
		_pings.erase(ping)
	queue_redraw()


# ------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------

## Add a ping to the display.
## world_pos: world-space position.
## ping_type: PingType enum value.
## player_id: originating player (for future per-player colour tinting).
func add_ping(world_pos: Vector2, ping_type: PingType, player_id: int) -> void:
	_pings.append({
		"pos":       world_pos,
		"type":      ping_type,
		"player_id": player_id,
		"age":       0.0,
		"color":     PING_COLORS.get(ping_type, Color.WHITE),
		"label":     PING_LABELS.get(ping_type, "?"),
	})
	queue_redraw()


## Convenience: add a ping from a PING_MAP command dictionary.
## Matches CommandProtocol PING_MAP params: { position, ping_type }.
func add_ping_from_command(params: Dictionary, player_id: int) -> void:
	var raw_pos: Dictionary = params.get("position", {"x": 0.0, "y": 0.0})
	var pos := Vector2(raw_pos.get("x", 0.0), raw_pos.get("y", 0.0))
	var type_str: String = params.get("ping_type", "DANGER").to_upper()
	var ping_type: PingType = PingType.get(type_str, PingType.DANGER) as PingType
	add_ping(pos, ping_type, player_id)


# ------------------------------------------------------------------
# Drawing
# ------------------------------------------------------------------

func _draw() -> void:
	for ping in _pings:
		_draw_ping(ping)


func _draw_ping(ping: Dictionary) -> void:
	var t: float = ping["age"] / PING_DURATION_SEC         # 0→1 as ping ages
	var alpha: float = 1.0 - t                             # fade out
	var color: Color = ping["color"]
	color.a = clampf(alpha, 0.0, 1.0)

	var pos: Vector2 = ping["pos"]

	# Expanding ring: starts small, grows to max radius.
	var radius: float = lerpf(PING_MIN_RADIUS, PING_MAX_RADIUS, t)
	draw_arc(pos, radius, 0.0, TAU, 32, color, PING_RING_WIDTH)

	# Static centre dot (fades same as ring).
	draw_circle(pos, 3.0, color)

	# Label above dot.
	if show_labels:
		var label: String = ping["label"]
		# draw_string requires a font; use a fallback approach via draw_string.
		var font := ThemeDB.fallback_font
		if font != null:
			var label_pos := pos + Vector2(-4.0, -radius - 4.0)
			draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, color)
