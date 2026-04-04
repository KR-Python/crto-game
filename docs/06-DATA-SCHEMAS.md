# 06 — Data Schemas

## Philosophy

All game content is data-driven. Units, structures, tech trees, maps, AI personalities — everything is defined in YAML files that conform to strict schemas. This enables:

1. **Agent productivity:** Agents produce data files that are immediately testable against the schema
2. **Parallel content creation:** Multiple agents produce unit/structure definitions simultaneously
3. **Balance iteration:** Change numbers in YAML, reload, playtest — no recompilation
4. **Mod support (future):** Players can create custom factions/units by editing YAML

---

## 1. Unit Definition Schema

```yaml
# schema: unit_definition
# file pattern: data/units/{faction}_{unit_name}.yaml

unit_id: "aegis_medium_tank"          # unique identifier
display_name: "Guardian Tank"          # shown in UI
faction: "aegis"
category: "vehicle"                    # infantry | vehicle | air | naval | structure
tier: 2                                # 1, 2, or 3
role_tag: "combat"                     # combat | spec_ops | hero | harvester | engineer | air

# Production
cost:
  primary: 800                         # ore/minerals
  secondary: 0                         # gems/gas
build_time: 12.0                       # seconds
produced_at: "war_factory"             # structure that builds this
tech_requirements:                     # all must be met
  - "aegis_tech_lab"

# Stats
health:
  max: 450
  armor_type: "heavy"                  # light | medium | heavy | building

movement:
  speed: 3.5                           # units per second
  type: "tracked"                      # foot | wheeled | tracked | hover | flying
  can_crush_infantry: true

vision:
  range: 8                             # tile units
  detector: false                      # can see stealth?

# Weapons (can have multiple)
weapons:
  - weapon_id: "120mm_cannon"
    damage: 85
    damage_type: "kinetic"             # kinetic | explosive | energy | chemical | fire
    range: 7
    cooldown: 2.0                      # seconds between shots
    targets: ["ground", "structure"]   # ground | air | structure | naval
    projectile_speed: 15
    area_of_effect: 0                  # 0 = single target
    turret: true                       # can rotate independently of body

# Abilities (optional)
abilities: []

# AI Hints (for partner/opponent AI)
ai_hints:
  threat_value: 6                      # how dangerous (1-10), used by AI threat assessment
  preferred_targets: ["vehicle", "structure"]
  engagement_range: "weapon_range"     # how close before engaging
  retreat_health_pct: 0.25             # AI pulls back below this HP %

# Audio
sounds:
  select: "sfx/aegis/tank_select.ogg"
  move: "sfx/aegis/tank_move.ogg"
  attack: "sfx/aegis/tank_fire.ogg"
  death: "sfx/aegis/tank_explode.ogg"

# Visual
sprite: "sprites/aegis/guardian_tank.png"
icon: "ui/icons/aegis/guardian_tank.png"
death_effect: "effects/vehicle_explosion"
scale: 1.0
```

### Damage Type vs Armor Type Matrix

```yaml
# data/balance/damage_armor_matrix.yaml

# Multiplier applied to damage: final_damage = base_damage × matrix[damage_type][armor_type]
matrix:
  kinetic:
    light: 1.0
    medium: 0.75
    heavy: 0.5
    building: 0.25
  explosive:
    light: 1.5
    medium: 1.0
    heavy: 0.75
    building: 1.5
  energy:
    light: 0.75
    medium: 1.0
    heavy: 1.25
    building: 1.0
  chemical:
    light: 1.5
    medium: 1.25
    heavy: 0.5
    building: 0.25
  fire:
    light: 1.75
    medium: 1.0
    heavy: 0.25
    building: 1.5
```

---

## 2. Structure Definition Schema

```yaml
# schema: structure_definition
# file pattern: data/structures/{faction}_{structure_name}.yaml

structure_id: "aegis_war_factory"
display_name: "War Factory"
faction: "aegis"
tier: 1
role_tag: "production"                 # production | defense | tech | economy | special

# Construction
cost:
  primary: 2000
  secondary: 0
build_time: 20.0
build_requirements:
  structures: ["aegis_barracks"]       # must have barracks first
  tech: []

# Footprint
footprint:
  width: 3                             # tiles
  height: 3
placement_rules:
  requires_power: true
  requires_ground: true                # can't build on water
  min_distance_from_edge: 2

# Stats
health:
  max: 1200
  armor_type: "building"

# Power
power:
  consumption: 30                      # drains this much from grid
  production: 0

# Vision
vision:
  range: 6

# Production (if applicable)
production:
  can_produce:
    - "aegis_light_tank"
    - "aegis_medium_tank"
    - "aegis_apc"
    - "aegis_aa_vehicle"
    - "aegis_harvester"
  queue_size: 5
  rally_point: true

# Tech provided (if applicable)
tech_provides: []                      # this structure unlocks no tech directly

# Defense (if applicable)
weapons: []                            # war factory has no weapons

# Special abilities
abilities: []

# Visual
sprite: "sprites/aegis/war_factory.png"
icon: "ui/icons/aegis/war_factory.png"
construction_stages: 3                 # visual build progress stages
```

