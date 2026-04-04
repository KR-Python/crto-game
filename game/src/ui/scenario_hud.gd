class_name ScenarioHUD
extends Control

# In-scenario HUD overlay.
# Displays:
#   - Objective tracker (top-left panel) — icon, description, progress/timer per objective
#   - Narrative popup (center screen) — auto-dismisses after NARRATIVE_DISPLAY_SECS seconds
#   - Time remaining display (top-center) — shown when scenario has a time_limit_ticks

const NARRATIVE_DISPLAY_SECS: float = 5.0
const TICK_RATE: int = 15  # ticks per second — matches ScenarioSystem convention

# Injected by GameLoop after load.
var scenario_system: ScenarioSystem = null:
	set(value):
		scenario_system = value
		_connect_scenario_signals()

var _time_limit_ticks: int = 0
var _current_tick: int = 0

# Runtime state for narrative popup.
var _narrative_timer: float = 0.0
var _narrative_visible: bool = false

# ── Child node references (set up in _ready or via @onready) ─────────────────

@onready var _objective_list: VBoxContainer = $ObjectivePanel/ObjectiveList
@onready var _narrative_panel: PanelContainer = $NarrativePanel
@onready var _narrative_speaker: Label = $NarrativePanel/VBox/Speaker
@onready var _narrative_text: Label = $NarrativePanel/VBox/Text
@onready var _time_label: Label = $TopBar/TimeRemaining
@onready var _top_bar: HBoxContainer = $TopBar


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_narrative_panel.visible = false


func _process(delta: float) -> void:
	if _narrative_visible:
		_narrative_timer -= delta
		if _narrative_timer <= 0.0:
			_hide_narrative()


# ── Public API (called by GameLoop each tick) ─────────────────────────────────

func set_scenario(scenario_data: Dictionary) -> void:
	_time_limit_ticks = scenario_data.get("time_limit_ticks", 0)
	_top_bar.visible = _time_limit_ticks > 0
	_rebuild_objective_list(scenario_data.get("objectives", []))


func update_tick(tick_count: int) -> void:
	_current_tick = tick_count
	if _time_limit_ticks > 0:
		_refresh_time_label()


# ── Signal handlers ───────────────────────────────────────────────────────────

func _connect_scenario_signals() -> void:
	if scenario_system == null:
		return
	scenario_system.objective_completed.connect(_on_objective_completed)
	scenario_system.objective_failed.connect(_on_objective_failed)
	scenario_system.narrative_message.connect(_on_narrative_message)
	scenario_system.scenario_won.connect(_on_scenario_won)
	scenario_system.scenario_lost.connect(_on_scenario_lost)


func _on_objective_completed(objective_id: String, _description: String) -> void:
	_set_objective_status(objective_id, "completed")


func _on_objective_failed(objective_id: String, _description: String) -> void:
	_set_objective_status(objective_id, "failed")


func _on_narrative_message(text: String, speaker: String) -> void:
	_show_narrative(text, speaker)


func _on_scenario_won() -> void:
	# GameLoop handles the victory screen; we just hide ourselves.
	visible = false


func _on_scenario_lost() -> void:
	visible = false


# ── Objective tracker ─────────────────────────────────────────────────────────

func _rebuild_objective_list(objectives: Array) -> void:
	for child in _objective_list.get_children():
		child.queue_free()

	for obj: Dictionary in objectives:
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "obj_" + obj.get("id", "unknown")

		var icon: Label = Label.new()
		icon.name = "Icon"
		icon.text = _status_icon("active")
		icon.custom_minimum_size = Vector2(24, 0)
		row.add_child(icon)

		var desc: Label = Label.new()
		desc.name = "Desc"
		desc.text = obj.get("description", "")
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc)

		_objective_list.add_child(row)


func _set_objective_status(objective_id: String, status: String) -> void:
	var row: Node = _objective_list.find_child("obj_" + objective_id, false, false)
	if row == null:
		return
	var icon: Label = row.find_child("Icon", false, false) as Label
	if icon:
		icon.text = _status_icon(status)
	var desc: Label = row.find_child("Desc", false, false) as Label
	if desc:
		# Dim completed/failed objectives visually.
		desc.modulate = Color(0.6, 0.6, 0.6) if status != "active" else Color.WHITE


func _status_icon(status: String) -> String:
	match status:
		"active":    return "◻"
		"completed": return "✔"
		"failed":    return "✘"
		_:           return "?"


# ── Narrative popup ───────────────────────────────────────────────────────────

func _show_narrative(text: String, speaker: String) -> void:
	_narrative_speaker.text = speaker
	_narrative_text.text = text
	_narrative_panel.visible = true
	_narrative_timer = NARRATIVE_DISPLAY_SECS
	_narrative_visible = true


func _hide_narrative() -> void:
	_narrative_panel.visible = false
	_narrative_visible = false


# ── Time remaining ────────────────────────────────────────────────────────────

func _refresh_time_label() -> void:
	var ticks_left: int = max(0, _time_limit_ticks - _current_tick)
	var seconds_left: int = ticks_left / TICK_RATE
	var minutes: int = seconds_left / 60
	var secs: int = seconds_left % 60
	_time_label.text = "Time: %02d:%02d" % [minutes, secs]

	# Pulse red in the final 60 seconds.
	if seconds_left <= 60:
		_time_label.modulate = Color(1.0, 0.3, 0.3)
	else:
		_time_label.modulate = Color.WHITE
