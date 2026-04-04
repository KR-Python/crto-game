class_name ScenarioSystem
extends Node

# Scenario engine — loads pre-scripted scenarios, drives event queues, and
# evaluates objectives each tick.
#
# Reads:  Position, FactionComponent, Health, Structure, UnitTag, UnitType
# Writes: nothing — emits signals consumed by GameLoop / ScenarioHUD

signal objective_completed(objective_id: String, description: String)
signal objective_failed(objective_id: String, description: String)
signal scenario_won()
signal scenario_lost()
signal narrative_message(text: String, speaker: String)

var current_scenario: Dictionary = {}
var objectives: Array = []
var _event_queue: Array = []  # sorted ascending by .tick
var _game_over: bool = false

# Injected by GameLoop — used to resolve faction IDs from string names.
var player_faction_id: int = 1


# ── Public API ────────────────────────────────────────────────────────────────

func load_scenario(scenario_data: Dictionary) -> void:
	current_scenario = scenario_data
	objectives = scenario_data.get("objectives", []).duplicate(true)
	_game_over = false

	# Mark all objectives as active by default.
	for obj: Dictionary in objectives:
		if not obj.has("status"):
			obj["status"] = "active"

	_build_event_queue(scenario_data.get("events", []))


func tick(ecs: ECS, tick_count: int) -> void:
	if _game_over:
		return
	_process_events(tick_count, ecs)
	_check_objectives(tick_count, ecs)


func reset() -> void:
	current_scenario = {}
	objectives = []
	_event_queue = []
	_game_over = false


# ── Event processing ──────────────────────────────────────────────────────────

func _build_event_queue(events: Array) -> void:
	_event_queue = events.duplicate(true)
	# Sort ascending by tick so pop_front() always gives the earliest event.
	_event_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("tick", 0) < b.get("tick", 0)
	)


func _process_events(tick_count: int, ecs: ECS) -> void:
	while _event_queue.size() > 0 and _event_queue[0].get("tick", 0) <= tick_count:
		var event: Dictionary = _event_queue.pop_front()
		_execute_event(event, ecs)


func _execute_event(event: Dictionary, ecs: ECS) -> void:
	match event.get("type", ""):
		"spawn_units":
			_event_spawn_units(event, ecs)
		"narrative":
			var text: String = event.get("text", "")
			var speaker: String = event.get("speaker", "")
			narrative_message.emit(text, speaker)
		"set_objective":
			_activate_objective(event.get("objective_id", ""))
		"enemy_attack":
			_event_enemy_attack(event, ecs)
		_:
			push_warning("ScenarioSystem: unknown event type '%s'" % event.get("type", ""))


func _event_spawn_units(event: Dictionary, ecs: ECS) -> void:
	# Spawn units for the specified faction at position.
	# The actual entity creation is delegated to a SpawnHelper that must be
	# connected externally (GameLoop injects it) via the spawn_units_requested
	# signal.  For now we emit a structured signal so the GameLoop can act.
	var faction: String = event.get("faction", "")
	var units: Array = event.get("units", [])
	var position: Array = event.get("position", [0, 0])
	var tags: Array = event.get("tags", [])

	# Emit narrative companion if present on spawn event.
	var narrative: String = event.get("narrative", "")
	if narrative != "":
		narrative_message.emit(narrative, event.get("speaker", ""))

	# Signal the game loop to spawn the units.
	spawn_units_requested.emit(faction, units, position, tags)


func _event_enemy_attack(event: Dictionary, ecs: ECS) -> void:
	# Scripted attack wave — treat as a spawn at spawn_position directed toward
	# the player base.  Reuse spawn pathway with an "attack" intent tag.
	var composition: Array = event.get("composition", [])
	var spawn_pos: Array = event.get("spawn_position", [0, 0])
	spawn_units_requested.emit("ai", composition, spawn_pos, ["attack_wave"])


# ── Objective management ──────────────────────────────────────────────────────

