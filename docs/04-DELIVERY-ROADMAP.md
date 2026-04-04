# 04 — Phased Delivery Roadmap

## Guiding Principle: Ship Vertically, Not Horizontally

Every phase produces something **playable**. No phase is "just infrastructure." If you can't play it at the end of a phase, the phase was scoped wrong.

---

## Phase 0: Foundation (Weeks 1-2)

### Goal
A Godot project that renders a map, accepts input, and moves a unit.

### Deliverables

| Task | Agent | Depends On | Est. |
|------|-------|------------|------|
| Project scaffold + directory structure | DevOps | — | 2h |
| ECS core (entity creation, component storage, system runner) | Engine | — | 1d |
| Game loop (fixed timestep sim, decoupled render) | Engine | ECS | 1d |
| Tilemap rendering (placeholder art, flat terrain) | Engine | Game loop | 0.5d |
| Camera controller (pan, zoom, edge scroll) | UI | Game loop | 0.5d |
| Click-to-move (click → pathfinding → unit moves) | Engine + Gameplay | ECS, tilemap | 2d |
| A* pathfinding (basic, single-threaded) | Engine | Tilemap | 1d |
| CI pipeline (lint, test runner, export builds) | DevOps | Project scaffold | 0.5d |

### Exit Criteria
- [ ] A unit (colored rectangle) moves to where you click on a tiled map
- [ ] Camera pans and zooms
- [ ] CI runs on push
- [ ] Sim runs at stable 15 ticks/sec regardless of render FPS

### Risk
None. This is well-trodden ground.

---

## Phase 1: Split Control Prototype (Weeks 3-5)

### Goal
Two players controlling one shared game — Commander builds, Field Marshal fights.

### Deliverables

| Task | Agent | Depends On | Est. |
|------|-------|------------|------|
| Role permission system | Engine | ECS | 1d |
| Entity role-ownership tagging | Engine | Permissions | 0.5d |
| Commander: structure placement (barracks, refinery, power) | Gameplay | ECS, tilemap | 1d |
| Quartermaster: production queue system | Gameplay | ECS, economy | 1d |
| Economy system (harvester, ore, refinery, resource pool) | Gameplay | ECS | 2d |
| Auto-harvester behavior (harvest → return → repeat) | Gameplay | Pathfinding, economy | 1d |
| Basic combat (attack command, range check, damage, death) | Gameplay | ECS | 1.5d |
| 2 unit types: Infantry (T1), Light Tank (T2) | Gameplay | Combat | 1d |
| Field Marshal: unit selection + command (move, attack-move) | UI + Gameplay | Permissions | 1d |
| Split-screen or two-window local play | Network | Game loop | 1d |
| Shared resource bar UI | UI | Economy | 0.5d |
| Minimap (basic) | UI | Tilemap, entities | 1d |
| Placeholder art (colored shapes with team tinting) | — | — | 0.5d |

### Exit Criteria
- [ ] Player 1 (Commander) places buildings and sees them construct
- [ ] Player 1 (Commander) CANNOT select or command units — permission system rejects
- [ ] Player 2 (Field Marshal) selects and commands combat units
- [ ] Player 2 (Field Marshal) CANNOT place buildings
- [ ] Quartermaster role (can be same player as Commander for now) queues production
- [ ] Units spawn from buildings and can fight
- [ ] Resources are harvested and spent
- [ ] Two players can play on the same machine (split input or two windows)

### Risk
- Split-screen input routing in Godot can be tricky → fallback to two Godot instances connecting via localhost

---

## Phase 2: Networked Co-op (Weeks 6-8)

### Goal
Two players on different machines playing together over the network.

### Deliverables

| Task | Agent | Depends On | Est. |
|------|-------|------------|------|
| Command protocol (serialize/deserialize all commands) | Network | Command types from Phase 1 | 1.5d |
| Host-authoritative game state | Network | Game loop | 2d |
| State delta sync (snapshot + delta compression) | Network | Host authority | 2d |
| Lobby system (create/join, role selection) | Network + UI | Session manager | 1.5d |
| Client-side camera independence | UI | State sync | 0.5d |
| Fog of war (grid-based, shared team vision) | Engine + Gameplay | Vision components | 2d |
| Ping system (map pings visible to all teammates) | UI + Network | Networking | 0.5d |
| Network testing (latency injection, disconnect handling) | DevOps | Networking | 1d |

