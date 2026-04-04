# 02 — Technical Architecture

## 1. Technology Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| **Engine** | Godot 4.4+ | Free, open source, excellent multiplayer support, GDScript is agent-friendly, C++ via GDExtension for hot paths |
| **Language (Gameplay)** | GDScript | Fast iteration, huge training corpus for AI agents, good enough performance for gameplay logic |
| **Language (Performance)** | C++ (GDExtension) | Pathfinding, simulation tick, spatial queries — anything called thousands of times per frame |
| **Networking** | ENet (built-in Godot) | Reliable UDP, built-in peer management, sufficient for co-op (not competitive) |
| **Data Formats** | YAML (design data), JSON (runtime serialization) | Human-readable, agent-friendly, diffable in git |
| **Build System** | Godot export + GitHub Actions CI | Cross-platform builds, automated testing |
| **Version Control** | Git + GitHub | Standard, works with agent workflows |

## 2. High-Level Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                        HOST MACHINE                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              AUTHORITATIVE SIMULATION                    │  │
│  │  ┌─────────┐ ┌──────────┐ ┌──────────┐ ┌────────────┐  │  │
│  │  │   ECS   │ │Pathfinder│ │ Combat   │ │  Economy   │  │  │
│  │  │  World  │ │(flowfield│ │ Resolver │ │  Tick      │  │  │
│  │  │  State  │ │  + A*)   │ │          │ │            │  │  │
│  │  └─────────┘ └──────────┘ └──────────┘ └────────────┘  │  │
│  │  ┌─────────┐ ┌──────────┐ ┌──────────┐ ┌────────────┐  │  │
│  │  │  Fog of │ │  Role    │ │ Command  │ │    AI      │  │  │
│  │  │   War   │ │Permission│ │  Queue   │ │ Opponent   │  │  │
│  │  │         │ │  System  │ │          │ │  + Partner │  │  │
│  │  └─────────┘ └──────────┘ └──────────┘ └────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                     State Snapshots                             │
│                     + Command Validation                        │
│                              │                                  │
│         ┌────────────────────┼────────────────────┐            │
│         ▼                    ▼                    ▼            │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐         │
│  │  Client 1   │   │  Client 2   │   │  Client N   │         │
│  │  (Cmdr UI)  │   │  (FM UI)    │   │  (QM UI)    │         │
│  │  Renderer   │   │  Renderer   │   │  Renderer   │         │
│  │  Input      │   │  Input      │   │  Input      │         │
│  │  Camera     │   │  Camera     │   │  Camera     │         │
│  └─────────────┘   └─────────────┘   └─────────────┘         │
└────────────────────────────────────────────────────────────────┘
```

### Architecture Model: Host-Authoritative with Client Prediction

- **Host** runs the authoritative simulation (one player is host, or dedicated server in future)
- **Clients** send commands, receive state snapshots
- **No deterministic lockstep needed** — co-op vs AI tolerates ~50-100ms latency gracefully
- **Client-side prediction** for camera movement and UI responsiveness only — no gameplay prediction needed

This is dramatically simpler than competitive RTS networking.

## 3. Entity Component System (ECS)

### Why ECS
- RTS games can have hundreds of units — ECS gives cache-friendly iteration
- Components map cleanly to role permissions (tag system)
- Agents can implement individual systems in isolation
- Godot 4's node system can coexist — use nodes for rendering, ECS for simulation

### Core Components

```
# Identity
EntityId          : u64
FactionComponent  : { faction_id: u8 }
RoleOwnership     : { role: Role, transferable: bool }
DisplayName       : { name: String }

# Spatial
Position          : { x: f32, y: f32 }
Velocity          : { x: f32, y: f32 }
Rotation          : { angle: f32 }
Footprint         : { width: u8, height: u8 }  # for structures
CollisionLayer    : { layers: u32 }

# Combat
Health            : { current: f32, max: f32, armor_type: ArmorType }
Weapon            : { damage: f32, range: f32, cooldown: f32, damage_type: DamageType, targets: TargetMask }
Attackable        : {}  # tag
AttackCommand     : { target: EntityId }

# Movement
MoveSpeed         : { speed: f32 }
MoveCommand       : { destination: Vec2, queued: bool }
PathState         : { path: Vec<Vec2>, current_index: u32 }
Flying            : {}  # tag — ignores terrain collision

