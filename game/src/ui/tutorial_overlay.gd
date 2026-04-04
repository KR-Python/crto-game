# TutorialOverlay: non-intrusive in-game guidance layer.
# Displays step text, progress indicator, highlighted UI elements, and a skip button.
# Connects to TutorialSystem signals — receives step dictionaries, drives all visual state.
class_name TutorialOverlay
extends CanvasLayer

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

## Duration (seconds) for the highlight ring pulse animation.
const HIGHLIGHT_PULSE_DURATION: float = 1.2
## Bottom panel height in pixels.
const PANEL_HEIGHT: float = 100.0
## Highlight ring radius offset beyond the target rect.
const RING_MARGIN: float = 8.0

# ---------------------------------------------------------------------------
# Node references — assigned in _ready, expected in scene tree.
# ---------------------------------------------------------------------------

@onready var _panel: PanelContainer = $BottomPanel
@onready var _instruction_label: Label = $BottomPanel/VBox/InstructionLabel
@onready var _progress_label: Label = $BottomPanel/VBox/ProgressLabel
@onready var _hint_label: Label = $BottomPanel/VBox/HintLabel
@onready var _next_button: Button = $BottomPanel/VBox/NextButton
@onready var _skip_button: Button = $SkipButton
@onready var _highlight_ring: Control = $HighlightRing
@onready var _arrow: TextureRect = $ArrowIndicator

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _tutorial_system: TutorialSystem = null
var _total_steps: int = 0
var _current_step_index: int = 0
var _highlight_tween: Tween = null
var _is_manual_step: bool = false

# Maps highlight_element name → NodePath of the actual UI node to highlight.
# Populated at runtime; extend as new UI panels are added.
var _element_map: Dictionary = {
	"request_wheel": "/root/GameScene/HUD/RequestWheel",
	"structure_palette": "/root/GameScene/HUD/StructurePalette",
	"tech_tree_panel": "/root/GameScene/HUD/TechTreePanel",
	"minimap": "/root/GameScene/HUD/Minimap",
	"game_world": "/root/GameScene/Viewport",
}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	visible = false
	_next_button.pressed.connect(_on_next_pressed)
	_skip_button.pressed.connect(_on_skip_pressed)
	_highlight_ring.visible = false
	_arrow.visible = false
	_hint_label.visible = false


## Bind this overlay to a TutorialSystem instance and show the first step.
func bind(tutorial_system: TutorialSystem, total_steps: int) -> void:
	if _tutorial_system != null:
		_disconnect_signals()

	_tutorial_system = tutorial_system
	_total_steps = total_steps
	_current_step_index = 0

	_tutorial_system.step_started.connect(_on_step_started)
	_tutorial_system.step_completed.connect(_on_step_completed)
	_tutorial_system.tutorial_finished.connect(_on_tutorial_finished)
	_tutorial_system.hint_shown.connect(_on_hint_shown)

	visible = true


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_step_started(step: Dictionary) -> void:
	_current_step_index = _tutorial_system.current_step
	show_step(step)


func _on_step_completed(step_index: int) -> void:
	# Visual feedback — flash the panel briefly.
	_flash_panel()


func _on_tutorial_finished() -> void:
	_clear_highlight()
	visible = false


func _on_hint_shown(text: String, target_ui: String) -> void:
	_hint_label.text = "💡 " + text
	_hint_label.visible = true


func _on_next_pressed() -> void:
	if _tutorial_system != null and _is_manual_step:
		_tutorial_system.advance_step()


