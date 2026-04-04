class_name PersonalityAI
extends ReactiveAI
## AI Opponent Iteration 3 — Personality-Driven AI
## Full utility-based decision making with personality weights, harassment squads,
## multi-prong attacks, and superweapon usage.

var personality: PersonalityDriver

# ---------------------------------------------------------------------------
# Army splitting
# ---------------------------------------------------------------------------
var _harassment_units: Array[int] = []   # small squad kept separate for harassment
var _main_army: Array[int] = []
var _harass_active: bool = false
var _multi_prong_active: bool = false
var _prong_a: Array[int] = []
var _prong_b: Array[int] = []

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
const HARASS_SQUAD_SIZE: int = 4
const MIN_ARMY_FOR_HARASS: int = 8
const MIN_ARMY_FOR_MULTI_PRONG: int = 12
const EVALUATION_INTERVAL: int = 75


# ===========================================================================
# Initialization
# ===========================================================================

func initialize_with_personality(personality_yaml: Dictionary, faction: int, enemy_spawn: Vector2) -> void:
	personality = PersonalityDriver.new(personality_yaml)
	faction_id = faction
	attack_target = enemy_spawn
	_attack_threshold_ratio = personality.get_attack_threshold()
	_first_attack_tick = personality.get_first_attack_tick()
	_retreat_threshold = personality_yaml.get("behavior", {}).get("retreat_threshold", 0.4)

	# Apply reaction time as evaluation interval
	var reaction_ticks: int = personality.get_reaction_time_ticks()
	if reaction_ticks > 0:
		evaluation_interval = reaction_ticks * 15

	# Preferred composition
	var comp: Dictionary = personality_yaml.get("behavior", {}).get("preferred_composition", {})
	if comp.size() > 0:
		_preferred_composition = comp


# ===========================================================================
# Main loop — overrides ReactiveAI
# ===========================================================================

func _ai_tick(tick_count: int) -> void:
	_update_scouting(tick_count)
	_update_army_split()

	if tick_count - _last_evaluation_tick >= evaluation_interval:
		_evaluate_with_personality(tick_count)
		_last_evaluation_tick = tick_count

	_execute_current_goal(tick_count)

	# Run harassment in parallel with main goal
	if _harass_active:
		_run_harass(tick_count)


# ===========================================================================
# Personality-driven evaluation (utility scoring)
# ===========================================================================

func _evaluate_with_personality(tick_count: int) -> void:
	var scores: Dictionary = _score_all_strategies(tick_count)
	# Highest-scoring strategy wins
	_current_strategic_goal = scores.keys()[0]

	# Activate/deactivate harassment
	if personality.should_harass() and army_entities.size() >= MIN_ARMY_FOR_HARASS:
		_harass_active = true
	else:
		_harass_active = false
		_return_harass_units()

	# Multi-prong decision
	if _current_strategic_goal == "attack" and personality.should_multi_prong() and army_entities.size() >= MIN_ARMY_FOR_MULTI_PRONG:
		_multi_prong_active = true
		_split_for_multi_prong()
	else:
		_multi_prong_active = false


func _score_all_strategies(tick_count: int) -> Dictionary:
	var my_strength: float = ThreatAssessment.estimate_army_strength(army_entities)
	var enemy_strength: float = _estimate_enemy_strength()
	var resources: Dictionary = get_resources()

	var scores: Dictionary = {
		"attack": _score_attack(my_strength, enemy_strength, tick_count) * personality.get_strategy_weight("attack"),
		"defend": _score_defend() * personality.get_strategy_weight("defend"),
		"harass": _score_harass(my_strength) * personality.get_strategy_weight("harass"),
		"tech": _score_tech(resources) * personality.get_strategy_weight("tech_up"),
		"build": _score_build(resources) * personality.get_strategy_weight("build_army"),
		"expand": _score_expand(resources) * personality.get_strategy_weight("expand_economy"),
	}

	# Sort by score descending
	var sorted_keys: Array = scores.keys()
	sorted_keys.sort_custom(func(a: String, b: String) -> bool: return scores[a] > scores[b])
	var result: Dictionary = {}
	for k in sorted_keys:
		result[k] = scores[k]
	return result


# ===========================================================================
# Individual strategy scoring (base scores before personality weight)
# ===========================================================================

