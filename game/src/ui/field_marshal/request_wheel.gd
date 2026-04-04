class_name RequestWheel
extends Control

## Field Marshal's quick request radial menu.
## Hold Q to show wheel centered on mouse; release over option to emit request_sent.

signal request_sent(request_type: String)

const WHEEL_RADIUS: float = 80.0
const REQUESTS: Array = [
	{"id": "tanks",    "label": "Need Tanks",    "category": "heavy_armor"},
	{"id": "antiair",  "label": "Need Anti-Air", "category": "anti_air"},
	{"id": "infantry", "label": "Need Infantry", "category": "infantry"},
	{"id": "support",  "label": "Need Support",  "category": "support"},
]

var _visible_wheel: bool = false
var _hovered_index: int = -1
var _segment_buttons: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_wheel()

func _build_wheel() -> void:
	name = "RequestWheel"
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(240, 240)
	var center_label := Label.new()
	center_label.text = "REQUEST"
	center_label.add_theme_font_size_override("font_size", 12)
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label.set_anchors_preset(Control.PRESET_CENTER)
	center_label.custom_minimum_size = Vector2(80, 24)
	add_child(center_label)
	# Cardinal directions: top, right, bottom, left
	var directions: Array = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	for i in range(REQUESTS.size()):
		var btn := Button.new()
		btn.text = REQUESTS[i].label
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(90, 36)
		btn.set_anchors_preset(Control.PRESET_CENTER)
		btn.position = directions[i] * WHEEL_RADIUS - btn.custom_minimum_size / 2.0
		_segment_buttons.append(btn)
		add_child(btn)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("request_wheel"):
		_show_wheel()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("request_wheel"):
		_commit_selection()
		_hide_wheel()
		get_viewport().set_input_as_handled()
	elif _visible_wheel and event is InputEventMouseMotion:
		_update_hover(event.position)

func _show_wheel() -> void:
	_visible_wheel = true
	_hovered_index = -1
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	global_position = get_viewport().get_mouse_position() - size / 2.0
	_update_segment_highlights()

func _hide_wheel() -> void:
	_visible_wheel = false
	_hovered_index = -1
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_segment_highlights()

func _update_hover(mouse_screen_pos: Vector2) -> void:
	var best_dist := INF
	var best_idx := -1
	for i in range(_segment_buttons.size()):
		var btn: Button = _segment_buttons[i]
		var center := btn.global_position + btn.size / 2.0
		var dist := mouse_screen_pos.distance_to(center)
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	_hovered_index = best_idx if best_dist < WHEEL_RADIUS * 1.5 else -1
	_update_segment_highlights()

func _commit_selection() -> void:
	if _hovered_index >= 0 and _hovered_index < REQUESTS.size():
		emit_signal("request_sent", REQUESTS[_hovered_index].id)

func _update_segment_highlights() -> void:
	for i in range(_segment_buttons.size()):
		_segment_buttons[i].modulate = Color(1.3, 1.0, 0.3) if i == _hovered_index else Color(1, 1, 1)
