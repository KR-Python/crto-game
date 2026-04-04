class_name GameLoop
extends Node
const TICK_INTERVAL: float = 1.0 / 15.0
var simulation: Simulation
var _tick_count: int = 0
var _accumulator: float = 0.0
var _running: bool = false
func start() -> void:
	_running = true
func stop() -> void:
	_running = false
func _process(delta: float) -> void:
	if not _running or simulation == null:
		return
	_accumulator += delta
	while _accumulator >= TICK_INTERVAL:
		_accumulator -= TICK_INTERVAL
		_tick_count += 1
		simulation.tick(_tick_count)
