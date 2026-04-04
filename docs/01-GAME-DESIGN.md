# 01 — Game Design Document

## 1. Core Loop

```
Scout → Plan → Build → Produce → Deploy → Engage → Adapt → Repeat
  |        |       |        |         |        |        |
SpecOps  Cmdr   Cmdr    QMaster   QMaster  FMarshal  Everyone
         +Team                     +FMarshal +SpecOps
```

A single game follows a classic RTS arc but distributed across roles:

1. **Early Game (0-5 min):** Commander places initial structures, Quartermaster optimizes harvester routing, Field Marshal positions starting units defensively, Spec Ops scouts
2. **Mid Game (5-15 min):** Tech choices diverge, economy scales, first major engagements, territory control becomes critical
3. **Late Game (15-30 min):** Superweapons, tier 3 units, coordinated pushes, decisive battles
4. **Match Length Target:** 15-30 minutes for standard games, 10-15 for quick mode

## 2. Player Roles — Detailed Design

### 2.1 Commander (The Strategist)

**Fantasy:** You are the general looking at the big board. You decide WHAT gets built and WHERE.

**Controls:**
- Place all structures (barracks, factories, defenses, tech buildings, expansions)
- Choose tech path / research upgrades
- Set strategic waypoints and objective markers visible to all players
- Approve superweapon deployment (requires co-sign from Field Marshal)
- Designate expansion locations

