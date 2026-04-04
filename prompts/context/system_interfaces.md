# System Interfaces Registry

Master reference for all Phase 1 ECS systems. Each system runs once per tick in the order listed.

## Tick Pipeline (15 ticks/sec, 66ms budget)

| Step | System | Status | Interface Spec | Reads | Writes |
|------|--------|--------|---------------|-------|--------|
| 1 | InputSystem | Phase 2 | — | Network buffer | CommandQueue |
| 2 | CommandValidation | **Phase 1** | [permission_system.md](interfaces/permission_system.md) | CommandQueue, RoleOwnership | ValidatedCommands, RejectedCommands |
| 3 | AIDecisionSystem | Phase 2 | — | ECS world state | CommandQueue |
| 4 | EconomySystem | **Phase 1** | [economy_system.md](interfaces/economy_system.md) | Harvester, ResourceNode, PowerConsumer, PowerProducer, FactionComponent | Harvester, ResourceNode, FactionResources |
| 5 | ProductionSystem | **Phase 1** | [production_system.md](interfaces/production_system.md) | ProductionQueue, FactionResources, Structure | ProductionQueue, spawns entities |
| 6 | CommandProcessing | **Phase 1** | [command_protocol.md](interfaces/command_protocol.md) | ValidatedCommands | MoveCommand, AttackCommand, etc. |
| 7 | PathfindingSystem | Phase 2 (C++) | — | MoveCommand, Position | PathState |
| 8 | MovementSystem | **Phase 1** | [movement_system.md](interfaces/movement_system.md) | Position, Velocity, MoveSpeed, PathState, MoveCommand | Position, Velocity |
| 9 | CombatSystem | **Phase 1** | [combat_system.md](interfaces/combat_system.md) | Position, Weapon, Health, AttackCommand, FactionComponent | Health, Weapon.cooldown_remaining |
| 10 | DeathSystem | **Phase 1** | (simple — remove entities where Health.current <= 0) | Health | Entity removal |
| 11 | VisionSystem | **Phase 1** | [vision_system.md](interfaces/vision_system.md) | Position, VisionRange, FactionComponent, Stealthed, Detector | FogOfWarGrid |
| 12 | StatusEffectSystem | Phase 2 | — | StatusEffects | Health, MoveSpeed, etc. |
| 13 | SnapshotSystem | Phase 2 | — | All changed components | Network buffer |

## Cross-System Data Flow

```
Commands → [Permission] → ValidatedCommands → [CommandProcessing] → MoveCommand/AttackCommand
                                                        ↓
FactionResources ← [Economy] ← Harvester/ResourceNode    ↓
        ↓                                          [Pathfinding] → PathState
   [Production] → spawn entities                        ↓
                                                  [Movement] → Position
                                                        ↓
                                                   [Combat] → Health
                                                        ↓
                                                    [Death] → entity removal
                                                        ↓
                                                   [Vision] → FogOfWarGrid
```

## Shared State

| State | Owner System | Consumers |
|-------|-------------|-----------|
| `FactionResources` (Dictionary per faction) | EconomySystem | ProductionSystem, UI |
| `FogOfWarGrid` (2D array per team) | VisionSystem | SnapshotSystem (filters state), UI |
| `CommandQueue` (Array per tick) | InputSystem | CommandValidation |
| `ValidatedCommands` (Array per tick) | CommandValidation | CommandProcessing |
