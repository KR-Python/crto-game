# Economy System Interface

**System:** `EconomySystem`
**Tick Pipeline Step:** 4
**File:** `src/systems/economy_system.gd`

## Purpose

Manages resource income (harvesting), resource spending, and the power grid. Owns the `FactionResources` shared state.

## Interface

```gdscript
class_name EconomySystem

## Main tick — runs harvester state machines, calculates income, manages power grid.
func tick(ecs: ECS, tick_count: int) -> void

## Get current resource state for a faction.
## Returns: { "primary": float, "secondary": float, "income_rate": float, "spend_rate": float, "power_balance": float }
func get_resources(faction_id: int) -> Dictionary

## Attempt to spend resources. Returns false if insufficient (no partial spend).
func spend(faction_id: int, primary: float, secondary: float) -> bool

## Add income directly (e.g., bounty from killing units, mission rewards).
func add_income(faction_id: int, amount: float, resource_type: ResourceType) -> void
```

## FactionResources State (per faction)

```gdscript
var primary: float = 0.0
var secondary: float = 0.0
var income_rate: float = 0.0       # calculated each tick (amount per second)
var spend_rate: float = 0.0        # calculated each tick
var power_produced: float = 0.0
var power_consumed: float = 0.0
```

## tick() Behavior

1. **Power grid calculation:**
   - Sum all `PowerProducer.output` for the faction → `power_produced`
   - Sum all `PowerConsumer.drain` for the faction → `power_consumed`
   - If `power_consumed > power_produced` → trigger power shutdown cascade
2. **Harvester state machine** (for each Harvester entity):
   - Advance state, issue MoveCommands, handle load/unload
3. **Income tracking:**
   - Calculate `income_rate` from harvesters that delivered this tick
   - Calculate `spend_rate` from spending since last tick

## Harvester State Machine

```
idle → moving_to_node → harvesting → returning → idle
 │          │               │            │
 │          │               │            └─ Arrives at refinery:
 │          │               │               add current_load to faction resources,
 │          │               │               reset current_load to 0,
 │          │               │               transition to idle
 │          │               │
 │          │               └─ Each tick: current_load += harvest_rate
 │          │                  When current_load >= capacity OR node depleted:
 │          │                  transition to returning
 │          │
 │          └─ MoveCommand issued to nearest resource node
 │             On arrival: transition to harvesting
 │
 └─ Assign target_node (nearest undepleted node of matching resource_type)
    Issue MoveCommand to node position
    transition to moving_to_node
    If no valid node exists: stay idle
```

**Harvest rate:** `10.0` resource per second (configurable per unit YAML). At 15 ticks/sec = `0.667` per tick.

**Refinery assignment:** `home_refinery` set on spawn to nearest refinery. If refinery destroyed, reassign to next nearest. If none exists, harvester idles.

## Resource Node Depletion

- `ResourceNode.remaining` decremented by harvest amount each tick
- When `remaining <= 0`: node entity is marked depleted (kept in world for visual, no longer targetable by harvesters)
- Harvesters targeting a depleted node transition to `idle` and seek new node
- Multiple harvesters can harvest the same node simultaneously (remaining shared)

## Power Grid — Shutdown Cascade

When `power_consumed > power_produced`:

1. Calculate deficit: `deficit = power_consumed - power_produced`
2. Sort all `PowerConsumer` entities by `priority` (ascending — lowest priority shuts off first)
3. Disable consumers starting from lowest priority until deficit is resolved
4. Disabled buildings: production paused, weapons offline, but NOT destroyed
5. Re-enable automatically when power is restored (e.g., new power plant built)

**Priority defaults:**
| Priority | Building Type |
|----------|--------------|
| 1 (lowest) | Radar, Sensors |
| 2 | Production buildings |
| 3 | Tech buildings |
| 4 | Defensive turrets |
| 5 (highest) | Superweapons, Shield generators |

**Disabled state:** Add `PoweredOff` tag component. Other systems check for this tag:
- ProductionSystem: skip tick for powered-off buildings
- CombatSystem: turrets with `PoweredOff` don't fire
- VisionSystem: radar/sensors with `PoweredOff` don't contribute vision

## Integration Notes

- **Reads:** `Harvester`, `ResourceNode`, `PowerConsumer`, `PowerProducer`, `FactionComponent`, `Position`
- **Writes:** `Harvester` (state, current_load), `ResourceNode` (remaining), `FactionResources` (shared state), `MoveCommand` (for harvesters), `PoweredOff` (tag)
- **Depends on:** MovementSystem must process harvester MoveCommands (Step 8)
- **Consumed by:** ProductionSystem (checks resources via `spend()`), UI (reads `get_resources()`)

## Test Cases

### 1. Harvester Full Cycle
**Setup:** 1 harvester (capacity=100, harvest_rate=10/sec), 1 resource node (remaining=500), 1 refinery adjacent to node
**Simulate:** 150 ticks (10 seconds)
**Assert:** harvester completed at least 1 full cycle, faction primary resources > 0, node remaining < 500

### 2. Resource Node Depletion
**Setup:** 1 harvester, 1 resource node (remaining=50), 1 refinery
**Simulate:** 150 ticks
**Assert:** node.remaining == 0, harvester state == idle (no other nodes), faction resources == 50

### 3. Power Shutdown Cascade
**Setup:** Faction has 3 buildings: radar (drain=10, priority=1), barracks (drain=20, priority=2), turret (drain=15, priority=4). Total power produced = 30.
**Simulate:** 1 tick
**Assert:** Total consumption = 45, deficit = 15. Radar disabled (saves 10), barracks disabled (saves 20, now surplus). Turret stays online. Radar and barracks have `PoweredOff` tag.

### 4. Power Restored
**Setup:** Same as test 3, then add a new PowerProducer (output=20) → total power = 50.
**Simulate:** 1 tick after adding producer
**Assert:** All buildings powered on, no `PoweredOff` tags remain.

### 5. Multiple Harvesters on Same Node
**Setup:** 3 harvesters, 1 resource node (remaining=200)
**Simulate:** 300 ticks (20 sec)
**Assert:** Node depleted, total faction resources == 200, all harvesters idle
