# Permission System Interface

**System:** `PermissionSystem`
**Tick Pipeline Step:** 2 (CommandValidation)
**File:** `src/systems/permission_system.gd`

## Purpose

Validates every command against role permissions before it enters the simulation. Rejects invalid commands with typed error codes. This is the security boundary — no gameplay action bypasses it.

## Interface

```gdscript
class_name PermissionSystem

## Check if a player/role can execute a given command action.
## Returns true if permitted, false otherwise.
func can_execute(player_id: int, role: Role, action: CommandAction) -> bool

## Get all entity IDs owned by a given role for a specific faction.
func get_owned_entities(role: Role, faction_id: int) -> Array[int]

## Assign an entity to a role. Called by EntityFactory on unit spawn.
## Sets the appropriate role tag component (e.g., FieldMarshalControlled).
func assign_entity(entity_id: int, role: Role) -> void

## Transfer an entity from one role to another. Both roles must exist.
## Returns false if entity is not transferable or from_role doesn't own it.
func transfer_entity(entity_id: int, from_role: Role, to_role: Role) -> bool

## Main tick entry point. Reads CommandQueue, writes ValidatedCommands + RejectedCommands.
func tick(ecs: ECS, tick_count: int) -> void
```

## tick() Behavior

1. Read all commands from `CommandQueue` for this tick
2. For each command:
   a. Verify `player_id` has `role` assigned in the current session
   b. Call `can_execute(player_id, role, command.action)`
   c. For entity-targeting commands, verify role owns all referenced entities
   d. For resource-spending commands, verify tech prerequisites are met
   e. If valid → append to `ValidatedCommands`
   f. If invalid → append to `RejectedCommands` with `CommandError` code
3. Clear `CommandQueue`

## can_execute() Rules

### CommandAction → Allowed Roles

| CommandAction | Commander | Quartermaster | FieldMarshal | SpecOps | ChiefEngineer | AirMarshal |
|---------------|:---------:|:------------:|:------------:|:-------:|:-------------:|:----------:|
| `MoveUnits` | ✗ | harvesters | ✓ (own units) | ✓ (own units) | engineers | ✓ (air) |
| `AttackTarget` | ✗ | ✗ | ✓ | ✓ | ✗ | ✓ |
| `PlaceStructure` | ✓ | ✗ | ✗ | ✗ | defense only | ✗ |
| `QueueProduction` | ✗ | ✓ | ✗ | ✗ | ✗ | ✗ |
| `CancelProduction` | ✗ | ✓ | ✗ | ✗ | ✗ | ✗ |
| `SetRallyPoint` | ✗ | ✓ | ✗ | ✗ | ✗ | ✗ |
| `Research` | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| `PingMap` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `RequestFromRole` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `ApproveSuperweapon` | ✓ | ✗ | ✓ | ✗ | ✗ | ✗ |
| `TransferControl` | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| `SetFormation` | ✗ | ✗ | ✓ | ✗ | ✗ | ✗ |
| `Patrol` | ✗ | ✗ | ✓ | ✗ | ✗ | ✓ |
| `Guard` | ✗ | ✗ | ✓ | ✗ | ✗ | ✗ |
| `HoldPosition` | ✗ | ✗ | ✓ | ✗ | ✗ | ✗ |
| `Stop` | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `Infiltrate` | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ |
| `Sabotage` | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ |
| `MarkTarget` | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ |
| `RepairStructure` | ✗ | ✗ | ✗ | ✗ | ✓ | ✗ |
| `RepairVehicle` | ✗ | ✗ | ✗ | ✗ | ✓ | ✗ |
| `PlaceWall` | ✗ | ✗ | ✗ | ✗ | ✓ | ✗ |
| `PlaceMine` | ✗ | ✗ | ✗ | ✗ | ✓ | ✗ |
| `BombingRun` | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ |
| `Paradrop` | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ |
| `TogglePower` | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |

## Entity Ownership Assignment (on spawn)

```
match unit.role_tag:
    "air"       → AirMarshal
    "spec_ops"  → SpecOps
    "hero"      → SpecOps
    "engineer"  → ChiefEngineer
    "harvester" → Quartermaster
    "combat"    → FieldMarshal
    "defense_turret" → ChiefEngineer
    "production" → Quartermaster (selectable, not commandable)
    "structure" → Commander
```

## Role Merging

When fewer than 6 players, roles merge. The absorbing role gains ALL permissions of absorbed roles.

| Players | Merges |
|---------|--------|
| 2 | Commander absorbs Quartermaster + ChiefEngineer. FieldMarshal absorbs SpecOps + AirMarshal. |
| 3 | Commander absorbs ChiefEngineer. FieldMarshal absorbs SpecOps + AirMarshal. |
| 4 | Commander absorbs ChiefEngineer. FieldMarshal absorbs AirMarshal. |
| 5+ | No merging. |

**Implementation:** Maintain a `merged_permissions: Dictionary[Role, Array[Role]]` mapping. `can_execute()` checks the player's base role AND all absorbed roles.

## CommandError Codes

```gdscript
enum CommandError {
    PERMISSION_DENIED,       # Role cannot perform this action type
    ENTITY_NOT_OWNED,        # Role doesn't own the target entity
    INVALID_TARGET,          # Target entity doesn't exist
    TECH_NOT_RESEARCHED,     # Missing tech prerequisite
    INSUFFICIENT_RESOURCES,  # Not enough primary/secondary
    INVALID_PLACEMENT,       # Structure can't be placed there
    QUEUE_FULL,              # Production queue at max depth
    UNIT_CAP_REACHED,        # SpecOps unit cap exceeded
    INVALID_COMMAND,         # Malformed command data
}
```

## Test Cases — Permission Denied

| # | Setup | Action | Expected |
|---|-------|--------|----------|
| 1 | 2-player game, Player A = Commander | `MoveUnits([tank_1], (20, 20))` | `PERMISSION_DENIED` — Commander cannot move combat units |
| 2 | Player B = FieldMarshal | `PlaceStructure(barracks, (10, 10))` | `PERMISSION_DENIED` — FM cannot place structures |
| 3 | Player B = FieldMarshal | `MoveUnits([spec_ops_1], (5, 5))` | `ENTITY_NOT_OWNED` — FM doesn't own spec ops units (absorbed in 2p, but still test 4p) |
| 4 | Player A = Quartermaster | `Research(aegis_advanced_armor, tech_lab_1)` | `PERMISSION_DENIED` — QM cannot research |
| 5 | Player C = SpecOps, unit_cap=15, has 15 units | `RequestEliteProduction(commando)` | `UNIT_CAP_REACHED` |

## Test Cases — Permission Granted

| # | Setup | Action | Expected |
|---|-------|--------|----------|
| 1 | Commander in 2-player game (absorbed QM) | `QueueProduction(war_factory_1, medium_tank)` | ✓ Valid — Commander has QM permissions via merge |
| 2 | FieldMarshal owns tank_1 | `AttackTarget([tank_1], enemy_unit_1)` | ✓ Valid |
| 3 | Commander | `PlaceStructure(barracks, (10, 10))` | ✓ Valid — enough resources, valid placement |
| 4 | Quartermaster | `SetRallyPoint(war_factory_1, (15, 15))` | ✓ Valid — QM owns production buildings |
| 5 | SpecOps | `Sabotage(spec_ops_1, enemy_power_plant)` | ✓ Valid — SpecOps owns the unit, action is permitted |