func _score_attack(my_strength: float, enemy_strength: float, tick_count: int) -> float:
	# Can't attack before first_attack_tick
	if tick_count < _first_attack_tick:
		return 0.0
	if enemy_strength <= 0.0:
		return 1.0
	var ratio: float = my_strength / enemy_strength
	# Higher ratio → higher score, capped at 1.0
	return clampf(ratio - 0.5, 0.0, 1.0)


func _score_defend() -> float:
	if _is_under_attack():
		return 1.0
	if _base_threat_entities.size() > 0:
		return 0.7
	return 0.1


func _score_harass(my_strength: float) -> float:
	if army_entities.size() < MIN_ARMY_FOR_HARASS:
		return 0.0
	# Harassment is useful when we can spare units
	return clampf(my_strength / 1000.0, 0.1, 0.6)


func _score_tech(resources: Dictionary) -> float:
	var primary: float = resources.get("primary", 0)
	# Incentivize teching when we have spare resources
	if primary > 1500:
		return 0.8
	elif primary > 800:
		return 0.5
	return 0.2


func _score_build(resources: Dictionary) -> float:
	var primary: float = resources.get("primary", 0)
	if army_entities.size() < 5:
		return 0.9  # need army urgently
	if primary > 500:
		return 0.6
	return 0.3


func _score_expand(resources: Dictionary) -> float:
	var primary: float = resources.get("primary", 0)
	if primary < 200:
		return 0.7  # running low, need expansion
	return 0.3


# ===========================================================================
# Harassment
# ===========================================================================

func _run_harass(_tick_count: int) -> void:
	if not personality.should_harass():
		return
	if _harassment_units.size() == 0:
		return
	# Send harassment squad to enemy economy (harvesters near attack_target)
	_emit_command("HarassTarget", {"position": attack_target, "units": _harassment_units, "max_units": HARASS_SQUAD_SIZE})


func _return_harass_units() -> void:
	# Merge harassment units back into main army
	_harassment_units.clear()


# ===========================================================================
# Multi-prong attacks
# ===========================================================================

func _split_for_multi_prong() -> void:
	if _main_army.size() < MIN_ARMY_FOR_MULTI_PRONG:
		_multi_prong_active = false
		return
	# Split main army roughly in half
	var mid: int = _main_army.size() / 2
	_prong_a = _main_army.slice(0, mid)
	_prong_b = _main_army.slice(mid)


func _run_multi_prong(_tick_count: int) -> void:
	if not _multi_prong_active:
		return
	# Prong A attacks from the direct route
	_emit_command("AttackMove", {"position": attack_target, "units": _prong_a})
	# Prong B flanks — offset attack position
	var flank_offset := Vector2(300, 300)
	_emit_command("AttackMove", {"position": attack_target + flank_offset, "units": _prong_b})


# ===========================================================================
# Army splitting utility
# ===========================================================================

func _update_army_split() -> void:
	# Separate harassment units from main army
	_main_army.clear()
	_harassment_units.clear()

	if not _harass_active or army_entities.size() < MIN_ARMY_FOR_HARASS:
		_main_army = army_entities.duplicate()
		return

	# Take up to HARASS_SQUAD_SIZE units for harassment
	var harass_count: int = mini(HARASS_SQUAD_SIZE, army_entities.size() / 3)
	for i in range(army_entities.size()):
		if i < harass_count:
			_harassment_units.append(army_entities[i])
		else:
			_main_army.append(army_entities[i])


# ===========================================================================
# Override execute to use multi-prong when active
# ===========================================================================

func _execute_current_goal(tick_count: int) -> void:
	if _current_strategic_goal == "attack" and _multi_prong_active:
		_run_multi_prong(tick_count)
	else:
		super._execute_current_goal(tick_count)


# ===========================================================================
# Resource helper
# ===========================================================================

func get_resources() -> Dictionary:
	return economy_resources


# ===========================================================================
# External access
# ===========================================================================

func get_harassment_units() -> Array[int]:
	return _harassment_units


func get_main_army() -> Array[int]:
	return _main_army


func is_multi_prong_active() -> bool:
	return _multi_prong_active


func get_prong_a() -> Array[int]:
	return _prong_a


func get_prong_b() -> Array[int]:
	return _prong_b
