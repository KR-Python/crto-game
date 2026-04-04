class_name ResourceBar
extends Control

## Top HUD bar — displays the shared faction economy in real time.
##
## Text-only for Phase 1.  Layout (all Labels):
##   [ORE] <primary>  [GEM] <secondary>  |  Income: +<rate>/s  Power: ⚡ <used>/<cap>
##
## Wire up in the scene: set faction_id and economy_system before _ready, or
## call configure() at any time.

# ------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------

var faction_id: int = 0
var economy_system  # EconomySystem — injected by the game HUD scene

# ------------------------------------------------------------------
# Node refs (created in _ready)
# ------------------------------------------------------------------

var _lbl_primary: Label
var _lbl_secondary: Label
var _lbl_income: Label
var _lbl_power: Label

# ------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------

const UPDATE_INTERVAL_SEC: float = 0.25  # Refresh 4× per second — snappy enough
var _timer: float = 0.0

# ------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------

func _ready() -> void:
	_build_layout()


func _process(delta: float) -> void:
	_timer += delta
	if _timer < UPDATE_INTERVAL_SEC:
		return
	_timer = 0.0
	if economy_system != null:
		var res: Dictionary = economy_system.get_resources(faction_id)
		_update_display(res)


# ------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------

func configure(new_faction_id: int, new_economy_system) -> void:
	faction_id = new_faction_id
	economy_system = new_economy_system


# ------------------------------------------------------------------
# Display
# ------------------------------------------------------------------

func _update_display(res: Dictionary) -> void:
	# Expected keys from EconomySystem.get_resources():
	#   primary: int, secondary: int, income_rate: float,
	#   power_used: int, power_cap: int
	_lbl_primary.text  = "⛏ %d" % res.get("primary", 0)
	_lbl_secondary.text = "💎 %d" % res.get("secondary", 0)

	var rate: float = res.get("income_rate", 0.0)
	var sign_str: String = "+" if rate >= 0.0 else ""
	_lbl_income.text = "Income: %s%.0f/s" % [sign_str, rate]

	var pwr_used: int = res.get("power_used", 0)
	var pwr_cap:  int = res.get("power_cap", 0)
	_lbl_power.text = "⚡ %d/%d" % [pwr_used, pwr_cap]

	# Colour power label red when over-budget.
	if pwr_used > pwr_cap:
		_lbl_power.add_theme_color_override("font_color", Color.RED)
	else:
		_lbl_power.remove_theme_color_override("font_color")


# ------------------------------------------------------------------
# Layout builder (pure code — no scene file needed for Phase 1)
# ------------------------------------------------------------------

func _build_layout() -> void:
	custom_minimum_size = Vector2(0, 28)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 16)
	add_child(hbox)

	# Background panel.
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.z_index = -1
	add_child(panel)

	_lbl_primary   = _make_label("⛏ --")
	_lbl_secondary = _make_label("💎 --")
	_lbl_income    = _make_label("Income: --/s")
	_lbl_power     = _make_label("⚡ --/--")

	# Separator between resource counts and economy stats.
	var sep := Label.new()
	sep.text = "|"

	for lbl in [_lbl_primary, _lbl_secondary, sep, _lbl_income, _lbl_power]:
		hbox.add_child(lbl)


func _make_label(initial_text: String) -> Label:
	var lbl := Label.new()
	lbl.text = initial_text
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl
