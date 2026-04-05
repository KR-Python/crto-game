## command_queue.gd
## Holds commands until their target tick. Written by InputSystem and AIDecisionSystem.
## Read and cleared by PermissionSystem at each tick boundary.
class_name CommandQueue

# ---------------------------------------------------------------------------
# Internal storage
# ---------------------------------------------------------------------------

## Pending commands: tick → Array[Dictionary]
var _queue: Dictionary = {}

## Total commands ever enqueued (for diagnostics)
var _total_enqueued: int = 0

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Enqueue a command dict. Required keys: player_id, role, tick, action, params.
## Commands missing required keys are dropped with a warning.
func enqueue(command: Dictionary) -> void:
	if not _validate_command_shape(command):
		push_warning("CommandQueue.enqueue: dropping malformed command: %s" % str(command))
		return
	var target_tick: int = command["tick"]
	if not target_tick in _queue:
		_queue[target_tick] = []
	_queue[target_tick].append(command)
	_total_enqueued += 1

## Returns all commands queued for exactly the given tick.
## Does NOT remove them — caller (PermissionSystem) clears after processing.
func get_commands_for_tick(tick: int) -> Array[Dictionary]:
	var raw: Array = _queue.get(tick, [])
	var result: Array[Dictionary] = []
	for item in raw:
		if item is Dictionary:
			result.append(item)
	return result

## Remove all commands whose target tick is strictly less than current_tick.
## These represent TICK_EXPIRED commands that arrived too late.
func clear_expired(current_tick: int) -> void:
	var expired_ticks: Array = []
	for tick in _queue.keys():
		if tick < current_tick:
			expired_ticks.append(tick)
	for tick in expired_ticks:
		_queue.erase(tick)

## Remove commands for a specific tick (called after PermissionSystem processes them).
func clear_tick(tick: int) -> void:
	_queue.erase(tick)

## Total number of commands currently buffered across all ticks.
func pending_count() -> int:
	var count: int = 0
	for tick in _queue:
		count += _queue[tick].size()
	return count

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _validate_command_shape(cmd: Dictionary) -> bool:
	var required_keys: Array[String] = ["player_id", "role", "tick", "action", "params"]
	for key in required_keys:
		if not key in cmd:
			return false
	return true
