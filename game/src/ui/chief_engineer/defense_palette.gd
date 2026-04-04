class_name DefensePalette
extends Control

## Chief Engineer building palette — defense structures only.
## Mirrors the Commander's StructurePalette API but scoped to:
##   Turret | Wall | Gate | Mine | Sensor
## Each entry shows:
##   - Structure name
##   - Placeholder icon (ColorRect)
##   - Power consumption cost
##   - Greyed out when insufficient power
## Also contains a Repair Mode toggle button.
##
## Signals:
##   structure_selected(structure_type)  — user clicked a structure button
##   repair_mode_toggled(active)         — user toggled the repair mode button

signal structure_selected(structure_type: String)
signal repair_mode_toggled(active: bool)

# Defense structure definitions.
const STRUCTURES: Array[Dictionary] = [
	{ "type": "turret",  "label": "Turret",  "power": 10, "color": Color(0.9, 0.3, 0.2) },
	{ "type": "wall",    "label": "Wall",    "power":  2, "color": Color(0.6, 0.6, 0.7) },
	{ "type": "gate",    "label": "Gate",    "power":  4, "color": Color(0.7, 0.6, 0.5) },
	{ "type": "mine",    "label": "Mine",    "power":  0, "color": Color(0.8, 0.7, 0.1) },
	{ "type": "sensor",  "label": "Sensor",  "power":  6, "color": Color(0.2, 0.8, 0.9) },
]

const BUTTON_SIZE := Vector2(80.0, 80.0)
const BUTTON_GAP := 6.0
const ICON_SIZE := Vector2(44.0, 44.0)

# Current available power (updated by Quartermaster/power system).
var available_power: int = 100

# Whether repair mode is currently active.
var repair_mode_active: bool = false

var _structure_buttons: Array[Button] = []
var _power_labels: Array[Label] = []
var _repair_button: Button = null


func _ready() -> void:
	_build_ui()


# ── Public API ──────────────────────────────────────────────────────────────


## Called by the power system to update the available power budget.
## Refreshes button enabled states.
func set_available_power(power: int) -> void:
	available_power = power
	_refresh_power_states()


# ── Private ──────────────────────────────────────────────────────────────────


func _build_ui() -> void:
	custom_minimum_size = Vector2(
		STRUCTURES.size() * (BUTTON_SIZE.x + BUTTON_GAP) + BUTTON_SIZE.x + BUTTON_GAP,
		BUTTON_SIZE.y + 8.0
	)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(BUTTON_GAP))
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hbox)

	# Structure buttons
	for i: int in range(STRUCTURES.size()):
		var def: Dictionary = STRUCTURES[i]

		var btn := Button.new()
		btn.custom_minimum_size = BUTTON_SIZE
		btn.flat = false
		btn.tooltip_text = "%s\nPower: %d" % [def["label"], def["power"]]
		btn.connect("pressed", _on_structure_pressed.bind(def["type"]))
		hbox.add_child(btn)
		_structure_buttons.append(btn)

		# Layout inside button: icon + name + power label
		var vbox := VBoxContainer.new()
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vbox)

		var icon := ColorRect.new()
		icon.custom_minimum_size = ICON_SIZE
		icon.color = def["color"]
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(icon)

		var name_lbl := Label.new()
		name_lbl.text = def["label"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(name_lbl)

		var power_lbl := Label.new()
		if def["power"] > 0:
			power_lbl.text = "⚡%d" % def["power"]
		else:
			power_lbl.text = "Free"
		power_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		power_lbl.add_theme_font_size_override("font_size", 10)
		power_lbl.modulate = Color(0.9, 0.9, 0.5)
		power_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(power_lbl)
		_power_labels.append(power_lbl)

	# Separator
	var sep := VSeparator.new()
	hbox.add_child(sep)

	# Repair mode toggle button
	_repair_button = Button.new()
	_repair_button.custom_minimum_size = BUTTON_SIZE
	_repair_button.text = "🔧\nRepair\nMode"
	_repair_button.toggle_mode = true
	_repair_button.tooltip_text = "Toggle repair targeting cursor"
	_repair_button.connect("toggled", _on_repair_toggled)
	hbox.add_child(_repair_button)

	_refresh_power_states()


func _refresh_power_states() -> void:
	for i: int in range(STRUCTURES.size()):
		var def: Dictionary = STRUCTURES[i]
		var can_afford: bool = def["power"] <= available_power
		_structure_buttons[i].disabled = not can_afford
		_structure_buttons[i].modulate = Color.WHITE if can_afford else Color(0.5, 0.5, 0.5)


func _on_structure_pressed(structure_type: String) -> void:
	# Deactivate repair mode when placing a structure
	if repair_mode_active:
		_repair_button.button_pressed = false
	structure_selected.emit(structure_type)


func _on_repair_toggled(active: bool) -> void:
	repair_mode_active = active
	repair_mode_toggled.emit(active)
