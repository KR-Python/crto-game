# Endless Defense HUD overlay.
# Displays: wave counter, next-wave countdown, total resources earned,
# all-time high score (waves survived), and incoming wave composition preview.
#
# Wires to EndlessDefenseSystem signals — does NOT read ECS directly.
class_name EndlessHUD
extends Control

# ---------------------------------------------------------------------------
# Node references (assign in the scene or override in _ready)
# ---------------------------------------------------------------------------

@onready var _wave_label:       Label = $WaveLabel
@onready var _timer_label:      Label = $TimerLabel
@onready var _resources_label:  Label = $ResourcesLabel
@onready var _highscore_label:  Label = $HighScoreLabel
@onready var _incoming_label:   Label = $IncomingLabel
@onready var _incoming_panel:   Control = $IncomingPanel

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _current_wave:      int = 0
var _total_resources:   int = 0
var _best_waves:        int = 0           # persistent high score
var _ticks_until_next:  int = 0           # updated every frame from system
var _ticks_per_second:  float = 15.0      # simulation ticks per real second

# Reference to the wave system — set via wire_to_system().
var _system: EndlessDefenseSystem = null

const HIGHSCORE_KEY := "endless_defense_best_waves"

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_best_waves = _load_highscore()
	_set_wave(0)
	_set_timer_text("Prepare…")
	_set_resources(0)
	_update_highscore_label()
	_incoming_panel.hide()


func _process(_delta: float) -> void:
	if _system == null or _system.wave_in_progress:
		return

	# Poll the system each frame for a smooth countdown display.
	# (The system itself does not emit per-tick timer signals.)
	if _system.is_between_waves():
		var ticks: int = _system.ticks_until_next_wave(_get_current_tick())
		var seconds: int = int(ceil(float(ticks) / _ticks_per_second))
		_set_timer_text("Next wave in: %ds" % seconds)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Connect this HUD to an EndlessDefenseSystem instance.
func wire_to_system(system: EndlessDefenseSystem) -> void:
	_system = system
	system.wave_started.connect(_on_wave_started)
	system.wave_defeated.connect(_on_wave_defeated)
	system.game_over.connect(_on_game_over)


## Called each simulation tick so the HUD can track countdown precisely.
func on_tick(_tick_count: int) -> void:
	pass  # countdown is polled in _process; hook available for future use

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_wave_started(wave_number: int, composition: Array) -> void:
	_set_wave(wave_number)
	_set_timer_text("⚔ Wave %d in progress" % wave_number)
	_show_incoming(composition)


func _on_wave_defeated(wave_number: int, resources_earned: int) -> void:
	_total_resources += resources_earned
	_set_resources(_total_resources)
	_incoming_panel.hide()

	# Check high score.
	if wave_number > _best_waves:
		_best_waves = wave_number
		_save_highscore(_best_waves)
		_update_highscore_label()


func _on_game_over(waves_survived: int) -> void:
	_set_timer_text("Game Over — Survived %d waves" % waves_survived)
	_incoming_panel.hide()

	if waves_survived > _best_waves:
		_best_waves = waves_survived
		_save_highscore(_best_waves)
		_update_highscore_label()

# ---------------------------------------------------------------------------
# Display helpers
# ---------------------------------------------------------------------------

func _set_wave(wave: int) -> void:
	_current_wave = wave
	if wave == 0:
		_wave_label.text = "Endless Defense"
	else:
		_wave_label.text = "Wave %d" % wave


func _set_timer_text(text: String) -> void:
	_timer_label.text = text


func _set_resources(amount: int) -> void:
	_resources_label.text = "Credits earned: %d" % amount


func _update_highscore_label() -> void:
	_highscore_label.text = "Best: %d waves  |  This run: %d" % [_best_waves, _current_wave]


## Builds and shows the "Incoming" preview panel from a wave composition Array.
## composition entries: {type: String, count: int}
func _show_incoming(composition: Array) -> void:
	if composition.is_empty():
		_incoming_panel.hide()
		return

	var parts: Array = []
	for entry in composition:
		var label: String = _unit_display_name(entry.type)
		parts.append("%dx %s" % [entry.count, label])

	_incoming_label.text = "Incoming: " + ", ".join(parts)
	_incoming_panel.show()


func _unit_display_name(unit_type: String) -> String:
	match unit_type:
		"enemy_conscript":    return "Infantry"
		"enemy_attack_bike":  return "Attack Bikes"
		"enemy_battle_tank":  return "Tanks"
		"enemy_rocket_buggy": return "Rocket Buggies"
		"enemy_helicopter":   return "Helicopters"
		"enemy_mammoth_tank": return "Mammoth Tanks"
		"enemy_chem_trooper": return "Chem Troopers"
		_:                    return unit_type.trim_prefix("enemy_").capitalize()

# ---------------------------------------------------------------------------
# Persistence (high score)
# ---------------------------------------------------------------------------

func _load_highscore() -> int:
	if not FileAccess.file_exists("user://endless_scores.cfg"):
		return 0
	var cfg := ConfigFile.new()
	if cfg.load("user://endless_scores.cfg") != OK:
		return 0
	return cfg.get_value("scores", HIGHSCORE_KEY, 0)


func _save_highscore(score: int) -> void:
	var cfg := ConfigFile.new()
	# Preserve any existing entries.
	cfg.load("user://endless_scores.cfg")
	cfg.set_value("scores", HIGHSCORE_KEY, score)
	cfg.save("user://endless_scores.cfg")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _get_current_tick() -> int:
	# Obtain from the scene tree's sim clock node if present.
	var clock = get_tree().get_first_node_in_group("sim_clock")
	if clock and clock.has_method("get_tick"):
		return clock.get_tick()
	return 0