func _activate_objective(objective_id: String) -> void:
	for obj: Dictionary in objectives:
		if obj.get("id", "") == objective_id:
			obj["status"] = "active"
			return
	push_warning("ScenarioSystem: set_objective for unknown id '%s'" % objective_id)


func _fail_objective(obj: Dictionary) -> void:
	obj["status"] = "failed"
	objective_failed.emit(obj.get("id", ""), obj.get("description", ""))
	_evaluate_game_over()


func _complete_objective(obj: Dictionary) -> void:
	obj["status"] = "completed"
	objective_completed.emit(obj.get("id", ""), obj.get("description", ""))
	_evaluate_game_over()


func _evaluate_game_over() -> void:
	if _game_over:
		return

	var any_failed_primary: bool = false
	var all_primary_done: bool = true

	for obj: Dictionary in objectives:
		if obj.get("status", "") == "active":
			# At least one objective still pending — not over yet.
			return
		if obj.get("primary", false) or obj.get("type", "") == "survive_ticks":
			if obj.get("status", "") == "failed":
				any_failed_primary = true
			elif obj.get("status", "") != "completed":
				all_primary_done = false

	_game_over = true
	if any_failed_primary:
		scenario_lost.emit()
	elif all_primary_done:
		scenario_won.emit()


# ── Objective checkers ────────────────────────────────────────────────────────

func _check_objectives(tick_count: int, ecs: ECS) -> void:
	for obj: Dictionary in objectives:
		if obj.get("status", "") != "active":
			continue
		match obj.get("type", ""):
			"survive_ticks":
				_check_survive(obj, tick_count, ecs)
			"destroy_structure":
				_check_destroy(obj, ecs)
			"escort_unit":
				_check_escort(obj, ecs)
			"hold_position":
				_check_hold(obj, tick_count, ecs)
			"survive":
				_check_survive_base(obj, ecs)
			_:
				push_warning("ScenarioSystem: unknown objective type '%s'" % obj.get("type", ""))


func _check_survive(obj: Dictionary, tick_count: int, ecs: ECS) -> void:
	# Also verify the player's CY is still alive.
	if not _player_base_alive(ecs):
		_fail_objective(obj)
		return
	var required: int = obj.get("duration", obj.get("duration_ticks", 0))
	if tick_count >= required:
		_complete_objective(obj)


func _check_survive_base(obj: Dictionary, ecs: ECS) -> void:
	# Passive check — fails the moment the player's Construction Yard is gone.
	if not _player_base_alive(ecs):
		_fail_objective(obj)


func _check_destroy(obj: Dictionary, ecs: ECS) -> void:
	# Complete when the target structure type no longer exists for any enemy faction.
	var target_type: String = obj.get("target_structure_type", "")
	if target_type == "":
		return

	var candidates: Array[int] = ecs.query(["Structure", "FactionComponent", "UnitType"])
	for entity_id: int in candidates:
		var faction: Dictionary = ecs.get_component(entity_id, "FactionComponent")
		if faction.get("faction_id", -1) == player_faction_id:
			continue  # Skip friendly structures.
		var utype: Dictionary = ecs.get_component(entity_id, "UnitType")
		if utype.get("type_id", "") != target_type:
			continue
		# Target still alive — check health.
		if not ecs.has_component(entity_id, "Health"):
			return  # Indestructible — objective can never be completed this way.
		var health: Dictionary = ecs.get_component(entity_id, "Health")
		if health.get("current", 0.0) > 0.0:
			return  # Still alive.

	# Either no entity matched or all are dead.
	_complete_objective(obj)


