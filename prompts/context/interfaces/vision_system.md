# Vision System Interface

**System:** `VisionSystem`
**Tick Pipeline Step:** 11
**File:** `src/systems/vision_system.gd`

## Purpose

Maintains fog of war state per team. Determines what each team can see.

## Interface

```gdscript
class_name VisionSystem

## Main tick — recalculate vision for all teams.
func tick(ecs: ECS, tick_count: int) -> void

## Query whether a world position is currently visible to a faction.
func is_visible(position: Vector2, faction_id: int) -> bool
```

## Fog of War Grid

- **Resolution:** 2×2 world units per fog cell (a 128×96 map = 64×48 fog grid)
- **Per-team state** (not per-player — all players on a team share vision)
- **Three cell states:**

| State | Value | Meaning |
|-------|-------|---------|
| `UNEXPLORED` | 0 | Never seen. Rendered as black. |
| `SEEN` | 1 | Previously visible, now not. Shows terrain/structures as last seen. No unit info. |
| `VISIBLE` | 2 | Currently visible. Full info. |

## tick() Behavior

1. **Decay:** Set all `VISIBLE` cells to `SEEN` (they'll be re-lit below if still in range)
2. **Vision sources:** For each entity with `VisionRange` + `Position` + `FactionComponent`:
   - Skip entities with `PoweredOff` tag (radars/sensors that lost power)
   - Calculate fog cells within `VisionRange.range` of entity position
   - Set those cells to `VISIBLE` in the team's fog grid
3. **Stealth detection:** (see below)

## Vision Calculation

For each vision source entity:
1. Convert `Position` to fog grid coordinates: `fog_x = floor(pos.x / 2)`, `fog_y = floor(pos.y / 2)`
2. Fog range in cells: `fog_range = ceil(VisionRange.range / 2)`
3. Iterate cells in circle of `fog_range` from `(fog_x, fog_y)`
4. Set matching cells to `VISIBLE`

**Optimization:** Use a pre-computed circle lookup table for each common range value.

## Stealth Detection

Entities with `Stealthed` component are invisible to enemy vision UNLESS:
1. An enemy entity with `Detector` component is within `Detector.range` of the stealthed unit, OR
2. An enemy entity (any) is within `Stealthed.detection_range` of the stealthed unit (close proximity reveal)

**Implementation:**
- After normal vision pass, check all `Stealthed` entities
- For each stealthed entity, check if any enemy detector is in range
- If detected: entity appears in fog as normal (VISIBLE)
- If NOT detected: entity is excluded from state snapshots sent to that team (even if the cell is VISIBLE)

## is_visible() Implementation

```gdscript
func is_visible(position: Vector2, faction_id: int) -> bool:
    var fog_x: int = int(position.x / 2.0)
    var fog_y: int = int(position.y / 2.0)
    var team_id: int = get_team_for_faction(faction_id)
    return fog_grid[team_id][fog_x][fog_y] == VISIBLE
```

## Integration Notes

- **Reads:** `Position`, `VisionRange`, `FactionComponent`, `Stealthed`, `Detector`, `PoweredOff`
- **Writes:** `FogOfWarGrid` (shared state, per-team 2D array)
- **Consumed by:** SnapshotSystem (filters entity data per team vision), CombatSystem (auto-acquire only visible targets), UI (fog rendering)

## Test Cases

### 1. Unit Enters Vision Range
**Setup:** Team A has unit at (10,10) with VisionRange=8. Team B has unit at (16,10). Fog cell (8,5) starts as UNEXPLORED.
**Simulate:** 1 tick
**Assert:** Fog cells around (5,5) in ~4-cell radius are VISIBLE for Team A. Team B unit at (16,10) is within range → visible to Team A.

### 2. Unit Exits Vision Range
**Setup:** Team A unit at (10,10) VisionRange=8. Team B unit moves from (16,10) to (30,10).
**Simulate:** After B moves, 1 tick
**Assert:** Cell at B's old position is `SEEN`. Cell at B's new position: if outside A's range → `UNEXPLORED` or `SEEN` depending on prior state. B's unit not visible to Team A.

### 3. Stealth Detection
**Setup:** Team A has detector (Detector.range=6) at (10,10). Team B has stealthed unit (Stealthed.detection_range=2) at (14,10).
**Simulate:** 1 tick
**Assert:** Distance = 4, within detector range (6) → stealthed unit revealed to Team A.

### 4. Stealth Not Detected
**Setup:** Same as test 3 but stealthed unit at (20,10) — distance 10, outside detector range.
**Simulate:** 1 tick
**Assert:** Stealthed unit NOT visible to Team A even though the cell might be VISIBLE from another vision source.

### 5. Powered Off Radar
**Setup:** Radar structure with VisionRange=16 at (10,10), has `PoweredOff` tag.
**Simulate:** 1 tick
**Assert:** Radar does NOT contribute vision. Cells that were VISIBLE from radar only → become SEEN.
