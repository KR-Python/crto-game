class_name VictoryScreen
extends CanvasLayer

# Post-game overlay. Shown by GameLoop after VictorySystem emits game_won/game_lost/game_drawn.
# Constructed purely in code — no separate scene file required for Phase 5.

signal play_again_requested()
signal main_menu_requested()

# ── Internal nodes ────────────────────────────────────────────────────────────
var _root_panel: Panel
var _title_label: Label
var _stats_label: Label
var _play_again_btn: Button
var _main_menu_btn: Button


func _ready() -> void:
	_build_ui()
	hide()


func show_victory(stats: Dictionary) -> void:
	_title_label.text = "VICTORY"
	_title_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	_stats_label.text = _format_stats(stats)
	show()


func show_defeat(stats: Dictionary) -> void:
	_title_label.text = "DEFEAT"
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))
	_stats_label.text = _format_stats(stats)
	show()


func show_draw(stats: Dictionary) -> void:
	_title_label.text = "DRAW"
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.1))
	_stats_label.text = _format_stats(stats)
	show()


# ── Private helpers ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	_root_panel = Panel.new()
	_root_panel.set_anchors_preset(Control.PRESET_CENTER)
	_root_panel.custom_minimum_size = Vector2(520, 380)
	_root_panel.offset_left = -260
	_root_panel.offset_top = -190
	_root_panel.offset_right = 260
	_root_panel.offset_bottom = 190
	add_child(_root_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 16)
	_root_panel.add_child(vbox)

	# Margin container for padding
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	vbox.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 16)
	margin.add_child(inner)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 64)
	inner.add_child(_title_label)

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_stats_label.add_theme_font_size_override("font_size", 18)
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(_stats_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	inner.add_child(btn_row)

	_play_again_btn = Button.new()
	_play_again_btn.text = "Play Again"
	_play_again_btn.custom_minimum_size = Vector2(140, 44)
	_play_again_btn.pressed.connect(_on_play_again_pressed)
	btn_row.add_child(_play_again_btn)

	_main_menu_btn = Button.new()
	_main_menu_btn.text = "Main Menu"
	_main_menu_btn.custom_minimum_size = Vector2(140, 44)
	_main_menu_btn.pressed.connect(_on_main_menu_pressed)
	btn_row.add_child(_main_menu_btn)


func _format_stats(stats: Dictionary) -> String:
	var lines: PackedStringArray = []

	var duration_s: float = stats.get("duration_seconds", 0.0)
	var minutes: int = int(duration_s) / 60
	var seconds: int = int(duration_s) % 60
	lines.append("Game Duration:       %d:%02d" % [minutes, seconds])

	# Per-faction stats (show player faction first if available)
	var units_lost: Dictionary = stats.get("units_lost", {})
	if not units_lost.is_empty():
		var parts: PackedStringArray = []
		for faction_id: int in units_lost:
			parts.append("Faction %d: %d" % [faction_id, units_lost[faction_id]])
		lines.append("Units Lost:          " + ", ".join(parts))

	var structures_built: Dictionary = stats.get("structures_built", {})
	if not structures_built.is_empty():
		var parts: PackedStringArray = []
		for faction_id: int in structures_built:
			parts.append("Faction %d: %d" % [faction_id, structures_built[faction_id]])
		lines.append("Structures Built:    " + ", ".join(parts))

	lines.append("Superweapons Fired:  %d" % stats.get("superweapons_fired", 0))

	return "\n".join(lines)


func _on_play_again_pressed() -> void:
	play_again_requested.emit()


func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()
