# Command Protocol Interface

**File:** `src/network/command_protocol.gd`

## Purpose

Defines the serialization format, validation, and processing pipeline for all player commands.

## Command Structure

```gdscript
class_name Command

var player_id: int          # Which player sent this
var role: Role              # Which role they're acting as
var tick: int               # Target simulation tick
var action: CommandAction   # What they want to do (see enum below)
var params: Dictionary      # Action-specific parameters
```

## CommandAction Enum + Parameter Schemas

```gdscript
enum CommandAction {
    # Movement & Combat (FieldMarshal, SpecOps, AirMarshal, partial Quartermaster/ChiefEngineer)
    MOVE_UNITS,          # { "unit_ids": Array[int], "destination": Vector2 }
    ATTACK_TARGET,       # { "unit_ids": Array[int], "target_id": int }
    ATTACK_MOVE,         # { "unit_ids": Array[int], "destination": Vector2 }
    PATROL,              # { "unit_ids": Array[int], "waypoints": Array[Vector2] }
    GUARD,               # { "unit_ids": Array[int], "guard_target_id": int }
    STOP,                # { "unit_ids": Array[int] }
    HOLD_POSITION,       # { "unit_ids": Array[int] }
    SET_FORMATION,       # { "unit_ids": Array[int], "formation": String }

    # Structure (Commander, ChiefEngineer partial)
    PLACE_STRUCTURE,     # { "structure_type": String, "position": Vector2 }
    CANCEL_STRUCTURE,    # { "structure_id": int }

    # Production (Quartermaster)
    QUEUE_PRODUCTION,    # { "factory_id": int, "unit_type": String }
    CANCEL_PRODUCTION,   # { "factory_id": int, "queue_index": int }
    SET_RALLY_POINT,     # { "factory_id": int, "position": Vector2 }

    # Research (Commander)
    RESEARCH,            # { "lab_id": int, "tech_id": String }
    CANCEL_RESEARCH,     # { "lab_id": int }

    # Communication (All roles)
    PING_MAP,            # { "position": Vector2, "ping_type": String }
    REQUEST_FROM_ROLE,   # { "target_role": String, "request": Dictionary }

    # Special
    APPROVE_SUPERWEAPON, # { "weapon_id": int, "confirmed": bool }
    TRANSFER_CONTROL,    # { "entity_id": int, "to_role": String }
    TOGGLE_POWER,        # { "building_id": int }

    # SpecOps-specific
    INFILTRATE,          # { "unit_id": int, "target_id": int }
    SABOTAGE,            # { "unit_id": int, "target_id": int }
    MARK_TARGET,         # { "unit_id": int, "target_id": int }

    # ChiefEngineer-specific
    REPAIR_STRUCTURE,    # { "engineer_id": int, "target_id": int }
    REPAIR_VEHICLE,      # { "engineer_id": int, "target_id": int }
    PLACE_WALL,          # { "positions": Array[Vector2] }
    PLACE_MINE,          # { "position": Vector2 }

    # AirMarshal-specific
    BOMBING_RUN,         # { "unit_ids": Array[int], "target_position": Vector2 }
    PARADROP,            # { "transport_id": int, "drop_position": Vector2 }
}
```

## Serialization Format

**Phase 1:** Dictionary-based (GDScript native). Simple and debuggable.

```gdscript
# Serialize
func to_dict() -> Dictionary:
    return {
        "player_id": player_id,
        "role": Role.keys()[role],
        "tick": tick,
        "action": CommandAction.keys()[action],
        "params": params,
    }

# Deserialize
static func from_dict(data: Dictionary) -> Command:
    var cmd := Command.new()
    cmd.player_id = data["player_id"]
    cmd.role = Role[data["role"]]
    cmd.tick = data["tick"]
    cmd.action = CommandAction[data["action"]]
    cmd.params = data["params"]
    return cmd
```

**Phase 2+:** Binary serialization for bandwidth. Same logical structure, packed with `StreamPeerBuffer`.

## Command Pipeline

```
Client Input → Command.new() → Network send to Host
                                      ↓
Host receives → CommandQueue (buffered for next tick boundary)
                                      ↓
Tick boundary → PermissionSystem validates (Step 2)
                                      ↓
              ValidatedCommands ←── valid
              RejectedCommands ←── invalid (sent back to client with CommandError)
                                      ↓
              CommandProcessing (Step 6) → converts to ECS components:
                  MOVE_UNITS      → MoveCommand on each unit
                  ATTACK_TARGET   → AttackCommand on each unit
                  QUEUE_PRODUCTION → ProductionQueue.queue.append()
                  PLACE_STRUCTURE → spawn Structure entity
                  etc.
```

## Command Buffering

- Commands arrive asynchronously from clients
- Buffered in `CommandQueue` until next tick boundary
- All commands for tick N are processed together at the start of tick N
- Commands targeting a future tick are held until that tick
- Commands targeting a past tick are rejected with `TICK_EXPIRED`

## Invalid Command Handling

```gdscript
class_name CommandReject

var command: Command            # The rejected command
var error: CommandError          # Error code (see permission_system.md)
var message: String              # Human-readable reason

# Sent back to originating client for UI feedback
# Client shows brief error toast: "Cannot build — insufficient resources"
```

## Error Code → Client Feedback

| CommandError | UI Feedback |
|-------------|-------------|
| `PERMISSION_DENIED` | "You don't have permission to do that" + error sound |
| `ENTITY_NOT_OWNED` | "You don't control that unit" |
| `INVALID_TARGET` | "Invalid target" |
| `TECH_NOT_RESEARCHED` | "Research required: [tech_name]" |
| `INSUFFICIENT_RESOURCES` | "Not enough resources" + flash resource bar |
| `INVALID_PLACEMENT` | "Can't build there" + red ghost |
| `QUEUE_FULL` | "Production queue full" |
| `UNIT_CAP_REACHED` | "Unit cap reached" |
| `INVALID_COMMAND` | (silent — log server-side, likely a bug) |
| `TICK_EXPIRED` | (silent — command arrived too late, will be common under lag) |

## Integration Notes

- **CommandQueue** is written by InputSystem (Step 1) and AIDecisionSystem (Step 3)
- **PermissionSystem** (Step 2) reads CommandQueue, writes ValidatedCommands + RejectedCommands
- **CommandProcessing** (Step 6) reads ValidatedCommands, writes ECS components
