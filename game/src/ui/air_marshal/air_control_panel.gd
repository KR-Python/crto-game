class_name AirControlPanel
extends Control

## Air Marshal HUD — command and status panel for all air units.
##
## Responsibilities:
##   • Display all air units with current fuel % and HP bar
##   • Bombing run: press button → targeting cursor active → click map → emit signal
##   • Paradrop: select transport + infantry → click drop zone → emit signal
##   • Air patrol: press button → draw patrol path (click points, double-click to finish)
##
## Signals:
##   bombing_run_requested(target: Vector2)
##   paradrop_requested(transport_id: int, drop_zone: Vector2)
##   air_patrol_set(unit_id: int, patrol_points: Array)

signal bombing_run_requested(target: Vector2)
signal paradrop_requested(transport_id: int, drop_zone: Vector2)
signal air_patrol_set(unit_id: int, patrol_points: Array)

enum InputMode {
	NONE,
	BOMBING_RUN_TARGETING,
	PARADROP_TARGETING,
	PATROL_DRAWING,
}

const UNIT_ROW_HEIGHT := 48.0
const FUEL_BAR_COLOR := Color(0.2, 0.8, 1.0)
const HP_BAR_COLOR := Color(0.2, 1.0, 0.3)
const LOW_FUEL_COLOR := Color(1.0, 0.6, 0.1)
const CRITICAL_FUEL_COLOR := Color(1.0, 0.2, 0.2)
const PANEL_WIDTH := 280.0

# Air unit data: entity_id -> { "name": String, "fuel": float, "max_fuel": float,
#                               "hp": float, "max_hp": float, "unit_type": String }
var _air_units: Dictionary = {}

# Pending paradrop: which transport is selected
var _pending_paradrop_transport_id: int = -1

# Patrol drawing state
var _patrol_unit_id: int = -1
var _patrol_points: Array[Vector2] = []

var _input_mode: InputMode = InputMode.NONE

# UI nodes built in _build_ui
var _unit_list_container: VBoxContainer = null
var _status_label: Label = null
var _bomb_btn: Button = null
var _paradrop_btn: Button = null
var _patrol_btn: Button = null


func _ready() -> void:
	_build_ui()
	set_process_input(true)


func _input(event: InputEvent) -> void:
	match _input_mode:
		InputMode.BOMBING_RUN_TARGETING:
			_handle_bombing_input(event)
		InputMode.PARADROP_TARGETING:
			_handle_paradrop_input(event)
		InputMode.PATROL_DRAWING:
			_handle_patrol_input(event)


# ── Public API ──────────────────────────────────────────────────────────────


## Feed the current air unit roster each tick (or on change).
func update_air_units(units: Dictionary) -> void:
	_air_units = units
	_rebuild_unit_rows()


## Notify the panel that a paradrop transport has been designated externally.
func set_paradrop_transport(transport_id: int) -> void:
	_pending_paradrop_transport_id = transport_id
	_status_label.text = "Select drop zone on map…"


## Set which unit is being assigned a patrol (called when user selects an air unit).
func set_patrol_unit(unit_id: int) -> void:
	_patrol_unit_id = unit_id


# ── Private ──────────────────────────────────────────────────────────────────


func _build_ui() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, 240.0)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "✈ AIR MARSHAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Scrollable unit list
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(PANEL_WIDTH, 120.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_unit_list_container = VBoxContainer.new()
	_unit_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_unit_list_container)

	vbox.add_child(HSeparator.new())

	# Command buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	vbox.add_child(btn_row)

	_bomb_btn = _make_command_button("💣 Bombing Run", _on_bomb_pressed)
	btn_row.add_child(_bomb_btn)

	_paradrop_btn = _make_command_button("🪂 Paradrop", _on_paradrop_pressed)
	btn_row.add_child(_paradrop_btn)

	_patrol_btn = _make_command_button("🔄 Air Patrol", _on_patrol_pressed)
	btn_row.add_child(_patrol_btn)

	# Status label for targeting feedback
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.modulate = Color(0.9, 0.9, 0.5)
	vbox.add_child(_status_label)


