# TutorialSystem: step-based tutorial engine with condition checking.
# Loaded with a tutorial definition (YAML-sourced dict); drives step progression
# by inspecting ECS state each tick. Emits signals consumed by TutorialOverlay.
class_name TutorialSystem
extends Node

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var active: bool = false
var current_step: int = 0
var steps: Array = []

var _step_completed: bool = false
var _tutorial_start_tick: int = 0

# Tracks counts used for condition checks so we can detect deltas.
var _prev_structure_count: int = 0
var _prev_enemy_count: int = 0
var _units_moved: Dictionary = {}   # entity_id -> bool
var _attack_move_issued: bool = false
var _request_sent: bool = false
var _palette_opened: bool = false

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal step_started(step: Dictionary)
signal step_completed(step_index: int)
signal tutorial_finished()
signal hint_shown(text: String, target_ui: String)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Load tutorial steps from a pre-parsed data dictionary.
## `data_loader` is expected to expose `get_tutorial(id)` returning a Dictionary
## with a "steps" Array matching the tutorial YAML schema.
func load_tutorial(tutorial_id: String, data_loader) -> void:
	var data: Dictionary = data_loader.get_tutorial(tutorial_id)
	if data.is_empty():
		push_error("TutorialSystem: tutorial not found: %s" % tutorial_id)
		return

	steps = data.get("steps", [])
	if steps.is_empty():
		push_warning("TutorialSystem: tutorial '%s' has no steps" % tutorial_id)
		return

	current_step = 0
	active = true
	_step_completed = false
	emit_signal("step_started", steps[current_step])


## Called each game tick from the game loop.
func tick(ecs: ECS, tick_count: int) -> void:
	if not active or steps.is_empty():
		return
	if _step_completed:
		return
	_check_current_step(ecs, tick_count)


## Called by UI when the player clicks "Next" (manual completion).
func advance_step() -> void:
	if not active:
		return
	_complete_current_step()


# ---------------------------------------------------------------------------
# External event hooks — called by input/UI systems
# ---------------------------------------------------------------------------

func notify_attack_move_issued() -> void:
	_attack_move_issued = true

func notify_request_sent() -> void:
	_request_sent = true

func notify_palette_opened() -> void:
	_palette_opened = true


# ---------------------------------------------------------------------------
# Internal: step condition checking
# ---------------------------------------------------------------------------

func _check_current_step(ecs: ECS, tick_count: int) -> void:
	var step: Dictionary = steps[current_step]
	match step.get("complete_when", ""):
		"structure_placed":
			_check_structure_placed(step, ecs)
		"unit_moved":
			_check_unit_moved(step, ecs)
		"unit_selected":
			_check_unit_selected(step, ecs)
		"all_units_selected":
			_check_all_units_selected(step, ecs)
		"attack_move_issued":
			_check_attack_move(step, ecs)
		"request_sent":
			_check_request_sent(step, ecs)
		"enemy_defeated":
			_check_enemy_defeated(step, ecs)
		"resources_collected":
			_check_resources(step, ecs)
		"time_elapsed":
			_check_time(step, tick_count)
		"palette_opened":
			_check_palette_opened(step, ecs)
		"manual":
			pass  # Player must click "Next" — advance_step() handles this.


func _check_structure_placed(step: Dictionary, ecs: ECS) -> void:
	var required: String = step.get("require_structure", "")
	if required.is_empty():
		# Any new structure satisfies the condition.
		var count: int = _count_player_structures(ecs)
		if count > _prev_structure_count:
			_prev_structure_count = count
			_complete_current_step()
		return

	# Check if a structure of the required type exists.
	var entities: Array = ecs.query_with_component("StructureComponent")
	for entity_id in entities:
		var sc = ecs.get_component(entity_id, "StructureComponent")
		if sc == null:
			continue
		if sc.structure_type == required and sc.owner_team == "player":
			_complete_current_step()
			return


func _check_unit_moved(step: Dictionary, ecs: ECS) -> void:
	var entities: Array = ecs.query_with_component("MovementComponent")
	for entity_id in entities:
		var mc = ecs.get_component(entity_id, "MovementComponent")
		if mc == null:
			continue
		if mc.owner_team != "player":
			continue
		# A unit with a reached-destination flag satisfies the condition.
		if mc.has_reached_destination and not _units_moved.has(entity_id):
			_units_moved[entity_id] = true
			_complete_current_step()
			return


