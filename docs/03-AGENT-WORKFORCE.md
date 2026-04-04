# 03 — Agentic AI Development Workforce

## Philosophy

Each agent is a specialized "employee" with a constrained scope, clear inputs, and testable outputs. You (Kyle) are the **Integration Architect** — you define the interfaces, the agents implement against them, and you wire the systems together.

### Key Principles

1. **Interface-first:** Define the contract before tasking the agent. "Implement MovementSystem that reads Position, Velocity, MoveCommand, PathState components and writes Position, Velocity" is actionable. "Make units move" is not.
2. **One system, one agent, one PR.** Never ask an agent to build two coupled systems at once.
3. **Data in, data out.** Agents work best when the task is: "given this input schema, produce this output." ECS systems, data parsers, UI components — all naturally fit this pattern.
4. **Prompt versioning.** Store agent prompts in `/prompts/` — they're as important as code. When you improve a prompt, commit it.
5. **Review everything.** Agents produce ~80% correct code. The 20% is where the bugs hide, especially at system boundaries.

## Agent Roster

### Agent 1: Systems Architect

**Role:** Produces technical design documents, interface definitions, and system contracts.

**When to use:**
- Before starting any new system
- When you need to decompose a feature into agent-implementable tasks
- When two systems need to interact and you need to define the boundary

**Input pattern:**
```
Context: [Current ECS components], [Existing systems], [Project structure]
Task: Design the interface for [SystemName]
Constraints: [Performance budget], [Must integrate with X, Y systems]
Output: Interface definition with input components, output components,
        method signatures, and integration test cases
```

**Output:** Markdown design doc + YAML interface spec

**Model recommendation:** Claude Opus (needs deep architectural reasoning)

---

### Agent 2: Core Engine Engineer

**Role:** Implements foundational systems — ECS framework, game loop, simulation tick, spatial data structures.

**When to use:**
- Phase 0 and early Phase 1
- Any performance-critical system
- Anything that touches the simulation tick pipeline

**Input pattern:**
```
Context: [Architecture doc], [ECS component definitions], [Performance budgets]
Task: Implement [system] in GDScript/C++
Contract: Reads [components], Writes [components]
Tests: [Deterministic test cases from architect]
```

**Output:** Implementation files + test files

**Key review focus:** Tick timing, memory allocation patterns, thread safety (for pathfinding)

**Model recommendation:** Claude Sonnet for GDScript, Opus for C++ hot paths

---

### Agent 3: Gameplay Engineer

**Role:** Implements individual gameplay systems — combat, economy, production, unit behaviors.

**When to use:**
- Phase 1 onward
- Any unit type, weapon, ability, or building behavior
- Balance tuning (with data input)

**Input pattern:**
```
Context: [Unit YAML schema], [ECS components available], [Existing systems]
Task: Implement [UnitType/Weapon/Ability]
Spec: [From game design doc — stats, behavior description, interactions]
Tests: [Expected combat outcomes, edge cases]
```

**Output:** System implementation + unit data YAML + tests

**Key review focus:** Edge cases (what happens when target dies mid-attack?), resource math precision

**This is your highest-volume agent.** Most tasks in the game are "implement this unit/building/ability" — perfectly scoped for agents.

**Model recommendation:** Claude Sonnet (high volume, well-defined tasks)

---

### Agent 4: Network Engineer

**Role:** Implements multiplayer networking — command protocol, state sync, session management.

**When to use:**
- Phase 1.5 onward (after single-machine split-screen works)
- Session management, reconnection, host migration

**Input pattern:**
```
Context: [Command protocol spec], [State snapshot format], [Godot ENet API]
Task: Implement [network feature]
Constraints: [Bandwidth budget], [Latency tolerance], [Max players]
Tests: [Simulated latency scenarios, disconnect/reconnect]
```

**Output:** Network code + integration tests

**Key review focus:** Race conditions, state consistency after reconnect, bandwidth usage

**Model recommendation:** Claude Opus (networking edge cases need deep reasoning)

---

### Agent 5: AI Engineer (In-Game)

**Role:** Implements AI opponent and AI partner systems.

**When to use:**
- Phase 2 onward
- Each AI personality, each partner role behavior

**Input pattern:**
```
Context: [Game state API], [Available commands per role], [Behavior tree framework]
Task: Implement [AI personality / AI partner role]
Behavior spec: [Decision priorities, aggression curve, response patterns]
Tests: [AI should expand by tick 500, should attack by tick 1500, etc.]
```

**Output:** Behavior tree definitions + AI controller code + personality configs

**Key review focus:** Does the AI feel fair? Does the partner AI feel helpful without being annoying?

**Model recommendation:** Opus for partner AI (needs to model human coordination), Sonnet for opponent AI behaviors

---

### Agent 6: UI/UX Engineer

**Role:** Implements per-role UI, HUD elements, menus, and visual feedback systems.

**When to use:**
- Phase 1 onward (in parallel with gameplay systems)
- Each role's unique UI panel
- Shared systems (minimap, resource bar, ping system)

