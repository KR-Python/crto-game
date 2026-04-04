# CRTO Coding Standards

## GDScript Style
- Use `class_name` declarations for all top-level classes
- Type all variables and function signatures: `var speed: float = 3.5`
- Constants in UPPER_SNAKE_CASE, variables in snake_case, classes in PascalCase
- One class per file; filename matches class name in snake_case
- Prefer composition over inheritance; use ECS components, not deep node hierarchies
- Keep functions under 40 lines; extract helpers aggressively
- Comments explain WHY, not WHAT

## ECS Patterns
- Components are plain data — no logic in components
- Systems contain all logic — read components, write components, no side effects outside their domain
- Never reach into another system's "domain" — if you need data from another system, expose it via a component
- Entity IDs are u64 — never store node references in simulation code
- All simulation code must be deterministic — no `randf()` in systems (use seeded RNG via SimRandom)

## File Organization
- One system per file in `src/systems/`
- Data files in `data/` — YAML only, conforming to schemas in `docs/06-DATA-SCHEMAS.md`
- Tests in `game/tests/` — one test file per system
- Native C++ in `game/native/` — GDExtension pattern, async where possible

## Naming Conventions
- System files: `{name}_system.gd` (e.g., `combat_system.gd`)
- Component structs: `{Name}Component` (e.g., `HealthComponent`)
- Test files: `test_{system_name}.gd`
- YAML data files: `{faction}_{unit_name}.yaml`

## Error Handling
- Validate all external inputs (commands from network, YAML data at load)
- Use `assert()` only in tests — never in production simulation code
- Log with `push_warning()` / `push_error()` — never `print()` in production code
- Invalid commands must be rejected with a typed error code (see `CommandError` enum)

## Performance Rules
- No heap allocations in the hot tick path — pre-allocate arrays
- No string operations per-entity per-tick
- Profile before optimizing — don't guess
- C++ GDExtension for anything called >1000x per tick

## Git Discipline
- One branch per feature/system: `feat/movement-system`, `feat/aegis-rifleman`
- Commit message format: `feat: implement MovementSystem reads PathState writes Position`
- No direct commits to main — PRs only
- Every PR includes: implementation + tests + schema validation if data added