func _check_unit_selected(step: Dictionary, ecs: ECS) -> void:
	var entities: Array = ecs.query_with_component("SelectionComponent")
	for entity_id in entities:
		var sel = ecs.get_component(entity_id, "SelectionComponent")
		if sel == null:
			continue
		if sel.is_selected and sel.owner_team == "player":
			_complete_current_step()
			return


func _check_all_units_selected(step: Dictionary, ecs: ECS) -> void:
	var all_entities: Array = ecs.query_with_component("SelectionComponent")
	var player_units: int = 0
	var selected_units: int = 0
	for entity_id in all_entities:
		var sel = ecs.get_component(entity_id, "SelectionComponent")
		if sel == null:
			continue
		if sel.owner_team != "player":
			continue
		player_units += 1
		if sel.is_selected:
			selected_units += 1
	if player_units > 0 and selected_units == player_units:
		_complete_current_step()


func _check_attack_move(step: Dictionary, ecs: ECS) -> void:
	if _attack_move_issued:
		_complete_current_step()


func _check_request_sent(step: Dictionary, ecs: ECS) -> void:
	if _request_sent:
		_complete_current_step()


func _check_enemy_defeated(step: Dictionary, ecs: ECS) -> void:
	# Counts living enemy entities; detects when any enemy is destroyed.
	var entities: Array = ecs.query_with_component("HealthComponent")
	var current_enemy_count: int = 0
	for entity_id in entities:
		var hc = ecs.get_component(entity_id, "HealthComponent")
		var tc = ecs.get_component(entity_id, "TeamComponent")
		if hc == null or tc == null:
			continue
		if tc.team == "enemy" and hc.current_hp > 0:
			current_enemy_count += 1

	if _prev_enemy_count > 0 and current_enemy_count < _prev_enemy_count:
		_complete_current_step()
	_prev_enemy_count = current_enemy_count


func _check_resources(step: Dictionary, ecs: ECS) -> void:
	var required: int = step.get("amount", 100)
	var rc = ecs.get_singleton("ResourceState")
	if rc == null:
		return
	if rc.primary_resources >= required:
		_complete_current_step()


func _check_time(step: Dictionary, tick_count: int) -> void:
	var duration: int = step.get("duration_ticks", 300)
	if tick_count - _tutorial_start_tick >= duration:
		_complete_current_step()


func _check_palette_opened(step: Dictionary, ecs: ECS) -> void:
	if _palette_opened:
		_complete_current_step()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _count_player_structures(ecs: ECS) -> int:
	var entities: Array = ecs.query_with_component("StructureComponent")
	var count: int = 0
	for entity_id in entities:
		var sc = ecs.get_component(entity_id, "StructureComponent")
		if sc != null and sc.owner_team == "player":
			count += 1
	return count


func _complete_current_step() -> void:
	if _step_completed:
		return
	_step_completed = true

	# Fire hint if present.
	var step: Dictionary = steps[current_step]
	var hint: String = step.get("hint", "")
	var highlight: String = step.get("highlight_element", "")
	if not hint.is_empty():
		emit_signal("hint_shown", hint, highlight)

	emit_signal("step_completed", current_step)

	# Advance after a brief delay (handled by the overlay / caller).
	current_step += 1
	_step_completed = false
	_attack_move_issued = false
	_request_sent = false
	_palette_opened = false

	if current_step >= steps.size():
		active = false
		emit_signal("tutorial_finished")
	else:
		# Fire any trigger event attached to the new step.
		var next_step: Dictionary = steps[current_step]
		var trigger: String = next_step.get("trigger_event", "")
		if not trigger.is_empty():
			_dispatch_trigger(trigger)
		emit_signal("step_started", next_step)


func _dispatch_trigger(event_name: String) -> void:
	# Broadcast on the event bus so game systems can react (e.g. spawn enemies).
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").emit_signal(event_name)
	else:
		push_warning("TutorialSystem: EventBus not found, cannot dispatch '%s'" % event_name)
