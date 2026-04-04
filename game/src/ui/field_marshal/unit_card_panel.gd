class_name UnitCardPanel
extends Control

## Field Marshal's selected unit info panel.
## Single: HP bar, weapon stats, ability/action buttons.
## Multi: summary by unit type with aggregate HP bars.

signal command_requested(action: String, params: Dictionary)

var selected_entities: Array[int] = []
var ecs: ECS
const ROLE_COLOR_FM := Color(0.9, 0.2, 0.2, 1.0)
var _single_view: Control
var _multi_view: Control
var _unit_name_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _armor_label: Label
var _dps_label: Label
var _ability_container: HBoxContainer
var _multi_summary_container: VBoxContainer

func _ready() -> void:
	_build_layout()

func _build_layout() -> void:
	name = "UnitCardPanel"
	custom_minimum_size = Vector2(280, 200)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var root_vbox := VBoxContainer.new()
	panel.add_child(root_vbox)
	var title := Label.new()
	title.text = "SELECTED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = ROLE_COLOR_FM
	title.add_theme_font_size_override("font_size", 13)
	root_vbox.add_child(title)
	root_vbox.add_child(HSeparator.new())
	_single_view = VBoxContainer.new()
	_single_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_single_view)
	_unit_name_label = Label.new()
	_unit_name_label.add_theme_font_size_override("font_size", 13)
	_single_view.add_child(_unit_name_label)
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(0, 14)
	_single_view.add_child(_hp_bar)
	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 10)
	_single_view.add_child(_hp_label)
	var stats_row := HBoxContainer.new()
	_single_view.add_child(stats_row)
	_armor_label = Label.new()
	_armor_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_armor_label.add_theme_font_size_override("font_size", 10)
	stats_row.add_child(_armor_label)
	_dps_label = Label.new()
	_dps_label.add_theme_font_size_override("font_size", 10)
	stats_row.add_child(_dps_label)
	_single_view.add_child(HSeparator.new())
	_ability_container = HBoxContainer.new()
	_single_view.add_child(_ability_container)
	_multi_view = VBoxContainer.new()
	_multi_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_multi_view)
	var multi_title := Label.new()
	multi_title.text = "Multiple Units"
	multi_title.add_theme_font_size_override("font_size", 11)
	_multi_view.add_child(multi_title)
	_multi_summary_container = VBoxContainer.new()
	_multi_view.add_child(_multi_summary_container)
	_multi_view.add_child(HSeparator.new())
	_multi_view.add_child(_build_action_buttons())
	_single_view.visible = false
	_multi_view.visible = false

func _build_action_buttons() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(_action_button("Stop", "stop"))
	row.add_child(_action_button("Hold", "hold_position"))
	row.add_child(_action_button("A-Move", "attack_move"))
	return row

func _action_button(lbl: String, action: String) -> Button:
	var btn := Button.new()
	btn.text = lbl
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(60, 28)
	btn.pressed.connect(_on_action_button_pressed.bind(action))
	return btn

func update_selection(entity_ids: Array[int]) -> void:
	selected_entities = entity_ids
	_refresh()

func clear_selection() -> void:
	selected_entities.clear()
	_single_view.visible = false
	_multi_view.visible = false

func _refresh() -> void:
	if not ecs:
		push_warning("UnitCardPanel: ecs not set")
		return
	match selected_entities.size():
		0:
			_single_view.visible = false
			_multi_view.visible = false
		1:
			_show_single(selected_entities[0])
		_:
			_show_multi(selected_entities)

func _show_single(entity_id: int) -> void:
	_multi_view.visible = false
	_single_view.visible = true
	var hp_comp: Dictionary = ecs.get_component(entity_id, "HealthComponent")
	var weapon_comp: Dictionary = ecs.get_component(entity_id, "WeaponComponent")
	var meta_comp: Dictionary = ecs.get_component(entity_id, "UnitMetaComponent")
	_unit_name_label.text = meta_comp.get("display_name", "Unit #%d" % entity_id)
	var hp_cur: int = hp_comp.get("current", 0)
	var hp_max: int = hp_comp.get("max", 1)
	_hp_bar.value = (float(hp_cur) / float(max(hp_max, 1))) * 100.0
	_hp_label.text = "%d / %d HP" % [hp_cur, hp_max]
	_armor_label.text = "Armor: %s" % meta_comp.get("armor_type", "—")
	if not weapon_comp.is_empty():
		_dps_label.text = "DPS ~%.1f" % (weapon_comp.get("damage", 0.0) * weapon_comp.get("attacks_per_second", 1.0))
	else:
		_dps_label.text = "No weapon"
	for child in _ability_container.get_children():
		child.queue_free()
	var action_row := _build_action_buttons()
	for btn in action_row.get_children():
		action_row.remove_child(btn)
		_ability_container.add_child(btn)
	for ability in meta_comp.get("abilities", []):
		var ab_btn := Button.new()
		ab_btn.text = ability.get("label", ability.id)
		ab_btn.focus_mode = Control.FOCUS_NONE
		ab_btn.custom_minimum_size = Vector2(60, 28)
		ab_btn.tooltip_text = ability.get("description", "")
		ab_btn.pressed.connect(_on_action_button_pressed.bind(ability.id))
		_ability_container.add_child(ab_btn)

func _show_multi(entity_ids: Array[int]) -> void:
	_single_view.visible = false
	_multi_view.visible = true
	for child in _multi_summary_container.get_children():
		child.queue_free()
	var type_counts: Dictionary = {}
	var type_hp_cur: Dictionary = {}
	var type_hp_max: Dictionary = {}
	for eid in entity_ids:
		var meta: Dictionary = ecs.get_component(eid, "UnitMetaComponent")
		var hp: Dictionary = ecs.get_component(eid, "HealthComponent")
		var utype: String = meta.get("unit_type", "unknown")
		type_counts[utype] = type_counts.get(utype, 0) + 1
		type_hp_cur[utype] = type_hp_cur.get(utype, 0) + hp.get("current", 0)
		type_hp_max[utype] = type_hp_max.get(utype, 0) + hp.get("max", 1)
	for utype in type_counts:
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lbl := Label.new()
		lbl.text = "%s x%d" % [utype, type_counts[utype]]
		lbl.custom_minimum_size = Vector2(120, 0)
		lbl.add_theme_font_size_override("font_size", 10)
		hbox.add_child(lbl)
		var bar := ProgressBar.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size = Vector2(0, 12)
		bar.value = (float(type_hp_cur[utype]) / float(max(type_hp_max[utype], 1))) * 100.0
		hbox.add_child(bar)
		_multi_summary_container.add_child(hbox)

func _on_action_button_pressed(action: String) -> void:
	emit_signal("command_requested", action, {"unit_ids": selected_entities})
