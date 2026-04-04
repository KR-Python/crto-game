# CRTO — Cooperative Real-Time Operations

## Project Planning Documents

| Document | Description |
|----------|-------------|
| [01-GAME-DESIGN.md](01-GAME-DESIGN.md) | Game Design Document — vision, mechanics, roles, factions, progression |
| [02-TECHNICAL-ARCHITECTURE.md](02-TECHNICAL-ARCHITECTURE.md) | Technical Architecture — ECS, networking, permission system, simulation model |
| [03-AGENT-WORKFORCE.md](03-AGENT-WORKFORCE.md) | Agentic AI Development Workforce — agent roles, prompt strategies, integration patterns |
| [04-DELIVERY-ROADMAP.md](04-DELIVERY-ROADMAP.md) | Phased Delivery Roadmap — milestones, exit criteria, dependencies, risk mitigations |
| [05-AI-SYSTEMS.md](05-AI-SYSTEMS.md) | In-Game AI Systems — opponent AI, partner AI, behavior trees, difficulty scaling |
| [06-DATA-SCHEMAS.md](06-DATA-SCHEMAS.md) | Data Schemas — unit definitions, tech trees, map format, role permissions |

## Concept

A cooperative real-time strategy game where 2-6 players share control of a single faction, each filling a specialized operational role (Commander, Quartermaster, Field Marshal, Spec Ops, etc.). Play with friends or AI partners against increasingly challenging AI opponents.

**Genre:** Cooperative Real-Time Operations (CRTO)
**Players:** 2-6 cooperative (human or AI) vs AI opponent
**Inspiration:** C&C Red Alert, RA2/Yuri's Revenge, StarCraft — reimagined as a team sport
**Engine:** Godot 4.4+
**Target Platforms:** PC (Windows/Linux/Mac), with architecture supporting future console/mobile

## Design Pillars

1. **Cooperation IS the gameplay.** The RTS simulation is the substrate. The real game is coordinating under pressure with your team.
2. **Every role has agency.** No role should feel like "the boring one." Each has meaningful decisions, tension, and moments of glory.
3. **Accessible depth.** A new player can fill one role and contribute immediately. Mastery of coordination between roles provides infinite skill ceiling.
4. **AI as first-class teammate.** AI partners must be good enough that solo + AI feels like a complete experience, not a compromise.
5. **Social by default.** The game should create stories worth telling. "Remember when our Spec Ops snuck behind their base while we held the bridge?"
