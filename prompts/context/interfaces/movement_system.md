# Movement System Interface

**System:** `MovementSystem`
**Tick Pipeline Step:** 8
**File:** `src/systems/movement_system.gd`

## Purpose

Moves entities along paths, handles arrival, and performs simple collision avoidance.

## Interface

```gdscript
class_name MovementSystem

## Main tick — advance all moving entities along their paths.
func tick(ecs: ECS, tick_count: int) -> void
```

## tick() Behavior

For each entity with `Position` + `MoveSpeed` components:

1. **No movement needed:** If no `MoveCommand` and no `PathState` with remaining waypoints → set `Velocity` to (0,0), skip
2. **Path following (if PathState exists and has waypoints):**
   a. Get current waypoint: `PathState.path[PathState.current_index]`
   b. Calculate direction to waypoint: `dir = (waypoint - Position).normalized()`
   c. Calculate step: `step = dir * MoveSpeed.speed / TICKS_PER_SECOND`
   d. If distance to waypoint < step magnitude → snap to waypoint, advance `current_index`
   e. Else → `Position += step`
   f. Set `Velocity = dir * MoveSpeed.speed`
   g. When `current_index >= path.size()`: arrival — clear `PathState`, clear `MoveCommand`, set `Velocity` to (0,0)
3. **Direct movement (MoveCommand exists but no PathState — Phase 1 fallback):**
   - Move directly toward `MoveCommand.destination` (straight line)
   - On arrival (distance < 1.0): clear `MoveCommand`, set `Velocity` to (0,0)
4. **Collision avoidance (separation steering):**
   - For each moving entity, check nearby entities within `SEPARATION_RADIUS` (2.0 units)
   - Apply push-apart force: `separation = sum of (self.pos - other.pos).normalized() / distance` for all nearby
   - Add separation to velocity (scaled by `SEPARATION_WEIGHT = 0.3`)
   - Flying entities skip ground collision avoidance (but avoid other flyers)

## MoveCommand → Pathfinding (handled by CommandProcessing, Step 6)

When a `MoveCommand` is created from a validated command:
1. CommandProcessing reads `MoveCommand.destination`
2. Submits pathfinding request to PathfindingSystem
3. PathfindingSystem writes `PathState` with computed path
4. MovementSystem consumes `PathState` to move the entity

**Phase 1 note:** Pathfinding may be a simple straight-line or basic A* placeholder. MovementSystem works the same either way — it just follows `PathState.path` waypoints.

## Constants

| Constant | Value | Notes |
|----------|-------|-------|
| `TICKS_PER_SECOND` | 15 | |
| `SEPARATION_RADIUS` | 2.0 | Units within this push apart |
| `SEPARATION_WEIGHT` | 0.3 | Strength of push-apart |
| `ARRIVAL_THRESHOLD` | 0.5 | Distance to consider "arrived" at waypoint |

## Integration Notes

- **Reads:** `Position`, `Velocity`, `MoveSpeed`, `PathState`, `MoveCommand`, `Flying`
- **Writes:** `Position`, `Velocity`, clears `MoveCommand` and `PathState` on arrival
- **Depends on:** PathfindingSystem has written `PathState` (Step 7)
- **Consumed by:** CombatSystem uses updated positions for range checks (Step 9)

## Test Cases

### 1. Unit Reaches Destination
**Setup:** Unit at (0,0), MoveSpeed=5.0, PathState with single waypoint (10,0)
**Simulate:** 30 ticks (2 seconds)
**Assert:** Position == (10,0), Velocity == (0,0), MoveCommand cleared, PathState cleared

### 2. Multi-Waypoint Path
**Setup:** Unit at (0,0), MoveSpeed=5.0, PathState with waypoints [(5,0), (5,5), (10,5)]
**Simulate:** Until arrival
**Assert:** Unit visits each waypoint in order, final Position == (10,5)

### 3. Path Blocked Mid-Move (entity destroyed at destination)
**Setup:** Unit moving toward (10,0). Destination becomes blocked (structure placed).
**Simulate:** Pathfinding re-query expected (CommandProcessing or PathfindingSystem handles re-path)
**Assert:** MovementSystem continues following whatever PathState is set. If PathState cleared externally, unit stops.

### 4. Collision Avoidance
**Setup:** 5 units all given same destination (10,10), starting at (0,0), (0,1), (1,0), (1,1), (0.5, 0.5)
**Simulate:** Until arrival
**Assert:** Units don't stack on exact same position. Final positions within ~2.0 units of (10,10) but spread out.

### 5. Unit Dies Mid-Move
**Setup:** Unit moving toward (10,0). At tick 20, Health set to 0.
**Assert:** DeathSystem removes entity. MovementSystem simply won't find it next tick — no special handling needed.
