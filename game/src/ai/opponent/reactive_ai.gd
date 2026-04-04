class_name ReactiveAI
extends AIOpponent
## AI Opponent Iteration 2 — Reactive AI
## Adapts build order based on scouting, chooses attack timing based on army
## strength comparison, retreats when losing.

# ---------------------------------------------------------------------------
# Scouting state
# ---------------------------------------------------------------------------
var _scouted_enemy_units: Dictionary = {}       # entity_id → {type, last_seen_tick, dps, health}
var _scouted_enemy_structures: Dictionary = {}  # entity_id → {structure_type, position}
var _enemy_tech_tier: int = 1                   # estimated from scouted structures

# ---------------------------------------------------------------------------
# Decision state
# ---------------------------------------------------------------------------
var _current_strategic_goal: String = "build"   # build | tech | attack | defend | harass
var _attack_threshold_ratio: float = 1.3        # attack when my/enemy strength > this
var _retreat_threshold: float = 0.4             # retreat when army drops below 40% of attack-start
var _attack_start_strength: float = 0.0         # snapshot when attack begins
var _last_evaluation_tick: int = 0
var _first_attack_tick: int = 900               # don't attack before this tick (personality-tunable)
var evaluation_interval: int = 75               # re-evaluate every 75 ticks (~5s at 15 ticks/s)

# ---------------------------------------------------------------------------
# Under-attack tracking
# ---------------------------------------------------------------------------
var _base_threat_entities: Array = []           # enemy entities near base (set externally or by scouting)
var _under_attack: bool = false

# ---------------------------------------------------------------------------
# Production tracking
# ---------------------------------------------------------------------------
var _production_queue: Array = []               # queued production commands
var _preferred_composition: Dictionary = {"infantry": 0.5, "vehicle": 0.4, "air": 0.1}


# ===========================================================================
# Main loop
# ===========================================================================

func _ai_tick(tick_count: int) -> void:
	_update_scouting(tick_count)
	if tick_count - _last_evaluation_tick >= evaluation_interval:
		_evaluate_situation(tick_count)
		_last_evaluation_tick = tick_count
	_execute_current_goal(tick_count)


# ===========================================================================
# Strategic evaluation
# ===========================================================================

func _evaluate_situation(tick_count: int) -> void:
	var my_strength: float = ThreatAssessment.estimate_army_strength(army_entities)
	var enemy_strength: float = _estimate_enemy_strength()
	var resources: Dictionary = get_resources()

	# Priority: defend > attack > tech > build
	if _is_under_attack():
		_current_strategic_goal = "defend"
	elif tick_count >= _first_attack_tick and my_strength > enemy_strength * _attack_threshold_ratio:
		_current_strategic_goal = "attack"
		_attack_start_strength = my_strength
	elif resources.get("primary", 0) > 2000 and _enemy_tech_tier <= 1:
		_current_strategic_goal = "tech"
	else:
		_current_strategic_goal = "build"


func _is_under_attack() -> bool:
	return _under_attack or _base_threat_entities.size() > 0


# ===========================================================================
# Goal execution
# ===========================================================================

func _execute_current_goal(tick_count: int) -> void:
	match _current_strategic_goal:
		"build":
			_run_adaptive_build(tick_count)
		"tech":
			_accelerate_tech(tick_count)
		"attack":
			_run_attack(tick_count)
		"defend":
			_run_defense(tick_count)
		"harass":
			_run_harass(tick_count)


func _run_adaptive_build(_tick_count: int) -> void:
	# Counter-build based on scouted enemy composition
	var enemy_has_vehicles := false
	for unit_data in _scouted_enemy_units.values():
		if unit_data.get("type", "") == "vehicle":
			enemy_has_vehicles = true
			break

	if enemy_has_vehicles:
		_emit_command("ProduceUnit", {"unit_type": "rocket_trooper", "count": 2})
	elif _enemy_tech_tier >= 2:
		# Enemy is teching — rush before they finish
		_emit_command("ProduceUnit", {"unit_type": "infantry", "count": 4})
	else:
		# Standard balanced production
		_emit_command("ProduceUnit", {"unit_type": "infantry", "count": 2})
		_emit_command("ProduceUnit", {"unit_type": "vehicle", "count": 1})


func _accelerate_tech(_tick_count: int) -> void:
	_emit_command("StartResearch", {"research_type": "tech_tier_2"})
	# Keep some production going while teching
	_emit_command("ProduceUnit", {"unit_type": "infantry", "count": 1})


func _run_attack(_tick_count: int) -> void:
	var current_strength: float = ThreatAssessment.estimate_army_strength(army_entities)

	# Retreat check: if army dropped below 40% of attack-start strength
	if _attack_start_strength > 0.0 and current_strength < _attack_start_strength * _retreat_threshold:
		_current_strategic_goal = "build"
		_emit_command("Retreat", {"position": base_position})
		_attack_start_strength = 0.0
		return

	_emit_command("AttackMove", {"position": attack_target})


func _run_defense(_tick_count: int) -> void:
	_emit_command("DefendPosition", {"position": base_position})
	# Produce reinforcements
	_emit_command("ProduceUnit", {"unit_type": "infantry", "count": 2})


func _run_harass(_tick_count: int) -> void:
	# Send small group to harass enemy economy
	_emit_command("HarassTarget", {"position": attack_target, "max_units": 3})


# ===========================================================================
# Scouting
# ===========================================================================

func _update_scouting(tick_count: int) -> void:
	# In a real implementation this reads visible enemy entities from the ECS.
	# Here we process whatever has been fed into _scouted_enemy_structures.
	_estimate_enemy_tech_tier()

	# Expire stale scouting data (older than 450 ticks / ~30 seconds)
	var expired: Array = []
	for eid in _scouted_enemy_units:
		var data: Dictionary = _scouted_enemy_units[eid]
		if tick_count - data.get("last_seen_tick", 0) > 450:
			expired.append(eid)
	for eid in expired:
		_scouted_enemy_units.erase(eid)


func _estimate_enemy_tech_tier() -> void:
	for s_data in _scouted_enemy_structures.values():
		var stype: String = s_data.get("structure_type", "")
		if stype == "tech_lab" or stype == "radar":
			_enemy_tech_tier = max(_enemy_tech_tier, 2)
		if stype == "advanced_tech_lab":
			_enemy_tech_tier = max(_enemy_tech_tier, 3)


func _estimate_enemy_strength() -> float:
	var base_estimate: float = 300.0  # assume moderate threat if no intel
	var scouted: float = 0.0
	for unit_data in _scouted_enemy_units.values():
		var h: float = unit_data.get("health", 100.0)
		var d: float = unit_data.get("dps", 10.0)
		scouted += h * d * 0.01
	return max(base_estimate, scouted)


# ===========================================================================
# External state setters (used by game systems and tests)
# ===========================================================================

func set_under_attack(value: bool) -> void:
	_under_attack = value


func add_scouted_unit(entity_id: int, data: Dictionary) -> void:
	_scouted_enemy_units[entity_id] = data


func add_scouted_structure(entity_id: int, data: Dictionary) -> void:
	_scouted_enemy_structures[entity_id] = data


func get_strategic_goal() -> String:
	return _current_strategic_goal
