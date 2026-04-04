class_name EconomySystem

# ECS system — tick pipeline step 4.
# Manages harvester state machine, per-faction resource pools, and power grid.
# All resources are integers internally — no float rounding bugs.

const TICK_RATE: int = 15  # ticks per second
const TICK_DURATION: float = 1.0 / TICK_RATE

# Per-faction resource pools: faction_id -> { primary, secondary, income_rate, spend_rate }
var _faction_resources: Dictionary = {}

# Rolling spend tracking for spend_rate calculation
var _spend_history: Dictionary = {}  # faction_id -> Array[int] (last N ticks total spend)
const SPEND_HISTORY_WINDOW: int = 15  # 1 second of ticks


# ── Public API ────────────────────────────────────────────────────────────────

func get_resources(faction_id: int) -> Dictionary:
	_ensure_faction(faction_id)
	var res: Dictionary = _faction_resources[faction_id]
	return {
		"primary": res.primary,
		"secondary": res.secondary,
		"income_rate": res.income_rate,
		"spend_rate": res.spend_rate,
	}


func spend(faction_id: int, primary: int, secondary: int) -> bool:
	_ensure_faction(faction_id)
	var res: Dictionary = _faction_resources[faction_id]
	if res.primary < primary or res.secondary < secondary:
		return false
	res.primary -= primary
	res.secondary -= secondary
	# Track spending
	if not _spend_history.has(faction_id):
		_spend_history[faction_id] = []
	var hist: Array = _spend_history[faction_id]
	if hist.size() > 0:
		hist[hist.size() - 1] += primary + secondary
	return true


func add_income(faction_id: int, amount: int, resource_type: String) -> void:
	_ensure_faction(faction_id)
	var res: Dictionary = _faction_resources[faction_id]
	if resource_type == "primary":
		res.primary += amount
	elif resource_type == "secondary":
		res.secondary += amount


func get_power_status(faction_id: int) -> Dictionary:
	return _faction_resources.get(faction_id, {}).get("_power_cache", {
		"produced": 0,
		"consumed": 0,
		"net": 0,
		"buildings_offline": 0,
	})


# ── Main tick ─────────────────────────────────────────────────────────────────

func tick(ecs: ECS, tick_count: int) -> void:
	# Collect all faction IDs from entities
	var faction_ids: Dictionary = {}
	for eid: int in ecs.query(["FactionComponent"] as Array[String]):
		var fc: Dictionary = ecs.get_component(eid, "FactionComponent")
		faction_ids[fc.faction_id] = true

	for fid: int in faction_ids:
		_ensure_faction(fid)
		# Reset per-tick income tracking
		_faction_resources[fid].tick_income = 0

	# 1. Power grid
	for fid: int in faction_ids:
		_update_power_grid(ecs, fid)

	# 2. Harvester state machines
	_update_harvesters(ecs, tick_count)

	# 3. Update income/spend rates
	for fid: int in faction_ids:
		_update_rates(fid)


# ── Power Grid ────────────────────────────────────────────────────────────────

func _update_power_grid(ecs: ECS, faction_id: int) -> void:
	var produced: int = 0
	var consumed: int = 0

	# Sum producers
	for eid: int in ecs.query(["PowerProducer", "FactionComponent"] as Array[String]):
		var fc: Dictionary = ecs.get_component(eid, "FactionComponent")
		if fc.faction_id != faction_id:
			continue
		var pp: Dictionary = ecs.get_component(eid, "PowerProducer")
		produced += int(pp.output)

	# Collect consumers with priority
	var consumers: Array[Dictionary] = []
	for eid: int in ecs.query(["PowerConsumer", "FactionComponent"] as Array[String]):
		var fc: Dictionary = ecs.get_component(eid, "FactionComponent")
		if fc.faction_id != faction_id:
			continue
		var pc: Dictionary = ecs.get_component(eid, "PowerConsumer")
		consumers.append({
			"entity_id": eid,
			"drain": int(pc.drain),
			"priority": pc.get("priority", 3),
		})

	# Sort by priority ascending (lowest priority shuts off first)
	consumers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.priority < b.priority
	)

	# Calculate total consumption
	for c: Dictionary in consumers:
		consumed += c.drain

	var net: int = produced - consumed
	var buildings_offline: int = 0

	# Determine which consumers to shut off
	var offline_set: Dictionary = {}
	if net < 0:
		var deficit: int = -net
		for c: Dictionary in consumers:
			if deficit <= 0:
				break
			offline_set[c.entity_id] = true
			deficit -= c.drain
			buildings_offline += 1

	# Apply PoweredOff tags
	for c: Dictionary in consumers:
		if offline_set.has(c.entity_id):
			ecs.add_component(c.entity_id, "PoweredOff", {})
		else:
			if ecs.has_component(c.entity_id, "PoweredOff"):
				ecs.remove_component(c.entity_id, "PoweredOff")

	_faction_resources[faction_id]["_power_cache"] = {
		"produced": produced,
		"consumed": consumed,
		"net": produced - consumed,
		"buildings_offline": buildings_offline,
	}


