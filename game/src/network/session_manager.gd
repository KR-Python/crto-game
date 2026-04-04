## SessionManager
## Host-authoritative session: tracks connected players, their roles,
## and whether each role is human- or AI-controlled.
## Wires into RoleHotSwap for seamless AI ↔ human transitions.
class_name SessionManager
extends Node

# ── Signals ──────────────────────────────────────────────────────────────────
signal player_joined(player_id: int, role: String)
signal player_left(player_id: int, role: String)
signal role_assignment_changed(role: String, player_id: int)  # -1 = AI

# ── Constants ─────────────────────────────────────────────────────────────────
const VALID_ROLES := ["commander", "quartermaster", "field_marshal", "spec_ops"]

# ── State ─────────────────────────────────────────────────────────────────────
## player_id → role
var player_roles: Dictionary = {}

## role → player_id (-1 = AI-controlled)
var role_assignments: Dictionary = {
	"commander":    -1,
	"quartermaster": -1,
	"field_marshal": -1,
	"spec_ops":     -1,
}

## role → AIPartner node (null if human-controlled)
var ai_partners: Dictionary = {}

## Set of currently connected player_ids
var connected_players: Dictionary = {}   # player_id → true

## Reference to RoleHotSwap helper (set during _ready or by game coordinator)
var hot_swap: RoleHotSwap = null

# ── ECS world reference (set by game coordinator) ─────────────────────────────
var ecs_world = null   # typed as variant to avoid hard dependency

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	hot_swap = RoleHotSwap.new()
	hot_swap.name = "RoleHotSwap"
	add_child(hot_swap)

	# Forward hot-swap signals upward
	hot_swap.role_transferred.connect(_on_role_transferred)
	hot_swap.ai_activated.connect(_on_ai_activated)
	hot_swap.ai_deactivated.connect(_on_ai_deactivated)

	# Wire multiplayer callbacks when running inside Godot's multiplayer tree
	if multiplayer:
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_player_disconnected)

# ── Public API ────────────────────────────────────────────────────────────────

## Called when a new peer connects (pre-lobby). Tracks presence only.
func _on_peer_connected(player_id: int) -> void:
	connected_players[player_id] = true

## Called when a peer disconnects. AI immediately covers their role.
func _on_player_disconnected(player_id: int) -> void:
	connected_players.erase(player_id)
	var role: String = player_roles.get(player_id, "")
	if role != "":
		player_roles.erase(player_id)
		emit_signal("player_left", player_id, role)
		# Seamlessly hand off to AI
		hot_swap.ai_take_role(role, self)

## Called when a joining player requests to fill an AI-held role.
## Returns true if the handoff succeeds.
func request_role(player_id: int, role: String) -> bool:
	if role not in VALID_ROLES:
		return false
	# Only allow taking AI-held roles via this path
	if role_assignments.get(role, -1) != -1:
		return false
	return hot_swap.human_take_role(player_id, role, self)

## Assign a role directly (called by RoleHotSwap after validation).
func assign_role(player_id: int, role: String) -> void:
	player_roles[player_id] = role
	role_assignments[role] = player_id
	emit_signal("role_assignment_changed", role, player_id)

## Mark a role as AI-controlled.
func mark_role_ai(role: String) -> void:
	# Remove reverse lookup for previous human holder if any
	var prev_player: int = role_assignments.get(role, -1)
	if prev_player != -1:
		player_roles.erase(prev_player)
	role_assignments[role] = -1
	emit_signal("role_assignment_changed", role, -1)

## Store an active AIPartner for a role.
func set_ai_partner(role: String, partner) -> void:
	ai_partners[role] = partner

## Remove and free the AIPartner for a role.
func clear_ai_partner(role: String) -> void:
	if ai_partners.has(role) and ai_partners[role] != null:
		var partner = ai_partners[role]
		if partner.is_inside_tree():
			partner.queue_free()
		ai_partners.erase(role)

## Returns true if role is currently AI-controlled.
func is_ai_role(role: String) -> bool:
	return role_assignments.get(role, -1) == -1

## Returns true if player_id is connected.
func is_connected_player(player_id: int) -> bool:
	return connected_players.has(player_id)

## Returns true if player_id already holds any role.
func player_has_role(player_id: int) -> bool:
	return player_roles.has(player_id)

## Returns a deep-copy snapshot of the current session state.
func get_state_snapshot() -> Dictionary:
	return {
		"player_roles":    player_roles.duplicate(),
		"role_assignments": role_assignments.duplicate(),
	}

# ── Signal Handlers ──────────────────────────────────────────────────────────
func _on_role_transferred(role: String, from_player_id: int, to_player_id: int) -> void:
	emit_signal("role_assignment_changed", role, to_player_id)

func _on_ai_activated(role: String) -> void:
	emit_signal("role_assignment_changed", role, -1)

func _on_ai_deactivated(role: String) -> void:
	pass  # role_assignment already updated by human_take_role
