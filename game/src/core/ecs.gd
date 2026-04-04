class_name ECS
## Lightweight Entity Component System for CRTO.
## Stores components as: { component_name: { entity_id: data_dict } }
## Entities tracked via _alive dict for O(1) lookup.

signal entity_created(entity_id: int)
signal entity_destroyed(entity_id: int)
signal component_added(entity_id: int, component_name: String)
signal component_removed(entity_id: int, component_name: String)

var _next_id: int = 1
var _alive: Dictionary = {}  # { entity_id: true }
var _components: Dictionary = {}  # { component_name: { entity_id: data_dict } }
var _query_result: Array[int] = []  # pre-allocated for query reuse


func create_entity() -> int:
	var id := _next_id
	_next_id += 1
	_alive[id] = true
	entity_created.emit(id)
	return id


func destroy_entity(entity_id: int) -> void:
	if not _alive.has(entity_id):
		return
	_alive.erase(entity_id)
	# Remove from all component stores
	for comp_name in _components:
		var store: Dictionary = _components[comp_name]
		if store.has(entity_id):
			store.erase(entity_id)
	entity_destroyed.emit(entity_id)


func is_alive(entity_id: int) -> bool:
	return _alive.has(entity_id)


func add_component(entity_id: int, component_name: String, data: Dictionary) -> void:
	if not _alive.has(entity_id):
		push_warning("ECS: add_component on dead entity %d" % entity_id)
		return
	if not _components.has(component_name):
		_components[component_name] = {}
	_components[component_name][entity_id] = data
	component_added.emit(entity_id, component_name)


func remove_component(entity_id: int, component_name: String) -> void:
	if _components.has(component_name):
		var store: Dictionary = _components[component_name]
		if store.has(entity_id):
			store.erase(entity_id)
			component_removed.emit(entity_id, component_name)


func has_component(entity_id: int, component_name: String) -> bool:
	if not _components.has(component_name):
		return false
	return _components[component_name].has(entity_id)


func get_component(entity_id: int, component_name: String) -> Dictionary:
	if _components.has(component_name):
		var store: Dictionary = _components[component_name]
		if store.has(entity_id):
			return store[entity_id]
	return {}


func set_component(entity_id: int, component_name: String, data: Dictionary) -> void:
	if not _alive.has(entity_id):
		push_warning("ECS: set_component on dead entity %d" % entity_id)
		return
	if not _components.has(component_name):
		_components[component_name] = {}
	_components[component_name][entity_id] = data


func query(required_components: Array[String]) -> Array[int]:
	_query_result.clear()
	if required_components.is_empty():
		return _query_result

	# Find the smallest component store to start intersection
	var smallest_name: String = required_components[0]
	var smallest_size: int = _get_store_size(smallest_name)
	for i in range(1, required_components.size()):
		var s := _get_store_size(required_components[i])
		if s < smallest_size:
			smallest_size = s
			smallest_name = required_components[i]

	if smallest_size == 0:
		return _query_result

	var smallest_store: Dictionary = _components.get(smallest_name, {})

	# Iterate smallest store and check membership in all others
	for eid in smallest_store:
		var match := true
		for comp_name in required_components:
			if comp_name == smallest_name:
				continue
			if not _components.has(comp_name) or not _components[comp_name].has(eid):
				match = false
				break
		if match:
			_query_result.append(eid)

	return _query_result


func query_with_data(required_components: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids := query(required_components)
	for eid in ids:
		var entry: Dictionary = {"entity_id": eid}
		for comp_name in required_components:
			entry[comp_name] = _components[comp_name][eid]
		result.append(entry)
	return result


func _get_store_size(component_name: String) -> int:
	if not _components.has(component_name):
		return 0
	return _components[component_name].size()
