class_name TeamHistory
extends Node

# Tracks win/loss records for groups of players across sessions.
# Keyed by a stable hash derived from the sorted player name list.

const SAVE_PATH := "user://team_history.cfg"

# { team_hash: { wins, losses, games_played, favorite_map, longest_game_ticks,
#                map_counts: { map_name: count } } }
var _teams: Dictionary = {}


func _ready() -> void:
	load_from_disk()


# ── Public API ────────────────────────────────────────────────────────────────

func record_game(
		player_names: Array[String],
		won: bool,
		map: String,
		duration_ticks: int) -> void:
	if player_names.is_empty():
		push_warning("TeamHistory.record_game: player_names must not be empty")
		return

	var key: String = _team_key(player_names)
	_ensure_team(key)

	var entry: Dictionary = _teams[key] as Dictionary
	entry["games_played"] = (entry["games_played"] as int) + 1
	if won:
		entry["wins"] = (entry["wins"] as int) + 1
	else:
		entry["losses"] = (entry["losses"] as int) + 1

	if duration_ticks > (entry["longest_game_ticks"] as int):
		entry["longest_game_ticks"] = duration_ticks

	# Track map play counts to determine favourite.
	var map_counts: Dictionary = entry["map_counts"] as Dictionary
	map_counts[map] = map_counts.get(map, 0) as int + 1
	entry["favorite_map"] = _most_played_map(map_counts)


func get_team_stats(player_names: Array[String]) -> Dictionary:
	var key: String = _team_key(player_names)
	if not _teams.has(key):
		return {}
	var entry: Dictionary = (_teams[key] as Dictionary).duplicate(true)
	entry.erase("map_counts")  # Internal detail — callers don't need it.
	return entry


func format_summary(player_names: Array[String]) -> String:
	var stats: Dictionary = get_team_stats(player_names)
	if stats.is_empty():
		return "No history with this squad yet."

	var wins: int = stats.get("wins", 0) as int
	var games: int = stats.get("games_played", 0) as int
	var fav: String = stats.get("favorite_map", "") as String

	var base: String = "Your squad has won %d of %d game%s together" % [
		wins, games, ("s" if games != 1 else "")
	]
	if not fav.is_empty():
		base += " — favourite map: %s" % fav
	return base + "."


func save() -> void:
	var cfg := ConfigFile.new()
	for key: String in _teams:
		var entry: Dictionary = _teams[key] as Dictionary
		cfg.set_value(key, "wins", entry.get("wins", 0))
		cfg.set_value(key, "losses", entry.get("losses", 0))
		cfg.set_value(key, "games_played", entry.get("games_played", 0))
		cfg.set_value(key, "favorite_map", entry.get("favorite_map", ""))
		cfg.set_value(key, "longest_game_ticks", entry.get("longest_game_ticks", 0))
		# Serialise map_counts as a JSON string — ConfigFile doesn't support nested dicts.
		var mc: Dictionary = entry.get("map_counts", {}) as Dictionary
		cfg.set_value(key, "map_counts_json", JSON.stringify(mc))

	var err: int = cfg.save(SAVE_PATH)
	if err != OK:
		push_error("TeamHistory.save: failed to write '%s' (error %d)" % [SAVE_PATH, err])


func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(SAVE_PATH)
	if err == ERR_FILE_NOT_FOUND:
		return
	if err != OK:
		push_error("TeamHistory.load_from_disk: failed to read '%s' (error %d)" % [SAVE_PATH, err])
		return

	for key: String in cfg.get_sections():
		_ensure_team(key)
		var entry: Dictionary = _teams[key] as Dictionary
		entry["wins"]               = cfg.get_value(key, "wins", 0)
		entry["losses"]             = cfg.get_value(key, "losses", 0)
		entry["games_played"]       = cfg.get_value(key, "games_played", 0)
		entry["favorite_map"]       = cfg.get_value(key, "favorite_map", "")
		entry["longest_game_ticks"] = cfg.get_value(key, "longest_game_ticks", 0)

		var mc_json: String = cfg.get_value(key, "map_counts_json", "{}") as String
		var parsed = JSON.parse_string(mc_json)
		entry["map_counts"] = parsed if parsed is Dictionary else {}


# ── Private helpers ───────────────────────────────────────────────────────────

func _team_key(player_names: Array[String]) -> String:
	var sorted: Array[String] = player_names.duplicate()
	sorted.sort()
	return str(sorted.hash())


func _ensure_team(key: String) -> void:
	if _teams.has(key):
		return
	_teams[key] = {
		"wins": 0,
		"losses": 0,
		"games_played": 0,
		"favorite_map": "",
		"longest_game_ticks": 0,
		"map_counts": {},
	}


func _most_played_map(map_counts: Dictionary) -> String:
	var best_map: String = ""
	var best_count: int = 0
	for m: String in map_counts:
		var c: int = map_counts[m] as int
		if c > best_count:
			best_count = c
			best_map = m
	return best_map
