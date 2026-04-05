class_name ECS
extends Node

# Optimized ECS — component-store-centric with small-store-first query intersection.
#
# Phase 6 optimizations:
# 1. Component-centric storage: _stores[component_name][entity_id] = data
#    - Iteration over a component type is O(n) where n = entities with that component
# 2. Small-store-first query: intersect starting from the smallest store
#    - For query(["Position", "Health", "Faction"]) with 300 entities, ~O(300)
# 3. Query cache: repeated identical queries within the same tick return cached results
#    - Vision + Combat + Stealth all query ["Position", "Faction"] — computed once
# 4. Compatibility: maintains full API from original ECS (entity_exists, set_component, etc.)

var _stores: Dictionary = {}        # String -> Dictionary{int -> Dictionary}
var _entity_set: Dictionary = {}    # int -> Dictionary (component_name -> true)
var _next_id: int = 1

var _query_cache: Dictionary = {}
var _cache_valid: bool = true

# -- Entity lifecycle ----------------------------------------------------------

func create_entity() -> int:
	var id: int = _next_id
	_next_id += 1
	_entity_set[id] = {}
	_invalidate_cache()
	return id


func destroy_entity(entity_id: int) -> void:
	if not _entity_set.has(entity_id):
		return
	var comp_names: Dictionary = _entity_set[entity_id]
	for cname in comp_names:
		if _stores.has(cname):
			_stores[cname].erase(entity_id)
	_entity_set.erase(entity_id)
	_invalidate_cache()


func entity_exists(entity_id: int) -> bool:
	return _entity_set.has(entity_id)


func is_alive(entity_id: int) -> bool:
	return _entity_set.has(entity_id)


func entity_count() -> int:
	return _entity_set.size()


# -- Component access ----------------------------------------------------------

func add_component(entity_id: int, component_name: String, data: Dictionary = {}) -> void:
	if not _entity_set.has(entity_id):
		push_error("ECS.add_component: entity %d does not exist" % entity_id)
		return
	if not _stores.has(component_name):
		_stores[component_name] = {}
	_stores[component_name][entity_id] = data
	_entity_set[entity_id][component_name] = true
	_invalidate_cache()


func set_component(entity_id: int, component_name: String, data: Dictionary = {}) -> void:
	add_component(entity_id, component_name, data)


func get_component(entity_id: int, component_name: String) -> Dictionary:
	if _stores.has(component_name) and _stores[component_name].has(entity_id):
		return _stores[component_name][entity_id]
	return {}


func has_component(entity_id: int, component_name: String) -> bool:
	return _entity_set.has(entity_id) and _entity_set[entity_id].has(component_name)


func remove_component(entity_id: int, component_name: String) -> void:
	if _stores.has(component_name):
		_stores[component_name].erase(entity_id)
	if _entity_set.has(entity_id):
		_entity_set[entity_id].erase(component_name)
	_invalidate_cache()


# -- Queries (small-store-first intersection + cache) --------------------------

func query(component_names) -> Array[int]:
	if component_names.is_empty():
		return [] as Array[int]

	var sorted_names: Array = []
	for n in component_names:
		sorted_names.append(n)
	sorted_names.sort()
	var cache_key: String = "|".join(sorted_names)

	if _cache_valid and _query_cache.has(cache_key):
		return _query_cache[cache_key]

	# Find smallest store for intersection pivot
	var smallest_store: Dictionary = {}
	var smallest_size: int = 999999999
	for cname in component_names:
		if not _stores.has(cname):
			_query_cache[cache_key] = [] as Array[int]
			return [] as Array[int]
		var store: Dictionary = _stores[cname]
		if store.size() < smallest_size:
			smallest_size = store.size()
			smallest_store = store

	# Intersect: iterate smallest, check membership in others
	var result: Array[int] = []
	for eid in smallest_store:
		var has_all: bool = true
		for cname in component_names:
			if not _stores[cname].has(eid):
				has_all = false
				break
		if has_all:
			result.append(eid)

	_query_cache[cache_key] = result
	return result


func query_exclude(required, excluded) -> Array[int]:
	var base: Array[int] = query(required)
	if excluded.is_empty():
		return base
	var result: Array[int] = []
	for eid in base:
		var dominated: bool = false
		for cname in excluded:
			if has_component(eid, cname):
				dominated = true
				break
		if not dominated:
			result.append(eid)
	return result


func query_with_components(component_names) -> Array[int]:
	return query(component_names)


func get_entities_with_component(component_name: String) -> Array:
	if _stores.has(component_name):
		return _stores[component_name].keys()
	return []


func get_store(component_name: String) -> Dictionary:
	if _stores.has(component_name):
		return _stores[component_name]
	return {}


# -- Cache management ----------------------------------------------------------

func _invalidate_cache() -> void:
	_cache_valid = false


func begin_tick() -> void:
	_cache_valid = true
	_query_cache.clear()
