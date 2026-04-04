# Contributing to CRTO

Thanks for contributing! This doc covers the development workflow, how to add game content, and how the agentic development system works.

---

## Workflow

```bash
# 1. Create a feature branch
git checkout -b feat/your-feature

# 2. Make changes (code or data)

# 3. If you touched YAML game data, regenerate and validate:
python3 tools/yaml_to_json.py
python3 tools/validate_schemas.py

# 4. Open a PR — CI must pass before merge
git push -u origin feat/your-feature
```

**Branch naming:** `feat/`, `fix/`, `data/`, `docs/` prefixes. Keep branches focused — one logical change per PR.

**CI checks:** lint, schema validation, headless test run, Godot export check. All must pass.

---

## Adding Game Content

Game content is data-driven. No code changes needed for most additions.

### New Unit

1. Copy an existing YAML from `game/data/units/` (pick one at the same tier)
2. Edit the copy — update `id`, `name`, `stats`, `cost`, `faction`, `role_restriction`
3. Add the unit to the appropriate tech tree in `game/data/tech_trees/`
4. Run the validator:
   ```bash
   python3 tools/validate_schemas.py
   ```
5. Run `python3 tools/yaml_to_json.py` and test in-engine

Schema reference: [`docs/06-DATA-SCHEMAS.md`](docs/06-DATA-SCHEMAS.md)

### New Structure

Same process as units — copy from `game/data/structures/`, edit, validate.

### New Map

Copy from `game/data/maps/`, edit the tile grid and starting positions, validate.

---

## Agent Workforce

This project uses an **agentic AI development workflow** — most features are implemented by specialized AI agents working from structured prompts.

Agent configs and context files live in `prompts/`:

```
prompts/
├── context/           ← Shared context injected into all agents
│   ├── project_overview.md
│   ├── coding_standards.md
│   └── ...
└── agents/            ← Per-agent role prompts
```

When contributing as a human alongside the agent workforce:
- Follow the same coding standards the agents use (see `prompts/context/coding_standards.md`)
- Agent-authored code has the same review bar as human code — read it, don't rubber-stamp it
- If you're extending an agent-built system, check its PR description for design notes

Full agent workforce overview: [`docs/03-AGENT-WORKFORCE.md`](docs/03-AGENT-WORKFORCE.md)

---

## Coding Standards

See [`prompts/context/coding_standards.md`](prompts/context/coding_standards.md) for the full guide. Key points:

- **GDScript** for all gameplay logic — keeps the codebase accessible and AI-friendly
- **C++ GDExtension** only for proven hot paths (pathfinding, simulation tick internals)
- **No magic numbers** — all game constants go in YAML data files or named constants
- **Tests alongside features** — every system should have a corresponding GDScript test
- **Comments explain why, not what**

---

## Architecture

The simulation is ECS-based with host-authoritative networking:

- Clients send **Commands** (never modify state directly)
- Server validates against the **Role Permission System** and runs the simulation
- State deltas broadcast every 2 ticks
- Rendering is decoupled and interpolated at display FPS

Full architecture: [`docs/02-TECHNICAL-ARCHITECTURE.md`](docs/02-TECHNICAL-ARCHITECTURE.md)

---

## Useful Commands

```bash
# Regenerate all JSON from YAML
python3 tools/yaml_to_json.py

# Validate all schemas (cross-references, required fields)
python3 tools/validate_schemas.py

# Run tests headless
godot --headless -s tests/run_all.gd

# Check what CI will check
cat .github/workflows/*.yml
```
