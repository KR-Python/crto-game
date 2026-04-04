# Combat System Interface

**System:** `CombatSystem`
**Tick Pipeline Step:** 9
**File:** `src/systems/combat_system.gd`

## Purpose

Handles target acquisition, damage calculation, and weapon cooldowns. Does NOT handle death — that's DeathSystem (Step 10).

## Interface

```gdscript
class_name CombatSystem

## Main tick — process all entities with Weapon components.
func tick(ecs: ECS, tick_count: int) -> void
```

## tick() Behavior

For each entity with `Weapon` + `Position` components:

1. **Cooldown tick:** Decrement `Weapon.cooldown_remaining` by `1.0 / TICKS_PER_SECOND`. Clamp to 0.
2. **Skip if on cooldown:** If `cooldown_remaining > 0`, skip to next entity.
3. **Skip if powered off:** If entity has `PoweredOff` tag, skip.
4. **Target acquisition:**
   a. If entity has `AttackCommand` → use that target (if valid and in range)
   b. Else → auto-acquire: find nearest enemy entity within `Weapon.range` that matches `Weapon.targets` mask and is `Attackable`
   c. If no valid target → skip
5. **Range check:** Distance from `Position` to target `Position` <= `Weapon.range`
   - If target out of range and entity has `AttackCommand`: do NOT fire, let MovementSystem close distance
6. **Fire:**
   a. Calculate damage (see below)
   b. Apply damage to target `Health.current`
   c. If `Weapon.area_of_effect > 0`: apply AoE damage
   d. Reset `Weapon.cooldown_remaining = Weapon.cooldown`

## Damage Calculation

```
final_damage = Weapon.damage × armor_matrix[Weapon.damage_type][target.Health.armor_type]
```

Armor matrix (from `data/balance/damage_armor_matrix.yaml`):

| | light | medium | heavy | building |
|---|:---:|:---:|:---:|:---:|
| **kinetic** | 1.0 | 0.75 | 0.5 | 0.25 |
| **explosive** | 1.5 | 1.0 | 0.75 | 1.5 |
| **energy** | 0.75 | 1.0 | 1.25 | 1.0 |
| **chemical** | 1.5 | 1.25 | 0.5 | 0.25 |
| **fire** | 1.75 | 1.0 | 0.25 | 1.5 |

## AoE Damage

When `Weapon.area_of_effect > 0`:

1. Find all `Attackable` entities within `area_of_effect` radius of the **target's position**
2. Apply full damage to primary target
3. Apply `final_damage * 0.5` to all other entities in radius (including friendlies — friendly fire on AoE)
4. The firing entity is excluded from its own AoE

## Target Acquisition — Auto-Acquire Rules

1. Only consider entities with `Attackable` tag and different `faction_id`
2. Filter by `Weapon.targets` mask:
   - `ground` → entities without `Flying` tag and without `Structure` tag
   - `air` → entities with `Flying` tag
   - `structure` → entities with `Structure` tag
3. From valid targets, select nearest by distance
4. Tie-breaking: lowest `EntityId` (deterministic)

## Target Dies Mid-Attack

- If target's `Health.current <= 0` when this entity tries to fire: clear `AttackCommand`, re-acquire next tick
- If target is removed between ticks (DeathSystem ran): `AttackCommand` references invalid entity → clear it, auto-acquire next tick

## Integration Notes

- **Reads:** `Position`, `Weapon`, `Health`, `AttackCommand`, `FactionComponent`, `Attackable`, `Flying`, `Structure`, `PoweredOff`
- **Writes:** `Health.current` (damage), `Weapon.cooldown_remaining`
- **Does NOT write:** Entity removal (DeathSystem), movement (MovementSystem)
- **Depends on:** MovementSystem has already updated positions this tick

## Test Cases

### 1. Single Target Combat
**Setup:** Unit A (weapon: damage=85, range=7, cooldown=2.0, type=kinetic) at (0,0). Unit B (health=450, armor=heavy) at (5,0). Both attackable, different factions.
**Simulate:** 30 ticks (2 seconds)
**Assert:** Unit A fires once at tick 0 (cooldown starts at 0). Damage = 85 × 0.5 = 42.5. B health = 407.5. Fires again at tick 30. B health = 365.

### 2. AoE Damage
**Setup:** Unit A (weapon: damage=100, AoE=3.0, type=explosive). Target B at (10,0), Unit C (same faction as B) at (11,0), Unit D (same faction as A) at (12,0).
**Simulate:** 1 attack
**Assert:** B takes 100 × 1.0 (medium armor) = 100 full damage. C is within AoE radius (1.0 < 3.0) → takes 50 half damage. D is within AoE (2.0 < 3.0) → takes 50 half damage (friendly fire).

### 3. Armor Type Interaction
**Setup:** Energy weapon (damage=100) vs heavy armor target
**Assert:** Damage = 100 × 1.25 = 125. Energy is strong vs heavy.

### 4. Target Dies Mid-Attack
**Setup:** Unit A attacking Unit B. B has 10 health. Another unit kills B before A fires this tick.
**Simulate:** 1 tick
**Assert:** A's AttackCommand cleared, A auto-acquires new target next tick.

### 5. Out of Range
**Setup:** Unit A (range=7) at (0,0) with AttackCommand targeting B at (15,0).
**Simulate:** 1 tick
**Assert:** A does NOT fire. AttackCommand preserved (MovementSystem should be closing distance).
