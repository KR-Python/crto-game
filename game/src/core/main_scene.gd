# Scene tree:
# MainScene (Node2D)
# ├── GameMap (Node2D) [game_map.gd]
# │   └── TileMapLayer
# ├── CameraController (Camera2D) [camera_controller.gd]
# ├── GameLoop (Node) [game_loop.gd]
# └── UnitLayer (Node2D)  [units rendered here]

class_name MainScene
extends Node2D

@onready var game_map: GameMap = $GameMap
@onready var camera: CameraController = $CameraController
@onready var unit_layer: Node2D = $UnitLayer

# ECS and GameLoop are created dynamically — not in scene tree
var ecs: ECS
var game_loop: GameLoop

# Maps entity_id -> visual node for Phase 0
var _unit_visuals: Dictionary = {}

# The single test unit spawned at map center
var _test_unit_id: int = -1


func _ready() -> void:
	# 1. Init ECS
	ecs = ECS.new()
	add_child(ecs)

	# 2. Load map and configure camera bounds
	game_map.load_flat_map(128, 96)
	camera.map_bounds = game_map.get_world_bounds()

	# Center camera on map
	var bounds: Rect2 = game_map.get_world_bounds()
	camera.position = bounds.get_center()
	camera.set_spawn_point(bounds.get_center())

	# 3. Init game loop
	game_loop = GameLoop.new()
	game_loop.ecs = ecs
	add_child(game_loop)

	# 4. Spawn test unit at map center
	var factory := EntityFactory.new(ecs)
	var center := bounds.get_center()
	_test_unit_id = factory.create_test_unit(center)
	_spawn_unit_visual(_test_unit_id, center)

	game_loop.start()


# ── Unit Visuals ──────────────────────────────────────────────────────────────

## Spawns a colored rectangle placeholder linked to `entity_id`.
## Phase 1 will replace this with proper sprites via a render system.
func _spawn_unit_visual(entity_id: int, pos: Vector2) -> void:
	var rect := ColorRect.new()
	rect.size = Vector2(24, 24)
	rect.position = pos - rect.size / 2.0   # center on position
	rect.color = Color("#e8d44d")            # yellow for test unit
	rect.name = "Unit_%d" % entity_id
	unit_layer.add_child(rect)
	_unit_visuals[entity_id] = rect


## Move a unit visual to `pos` (called by render system in Phase 1).
func update_unit_visual(entity_id: int, pos: Vector2) -> void:
	if not _unit_visuals.has(entity_id):
		return
	var rect: ColorRect = _unit_visuals[entity_id]
	rect.position = pos - rect.size / 2.0


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return

	var world_pos: Vector2 = camera.get_global_mouse_position()
	_issue_move_command(_test_unit_id, world_pos)


## Issues a move command to `entity_id` for Phase 0 pathfinder testing.
## Phase 1 replaces this with the full CommandQueue + MovementSystem flow.
func _issue_move_command(entity_id: int, destination: Vector2) -> void:
	if entity_id < 0:
		return
	# Direct pathfinder call for Phase 0 — bypasses command queue
	# TODO: route through CommandQueue in Phase 1
	var start_cell := Vector2i(
		int(camera.position.x) / GameMap.TILE_SIZE,
		int(camera.position.y) / GameMap.TILE_SIZE
	)
	var dest_cell := Vector2i(
		int(destination.x) / GameMap.TILE_SIZE,
		int(destination.y) / GameMap.TILE_SIZE
	)
	# Stub — pathfinder integration wired in Phase 1
	push_warning("MainScene._issue_move_command: move to cell %s (pathfinder not yet wired)" % str(dest_cell))