---

## 3. Tech Tree Schema

```yaml
# schema: tech_tree
# file pattern: data/tech_trees/{faction}_tech_tree.yaml

faction: "aegis"

tiers:
  tier_1:
    available_at_start: true
    structures:
      - aegis_construction_yard
      - aegis_power_plant
      - aegis_barracks
      - aegis_refinery
    units:
      - aegis_rifleman
      - aegis_engineer
      - aegis_scout_buggy
      - aegis_harvester

  tier_2:
    unlock_requirements:
      structures: ["aegis_barracks"]     # must have built at least one
    structures:
      - aegis_war_factory
      - aegis_radar
      - aegis_tech_lab
      - aegis_turret
    units:
      - aegis_rocket_trooper
      - aegis_medic
      - aegis_medium_tank
      - aegis_apc
      - aegis_aa_vehicle
      - aegis_interceptor          # requires airfield

  tier_3:
    unlock_requirements:
      structures: ["aegis_tech_lab", "aegis_radar"]
    structures:
      - aegis_advanced_tech
      - aegis_airfield
      - aegis_shield_generator
      - aegis_orbital_cannon       # superweapon
    units:
      - aegis_shock_trooper
      - aegis_sniper
      - aegis_heavy_tank
      - aegis_artillery
      - aegis_bomber
      - aegis_gunship
      - aegis_transport
      - aegis_commander_unit       # hero

research:
  - research_id: "aegis_advanced_armor"
    display_name: "Composite Armor"
    description: "+25% HP for all vehicles"
    cost: {primary: 1500, secondary: 500}
    time: 45.0
    requires: ["aegis_tech_lab"]
    effect:
      type: "stat_modifier"
      target: {category: "vehicle", faction: "aegis"}
      modifier: {health.max: 1.25}

  - research_id: "aegis_energy_weapons"
    display_name: "Focused Energy Weapons"
    description: "+20% damage for energy weapons"
    cost: {primary: 1000, secondary: 750}
    time: 60.0
    requires: ["aegis_advanced_tech"]
    effect:
      type: "stat_modifier"
      target: {weapon.damage_type: "energy"}
      modifier: {weapons.damage: 1.2}

  - research_id: "aegis_shield_upgrade"
    display_name: "Hardened Shields"
    description: "Shield generators cover wider area, recharge faster"
    cost: {primary: 2000, secondary: 1000}
    time: 90.0
    requires: ["aegis_shield_generator"]
    effect:
      type: "ability_upgrade"
      target: "aegis_shield_generator"
      modifier: {shield_radius: 1.5, recharge_rate: 2.0}
```

---

## 4. Map Definition Schema

