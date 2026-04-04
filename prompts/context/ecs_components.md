# ECS Components Reference

Quick-scan reference for all simulation components. Components are **plain data only** — no logic.

## Identity

| Component | Fields | Types | Used By |
|-----------|--------|-------|---------|
| `EntityId` | (implicit) | `u64` | All systems |
| `FactionComponent` | `faction_id` | `u8` | Economy, Vision, Combat |
| `RoleOwnership` | `role: Role, transferable: bool` | `enum, bool` | PermissionSystem |
| `DisplayName` | `name` | `String` | UI only |

## Spatial

| Component | Fields | Types | Used By |
|-----------|--------|-------|---------|
| `Position` | `x, y` | `f32, f32` | Movement, Combat, Vision, Pathfinding |
| `Velocity` | `x, y` | `f32, f32` | Movement |
| `Rotation` | `angle` | `f32` | Movement, Combat (turret facing) |
| `Footprint` | `width, height` | `u8, u8` | Structures, Pathfinding |
| `CollisionLayer` | `layers` | `u32` | Movement, Combat |

## Combat

| Component | Fields | Types | Used By |
|-----------|--------|-------|---------|
| `Health` | `current, max, armor_type` | `f32, f32, ArmorType` | Combat, Death |
| `Weapon` | `damage, range, cooldown, cooldown_remaining, damage_type, targets, area_of_effect` | `f32, f32, f32, f32, DamageType, TargetMask, f32` | Combat |
| `Attackable` | _(tag)_ | — | Combat (target filtering) |
| `AttackCommand` | `target` | `EntityId` | Combat, CommandProcessing |

## Movement

| Component | Fields | Types | Used By |
|-----------|--------|-------|---------|
| `MoveSpeed` | `speed` | `f32` | Movement |
| `MoveCommand` | `destination, queued` | `Vec2, bool` | CommandProcessing, Movement |
| `PathState` | `path, current_index` | `Array[Vec2], u32` | Pathfinding, Movement |
| `Flying` | _(tag)_ | — | Movement, Pathfinding, Combat |

## Economy

| Component | Fields | Types | Used By |
|-----------|--------|-------|---------|
| `Harvester` | `capacity, current_load, resource_type, state, target_node, home_refinery` | `f32, f32, ResourceType, HarvesterState, EntityId, EntityId` | Economy |
| `ResourceNode` | `type, remaining` | `ResourceType, f32` | Economy |
| `ProductionQueue` | `queue, progress, rate` | `Array[UnitType], f32, f32` | Production |

## Structure

| Component | Fields | Types | Used By |
|-----------|--------|-------|---------|
| `Structure` | `built, build_progress` | `bool, f32` | Production, Economy |
| `PowerConsumer` | `drain, priority` | `f32, u8` | Economy (power grid) |
| `PowerProducer` | `output` | `f32` | Economy (power grid) |
| `TechProvider` | `techs` | `Array[TechId]` | Permission (tech prereqs) |
| `RallyPoint` | `position` | `Vec2` | Production |

## Visibility

| Component | Fields | Types | Used By |
|-----------|--------|-------|---------|
| `VisionRange` | `range` | `f32` | Vision |
| `Stealthed` | `detection_range` | `f32` | Vision |
| `Detector` | `range` | `f32` | Vision |

## Role Tags (all are empty marker components)

| Component | Assigned To | Used By |
|-----------|------------|---------|
| `CommanderControlled` | Structures, construction yard | PermissionSystem |
| `QuartermasterControlled` | Harvesters, production buildings, refineries | PermissionSystem |
| `FieldMarshalControlled` | Infantry, vehicles, naval (non-spec-ops, non-air) | PermissionSystem |
| `SpecOpsControlled` | Spec ops units, hero units | PermissionSystem |
| `ChiefEngineerControlled` | Defensive structures, walls, engineer units | PermissionSystem |
| `AirMarshalControlled` | Air units, airfields | PermissionSystem |

## Enums

### ArmorType
`light | medium | heavy | building`

### DamageType
`kinetic | explosive | energy | chemical | fire`

### TargetMask
`ground | air | structure | naval` (bitmask — weapons can target multiple)

### ResourceType
`primary | secondary`

### HarvesterState
`idle | moving_to_node | harvesting | returning`

### Role
`commander | quartermaster | field_marshal | spec_ops | chief_engineer | air_marshal`