func _check_escort(obj: Dictionary, ecs: ECS) -> void:
	# Track convoy units — complete when min_survivors reach destination_zone.
	var tags: Array = obj.get("target_unit_tags", [])
	var dest: Dictionary = obj.get("destination_zone", {})
	var dest_pos: Array = dest.get("position", [0, 0])
	var dest_radius: float = float(dest.get("radius", 10))
	var min_survivors: int = obj.get("min_survivors", 1)

	if tags.is_empty() or dest_pos.is_empty():
		return

	var arrived: int = 0
	var alive: int = 0

	var candidates: Array[int] = ecs.query(["Position", "FactionComponent", "UnitTag"])
	for entity_id: int in candidates:
		var faction: Dictionary = ecs.get_component(entity_id, "FactionComponent")
		if faction.get("faction_id", -1) != player_faction_id:
			continue
		var tag_comp: Dictionary = ecs.get_component(entity_id, "UnitTag")
		var unit_tags: Array = tag_comp.get("tags", [])
		var has_tag: bool = false
		for t: String in tags:
			if unit_tags.has(t):
				has_tag = true
				break
		if not has_tag:
			continue

		# Check if alive.
		if ecs.has_component(entity_id, "Health"):
			var health: Dictionary = ecs.get_component(entity_id, "Health")
			if health.get("current", 0.0) <= 0.0:
				continue  # Dead.
		alive += 1

		# Check if in destination zone.
		var pos: Dictionary = ecs.get_component(entity_id, "Position")
		var dx: float = float(pos.get("x", 0)) - float(dest_pos[0])
		var dy: float = float(pos.get("y", 0)) - float(dest_pos[1])
		if dx * dx + dy * dy <= dest_radius * dest_radius:
			arrived += 1

	if arrived >= min_survivors:
		_complete_objective(obj)
	elif alive < min_survivors:
		# Not enough units left alive to satisfy the requirement.
		_fail_objective(obj)


func _check_hold(obj: Dictionary, tick_count: int, ecs: ECS) -> void:
	var pos: Array = obj.get("position", [0, 0])
	var radius: float = float(obj.get("radius", 8))
	var required_ticks: int = obj.get("duration_ticks", 0)
	var fail_if_enemy: bool = obj.get("fail_if_enemy_present", false)

	# Check for enemy presence in the zone.
	var enemy_in_zone: bool = _faction_units_in_zone(ecs, pos, radius, -1)  # -1 = any enemy

	if fail_if_enemy and enemy_in_zone:
		_fail_objective(obj)
		return

	if tick_count >= required_ticks:
		_complete_objective(obj)


# ── Utility helpers ───────────────────────────────────────────────────────────

func _player_base_alive(ecs: ECS) -> bool:
	var candidates: Array[int] = ecs.query(["Structure", "ConstructionYard", "FactionComponent"])
	for entity_id: int in candidates:
		var faction: Dictionary = ecs.get_component(entity_id, "FactionComponent")
		if faction.get("faction_id", -1) != player_faction_id:
			continue
		if not ecs.has_component(entity_id, "Health"):
			return true
		var health: Dictionary = ecs.get_component(entity_id, "Health")
		if health.get("current", 0.0) > 0.0:
			return true
	return false


func _faction_units_in_zone(ecs: ECS, zone_pos: Array, radius: float, faction_id: int) -> bool:
	# faction_id == -1 means "any enemy faction"
	var candidates: Array[int] = ecs.query(["Position", "FactionComponent"])
	for entity_id: int in candidates:
		var faction: Dictionary = ecs.get_component(entity_id, "FactionComponent")
		var fid: int = faction.get("faction_id", -1)
		if faction_id == -1:
			if fid == player_faction_id:
				continue  # Skip friendlies when looking for enemies.
		else:
			if fid != faction_id:
				continue

		var pos: Dictionary = ecs.get_component(entity_id, "Position")
		var dx: float = float(pos.get("x", 0)) - float(zone_pos[0])
		var dy: float = float(pos.get("y", 0)) - float(zone_pos[1])
		if dx * dx + dy * dy <= radius * radius:
			return true
	return false


# ── Extra signals (for GameLoop integration) ─────────────────────────────────

signal spawn_units_requested(faction: String, units: Array, position: Array, tags: Array)
