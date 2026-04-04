# CRTO — Cooperative Real-Time Operations

**Genre:** Cooperative RTS  
**Engine:** Godot 4.4+  
**Players:** 2-6 cooperative vs AI opponent  
**Inspiration:** C&C Red Alert / RA2 / StarCraft — reimagined as a team sport  

## Core Concept
Each player fills a specialized role (Commander, Quartermaster, Field Marshal, Spec Ops, etc.). The RTS simulation is the substrate — the real game is coordinating under pressure.

## Design Pillars
1. Cooperation IS the gameplay
2. Every role has agency
3. Accessible depth — new player contributes immediately, infinite skill ceiling
4. AI as first-class teammate
5. Social by default — creates stories worth telling

## Tech Stack
- **Gameplay language:** GDScript (fast iteration, huge AI training corpus)
- **Performance-critical:** C++ via GDExtension (pathfinding, simulation tick)
- **Data format:** YAML (design data), JSON (runtime serialization)
- **Networking:** ENet (built-in Godot) — host-authoritative, co-op tolerates ~100ms latency
- **Version control:** Git + GitHub

## Project Layout
```
projects/crto/
├── docs/           ← Design & architecture docs
├── game/           ← Godot project root
│   ├── data/       ← YAML game data (agent-editable)
│   ├── src/        ← GDScript source
│   └── native/     ← C++ GDExtension
├── prompts/        ← Agent prompt library (this directory)
└── tools/          ← Build & dev tools
```

## Architecture in One Paragraph
Host-authoritative simulation running at 15 ticks/sec. Clients send Commands (never modify state directly). Server validates against a Role Permission System, queues valid commands, runs ECS simulation, broadcasts state deltas every 2 ticks. Rendering is decoupled and interpolated at display FPS. No deterministic lockstep needed — co-op vs AI tolerates latency gracefully.

## ECS Overview
Entities have Components. Systems run in fixed order each tick. Role ownership is encoded as tags on entities. Full component list: see `docs/02-TECHNICAL-ARCHITECTURE.md`.

## Current Phase
**Phase 0** — Foundation. Goal: a unit moves to where you click on a tiled map.
