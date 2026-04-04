class_name TunnelSystem

# Tick pipeline step: FORGE faction tunnel network mechanic.
# Tunnel entrances allow instant unit transport between connected exits.
# Units enter by moving to a tunnel entrance; they arrive at their chosen exit next tick.
# Spec Ops units can enter enemy tunnels if the exit is uncaptured (no faction check).
# Enemy can destroy tunnel exits; units in transit are rerouted to the nearest safe exit
# or become stranded (dropped at their source position) if none exists.
#
# Reads:  TunnelEntrance, InTransit, Position, FactionComponent, UnitType
# Writes: InTransit (add/remove), Position (on arrival), TunnelEntrance (on destroy)

const TRANSIT_TICKS: int = 1  # Arrive next tick after entry

# Component constructors ───────────────────────────────────────────────────────

static func tunnel_entrance(network_id: int, faction_id: int) -> Dictionary:
	# Placed on tunnel entrance/exit entities.
	return {
		"network_id": network_id,
		"faction_id": faction_id,
		"connected_exits": [],   # Array[int] of entity IDs
		"max_capacity": 8,
		"destroyed": false,
	}


static func in_transit(destination_entity: int, arrive_tick: int) -> Dictionary:
	# Placed on a unit while it is travelling through a tunnel.
	return {
		"destination_entity": destination_entity,
		"arrive_tick": arrive_tick,
	}


# ── Tick ──────────────────────────────────────────────────────────────────────

func tick(ecs: ECS, tick_count: int) -> void:
	_process_arrivals(ecs, tick_count)
	_handle_destroyed_tunnels(ecs, tick_count)


# ── Public API ────────────────────────────────────────────────────────────────

func enter_tunnel(unit_id: int, tunnel_id: int, destination_id: int, ecs: ECS) -> bool:
	# Returns false if entry is invalid (tunnel destroyed, destination invalid, etc.).
	if not ecs.has_component(tunnel_id, "TunnelEntrance"):
		push_warning("TunnelSystem.enter_tunnel: entity %d has no TunnelEntrance" % tunnel_id)
		return false

	var tunnel: Dictionary = ecs.get_component(tunnel_id, "TunnelEntrance")
	if tunnel.get("destroyed", false):
		return false

	if not ecs.has_component(destination_id, "TunnelEntrance"):
		push_warning("TunnelSystem.enter_tunnel: destination %d has no TunnelEntrance" % destination_id)
		return false

	var dest_tunnel: Dictionary = ecs.get_component(destination_id, "TunnelEntrance")
	if dest_tunnel.get("destroyed", false):
		return false

	# Destination must be in the same network
	if dest_tunnel.get("network_id", -1) != tunnel.get("network_id", -1):
		return false

	if ecs.has_component(unit_id, "InTransit"):
		# Already in transit
		return false

	var tick_count: int = 0  # Caller provides via parameter; use passed arrive_tick instead.
	# Note: arrive_tick is calculated by the caller (current_tick + TRANSIT_TICKS).
	# We accept any destination_id that passes validation; tick is embedded in component.
	# The caller must pass the current tick context — we grab it from InTransit on next tick.
	# Re-expose via a separate overload that accepts tick_count for correct arrive_tick:
	push_warning("TunnelSystem.enter_tunnel: use enter_tunnel_at_tick() for tick-aware entry")
	return false


func enter_tunnel_at_tick(unit_id: int, tunnel_id: int, destination_id: int, ecs: ECS, tick_count: int) -> bool:
	# Tick-aware entry — preferred overload.
	if not ecs.has_component(tunnel_id, "TunnelEntrance"):
		push_warning("TunnelSystem: tunnel entity %d missing TunnelEntrance" % tunnel_id)
		return false

	var tunnel: Dictionary = ecs.get_component(tunnel_id, "TunnelEntrance")
	if tunnel.get("destroyed", false):
		return false

	if not ecs.has_component(destination_id, "TunnelEntrance"):
		push_warning("TunnelSystem: destination entity %d missing TunnelEntrance" % destination_id)
		return false

	var dest_tunnel: Dictionary = ecs.get_component(destination_id, "TunnelEntrance")
	if dest_tunnel.get("destroyed", false):
		return false

	# Same network required
	if dest_tunnel.get("network_id", -1) != tunnel.get("network_id", -1):
		return false

	if ecs.has_component(unit_id, "InTransit"):
		return false

	ecs.add_component(unit_id, "InTransit", in_transit(destination_id, tick_count + TRANSIT_TICKS))
	return true


