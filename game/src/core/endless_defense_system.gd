# EndlessDefenseSystem — wave manager for Endless Defense mode.
# Handles wave generation, enemy tracking, resource payouts, and game-over detection.
# All unit budget math must stay deterministic — uses SimRandom, no randf().
class_name EndlessDefenseSystem
extends Node

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const WAVE_INTERVAL_TICKS: int = 900  # 60 s at 15 tps between waves

# Unit type tags used in wave composition entries.
const UNIT_CONSCRIPT     := "enemy_conscript"
const UNIT_ATTACK_BIKE   := "enemy_attack_bike"
const UNIT_BATTLE_TANK   := "enemy_battle_tank"
const UNIT_ROCKET_BUGGY  := "enemy_rocket_buggy"
const UNIT_HELICOPTER    := "enemy_helicopter"
const UNIT_MAMMOTH_TANK  := "enemy_mammoth_tank"
const UNIT_CHEM_TROOPER  := "enemy_chem_trooper"

# Cost of each unit type in wave budget.
const UNIT_COST: Dictionary = {
	UNIT_CONSCRIPT:    50,
	UNIT_ATTACK_BIKE:  100,
	UNIT_BATTLE_TANK:  200,
	UNIT_ROCKET_BUGGY: 250,
	UNIT_HELICOPTER:   300,
	UNIT_MAMMOTH_TANK: 500,
	UNIT_CHEM_TROOPER: 350,
}

# Tier unlock thresholds (inclusive wave number).
const T2_UNLOCK_WAVE: int = 4
const T3_UNLOCK_WAVE: int = 7
const T4_UNLOCK_WAVE: int = 10

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var current_wave: int = 0
var resources_per_wave: int = 500  # base payout; increases each wave
var wave_in_progress: bool = false

# Tick at which the next wave should start (set after each wave is defeated).
var _next_wave_tick: int = 0

# Seeded RNG — injected by the game coordinator for determinism.
var _rng: SimRandom = null

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal wave_started(wave_number: int, composition: Array)
signal wave_defeated(wave_number: int, resources_earned: int)
signal all_enemies_defeated()
signal game_over(waves_survived: int)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Inject the seeded RNG before the first tick.
func init(rng: SimRandom) -> void:
	_rng = rng
	_next_wave_tick = 0


## Called every simulation tick by the game loop.
func tick(ecs: ECS, tick_count: int) -> void:
	if wave_in_progress:
		_check_wave_complete(ecs)
	elif tick_count >= _next_wave_tick:
		_start_next_wave(ecs, tick_count)

	check_game_over(ecs)


## Returns true if the game is currently between waves.
func is_between_waves() -> bool:
	return not wave_in_progress


## Returns seconds until the next wave starts (for HUD display).
func ticks_until_next_wave(tick_count: int) -> int:
	if wave_in_progress:
		return 0
	return max(0, _next_wave_tick - tick_count)

# ---------------------------------------------------------------------------
# Wave lifecycle
# ---------------------------------------------------------------------------

func _start_next_wave(ecs: ECS, tick_count: int) -> void:
	current_wave += 1
	var composition: Array = _generate_wave_composition(current_wave)
	_spawn_wave(composition, ecs)
	wave_in_progress = true
	emit_signal("wave_started", current_wave, composition)


func _check_wave_complete(ecs: ECS) -> void:
	var enemy_count: int = 0
	for entity_id in ecs.query(["health", "faction"]):
		var faction = ecs.get_component(entity_id, "faction")
		if faction.faction_id == 1:  # enemy faction
			enemy_count += 1

	if enemy_count == 0:
		wave_in_progress = false
		var earned: int = resources_per_wave + (current_wave * 100)
		resources_per_wave += 50  # base payout scales slightly each wave
		emit_signal("wave_defeated", current_wave, earned)
		_next_wave_tick = _current_tick_from_ecs(ecs) + WAVE_INTERVAL_TICKS


## Checks whether the player Construction Yard still exists.
## Emits game_over if it has been destroyed.
func check_game_over(ecs: ECS) -> void:
	var cy_count: int = 0
	for entity_id in ecs.query(["building_type", "faction"]):
		var faction = ecs.get_component(entity_id, "faction")
		var building = ecs.get_component(entity_id, "building_type")
		if faction.faction_id == 0 and building.type_id == "construction_yard":
			cy_count += 1

	if cy_count == 0:
		emit_signal("game_over", current_wave)

# ---------------------------------------------------------------------------
# Wave composition
# ---------------------------------------------------------------------------

## Generates a budget-based wave composition.
## Returns an Array of Dictionaries: [{type: String, count: int}, …]
func _generate_wave_composition(wave: int) -> Array:
	var budget: int = 500 + (wave * 200)
	var pool: Array = _get_unit_pool(wave)
	return _fill_budget(budget, pool)


func _get_unit_pool(wave: int) -> Array:
	# T1 — always available.
	var pool: Array = [UNIT_CONSCRIPT, UNIT_ATTACK_BIKE]

	# T2 — unlocks at wave 4.
	if wave >= T2_UNLOCK_WAVE:
		pool.append(UNIT_BATTLE_TANK)

	# T3 — unlocks at wave 7.
	if wave >= T3_UNLOCK_WAVE:
		pool.append(UNIT_ROCKET_BUGGY)
		pool.append(UNIT_HELICOPTER)

	# T4 — unlocks at wave 10.
	if wave >= T4_UNLOCK_WAVE:
		pool.append(UNIT_MAMMOTH_TANK)
		pool.append(UNIT_CHEM_TROOPER)

	return pool


## Fills the given budget with units from the pool using a greedy random approach.
## Returns an aggregated Array of {type, count} dicts.
func _fill_budget(budget: int, pool: Array) -> Array:
	# Count map: type → total count.
	var counts: Dictionary = {}

	var remaining: int = budget
	var iterations: int = 0
	var max_iter: int = 500  # guard against infinite loop

	while remaining > 0 and iterations < max_iter:
		iterations += 1
		# Pick a random unit type from the pool that fits the remaining budget.
		var affordable: Array = []
		for unit_type in pool:
			if UNIT_COST[unit_type] <= remaining:
				affordable.append(unit_type)

		if affordable.is_empty():
			break

		var pick: String = affordable[_rng.randi() % affordable.size()]
		counts[pick] = counts.get(pick, 0) + 1
		remaining -= UNIT_COST[pick]

	# Convert to array form expected by callers.
	var result: Array = []
	for unit_type in counts:
		result.append({type = unit_type, count = counts[unit_type]})
	return result

# ---------------------------------------------------------------------------
# Wave spawning (stub — wired to SpawnSystem in integration)
# ---------------------------------------------------------------------------

## Requests SpawnSystem (or equivalent) to materialise the wave entities.
## Composition entries: {type: String, count: int}
func _spawn_wave(composition: Array, ecs: ECS) -> void:
	for entry in composition:
		for _i in range(entry.count):
			var spawn_cmd: Dictionary = {
				unit_type = entry.type,
				faction_id = 1,
				spawn_tag  = "wave_%d" % current_wave,
			}
			ecs.emit_command("spawn_unit", spawn_cmd)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Reads current tick from a lightweight ECS global component, if available.
## Falls back to 0 (safe for unit tests that stub ECS).
func _current_tick_from_ecs(ecs: ECS) -> int:
	if ecs.has_global("sim_clock"):
		return ecs.get_global("sim_clock").tick
	return 0