func _make_command_button(label: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.connect("pressed", callback)
	return btn


func _rebuild_unit_rows() -> void:
	for child: Node in _unit_list_container.get_children():
		child.queue_free()

	if _air_units.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "(No air units)"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_unit_list_container.add_child(empty_lbl)
		return

	for entity_id: int in _air_units:
		var data: Dictionary = _air_units[entity_id]
		_unit_list_container.add_child(_build_unit_row(entity_id, data))


func _build_unit_row(entity_id: int, data: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH - 12.0, UNIT_ROW_HEIGHT)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 6)
	panel.add_child(hbox)

	# Unit name
	var name_lbl := Label.new()
	name_lbl.text = data.get("name", "Air Unit %d" % entity_id)
	name_lbl.custom_minimum_size = Vector2(80.0, 0.0)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)

	# Fuel bar
	var fuel: float = data.get("fuel", 0.0)
	var max_fuel: float = maxf(data.get("max_fuel", 1.0), 1.0)
	var fuel_pct: float = fuel / max_fuel
	hbox.add_child(_build_bar(fuel_pct, _fuel_color(fuel_pct), "⛽"))

	# HP bar
	var hp: float = data.get("hp", 0.0)
	var max_hp: float = maxf(data.get("max_hp", 1.0), 1.0)
	hbox.add_child(_build_bar(hp / max_hp, HP_BAR_COLOR, "❤"))

	return panel


func _build_bar(pct: float, color: Color, icon: String) -> Control:
	var container := HBoxContainer.new()

	var icon_lbl := Label.new()
	icon_lbl.text = icon
	icon_lbl.add_theme_font_size_override("font_size", 10)
	container.add_child(icon_lbl)

	var bar := ProgressBar.new()
	bar.value = clampf(pct * 100.0, 0.0, 100.0)
	bar.custom_minimum_size = Vector2(52.0, 14.0)
	bar.show_percentage = false
	# Tint the fill via modulate (no StyleBox override needed for placeholder)
	bar.modulate = color
	container.add_child(bar)

	return container


func _fuel_color(pct: float) -> Color:
	if pct < 0.25:
		return CRITICAL_FUEL_COLOR
	if pct < 0.5:
		return LOW_FUEL_COLOR
	return FUEL_BAR_COLOR


# ── Input handlers ────────────────────────────────────────────────────────


func _on_bomb_pressed() -> void:
	_input_mode = InputMode.BOMBING_RUN_TARGETING
	_status_label.text = "Click map to select bombing target…"


func _on_paradrop_pressed() -> void:
	if _pending_paradrop_transport_id == -1:
		_status_label.text = "Select a transport unit first."
		return
	_input_mode = InputMode.PARADROP_TARGETING
	_status_label.text = "Click map to select drop zone…"


func _on_patrol_pressed() -> void:
	if _patrol_unit_id == -1:
		_status_label.text = "Select an air unit first."
		return
	_patrol_points.clear()
	_input_mode = InputMode.PATROL_DRAWING
	_status_label.text = "Click map points for patrol path. Double-click to finish."


func _handle_bombing_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and \
			event.button_index == MOUSE_BUTTON_LEFT:
		var world_pos: Vector2 = _screen_to_world(event.position)
		bombing_run_requested.emit(world_pos)
		_input_mode = InputMode.NONE
		_status_label.text = "Bombing run ordered."
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_input_mode()


func _handle_paradrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and \
			event.button_index == MOUSE_BUTTON_LEFT:
		var world_pos: Vector2 = _screen_to_world(event.position)
		paradrop_requested.emit(_pending_paradrop_transport_id, world_pos)
		_pending_paradrop_transport_id = -1
		_input_mode = InputMode.NONE
		_status_label.text = "Paradrop ordered."
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_input_mode()


func _handle_patrol_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		var world_pos: Vector2 = _screen_to_world(event.position)
		if event.double_click:
			# Finish patrol path
			_patrol_points.append(world_pos)
			air_patrol_set.emit(_patrol_unit_id, _patrol_points.duplicate())
			_patrol_points.clear()
			_patrol_unit_id = -1
			_input_mode = InputMode.NONE
			_status_label.text = "Air patrol set."
		else:
			_patrol_points.append(world_pos)
			_status_label.text = "Point added (%d). Double-click to finish." % _patrol_points.size()
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_input_mode()


func _cancel_input_mode() -> void:
	_input_mode = InputMode.NONE
	_patrol_points.clear()
	_status_label.text = ""
	get_viewport().set_input_as_handled()


# Converts a screen-space position to world-space via the active camera.
# Falls back to raw screen position if no camera is found.
func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return screen_pos
	var camera: Camera2D = viewport.get_camera_2d()
	if camera == null:
		return screen_pos
	return camera.get_screen_center_position() + \
		(screen_pos - Vector2(viewport.get_visible_rect().size) * 0.5) / camera.zoom
