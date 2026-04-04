class_name TechTreePanel
extends Control

## Commander's tech tree browser. Phase 1: flat list grouped by tier.

signal research_requested(tech_id: String)

var data_loader: DataLoader
var faction_id: int
var current_tier: int = 1
var researched_ids: Array[String] = []
var active_research: Dictionary = {}
var _tier_label: Label
var _list_container: VBoxContainer
var _active_bar_container: Control
var _active_label: Label
var _active_progress: ProgressBar

func _ready() -> void:
	_build_layout()
	if data_loader:
		refresh()

func _build_layout() -> void:
	name = "TechTreePanel"
	custom_minimum_size = Vector2(240, 420)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "RESEARCH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	_active_bar_container = VBoxContainer.new()
	_active_bar_container.visible = false
	vbox.add_child(_active_bar_container)
	_active_label = Label.new()
	_active_label.text = "Researching: —"
	_active_label.add_theme_font_size_override("font_size", 11)
	_active_bar_container.add_child(_active_label)
	_active_progress = ProgressBar.new()
	_active_progress.custom_minimum_size = Vector2(0, 14)
	_active_bar_container.add_child(_active_progress)
	vbox.add_child(HSeparator.new())
	_tier_label = Label.new()
	_tier_label.text = "Tech Tier: 1"
	_tier_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_tier_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_container)

## Full refresh — call when researched_ids, active_research, or tier changes.
func refresh() -> void:
	_tier_label.text = "Tech Tier: %d" % current_tier
	_rebuild_list()
	_update_active_bar()

## Lightweight tick update — just updates progress bar.
func tick_update(ticks_remaining: int, _total: int) -> void:
	if active_research.is_empty():
		return
	active_research["ticks_remaining"] = ticks_remaining
	_update_active_bar()

func _rebuild_list() -> void:
	for child in _list_container.get_children():
		child.queue_free()
	if not data_loader:
		push_warning("TechTreePanel: data_loader not set")
		return
	var techs: Array = data_loader.get_techs_for_faction(faction_id)
	var by_tier: Dictionary = {}
	for tech in techs:
		var tier: int = tech.get("tier", 1)
		if tier not in by_tier:
			by_tier[tier] = []
		by_tier[tier].append(tech)
	var keys := by_tier.keys()
	keys.sort()
	for tier in keys:
		var hdr := Label.new()
		hdr.text = "── Tier %d ──" % tier
		hdr.add_theme_font_size_override("font_size", 11)
		hdr.modulate = Color(0.7, 0.9, 1.0)
		_list_container.add_child(hdr)
		for tech in by_tier[tier]:
			_list_container.add_child(_create_tech_row(tech))

func _create_tech_row(tech: Dictionary) -> Button:
	var already_done: bool = tech.id in researched_ids
	var is_active: bool = active_research.get("tech_id", "") == tech.id
	var reqs_met: bool = _tech_requirements_met(tech)
	var busy: bool = not active_research.is_empty() and not is_active
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 48)
	var tag := ""
	if already_done:
		tag = " ✓"; btn.disabled = true; btn.modulate = Color(0.6, 0.6, 0.6)
	elif is_active:
		tag = " [active]"; btn.disabled = true
	elif not reqs_met:
		tag = " [locked]"; btn.disabled = true; btn.modulate = Color(0.5, 0.5, 0.5)
	elif busy:
		btn.disabled = true
	btn.text = "%s%s\n%d ore  %d gems  |  %ds\n%s" % [
		tech.get("name", tech.id), tag,
		tech.get("cost_ore", 0), tech.get("cost_gems", 0),
		tech.get("research_ticks", 0), tech.get("effect_description", "")]
	if not btn.disabled:
		btn.pressed.connect(_on_research_pressed.bind(tech.id))
	return btn

func _tech_requirements_met(tech: Dictionary) -> bool:
	for req in tech.get("requirements", []):
		if req not in researched_ids:
			return false
	return true

func _update_active_bar() -> void:
	if active_research.is_empty():
		_active_bar_container.visible = false
		return
	_active_bar_container.visible = true
	var remaining: int = active_research.get("ticks_remaining", 0)
	var total: int = active_research.get("ticks_total", 1)
	_active_label.text = "Researching: %s  |  ETA: %ds" % [active_research.get("tech_id", ""), remaining]
	_active_progress.value = (1.0 - float(remaining) / float(max(total, 1))) * 100.0

func _on_research_pressed(tech_id: String) -> void:
	emit_signal("research_requested", tech_id)