# Economy
Harvester         : { capacity: f32, current_load: f32, resource_type: ResourceType }
ResourceNode      : { type: ResourceType, remaining: f32 }
ProductionQueue   : { queue: Vec<UnitType>, progress: f32, rate: f32 }

# Structure
Structure         : { built: bool, build_progress: f32 }
PowerConsumer     : { drain: f32 }
PowerProducer     : { output: f32 }
TechProvider      : { techs: Vec<TechId> }

# Visibility
VisionRange       : { range: f32 }
Stealthed         : { detection_range: f32 }  # how close enemy must be to see
Detector          : { range: f32 }

# Role Tags
CommanderControlled    : {}
QuartermasterControlled: {}
FieldMarshalControlled : {}
SpecOpsControlled      : {}
ChiefEngineerControlled: {}
AirMarshalControlled   : {}
```

### Core Systems (Execution Order per Tick)

```
1. InputSystem          — Reads commands from all clients
2. CommandValidation    — Checks role permissions, rejects invalid commands
3. AIDecisionSystem     — AI opponent + AI partners generate commands
4. EconomySystem        — Harvest, refine, spend, income tracking
5. ProductionSystem     — Advance build queues, spawn completed units
6. CommandProcessing    — Convert move/attack commands to pathfinding requests
7. PathfindingSystem    — Calculate/update paths (flowfield for groups, A* for individuals)
8. MovementSystem       — Apply velocity, collision avoidance
9. CombatSystem         — Range checks, damage application, target acquisition
10. DeathSystem         — Remove dead entities, trigger death effects
11. VisionSystem        — Update fog of war per entity vision range
12. StatusEffectSystem  — Tick buffs, debuffs, DOTs
13. SnapshotSystem      — Package state delta for network broadcast
```

### Tick Rate

- **Simulation:** 15 ticks/second (66ms per tick) — sufficient for RTS, keeps CPU budget sane with many units
- **Rendering:** Decoupled, runs at display refresh rate with interpolation between sim states
- **Network:** State deltas sent every 2 sim ticks (133ms) — fine for co-op latency tolerance

## 4. Networking Architecture

### Command-Based Protocol

Clients never modify game state directly. They send commands:

```
Command {
    player_id: PlayerId,
    role: Role,
    tick: u64,           # which sim tick this targets
    action: CommandAction,
}

CommandAction (enum):
    | MoveUnits { unit_ids: Vec<EntityId>, destination: Vec2 }
    | AttackTarget { unit_ids: Vec<EntityId>, target: EntityId }
    | PlaceStructure { structure_type: StructureType, position: Vec2 }
    | QueueProduction { factory_id: EntityId, unit_type: UnitType }
    | CancelProduction { factory_id: EntityId, queue_index: u8 }
    | SetRallyPoint { factory_id: EntityId, position: Vec2 }
    | Research { lab_id: EntityId, tech_id: TechId }
    | PingMap { position: Vec2, ping_type: PingType }
    | RequestFromRole { target_role: Role, request: ResourceRequest }
    | ApproveSuperweapon { weapon_id: EntityId, confirmed: bool }
    | TransferControl { entity_id: EntityId, to_role: Role }
```

### Validation Flow

```
Client sends Command
    → Server receives
    → PermissionSystem checks:
        1. Does this player have this role?
        2. Does this role have permission for this action?
        3. Does this role own the target entities?
        4. Are prerequisites met (tech, resources, etc.)?
    → If valid: queue for next simulation tick
    → If invalid: reject with reason code → client shows error feedback
```

### State Synchronization

- **Full state snapshot** on client connect (or reconnect)
- **Delta compression** every 2 ticks: only changed components
- **Priority system:** nearby visible entities get full updates, distant entities get reduced update frequency
- **Fog of war masking:** clients only receive data for entities in their team's vision

### Session Management

```
Lobby:
    → Host creates game session
    → Players join, select roles
    → Empty roles filled with AI (configurable difficulty)
    → Host starts game → simulation begins

Mid-Game:
    → Player disconnects → AI takes over their role immediately
    → New player joins → can take over AI role (hot-swap)
    → Host disconnects → host migration to next player
```

## 5. Role Permission System

This is a first-class system, not an afterthought.

```yaml
# role_permissions.yaml

commander:
  can_select:
    - structures
    - construction_yard
  can_build:
    - all_structures
  can_research:
    - all_tech
  can_command_units: false
  can_queue_production: false
  special_actions:
    - ping_map
    - set_objective_marker
    - approve_superweapon
    - designate_expansion
    - toggle_power

