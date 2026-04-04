class_name SettingsScreen
extends Control

## Three-tab settings UI: Audio, Video, Keybinds.
## Reads/writes through SettingsManager autoload.

signal closed()

const TAB_AUDIO: int    = 0
const TAB_VIDEO: int    = 1
const TAB_KEYBINDS: int = 2

var _rebinding_action: String = ""
var _keybind_labels: Dictionary = {}

const REBINDABLE_ACTIONS: Array = [
	["camera_up",     "Move Camera Up"],
	["camera_down",   "Move Camera Down"],
	["camera_left",   "Move Camera Left"],
	["camera_right",  "Move Camera Right"],
	["zoom_in",       "Zoom In"],
	["zoom_out",      "Zoom Out"],
	["select_all",    "Select All"],
	["attack_move",   "Attack Move"],
	["stop",          "Stop"],
	["hold_position", "Hold Position"],
	["request_wheel", "Open Request Wheel"],
	["ping_danger",   "Ping Danger"],
	["home_camera",   "Home Camera"],
]

var _tab_container: TabContainer
var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider
var _fullscreen_check: CheckButton
var _vsync_check: CheckButton
var _resolution_opt: OptionButton
var _render_scale_slider: HSlider
var _render_scale_label: Label
var _keybind_list: VBoxContainer
var _rebind_overlay: Panel


func _ready() -> void:
	_build_ui()
	_load_values()


func _input(event: InputEvent) -> void:
	if _rebinding_action.is_empty():
		return
	# Ignore key/button release events
	if event is InputEventKey and not (event as InputEventKey).pressed:
		return
	if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		return
	# Escape cancels the rebind
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
		_cancel_rebind()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey or event is InputEventMouseButton:
		SettingsManager.rebind_key(_rebinding_action, event)
		_finish_rebind()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# UI Construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.7)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := Panel.new()
	panel.set_anchor(SIDE_LEFT,   0.5)
	panel.set_anchor(SIDE_RIGHT,  0.5)
	panel.set_anchor(SIDE_TOP,    0.5)
	panel.set_anchor(SIDE_BOTTOM, 0.5)
	panel.set_offset(SIDE_LEFT,   -350.0)
	panel.set_offset(SIDE_RIGHT,   350.0)
	panel.set_offset(SIDE_TOP,    -250.0)
	panel.set_offset(SIDE_BOTTOM,  250.0)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	var title := Label.new()
	title.text = "Settings"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(_on_close_pressed)
	title_row.add_child(close_btn)

	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tab_container)

	_build_audio_tab()
	_build_video_tab()
	_build_keybind_tab()

	_rebind_overlay = Panel.new()
	_rebind_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rebind_overlay.visible = false
	add_child(_rebind_overlay)

	var overlay_label := Label.new()
	overlay_label.text = "Press any key to rebind.\n(Escape to cancel)"
	overlay_label.set_anchors_preset(Control.PRESET_CENTER)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rebind_overlay.add_child(overlay_label)


func _build_audio_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Audio"
	tab.add_theme_constant_override("separation", 12)
	_tab_container.add_child(tab)

	_master_slider = _add_volume_row(tab, "Master Volume")
	_music_slider  = _add_volume_row(tab, "Music Volume")
	_sfx_slider    = _add_volume_row(tab, "SFX Volume")

	var test_btn := Button.new()
	test_btn.text = "Test Sound"
	test_btn.pressed.connect(_on_test_sound_pressed)
	tab.add_child(test_btn)


func _add_volume_row(parent: VBoxContainer, label_text: String) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(160, 0)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var pct_lbl := Label.new()
	pct_lbl.custom_minimum_size = Vector2(40, 0)
	pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pct_lbl)

	slider.value_changed.connect(func(v: float) -> void:
		pct_lbl.text = "%d%%" % int(v * 100)
	)
	return slider


func _build_video_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Video"
	tab.add_theme_constant_override("separation", 12)
	_tab_container.add_child(tab)

	var fs_row := HBoxContainer.new()
	tab.add_child(fs_row)
	var fs_lbl := Label.new()
	fs_lbl.text = "Fullscreen"
	fs_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_row.add_child(fs_lbl)
	_fullscreen_check = CheckButton.new()
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	fs_row.add_child(_fullscreen_check)

	var vs_row := HBoxContainer.new()
	tab.add_child(vs_row)
	var vs_lbl := Label.new()
	vs_lbl.text = "VSync"
	vs_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vs_row.add_child(vs_lbl)
	_vsync_check = CheckButton.new()
	_vsync_check.toggled.connect(_on_vsync_toggled)
	vs_row.add_child(_vsync_check)

	var res_row := HBoxContainer.new()
	tab.add_child(res_row)
	var res_lbl := Label.new()
	res_lbl.text = "Resolution"
	res_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_row.add_child(res_lbl)
	_resolution_opt = OptionButton.new()
	for res in ["1280x720", "1920x1080", "2560x1440", "3840x2160"]:
		_resolution_opt.add_item(res)
	res_row.add_child(_resolution_opt)

	var scale_row := HBoxContainer.new()
	tab.add_child(scale_row)
	var scale_lbl := Label.new()
	scale_lbl.text = "Render Scale"
	scale_lbl.custom_minimum_size = Vector2(140, 0)
	scale_row.add_child(scale_lbl)
	_render_scale_slider = HSlider.new()
	_render_scale_slider.min_value = 0.5
	_render_scale_slider.max_value = 1.0
	_render_scale_slider.step = 0.05
	_render_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_row.add_child(_render_scale_slider)
	_render_scale_label = Label.new()
	_render_scale_label.custom_minimum_size = Vector2(50, 0)
	_render_scale_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	scale_row.add_child(_render_scale_label)
	_render_scale_slider.value_changed.connect(func(v: float) -> void:
		_render_scale_label.text = "%d%%" % int(v * 100)
	)

	var apply_btn := Button.new()
	apply_btn.text = "Apply"
	apply_btn.pressed.connect(_on_video_apply_pressed)
	tab.add_child(apply_btn)


