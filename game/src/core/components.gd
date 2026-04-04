class_name Components
## Static factory functions returning properly structured component dictionaries.


# --- Identity ---

static func entity_id(id: int) -> Dictionary:
	return {"entity_id": id}


static func faction(faction_id: int) -> Dictionary:
	return {"faction_id": faction_id}


static func role_ownership(role: String, transferable: bool = false) -> Dictionary:
	return {"role": role, "transferable": transferable}


# --- Spatial ---

static func position(x: float, y: float) -> Dictionary:
	return {"x": x, "y": y}


static func velocity(x: float = 0.0, y: float = 0.0) -> Dictionary:
	return {"x": x, "y": y}


# --- Combat ---

static func health(max_hp: float, armor_type: String = "medium") -> Dictionary:
	return {"current": max_hp, "max": max_hp, "armor_type": armor_type}


static func weapon(damage: float, range_val: float, cooldown: float, damage_type: String, targets: Array) -> Dictionary:
	return {
		"damage": damage, "range": range_val, "cooldown": cooldown,
		"cooldown_remaining": 0.0, "damage_type": damage_type, "targets": targets
	}


# --- Movement ---

static func move_speed(speed: float) -> Dictionary:
	return {"speed": speed}


static func move_command(destination: Vector2, queued: bool = false) -> Dictionary:
	return {"destination": destination, "queued": queued}


static func path_state() -> Dictionary:
	return {"path": [], "current_index": 0}


# --- Economy ---

static func harvester(capacity: float, resource_type: String = "ore") -> Dictionary:
	return {"capacity": capacity, "current_load": 0.0, "resource_type": resource_type, "state": "idle"}


static func resource_node(resource_type: String, amount: float) -> Dictionary:
	return {"type": resource_type, "remaining": amount}


static func production_queue() -> Dictionary:
	return {"queue": [], "progress": 0.0, "rate": 1.0}


# --- Structure ---

static func structure(build_time: float = 0.0) -> Dictionary:
	return {"built": build_time == 0.0, "build_progress": 0.0, "build_time": build_time}


static func power_consumer(drain: float) -> Dictionary:
	return {"drain": drain}


static func power_producer(output: float) -> Dictionary:
	return {"output": output}


# --- Visibility ---

static func vision_range(vis_range: float) -> Dictionary:
	return {"range": vis_range}


# --- Role tags (empty dicts — pure tags) ---

static func commander_controlled() -> Dictionary:
	return {}


static func quartermaster_controlled() -> Dictionary:
	return {}


static func field_marshal_controlled() -> Dictionary:
	return {}


static func spec_ops_controlled() -> Dictionary:
	return {}
