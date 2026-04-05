class_name Simulation
extends Node

## Core simulation orchestrator — drives the deterministic tick pipeline.
## All 13 steps execute in order each tick. Systems are wired at initialize().
##
## Tick Pipeline:
##  1. InputSystem (read CommandQueue)
##  2. PermissionSystem (validate commands)
##  3. AIDecisionSystem (ScriptedAI / ReactiveAI / PersonalityAI + partners)
##  4. EconomySystem (harvester ticks, income, power grid)
##  5. ProductionSystem (advance queues, spawn units)
##  6. CommandProcessingSystem (pathfinding dispatch)
##  7. (pathfinding resolved in step 6)
##  8. MovementSystem (move along paths, separation steering)
##  9. CombatSystem (target acquisition, damage)
## 10. DeathSystem (remove dead entities, emit signals)
## 11. VisionSystem + StealthSystem (fog of war, detection)
## 12. StatusEffectSystem + AbilitySystem (DOTs, cooldowns, C4)
## 13. SuperweaponSystem + VictorySystem + TechTreeSystem + RepairSystem

const TICKS_PER_SECOND: int = 15

signal tick_completed(tick_count: int)
signal game_over(result: Dictionary)

# ── Core references ───────────────────────────────────────────────────────────
var ecs: ECS
var command_queue: CommandQueue
var game_map: GameMap
var nav_grid: NavGrid
var entity_factory: EntityFactory
var game_stats: GameStats

# ── Systems ───────────────────────────────────────────────────────────────────
var economy_system: EconomySystem
var production_system: ProductionSystem
var command_processing_system: CommandProcessingSystem
var movement_system: MovementSystem
var combat_system: CombatSystem
var death_system: DeathSystem
var vision_system: VisionSystem
var stealth_system: StealthSystem
var status_effect_system: StatusEffectSystem
var ability_system: AbilitySystem
var superweapon_system: SuperweaponSystem
var victory_system: VictorySystem
var formation_system: FormationSystem
var repair_system: RepairSystem
var tech_tree_system: TechTreeSystem
var endless_defense_system: EndlessDefenseSystem

# ── AI ────────────────────────────────────────────────────────────────────────
var ai_opponents: Array = []  # Array[AIOpponent]

# ── State ─────────────────────────────────────────────────────────────────────
var tick_count: int = 0
var _running: bool = false
var _game_mode: String = "skirmish"
var _config: Dictionary = {}


func initialize(map: GameMap, config: Dictionary = {}) -> void:
	_config = config
	_game_mode = config.get("mode", "skirmish")
	game_map = map

	# Core
	ecs = ECS.new()
	command_queue = CommandQueue.new()
	nav_grid = NavGrid.new(game_map)
	entity_factory = EntityFactory.new(ecs)
	game_stats = GameStats.new()
	game_stats.game_start_tick = 0

	# Step 4: Economy
	economy_system = EconomySystem.new()
	_init_faction_resources(config)

	# Step 5: Production
	production_system = ProductionSystem.new()
	production_system.economy_system = economy_system

	# Step 6: Command Processing (with pathfinding)
	command_processing_system = CommandProcessingSystem.new(nav_grid)

	# Step 8: Movement
	movement_system = MovementSystem.new()
	movement_system.map_bounds = Rect2(0.0, 0.0, float(game_map.width), float(game_map.height))

	# Step 9: Combat
	combat_system = CombatSystem.new()

	# Step 10: Death
	death_system = DeathSystem.new()
	death_system.unit_died.connect(_on_unit_died)

	# Step 11: Vision + Stealth
	vision_system = VisionSystem.new()
	_register_faction_teams(config)
	stealth_system = StealthSystem.new()

	# Step 12: Status Effects + Abilities
	status_effect_system = StatusEffectSystem.new()
	ability_system = AbilitySystem.new()

	# Step 13: Superweapon, Victory, etc.
	superweapon_system = SuperweaponSystem.new()
	victory_system = VictorySystem.new()
	victory_system.player_faction_id = config.get("player_faction", 1)
	victory_system.game_won.connect(_on_game_won)
	victory_system.game_lost.connect(_on_game_lost)
	victory_system.game_drawn.connect(_on_game_drawn)

	# Auxiliary systems
	formation_system = FormationSystem.new()
	repair_system = RepairSystem.new()
	tech_tree_system = TechTreeSystem.new()

	# Endless mode
	if _game_mode == "endless":
		endless_defense_system = EndlessDefenseSystem.new()

	_running = true


