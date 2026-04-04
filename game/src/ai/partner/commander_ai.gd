class_name CommanderAI
extends AIPartner
## Commander AI partner — manages base building, tech progression, and responds
## to teammate needs. Follows a hardcoded build order, then adapts based on
## human pings and team requests.

const TICK_INTERVAL: int = 30  # run every 2 seconds at 15 ticks/s

const DEFAULT_BUILD_ORDER: Array = [
	{"tick_offset": 0,   "structure": "power_plant",  "offset": Vector2(4, 0)},
	{"tick_offset": 30,  "structure": "barracks",     "offset": Vector2(0, 4)},
	{"tick_offset": 75,  "structure": "refinery",     "offset": Vector2(-4, 0)},
	{"tick_offset": 150, "structure": "power_plant",  "offset": Vector2(6, 0)},
	{"tick_offset": 225, "structure": "war_factory",  "offset": Vector2(0, -4)},
	{"tick_offset": 300, "structure": "radar",        "offset": Vector2(4, 4)},
	{"tick_offset": 375, "structure": "tech_lab",     "offset": Vector2(-4, 4)},
]

## Default research priority once tech_lab is built.
const RESEARCH_PRIORITY: Array = ["armor_upgrade", "weapon_upgrade", "special"]

var _build_order_index: int = 0
var _game_start_tick: int = 0
var _base_position: Vector2 = Vector2.ZERO
var _pending_research: Array = []
var _built_structures: Array = []  # structure type strings
var _power_net: float = 0.0  # set externally or via game state
var _extra_power_plant_count: int = 0
var _research_in_progress: String = ""


func _init() -> void:
	role = "commander"


func initialize_base(base_pos: Vector2, start_tick: int) -> void:
	_base_position = base_pos
	_game_start_tick = start_tick


func set_power_net(value: float) -> void:
	_power_net = value


func _ai_tick(tick_count: int) -> void:
	if tick_count % TICK_INTERVAL != 0:
		return

	var elapsed: int = tick_count - _game_start_tick

	# 1. Check human pings first — human intent takes priority
	_respond_to_human_pings(tick_count)

	# 2. Follow build order
	_advance_build_order(elapsed, tick_count)

	# 3. Manage tech research
	_manage_research(tick_count)

	# 4. Respond to QM structure requests
	_handle_structure_requests(tick_count)

	# 5. Power management — build more power plants if net negative
	_manage_power(tick_count)


func _advance_build_order(elapsed_ticks: int, tick_count: int) -> void:
	while _build_order_index < DEFAULT_BUILD_ORDER.size():
		var order: Dictionary = DEFAULT_BUILD_ORDER[_build_order_index]
		if elapsed_ticks < order["tick_offset"]:
			break
		# Idempotent — skip if structure type already built
		if not _built_structures.has(order["structure"]):
			var pos: Vector2 = _base_position + order["offset"] * 32.0
			_emit_command("PlaceStructure", {
				"structure_type": order["structure"],
				"position": pos,
			})
			_built_structures.append(order["structure"])
			send_status("Building " + order["structure"], tick_count)
		_build_order_index += 1


func _respond_to_human_pings(tick_count: int) -> void:
	for ping in recent_pings:
		match ping["type"]:
			"build_here":
				_emit_command("PlaceStructure", {
					"structure_type": "turret",
					"position": ping["position"],
				})
				send_status("Building turret at ping", tick_count)
			"expand":
				_emit_command("PlaceStructure", {
					"structure_type": "refinery",
					"position": ping["position"],
				})
				send_status("Expanding to pinged location", tick_count)
	recent_pings.clear()


func _manage_research(tick_count: int) -> void:
	# Only research once tech_lab is built
	if not _built_structures.has("tech_lab"):
		return
	if _research_in_progress != "":
		return
	for tech in RESEARCH_PRIORITY:
		if not _pending_research.has(tech):
			_emit_command("StartResearch", {"research_type": tech})
			_pending_research.append(tech)
			_research_in_progress = tech
			send_status("Researching " + tech, tick_count)
			break


func _handle_structure_requests(_tick_count: int) -> void:
	# Stub — will respond to Quartermaster requests for factories/refineries
	pass


func _manage_power(tick_count: int) -> void:
	if _power_net >= 0.0:
		return
	# Build an emergency power plant offset from base
	_extra_power_plant_count += 1
	var offset := Vector2(8 + _extra_power_plant_count * 2, 0)
	var pos: Vector2 = _base_position + offset * 32.0
	_emit_command("PlaceStructure", {
		"structure_type": "power_plant",
		"position": pos,
	})
	send_status("Low power — building emergency power plant", tick_count)
