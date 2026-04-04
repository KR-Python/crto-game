class_name Simulation
extends Node
var ecs: ECS
var nav_grid: NavGrid
var pathfinder: Pathfinder
var permission_system: PermissionSystem
var economy_system: EconomySystem
var production_system: ProductionSystem
var command_processing_system: CommandProcessingSystem
var movement_system: MovementSystem
var combat_system: CombatSystem
var death_system: DeathSystem
var vision_system: VisionSystem
var status_effect_system: StatusEffectSystem
var snapshot_system: SnapshotSystem
func initialize(map: GameMap) -> void:
	ecs = ECS.new()
	add_child(ecs)
	nav_grid = map.nav_grid
	pathfinder = Pathfinder.new(nav_grid)
	permission_system = PermissionSystem.new()
	economy_system = EconomySystem.new()
	production_system = ProductionSystem.new()
	command_processing_system = CommandProcessingSystem.new()
	command_processing_system.pathfinder = pathfinder
	command_processing_system.nav_grid = nav_grid
	movement_system = MovementSystem.new()
	movement_system.map_bounds = map.get_world_bounds()
	combat_system = CombatSystem.new()
	death_system = DeathSystem.new()
	vision_system = VisionSystem.new()
	vision_system.initialize(map.width, map.height)
	status_effect_system = StatusEffectSystem.new()
	snapshot_system = SnapshotSystem.new()
func tick(tick_count: int) -> void:
	permission_system.tick(ecs, tick_count)
	economy_system.tick(ecs, tick_count)
	production_system.tick(ecs, tick_count)
	command_processing_system.tick(ecs, tick_count)
	movement_system.tick(ecs, tick_count)
	combat_system.tick(ecs, tick_count)
	death_system.tick(ecs, tick_count)
	vision_system.tick(ecs, tick_count)
	status_effect_system.tick(ecs, tick_count)
	snapshot_system.tick(ecs, tick_count)
func issue_move_command(entity_id: int, destination: Vector2) -> void:
	if not ecs.is_alive(entity_id):
		return
	ecs.add_component(entity_id, "MoveCommand", {"destination": destination, "queued": false})
