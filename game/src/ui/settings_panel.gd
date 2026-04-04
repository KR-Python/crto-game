class_name SettingsPanel
extends PanelContainer

## Lobby settings panel — map, difficulty, starting resources, AI personality.
## Emits settings_changed whenever the player changes any option.

signal settings_changed(settings: Dictionary)

const MAP_OPTIONS: PackedStringArray = ["Contested Highlands", "Frozen Tundra", "Desert Sands", "Island Chain", "Volcanic Rift"]
const DIFFICULTY_OPTIONS: PackedStringArray = ["Easy", "Medium", "Hard"]
const STARTING_RESOURCES_OPTIONS: PackedStringArray = ["Low (500)", "Standard (1000)", "High (2000)", "Unlimited"]
const AI_PERSONALITY_OPTIONS: PackedStringArray = ["Passive", "Balanced", "Aggressive", "Adaptive"]

@onready var _map_dropdown: OptionButton = $VBox/MapRow/MapOption
@onready var _difficulty_dropdown: OptionButton = $VBox/DifficultyRow/DifficultyOption
@onready var _resources_dropdown: OptionButton = $VBox/ResourcesRow/ResourcesOption
@onready var _ai_personality_dropdown: OptionButton = $VBox/AIRow/AIOption


func _ready() -> void:
	_populate_dropdown(_map_dropdown, MAP_OPTIONS)
	_populate_dropdown(_difficulty_dropdown, DIFFICULTY_OPTIONS)
	_populate_dropdown(_resources_dropdown, STARTING_RESOURCES_OPTIONS)
	_populate_dropdown(_ai_personality_dropdown, AI_PERSONALITY_OPTIONS)

	# Default to Medium difficulty
	_difficulty_dropdown.select(1)

	_map_dropdown.item_selected.connect(_on_any_changed)
	_difficulty_dropdown.item_selected.connect(_on_any_changed)
	_resources_dropdown.item_selected.connect(_on_any_changed)
	_ai_personality_dropdown.item_selected.connect(_on_any_changed)


# ── Public API ────────────────────────────────────────────────────────────────

## Returns current settings as a plain dictionary.
func get_settings() -> Dictionary:
	return {
		"map": _map_dropdown.get_item_text(_map_dropdown.selected),
		"difficulty": _difficulty_dropdown.get_item_text(_difficulty_dropdown.selected),
		"starting_resources": _resources_dropdown.get_item_text(_resources_dropdown.selected),
		"ai_personality": _ai_personality_dropdown.get_item_text(_ai_personality_dropdown.selected),
	}


## Apply settings dict (e.g., received from host over network).
func apply_settings(settings: Dictionary) -> void:
	_select_by_text(_map_dropdown, settings.get("map", ""))
	_select_by_text(_difficulty_dropdown, settings.get("difficulty", ""))
	_select_by_text(_resources_dropdown, settings.get("starting_resources", ""))
	_select_by_text(_ai_personality_dropdown, settings.get("ai_personality", ""))


# ── Private ───────────────────────────────────────────────────────────────────

func _populate_dropdown(btn: OptionButton, options: PackedStringArray) -> void:
	btn.clear()
	for option: String in options:
		btn.add_item(option)


func _select_by_text(btn: OptionButton, text: String) -> void:
	for i: int in btn.item_count:
		if btn.get_item_text(i) == text:
			btn.select(i)
			return


func _on_any_changed(_index: int) -> void:
	settings_changed.emit(get_settings())
