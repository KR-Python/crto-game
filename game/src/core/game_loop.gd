class_name GameLoop
extends Node
## Fixed-timestep simulation loop, decoupled from rendering.
## Runs at 15 ticks/sec regardless of frame rate.

const TICK_RATE: int = 15
const TICK_DURATION: float = 1.0 / TICK_RATE  # ~0.0667s

var ecs: ECS
var systems: Array = []  # ordered list of system instances
var tick_count: int = 0
var _accumulator: float = 0.0
var _running: bool = false

signal tick_completed(tick: int)
signal simulation_started()
signal simulation_stopped()


func _physics_process(delta: float) -> void:
	if not _running:
		return
	_accumulator += delta
	while _accumulator >= TICK_DURATION:
		_tick()
		_accumulator -= TICK_DURATION


func _tick() -> void:
	tick_count += 1
	for system in systems:
		system.tick(ecs, tick_count)
	tick_completed.emit(tick_count)


func register_system(system) -> void:
	systems.append(system)


func start() -> void:
	_running = true
	simulation_started.emit()


func stop() -> void:
	_running = false
	simulation_stopped.emit()
