## session_manager.gd
## Lobby + session lifecycle using Godot's built-in ENetMultiplayerPeer.
## Handles hosting, joining, role selection, disconnect → AI takeover, host migration.
class_name SessionManager
extends Node

enum State { IDLE, HOSTING, JOINING, IN_LOBBY, IN_GAME }

var state: State = State.IDLE
var players: Dictionary = {}  # peer_id → {name, role, connected, is_ai}
var local_player_id: int = -1
var is_host: bool = false

var _peer: ENetMultiplayerPeer = null

const DEFAULT_PORT: int = 7777
const MAX_CLIENTS: int = 7

signal player_joined(player_id: int, player_name: String)
signal player_left(player_id: int)
signal role_assigned(player_id: int, role: String)
signal role_vacated(role: String)
signal game_started()
signal host_migrated(new_host_id: int)
signal connection_failed()


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_host_disconnected)


## Host a new game on the given port.
func host_game(port: int = DEFAULT_PORT) -> Error:
	if state != State.IDLE:
		push_warning("SessionManager.host_game: not in IDLE state")
		return ERR_ALREADY_IN_USE

	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("SessionManager.host_game: create_server failed: %s" % error_string(err))
		_peer = null
		return err

	multiplayer.multiplayer_peer = _peer
	is_host = true
	local_player_id = 1
	state = State.IN_LOBBY
	players[1] = {"name": "Host", "role": "", "connected": true, "is_ai": false}
	return OK


## Join an existing game at the given address and port.
func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	if state != State.IDLE:
		push_warning("SessionManager.join_game: not in IDLE state")
		return ERR_ALREADY_IN_USE

	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(address, port)
	if err != OK:
		push_error("SessionManager.join_game: create_client failed: %s" % error_string(err))
		_peer = null
		return err

	multiplayer.multiplayer_peer = _peer
	is_host = false
	state = State.JOINING
	return OK


## Select a role for the local player.
func select_role(role: String) -> void:
	if local_player_id < 0:
		push_warning("SessionManager.select_role: not connected")
		return
	if local_player_id in players:
		players[local_player_id]["role"] = role
		role_assigned.emit(local_player_id, role)


## Check if a role is already taken by a connected player.
func is_role_taken(role: String) -> bool:
	for pid: int in players:
		if players[pid]["role"] == role and players[pid]["connected"]:
			return true
	return false


## Start the game (host only).
func start_game() -> void:
	if not is_host:
		push_warning("SessionManager.start_game: only host can start")
		return
	if state != State.IN_LOBBY:
		push_warning("SessionManager.start_game: not in lobby")
		return
	state = State.IN_GAME
	game_started.emit()


func _on_peer_connected(peer_id: int) -> void:
	players[peer_id] = {"name": "Player_%d" % peer_id, "role": "", "connected": true, "is_ai": false}
	player_joined.emit(peer_id, players[peer_id]["name"])


func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id not in players:
		return
	var role: String = players[peer_id].get("role", "")
	players[peer_id]["connected"] = false
	players[peer_id]["is_ai"] = true
	player_left.emit(peer_id)
	if role != "":
		role_vacated.emit(role)


func _on_connected_to_server() -> void:
	local_player_id = multiplayer.get_unique_id()
	state = State.IN_LOBBY
	players[local_player_id] = {"name": "Player_%d" % local_player_id, "role": "", "connected": true, "is_ai": false}


func _on_connection_failed() -> void:
	state = State.IDLE
	_peer = null
	connection_failed.emit()


func _on_host_disconnected() -> void:
	if state == State.IN_GAME:
		var new_host_id: int = HostMigration.select_new_host(players)
		if new_host_id == local_player_id:
			is_host = true
		host_migrated.emit(new_host_id)
	else:
		state = State.IDLE
		players.clear()
		_peer = null


## Disconnect and reset state.
func disconnect_game() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	multiplayer.multiplayer_peer = null
	state = State.IDLE
	players.clear()
	local_player_id = -1
	is_host = false


## Get list of connected player IDs.
func get_connected_players() -> Array[int]:
	var result: Array[int] = []
	for pid: int in players:
		if players[pid]["connected"]:
			result.append(pid)
	return result
