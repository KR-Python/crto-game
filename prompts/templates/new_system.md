# Template: Implement New ECS System

Use this template when tasking an Engine or Gameplay Engineer to implement a new ECS system.

---

**Agent:** Core Engine Engineer (Sonnet/Opus) or Gameplay Engineer (Sonnet)

**Prerequisites:** Systems Architect must produce an interface definition first.

**Context files to attach:**
- `prompts/context/project_overview.md`
- `prompts/context/coding_standards.md`
- `docs/02-TECHNICAL-ARCHITECTURE.md`
- Interface definition from Systems Architect (attach as inline text)
- Any systems this integrates with

**Task prompt:**
```
You are implementing a new ECS system for the CRTO game.

### System to implement
Name: [SystemName]
Position in tick pipeline: [step N — after X, before Y]
Language: [GDScript | C++ GDExtension]

### Interface contract
[paste the Systems Architect's interface definition here]

Components read: [list]
Components written: [list]
Systems depended on: [list]
Systems that depend on this: [list]

### Performance budget
- Called: every tick (15/sec)
- Max time budget: [X]ms
- Max entities: [Y]
- Allocation policy: [pre-allocate / no alloc in hot path]

### Deliverables
1. `src/systems/[system_name]_system.gd` — implementation
2. `tests/test_[system_name].gd` — deterministic tests
3. Integration note: where to register in game_loop.gd

### Test cases
[paste from Systems Architect's test cases]
```
