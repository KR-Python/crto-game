class_name HUDContainer
extends CanvasLayer

## Master HUD layer — composes the resource bar, role-specific panel, minimap,
## comms panel, ping system, and selection box.
## Call set_role() after role assignment is confirmed to swap visible panels.

const VALID_ROLES: PackedStringArray = [
	"commander",
	"quartermaster",
	"field_marshal",
	"spec_ops",
	"chief_engineer",
	"air_marshal",
]

# Top bar
@onready var _resource_bar: Control = $ResourceBar
# Bottom-left slot: role-specific panel placeholder
@onready var _role_panel_slot: Control = $RolePanelSlot
# Bottom-right
@onready var _minimap: Control = $Minimap
# Top-right
@onready var _comms_panel: Control = $CommsPanel
# Overlays
@onready var _ping_system: Control = $PingSystem
@onready var _selection_box: Control = $SelectionBox

var _active_role: String = ""
# Role panels are instantiated on demand and cached here.
var _role_panels: Dictionary = {}


func _ready() -> void:
	# All role panels start hidden; set_role() will activate the right one.
	pass


# ── Public API ────────────────────────────────────────────────────────────────

## Swap to the panel that corresponds to `role`.
## Role must be one of VALID_ROLES. Logs a warning and no-ops on invalid input.
func set_role(role: String) -> void:
	if role == _active_role:
		return

	if role not in VALID_ROLES:
		push_warning("HUDContainer: unknown role '%s'" % role)
		return

	_hide_active_panel()
	_active_role = role
	_show_or_create_panel(role)


## Returns the currently active role string, or empty string if none set.
func get_active_role() -> String:
	return _active_role


## Show or hide the entire HUD (e.g., during cutscenes).
func set_hud_visible(visible_flag: bool) -> void:
	_resource_bar.visible = visible_flag
	_role_panel_slot.visible = visible_flag
	_minimap.visible = visible_flag
	_comms_panel.visible = visible_flag
	# Overlays stay visible so players can still ping / select during cinematic pauses
	_ping_system.visible = visible_flag
	_selection_box.visible = visible_flag


# ── Private ───────────────────────────────────────────────────────────────────

func _hide_active_panel() -> void:
	if _active_role.is_empty():
		return
	if _role_panels.has(_active_role):
		(_role_panels[_active_role] as Control).hide()


func _show_or_create_panel(role: String) -> void:
	if not _role_panels.has(role):
		var panel := _build_panel_for_role(role)
		_role_panel_slot.add_child(panel)
		_role_panels[role] = panel

	(_role_panels[role] as Control).show()


## Builds a placeholder panel node for a role.
## Replace each branch with the real role-panel scene once those are implemented.
func _build_panel_for_role(role: String) -> Control:
	# Each role's dedicated panel scene will be loaded from res://src/ui/roles/
	# once those scenes exist. For now we create a labelled placeholder so that
	# the HUD wiring can be tested end-to-end without those assets.
	var path := "res://src/ui/roles/%s_panel.tscn" % role
	if ResourceLoader.exists(path):
		return load(path).instantiate() as Control

	# Fallback placeholder
	var placeholder := Label.new()
	placeholder.name = role.capitalize() + "Panel"
	placeholder.text = "[%s panel — not yet implemented]" % role
	placeholder.hide()
	return placeholder
