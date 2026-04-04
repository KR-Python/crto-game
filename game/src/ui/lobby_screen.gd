class_name LobbyScreen
extends Control

## Role-selection lobby displayed after host/join.
## Shows 6 role cards, a player list, settings panel, and ready/start controls.

signal role_selected(role: String)
signal game_start_requested()

const ROLE_DATA: Array[Dictionary] = [
	{
		"id": "commander",
		"name": "Commander",
		"description": "Places structures, sets strategy, approves superweapons.",
		"color": Color("#4A90D9"),
	},
	{
		"id": "quartermaster",
		"name": "Quartermaster",
		"description": "Manages production queues, economy, and harvester routing.",
		"color": Color("#F5A623"),
	},
	{
		"id": "field_marshal",
		"name": "Field Marshal",
		"description": "Commands all combat units and leads engagements.",
		"color": Color("#D0021B"),
	},
	{
		"id": "spec_ops",
		"name": "Spec Ops",
		"description": "Controls elite infiltration units and deep scouting.",
		"color": Color("#7ED321"),
	},
	{
		"id": "chief_engineer",
		"name": "Chief Engineer",
		"description": "Repairs structures, deploys defenses, manages power grid.",
		"color": Color("#9013FE"),
	},
	{
		"id": "air_marshal",
		"name": "Air Marshal",
		"description": "Commands air forces, interceptors, and strategic bombers.",
		"color": Color("#50E3C2"),
	},
]

## role_id → player name (empty string = open slot)
var _assignments: Dictionary = {}

## Whether this client is the session host
var is_host: bool = false

@onready var _role_grid: GridContainer = $HSplit/Center/RoleGrid
@onready var _player_list: ItemList = $HSplit/Left/PlayerList
@onready var _settings_anchor: Control = $HSplit/Right/SettingsAnchor
@onready var _ready_button: Button = $Bottom/ReadyButton
@onready var _start_button: Button = $Bottom/StartButton

var _settings_panel: SettingsPanel = null

# Maps role_id → card root node
var _role_cards: Dictionary = {}


func _ready() -> void:
	for role: Dictionary in ROLE_DATA:
		_assignments[role["id"]] = ""

	_build_role_cards()
	_apply_host_visibility()

	_ready_button.pressed.connect(_on_ready_pressed)
	_start_button.pressed.connect(_on_start_pressed)

	_settings_panel = SettingsPanel.new()
	_settings_anchor.add_child(_settings_panel)


# ── Public API ────────────────────────────────────────────────────────────────

## Update which player holds a role. Pass empty string to mark as open, "AI" for AI.
func set_role_assignment(role_id: String, player_name: String) -> void:
	if not _assignments.has(role_id):
		push_warning("LobbyScreen: unknown role '%s'" % role_id)
		return
	_assignments[role_id] = player_name
	_refresh_card(role_id)


## Replace the player list contents.
func set_player_list(players: Array[String]) -> void:
	_player_list.clear()
	for name: String in players:
		_player_list.add_item(name)


# ── Private ───────────────────────────────────────────────────────────────────

func _build_role_cards() -> void:
	for role: Dictionary in ROLE_DATA:
		var card := _create_role_card(role)
		_role_grid.add_child(card)
		_role_cards[role["id"]] = card


func _create_role_card(role: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Card_" + role["id"]

	var style := StyleBoxFlat.new()
	style.bg_color = (role["color"] as Color).darkened(0.4)
	style.border_color = role["color"] as Color
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	card.add_child(vbox)

	var title := Label.new()
	title.name = "Title"
	title.text = role["name"]
	title.add_theme_color_override("font_color", role["color"] as Color)
	vbox.add_child(title)

	var desc := Label.new()
	desc.name = "Desc"
	desc.text = role["description"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	var assignment := Label.new()
	assignment.name = "Assignment"
	assignment.text = "Open"
	vbox.add_child(assignment)

	var take_btn := Button.new()
	take_btn.name = "TakeButton"
	take_btn.text = "Take Role"
	take_btn.pressed.connect(_on_take_role.bind(role["id"]))
	vbox.add_child(take_btn)

	return card


func _refresh_card(role_id: String) -> void:
	if not _role_cards.has(role_id):
		return
	var card: PanelContainer = _role_cards[role_id]
	var assignment: Label = card.get_node("VBoxContainer/Assignment")
	var value: String = _assignments[role_id]
	assignment.text = value if not value.is_empty() else "Open"


func _apply_host_visibility() -> void:
	_start_button.visible = is_host
	_ready_button.visible = not is_host


func _on_take_role(role_id: String) -> void:
	role_selected.emit(role_id)


func _on_ready_pressed() -> void:
	_ready_button.disabled = true
	_ready_button.text = "Ready ✓"


func _on_start_pressed() -> void:
	game_start_requested.emit()