```yaml
# schema: map_definition
# file pattern: data/maps/{map_name}.yaml

map_id: "iron_bridge"
display_name: "Iron Bridge"
description: "Two bases separated by a river. One bridge. Infinite possibilities."
author: "CRTO Team"

dimensions:
  width: 128                           # tiles
  height: 96

player_count:
  min: 2
  max: 4                               # recommended max
  optimal: 2

# Starting positions
spawn_points:
  team_human:
    construction_yard: [15, 48]
    starting_units:
      - {type: "faction_harvester", position: [18, 48]}
      - {type: "faction_rifleman", position: [12, 45], count: 3}
      - {type: "faction_scout_buggy", position: [12, 51]}
    initial_resources: {primary: 5000, secondary: 1000}

  team_ai:
    construction_yard: [113, 48]
    starting_units:
      - {type: "faction_harvester", position: [110, 48]}
      - {type: "faction_rifleman", position: [116, 45], count: 3}
      - {type: "faction_scout_buggy", position: [116, 51]}
    initial_resources: {primary: 5000, secondary: 1000}

# Resource nodes
resources:
  # Near team_human base
  - {type: "ore", position: [20, 40], amount: 25000}
  - {type: "ore", position: [20, 56], amount: 25000}

  # Near team_ai base
  - {type: "ore", position: [108, 40], amount: 25000}
  - {type: "ore", position: [108, 56], amount: 25000}

  # Contested middle
  - {type: "gems", position: [64, 30], amount: 10000}
  - {type: "gems", position: [64, 66], amount: 10000}

  # Expansion ore (risky, high reward)
  - {type: "ore", position: [50, 48], amount: 30000}
  - {type: "ore", position: [78, 48], amount: 30000}

# Expansion points
expansions:
  - {id: "human_north", position: [30, 25], risk: "low"}
  - {id: "human_south", position: [30, 71], risk: "low"}
  - {id: "mid_north", position: [64, 20], risk: "high"}
  - {id: "mid_south", position: [64, 76], risk: "high"}
  - {id: "ai_north", position: [98, 25], risk: "low"}
  - {id: "ai_south", position: [98, 71], risk: "low"}

# Terrain features
terrain:
  base_type: "grass"
  features:
    # River (impassable except at bridge)
    - type: "water"
      shape: "rect"
      bounds: {x: 60, y: 0, width: 8, height: 96}

    # The Bridge
    - type: "bridge"
      bounds: {x: 60, y: 42, width: 8, height: 12}
      passable_by: ["foot", "wheeled", "tracked"]

    # Spec Ops flanking paths (narrow, north and south)
    - type: "ford"
      bounds: {x: 62, y: 5, width: 4, height: 3}
      passable_by: ["foot"]          # infantry only

    - type: "ford"
      bounds: {x: 62, y: 88, width: 4, height: 3}
      passable_by: ["foot"]

    # Cliff overlooks
    - type: "cliff"
      bounds: {x: 55, y: 35, width: 3, height: 5}
      provides: {vision_bonus: 4}    # extra vision range for units on cliff

    - type: "cliff"
      bounds: {x: 70, y: 56, width: 3, height: 5}
      provides: {vision_bonus: 4}

# Map-specific rules
rules:
  bridge_destructible: true            # bridge can be destroyed
  bridge_health: 2000
  bridge_rebuild_time: 120             # seconds to auto-repair

# AI hints for opponent AI
ai_hints:
  attack_routes: [[64, 48]]           # through the bridge
  harass_routes: [[63, 6], [63, 89]]  # through the fords
  expansion_priority: ["near_base", "contested_mid"]
```

---

## 5. Role Permissions Schema

```yaml
# schema: role_permissions
# file: data/role_permissions.yaml

roles:
  commander:
    display_name: "Commander"
    icon: "ui/roles/commander.png"
    color: "#4A90D9"                   # blue
    description: "Base building, tech research, strategic planning"
    min_players_required: 2            # always present in 2+ player games

    selectable_entities:
      tags_include: [structure, construction_yard]
      tags_exclude: [defense_turret]   # that's Chief Engineer

    actions:
      - place_structure
      - cancel_structure
      - research_tech
      - cancel_research
      - set_objective_marker
      - approve_superweapon
      - toggle_power
      - designate_expansion
      - transfer_control

    cannot:
      - select_mobile_units
      - queue_production
      - command_units

    shared_visibility: true
    independent_camera: true

  quartermaster:
    display_name: "Quartermaster"
    icon: "ui/roles/quartermaster.png"
    color: "#F5A623"                   # gold
    description: "Economy, production, supply chain"
    min_players_required: 3            # merged with Commander in 2-player

    selectable_entities:
      tags_include: [harvester, production_building, refinery]

    actions:
      - queue_production
      - cancel_production
      - set_rally_point
      - command_harvesters
      - toggle_production_power
      - request_structure

    cannot:
      - place_structures
      - command_combat_units
      - research_tech

  field_marshal:
    display_name: "Field Marshal"
    icon: "ui/roles/field_marshal.png"
    color: "#D0021B"                   # red
    description: "Combat unit control, tactical operations"
    min_players_required: 2            # always present

    selectable_entities:
      tags_include: [combat, infantry, vehicle, naval]
      tags_exclude: [spec_ops, hero, air, harvester, engineer_unit]

    actions:
      - move
      - attack_move
      - attack_target
      - patrol
      - guard
      - stop
      - hold_position
      - set_formation
      - request_production

    cannot:
      - build_structures
      - queue_production
      - research_tech
      - control_air_units

  spec_ops:
    display_name: "Spec Ops"
    icon: "ui/roles/spec_ops.png"
    color: "#7ED321"                   # green
    description: "Elite units, infiltration, sabotage, intelligence"
    min_players_required: 4
    unit_cap: 15

    selectable_entities:
      tags_include: [spec_ops, hero]

    actions:
      - move
      - attack_target
      - infiltrate
      - sabotage
      - plant_c4
      - steal_tech
      - cloak
      - mark_target
      - use_ability
      - request_elite_production

    cannot:
      - build_structures
      - command_standard_army
      - queue_standard_production

  chief_engineer:
    display_name: "Chief Engineer"
    icon: "ui/roles/chief_engineer.png"
    color: "#9013FE"                   # purple
    description: "Defensive structures, walls, repairs, fortification"
    min_players_required: 5

    selectable_entities:
      tags_include: [defense_turret, wall, gate, mine, sensor, engineer_unit]

    actions:
      - place_defense_structure
      - place_wall
      - place_mine
      - repair_structure
      - repair_vehicle
      - reclaim_wreckage
      - command_engineers
      - fortify

    cannot:
      - place_production_buildings
      - command_combat_units
      - research_tech

  air_marshal:
    display_name: "Air Marshal"
    icon: "ui/roles/air_marshal.png"
    color: "#50E3C2"                   # teal
    description: "Air superiority, bombing runs, transport operations"
    min_players_required: 5

    selectable_entities:
      tags_include: [air, airfield]

    actions:
      - move
      - attack_target
      - patrol_air
      - bombing_run
      - paradrop
      - air_transport
      - request_air_production

    cannot:
      - command_ground_units
      - build_non_airfield_structures

# Role merging rules (when fewer players)
merge_rules:
  2_players:
    - {role: commander, absorbs: [quartermaster, chief_engineer]}
    - {role: field_marshal, absorbs: [spec_ops, air_marshal]}

  3_players:
    - {role: commander, absorbs: [chief_engineer]}
    - {role: quartermaster, absorbs: []}
    - {role: field_marshal, absorbs: [spec_ops, air_marshal]}

  4_players:
    - {role: commander, absorbs: [chief_engineer]}
    - {role: quartermaster, absorbs: []}
    - {role: field_marshal, absorbs: [air_marshal]}
    - {role: spec_ops, absorbs: []}
```

