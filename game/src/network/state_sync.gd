## state_sync.gd
## State snapshot and delta compression with fog-of-war masking.
## Security-critical: clients must NOT receive entity data outside their vision.
class_name StateSync

## faction_id → { entity_id_str → component_hash }
var _last_snapshots: Dictionary = {}

# ---------------------------------------------------------------------------
# Full snapshot — sent on client connect/reconnect
# ---------------------------------------------------------------------------

## Generate a full state snapshot visible to the given faction.
## Applies fog-of-war masking: enemy entities outside vision are excluded.
func generate_full_snapshot(ecs: ECS, faction_id: int, vision_system: VisionSystem) -> Dictionary:
	var snapshot: Dictionary = {}
	for entity_id: int in ecs.query([]):
		if not _is_visible_to_faction(ecs, entity_id, faction_id, vision_system):
			continue
		snapshot[str(entity_id)] = _get_entity_data(ecs, entity_id)

	_last_snapshots[faction_id] = _compute_hashes(snapshot)
	return snapshot

# ---------------------------------------------------------------------------
# Delta snapshot — sent every 2 ticks
# ---------------------------------------------------------------------------

## Generate a delta containing only changes since the last snapshot.
## Returns {added: {}, changed: {}, removed: []}.
func generate_delta(ecs: ECS, faction_id: int, vision_system: VisionSystem) -> Dictionary:
	var current_snapshot: Dictionary = {}
	for entity_id: int in ecs.query([]):
		if not _is_visible_to_faction(ecs, entity_id, faction_id, vision_system):
			continue
		current_snapshot[str(entity_id)] = _get_entity_data(ecs, entity_id)

	var current_hashes: Dictionary = _compute_hashes(current_snapshot)
	var previous_hashes: Dictionary = _last_snapshots.get(faction_id, {})

	var added: Dictionary = {}
	var changed: Dictionary = {}
	var removed: Array = []

	for eid_str: String in current_hashes:
		if eid_str not in previous_hashes:
			added[eid_str] = current_snapshot[eid_str]
		elif current_hashes[eid_str] != previous_hashes[eid_str]:
			changed[eid_str] = current_snapshot[eid_str]

	for eid_str: String in previous_hashes:
		if eid_str not in current_hashes:
			removed.append(eid_str)

	_last_snapshots[faction_id] = current_hashes
	return {"added": added, "changed": changed, "removed": removed}

# ---------------------------------------------------------------------------
# Apply delta/snapshot — client side
# ---------------------------------------------------------------------------

## Apply a delta to a client's local ECS mirror.
func apply_delta(delta: Dictionary, local_ecs: ECS) -> void:
	var added: Dictionary = delta.get("added", {})
	for eid_str: String in added:
		var entity_id: int = int(eid_str)
		if not local_ecs.entity_exists(entity_id):
			_force_create_entity(local_ecs, entity_id)
		_apply_components(local_ecs, entity_id, added[eid_str])

	var changed_entities: Dictionary = delta.get("changed", {})
	for eid_str: String in changed_entities:
		var entity_id: int = int(eid_str)
		if not local_ecs.entity_exists(entity_id):
			_force_create_entity(local_ecs, entity_id)
		_apply_components(local_ecs, entity_id, changed_entities[eid_str])

	var removed: Array = delta.get("removed", [])
	for eid_str in removed:
		var entity_id: int = int(eid_str)
		if local_ecs.entity_exists(entity_id):
			local_ecs.destroy_entity(entity_id)


## Apply a full snapshot to a client's local ECS (used on reconnect).
func apply_full_snapshot(snapshot: Dictionary, local_ecs: ECS) -> void:
	for entity_id: int in local_ecs.query([]):
		local_ecs.destroy_entity(entity_id)
	for eid_str: String in snapshot:
		var entity_id: int = int(eid_str)
		_force_create_entity(local_ecs, entity_id)
		_apply_components(local_ecs, entity_id, snapshot[eid_str])

# ---------------------------------------------------------------------------
# Checksum — desync detection (run every 100 ticks)
# ---------------------------------------------------------------------------

## Compute a simple checksum over all entity IDs and key component values.
static func compute_checksum(ecs: ECS) -> int:
	var hash_val: int = 0
	var entity_ids: Array[int] = ecs.query([])
	entity_ids.sort()

	for entity_id: int in entity_ids:
		hash_val = _hash_combine(hash_val, entity_id)
		if ecs.has_component(entity_id, "Position"):
			var pos: Dictionary = ecs.get_component(entity_id, "Position")
			hash_val = _hash_combine(hash_val, int(pos.get("x", 0.0) * 100))
			hash_val = _hash_combine(hash_val, int(pos.get("y", 0.0) * 100))
		if ecs.has_component(entity_id, "Health"):
			var hp: Dictionary = ecs.get_component(entity_id, "Health")
			hash_val = _hash_combine(hash_val, int(hp.get("current", 0.0) * 100))
	return hash_val

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _is_visible_to_faction(ecs: ECS, entity_id: int, faction_id: int, vision_system: VisionSystem) -> bool:
	if not ecs.has_component(entity_id, "FactionComponent"):
		return true
	var entity_faction: int = ecs.get_component(entity_id, "FactionComponent").get("faction_id", -1)
	if entity_faction == faction_id:
		return true
	if not ecs.has_component(entity_id, "Position"):
		return false
	var pos: Dictionary = ecs.get_component(entity_id, "Position")
	var world_pos := Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
	return vision_system.is_visible(faction_id, world_pos)


func _get_entity_data(ecs: ECS, entity_id: int) -> Dictionary:
	var data: Dictionary = {}
	if ecs._entities.has(entity_id):
		for comp_name: String in ecs._entities[entity_id]:
			data[comp_name] = ecs._entities[entity_id][comp_name].duplicate()
	return data


func _compute_hashes(snapshot: Dictionary) -> Dictionary:
	var hashes: Dictionary = {}
	for eid_str: String in snapshot:
		hashes[eid_str] = hash(str(snapshot[eid_str]))
	return hashes


func _force_create_entity(ecs: ECS, entity_id: int) -> void:
	if not ecs._entities.has(entity_id):
		ecs._entities[entity_id] = {}
	if entity_id >= ecs._next_id:
		ecs._next_id = entity_id + 1


func _apply_components(ecs: ECS, entity_id: int, components: Dictionary) -> void:
	for comp_name: String in components:
		ecs.set_component(entity_id, comp_name, components[comp_name])


static func _hash_combine(current: int, value: int) -> int:
	return (current * 16777619) ^ value
