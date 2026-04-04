class_name GameStats

# Tracks aggregate statistics throughout a match for post-game display.
# Updated by GameLoop (or directly by systems) via record_* methods.
# Read by VictoryScreen via get_summary().

var units_produced: Dictionary = {}    # faction_id (int) → count (int)
var units_lost: Dictionary = {}        # faction_id (int) → count (int)
var structures_built: Dictionary = {}  # faction_id (int) → count (int)
var resources_spent: Dictionary = {}   # faction_id (int) → { "primary": int, "secondary": int }
var superweapons_fired: int = 0
var game_start_tick: int = 0

const TICKS_PER_SECOND: float = 15.0


func record_unit_produced(faction_id: int) -> void:
	units_produced[faction_id] = units_produced.get(faction_id, 0) + 1


func record_unit_lost(faction_id: int) -> void:
	units_lost[faction_id] = units_lost.get(faction_id, 0) + 1


func record_structure_built(faction_id: int) -> void:
	structures_built[faction_id] = structures_built.get(faction_id, 0) + 1


func record_resources_spent(faction_id: int, primary: int, secondary: int) -> void:
	if not resources_spent.has(faction_id):
		resources_spent[faction_id] = {"primary": 0, "secondary": 0}
	resources_spent[faction_id]["primary"] += primary
	resources_spent[faction_id]["secondary"] += secondary


func get_summary(current_tick: int) -> Dictionary:
	var elapsed_ticks: int = current_tick - game_start_tick
	var duration_seconds: float = elapsed_ticks / TICKS_PER_SECOND

	return {
		"duration_seconds": duration_seconds,
		"duration_ticks": elapsed_ticks,
		"units_produced": units_produced.duplicate(),
		"units_lost": units_lost.duplicate(),
		"structures_built": structures_built.duplicate(),
		"resources_spent": resources_spent.duplicate(),
		"superweapons_fired": superweapons_fired,
	}


func reset() -> void:
	units_produced.clear()
	units_lost.clear()
	structures_built.clear()
	resources_spent.clear()
	superweapons_fired = 0
	game_start_tick = 0