### Exit Criteria
- [ ] Two machines connect via LAN/internet
- [ ] Lobby: one player hosts, other joins, roles are assigned
- [ ] Gameplay from Phase 1 works identically over network
- [ ] Fog of war: can't see enemy units outside vision range
- [ ] Pings appear on teammates' maps
- [ ] 100ms simulated latency feels playable
- [ ] Client disconnect → game pauses → reconnect → game resumes

### Risk
- ENet NAT traversal can be finicky → Phase 2.5 fallback: add relay server or WebRTC
- State desync → add checksum verification every 100 ticks

---

## Phase 3: Full Skirmish vs AI (Weeks 9-13)

### Goal
A complete skirmish game: 2 humans vs AI opponent, with faction identity.

### Deliverables

| Task | Agent | Depends On | Est. |
|------|-------|------------|------|
| AEGIS faction: full T1-T2 unit roster (6-8 units) | Gameplay (parallel) | Combat system | 3d |
| FORGE faction: full T1-T2 unit roster (6-8 units) | Gameplay (parallel) | Combat system | 3d |
| Tech tree system (prerequisites, research time) | Gameplay | Economy | 1.5d |
| AEGIS tech tree data | Design | Tech tree system | 0.5d |
| FORGE tech tree data | Design | Tech tree system | 0.5d |
| Structure roster (both factions, T1-T2) | Gameplay | Structure placement | 2d |
| AI Opponent: basic (scripted build order → attack) | AI | All gameplay systems | 3d |
| AI Opponent: medium (utility-based, adapts to player) | AI | Basic AI | 3d |
| Commander UI: tech tree browser, structure palette | UI | Tech tree, structures | 2d |
| Quartermaster UI: production dashboard | UI | Production system | 1.5d |
| Field Marshal UI: unit cards, control groups, command panel | UI | Unit roster | 1.5d |
| Sound: basic combat sounds, UI clicks, ambient | — | — | 1d |
| Map: 2 skirmish maps with lane structure + expansion points | Design + Engine | Tilemap | 2d |
| Damage types + armor types (counter system) | Gameplay | Combat | 1d |
| Rally points, formation movement | Gameplay | Pathfinding | 1d |

### Exit Criteria
- [ ] AEGIS vs FORGE: distinct visual identity, different units, different feel
- [ ] Tech tree: meaningful choices (rush vs. tech)
- [ ] AI opponent builds a base, produces units, and attacks
- [ ] Medium AI adapts: if you spam tanks, it builds anti-armor
- [ ] Two humans can play a full 20-minute game that has an arc
- [ ] Game ends: victory screen when enemy HQ destroyed
- [ ] "Is this fun?" test: would you play this again? (subjective but critical)

### Risk
- Balance will be off → that's fine, this is the playtest phase
- AI may feel dumb → scripted difficulty helps: Easy AI is intentionally bad, gives humans time to learn roles

---

## Phase 4: Role Expansion (Weeks 14-17)

### Goal
4-player co-op with all core roles and Spec Ops gameplay.

### Deliverables

| Task | Agent | Depends On | Est. |
|------|-------|------------|------|
| Spec Ops role: full implementation | Gameplay | Permission system | 2d |
| Spec Ops units: Commando, Spy, Engineer, Saboteur | Gameplay | Spec Ops role | 2d |
| Stealth system (cloak, detection, reveal) | Gameplay | Vision/fog | 1.5d |
| Sabotage mechanics (C4, disable structure, steal tech) | Gameplay | Spec Ops | 1.5d |
| Spec Ops UI: intel overlay, ability bar, infiltration view | UI | Spec Ops systems | 2d |
| Chief Engineer role (5+ player games) | Gameplay | Permission system | 1d |
| Defensive structures: turrets, walls, gates, mines | Gameplay | Structure system | 2d |
| Repair mechanic | Gameplay | Health system | 0.5d |
| Lobby update: 2-6 player role selection | UI + Network | Session manager | 1d |
| AI Partner: Commander AI | AI | Commander role spec | 3d |
| AI Partner: Field Marshal AI | AI | Field Marshal spec | 3d |
| AI Partner: Quartermaster AI | AI | Quartermaster spec | 2d |
| AI Partner: Spec Ops AI | AI | Spec Ops spec | 2d |
| Hot-swap: AI ↔ human mid-game | Network | AI partners | 1.5d |

