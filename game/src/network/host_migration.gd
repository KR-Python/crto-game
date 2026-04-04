## host_migration.gd
## Simple host migration: when host disconnects, lowest connected peer_id becomes new host.
class_name HostMigration


## Select the new host from connected players.
## Returns the lowest peer_id among connected, non-AI players. Returns -1 if none.
static func select_new_host(players: Dictionary) -> int:
	var best_id: int = -1
	for pid: int in players:
		if not players[pid].get("connected", false):
			continue
		if players[pid].get("is_ai", false):
			continue
		if best_id == -1 or pid < best_id:
			best_id = pid
	return best_id
