class_name VictorySystem

# Tick pipeline step: Check win/loss conditions each tick.
# Win:  enemy Construction Yard destroyed (no Structure + ConstructionYard + enemy faction remains)
# Loss: own Construction Yard destroyed
# Draw: both CYs destroyed in the same tick
#
# Reads:  Structure, FactionComponent, ConstructionYard (tag), Health
# Writes: nothing — emits signals consumed by GameLoop / UI

signal game_won(winning_faction: int, tick_count: int)
signal game_lost(losing_faction: int, tick_count: int)
signal game_drawn(tick_count: int)

# Set by GameLoop before first tick.
var player_faction_id: int = 1
var _game_over: bool = false


func tick(ecs: ECS, tick_count: int) -> void:
	if _game_over:
		return

	var own_cy_alive: bool = _faction_has_construction_yard(ecs, player_faction_id)
	var enemy_cy_alive: bool = _any_enemy_has_construction_yard(ecs, player_faction_id)

	if own_cy_alive and enemy_cy_alive:
		return  # Game continues

	_game_over = true

	if not own_cy_alive and not enemy_cy_alive:
		game_drawn.emit(tick_count)
	elif not enemy_cy_alive:
		game_won.emit(player_faction_id, tick_count)
	else:
		game_lost.emit(player_faction_id, tick_count)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _faction_has_construction_yard(ecs: ECS, faction_id: int) -> bool:
	var candidates: Array[int] = ecs.query(["Structure", "ConstructionYard", "FactionComponent"])
	for entity_id: int in candidates:
		var faction: Dictionary = ecs.get_component(entity_id, "FactionComponent")
		if faction.get("faction_id", -1) == faction_id:
			# Must be alive (Health.current > 0) or no Health component (indestructible)
			if not ecs.has_component(entity_id, "Health"):
				return true
			var health: Dictionary = ecs.get_component(entity_id, "Health")
			if health.get("current", 0.0) > 0.0:
				return true
	return false


func _any_enemy_has_construction_yard(ecs: ECS, friendly_faction_id: int) -> bool:
	var candidates: Array[int] = ecs.query(["Structure", "ConstructionYard", "FactionComponent"])
	for entity_id: int in candidates:
		var faction: Dictionary = ecs.get_component(entity_id, "FactionComponent")
		var fid: int = faction.get("faction_id", -1)
		if fid != friendly_faction_id:
			if not ecs.has_component(entity_id, "Health"):
				return true
			var health: Dictionary = ecs.get_component(entity_id, "Health")
			if health.get("current", 0.0) > 0.0:
				return true
	return false


func reset() -> void:
	_game_over = false
