class_name PerformanceMonitor
extends Node

# In-game performance overlay, toggled with F3.
# Tracks tick times, entity count, and spatial hash stats.

var enabled: bool = false
var _tick_times: Array = []
var _tick_start_usec: int = 0
var _entity_count: int = 0
var _spatial_hash_cells: int = 0

const MAX_SAMPLES: int = 60


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		enabled = not enabled
		queue_redraw()


func record_tick_start() -> void:
	_tick_start_usec = Time.get_ticks_usec()


func record_tick_end() -> void:
	var elapsed_ms: float = (Time.get_ticks_usec() - _tick_start_usec) / 1000.0
	_tick_times.append(elapsed_ms)
	if _tick_times.size() > MAX_SAMPLES:
		_tick_times.pop_front()


func set_entity_count(count: int) -> void:
	_entity_count = count


func set_spatial_hash_cells(count: int) -> void:
	_spatial_hash_cells = count


func get_avg_tick_ms() -> float:
	if _tick_times.is_empty():
		return 0.0
	var total: float = 0.0
	for t in _tick_times:
		total += t
	return total / _tick_times.size()


func get_max_tick_ms() -> float:
	if _tick_times.is_empty():
		return 0.0
	var mx: float = 0.0
	for t in _tick_times:
		if t > mx:
			mx = t
	return mx


func _draw() -> void:
	if not enabled:
		return

	var font: Font = ThemeDB.fallback_font
	var font_size: int = 14
	var x: float = 10.0
	var y: float = 30.0
	var line_h: float = 20.0
	var bg := Rect2(4, 8, 320, line_h * 4 + 12)

	draw_rect(bg, Color(0, 0, 0, 0.7))

	var lines: Array = [
		"ECS entities: %d" % _entity_count,
		"Avg tick: %.1fms | Max tick: %.1fms" % [get_avg_tick_ms(), get_max_tick_ms()],
		"FPS: %d | Frame time: %.1fms" % [Engine.get_frames_per_second(), 1000.0 / max(Engine.get_frames_per_second(), 1)],
		"Spatial hash cells: %d" % _spatial_hash_cells,
	]

	for i in range(lines.size()):
		draw_string(font, Vector2(x, y + i * line_h), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _process(_delta: float) -> void:
	if enabled:
		queue_redraw()
