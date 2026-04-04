class_name ProductionDashboard
extends Control

## Quartermaster's production overview. Updates every 2 ticks via _on_tick().
## Shows all factories, queues, ETAs, idle alerts, and economy rates.

signal cancel_production_requested(factory_id: int, queue_index: int)
signal queue_unit_requested(factory_id: int, unit_type: String)

var production_system: ProductionSystem
var ecs: ECS
var faction_id: int

const MAX_QUEUE_SLOTS: int = 5
const ROLE_COLOR_QM := Color(1.0, 0.8, 0.0, 1.0)

var _income_label: Label
var _spend_label: Label
var _factory_container: VBoxContainer
var _alert_banner: Label


func _ready() -> void:
	_build_layout()


func _build_layout() -> void:
	name = "ProductionDashboard"
	custom_minimum_size = Vector2(320, 480)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var root_vbox := VBoxContainer.new()
	panel.add_child(root_vbox)

	var header := Label.new()
	header.text = "PRODUCTION"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.modulate = ROLE_COLOR_QM
	header.add_theme_font_size_override("font_size", 14)
	root_vbox.add_child(header)

	var econ_row := HBoxContainer.new()
	root_vbox.add_child(econ_row)

	_income_label = Label.new()
	_income_label.text = "Income: —"
	_income_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_income_label.add_theme_font_size_override("font_size", 11)
	econ_row.add_child(_income_label)

	_spend_label = Label.new()
	_spend_label.text = "Spend: —"
	_spend_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_spend_label.add_theme_font_size_override("font_size", 11)
	econ_row.add_child(_spend_label)

	_alert_banner = Label.new()
	_alert_banner.text = "⚠ FACTORY IDLE"
	_alert_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_banner.modulate = Color(1.0, 0.3, 0.1)
	_alert_banner.visible = false
	_alert_banner.add_theme_font_size_override("font_size", 12)
	root_vbox.add_child(_alert_banner)

	root_vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	_factory_container = VBoxContainer.new()
	_factory_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_factory_container)


func _on_tick(tick_count: int) -> void:
	if tick_count % 2 == 0:
		_refresh()


func _refresh() -> void:
	if not production_system or not ecs:
		push_warning("ProductionDashboard: production_system or ecs not set")
		return
	_update_economy_row()
	_rebuild_factory_rows()


func _update_economy_row() -> void:
	var income: int = production_system.get_income_rate(faction_id)
	var spend: int = production_system.get_spend_rate(faction_id)
	_income_label.text = "Income: +%d/s" % income
	_spend_label.text = "Spend: -%d/s" % spend
	_spend_label.modulate = Color(1.0, 0.4, 0.4) if spend > income else Color(1, 1, 1)


func _rebuild_factory_rows() -> void:
	for child in _factory_container.get_children():
		child.queue_free()
	var factories: Array = production_system.get_factories(faction_id)
	var any_idle := false
	for factory in factories:
		_factory_container.add_child(_create_factory_row(factory))
		if factory.get("queue", []).is_empty():
			any_idle = true
	_alert_banner.visible = any_idle


func _create_factory_row(factory: Dictionary) -> Control:
	var factory_id: int = factory.get("entity_id", -1)
	var fname: String = factory.get("name", "Factory")
	var queue: Array = factory.get("queue", [])
	var current_unit: String = factory.get("current_unit", "")
	var progress: float = factory.get("progress", 0.0)
	var eta_ticks: int = factory.get("eta_ticks", 0)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)

	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)

	var name_label := Label.new()
	name_label.text = fname
	name_label.custom_minimum_size = Vector2(90, 0)
	name_label.add_theme_font_size_override("font_size", 11)
	top_row.add_child(name_label)

	if current_unit != "":
		var bar := ProgressBar.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size = Vector2(0, 16)
		bar.value = progress * 100.0
		top_row.add_child(bar)
		var eta_label := Label.new()
		eta_label.text = " ETA:%ds" % eta_ticks
		eta_label.add_theme_font_size_override("font_size", 10)
		top_row.add_child(eta_label)
	else:
		var idle_label := Label.new()
		idle_label.text = "  IDLE"
		idle_label.modulate = Color(1.0, 0.4, 0.2)
		idle_label.add_theme_font_size_override("font_size", 10)
		top_row.add_child(idle_label)

	var queue_row := HBoxContainer.new()
	vbox.add_child(queue_row)
	for slot_idx in range(MAX_QUEUE_SLOTS):
		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(36, 28)
		slot_btn.focus_mode = Control.FOCUS_NONE
		if slot_idx < queue.size():
			var unit_type: String = queue[slot_idx]
			slot_btn.text = _unit_abbrev(unit_type)
			slot_btn.tooltip_text = unit_type
			slot_btn.pressed.connect(_on_queue_slot_pressed.bind(factory_id, slot_idx))
		else:
			slot_btn.text = "—"
			slot_btn.disabled = true
			slot_btn.modulate = Color(0.5, 0.5, 0.5, 0.6)
		queue_row.add_child(slot_btn)

	vbox.add_child(HSeparator.new())
	return vbox


func _on_queue_slot_pressed(factory_id: int, queue_index: int) -> void:
	emit_signal("cancel_production_requested", factory_id, queue_index)


func _unit_abbrev(unit_type: String) -> String:
	var parts := unit_type.split("_")
	if parts.size() > 0:
		return parts[-1].substr(0, 3).to_upper()
	return unit_type.substr(0, 3).to_upper()