**Cannot:**
- Select or command any mobile units
- Queue production (that's Quartermaster)
- Control harvesters

**Unique UI Elements:**
- Strategic overlay: fog-of-war with threat assessment heat map
- Tech tree browser with research queue
- Structure placement ghost with power grid visualization
- Team comms panel: ping system, objective markers

**Skill Expression:**
- Base layout (chokepoints, power routing, defense depth)
- Tech timing (when to invest in upgrades vs. raw production)
- Strategic reads (scouting intel → what to prepare for)
- Resource allocation calls ("Quartermaster, shift 70% to tank production")

**Why It's Fun:** You're playing SimCity under siege. Every building placement is a bet on the future. You see the whole picture and make the calls.

---

### 2.2 Quartermaster (The Economist)

**Fantasy:** You are the supply chain. Nothing moves, nothing fights, nothing gets built without your output.

**Controls:**
- Queue unit production at all production structures
- Route harvesters to specific resource nodes
- Set production priorities and rally points
- Manage power grid (toggle buildings on/off to manage power)
- Request Commander build specific structures

**Cannot:**
- Place structures
- Command combat units
- Research tech

**Unique UI Elements:**
- Production dashboard: all factories with queue status, ETA, efficiency %
- Resource flow graph: income vs. spend rate, projected depletion
- Harvester map: routes, capacity, threats to harvesters
- Supply/demand alerts: "Field Marshal needs anti-air, 0 in production"

**Skill Expression:**
- Production efficiency (never idle factories, optimal queue depth)
- Economy reads (when to expand harvester count vs. spend reserves)
- Anticipation (pre-building counters before Field Marshal asks)
- Resource node control (routing harvesters safely, prioritizing rich nodes)

**Why It's Fun:** You're playing Factorio inside an RTS. The dopamine hit of a perfectly optimized production pipeline feeding a teammate's army is real. When the Field Marshal says "I need more tanks" and you already have 6 queued, you're a god.

---

### 2.3 Field Marshal (The Warrior)

**Fantasy:** You control the army. Every unit, every engagement, every flanking maneuver.

**Controls:**
- Select and command all standard combat units (infantry, vehicles, naval)
- Attack-move, patrol, guard, formations, focus fire
- Control group management
- Set defensive positions
- Request production from Quartermaster

**Cannot:**
- Build structures
- Queue production
- Control Spec Ops units or hero units
- Control harvesters

**Unique UI Elements:**
- Tactical minimap with unit group indicators
- Combat forecast (selected units vs. visible enemies)
- Engagement history (last 3 fights: win/loss/units lost)
- Quick request wheel: "Need tanks / Need anti-air / Need infantry / Need support"

**Skill Expression:**
- Micro (focus fire, kiting, ability usage, retreat timing)
- Macro positioning (army splits, map control, chokepoint holds)
- Engagement selection (knowing when to fight vs. when to back off)
- Communication (calling targets, requesting specific unit compositions)

**Why It's Fun:** Pure combat RTS with none of the base management overhead. You get to focus entirely on the part of RTS that creates highlight-reel moments.

---

### 2.4 Spec Ops (The Rogue)

**Fantasy:** You're behind enemy lines. Small team, high impact, high risk.

**Controls:**
- Command elite/special units (commandos, spies, engineers, stealth units)
- Scouting and intelligence gathering
- Sabotage (plant C4, disable structures, steal tech)
- Hero unit abilities
- Mark high-value targets for the team

**Cannot:**
- Control standard army units
- Build structures
- Queue production (can request specific elite units)

**Unit Cap:** 10-15 units maximum (elite, expensive, powerful)

**Unique UI Elements:**
- Intel overlay: last-known enemy positions, structure IDs, patrol routes
- Infiltration view: detection radius visualization for enemy units/structures
- Ability cooldown tracker
- Target marking system (visible to Field Marshal and Commander)

**Skill Expression:**
- Infiltration routing (getting past defenses, timing patrols)
- Target prioritization (what's the highest-value sabotage target right now?)
- Intel communication (calling out enemy compositions and positions)
- Hero unit mastery (ability combos, clutch plays)

**Why It's Fun:** You're playing a stealth/tactical game inside an RTS. While your teammates handle the conventional war, you're doing spec ops missions. When you blow up their superweapon 5 seconds before it fires, everyone cheers.

---

### 2.5 Chief Engineer (5-6 player games)

**Fantasy:** You are the fortress builder. Walls, turrets, minefields, and repairs.

**Controls:**
- Place defensive structures (turrets, walls, gates, mines, sensors)
- Repair all friendly structures and vehicles
- Build and manage base expansions
- Control engineer units for battlefield repairs
- Manage power grid jointly with Quartermaster

**Cannot:**
- Place production buildings or tech buildings (Commander only)
- Command combat units
- Queue production

**Skill Expression:**
- Defensive geometry (overlapping fields of fire, funnel chokepoints)
- Repair prioritization under fire
- Expansion defense timing
- Mine placement mindgames

---

### 2.6 Air Marshal (5-6 player games)

**Fantasy:** You own the sky.

**Controls:**
- All air units (fighters, bombers, transports, gunships)
- Airfield management
- Air-to-ground support requests
- Paradrop coordination
- Anti-air defense coordination with Chief Engineer

**Cannot:**
- Control ground units
- Build non-airfield structures

**Skill Expression:**
- Air superiority management
- Bombing run timing and targeting
- Transport micro (drops behind enemy lines coordinated with Spec Ops)
- Air patrol routing for intel

---

## 3. Shared Systems

### 3.1 Economy

- **Two resource types:** Primary (ore/minerals — abundant, steady) and Secondary (gems/gas — scarce, needed for advanced units)
- **Shared pool:** All players draw from the same reserves
- **Visibility:** Every player sees current resources, income rate, and spend rate per role
- **Tension mechanic:** When resources are scarce, roles must negotiate priority. A simple "priority request" system lets any player flag urgency

### 3.2 Communication

- **Ping System:** All players can ping the map with context (danger, attack here, defend here, scout here, expand here)
- **Request System:** Structured requests between roles (Field Marshal → Quartermaster: "Need 4 tanks"), with accept/deny/queued responses
- **Strategic Markers:** Commander can place persistent objective markers on the map
- **Voice Chat:** Built-in proximity or team voice (or rely on Discord/external)
- **Quick Comms Wheel:** Radial menu with role-specific callouts

### 3.3 Shared Vision

- All players share the same fog of war
- Each player's camera is independent (look at what matters to YOUR role)
- Minimap shows teammate camera positions as colored indicators
- Any player can "ping to look" to draw teammates' attention

### 3.4 Superweapon Protocol

Superweapons require multi-role authorization:
1. Commander selects the superweapon and designates target
2. Field Marshal confirms the target (or suggests alternative)
3. Both players "turn their key" simultaneously (2-second window)
4. Weapon fires

This prevents accidental launches and creates a dramatic team moment.

## 4. Faction Design (Initial — 2 Factions)

### 4.1 Faction: AEGIS (Defensive/Tech)

**Identity:** Advanced technology, energy weapons, shields, air superiority
**Playstyle:** Slower start, powerful mid-to-late game, excels at defense and tech
**Aesthetic:** Clean, angular, blue/white, energy fields

| Tier | Infantry | Vehicles | Air | Structures | Special |
|------|----------|----------|-----|------------|---------|
| T1 | Rifleman, Engineer | Scout Buggy, Light Tank | — | Barracks, Refinery, Power Plant | — |
| T2 | Rocket Trooper, Medic | Medium Tank, APC, AA Vehicle | Interceptor, Scout Drone | War Factory, Radar, Tech Lab | Shield Generator |
| T3 | Shock Trooper, Sniper | Heavy Tank, Artillery | Bomber, Gunship, Transport | Advanced Tech, Air Field | Orbital Cannon (superweapon) |

**Faction Mechanic:** Shield Generators create protective bubbles over structures. Chief Engineer can reposition shields. Shields recharge over time.

### 4.2 Faction: FORGE (Aggressive/Industry)

**Identity:** Raw industrial power, overwhelming numbers, brute force, chemical weapons
**Playstyle:** Fast expansion, swarm tactics, powerful early-mid game, must close out before AEGIS reaches T3
**Aesthetic:** Rough, industrial, red/black, smoke and fire

| Tier | Infantry | Vehicles | Air | Structures | Special |
|------|----------|----------|-----|------------|---------|
| T1 | Conscript, Saboteur | Attack Bike, Flame Tank | — | Barracks, Refinery, Generator | — |
| T2 | Grenadier, Flametrooper | Battle Tank, Rocket Buggy, Toxin Truck | Helicopter, Recon Plane | War Factory, Radar, Munitions | Tunnel Network |
| T3 | Commando, Chem Trooper | Siege Tank, Mammoth Tank | Strike Bomber, Transport | Advanced Munitions, Airstrip | Chemical Missile (superweapon) |

**Faction Mechanic:** Tunnel Network allows instant unit transport between connected tunnel entrances. Spec Ops can use tunnels for infiltration. Enemy can destroy tunnel exits.

## 5. Map Design Principles

- **Lane Structure:** Maps should have 2-3 natural attack paths with defensible chokepoints
- **Resource Placement:** Starting ore near base, secondary resources (gems) in contested middle ground
- **Expansion Slots:** 2-3 designated expansion points per side, each with risk/reward tradeoffs
- **Spec Ops Routes:** Every map should have "back door" paths — narrow passages, water routes, cliffs — that are impractical for armies but perfect for small squads
- **Symmetry:** Rotational symmetry for fairness, not mirror symmetry (more interesting map reads)
- **Size Scaling:** Maps scale with player count — 2-player maps are tighter, 6-player maps have more territory to control

## 6. Game Modes

### 6.1 Skirmish (Core)
- Team vs AI on selected map
- Configurable: difficulty, AI personality, starting resources, map
- This is the primary mode — must be excellent

### 6.2 Operations (Campaign-lite)
- Pre-designed scenarios with specific objectives
- Narrative framing but not a full story campaign
- Examples: "Hold the bridge for 20 minutes," "Escort the convoy," "Destroy the weapon before it fires"
- Excellent for introducing new players to roles gradually

### 6.3 Endless Defense
- Cooperative tower defense variant
- Waves of increasing difficulty
- All resources come from defeating waves
- Tests coordination endurance — how long can your team hold?

### 6.4 Ranked Co-op (Future)
- Matchmade teams vs AI on escalating difficulty
- Leaderboards per team composition
- Seasonal challenges

## 7. Progression & Meta (Light Touch)

- **No pay-to-win, no loot boxes.** Period.
- **Role Mastery:** Track stats per role (economy efficiency for Quartermaster, K/D for Field Marshal, sabotages for Spec Ops)
- **Cosmetics:** Faction skins, unit skins, commander portraits, ping cosmetics
- **Unlockable AI Personalities:** Beat certain challenges to unlock new AI opponent types
- **Team History:** Track stats for regular groups — "Your squad has won 47 games together"