quartermaster:
  can_select:
    - harvesters
    - production_buildings
    - refineries
  can_build: false
  can_research: false
  can_command_units:
    - harvesters_only
  can_queue_production: true
  special_actions:
    - set_rally_point
    - prioritize_resource
    - request_structure  # asks Commander
    - toggle_production_building_power

field_marshal:
  can_select:
    - infantry
    - vehicles
    - naval
  can_build: false
  can_research: false
  can_command_units: true
  unit_filter:
    exclude_tags: [spec_ops, hero, air, harvester]
  special_actions:
    - request_production
    - set_defensive_stance
    - formations

spec_ops:
  can_select:
    - spec_ops_units
    - hero_units
  can_build: false
  can_research: false
  can_command_units: true
  unit_filter:
    require_tags: [spec_ops, hero]
  unit_cap: 15
  special_actions:
    - mark_target
    - sabotage
    - infiltrate
    - call_support_strike

chief_engineer:
  can_select:
    - defensive_structures
    - walls
    - engineer_units
  can_build:
    - turrets
    - walls
    - gates
    - mines
    - sensors
  can_command_units:
    - engineer_units_only
  special_actions:
    - repair_structure
    - repair_vehicle
    - reclaim_wreckage
    - fortify

air_marshal:
  can_select:
    - air_units
    - airfields
  can_build:
    - airfield_structures
  can_command_units: true
  unit_filter:
    require_tags: [air]
  special_actions:
    - air_patrol
    - bombing_run
    - paradrop
    - request_aa_coverage
```

### Unit Ownership Assignment

When a unit is produced, it's automatically assigned to the correct role based on its tags:

```
on_unit_produced(unit):
    if unit.has_tag("air"):
        assign_to(AirMarshal)
    elif unit.has_tag("spec_ops") or unit.has_tag("hero"):
        assign_to(SpecOps)
    elif unit.has_tag("engineer"):
        assign_to(ChiefEngineer)
    elif unit.has_tag("harvester"):
        assign_to(Quartermaster)
    elif unit.has_tag("combat"):
        assign_to(FieldMarshal)
