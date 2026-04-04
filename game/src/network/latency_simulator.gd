## LatencySimulator
## Injects artificial latency, jitter, and packet loss into the command pipeline
## for network condition testing. Wrap your ENet command dispatch through
## queue_command(); connect command_ready to your actual send/process logic.
##
## Usage:
##   var sim := LatencySimulator.new()
##   sim.simulate(100, 20, 0.05)   # 100ms ± 20ms, 5% packet loss
##   sim.command_ready.connect(_on_command_ready)
##   sim.queue_command({"type": "move", "entity": 42, "target": Vector2(10,20)})
class_name LatencySimulator
extends Node

# ── Signals ──────────────────────────────────────────────────────────────────
## Fired when a queued command's delivery time has arrived.
signal command_ready(command: Dictionary)

# ── Configuration ─────────────────────────────────────────────────────────────
var enabled: bool = false
var simulated_latency_ms: int = 0  ## one-way latency (milliseconds)
var jitter_ms: int = 0             ## random variance added on top (milliseconds)
var packet_loss_pct: float = 0.0   ## fraction of packets to silently drop (0.0–1.0)

# ── Internal queue ────────────────────────────────────────────────────────────
## Each entry: { "command": Dictionary, "deliver_at_ms": int }
var _pending_commands: Array = []

# ── Public API ────────────────────────────────────────────────────────────────

## Configure and enable the simulator.
func simulate(latency_ms: int, jitter: int = 0, loss_pct: float = 0.0) -> void:
	enabled = true
	simulated_latency_ms = latency_ms
	jitter_ms = jitter
	packet_loss_pct = clampf(loss_pct, 0.0, 1.0)

## Disable simulation — all subsequent queue_command calls pass through
## immediately (command_ready fired synchronously).
func disable() -> void:
	enabled = false
	_pending_commands.clear()

## Submit a command into the pipeline.
## • If disabled: fires command_ready immediately (synchronous pass-through).
## • If packet_loss drops the packet: silently discarded.
## • Otherwise: scheduled for delivery after latency + random jitter.
func queue_command(command: Dictionary) -> void:
	if not enabled:
		emit_signal("command_ready", command)
		return

	# Packet loss
	if packet_loss_pct > 0.0 and randf() < packet_loss_pct:
		return  # drop

	# Schedule delivery
	var jitter_offset: int = 0
	if jitter_ms > 0:
		jitter_offset = randi() % jitter_ms
	var deliver_at: int = Time.get_ticks_msec() + simulated_latency_ms + jitter_offset

	_pending_commands.append({
		"command":       command,
		"deliver_at_ms": deliver_at,
	})

## Flush all pending commands immediately (useful in tests or on scene exit).
func flush() -> void:
	for item in _pending_commands:
		emit_signal("command_ready", item["command"])
	_pending_commands.clear()

# ── Process loop ──────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if _pending_commands.is_empty():
		return

	var now: int = Time.get_ticks_msec()
	# Pop all commands whose delivery time has passed (in insertion order)
	while not _pending_commands.is_empty() and _pending_commands[0]["deliver_at_ms"] <= now:
		var item: Dictionary = _pending_commands.pop_front()
		emit_signal("command_ready", item["command"])
