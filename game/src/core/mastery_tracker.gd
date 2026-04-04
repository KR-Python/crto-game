class_name MasteryTracker
extends Node

# Tracks per-role statistics across games, persisted to disk.
# Cosmetic only — no gameplay impact, no pay-to-win.

const SAVE_PATH := "user://mastery.cfg"

# Games-played thresholds for each mastery level (1-10).
const LEVEL_THRESHOLDS: Array[int] = [0, 1, 3, 6, 10, 25, 40, 60, 80, 100]

const MASTERY_TITLES: Dictionary = {
	"commander": [
		"Recruit", "Lieutenant", "Captain", "Major", "Colonel",
		"Brigadier", "General", "Field General", "Grand Marshal", "Supreme Commander"
	],
	"quartermaster": [
		"Supply Clerk", "Logistics Officer", "Supply Sergeant", "Chief Supply",
		"Logistics Master", "Supply Admiral", "Grand Quartermaster",
		"Logistics Legend", "Supply Overlord", "Logistics God"
	],
	"field_marshal": [
		"Soldier", "Corporal", "Sergeant", "Lieutenant", "Captain",
		"Major", "Colonel", "General", "War Hero", "Legend of War"
	],
	"spec_ops": [
		"Recruit", "Scout", "Infiltrator", "Shadow", "Ghost",
		"Phantom", "Specter", "Wraith", "Silent Blade", "The Ghost"
	],
	"chief_engineer": [
		"Apprentice", "Engineer", "Senior Engineer", "Chief Engineer",
		"Master Builder", "Fortress Architect", "Grand Engineer",
		"Fortification Expert", "Master of Walls", "The Architect"
	],
	"air_marshal": [
		"Pilot", "Flight Officer", "Squadron Leader", "Wing Commander",
		"Group Captain", "Air Commodore", "Air Vice Marshal", "Air Marshal",
		"Air Chief", "Sky Emperor"
	],
}

# Default stat templates per role.
const ROLE_STAT_DEFAULTS: Dictionary = {
	"commander": {
		"games_played": 0,
		"structures_placed": 0,
		"tech_researched": 0,
		"expansions_built": 0,
	},
	"quartermaster": {
		"games_played": 0,
		"units_produced": 0,
		"factories_never_idled": 0,  # count of games with 100% efficiency
		"ore_harvested": 0,
	},
	"field_marshal": {
		"games_played": 0,
		"kills": 0,
		"units_lost": 0,
		"battles_won": 0,
		"battles_lost": 0,
	},
	"spec_ops": {
		"games_played": 0,
		"sabotages_completed": 0,
		"structures_destroyed": 0,
		"intel_reports": 0,
	},
	"chief_engineer": {
		"games_played": 0,
		"structures_repaired": 0,
		"walls_placed": 0,
		"mines_triggered": 0,
	},
	"air_marshal": {
		"games_played": 0,
		"bombing_runs": 0,
		"paradrops": 0,
		"air_kills": 0,
	},
}

# In-memory store: { role -> { stat_key -> int } }
var _data: Dictionary = {}


func _ready() -> void:
	load_from_disk()


# ── Public API ────────────────────────────────────────────────────────────────

func record_stat(role: String, stat: String, amount: int = 1) -> void:
	if not ROLE_STAT_DEFAULTS.has(role):
		push_warning("MasteryTracker.record_stat: unknown role '%s'" % role)
		return
	_ensure_role(role)
	if not _data[role].has(stat):
		push_warning("MasteryTracker.record_stat: unknown stat '%s' for role '%s'" % [stat, role])
		return
	_data[role][stat] = (_data[role][stat] as int) + amount


func get_stats(role: String) -> Dictionary:
	if not ROLE_STAT_DEFAULTS.has(role):
		push_warning("MasteryTracker.get_stats: unknown role '%s'" % role)
		return {}
	_ensure_role(role)
	return _data[role].duplicate()


func get_mastery_level(role: String) -> int:
	# Level 1-10 driven by games_played; returns 1 if the role has never been played.
	_ensure_role(role)
	var games: int = _data[role].get("games_played", 0) as int
	return _games_to_level(games)


func get_mastery_title(role: String) -> String:
	if not MASTERY_TITLES.has(role):
		return "Unknown"
	var level: int = get_mastery_level(role)
	var titles: Array = MASTERY_TITLES[role] as Array
	# level is 1-10; array is 0-indexed
	return titles[clampi(level - 1, 0, titles.size() - 1)] as String


func save() -> void:
	var cfg := ConfigFile.new()
	for role: String in _data:
		for stat: String in _data[role]:
			cfg.set_value(role, stat, _data[role][stat])
	var err: int = cfg.save(SAVE_PATH)
	if err != OK:
		push_error("MasteryTracker.save: failed to write '%s' (error %d)" % [SAVE_PATH, err])


func load_from_disk() -> void:
	# Seed with defaults first so missing keys are always present.
	for role: String in ROLE_STAT_DEFAULTS:
		_ensure_role(role)

	var cfg := ConfigFile.new()
	var err: int = cfg.load(SAVE_PATH)
	if err == ERR_FILE_NOT_FOUND:
		return  # First launch — defaults are fine.
	if err != OK:
		push_error("MasteryTracker.load_from_disk: failed to read '%s' (error %d)" % [SAVE_PATH, err])
		return

	for role: String in cfg.get_sections():
		if not _data.has(role):
			continue  # Ignore unknown roles from old saves.
		for stat: String in cfg.get_section_keys(role):
			if _data[role].has(stat):
				_data[role][stat] = cfg.get_value(role, stat, 0)


# ── Private helpers ───────────────────────────────────────────────────────────

func _ensure_role(role: String) -> void:
	if _data.has(role):
		return
	var defaults: Dictionary = ROLE_STAT_DEFAULTS.get(role, {}) as Dictionary
	_data[role] = defaults.duplicate(true)


func _games_to_level(games: int) -> int:
	# Walks thresholds from highest to lowest; returns the highest level reached.
	var level: int = 1
	for i: int in range(LEVEL_THRESHOLDS.size()):
		if games >= LEVEL_THRESHOLDS[i]:
			level = i + 1
	return clampi(level, 1, 10)
