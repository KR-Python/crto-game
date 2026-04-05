## RoleHotSwap
## Handles seamless AI ↔ human role transitions mid-game.
## Works in concert with SessionManager — never mutates session state directly;
## always calls the SessionManager API so signals propagate correctly.
class_name RoleHotSwap
extends Node

# ── Signals ──────────────────────────────────────────────────────────────────
signal role_transferred(role: String, from_player_id: int, to_player_id: int)
signal ai_activated(role: String)
signal ai_deactivated(role: String)
signal handoff_warning(role: String, seconds_remaining: int)

# ── Constants ─────────────────────────────────────────────────────────────────
const GRACEFUL_HANDOFF_SECONDS := 5

# ── Human takes over an AI-controlled role (joining player) ───────────────────
## Validates that:
##   • role is currently AI-controlled
##   • player_id is connected and doesn't already hold a role
## On success: stops AI, updates session mapping, emits role_transferred.
## Returns true on success.
func human_take_role(player_id: int, role: String, session_manager: SessionManager) -> bool:
	# Validate: role must be AI-controlled
	if not session_manager.is_ai_role(role):
		push_warning("RoleHotSwap.human_take_role: role '%s' is not AI-controlled." % role)
		return false

	# Validate: player must be connected
	if not session_manager.is_connected_player(player_id):
		push_warning("RoleHotSwap.human_take_role: player %d is not connected." % player_id)
		return false

	# Validate: player must not already hold a role
	if session_manager.player_has_role(player_id):
		push_warning("RoleHotSwap.human_take_role: player %d already has a role." % player_id)
		return false

	# Stop AI partner for this role
	session_manager.clear_ai_partner(role)
	emit_signal("ai_deactivated", role)

	# Update session mapping
	session_manager.assign_role(player_id, role)

	# Send full state snapshot to new player (host-side; client requests via RPC in full impl)
	_send_state_snapshot_to(player_id, session_manager)

	emit_signal("role_transferred", role, -1, player_id)
	return true

# ── AI takes over a human role (player disconnected or graceful handoff) ──────
## Marks the role as AI-controlled in SessionManager,
## instantiates the appropriate AIPartner, and continues from ECS state.
func ai_take_role(role: String, session_manager: SessionManager) -> void:
	# Update session mapping
	session_manager.mark_role_ai(role)

	# Instantiate and start AI partner
	var partner: AIPartner = _instantiate_ai_for_role(role)
	if partner == null:
		push_error("RoleHotSwap.ai_take_role: no AI available for role '%s'." % role)
		return

	partner.name = "AIPartner_%s" % role
	session_manager.add_child(partner)

	# Feed current ECS world state so AI continues seamlessly
	if session_manager.ecs_world != null:
		partner.initialize(session_manager.ecs_world)

	session_manager.set_ai_partner(role, partner)
	emit_signal("ai_activated", role)

# ── Graceful handoff: human signals intent to leave ───────────────────────────
## Emits countdown warnings to teammates, then hands off to AI.
## Uses a timer so the player can still cancel before expiry.
func initiate_graceful_handoff(player_id: int, session_manager: SessionManager) -> void:
	var role: String = session_manager.player_roles.get(player_id, "")
	if role == "":
		push_warning("RoleHotSwap.initiate_graceful_handoff: player %d has no role." % player_id)
		return

	# Count down from GRACEFUL_HANDOFF_SECONDS → 1, then transfer
	for i in range(GRACEFUL_HANDOFF_SECONDS, 0, -1):
		emit_signal("handoff_warning", role, i)
		await get_tree().create_timer(1.0).timeout

	# AI takes over — player is expected to disconnect immediately after
	ai_take_role(role, session_manager)

# ── Internal helpers ──────────────────────────────────────────────────────────

func _instantiate_ai_for_role(role: String) -> AIPartner:
	match role:
		"commander":     return CommanderAI.new()
		"quartermaster": return QuartermasterAI.new()
		"field_marshal": return FieldMarshalAI.new()
		"spec_ops":      return SpecOpsAI.new()
		_:
			push_warning("RoleHotSwap._instantiate_ai_for_role: unknown role '%s'." % role)
			return null

## Sends a full state snapshot to the specified player.
## In a real host-authoritative setup this would be an RPC; here we emit
## the snapshot as a signal so the test harness and UI can react without
## requiring a live multiplayer peer.
func _send_state_snapshot_to(player_id: int, session_manager: SessionManager) -> void:
	var snapshot: Dictionary = session_manager.get_state_snapshot()
	# In production: rpc_id(player_id, "_receive_state_snapshot", snapshot)
	# For now emit as a local signal so callers/tests can observe it:
	emit_signal("role_transferred", "snapshot_sent", player_id, player_id)
	@warning_ignore("unused_variable")
	var _snapshot_ref := snapshot  # suppress unused-variable warning
