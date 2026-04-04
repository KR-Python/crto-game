# Template: Implement New Unit

Use this template when tasking a Gameplay Engineer to implement a new unit type.

---

**Agent:** Gameplay Engineer (Claude Sonnet)

**Context files to attach:**
- `prompts/context/project_overview.md`
- `prompts/context/coding_standards.md`
- `docs/06-DATA-SCHEMAS.md` (unit definition schema section)
- `docs/02-TECHNICAL-ARCHITECTURE.md` (ECS components section)
- Existing unit YAML for reference: `data/units/[similar_unit].yaml`

**Task prompt:**
```
You are implementing a new unit for the CRTO game.

### Unit to implement
Name: [unit_name]
Faction: [aegis | forge]
Tier: [1 | 2 | 3]
Role tag: [combat | spec_ops | hero | harvester | engineer | air]

### Design spec
[paste the unit's section from 01-GAME-DESIGN.md, or describe inline]

### Deliverables
1. `data/units/[faction]_[unit_name].yaml` — unit definition conforming to schema
2. `src/systems/[any_new_system].gd` — only if this unit requires a new system not already implemented
3. `tests/test_[unit_name].gd` — deterministic combat test

### Test requirements
- 5 [this unit] vs 5 [intended counter unit] — [this unit] should lose or be even
- 5 [this unit] vs 5 [unit this counters] — [this unit] should win decisively
- Single unit vs structure: assert damage-per-second is correct

### Edge cases to handle
- Target dies mid-attack (target_id becomes invalid)
- Unit killed while mid-move (clean up PathState)
- Production building destroyed while this unit is in queue (refund cost)
```
