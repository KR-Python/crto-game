class_name PersonalityDriver
extends RefCounted
## Loads an AI personality config (Dictionary, typically from YAML) and applies
## its weights/modifiers to a ReactiveAI instance.

var personality: Dictionary = {}


func _init(config: Dictionary = {}) -> void:
	personality = config


## Apply personality overrides to a ReactiveAI.
func apply_to_ai(ai: ReactiveAI) -> void:
	# Attack threshold: higher attack weight → lower ratio needed to attack
	var attack_weight: float = get_strategy_weight("attack")
	if attack_weight > 0.0:
		ai._attack_threshold_ratio = 1.3 / attack_weight  # e.g. 1.8 → 0.72 threshold

	# Retreat threshold from behavior
	var retreat: float = personality.get("behavior", {}).get("retreat_threshold", 0.4)
	ai._retreat_threshold = retreat

	# Reaction time → evaluation interval
	var reaction_ticks: int = personality.get("difficulty_modifiers", {}).get("reaction_time_ticks", -1)
	if reaction_ticks > 0:
		ai.evaluation_interval = reaction_ticks * 15  # scale to game ticks

	# First attack tick
	ai._first_attack_tick = get_first_attack_tick()

	# Preferred composition
	var comp: Dictionary = personality.get("behavior", {}).get("preferred_composition", {})
	if comp.size() > 0:
		ai._preferred_composition = comp


func get_strategy_weight(strategy: String) -> float:
	return personality.get("strategy_weights", {}).get(strategy, 1.0)


func should_multi_prong() -> bool:
	return personality.get("difficulty_modifiers", {}).get("multi_prong_attacks", false)


func get_first_attack_tick() -> int:
	return personality.get("behavior", {}).get("first_attack_tick", 900)


func should_harass() -> bool:
	return get_strategy_weight("harass") >= 0.8


func get_attack_threshold() -> float:
	var attack_weight: float = get_strategy_weight("attack")
	if attack_weight > 0.0:
		return 1.3 / attack_weight
	return 1.3


func get_reaction_time_ticks() -> int:
	return personality.get("difficulty_modifiers", {}).get("reaction_time_ticks", 15)