```

### Transfer Mechanic

Some units can be transferred between roles:
- Commander can transfer a defensive turret to Chief Engineer's control
- Field Marshal can designate units as "support Spec Ops" (temporary)
- Transfer requires both roles to confirm

## 6. Pathfinding Architecture

### Hybrid Approach

- **Flowfield** for large group movement (>5 units moving to same area) — computed once, shared by all units in the group
- **A* with JPS** (Jump Point Search) for individual units and small groups
- **Navigation mesh** for Spec Ops pathfinding (different traversability — can use narrow paths, ladders, etc.)
- **Steering behaviors** for local avoidance (separation, alignment, cohesion for formations)

### Implementation

- Built as GDExtension (C++) for performance
- Runs on separate thread, returns paths asynchronously
- Terrain grid resolution: 1 unit = 1 cell (buildings occupy multiple cells)
- Path cache with invalidation on structure placement/destruction

## 7. Fog of War

### Implementation Strategy

- **Grid-based:** Map divided into visibility cells (2x2 unit cells per fog cell)
- **Three states:** Unexplored (black), Previously seen (dim/frozen), Currently visible (full)
- **Per-team:** All players on the team share the same vision
- **GPU-accelerated:** Vision computed on CPU, fog rendered as GPU texture overlay
- **Update rate:** Every simulation tick (15/sec)

### Vision Sources

- Units: circular vision range from VisionRange component
- Structures: typically larger vision range
- Sensor towers: very large range
- Spec Ops scouts: vision + detection (reveals stealth)

## 8. Project Structure

```
crto-game/
├── docs/                          # Design & architecture docs (this)
├── game/                          # Godot project root
│   ├── project.godot
│   ├── addons/                    # Third-party plugins
│   ├── assets/
│   │   ├── sprites/
│   │   ├── audio/
│   │   ├── shaders/
│   │   └── ui/
│   ├── data/                      # YAML data files (agent-editable)
│   │   ├── units/
│   │   │   ├── aegis_units.yaml
│   │   │   └── forge_units.yaml
│   │   ├── structures/
│   │   ├── tech_trees/
│   │   ├── maps/
│   │   ├── ai_personalities/
│   │   └── role_permissions.yaml
│   ├── src/
│   │   ├── core/                  # ECS, game loop, tick management
│   │   │   ├── ecs.gd
│   │   │   ├── game_loop.gd
│   │   │   ├── simulation.gd
│   │   │   └── entity_factory.gd
│   │   ├── systems/               # ECS systems (one file per system)
│   │   │   ├── movement_system.gd
│   │   │   ├── combat_system.gd
│   │   │   ├── economy_system.gd
│   │   │   ├── production_system.gd
│   │   │   ├── vision_system.gd
│   │   │   ├── pathfinding_system.gd
│   │   │   └── permission_system.gd
│   │   ├── network/               # Multiplayer networking
│   │   │   ├── command_protocol.gd
│   │   │   ├── state_sync.gd
│   │   │   ├── session_manager.gd
│   │   │   └── host_migration.gd
│   │   ├── ai/                    # AI systems
│   │   │   ├── opponent/
│   │   │   │   ├── ai_opponent.gd
│   │   │   │   ├── behavior_trees/
│   │   │   │   └── personalities/
│   │   │   └── partner/
│   │   │       ├── ai_partner.gd
│   │   │       ├── commander_ai.gd
│   │   │       ├── quartermaster_ai.gd
│   │   │       ├── field_marshal_ai.gd
│   │   │       └── spec_ops_ai.gd
│   │   ├── ui/                    # Per-role UI
│   │   │   ├── shared/
│   │   │   │   ├── minimap.gd
│   │   │   │   ├── resource_bar.gd
│   │   │   │   ├── ping_system.gd
│   │   │   │   └── comms_panel.gd
│   │   │   ├── commander/
│   │   │   ├── quartermaster/
│   │   │   ├── field_marshal/
│   │   │   └── spec_ops/
│   │   └── roles/                 # Role management
│   │       ├── role_manager.gd
│   │       ├── role_definitions.gd
│   │       └── role_assignment.gd
│   ├── native/                    # C++ GDExtension
│   │   ├── pathfinding/
│   │   │   ├── flowfield.cpp
│   │   │   ├── astar_jps.cpp
│   │   │   └── nav_mesh.cpp
│   │   └── simulation/
│   │       └── spatial_hash.cpp
│   └── tests/                     # Test scenes and scripts
│       ├── test_combat.gd
│       ├── test_economy.gd
│       ├── test_permissions.gd
│       └── test_networking.gd
├── tools/                         # Build & development tools
│   ├── map_editor/
│   └── balance_simulator/
└── prompts/                       # Agent prompt library (versioned)
    ├── systems_architect.md
    ├── engine_engineer.md
    ├── gameplay_engineer.md
    ├── network_engineer.md
    ├── ai_engineer.md
    ├── ui_engineer.md
    └── devops_engineer.md
```

## 9. Performance Budgets

| Metric | Target | Notes |
|--------|--------|-------|
| Max entities | 500 | Units + structures + projectiles |
| Sim tick time | <15ms | At 15 ticks/sec, leaves headroom |
| Pathfinding | <5ms per group | Async, amortized across ticks |
| Network bandwidth | <50 KB/s per client | Delta compression + fog masking |
| Memory | <512 MB | Gameplay data; rendering separate |
| Render target | 60 FPS | Decoupled from sim; interpolated |

## 10. Testing Strategy

### Deterministic Simulation Tests
```
# Example: combat balance test
setup:
  spawn: [{type: "aegis_medium_tank", count: 5, position: [10, 10]}]
  spawn: [{type: "forge_battle_tank", count: 5, position: [20, 10]}]
  command: [attack_move, group_0, [20, 10]]
  command: [attack_move, group_1, [10, 10]]
simulate: 300 ticks
assert:
  - group_0.survivors <= 2
  - group_1.survivors <= 2
  # roughly even fight
```

### Permission Tests
```
# Verify role boundaries
test: "field_marshal_cannot_build"
  role: field_marshal
  action: place_structure(barracks, [10, 10])
  expect: rejected(PERMISSION_DENIED)

test: "commander_cannot_move_units"
  role: commander
  action: move_units([tank_1], [20, 20])
  expect: rejected(PERMISSION_DENIED)
```

### Network Tests
- Simulated latency injection (100ms, 200ms, 500ms)
- Client disconnect/reconnect during active game
- Host migration under load
- Hot-swap AI → human for each role