func get_available_exits(tunnel_id: int, faction_id: int, ecs: ECS) -> Array[int]:
	# Returns all non-destroyed exits in the same network accessible to faction_id.
	# Spec Ops (unit type "spec_ops") has special infiltration access handled separately —
	# this function returns exits for standard faction-matched access.
	# An exit is available if: same network AND (same faction OR uncaptured/neutral).
	if not ecs.has_component(tunnel_id, "TunnelEntrance"):
		return []

	var tunnel: Dictionary = ecs.get_component(tunnel_id, "TunnelEntrance")
	var network_id: int = tunnel.get("network_id", -1)

	var result: Array[int] = []
	var all_tunnels: Array[int] = ecs.query(["TunnelEntrance"])
	for tid: int in all_tunnels:
		if tid == tunnel_id:
			continue
		var t: Dictionary = ecs.get_component(tid, "TunnelEntrance")
		if t.get("network_id", -1) != network_id:
			continue
		if t.get("destroyed", false):
			continue
		var exit_faction: int = t.get("faction_id", -1)
		# Available if same faction OR neutral (faction_id == -1)
		if exit_faction == faction_id or exit_faction == -1:
			result.append(tid)

	return result


func get_available_exits_spec_ops(tunnel_id: int, ecs: ECS) -> Array[int]:
	# Spec Ops can use any non-destroyed tunnel in the network regardless of faction.
	if not ecs.has_component(tunnel_id, "TunnelEntrance"):
		return []

	var tunnel: Dictionary = ecs.get_component(tunnel_id, "TunnelEntrance")
	var network_id: int = tunnel.get("network_id", -1)

	var result: Array[int] = []
	var all_tunnels: Array[int] = ecs.query(["TunnelEntrance"])
	for tid: int in all_tunnels:
		if tid == tunnel_id:
			continue
		var t: Dictionary = ecs.get_component(tid, "TunnelEntrance")
		if t.get("network_id", -1) != network_id:
			continue
		if not t.get("destroyed", false):
			result.append(tid)

	return result


# ── Internal helpers ──────────────────────────────────────────────────────────

func _process_arrivals(ecs: ECS, tick_count: int) -> void:
	var in_transit_units: Array[int] = ecs.query(["InTransit", "Position"])
	for unit_id: int in in_transit_units:
		var transit: Dictionary = ecs.get_component(unit_id, "InTransit")
		if tick_count < transit.get("arrive_tick", 0):
			continue

		var dest_id: int = transit.get("destination_entity", -1)
		if dest_id < 0:
			ecs.remove_component(unit_id, "InTransit")
			continue

		# Check destination is still valid
		if ecs.has_component(dest_id, "TunnelEntrance"):
			var dest: Dictionary = ecs.get_component(dest_id, "TunnelEntrance")
			if not dest.get("destroyed", false) and ecs.has_component(dest_id, "Position"):
				var dest_pos: Dictionary = ecs.get_component(dest_id, "Position")
				var unit_pos: Dictionary = ecs.get_component(unit_id, "Position")
				unit_pos["x"] = dest_pos.get("x", 0.0)
				unit_pos["y"] = dest_pos.get("y", 0.0)
				ecs.add_component(unit_id, "Position", unit_pos)
				ecs.remove_component(unit_id, "InTransit")
				continue

		# Destination was destroyed — reroute to nearest safe exit
		_reroute_or_strand(unit_id, dest_id, ecs)


func _handle_destroyed_tunnels(ecs: ECS, tick_count: int) -> void:
	# Units in transit targeting a just-destroyed tunnel are caught in _process_arrivals.
	# Nothing additional needed here — destruction is detected per-unit on arrival.
	pass


func _reroute_or_strand(unit_id: int, failed_dest_id: int, ecs: ECS) -> void:
	# Try to find the nearest non-destroyed tunnel in the same network.
	var transit: Dictionary = ecs.get_component(unit_id, "InTransit")
	var failed_network_id: int = -1
	if ecs.has_component(failed_dest_id, "TunnelEntrance"):
		failed_network_id = ecs.get_component(failed_dest_id, "TunnelEntrance").get("network_id", -1)

	var unit_pos: Dictionary = ecs.get_component(unit_id, "Position")
	var best_dist_sq: float = INF
	var best_exit: int = -1

	if failed_network_id >= 0:
		var all_tunnels: Array[int] = ecs.query(["TunnelEntrance", "Position"])
		for tid: int in all_tunnels:
			var t: Dictionary = ecs.get_component(tid, "TunnelEntrance")
			if t.get("network_id", -1) != failed_network_id:
				continue
			if t.get("destroyed", false):
				continue
			var tpos: Dictionary = ecs.get_component(tid, "Position")
			var dx: float = tpos.get("x", 0.0) - unit_pos.get("x", 0.0)
			var dy: float = tpos.get("y", 0.0) - unit_pos.get("y", 0.0)
			var dist_sq: float = dx * dx + dy * dy
			if dist_sq < best_dist_sq:
				best_dist_sq = dist_sq
				best_exit = tid

	if best_exit >= 0:
		# Teleport to nearest safe exit
		var exit_pos: Dictionary = ecs.get_component(best_exit, "Position")
		unit_pos["x"] = exit_pos.get("x", 0.0)
		unit_pos["y"] = exit_pos.get("y", 0.0)
		ecs.add_component(unit_id, "Position", unit_pos)
	# else: unit is stranded — stays at current position (no teleport)

	ecs.remove_component(unit_id, "InTransit")
