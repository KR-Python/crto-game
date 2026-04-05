class_name CameraController
extends Camera2D

# Settings
@export var pan_speed: float = 400.0        # pixels/sec keyboard pan
@export var edge_scroll_margin: int = 20    # pixels from edge to trigger scroll
@export var edge_scroll_speed: float = 500.0
@export var zoom_min: float = 0.25
@export var zoom_max: float = 4.0
@export var zoom_step: float = 0.25
@export var zoom_speed: float = 8.0         # smooth zoom lerp speed

# Map bounds clamping (set from GameMap on load)
var map_bounds: Rect2 = Rect2(0, 0, 4096, 3072)

# Internal state
var _target_zoom: float = 3.0
var _is_middle_drag: bool = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_cam: Vector2 = Vector2.ZERO
var _spawn_point: Vector2 = Vector2.ZERO     # Home key destination

# Smooth pan tween
var _pan_tween: Tween = null

signal camera_moved(new_position: Vector2)
signal zoom_changed(new_zoom: float)


func _ready() -> void:
	zoom = Vector2(_target_zoom, _target_zoom)
	_spawn_point = position


func _process(delta: float) -> void:
	_handle_keyboard_pan(delta)
	_handle_edge_scroll(delta)
	_handle_zoom_lerp(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_drag(event as InputEventMouseMotion)
	elif event is InputEventKey:
		_handle_key(event as InputEventKey)


# ── Input handlers ────────────────────────────────────────────────────────────

func _handle_keyboard_pan(delta: float) -> void:
	var dir := Vector2.ZERO

	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0

	if dir == Vector2.ZERO:
		return

	_cancel_pan_tween()
	_move_camera(dir.normalized() * pan_speed * delta)


func _handle_edge_scroll(delta: float) -> void:
	var vp := get_viewport()
	if vp == null:
		return

	var mouse_pos: Vector2 = vp.get_mouse_position()
	var vp_size: Vector2 = vp.get_visible_rect().size
	var dir := Vector2.ZERO

	if mouse_pos.x < edge_scroll_margin:
		dir.x -= 1.0
	elif mouse_pos.x > vp_size.x - edge_scroll_margin:
		dir.x += 1.0

	if mouse_pos.y < edge_scroll_margin:
		dir.y -= 1.0
	elif mouse_pos.y > vp_size.y - edge_scroll_margin:
		dir.y += 1.0

	if dir == Vector2.ZERO:
		return

	_cancel_pan_tween()
	_move_camera(dir.normalized() * edge_scroll_speed * delta)


func _handle_zoom_lerp(delta: float) -> void:
	var current_z: float = zoom.x
	var new_z: float = lerpf(current_z, _target_zoom, zoom_speed * delta)
	if abs(new_z - current_z) < 0.0001:
		return
	zoom = Vector2(new_z, new_z)
	zoom_changed.emit(new_z)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_target_zoom = clampf(_target_zoom + zoom_step, zoom_min, zoom_max)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_target_zoom = clampf(_target_zoom - zoom_step, zoom_min, zoom_max)
		MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_is_middle_drag = true
				_drag_start_mouse = event.position
				_drag_start_cam = position
				_cancel_pan_tween()
			else:
				_is_middle_drag = false


func _handle_mouse_drag(event: InputEventMouseMotion) -> void:
	if not _is_middle_drag:
		return
	var delta_mouse: Vector2 = event.position - _drag_start_mouse
	# Invert because dragging right should move map right (camera moves left)
	var new_pos: Vector2 = _drag_start_cam - delta_mouse / zoom.x
	position = _clamp_to_bounds(new_pos)
	camera_moved.emit(position)


func _handle_key(event: InputEventKey) -> void:
	if event.pressed and event.keycode == KEY_HOME:
		jump_to(_spawn_point)


# ── Public API ────────────────────────────────────────────────────────────────

## Instantly snap camera to world position.
func jump_to(world_pos: Vector2) -> void:
	_cancel_pan_tween()
	position = _clamp_to_bounds(world_pos)
	camera_moved.emit(position)


## Set the home / spawn point (used by Home key).
func set_spawn_point(world_pos: Vector2) -> void:
	_spawn_point = world_pos


## Smoothly pan to world position over `duration` seconds.
func smooth_pan_to(world_pos: Vector2, duration: float = 0.5) -> void:
	_cancel_pan_tween()
	var target: Vector2 = _clamp_to_bounds(world_pos)
	_pan_tween = create_tween()
	_pan_tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_SINE)
	_pan_tween.tween_callback(func() -> void: camera_moved.emit(position))


# ── Helpers ───────────────────────────────────────────────────────────────────

func _move_camera(offset: Vector2) -> void:
	position = _clamp_to_bounds(position + offset)
	camera_moved.emit(position)


func _clamp_to_bounds(pos: Vector2) -> Vector2:
	return Vector2(
		clampf(pos.x, map_bounds.position.x, map_bounds.end.x),
		clampf(pos.y, map_bounds.position.y, map_bounds.end.y)
	)


func _cancel_pan_tween() -> void:
	if _pan_tween != null and _pan_tween.is_running():
		_pan_tween.kill()
	_pan_tween = null
