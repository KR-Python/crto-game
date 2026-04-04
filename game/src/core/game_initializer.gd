class_name GameInitializer
extends RefCounted

## Factory that sets up a complete game from configuration.


static func setup_skirmish(map_data: Dictionary, player_faction: int,
		ai_personality: Dictionary, _difficulty: String,
		simulation: Simulation) -> void:

	var game_map := GameMap.new()
	game_map.load_from_data(map_data)

	simulation.initialize(game_map, {
		"mode": "skirmish",
		"player_faction": player_faction,
		"player_count": 2,
	})

	# Spawn starting units per spawn points
	var player_spawn: Dictionary = game_map.get_spawn_data("team_1")
	var enemy_spawn: Dictionary = game_map.get_spawn_data("team_2")
	var enemy_faction: int = 2 if player_faction == 1 else 1

	_spawn_starting_units(simulation, player_spawn, player_faction)
	_spawn_starting_units(simulation, enemy_spawn, enemy_faction)
	game_map.spawn_resource_nodes(simulation.ecs, simulation.entity_factory)

	# AI opponent
	var ai := ReactiveAI.new()
	ai.faction_id = enemy_faction
	ai.base_position = Vector2(enemy_spawn.get("x", 64.0), enemy_spawn.get("y", 48.0))

	if not ai_personality.is_empty():
		PersonalityDriver.new(ai_personality).apply_to_ai(ai)

	simulation.add_ai_opponent(ai)


static func setup_scenario(scenario_data: Dictionary, simulation: Simulation) -> void:
	var game_map := GameMap.new()
	game_map.load_from_data(scenario_data.get("map", {}))

	simulation.initialize(game_map, {
		"mode": "scenario",
		"player_faction": scenario_data.get("player_faction", 1),
		"player_count": scenario_data.get("player_count", 2),
	})

	for unit_data in scenario_data.get("starting_units", []):
		var pos := Vector2(unit_data.get("x", 0.0), unit_data.get("y", 0.0))
		var eid: int = simulation.entity_factory.create_from_definition(
			unit_data.get("type", "aegis_rifleman"), pos)
		if eid >= 0 and unit_data.has("faction"):
			simulation.ecs.add_component(eid, "FactionComponent", {"faction_id": unit_data["faction"]})


static func setup_endless(map_data: Dictionary, simulation: Simulation) -> void:
	var game_map := GameMap.new()
	game_map.load_from_data(map_data)

	simulation.initialize(game_map, {
		"mode": "endless",
		"player_faction": 1,
		"player_count": 1,
	})

	simulation.economy_system.add_income(1, 10000, "primary")
	simulation.economy_system.add_income(1, 5000, "secondary")


static func _spawn_starting_units(simulation: Simulation, spawn_data: Dictionary,
		faction_id: int) -> void:
	var pos := Vector2(spawn_data.get("x", 0.0), spawn_data.get("y", 0.0))
	for unit_entry in spawn_data.get("starting_units", []):
		var unit_type: String = unit_entry.get("type", "aegis_rifleman")
		var count: int = unit_entry.get("count", 1)
		for i in range(count):
			var offset := Vector2(float(i % 5) * 2.0, float(i / 5) * 2.0)
			var eid: int = simulation.entity_factory.create_from_definition(unit_type, pos + offset)
			if eid >= 0:
				simulation.ecs.add_component(eid, "FactionComponent", {"faction_id": faction_id})
