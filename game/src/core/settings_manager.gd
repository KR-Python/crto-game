class_name SettingsManager
extends Node

## Singleton for persisting and applying player settings via Godot's ConfigFile.
## Covers audio levels, video options, and rebindable keybinds.

signal settings_changed(category: String)

const SETTINGS_PATH: String = "user://settings.cfg"

# Default values — also used by reset_to_defaults()
const DEFAULT_AUDIO: Dictionary = {
	"master_volume": 1.0,
	"music_volume": 0.7,
	"sfx_volume": 0.9,
}

const DEFAULT_VIDEO: Dictionary = {
	"fullscreen": false,
	"vsync": true,
	"resolution": "1920x1080",
	"render_scale": 1.0,
}

# Key constants used as default values; stored as int scancode / mouse button index
const DEFAULT_KEYBINDS: Dictionary = {
	"camera_up": KEY_W,
	"camera_down": KEY_S,
	"camera_left": KEY_A,
	"camera_right": KEY_D,
	"zoom_in": MOUSE_BUTTON_WHEEL_UP,
	"zoom_out": MOUSE_BUTTON_WHEEL_DOWN,
	"select_all": KEY_CTRL,   # +A combo handled in InputHandler
	"attack_move": KEY_A,
	"stop": KEY_S,
	"hold_position": KEY_H,
	"request_wheel": KEY_Q,
	"ping_danger": KEY_ALT,
	"home_camera": KEY_HOME,
}

var audio: Dictionary = DEFAULT_AUDIO.duplicate()
var video: Dictionary = DEFAULT_VIDEO.duplicate()
# action_name → InputEvent (populated from DEFAULT_KEYBINDS on first load)
var keybinds: Dictionary = {}

var _config: ConfigFile = ConfigFile.new()


func _ready() -> void:
	load_settings()


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func load_settings() -> void:
	var err: int = _config.load(SETTINGS_PATH)
	if err != OK:
		# No saved config yet — apply defaults and bail
		_apply_keybind_defaults()
		return

	# Audio
	for key in DEFAULT_AUDIO.keys():
		audio[key] = _config.get_value("audio", key, DEFAULT_AUDIO[key])

	# Video
	for key in DEFAULT_VIDEO.keys():
		video[key] = _config.get_value("video", key, DEFAULT_VIDEO[key])

	# Keybinds — serialised as scancode integers
	for action in DEFAULT_KEYBINDS.keys():
		var stored: int = _config.get_value("keybinds", action, -1)
		if stored == -1:
			keybinds[action] = _make_event_from_default(action)
		else:
			keybinds[action] = _make_event_from_int(action, stored)

	_apply_audio()
	_apply_video()


func save_settings() -> void:
	for key in audio.keys():
		_config.set_value("audio", key, audio[key])

	for key in video.keys():
		_config.set_value("video", key, video[key])

	for action in keybinds.keys():
		_config.set_value("keybinds", action, _event_to_int(keybinds[action]))

	var err: int = _config.save(SETTINGS_PATH)
	if err != OK:
		push_error("SettingsManager: failed to save settings — error %d" % err)


func reset_to_defaults() -> void:
	audio = DEFAULT_AUDIO.duplicate()
	video = DEFAULT_VIDEO.duplicate()
	_apply_keybind_defaults()
	_apply_audio()
	_apply_video()
	save_settings()
	settings_changed.emit("all")


# ---------------------------------------------------------------------------
# Audio API
# ---------------------------------------------------------------------------

func set_audio(key: String, value: float) -> void:
	if not DEFAULT_AUDIO.has(key):
		push_warning("SettingsManager: unknown audio key '%s'" % key)
		return
	audio[key] = clampf(value, 0.0, 1.0)
	_apply_audio()
	save_settings()
	settings_changed.emit("audio")


func _apply_audio() -> void:
	_set_bus_volume("Master", audio.get("master_volume", 1.0))
	_set_bus_volume("Music", audio.get("music_volume", 0.7))
	_set_bus_volume("SFX", audio.get("sfx_volume", 0.9))


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		push_warning("SettingsManager: audio bus '%s' not found" % bus_name)
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


# ---------------------------------------------------------------------------
# Video API
# ---------------------------------------------------------------------------

func set_video(key: String, value: Variant) -> void:
	if not DEFAULT_VIDEO.has(key):
		push_warning("SettingsManager: unknown video key '%s'" % key)
		return
	video[key] = value
	save_settings()
	settings_changed.emit("video")


func apply_video() -> void:
	_apply_video()


func _apply_video() -> void:
	# Fullscreen
	var fs: bool = video.get("fullscreen", false)
	if fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# VSync
	var vsync_mode: int = DisplayServer.VSYNC_ENABLED if video.get("vsync", true) \
		else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)

	# Resolution
	var res_str: String = video.get("resolution", "1920x1080")
	var parts: PackedStringArray = res_str.split("x")
	if parts.size() == 2:
		var w: int = parts[0].to_int()
		var h: int = parts[1].to_int()
		if w > 0 and h > 0:
			DisplayServer.window_set_size(Vector2i(w, h))

	# Render scale — applies to the 3D viewport if one exists
	var scale: float = clampf(video.get("render_scale", 1.0), 0.5, 1.0)
	var vp: Viewport = get_viewport()
	if vp:
		vp.scaling_3d_scale = scale


# ---------------------------------------------------------------------------
# Keybind API
# ---------------------------------------------------------------------------

func rebind_key(action: String, event: InputEvent) -> void:
	if not DEFAULT_KEYBINDS.has(action):
		push_warning("SettingsManager: unknown action '%s'" % action)
		return
	keybinds[action] = event
	# Propagate to Godot's InputMap so the new binding takes effect immediately
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	save_settings()
	settings_changed.emit("keybinds")


func get_keybind(action: String) -> InputEvent:
	return keybinds.get(action, null)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _apply_keybind_defaults() -> void:
	for action in DEFAULT_KEYBINDS.keys():
		keybinds[action] = _make_event_from_default(action)


func _make_event_from_default(action: String) -> InputEvent:
	return _make_event_from_int(action, DEFAULT_KEYBINDS[action])


func _make_event_from_int(action: String, code: int) -> InputEvent:
	# Mouse button codes live in the MouseButton enum range
	if code == MOUSE_BUTTON_WHEEL_UP or code == MOUSE_BUTTON_WHEEL_DOWN \
			or code == MOUSE_BUTTON_LEFT or code == MOUSE_BUTTON_RIGHT \
			or code == MOUSE_BUTTON_MIDDLE:
		var mb := InputEventMouseButton.new()
		mb.button_index = code
		return mb
	var kb := InputEventKey.new()
	kb.keycode = code
	return kb


func _event_to_int(event: InputEvent) -> int:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).button_index
	if event is InputEventKey:
		return (event as InputEventKey).keycode
	return -1
