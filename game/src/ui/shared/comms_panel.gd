class_name CommsPanel
extends Control

## Shared team communication log.
## Max 20 entries, color-coded by role.
## Request entries show Accept/Deny buttons when relevant to local_role.

const MAX_ENTRIES: int = 20
const ROLE_COLORS: Dictionary = {
	"commander":     Color(0.3, 0.5, 1.0),
	"quartermaster": Color(1.0, 0.8, 0.0),
	"field_marshal": Color(0.9, 0.2, 0.2),
	"spec_ops":      Color(0.2, 0.9, 0.4),
	"chief_engineer": Color(0.8, 0.5, 0.2),
	"air_marshal":   Color(0.5, 0.8, 1.0),
	"system":        Color(0.7, 0.7, 0.7),
}

var local_role: String = ""

signal request_accepted(request_id: int)
signal request_denied(request_id: int)

var _entries: Array = []
var _scroll: ScrollContainer
var _log_container: VBoxContainer


func _ready() -> void:
	_build_layout()


func _build_layout() -> void:
	name = "CommsPanel"
	custom_minimum_size = Vector2(280, 200)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var header := Label.new()
	header.text = "COMMS"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 12)
	vbox.add_child(header)
	vbox.add_child(HSeparator.new())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	vbox.add_child(_scroll)

	_log_container = VBoxContainer.new()
	_log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_container.add_theme_constant_override("separation", 2)
	_scroll.add_child(_log_container)


func add_message(role: String, message: String, request_id: int = -1) -> void:
	_append_entry({
		"role": role, "message": message,
		"request_id": request_id, "is_request": false,
	})


func add_request(from_role: String, to_role: String, request: Dictionary, request_id: int) -> void:
	var summary := "[→ %s] %s: %s" % [
		to_role.to_upper(),
		request.get("type", "request"),
		request.get("detail", ""),
	]
	_append_entry({
		"role": from_role, "message": summary,
		"request_id": request_id, "is_request": true,
		"to_role": to_role, "request": request,
	})


func _append_entry(entry: Dictionary) -> void:
	if _entries.size() >= MAX_ENTRIES:
		var oldest: Dictionary = _entries.pop_front()
		if oldest.has("node") and is_instance_valid(oldest.node):
			oldest.node.queue_free()

	var node := _create_entry_node(entry)
	entry["node"] = node
	_entries.append(entry)
	_log_container.add_child(node)

	await get_tree().process_frame
	_scroll.scroll_vertical = _scroll.get_v_scroll_bar().max_value


func _create_entry_node(entry: Dictionary) -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var role_str: String = entry.get("role", "system").to_lower()
	var color: Color = ROLE_COLORS.get(role_str, ROLE_COLORS["system"])

	var msg := RichTextLabel.new()
	msg.fit_content = true
	msg.bbcode_enabled = true
	msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg.text = "[color=#%s][b]%s:[/b][/color] %s" % [
		color.to_html(false), role_str.to_upper(), entry.get("message", "")]
	msg.add_theme_font_size_override("normal_font_size", 10)
	container.add_child(msg)

	# Accept/Deny buttons when this request targets our role (or local_role is unset)
	var rid: int = entry.get("request_id", -1)
	if entry.get("is_request", false) and rid >= 0:
		var to_role: String = entry.get("to_role", "")
		if local_role == "" or local_role == to_role:
			container.add_child(_create_accept_deny_row(rid))

	return container


func _create_accept_deny_row(request_id: int) -> HBoxContainer:
	var row := HBoxContainer.new()

	var accept_btn := Button.new()
	accept_btn.text = "Accept"
	accept_btn.focus_mode = Control.FOCUS_NONE
	accept_btn.custom_minimum_size = Vector2(60, 22)
	accept_btn.modulate = Color(0.3, 0.9, 0.3)
	accept_btn.pressed.connect(_on_accept.bind(request_id))
	row.add_child(accept_btn)

	var deny_btn := Button.new()
	deny_btn.text = "Deny"
	deny_btn.focus_mode = Control.FOCUS_NONE
	deny_btn.custom_minimum_size = Vector2(60, 22)
	deny_btn.modulate = Color(0.9, 0.3, 0.3)
	deny_btn.pressed.connect(_on_deny.bind(request_id))
	row.add_child(deny_btn)

	return row


func _on_accept(request_id: int) -> void:
	emit_signal("request_accepted", request_id)
	_resolve_request(request_id, "ACCEPTED")


func _on_deny(request_id: int) -> void:
	emit_signal("request_denied", request_id)
	_resolve_request(request_id, "DENIED")


func _resolve_request(request_id: int, status: String) -> void:
	for entry in _entries:
		if entry.get("request_id", -1) == request_id and is_instance_valid(entry.get("node")):
			var node: Control = entry.node
			for child in node.get_children():
				if child is HBoxContainer:
					child.queue_free()
			var lbl := Label.new()
			lbl.text = status
			lbl.modulate = Color(0.6, 0.9, 0.6) if status == "ACCEPTED" else Color(0.9, 0.4, 0.4)
			lbl.add_theme_font_size_override("font_size", 9)
			node.add_child(lbl)
			break
