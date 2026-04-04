class_name PostGameScreen
extends CanvasLayer

# Full post-game screen: VICTORY/DEFEAT header, per-role stat highlights,
# mastery progress bars (animated level-up), team history blurb, and action buttons.
# Supersedes VictoryScreen for games with role-tracking enabled.

signal play_again_requested()
signal change_roles_requested()
signal main_menu_requested()

const _LEVEL_UP_ANIM_DURATION := 0.6  # seconds

# ── Internal nodes ────────────────────────────────────────────────────────────
var _root_panel: Panel
var _title_label: Label
var _duration_label: Label
var _stats_container: VBoxContainer
var _mastery_container: VBoxContainer
var _team_blurb_label: Label
var _play_again_btn: Button
var _change_roles_btn: Button
var _main_menu_btn: Button

# { role -> ProgressBar } for mastery bars
var _mastery_bars: Dictionary = {}


func _ready() -> void:
	_build_ui()
	hide()


# ── Public API ────────────────────────────────────────────────────────────────

func show_results(
		result: String,
		game_stats: Dictionary,
		mastery_updates: Dictionary) -> void:
	# result: "victory" | "defeat" | "draw"
	_apply_result_header(result)
	_populate_duration(game_stats)
	_populate_role_highlights(game_stats)
	_populate_mastery_bars(mastery_updates)
	_populate_team_blurb(game_stats)
	show()


# ── Private: UI construction ──────────────────────────────────────────────────

func _build_ui() -> void:
	_root_panel = Panel.new()
	_root_panel.set_anchors_preset(Control.PRESET_CENTER)
	_root_panel.custom_minimum_size = Vector2(600, 580)
	_root_panel.offset_left  = -300
	_root_panel.offset_top   = -290
	_root_panel.offset_right  = 300
	_root_panel.offset_bottom = 290
	add_child(_root_panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root_panel.add_child(scroll)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 64)
	vbox.add_child(_title_label)

	# Duration
	_duration_label = Label.new()
	_duration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_duration_label.add_theme_font_size_override("font_size", 16)
	_duration_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(_duration_label)

	vbox.add_child(_make_separator())

	# Role stat highlights
	var stats_header := _make_section_label("Role Highlights")
	vbox.add_child(stats_header)

	_stats_container = VBoxContainer.new()
	_stats_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_stats_container)

	vbox.add_child(_make_separator())

	# Mastery progress
	var mastery_header := _make_section_label("Mastery Progress")
	vbox.add_child(mastery_header)

	_mastery_container = VBoxContainer.new()
	_mastery_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_mastery_container)

	vbox.add_child(_make_separator())

	# Team history blurb
	_team_blurb_label = Label.new()
	_team_blurb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_team_blurb_label.add_theme_font_size_override("font_size", 15)
	_team_blurb_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	_team_blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_team_blurb_label)

	# Action buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	_play_again_btn = _make_button("Play Again", _on_play_again_pressed)
	btn_row.add_child(_play_again_btn)

	_change_roles_btn = _make_button("Change Roles", _on_change_roles_pressed)
	btn_row.add_child(_change_roles_btn)

	_main_menu_btn = _make_button("Main Menu", _on_main_menu_pressed)
	btn_row.add_child(_main_menu_btn)


# ── Private: data population ──────────────────────────────────────────────────

func _apply_result_header(result: String) -> void:
	match result.to_lower():
		"victory":
			_title_label.text = "VICTORY"
			_title_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		"defeat":
			_title_label.text = "DEFEAT"
			_title_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))
		_:
			_title_label.text = "DRAW"
			_title_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.1))


func _populate_duration(game_stats: Dictionary) -> void:
	var ticks: int = game_stats.get("duration_ticks", 0) as int
	var seconds: int = ticks / 60  # Assumes 60 ticks/s; caller may pass duration_seconds instead.
	if game_stats.has("duration_seconds"):
		seconds = int(game_stats["duration_seconds"])
	var minutes: int = seconds / 60
	var secs: int    = seconds % 60
	_duration_label.text = "Duration: %d:%02d" % [minutes, secs]


func _populate_role_highlights(game_stats: Dictionary) -> void:
	# Clear previous children.
	for child in _stats_container.get_children():
		child.queue_free()

	var role_stats: Dictionary = game_stats.get("role_stats", {}) as Dictionary

	# Build human-readable highlights per role.
	var highlights: Array[String] = []
	highlights.append_array(_highlights_commander(role_stats.get("commander", {})))
	highlights.append_array(_highlights_quartermaster(role_stats.get("quartermaster", {})))
	highlights.append_array(_highlights_field_marshal(role_stats.get("field_marshal", {})))
	highlights.append_array(_highlights_spec_ops(role_stats.get("spec_ops", {})))
	highlights.append_array(_highlights_chief_engineer(role_stats.get("chief_engineer", {})))
	highlights.append_array(_highlights_air_marshal(role_stats.get("air_marshal", {})))

	for line: String in highlights:
		var lbl := Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 15)
		_stats_container.add_child(lbl)


