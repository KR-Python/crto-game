class_name ECS
extends Node

# Minimal ECS — dictionary-of-dictionaries.
# entities[entity_id][component_name] = component_data (Dictionary)
# Tag components are empty dictionaries: {}

var _entities: Dictionary = {}       # entity_id -> { component_name -> data }
var _next_id: int = 1

# ── Entity lifecycle ──────────────────────────────────────────────────────────

func create_entity() -> int:
	var id: int = _next_id
	_next_id += 1
	_entities[id] = {}
	return id


func destroy_entity(entity_id: int) -> void:
	_entities.erase(entity_id)


func entity_exists(entity_id: int) -> bool:
	return _entities.has(entity_id)


# ── Component access ──────────────────────────────────────────────────────────

func add_component(entity_id: int, component_name: String, data: Dictionary = {}) -> void:
	if not _entities.has(entity_id):
		push_error("ECS.add_component: entity %d does not exist" % entity_id)
		return
	_entities[entity_id][component_name] = data


func get_component(entity_id: int, component_name: String) -> Dictionary:
	if not _entities.has(entity_id):
		return {}
	return _entities[entity_id].get(component_name, {})


func has_component(entity_id: int, component_name: String) -> bool:
	if not _entities.has(entity_id):
		return false
	return _entities[entity_id].has(component_name)


func remove_component(entity_id: int, component_name: String) -> void:
	if _entities.has(entity_id):
		_entities[entity_id].erase(component_name)


# ── Queries ───────────────────────────────────────────────────────────────────

## Returns all entity IDs that have ALL of the listed components.
func query(component_names: Array[String]) -> Array[int]:
	var result: Array[int] = []
	for entity_id: int in _entities:
		var components: Dictionary = _entities[entity_id]
		var has_all: bool = true
		for cn: String in component_names:
			if not components.has(cn):
				has_all = false
				break
		if has_all:
			result.append(entity_id)
	return result


## Returns all entity IDs that have ALL required AND NONE of the excluded components.
func query_exclude(required: Array[String], excluded: Array[String]) -> Array[int]:
	var result: Array[int] = []
	for entity_id: int in _entities:
		var components: Dictionary = _entities[entity_id]
		var has_all: bool = true
		for cn: String in required:
			if not components.has(cn):
				has_all = false
				break
		if not has_all:
			continue
		var has_excluded: bool = false
		for cn: String in excluded:
			if components.has(cn):
				has_excluded = true
				break
		if not has_excluded:
			result.append(entity_id)
	return result

func set_component(entity_id: int, component_name: String, data: Dictionary = {}) -> void:
	add_component(entity_id, component_name, data)

func query_with_components(component_names: Array[String]) -> Array[int]:
	return query(component_names)

func is_alive(entity_id: int) -> bool:
	return entity_exists(entity_id)

func get_entities_with_component(component_name: String) -> Array[int]:
	var result: Array[int] = []
	for entity_id: int in _entities:
		if _entities[entity_id].has(component_name):
			result.append(entity_id)
	return result
