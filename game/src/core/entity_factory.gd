class_name EntityFactory
## Creates entities pre-loaded with components.
## Phase 0: test helpers only. YAML-based loading in Phase 1.

var ecs: ECS


func _init(ecs_ref: ECS) -> void:
	ecs = ecs_ref


## Create a basic unit entity for Phase 0 testing.
func create_test_unit(pos: Vector2, faction_id: int = 0) -> int:
	var id := ecs.create_entity()
	ecs.add_component(id, "position", Components.position(pos.x, pos.y))
	ecs.add_component(id, "velocity", Components.velocity())
	ecs.add_component(id, "move_speed", Components.move_speed(3.0))
	ecs.add_component(id, "path_state", Components.path_state())
	ecs.add_component(id, "health", Components.health(100.0))
	ecs.add_component(id, "faction", Components.faction(faction_id))
	ecs.add_component(id, "vision_range", Components.vision_range(8.0))
	return id


## Stub: will load from YAML in Phase 1.
func create_from_definition(unit_type: String, pos: Vector2) -> int:
	push_warning("EntityFactory.create_from_definition: YAML loading not yet implemented for '%s'" % unit_type)
	return create_test_unit(pos)
