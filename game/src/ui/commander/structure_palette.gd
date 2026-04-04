class_name StructurePalette
extends Control

## Commander's primary build panel — lists structures available for placement.
## Filtered by faction and build requirements. Emits structure_selected to trigger
## InputHandler placement ghost.

signal structure_selected(structure_type: String)
signal placement_cancelled()

var data_loader: DataLoader
var faction_id: int
var selected_structure: String = ""
var _built_ids: Array[String] = []
var _item_container: VBoxContainer
var _items: Dictionary = {}

func _ready() -> void:
	_build_layout()
	if data_loader:
		refresh(_built_ids)

func _build_layout() -> void:
	name = "StructurePalette"
	custom_minimum_size = Vector2(200, 400)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "BUILD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_item_container = VBoxContainer.new()
	_item_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_item_container)

## Re-filter palette items based on what's already been built.
func refresh(built_structure_ids: Array[String]) -> void:
	_built_ids = built_structure_ids
	_rebuild_items()

## Called by InputHandler when placement completes or is cancelled.
func clear_selection() -> void:
	selected_structure = ""
	_update_selection_highlight()

func _rebuild_items() -> void:
	for child in _item_container.get_children():
		child.queue_free()
	_items.clear()
	if not data_loader:
		push_warning("StructurePalette: data_loader not set")
		return
	var structures: Array = data_loader.get_structures_for_faction(faction_id)
	for struct_data in structures:
		var item := _create_item(struct_data)
		_item_container.add_child(item)
		_items[struct_data.id] = item

func _create_item(struct_data: Dictionary) -> Button:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 56)
	btn.focus_mode = Control.FOCUS_NONE
	var met := _requirements_met(struct_data)
	btn.disabled = not met
	btn.text = _format_item_label(struct_data, met)
	btn.tooltip_text = struct_data.get("description", "")
	if met:
		btn.pressed.connect(_on_item_pressed.bind(struct_data.id))
	else:
		btn.modulate = Color(0.5, 0.5, 0.5, 1.0)
	return btn

func _format_item_label(data: Dictionary, met: bool) -> String:
	var ore: int = data.get("cost_ore", 0)
	var gems: int = data.get("cost_gems", 0)
	var power: int = data.get("power_consumption", 0)
	var cost_str := "%d ore" % ore
	if gems > 0:
		cost_str += " / %d gems" % gems
	if power != 0:
		cost_str += " | %+d pwr" % -power
	return "%s%s\n%s" % [data.get("name", data.id), "" if met else " [locked]", cost_str]

func _requirements_met(struct_data: Dictionary) -> bool:
	for req in struct_data.get("build_requirements", []):
		if req not in _built_ids:
			return false
	return true

func _on_item_pressed(structure_type: String) -> void:
	selected_structure = structure_type
	_update_selection_highlight()
	emit_signal("structure_selected", structure_type)

func _update_selection_highlight() -> void:
	for sid in _items:
		var btn: Button = _items[sid]
		if sid == selected_structure:
			btn.modulate = Color(1.2, 1.2, 0.6, 1.0)
		elif btn.disabled:
			btn.modulate = Color(0.5, 0.5, 0.5, 1.0)
		else:
			btn.modulate = Color(1, 1, 1, 1)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and selected_structure != "":
		selected_structure = ""
		_update_selection_highlight()
		emit_signal("placement_cancelled")
