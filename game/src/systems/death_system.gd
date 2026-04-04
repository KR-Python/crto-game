class_name DeathSystem

# Tick pipeline step 10: Remove dead entities and emit death signals.
#
# Reads: Health (current <= 0), Position, FactionComponent
# Writes: Entity removal
# Emits: unit_died(entity_id, faction_id, position)

signal unit_died(entity_id: int, faction_id: int, position: Vector2)


func tick(ecs: ECS, tick_count: int) -> void:
	var health_entities: Array = ecs.query(["Health"])
	var to_remove: Array = []

	for entity_id in health_entities:
		var health: Dictionary = ecs.get_component(entity_id, "Health")
		if health.get("current", 1.0) <= 0.0:
			to_remove.append(entity_id)

	for entity_id in to_remove:
		var faction_id: int = -1
		if ecs.has_component(entity_id, "FactionComponent"):
			var faction: Dictionary = ecs.get_component(entity_id, "FactionComponent")
			faction_id = faction.get("faction_id", -1)

		var pos := Vector2.ZERO
		if ecs.has_component(entity_id, "Position"):
			var pos_data: Dictionary = ecs.get_component(entity_id, "Position")
			pos = Vector2(pos_data.get("x", 0.0), pos_data.get("y", 0.0))

		ecs.destroy_entity(entity_id)
		unit_died.emit(entity_id, faction_id, pos)

		# TODO: XP/resource refund hooks (Phase 2+)
		_on_unit_death_hooks(entity_id, faction_id, pos)


func _on_unit_death_hooks(_entity_id: int, _faction_id: int, _position: Vector2) -> void:
	# Stub for Phase 2+: XP grants, resource refunds, kill tracking
	pass