**Input pattern:**
```
Context: [Role permissions], [Game state available to this role], [UI mockup/wireframe]
Task: Implement [UI element] for [role]
Spec: [What data it shows, what actions it enables, update frequency]
Interaction: [Click behaviors, keyboard shortcuts, drag behaviors]
```

**Output:** UI scene + script + theme resources

**Key review focus:** Does it update at the right frequency? Does it respect role permissions? Responsiveness.

**Model recommendation:** Sonnet (UI is well-structured, high volume)

---

### Agent 7: Head of Design (Data)

**Role:** Produces game design data — unit rosters, tech trees, balance spreadsheets, AI personality configs, map layouts.

**When to use:**
- Before gameplay engineers implement content
- Balance iteration (after playtesting)
- New faction, unit, or tech design

**Input pattern:**
```
Context: [Existing unit roster], [Faction identity], [Counter-relationship matrix]
Task: Design [unit/tech tree/faction mechanic]
Constraints: [Must counter X, must cost Y, must be T2]
Output format: YAML matching [schema]
```

**Output:** YAML data files conforming to game data schemas

**Key review focus:** Does it fit the faction identity? Is it fun on paper? Are counters clear?

**Model recommendation:** Opus (creative design decisions need deeper reasoning)

---

### Agent 8: DevOps / Pipeline Engineer

**Role:** CI/CD, test automation, build pipelines, asset pipeline tooling.

**When to use:**
- Phase 0 (foundational setup)
- Whenever test infrastructure needs expansion
- Build/export configuration

**Input pattern:**
```
Context: [Project structure], [Godot version], [Target platforms], [Test framework]
Task: Set up [CI pipeline / test runner / asset pipeline]
Requirements: [Platforms, triggers, artifacts]
```

**Output:** GitHub Actions configs, scripts, Makefiles

**Model recommendation:** Sonnet (well-defined infrastructure tasks)

## Agent Orchestration Patterns

### Pattern 1: Vertical Slice

For each new feature, agents work in sequence:

```
Systems Architect → defines interface
    → Core Engine Engineer → implements system skeleton
        → Gameplay Engineer → implements behavior
            → UI Engineer → implements UI for the feature
                → DevOps → adds tests to CI
```

### Pattern 2: Parallel Content Production

Once systems exist, multiple Gameplay Engineer agents work in parallel:

```
                    ┌→ Agent: Implement Rifleman
                    ├→ Agent: Implement Light Tank
Systems Architect   ├→ Agent: Implement Barracks
  (unit schema)  ───├→ Agent: Implement Refinery
                    ├→ Agent: Implement Engineer
                    └→ Agent: Implement Scout Buggy
```

Each agent gets the same schema, same ECS components, same system interfaces. They produce independent YAML + GDScript files. You integrate.

### Pattern 3: Adversarial Review

For critical systems (networking, permissions, AI), use two agents:

```
Agent A: Implement the system
Agent B: Review Agent A's implementation, write adversarial tests
    → You resolve disagreements
```

### Pattern 4: Design-Data-Implement Pipeline

```
Design Agent → produces YAML data (unit roster)
    → You review/approve
        → Gameplay Agent → implements systems that consume the data
            → Test Agent → verifies data + implementation match
```

## Prompt Library Structure

```
prompts/
├── README.md                     # How to use each prompt
├── context/                      # Shared context all agents receive
│   ├── project_overview.md       # What the game is
│   ├── ecs_components.md         # Current component list
│   ├── coding_standards.md       # Style guide, patterns to use
│   └── system_interfaces.md      # Current system contracts
├── agents/
│   ├── systems_architect.md      # Full prompt for architect agent
│   ├── engine_engineer.md
│   ├── gameplay_engineer.md
│   ├── network_engineer.md
│   ├── ai_engineer.md
│   ├── ui_engineer.md
│   ├── design_lead.md
│   └── devops_engineer.md
└── templates/
    ├── new_unit.md               # "Implement unit X" template
    ├── new_building.md           # "Implement building X" template
    ├── new_system.md             # "Implement ECS system X" template
    └── new_ui_panel.md           # "Implement UI panel X" template
```

## Task Decomposition Example

**Goal:** "Add Medium Tank to AEGIS faction"

1. **Design Agent:** Produce `aegis_medium_tank.yaml` conforming to unit schema (stats, weapon, armor, cost, build time, tech requirements)
2. **Gameplay Agent:** If tank weapon type doesn't exist yet, implement `ProjectileWeaponSystem` against the combat interface
3. **UI Agent:** Add tank icon to Quartermaster's production panel, Field Marshal's unit card
4. **Art Agent (human/external):** Produce sprite/model (or use placeholder)
5. **Test Agent:** Write deterministic combat test: 5 AEGIS medium tanks vs 5 FORGE battle tanks, assert roughly even

Each of these is a standalone, parallelizable task with clear inputs and outputs.

## Time Allocation Guide

| Activity | % of Your Time | Notes |
|----------|----------------|-------|
| Defining interfaces & prompting agents | 25% | The "architecture" work |
| Reviewing agent output | 25% | The "quality" work |
| Integration (wiring systems together) | 30% | The work only you can do |
| Playtesting & feel tuning | 15% | The work agents can't do |
| DevOps/tooling | 5% | Mostly automated |
