class_name InputHandler
extends Node

## Central input router.  Translates raw Godot input events into typed
## Command dictionaries (matching CommandProtocol) and emits them via
## command_issued so the caller can forward them to the simulation.
##
## One InputHandler lives per local player.  Set active_role to match the
## player's current role before the game starts.

signal command_issued(command: Dictionary)

# ------------------------------------------------------------------
# Public state — set by the game session before first frame
# ------------------------------------------------------------------

## The role this local player is currently playing.
var active_role: String = "field_marshal"

## ECS reference — used for entity queries.
var simulation  # ECS

## Camera — used to convert screen positions to world positions.
var camera: CameraController

## The player's own faction id — used to filter selectable entities.
var player_faction_id: int = 0

## Player id — embedded in every issued command.
var player_id: int = 0

# ------------------------------------------------------------------
# Selection state (Field Marshal)
# ------------------------------------------------------------------

var selected_entities: Array[int] = []
var _selection_box: SelectionBox

# Commander placement state
var _placement_ghost_active: bool = false
var _placement_structure_type: String = ""

# Double-click detection
const DOUBLE_CLICK_TIME_SEC: float = 0.35
var _last_lmb_time: float = -1.0
var _last_lmb_pos: Vector2 = Vector2.ZERO
const DOUBLE_CLICK_RADIUS: float = 8.0

# ------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------

func _ready() -> void:
	_selection_box = SelectionBox.new()
	_selection_box.camera = camera
	add_child(_selection_box)
	_selection_box.selection_complete.connect(_on_selection_complete)


# ------------------------------------------------------------------
# Input dispatch
# ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	match active_role:
		"field_marshal":
			_handle_field_marshal_input(event)
		"commander":
			_handle_commander_input(event)
		"quartermaster":
			_handle_quartermaster_input(event)


# ------------------------------------------------------------------
# Field Marshal input
# ------------------------------------------------------------------

func _handle_field_marshal_input(event: InputEvent) -> void:
	# Selection box handles left-click drag — just pass through.
	# We intercept discrete left clicks for single-unit selection and
	# right-clicks for move/attack commands.

	if not (event is InputEventMouseButton):
		return

	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return

	var world_pos := _screen_to_world(mb.position)

	if mb.button_index == MOUSE_BUTTON_LEFT:
		_handle_fm_left_click(mb, world_pos)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_handle_fm_right_click(world_pos)


