class_name AbilityBar
extends Control

## Spec Ops ability cooldown tracker.
## Displays a horizontal row of four ability buttons:
##   [1] Cloak  [2] Plant C4  [3] Steal Tech  [4] Mark Target
## Each button shows:
##   - A placeholder icon (ColorRect tinted to ability theme color)
##   - Cooldown countdown (seconds remaining)
##   - Hotkey label (1 / 2 / 3 / 4)
##   - Greyed-out overlay while on cooldown
##   - Pulsing glow when cooldown completes and ability is ready
## Clicking a button or pressing the matching hotkey emits ability_activated.

signal ability_activated(ability_id: String, entity_id: int)

const BUTTON_SIZE := Vector2(72.0, 72.0)
const BUTTON_GAP := 8.0
const COOLDOWN_FONT_SIZE := 18
const HOTKEY_FONT_SIZE := 11
const PULSE_PERIOD := 0.6  # seconds for one ready-flash cycle

# Ability definitions — order determines hotkey index (1-based).
const ABILITIES: Array[Dictionary] = [
	{ "id": "cloak",       "label": "Cloak",        "hotkey": "1", "color": Color(0.3, 0.6, 1.0) },
	{ "id": "plant_c4",    "label": "Plant C4",     "hotkey": "2", "color": Color(1.0, 0.35, 0.1) },
	{ "id": "steal_tech",  "label": "Steal Tech",   "hotkey": "3", "color": Color(0.5, 1.0, 0.5) },
	{ "id": "mark_target", "label": "Mark Target",  "hotkey": "4", "color": Color(1.0, 0.9, 0.2) },
]

# entity_id of the currently tracked Spec Ops unit (-1 = no unit selected).
var tracked_entity_id: int = -1

# Cooldown state: ability_id -> seconds remaining (0.0 = ready).
var _cooldowns: Dictionary = {
	"cloak": 0.0,
	"plant_c4": 0.0,
	"steal_tech": 0.0,
	"mark_target": 0.0,
}

# Max cooldowns (filled in by set_max_cooldowns or game data system).
var _max_cooldowns: Dictionary = {
	"cloak": 12.0,
	"plant_c4": 20.0,
	"steal_tech": 30.0,
	"mark_target": 8.0,
}

var _pulse_time: float = 0.0

# Cached button containers (Panel nodes), indexed same as ABILITIES.
var _buttons: Array[Control] = []
var _cooldown_labels: Array[Label] = []
var _overlay_rects: Array[ColorRect] = []
var _icon_rects: Array[ColorRect] = []


func _ready() -> void:
	_build_ui()
	set_process(true)
	set_process_input(true)


func _process(delta: float) -> void:
	_pulse_time += delta
	_tick_cooldowns(delta)
	_refresh_visuals()


func _input(event: InputEvent) -> void:
	if tracked_entity_id == -1:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		for i: int in range(ABILITIES.size()):
			var ab: Dictionary = ABILITIES[i]
			if event.as_text() == ab["hotkey"]:
				_activate_ability(ab["id"])
				get_viewport().set_input_as_handled()
				break


# ── Public API ──────────────────────────────────────────────────────────────


## Bind this bar to a Spec Ops entity.  Pass -1 to detach.
func set_tracked_entity(entity_id: int) -> void:
	tracked_entity_id = entity_id
	_refresh_visuals()


## Override default max cooldowns (called once when loading ability data).
func set_max_cooldowns(maxes: Dictionary) -> void:
	for key: String in maxes:
		_max_cooldowns[key] = maxes[key]


## Called by the ability system when an ability is used (starts cooldown).
func start_cooldown(ability_id: String) -> void:
	if ability_id in _cooldowns:
		_cooldowns[ability_id] = _max_cooldowns.get(ability_id, 10.0)
		_refresh_visuals()


# ── Private ──────────────────────────────────────────────────────────────────


func _build_ui() -> void:
	custom_minimum_size = Vector2(
		ABILITIES.size() * BUTTON_SIZE.x + (ABILITIES.size() - 1) * BUTTON_GAP,
		BUTTON_SIZE.y
	)

	for i: int in range(ABILITIES.size()):
		var ab: Dictionary = ABILITIES[i]

		# Outer panel
		var panel := PanelContainer.new()
		panel.custom_minimum_size = BUTTON_SIZE
		panel.position = Vector2(i * (BUTTON_SIZE.x + BUTTON_GAP), 0.0)
		panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		add_child(panel)
		_buttons.append(panel)

		var vbox := VBoxContainer.new()
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(vbox)

		# Ability icon placeholder
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(40.0, 40.0)
		icon.color = ab["color"]
		vbox.add_child(icon)
		_icon_rects.append(icon)

		# Cooldown / hotkey label
		var cd_label := Label.new()
		cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_label.add_theme_font_size_override("font_size", COOLDOWN_FONT_SIZE)
		vbox.add_child(cd_label)
		_cooldown_labels.append(cd_label)

		var hk_label := Label.new()
		hk_label.text = "[%s] %s" % [ab["hotkey"], ab["label"]]
		hk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hk_label.add_theme_font_size_override("font_size", HOTKEY_FONT_SIZE)
		vbox.add_child(hk_label)

		# Cooldown dimming overlay
		var overlay := ColorRect.new()
		overlay.color = Color(0.0, 0.0, 0.0, 0.55)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(overlay)
		_overlay_rects.append(overlay)

		# Click detection
		var btn := Button.new()
		btn.flat = true
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.connect("pressed", _on_button_pressed.bind(ab["id"]))
		panel.add_child(btn)


func _tick_cooldowns(delta: float) -> void:
	for key: String in _cooldowns:
		if _cooldowns[key] > 0.0:
			_cooldowns[key] = maxf(_cooldowns[key] - delta, 0.0)


func _refresh_visuals() -> void:
	for i: int in range(ABILITIES.size()):
		var ab: Dictionary = ABILITIES[i]
		var cd: float = _cooldowns[ab["id"]]
		var on_cd: bool = cd > 0.0
		var is_ready: bool = not on_cd and tracked_entity_id != -1

		# Cooldown label
		if on_cd:
			_cooldown_labels[i].text = "%.0f" % ceilf(cd)
		else:
			_cooldown_labels[i].text = ""

		# Dim overlay
		_overlay_rects[i].visible = on_cd or tracked_entity_id == -1

		# Pulse when ready
		if is_ready:
			var pulse: float = (sin(_pulse_time * TAU / PULSE_PERIOD) * 0.5 + 0.5) * 0.4
			_icon_rects[i].color = ab["color"].lightened(pulse)
		else:
			_icon_rects[i].color = ab["color"].darkened(0.3) if on_cd else ab["color"]


func _on_button_pressed(ability_id: String) -> void:
	_activate_ability(ability_id)


func _activate_ability(ability_id: String) -> void:
	if tracked_entity_id == -1:
		return
	if _cooldowns.get(ability_id, 0.0) > 0.0:
		return
	ability_activated.emit(ability_id, tracked_entity_id)
