class_name TestIntegration
extends RefCounted

## Integration test — 300-tick headless mini-game.

const TEST_TICKS: int = 300
const UNITS_PER_SIDE: int = 5


static func run() -> Dictionary:
	var results := {"passed": true, "errors": [], "ticks_run": 0, "deaths": 0}

	var map_data := {
		"dimensions": {"width": 32, "height": 32},
		"terrain": {"base_type": "grass"},
		"spawn_points": {
			"team_1": {"x": 5.0, "y": 16.0, "starting_units": []},
			"team_2": {"x": 27.0, "y": 16.0, "starting_units": []},
		},
		"resources": [],
		"expansions": [],
	}

	var sim := Simulation.new()
	var game_map := GameMap.new()
	game_map.load_from_data(map_data)
	sim.initialize(game_map, {"mode": "skirmish", "player_faction": 1, "player_count": 2})

	var death_count: int = 0
	sim.death_system.unit_died.connect(
		func(_eid: int, _fid: int, _pos: Vector2) -> void:
			death_count += 1
	)

	# Spawn 5 AEGIS vs 5 FORGE
	for i in range(UNITS_PER_SIDE):
		var aegis_id: int = sim.ecs.create_entity()
		sim.ecs.add_component(aegis_id, "Position", {"x": 5.0 + float(i), "y": 16.0})
		sim.ecs.add_component(aegis_id, "FactionComponent", {"faction_id": 1})
		sim.ecs.add_component(aegis_id, "Health", {"current": 100.0, "max": 100.0})
		sim.ecs.add_component(aegis_id, "MoveSpeed", {"speed": 3.0})
		sim.ecs.add_component(aegis_id, "Weapon", {
			"damage": 12.0, "range": 5.0, "cooldown": 15, "cooldown_remaining": 0, "damage_type": "kinetic"})
		sim.ecs.add_component(aegis_id, "Attackable", {})
		sim.ecs.add_component(aegis_id, "VisionRange", {"range": 8.0})

		var forge_id: int = sim.ecs.create_entity()
		sim.ecs.add_component(forge_id, "Position", {"x": 27.0 - float(i), "y": 16.0})
		sim.ecs.add_component(forge_id, "FactionComponent", {"faction_id": 2})
		sim.ecs.add_component(forge_id, "Health", {"current": 100.0, "max": 100.0})
		sim.ecs.add_component(forge_id, "MoveSpeed", {"speed": 3.0})
		sim.ecs.add_component(forge_id, "Weapon", {
			"damage": 12.0, "range": 5.0, "cooldown": 15, "cooldown_remaining": 0, "damage_type": "kinetic"})
		sim.ecs.add_component(forge_id, "Attackable", {})
		sim.ecs.add_component(forge_id, "VisionRange", {"range": 8.0})

	# Construction yards for VictorySystem
	for data in [{"x": 2.0, "fid": 1}, {"x": 30.0, "fid": 2}]:
		var cy: int = sim.ecs.create_entity()
		sim.ecs.add_component(cy, "Position", {"x": data["x"], "y": 16.0})
		sim.ecs.add_component(cy, "FactionComponent", {"faction_id": data["fid"]})
		sim.ecs.add_component(cy, "Health", {"current": 1000.0, "max": 1000.0})
		sim.ecs.add_component(cy, "Structure", {"type": "construction_yard"})
		sim.ecs.add_component(cy, "ConstructionYard", {})

	# Run 300 ticks
	for _t in range(TEST_TICKS):
		sim.tick()

	results["ticks_run"] = sim.get_tick_count()
	results["deaths"] = death_count

	if sim.get_tick_count() != TEST_TICKS:
		results["passed"] = false
		results["errors"].append("Expected %d ticks, got %d" % [TEST_TICKS, sim.get_tick_count()])

	# ECS integrity
	for eid in sim.ecs.query(["Health"]):
		if not sim.ecs.is_alive(eid):
			results["passed"] = false
			results["errors"].append("Zombie entity %d" % eid)
			break

	print("Integration test: %d ticks, %d deaths, passed=%s" % [
		results["ticks_run"], results["deaths"], str(results["passed"])])
	return results