---

## 6. AI Personality Schema

```yaml
# schema: ai_personality
# file pattern: data/ai_personalities/{personality_name}.yaml

personality_id: "colonel_volkov"
display_name: "Colonel Volkov"
faction_affinity: "forge"              # preferred faction (can play either)
difficulty: "hard"
portrait: "ui/portraits/volkov.png"
description: "Relentless aggressor. Will pressure you from minute one."
unlock_condition: "beat_any_hard_ai"   # null = available from start

voice_lines:
  game_start: "Your defenses mean nothing."
  first_attack: "Here they come."
  losing: "You think you've won? I'm just getting started."
  winning: "Crumble."
  superweapon: "Fire everything."

# See 05-AI-SYSTEMS.md for full strategy_weights documentation
strategy_weights:
  expand_economy: 0.5
  build_army: 1.5
  tech_up: 0.6
  attack: 1.8
  defend: 0.4
  harass: 1.2

behavior:
  first_attack_tick: 600
  attack_frequency: "high"
  retreat_threshold: 0.3
  expansion_timing: "late"
  tech_priority: ["vehicles", "infantry", "air"]
  preferred_composition:
    infantry: 0.3
    vehicles: 0.6
    air: 0.1

difficulty_modifiers:
  resource_bonus: 1.0
  reaction_time_ticks: 5
  micro_precision: 0.8
  scouting_frequency: "high"
  multi_prong_attacks: true
  uses_superweapon: true
```

---

## 7. Schema Validation

All YAML files should be validated at load time and in CI:

```
Validation Rules:
    1. All referenced IDs must exist (unit references structure, tech references unit, etc.)
    2. Numeric values must be within sane ranges (health > 0, cost >= 0, etc.)
    3. Enum values must match allowed set (damage_type, armor_type, etc.)
    4. Tech tree must be acyclic (no circular dependencies)
    5. Every unit must have at least one production source
    6. Every production structure must produce at least one unit
    7. Faction rosters must cover all counter relationships (no unbeatable composition)
    8. Map spawn points must be on valid terrain
    9. Resource nodes must be reachable by harvesters
```

### CI Integration

```bash
# Run on every push
python tools/validate_schemas.py data/

# Output:
# ✓ 24 unit definitions valid
# ✓ 16 structure definitions valid
# ✓ 2 tech trees valid (no cycles, all refs resolved)
# ✓ 4 maps valid (spawns on valid terrain, resources reachable)
# ✓ 6 AI personalities valid
# ✗ ERROR: aegis_heavy_tank.yaml references "aegis_advanced_tech_center" — ID not found
```