func _on_skip_pressed() -> void:
	if _tutorial_system != null:
		_tutorial_system.active = false
		_tutorial_system.emit_signal("tutorial_finished")
	visible = false


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Render the given step dictionary into all overlay widgets.
func show_step(step: Dictionary) -> void:
	var complete_when: String = step.get("complete_when", "")
	_is_manual_step = (complete_when == "manual")

	_instruction_label.text = step.get("text", "")
	_hint_label.visible = false

	_progress_label.text = "Step %d of %d" % [_current_step_index + 1, _total_steps]

	_next_button.visible = _is_manual_step
	_next_button.text = "Next ▶"

	var highlight_name: String = step.get("highlight_element", "")
	if not highlight_name.is_empty():
		highlight_element(highlight_name)
		_point_arrow_at(highlight_name)
	else:
		_clear_highlight()
		_arrow.visible = false

	# Ensure panel slides into view.
	_panel.visible = true
	_animate_panel_in()


## Draw an animated ring around the UI element identified by `element_name`.
func highlight_element(element_name: String) -> void:
	var target_path: String = _element_map.get(element_name, "")
	if target_path.is_empty():
		push_warning("TutorialOverlay: no mapping for element '%s'" % element_name)
		_highlight_ring.visible = false
		return

	var target_node = get_node_or_null(target_path)
	if target_node == null:
		push_warning("TutorialOverlay: node not found at '%s'" % target_path)
		_highlight_ring.visible = false
		return

	_position_ring_over(target_node)
	_animate_highlight_ring()


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _position_ring_over(target: Control) -> void:
	if not target is Control:
		_highlight_ring.visible = false
		return

	var rect: Rect2 = target.get_global_rect()
	_highlight_ring.position = rect.position - Vector2(RING_MARGIN, RING_MARGIN)
	_highlight_ring.size = rect.size + Vector2(RING_MARGIN * 2, RING_MARGIN * 2)
	_highlight_ring.visible = true


func _animate_highlight_ring() -> void:
	if _highlight_tween != null:
		_highlight_tween.kill()
	_highlight_tween = create_tween().set_loops()
	_highlight_tween.tween_property(
		_highlight_ring, "modulate:a", 0.3, HIGHLIGHT_PULSE_DURATION / 2.0
	).from(1.0)
	_highlight_tween.tween_property(
		_highlight_ring, "modulate:a", 1.0, HIGHLIGHT_PULSE_DURATION / 2.0
	)


func _clear_highlight() -> void:
	if _highlight_tween != null:
		_highlight_tween.kill()
		_highlight_tween = null
	_highlight_ring.visible = false


func _point_arrow_at(element_name: String) -> void:
	var target_path: String = _element_map.get(element_name, "")
	if target_path.is_empty():
		_arrow.visible = false
		return

	var target_node = get_node_or_null(target_path)
	if target_node == null or not target_node is Control:
		_arrow.visible = false
		return

	var rect: Rect2 = (target_node as Control).get_global_rect()
	# Position the arrow just above the target element.
	_arrow.position = Vector2(rect.get_center().x - _arrow.size.x / 2.0, rect.position.y - _arrow.size.y - 4.0)
	_arrow.visible = true


func _animate_panel_in() -> void:
	var t: Tween = create_tween()
	_panel.modulate.a = 0.0
	t.tween_property(_panel, "modulate:a", 1.0, 0.3)


func _flash_panel() -> void:
	var t: Tween = create_tween()
	t.tween_property(_panel, "modulate", Color(1.2, 1.2, 0.8, 1.0), 0.1)
	t.tween_property(_panel, "modulate", Color.WHITE, 0.2)


func _disconnect_signals() -> void:
	if _tutorial_system == null:
		return
	if _tutorial_system.step_started.is_connected(_on_step_started):
		_tutorial_system.step_started.disconnect(_on_step_started)
	if _tutorial_system.step_completed.is_connected(_on_step_completed):
		_tutorial_system.step_completed.disconnect(_on_step_completed)
	if _tutorial_system.tutorial_finished.is_connected(_on_tutorial_finished):
		_tutorial_system.tutorial_finished.disconnect(_on_tutorial_finished)
	if _tutorial_system.hint_shown.is_connected(_on_hint_shown):
		_tutorial_system.hint_shown.disconnect(_on_hint_shown)
