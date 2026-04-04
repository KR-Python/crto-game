extends GutTest
## Tests for PersonalityAI — utility scoring, harassment, multi-prong, timing.


# ===========================================================================
# Helpers
# ===========================================================================

var _volkov_config: Dictionary = {
	"strategy_weights": {
		"expand_economy": 0.5, "build_army": 1.5, "tech_up": 0.6,
		"attack": 1.8, "defend": 0.4, "harass": 1.2,
	},
	"behavior": {
		"first_attack_tick": 600,
		"retreat_threshold": 0.3,
		"preferred_composition": {"vehicles": 0.6, "infantry": 0.3, "air": 0.1},
	},
	"difficulty_modifiers": {
		"reaction_time_ticks": 5,
		"multi_prong_attacks": true,
	},
}

var _chen_config: Dictionary = {
	"strategy_weights": {
		"expand_economy": 1.2, "build_army": 0.6, "tech_up": 1.8,
		"attack": 0.5, "defend": 1.6, "harass": 0.3,
	},
	"behavior": {
		"first_attack_tick": 3000,
		"retreat_threshold": 0.6,
	},
	"difficulty_modifiers": {
		"reaction_time_ticks": 15,
		"multi_prong_attacks": false,
	},
}

var _easy_config: Dictionary = {
	"strategy_weights": {
		"expand_economy": 1.0, "build_army": 1.0, "tech_up": 1.0,
		"attack": 1.0, "defend": 1.0, "harass": 0.5,
	},
	"behavior": {
		"first_attack_tick": 1200,
		"retreat_threshold": 0.5,
	},
	"difficulty_modifiers": {
		"reaction_time_ticks": 45,
		"multi_prong_attacks": false,
	},
}


func _make_ai(config: Dictionary) -> PersonalityAI:
	var ai := PersonalityAI.new()
	ai.initialize_with_personality(config, 1, Vector2(1000, 1000))
	return ai


func _populate_army(ai: PersonalityAI, count: int) -> void:
	ai.army_entities.clear()
	for i in range(count):
		ai.army_entities.append(i)


# ===========================================================================
# Test 1: Volkov attack score highest when army_ratio > 1.3
# ===========================================================================

func test_volkov_attack_highest_when_strong() -> void:
	var ai := _make_ai(_volkov_config)
	_populate_army(ai, 20)
	# Give enough resources so build/expand don't dominate
	ai.economy_resources = {"primary": 800, "secondary": 200}

	# Mock: strong army → high strength estimate
	# Volkov attack weight 1.8 makes attack threshold ~0.72
	# With 20 units the strength ratio should favor attack
	var scores: Dictionary = ai._score_all_strategies(700)  # past first_attack_tick=600
	var first_key: String = scores.keys()[0]
	assert_eq(first_key, "attack", "Volkov should prioritize attack when army is strong and past first_attack_tick")


# ===========================================================================
# Test 2: Dr. Chen tech score highest when resources > 1500
# ===========================================================================

func test_chen_tech_highest_when_rich() -> void:
	var ai := _make_ai(_chen_config)
	_populate_army(ai, 6)
	ai.economy_resources = {"primary": 2000, "secondary": 500}

	var scores: Dictionary = ai._score_all_strategies(500)  # before first_attack_tick=3000
	var first_key: String = scores.keys()[0]
	# With resources > 1500, tech base score = 0.8 × weight 1.8 = 1.44
	# Attack is 0 (before first_attack_tick), build is moderate
	assert_eq(first_key, "tech", "Dr. Chen should prioritize tech when resources are high")


# ===========================================================================
# Test 3: Harassment splits off 3-4 units when active
# ===========================================================================

func test_harassment_splits_units() -> void:
	var ai := _make_ai(_volkov_config)
	_populate_army(ai, 12)

	# Force harass active
	ai._harass_active = true
	ai._update_army_split()

	var harass_count: int = ai.get_harassment_units().size()
	assert_true(harass_count >= 3 and harass_count <= PersonalityAI.HARASS_SQUAD_SIZE,
		"Harassment squad should be 3-4 units, got %d" % harass_count)
	assert_eq(harass_count + ai.get_main_army().size(), 12,
		"All units should be accounted for between harass and main army")


# ===========================================================================
# Test 4: Multi-prong splits army into 2 groups
# ===========================================================================

func test_multi_prong_splits_army() -> void:
	var ai := _make_ai(_volkov_config)
	_populate_army(ai, 16)
	ai._main_army = ai.army_entities.duplicate()

	ai._split_for_multi_prong()

	assert_true(ai.get_prong_a().size() > 0, "Prong A should have units")
	assert_true(ai.get_prong_b().size() > 0, "Prong B should have units")
	assert_eq(ai.get_prong_a().size() + ai.get_prong_b().size(), ai._main_army.size(),
		"Both prongs should account for entire main army")


# ===========================================================================
# Test 5: first_attack_tick respected — no attack before that tick
# ===========================================================================

func test_first_attack_tick_respected() -> void:
	var ai := _make_ai(_chen_config)
	_populate_army(ai, 20)
	ai.economy_resources = {"primary": 500, "secondary": 200}

	# Score at tick 100 — well before Chen's first_attack_tick of 3000
	var scores: Dictionary = ai._score_all_strategies(100)
	# Attack should have raw score 0 (blocked by first_attack_tick)
	var attack_score: float = scores.get("attack", -1.0)
	assert_eq(attack_score, 0.0, "Attack score should be 0 before first_attack_tick")


# ===========================================================================
# Test 6: Easy difficulty applies reaction_time_ticks=45
# ===========================================================================

func test_easy_difficulty_slow_evaluation() -> void:
	var ai := _make_ai(_easy_config)
	# reaction_time_ticks=45 → evaluation_interval = 45 * 15 = 675
	assert_eq(ai.evaluation_interval, 675,
		"Easy difficulty should have evaluation_interval = 675 (45 * 15)")
