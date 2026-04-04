# Production System Interface

**System:** `ProductionSystem`
**Tick Pipeline Step:** 5
**File:** `src/systems/production_system.gd`

## Purpose

Advances production queues, spawns completed units, handles queue management. Consumes resources via EconomySystem.

## Interface

```gdscript
class_name ProductionSystem

## Main tick — advance all production queues, spawn completed units.
func tick(ecs: ECS, tick_count: int) -> void
```

## tick() Behavior

1. For each entity with `ProductionQueue` component:
   a. Skip if `PoweredOff` tag present
   b. Skip if `queue` is empty
   c. Advance `progress` by `rate / TICKS_PER_SECOND` (rate is in build-time-seconds per second; progress tracks toward `build_time` of the current item)
   d. When `progress >= build_time` of front item:
      - Spawn the unit entity via `EntityFactory`
      - Set spawn position to building exit point
      - If `RallyPoint` component exists, issue `MoveCommand` to rally position
      - Auto-assign ownership via `PermissionSystem.assign_entity()`
      - Dequeue front item, reset `progress` to 0
      - Carry over excess progress to next item if queue not empty
2. Track `spend_rate` for UI

## Queue Mechanics

| Property | Value |
|----------|-------|
| Max queue depth | 5 items |
| Resource deduction | On enqueue (not on completion) |
| Progress unit | Seconds of build time completed |
| Rate | `ProductionQueue.rate` (default 1.0 = real-time; 2.0 = double speed) |

## Enqueue Flow (called from CommandProcessing when QueueProduction validated)

```
1. Check queue.size() < MAX_QUEUE_DEPTH → else reject QUEUE_FULL
2. Look up unit definition → get cost.primary, cost.secondary, build_time
3. Call EconomySystem.spend(faction_id, cost.primary, cost.secondary) → reject INSUFFICIENT_RESOURCES if false
4. Append UnitType to queue
```

## Cancel Production

- Cancel by queue index (0 = currently building)
- **Refund policy:** 100% refund of cost
- If cancelling index 0 (in-progress): refund full cost, reset progress, advance queue
- If cancelling index > 0: refund full cost, remove from queue

## Building Destroyed Mid-Queue

- All queued items are refunded at **50%** (half cost returned to faction)
- In-progress item: 50% refund regardless of progress
- Queue is cleared (entity is about to be removed by DeathSystem)

## Rally Point

- `RallyPoint` component on production buildings (optional, set via `SetRallyPoint` command)
- Default rally point: building exit position (offset from building center based on footprint)
- When unit spawns: if rally point exists and differs from exit, issue `MoveCommand` to rally position

## Integration Notes

- **Reads:** `ProductionQueue`, `Structure`, `FactionComponent`, `RallyPoint`, `PoweredOff`
- **Writes:** `ProductionQueue` (progress, dequeue), spawns new entities
- **Depends on:** EconomySystem (spend/refund), PermissionSystem (assign_entity)
- **Consumed by:** UI (queue display, ETA)

## Test Cases

### 1. Queue and Complete a Unit
**Setup:** War factory with ProductionQueue (rate=1.0), queue 1 medium_tank (build_time=12.0)
**Simulate:** 180 ticks (12 seconds)
**Assert:** Tank entity spawned at factory exit, queue empty, progress == 0

### 2. Cancel Mid-Production
**Setup:** War factory building a tank (build_time=12, progress=6.0 at tick 90). Queue has 1 more item behind it.
**Action:** CancelProduction(factory, index=0)
**Assert:** Full cost refunded, progress reset to 0, second item is now building

### 3. Building Destroyed with Queue
**Setup:** War factory with 3 items in queue, first at 50% progress
**Action:** Health.current set to 0 (DeathSystem will remove)
**Assert:** Each item refunded at 50% cost. (ProductionSystem detects Structure removal and processes refund before DeathSystem clears entity — or DeathSystem triggers refund callback.)

### 4. Rally Point
**Setup:** War factory with rally point at (30, 30), building a rifleman
**Simulate:** Until unit spawns
**Assert:** Spawned unit has MoveCommand with destination (30, 30)

### 5. Queue Full Rejection
**Setup:** War factory with 5 items already queued
**Action:** QueueProduction(factory, light_tank)
**Assert:** Rejected with QUEUE_FULL, no resources deducted