func _build_keybind_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Keybinds"
	tab.add_theme_constant_override("separation", 6)
	_tab_container.add_child(tab)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)

	_keybind_list = VBoxContainer.new()
	_keybind_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_keybind_list)

	for entry in REBINDABLE_ACTIONS:
		_add_keybind_row(entry[0], entry[1])

	var reset_btn := Button.new()
	reset_btn.text = "Reset to Defaults"
	reset_btn.pressed.connect(_on_keybind_reset_pressed)
	tab.add_child(reset_btn)


func _add_keybind_row(action: String, display_name: String) -> void:
	var row := HBoxContainer.new()
	_keybind_list.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = display_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var bind_lbl := Label.new()
	bind_lbl.custom_minimum_size = Vector2(120, 0)
	bind_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(bind_lbl)
	_keybind_labels[action] = bind_lbl

	var edit_btn := Button.new()
	edit_btn.text = "Change"
	edit_btn.pressed.connect(func() -> void: _start_rebind(action))
	row.add_child(edit_btn)


# ---------------------------------------------------------------------------
# Populate widgets from SettingsManager
# ---------------------------------------------------------------------------

func _load_values() -> void:
	_master_slider.value = SettingsManager.audio.get("master_volume", 1.0)
	_music_slider.value  = SettingsManager.audio.get("music_volume",  0.7)
	_sfx_slider.value    = SettingsManager.audio.get("sfx_volume",    0.9)

	_fullscreen_check.button_pressed = SettingsManager.video.get("fullscreen", false)
	_vsync_check.button_pressed      = SettingsManager.video.get("vsync", true)
	_select_resolution(SettingsManager.video.get("resolution", "1920x1080"))
	_render_scale_slider.value = SettingsManager.video.get("render_scale", 1.0)

	_refresh_keybind_labels()


func _select_resolution(res: String) -> void:
	for i in _resolution_opt.item_count:
		if _resolution_opt.get_item_text(i) == res:
			_resolution_opt.selected = i
			return
	_resolution_opt.selected = 1  # fallback to 1920x1080


func _refresh_keybind_labels() -> void:
	for action in _keybind_labels.keys():
		var event: InputEvent = SettingsManager.get_keybind(action)
		_keybind_labels[action].text = _event_display(event)


func _event_display(event: InputEvent) -> String:
	if event == null:
		return "—"
	if event is InputEventKey:
		return OS.get_keycode_string((event as InputEventKey).keycode)
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_WHEEL_UP:   return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
			MOUSE_BUTTON_LEFT:       return "Mouse Left"
			MOUSE_BUTTON_RIGHT:      return "Mouse Right"
			MOUSE_BUTTON_MIDDLE:     return "Mouse Middle"
	return "Unknown"


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_fullscreen_toggled(pressed: bool) -> void:
	SettingsManager.set_video("fullscreen", pressed)


func _on_vsync_toggled(pressed: bool) -> void:
	SettingsManager.set_video("vsync", pressed)


func _on_video_apply_pressed() -> void:
	SettingsManager.set_video("fullscreen",    _fullscreen_check.button_pressed)
	SettingsManager.set_video("vsync",         _vsync_check.button_pressed)
	SettingsManager.set_video("resolution",    _resolution_opt.get_item_text(_resolution_opt.selected))
	SettingsManager.set_video("render_scale",  _render_scale_slider.value)
	SettingsManager.apply_video()


func _on_test_sound_pressed() -> void:
	# Requires an AudioStreamPlayer autoloaded as UIClick; skip gracefully if absent
	var player: AudioStreamPlayer = get_node_or_null("/root/UIClick")
	if player:
		player.play()


func _start_rebind(action: String) -> void:
	_rebinding_action = action
	_rebind_overlay.visible = true


func _finish_rebind() -> void:
	_rebinding_action = ""
	_rebind_overlay.visible = false
	_refresh_keybind_labels()


func _cancel_rebind() -> void:
	_rebinding_action = ""
	_rebind_overlay.visible = false


func _on_keybind_reset_pressed() -> void:
	SettingsManager.reset_to_defaults()
	_load_values()


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
