# Design Decisions Log

Decisions made during Phase 1 interface design that weren't explicitly specified in the architecture doc.

---

## Decision: AoE Friendly Fire

**Context:** Architecture doc defines AoE damage (area_of_effect > 0) but doesn't specify whether friendly units in the blast radius take damage.
**Options:** (A) No friendly fire, (B) Full friendly fire, (C) Half damage to friendlies
**Decision:** Half damage (50%) to all entities in AoE radius, including friendlies. Firing entity excluded.
**Rationale:** Creates tactical depth — players must be careful with AoE. Half damage prevents it from being too punishing while still mattering. Common in RTS games (C&C, StarCraft splash).
**Revisit if:** Playtesters find AoE too punishing for cooperative play. Could reduce to 25% or disable friendly fire.

---

## Decision: Production Refund Policy

**Context:** Architecture doc doesn't specify refund amounts for cancelled or destroyed production.
**Options:** (A) 100% refund always, (B) 0% refund, (C) 100% cancel / 50% destroyed
**Decision:** 100% refund on voluntary cancel, 50% refund when building destroyed with active queue.
**Rationale:** Full cancel refund encourages adaptation without punishment. 50% on destruction creates meaningful loss when buildings die — you lose half the investment in queued units. This makes protecting production buildings strategically important.
**Revisit if:** 50% feels too punishing. Could increase to 75%.

---

## Decision: Power Shutdown Priority System

**Context:** Architecture doc mentions power grid but doesn't specify shutdown order when power goes negative.
**Options:** (A) All buildings shut off, (B) Random, (C) Priority-based cascade
**Decision:** Priority-based cascade. Lowest priority buildings shut off first. Priorities: 1=radar/sensors, 2=production, 3=tech, 4=turrets, 5=superweapons.
**Rationale:** Gives players meaningful power management decisions. Turrets staying on longer than production makes sense — you need defense when you're already power-starved. Radar going first is standard RTS convention.
**Revisit if:** Players want manual priority control per-building. Could add a Commander/QM action to re-prioritize.

---

## Decision: PoweredOff Tag Component

**Context:** Need a way for multiple systems to know a building lost power. Architecture doc doesn't define this.
**Options:** (A) Each system queries power state, (B) Shared tag component, (C) Callback system
**Decision:** `PoweredOff` tag component added/removed by EconomySystem. Other systems check for it.
**Rationale:** Follows ECS pattern — inter-system communication via components, not direct coupling. Simple, queryable, no callbacks needed.
**Revisit if:** Need more granular power states (e.g., "reduced power" for partial functionality).

---

## Decision: Harvester State Machine Fields

**Context:** Architecture doc defines `Harvester` component with `capacity, current_load, resource_type` but the state machine needs more fields.
**Options:** (A) Minimal component + external state, (B) Extend component with state/target_node/home_refinery
**Decision:** Extended Harvester component: added `state: HarvesterState`, `target_node: EntityId`, `home_refinery: EntityId`.
**Rationale:** All harvester state belongs in the component — keeps EconomySystem self-contained and queryable.
**Revisit if:** Harvester component gets too bloated with more features.

---

## Decision: Combat Auto-Acquire Targets Even Without AttackCommand

**Context:** Should idle units with weapons automatically engage nearby enemies?
**Options:** (A) Only fire when explicitly commanded, (B) Auto-acquire nearest enemy
**Decision:** Auto-acquire nearest valid enemy within weapon range. AttackCommand overrides auto-acquire.
**Rationale:** Standard RTS behavior. Units standing idle while enemies walk past feels broken. Auto-acquire makes the game feel responsive. Explicit commands take priority.
**Revisit if:** Need a "hold fire" stance. Could add a `HoldFire` tag component.

---

## Decision: Direct Movement Fallback (Phase 1)

**Context:** Full pathfinding (flowfield + A*) is Phase 2 (C++ GDExtension). Phase 1 needs movement to work.
**Options:** (A) No movement until pathfinding is built, (B) Straight-line movement, (C) Simple GDScript A*
**Decision:** Support both PathState-following AND direct movement toward MoveCommand.destination as fallback. If PathState exists, follow it. If only MoveCommand exists (no path computed), move in a straight line.
**Rationale:** Lets Phase 1 be playable without C++ pathfinding. Simple A* can be added as a GDScript placeholder later. Movement system doesn't care — it follows whatever path it's given.
**Revisit if:** Straight-line movement causes too many stuck-unit issues. Add simple grid A* in GDScript.

---

## Decision: Vision Fog Cell Resolution

**Context:** Architecture doc says "2x2 unit cells per fog cell." Confirmed this means each fog cell covers a 2×2 area of world units.
**Options:** (A) 1:1 (expensive), (B) 2:2 as specified, (C) 4:4 (coarse)
**Decision:** 2×2 as specified. A 128×96 map = 64×48 fog grid = 3,072 cells per team.
**Rationale:** Good balance of precision and performance. 3K cells is trivial to iterate at 15 ticks/sec.
**Revisit if:** Maps get much larger or performance becomes an issue.

---

## Decision: TICK_EXPIRED Error for Late Commands

**Context:** Architecture doc doesn't specify what happens when a command arrives targeting a past tick.
**Options:** (A) Execute on current tick, (B) Reject silently, (C) Reject with error code
**Decision:** Reject with `TICK_EXPIRED` error. Silent on client side (no toast — this is expected under network lag).
**Rationale:** Commands must target the current or future tick for determinism. Late commands under lag are normal — don't annoy the player with error messages. Log server-side for network diagnostics.
**Revisit if:** Too many commands getting dropped under high latency. Could add "execute on next available tick" mode for co-op.

---

## Decision: RallyPoint as Separate Component

**Context:** Architecture doc mentions rally points in ProductionQueue context but doesn't define storage.
**Options:** (A) Field on ProductionQueue, (B) Separate RallyPoint component
**Decision:** Separate `RallyPoint` component with `position: Vec2`.
**Rationale:** Not all entities with ProductionQueue need rally points. Separate component is more ECS-idiomatic and can be queried independently.
**Revisit if:** Never used outside production buildings (then merge back for simplicity).

---

## Decision: PowerConsumer Priority Field

**Context:** Need to order shutdown cascade. Architecture doc doesn't define priority storage.
**Options:** (A) Hardcoded by building type, (B) Field on PowerConsumer component
**Decision:** Added `priority: u8` field to `PowerConsumer` component. Set from structure definition YAML.
**Rationale:** Data-driven priority allows balance tuning via YAML without code changes. Consistent with project's data-driven philosophy.
**Revisit if:** Players need per-instance priority override (currently per-type only from YAML).