# ── Harvester State Machine ──────────────────────────────────────────────────

func _update_harvesters(ecs: ECS, tick_count: int) -> void:
	for eid: int in ecs.query(["Harvester", "FactionComponent", "Position"] as Array[String]):
		var h: Dictionary = ecs.get_component(eid, "Harvester")
		var faction: Dictionary = ecs.get_component(eid, "FactionComponent")
		var pos: Dictionary = ecs.get_component(eid, "Position")
		var fid: int = faction.faction_id
		_ensure_faction(fid)

		var state: String = h.get("state", "idle")

		match state:
			"idle":
				_harvester_idle(ecs, eid, h, pos, fid)
			"moving_to_node":
				_harvester_moving_to_node(ecs, eid, h, pos, fid)
			"harvesting":
				_harvester_harvesting(ecs, eid, h, pos, fid)
			"returning":
				_harvester_returning(ecs, eid, h, pos, fid)


func _harvester_idle(ecs: ECS, eid: int, h: Dictionary, pos: Dictionary, faction_id: int) -> void:
	var node_id: int = _find_nearest_resource_node(ecs, pos, h.get("resource_type", "primary"))
	if node_id < 0:
		return  # No nodes available — stay idle
	h.state = "moving_to_node"
	h.target_node = node_id
	ecs.add_component(eid, "Harvester", h)
	# Issue move command to node position
	var node_pos: Dictionary = ecs.get_component(node_id, "Position")
	ecs.add_component(eid, "MoveCommand", {
		"destination_x": node_pos.x,
		"destination_y": node_pos.y,
		"queued": false,
	})


func _harvester_moving_to_node(ecs: ECS, eid: int, h: Dictionary, pos: Dictionary, faction_id: int) -> void:
	var target: int = h.get("target_node", -1)
	# Check if node still exists and has resources
	if target < 0 or not ecs.entity_exists(target):
		h.state = "idle"
		ecs.add_component(eid, "Harvester", h)
		return
	if not ecs.has_component(target, "ResourceNode"):
		h.state = "idle"
		ecs.add_component(eid, "Harvester", h)
		return
	var node_res: Dictionary = ecs.get_component(target, "ResourceNode")
	if node_res.remaining <= 0:
		h.state = "idle"
		ecs.add_component(eid, "Harvester", h)
		return

	# Check proximity (within 1 tile = 32 pixels)
	var node_pos: Dictionary = ecs.get_component(target, "Position")
	var dist: float = _distance(pos, node_pos)
	if dist <= 32.0:
		h.state = "harvesting"
		ecs.add_component(eid, "Harvester", h)
		# Remove move command
		ecs.remove_component(eid, "MoveCommand")


func _harvester_harvesting(ecs: ECS, eid: int, h: Dictionary, pos: Dictionary, faction_id: int) -> void:
	var target: int = h.get("target_node", -1)
	if target < 0 or not ecs.entity_exists(target) or not ecs.has_component(target, "ResourceNode"):
		h.state = "idle"
		ecs.add_component(eid, "Harvester", h)
		return

	var node_res: Dictionary = ecs.get_component(target, "ResourceNode")
	if node_res.remaining <= 0:
		# Node depleted mid-harvest — go idle to find new node
		h.state = "idle"
		ecs.add_component(eid, "Harvester", h)
		return

	var harvest_rate: float = h.get("harvest_rate", 10.0)
	var harvest_amount: int = int(harvest_rate * TICK_DURATION)  # floor
	if harvest_amount < 1:
		harvest_amount = 1  # minimum 1 per tick if rate > 0

	# Clamp to what's available in the node
	harvest_amount = mini(harvest_amount, int(node_res.remaining))
	# Clamp to remaining capacity
	var capacity: int = int(h.get("capacity", 100))
	var current_load: int = int(h.get("current_load", 0))
	harvest_amount = mini(harvest_amount, capacity - current_load)

	current_load += harvest_amount
	h.current_load = current_load
	node_res.remaining -= harvest_amount
	ecs.add_component(target, "ResourceNode", node_res)

	if current_load >= capacity or node_res.remaining <= 0:
		h.state = "returning"

	ecs.add_component(eid, "Harvester", h)

	if h.state == "returning":
		_issue_return_command(ecs, eid, h)


