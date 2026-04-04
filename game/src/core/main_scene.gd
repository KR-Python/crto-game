class_name MainScene
extends Node2D
@onready var game_map: GameMap = $GameMap
@onready var camera: CameraController = $CameraController
@onready var unit_layer: Node2D = $UnitLayer
var simulation: Simulation
var game_loop: GameLoop
var _unit_visuals: Dictionary = {}
var _test_unit_id: int = -1
func _ready() -> void:
	game_map.load_flat_map(128, 96)
	var bounds: Rect2 = game_map.get_world_bounds()
	camera.map_bounds = bounds
	camera.position = bounds.get_center()
	camera.set_spawn_point(bounds.get_center())
	simulation = Simulation.new()
	add_child(simulation)
	simulation.initialize(game_map)
	game_loop = GameLoop.new()
	game_loop.simulation = simulation
	add_child(game_loop)
	var factory := EntityFactory.new(simulation.ecs)
	_test_unit_id = factory.create_test_unit(bounds.get_center())
	_spawn_unit_visual(_test_unit_id)
	game_loop.start()
func _spawn_unit_visual(entity_id: int) -> void:
	var visual := UnitVisual.new()
	visual.entity_id = entity_id
	visual.ecs = simulation.ecs
	visual.color = Color("#e8d44d")
	unit_layer.add_child(visual)
	_unit_visuals[entity_id] = visual
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	simulation.issue_move_command(_test_unit_id, get_global_mouse_position())