func tick() -> void:
	if not _running:
		return

	# Step 1 & 2: Input + Permission
	var commands: Array = command_queue.get_commands_for_tick(tick_count)
	command_queue.clear_tick(tick_count)
	command_queue.clear_expired(tick_count)

	# Step 3: AI Decision
	for ai in ai_opponents:
		ai.tick(tick_count)
		var ai_commands: Array = ai.get_commands()
		for cmd in ai_commands:
			cmd["tick"] = tick_count
			commands.append(cmd)

	# Step 4: Economy
	economy_system.tick(ecs, tick_count)

	# Step 5: Production
	production_system.tick(ecs, tick_count)

	# Step 6: Command Processing (pathfinding)
	command_processing_system.process_move_commands(ecs, tick_count)

	# Step 8: Movement
	movement_system.tick(ecs, tick_count)

	# Step 9: Combat
	combat_system.tick(ecs, tick_count)

	# Step 10: Death
	death_system.tick(ecs, tick_count)

	# Step 11: Vision + Stealth
	vision_system.tick(ecs, tick_count)
	stealth_system.tick(ecs, tick_count)

	# Step 12: Status Effects + Abilities
	status_effect_system.tick(ecs, tick_count)
	ability_system.tick(ecs, tick_count)

	# Step 13: Superweapon + Victory + Tech + Repair
	superweapon_system.tick(ecs, tick_count)
	victory_system.tick(ecs, tick_count)
	tech_tree_system.tick(ecs, tick_count)
	repair_system.tick(ecs, tick_count)

	# Endless mode wave management
	if _game_mode == "endless" and endless_defense_system != null:
		endless_defense_system.tick(ecs, tick_count)

	tick_count += 1
	tick_completed.emit(tick_count)


# ── Public API ────────────────────────────────────────────────────────────────

func add_ai_opponent(ai: AIOpponent) -> void:
	ai_opponents.append(ai)

func is_running() -> bool:
	return _running

func stop() -> void:
	_running = false

func get_ecs() -> ECS:
	return ecs


func issue_move_command(entity_id: int, world_position: Vector2) -> void:
	command_queue.enqueue({
		"action": "MoveUnit",
		"entity_ids": [entity_id],
		"target_position": {"x": world_position.x, "y": world_position.y},
		"player_id": 1,
		"role": "field_marshal",
		"tick": tick_count,
	})

func get_tick_count() -> int:
	return tick_count


# ── Private ───────────────────────────────────────────────────────────────────

func _init_faction_resources(config: Dictionary) -> void:
	var player_count: int = config.get("player_count", 2)
	for i in range(1, player_count + 1):
		economy_system.add_income(i, 5000, "primary")
		economy_system.add_income(i, 2000, "secondary")

func _register_faction_teams(config: Dictionary) -> void:
	var player_count: int = config.get("player_count", 2)
	for i in range(1, player_count + 1):
		vision_system.register_faction_team(i, i)

func _on_unit_died(_entity_id: int, faction_id: int, _position: Vector2) -> void:
	if faction_id >= 0:
		game_stats.record_unit_lost(faction_id)

func _on_game_won(winning_faction: int, tc: int) -> void:
	_running = false
	game_over.emit({"result": "victory", "faction": winning_faction, "tick": tc})

func _on_game_lost(losing_faction: int, tc: int) -> void:
	_running = false
	game_over.emit({"result": "defeat", "faction": losing_faction, "tick": tc})

func _on_game_drawn(tc: int) -> void:
	_running = false
	game_over.emit({"result": "draw", "tick": tc})