func _harvester_returning(ecs: ECS, eid: int, h: Dictionary, pos: Dictionary, faction_id: int) -> void:
	var refinery_id: int = h.get("home_refinery", -1)

	# Check if home refinery still exists
	if refinery_id < 0 or not ecs.entity_exists(refinery_id):
		# Find nearest other refinery
		refinery_id = _find_nearest_refinery(ecs, pos, faction_id)
		if refinery_id < 0:
			# No refineries — idle with load
			h.state = "idle"
			h.home_refinery = -1
			ecs.add_component(eid, "Harvester", h)
			return
		h.home_refinery = refinery_id
		ecs.add_component(eid, "Harvester", h)
		# Re-issue move to new refinery
		_issue_return_command(ecs, eid, h)
		return

	# Check proximity to refinery
	var ref_pos: Dictionary = ecs.get_component(refinery_id, "Position")
	var dist: float = _distance(pos, ref_pos)
	if dist <= 32.0:
		# Deposit
		var load: int = int(h.get("current_load", 0))
		var res_type: String = h.get("resource_type", "primary")
		add_income(faction_id, load, res_type)
		_faction_resources[faction_id].tick_income += load
		h.current_load = 0
		h.state = "idle"
		ecs.add_component(eid, "Harvester", h)
		ecs.remove_component(eid, "MoveCommand")


func _issue_return_command(ecs: ECS, eid: int, h: Dictionary) -> void:
	var refinery_id: int = h.get("home_refinery", -1)
	if refinery_id < 0 or not ecs.entity_exists(refinery_id):
		return
	var ref_pos: Dictionary = ecs.get_component(refinery_id, "Position")
	ecs.add_component(eid, "MoveCommand", {
		"destination_x": ref_pos.x,
		"destination_y": ref_pos.y,
		"queued": false,
	})


# ── Helpers ───────────────────────────────────────────────────────────────────

func _find_nearest_resource_node(ecs: ECS, pos: Dictionary, resource_type: String) -> int:
	var best_id: int = -1
	var best_dist: float = INF
	for nid: int in ecs.query(["ResourceNode", "Position"] as Array[String]):
		var node_res: Dictionary = ecs.get_component(nid, "ResourceNode")
		if node_res.remaining <= 0:
			continue
		if node_res.type != resource_type:
			continue
		var node_pos: Dictionary = ecs.get_component(nid, "Position")
		var dist: float = _distance(pos, node_pos)
		if dist < best_dist:
			best_dist = dist
			best_id = nid
	return best_id


func _find_nearest_refinery(ecs: ECS, pos: Dictionary, faction_id: int) -> int:
	var best_id: int = -1
	var best_dist: float = INF
	for rid: int in ecs.query(["Structure", "FactionComponent", "Position"] as Array[String]):
		var fc: Dictionary = ecs.get_component(rid, "FactionComponent")
		if fc.faction_id != faction_id:
			continue
		var s: Dictionary = ecs.get_component(rid, "Structure")
		if not s.get("is_refinery", false):
			continue
		var ref_pos: Dictionary = ecs.get_component(rid, "Position")
		var dist: float = _distance(pos, ref_pos)
		if dist < best_dist:
			best_dist = dist
			best_id = rid
	return best_id


func _distance(a: Dictionary, b: Dictionary) -> float:
	var dx: float = float(a.x) - float(b.x)
	var dy: float = float(a.y) - float(b.y)
	return sqrt(dx * dx + dy * dy)


func _ensure_faction(faction_id: int) -> void:
	if not _faction_resources.has(faction_id):
		_faction_resources[faction_id] = {
			"primary": 0,
			"secondary": 0,
			"income_rate": 0.0,
			"spend_rate": 0.0,
			"tick_income": 0,
			"_power_cache": {
				"produced": 0,
				"consumed": 0,
				"net": 0,
				"buildings_offline": 0,
			},
		}
		_spend_history[faction_id] = []


func _update_rates(faction_id: int) -> void:
	var res: Dictionary = _faction_resources[faction_id]
	# Income rate: resources deposited this tick × tick rate
	res.income_rate = float(res.tick_income) * TICK_RATE

	# Spend rate: rolling average over window
	if not _spend_history.has(faction_id):
		_spend_history[faction_id] = []
	var hist: Array = _spend_history[faction_id]
	hist.append(0)  # new tick slot
	if hist.size() > SPEND_HISTORY_WINDOW:
		hist.pop_front()
	var total_spent: int = 0
	for s: int in hist:
		total_spent += s
	res.spend_rate = float(total_spent) * TICK_RATE / float(hist.size())