func _handle_fm_left_click(event: InputEventMouseButton, world_pos: Vector2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var is_double_click := (
		(now - _last_lmb_time) < DOUBLE_CLICK_TIME_SEC
		and event.position.distance_to(_last_lmb_pos) < DOUBLE_CLICK_RADIUS
	)
	_last_lmb_time = now
	_last_lmb_pos = event.position

	if is_double_click:
		# Select all same-type units currently visible on screen.
		_select_all_same_type_on_screen(world_pos)
		return

	var hit := _get_entity_at_point(world_pos)
	if hit == -1:
		# Clicked empty ground — clear selection (unless Ctrl held).
		if not event.ctrl_pressed:
			selected_entities.clear()
		return

	if event.ctrl_pressed:
		# Ctrl+click: toggle entity in selection.
		if hit in selected_entities:
			selected_entities.erase(hit)
		else:
			selected_entities.append(hit)
	else:
		selected_entities = [hit]


func _handle_fm_right_click(world_pos: Vector2) -> void:
	if selected_entities.is_empty():
		return

	# Determine if target is an enemy entity.
	var target_id := _get_entity_at_point(world_pos)
	var is_enemy := _is_enemy_entity(target_id)

	if target_id != -1 and is_enemy:
		_emit_command({
			"action": "ATTACK_TARGET",
			"unit_ids": selected_entities.duplicate(),
			"target_id": target_id,
		})
	else:
		_emit_command({
			"action": "MOVE_UNITS",
			"unit_ids": selected_entities.duplicate(),
			"destination": {"x": world_pos.x, "y": world_pos.y},
		})


## Called when SelectionBox emits selection_complete.
func _on_selection_complete(world_rect: Rect2) -> void:
	if active_role != "field_marshal":
		return
	var in_rect := _get_entities_in_rect(world_rect)
	if in_rect.is_empty():
		return
	selected_entities = in_rect


func _select_all_same_type_on_screen(world_pos: Vector2) -> void:
	# Identify the unit type at the click position, then select all
	# same-type units within the camera viewport.
	if simulation == null:
		return
	var reference_id := _get_entity_at_point(world_pos)
	if reference_id == -1:
		return
	# We rely on simulation having a helper to query same-type screen entities.
	# This is a placeholder call — the simulation layer exposes this.
	if simulation.has_method("get_same_type_entities_on_screen"):
		var same_type: Array[int] = simulation.get_same_type_entities_on_screen(
			reference_id, camera, player_faction_id
		)
		if not same_type.is_empty():
			selected_entities = same_type


# ------------------------------------------------------------------
# Commander input
# ------------------------------------------------------------------

func _handle_commander_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return

	var world_pos := _screen_to_world(mb.position)

	if mb.button_index == MOUSE_BUTTON_LEFT:
		if _placement_ghost_active:
			# Confirm structure placement.
			_emit_command({
				"action": "PLACE_STRUCTURE",
				"structure_type": _placement_structure_type,
				"position": {"x": world_pos.x, "y": world_pos.y},
			})
			_placement_ghost_active = false
			_placement_structure_type = ""
		# Else: clicks on palette items are handled by the palette UI.

	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		# Cancel active placement ghost.
		if _placement_ghost_active:
			_placement_ghost_active = false
			_placement_structure_type = ""


## Called by the structure palette UI when the player picks a building to place.
func begin_structure_placement(structure_type: String) -> void:
	_placement_ghost_active = true
	_placement_structure_type = structure_type


# ------------------------------------------------------------------
# Quartermaster input
# ------------------------------------------------------------------

func _handle_quartermaster_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			# Left-click on a production building opens the production panel.
			# The actual panel open is driven by the QM UI; we just surface the
			# entity id so the panel knows which factory was clicked.
			var world_pos := _screen_to_world(mb.position)
			var hit := _get_entity_at_point(world_pos)
			if hit != -1 and _is_production_building(hit):
				emit_signal("command_issued", {
					"action": "_UI_OPEN_PRODUCTION_PANEL",
					"factory_id": hit,
				})

	elif event is InputEventKey and event.pressed:
		_handle_qm_key(event as InputEventKey)


func _handle_qm_key(event: InputEventKey) -> void:
	# Number keys 1–9 trigger production shortcuts when a factory is focused.
	# The active factory id should be set by the production panel UI.
	# We emit a named event so the panel can react.
	var key := event.keycode
	if key >= KEY_1 and key <= KEY_9:
		var slot := key - KEY_1  # 0-indexed
		emit_signal("command_issued", {
			"action": "_UI_PRODUCTION_SHORTCUT",
			"slot": slot,
		})


# ------------------------------------------------------------------
# Entity query helpers
# ------------------------------------------------------------------

## Return all FM-controllable entity IDs inside the given world-space Rect2.
func _get_entities_in_rect(world_rect: Rect2) -> Array[int]:
	if simulation == null:
		return []
	# Simulation exposes a generic spatial query; we filter by ownership.
	var all_in_rect: Array[int] = simulation.query_entities_in_rect(world_rect)
	var owned: Array[int] = []
	for eid in all_in_rect:
		if _entity_is_fm_controlled(eid):
			owned.append(eid)
	return owned


## Return the nearest entity within radius of world_pos, or -1 if none.
func _get_entity_at_point(world_pos: Vector2, radius: float = 16.0) -> int:
	if simulation == null:
		return -1
	var candidates: Array[int] = simulation.query_entities_in_rect(
		Rect2(world_pos - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
	)
	if candidates.is_empty():
		return -1
	var closest_id: int = -1
	var closest_dist: float = radius + 1.0
	for eid in candidates:
		var pos: Vector2 = simulation.get_entity_position(eid)
		var d: float = world_pos.distance_to(pos)
		if d < closest_dist:
			closest_dist = d
			closest_id = eid
	return closest_id


# ------------------------------------------------------------------
# Internal helpers
# ------------------------------------------------------------------

func _emit_command(params: Dictionary) -> void:
	params["player_id"] = player_id
	params["role"] = active_role
	command_issued.emit(params)


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	if camera != null:
		return camera.screen_to_world(screen_pos)
	return screen_pos


func _entity_is_fm_controlled(entity_id: int) -> bool:
	if simulation == null:
		return false
	return simulation.entity_has_component(entity_id, "FieldMarshalControlled")


func _is_enemy_entity(entity_id: int) -> bool:
	if entity_id == -1 or simulation == null:
		return false
	var faction: int = simulation.get_entity_faction(entity_id)
	return faction != player_faction_id and faction != -1


func _is_production_building(entity_id: int) -> bool:
	if simulation == null:
		return false
	return simulation.entity_has_component(entity_id, "ProductionQueue")