### Exit Criteria
- [ ] 4 humans can play together, each with a distinct role
- [ ] Spec Ops feels like "a different game inside the game"
- [ ] Solo player + 3 AI partners can play a full skirmish
- [ ] AI partner Commander makes reasonable build decisions
- [ ] AI partner Field Marshal doesn't throw units away
- [ ] Player can join mid-game, taking over an AI role smoothly

### Risk
- AI partners need tuning to feel helpful, not frustrating → start conservative, add aggression over time
- 4-player networking load → verify bandwidth budget holds

---

## Phase 5: T3 Content + Superweapons (Weeks 18-21)

### Goal
Late-game content that creates climactic moments.

### Deliverables

| Task | Agent | Depends On | Est. |
|------|-------|------------|------|
| T3 tech tier for both factions | Gameplay + Design | Tech tree | 2d |
| T3 units (3-4 per faction): heavy/super units | Gameplay (parallel) | T3 tech | 3d |
| Superweapon system (build time, targeting, dual-confirm) | Gameplay | Structure system | 2d |
| AEGIS superweapon: Orbital Cannon | Gameplay | Superweapon system | 1d |
| FORGE superweapon: Chemical Missile | Gameplay | Superweapon system | 1d |
| Faction mechanics: AEGIS shields, FORGE tunnels | Gameplay | Faction design | 3d |
| Hero units (1 per faction) | Gameplay | Spec Ops | 2d |
| AI Opponent: Hard difficulty (uses superweapons, multi-prong attacks) | AI | Superweapons, full roster | 3d |
| Visual effects: explosions, shields, energy weapons | UI/Art | — | 2d |
| 2 additional maps (4 total) | Design | Map system | 2d |

### Exit Criteria
- [ ] A game that reaches T3 feels epic — superweapons, hero units, massive armies
- [ ] Dual-confirm superweapon feels dramatic ("turn your key!")
- [ ] Faction mechanics create meaningfully different strategies
- [ ] Hard AI is a genuine challenge for a coordinated team

---

## Phase 6: Polish + Game Modes (Weeks 22-28)

### Goal
A polished vertical slice ready for external playtesting.

### Deliverables

| Task | Agent | Depends On | Est. |
|------|-------|------------|------|
| Operations mode (3 scripted scenarios) | Gameplay + Design | All systems | 4d |
| Endless Defense mode | Gameplay + Design | All systems | 3d |
| Music + full sound design | External/Asset | — | ongoing |
| Art pass: real sprites/models (can be asset packs initially) | External/Asset | — | ongoing |
| Tutorial / first-time experience | UI + Design | All roles | 3d |
| Settings menu (audio, video, keybinds, network) | UI | — | 1d |
| Performance optimization pass | Engine | Profiling | 2d |
| Balance pass (data-driven, spreadsheet analysis) | Design | Playtest data | ongoing |
| Bug bash | All | — | 2d |
| External playtest (friends, Discord community) | — | Polish | ongoing |

### Exit Criteria
- [ ] New player can learn one role in a tutorial mission
- [ ] 4+ maps, 2 factions, all roles, 3+ game modes
- [ ] Stable 60 FPS with 300+ units on mid-range hardware
- [ ] 10 external playtesters can complete a full game without crashes
- [ ] "Would you play this again?" rate > 70%

---

## Milestone Summary

```
Week  0 ─── Phase 0: Foundation ──────────── "A unit moves"
Week  2 ─── Phase 1: Split Control ───────── "Two players, one game"
Week  5 ─── Phase 2: Networked Co-op ─────── "Over the internet"
Week  8 ─── Phase 3: Full Skirmish ────────── "A real game vs AI"
Week 13 ─── Phase 4: Role Expansion ──────── "4-player team ops"
Week 17 ─── Phase 5: T3 + Superweapons ──── "Epic late game"
Week 21 ─── Phase 6: Polish + Modes ──────── "Ready for playtest"
Week 28 ─── External playtest / Early Access consideration
```

## Decision Gates

At each phase boundary, answer honestly:

1. **Is this fun?** If the core loop isn't fun by Phase 3, stop and redesign before adding content.
2. **Is the architecture holding?** If systems are fighting each other, refactor before Phase 4. It's cheaper now.
3. **Is agent productivity high?** If you're spending more time fixing agent output than writing code yourself, improve your prompts and interfaces before continuing.
4. **Is scope creeping?** If you've added features not in this doc, cut them or defer to Phase 6+.
