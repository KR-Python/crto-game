class_name Minimap
extends Control

## Phase 1 minimap — entity dots + camera viewport outline.
##
## Redraws on every 5th game-loop tick.  Connect the game loop's
## tick_completed signal:
##   game_loop.tick_completed.connect(_on_tick_completed)
##
## World coordinates:  (0,0) → (map_width * tile_size, map_height * tile_size)
## Minimap coordinates: (0,0) → MINIMAP_SIZE

# ------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------

const MINIMAP_SIZE: Vector2 = Vector2(200, 150)  # pixels

var ecs         # ECS — injected by HUD
var camera: CameraController
var map_width: int  = 128  # tiles
var map_height: int = 96   # tiles
var tile_size: int  = 16   # pixels per tile (matches world scale)
var local_faction_id: int = 0

# Dot sizes
const DOT_RADIUS: float    = 2.0
const DOT_RADIUS_LARGE: float = 3.0  # structures

# Tick-based redraw
const REDRAW_EVERY_N_TICKS: int = 5
var _tick_counter: int = 0

# Faction colour palette (faction_id → colour)
# Friendly (own faction) = green, Enemy = red, neutral/unknown = gray
const COLOR_FRIENDLY: Color = Color(0.2, 0.9, 0.2)
const COLOR_ENEMY:    Color = Color(0.9, 0.2, 0.2)
const COLOR_NEUTRAL:  Color = Color(0.6, 0.6, 0.6)
const COLOR_CAMERA:   Color = Color(1.0, 1.0, 1.0, 0.8)

# ------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------

func _ready() -> void:
	custom_minimum_size = MINIMAP_SIZE
	set_process_input(true)


# ------------------------------------------------------------------
# Tick-based refresh (connect game_loop.tick_completed here)
# ------------------------------------------------------------------

func _on_tick_completed(_tick: int) -> void:
	_tick_counter += 1
	if _tick_counter >= REDRAW_EVERY_N_TICKS:
		_tick_counter = 0
		queue_redraw()


# ------------------------------------------------------------------
# Drawing
# ------------------------------------------------------------------

func _draw() -> void:
	# Dark background.
	draw_rect(Rect2(Vector2.ZERO, MINIMAP_SIZE), Color(0.1, 0.1, 0.1))

	_draw_entities()
	_draw_camera_rect()
	# Border.
	draw_rect(Rect2(Vector2.ZERO, MINIMAP_SIZE), Color(0.4, 0.4, 0.4), false)


func _draw_entities() -> void:
	if ecs == null:
		return

	# Query all entities that have both Position and FactionComponent.
	var entities: Array[int] = ecs.query_entities_with_components(
		["Position", "FactionComponent"]
	)

	for eid in entities:
		var world_pos: Vector2 = ecs.get_component(eid, "Position")
		var faction_id: int    = ecs.get_component_value(eid, "FactionComponent", "faction_id")
		var is_structure: bool = ecs.entity_has_component(eid, "Structure")

		var dot_pos: Vector2 = _world_to_minimap(world_pos)
		var color: Color      = _faction_color(faction_id)
		var radius: float     = DOT_RADIUS_LARGE if is_structure else DOT_RADIUS

		draw_circle(dot_pos, radius, color)


func _draw_camera_rect() -> void:
	if camera == null:
		return
	var viewport_rect: Rect2 = camera.get_viewport_world_rect()
	var tl := _world_to_minimap(viewport_rect.position)
	var br := _world_to_minimap(viewport_rect.end)
	var mm_rect := Rect2(tl, br - tl).abs()
	draw_rect(mm_rect, COLOR_CAMERA, false)


# ------------------------------------------------------------------
# Input — click to jump camera
# ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return

	# Only respond to clicks inside our own rect.
	var local_pos := mb.position - global_position
	if not Rect2(Vector2.ZERO, MINIMAP_SIZE).has_point(local_pos):
		return

	var world_pos := _minimap_to_world(local_pos)
	if camera != null:
		camera.center_on(world_pos)
	get_viewport().set_input_as_handled()


# ------------------------------------------------------------------
# Coordinate helpers
# ------------------------------------------------------------------

func _world_to_minimap(world_pos: Vector2) -> Vector2:
	var world_w: float = float(map_width  * tile_size)
	var world_h: float = float(map_height * tile_size)
	return Vector2(
		(world_pos.x / world_w) * MINIMAP_SIZE.x,
		(world_pos.y / world_h) * MINIMAP_SIZE.y
	)


func _minimap_to_world(mm_pos: Vector2) -> Vector2:
	var world_w: float = float(map_width  * tile_size)
	var world_h: float = float(map_height * tile_size)
	return Vector2(
		(mm_pos.x / MINIMAP_SIZE.x) * world_w,
		(mm_pos.y / MINIMAP_SIZE.y) * world_h
	)


func _faction_color(faction_id: int) -> Color:
	if faction_id == local_faction_id:
		return COLOR_FRIENDLY
	if faction_id == -1:
		return COLOR_NEUTRAL
	return COLOR_ENEMY
