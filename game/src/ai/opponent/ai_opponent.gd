class_name AIOpponent
extends Node
## Base AI opponent controller.
## Emits commands to the CommandQueue — same interface as a human player.
## Subclass this to implement specific AI strategies.

var faction_id: int
var role: String = "ai_opponent"
var ecs: ECS
var command_queue: CommandQueue
var economy_system: EconomySystem
var data_loader: DataLoader

# Current strategy state
var current_phase: String = "early"  # early | mid | late
var build_order_index: int = 0
var army_entities: Array[int] = []
var attack_target: Vector2 = Vector2.ZERO  # enemy base position
var _attack_triggered: bool = false


func initialize(faction: int, enemy_spawn: Vector2) -> void:
	faction_id = faction
	attack_target = enemy_spawn


func tick(ecs_ref: ECS, tick_count: int) -> void:
	ecs = ecs_ref
	_update_army_list()
	_run_build_order(tick_count)
	_run_attack_logic(tick_count)


func _run_build_order(_tick_count: int) -> void:
	pass


func _run_attack_logic(_tick_count: int) -> void:
	pass


func _emit_command(action: String, params: Dictionary) -> void:
	command_queue.enqueue({
		"player_id": -1,  # AI player
		"role": role,
		"tick": 0,  # immediate
		"action": action,
		"params": params,
	})


func _update_army_list() -> void:
	## Rebuild army entity list from ECS — all mobile combat units owned by this faction.
	army_entities.clear()
	if ecs == null:
		return
	var entities: Array = ecs.get_entities_with_components(["FactionComponent", "MoveSpeed", "Weapon"])
	for entity_id in entities:
		var faction_comp: Dictionary = ecs.get_component(entity_id, "FactionComponent")
		if faction_comp.get("faction_id") == faction_id:
			army_entities.append(entity_id)


func _get_base_position() -> Vector2:
	## Find our construction yard / main base position.
	if ecs == null:
		return Vector2.ZERO
	var structures: Array = ecs.get_entities_with_components(["FactionComponent", "Structure"])
	for entity_id in structures:
		var faction_comp: Dictionary = ecs.get_component(entity_id, "FactionComponent")
		if faction_comp.get("faction_id") == faction_id:
			var pos: Dictionary = ecs.get_component(entity_id, "Position")
			if pos:
				return Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
	return Vector2.ZERO


func _get_production_buildings() -> Array[int]:
	## Return entity IDs of production structures owned by this faction.
	var result: Array[int] = []
	if ecs == null:
		return result
	var factories: Array = ecs.get_entities_with_components(["FactionComponent", "ProductionQueue"])
	for entity_id in factories:
		var faction_comp: Dictionary = ecs.get_component(entity_id, "FactionComponent")
		if faction_comp.get("faction_id") == faction_id:
			result.append(entity_id)
	return result
