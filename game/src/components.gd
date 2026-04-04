class_name Components

# Factory methods for ECS component dictionaries.
# Components are plain data — no logic here.
# Systems own all logic; components own only structure.
#
# Naming: component keys use snake_case matching the component type string.

# -- Stealth / Vision ----------------------------------------------------------

## Marks a unit as stealthed. Removed by StealthSystem or AbilitySystem.
## detection_range: tiles within which enemy Detectors reveal this unit.
## cloak_until_tick: if > 0, stealth expires automatically at this tick.
static func stealthed(detection_range: float = 2.0, cloak_until_tick: int = 0) -> Dictionary:
	return {
		"detection_range": detection_range,
		"cloak_until_tick": cloak_until_tick,
	}


## Applied by StealthSystem when a detector spots a Stealthed unit.
## Removed automatically when tick_count >= revealed_until_tick.
static func revealed(until_tick: int) -> Dictionary:
	return {"revealed_until_tick": until_tick}


## Applied when stealth breaks (attack or damage).
## Prevents re-cloaking until break_until_tick has passed.
static func break_stealth(until_tick: int) -> Dictionary:
	return {"break_until_tick": until_tick}


# -- Ability -------------------------------------------------------------------

## Stored inside the AbilityCooldown component dictionary (keyed by ability_id).
## Not set directly as a top-level component — nested under "AbilityCooldown".
static func ability_cooldown(ability_id: String, ready_at_tick: int) -> Dictionary:
	return {
		"ability_id": ability_id,
		"ready_at_tick": ready_at_tick,
	}


## Sabotage charge placed on a structure.
## Removed by AbilitySystem when detonation_tick is reached.
static func c4_charge(damage: int, detonation_tick: int, placed_by: int) -> Dictionary:
	return {
		"damage": damage,
		"detonation_tick": detonation_tick,
		"placed_by": placed_by,
	}


# -- Repair -------------------------------------------------------------------

## Command issued to an EngineerUnit to repair a target entity.
static func repair_command(target_entity: int) -> Dictionary:
	return {"target_entity": target_entity}


## Left behind by DeathSystem when a vehicle is destroyed.
## reclaim_value: 25% of original unit cost in primary resources.
static func wreckage(unit_type: String, reclaim_value: int) -> Dictionary:
	return {
		"unit_type": unit_type,
		"reclaim_value": reclaim_value,
	}


# -- Detection -----------------------------------------------------------------

## Marks a unit or structure as capable of revealing Stealthed entities.
## radius: detection radius in tiles.
static func detector(radius: float = 3.0) -> Dictionary:
	return {"radius": radius}