func _populate_mastery_bars(mastery_updates: Dictionary) -> void:
	# mastery_updates: { role -> { old_level, new_level, title, progress_pct } }
	for child in _mastery_container.get_children():
		child.queue_free()
	_mastery_bars.clear()

	for role: String in mastery_updates:
		var info: Dictionary = mastery_updates[role] as Dictionary
		var new_level: int  = info.get("new_level", 1) as int
		var title: String   = info.get("title", "") as String
		var pct: float      = clampf(info.get("progress_pct", 0.0) as float, 0.0, 1.0)
		var leveled_up: bool = (info.get("old_level", new_level) as int) < new_level

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_mastery_container.add_child(row)

		var role_lbl := Label.new()
		role_lbl.text = "%s (Lv.%d — %s)" % [_pretty_role(role), new_level, title]
		role_lbl.custom_minimum_size = Vector2(280, 0)
		role_lbl.add_theme_font_size_override("font_size", 14)
		if leveled_up:
			role_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		row.add_child(role_lbl)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(180, 22)
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.show_percentage = false
		if leveled_up:
			bar.value = 0.0  # Animate from 0 to pct.
			_mastery_bars[role] = bar
			_animate_bar(bar, pct)
		else:
			bar.value = pct
		row.add_child(bar)


func _populate_team_blurb(game_stats: Dictionary) -> void:
	var blurb: String = game_stats.get("team_history_blurb", "") as String
	_team_blurb_label.text = blurb
	_team_blurb_label.visible = not blurb.is_empty()


# ── Private: role highlight builders ─────────────────────────────────────────

func _highlights_commander(s: Dictionary) -> Array[String]:
	if s.is_empty():
		return []
	return ["  Commander — %d structures placed, %d techs researched, %d expansions" % [
		s.get("structures_placed", 0),
		s.get("tech_researched", 0),
		s.get("expansions_built", 0),
	]]


func _highlights_quartermaster(s: Dictionary) -> Array[String]:
	if s.is_empty():
		return []
	var efficiency: int = s.get("factory_efficiency_pct", 0) as int
	return ["  Quartermaster — %d units produced, %d%% factory efficiency, %d ore" % [
		s.get("units_produced", 0),
		efficiency,
		s.get("ore_harvested", 0),
	]]


func _highlights_field_marshal(s: Dictionary) -> Array[String]:
	if s.is_empty():
		return []
	return ["  Field Marshal — %d kills, %d units lost, %d/%d battles" % [
		s.get("kills", 0),
		s.get("units_lost", 0),
		s.get("battles_won", 0),
		s.get("battles_won", 0) + s.get("battles_lost", 0),
	]]


func _highlights_spec_ops(s: Dictionary) -> Array[String]:
	if s.is_empty():
		return []
	return ["  Spec Ops — %d sabotages, %d structures destroyed, %d intel reports" % [
		s.get("sabotages_completed", 0),
		s.get("structures_destroyed", 0),
		s.get("intel_reports", 0),
	]]


func _highlights_chief_engineer(s: Dictionary) -> Array[String]:
	if s.is_empty():
		return []
	return ["  Chief Engineer — %d repaired, %d walls, %d mines triggered" % [
		s.get("structures_repaired", 0),
		s.get("walls_placed", 0),
		s.get("mines_triggered", 0),
	]]


func _highlights_air_marshal(s: Dictionary) -> Array[String]:
	if s.is_empty():
		return []
	return ["  Air Marshal — %d bombing runs, %d paradrops, %d air kills" % [
		s.get("bombing_runs", 0),
		s.get("paradrops", 0),
		s.get("air_kills", 0),
	]]


# ── Private: UI helpers ───────────────────────────────────────────────────────

func _make_separator() -> HSeparator:
	return HSeparator.new()


func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	return lbl


func _make_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 44)
	btn.pressed.connect(callback)
	return btn


func _pretty_role(role: String) -> String:
	return role.replace("_", " ").capitalize()


func _animate_bar(bar: ProgressBar, target: float) -> void:
	var tween := create_tween()
	tween.tween_property(bar, "value", target, _LEVEL_UP_ANIM_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


# ── Button callbacks ──────────────────────────────────────────────────────────

func _on_play_again_pressed() -> void:
	play_again_requested.emit()


func _on_change_roles_pressed() -> void:
	change_roles_requested.emit()


func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()
