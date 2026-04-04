# 05 — In-Game AI Systems

## Overview

There are two fundamentally different AI systems in CRTO:

1. **AI Opponent** — plays against the human team, controls an entire faction
2. **AI Partner** — fills a cooperative role alongside human players

They share some infrastructure (behavior trees, game state reading) but have completely different design goals.

## 1. AI Opponent

### Design Goal
Create an opponent that is **fun to play against**, not one that is optimal. The AI should feel like a real commander with a personality, not a perfect calculator.

### Architecture

```
┌─────────────────────────────────────────┐
│            AI Opponent Controller        │
│                                         │
│  ┌─────────────┐  ┌─────────────────┐  │
│  │  Personality │  │  Game State     │  │
│  │  Config      │  │  Evaluator      │  │
│  │  (YAML)      │  │  (threat, econ, │  │
│  │              │  │   map control)  │  │
│  └──────┬──────┘  └────────┬────────┘  │
│         │                  │            │
│         ▼                  ▼            │
│  ┌─────────────────────────────────┐   │
│  │      Strategic Planner          │   │
│  │  (utility-based decision tree)  │   │
│  │                                 │   │
│  │  Options:                       │   │
│  │   - Expand economy              │   │
│  │   - Build army                  │   │
│  │   - Tech up                     │   │
│  │   - Attack (where, with what)   │   │
│  │   - Defend                      │   │
│  │   - Harass                      │   │
│  │                                 │   │
│  │  Each scored by:                │   │
│  │   utility = base_value          │   │
│  │           × personality_weight  │   │
│  │           × situation_modifier  │   │
│  └──────────────┬──────────────────┘   │
│                 │                       │
│                 ▼                       │
│  ┌─────────────────────────────────┐   │
│  │      Tactical Executor          │   │
│  │  (behavior trees per task)      │   │
│  │                                 │   │
│  │  BT: BuildBase                  │   │
│  │  BT: ManageEconomy              │   │
│  │  BT: AssembleArmy               │   │
│  │  BT: AttackTarget               │   │
│  │  BT: DefendBase                 │   │
│  │  BT: ScoutMap                   │   │
│  └──────────────┬──────────────────┘   │
│                 │                       │
│                 ▼                       │
│  ┌─────────────────────────────────┐   │
│  │      Command Emitter            │   │
│  │  (produces same Command types   │   │
│  │   as human players)             │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### Personality System

Each AI opponent has a personality defined in YAML:

```yaml
# ai_personalities/colonel_volkov.yaml
name: "Colonel Volkov"
faction: forge
difficulty: hard
description: "Aggressive commander who pressures early and never lets up."

strategy_weights:
  expand_economy: 0.5    # lower priority
  build_army: 1.5        # much higher priority
  tech_up: 0.6
  attack: 1.8            # very aggressive
  defend: 0.4            # doesn't like turtling
  harass: 1.2

behavior:
  first_attack_tick: 600       # attacks early (~40 seconds)
  attack_frequency: medium     # attacks regularly
  retreat_threshold: 0.3       # only retreats when army is 30% or less
  expansion_timing: late       # expands only when forced
  tech_priority: [vehicles, infantry, air]  # prefers vehicles
  preferred_composition:
    vehicles: 0.6
    infantry: 0.3
    air: 0.1

difficulty_modifiers:
  resource_bonus: 1.0          # no cheating on hard (cheats on easy to be worse)
  reaction_time_ticks: 5       # reacts quickly
  micro_precision: 0.8         # 80% optimal micro
  scouting_frequency: high
  multi_prong_attacks: true

personality_quirks:
  - "Will always attack the expansion farthest from your main base"
  - "Loves flame tanks — will over-build them"
  - "Will NOT retreat if hero unit is in the fight"
```

### More Personality Examples

```yaml
# ai_personalities/dr_chen.yaml
name: "Dr. Chen"
faction: aegis
difficulty: medium
description: "Defensive mastermind who turtles to T3 and overwhelms with technology."

strategy_weights:
  expand_economy: 1.2
  build_army: 0.6
  tech_up: 1.8           # races to T3
  attack: 0.5            # passive until ready
  defend: 1.6            # loves defense
  harass: 0.3

behavior:
  first_attack_tick: 3000      # doesn't attack until ~3 minutes
  attack_frequency: rare       # but when attacks, it's devastating
  retreat_threshold: 0.6       # retreats easily to preserve army
  expansion_timing: mid
  tech_priority: [tech, air, vehicles]
  preferred_composition:
    vehicles: 0.3
    infantry: 0.1
    air: 0.4
    special: 0.2               # loves hero units + superweapon

difficulty_modifiers:
  resource_bonus: 1.0
  reaction_time_ticks: 15
  micro_precision: 0.6
  scouting_frequency: medium
  multi_prong_attacks: false    # single decisive push
```

### Difficulty Scaling

Rather than making AI "cheat" at higher difficulties, scale these knobs:

| Knob | Easy | Medium | Hard |
|------|------|--------|------|
| Reaction time (ticks) | 45 (3s) | 15 (1s) | 5 (0.3s) |
| Build order efficiency | 50% | 75% | 95% |
| Micro precision | 30% | 60% | 85% |
| Scouting | Rarely | Occasionally | Constantly |
| Counter-building | Never | Sometimes | Always |
| Multi-prong attacks | Never | Rarely | Regularly |
| Resource bonus | 0.8x (penalty) | 1.0x | 1.0x |
| Expansion timing | Very late | Appropriate | Optimal |

**Easy AI should feel beatable but not brain-dead.** It makes mistakes a human would make — forgets to scout, doesn't counter properly, attacks at bad times.

### Game State Evaluator

The AI reads game state and produces evaluations:

```
EvaluationResult {
    threat_level: f32,           # 0.0 (safe) to 1.0 (base under attack)
    economic_health: f32,        # income vs. spend rate
    army_strength_ratio: f32,    # my army / estimated enemy army
    map_control: f32,            # % of map I have vision/presence in
    tech_advantage: f32,         # my tech tier vs. estimated enemy tier
    expansion_opportunity: f32,  # available uncontested expansion slots

    threats: Vec<Threat>,        # specific threats with positions
    opportunities: Vec<Opportunity>,  # attack targets, expansion sites
}
```

This evaluation feeds into the utility function that decides what to do next.

---

## 2. AI Partner

### Design Goal
An AI that fills a cooperative role so well that a solo player paired with AI partners has a **complete, satisfying game experience.**

### Critical Design Constraint
The AI partner must be:
- **Predictable enough** to coordinate with (no random surprises)
- **Competent enough** to not feel like a liability
- **Communicative enough** to feel like a teammate (uses ping system, sends requests)
- **Deferential enough** to let the human lead (follows human pings/objectives)

### Architecture: Role-Specific AI

Each role has its own AI implementation, because the decision space is completely different:

```
┌────────────────────────────────────────────────┐
│              AI Partner Controller              │
│                                                │
│  ┌──────────────────────────────────────────┐  │
│  │  Shared: Game State Reader               │  │
│  │  Shared: Communication Layer (pings,     │  │
│  │          requests, acknowledgments)       │  │
│  │  Shared: Human Intent Tracker            │  │
│  │          (what is the human doing?        │  │
│  │           what have they pinged?)         │  │
│  └──────────────────────────────────────────┘  │
│                                                │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│  │Commander │ │Quarter-  │ │ Field    │  ...   │
│  │   AI     │ │master AI │ │Marshal AI│       │
│  │          │ │          │ │          │       │
│  │Behavior: │ │Behavior: │ │Behavior: │       │
│  │-Build    │ │-Optimize │ │-Defend   │       │
│  │ order    │ │ production│ │-Attack   │       │
│  │-Tech path│ │-Balance  │ │-Retreat  │       │
│  │-Expand   │ │ queues   │ │-Support  │       │
│  │-Respond  │ │-Anticipate│ │-Control  │       │
│  │ to pings │ │ needs    │ │ map      │       │
│  └──────────┘ └──────────┘ └──────────┘       │
└────────────────────────────────────────────────┘
```

### Commander AI (Partner)

```
Priority Loop (every 30 ticks / 2 seconds):
    1. Check for human pings:
       - "Build here" ping? → Place appropriate structure at location
       - "Expand" ping? → Build expansion at pinged location
       - "Need defense" ping? → Build turrets at pinged location

    2. Follow build order:
       - Has a pre-set build order for first 3 minutes
       - After that, adapts based on:
         - What Field Marshal is fighting (if they're facing tanks, research anti-armor)
         - What Quartermaster requests (if QM says "need another factory", build it)
         - Threat assessment (if base threatened, build defenses)

    3. Tech decisions:
       - Default tech path per faction
       - Accelerate if economy is strong
       - Delay if under pressure

    4. Communication:
       - Ping when starting important research ("Researching T2 — 45 seconds")
       - Ping when expansion is ready
       - Warn when power is low
```

### Quartermaster AI (Partner)

```
Priority Loop (every 15 ticks / 1 second):
    1. Never let a factory idle:
       - If factory has empty queue and resources available → queue units
       - Priority: whatever Field Marshal last requested > balanced composition

    2. Harvester management:
       - Maintain optimal harvester count (2 per active refinery)
       - Route harvesters to safest ore fields
       - Replace lost harvesters immediately

    3. Read team needs:
       - Track Field Marshal's unit losses → auto-replace
       - Track Spec Ops' requests for elite units
       - If Field Marshal pings "need anti-air" → shift production

    4. Economy optimization:
       - Expand harvester count when income drops below threshold
       - Request new refinery from Commander when needed
       - Alert team when resources are low

    5. Communication:
       - Announce production: "4 tanks queued, 60 seconds"
       - Warn on resource issues: "Ore depleting, need new expansion"
       - Respond to requests: "Anti-air queued, 30 seconds"
```

### Field Marshal AI (Partner)

```
Priority Loop (every 5 ticks / 0.3 seconds):
    1. Immediate threats:
       - Base under attack? → Rally all available units to defend
       - Human-pinged "danger" location? → Send units there

    2. Follow human direction:
       - Human pinged "attack here"? → Send army to that location
       - Human set objective marker? → Prioritize that area
       - No human direction? → Default behavior below

    3. Default behavior:
       - Army < threshold → hold defensive position near base
       - Army >= threshold → advance to nearest contested area
       - Strong army advantage → push toward enemy base

    4. Tactical micro:
       - Focus fire on highest-value targets
       - Pull back damaged units (if retreat_threshold met)
       - Don't chase into fog of war
       - Keep army in formation during movement

    5. Communication:
       - "Attacking [location]" when committing to fight
       - "Falling back, lost too many units" when retreating
       - "Need more [unit type]" based on what counters the enemy
       - "Enemy pushing [location]" when spotting large threat
```

### Spec Ops AI (Partner)

```
Priority Loop (every 15 ticks / 1 second):
    1. Scouting:
       - Always have at least 1 unit scouting unexplored areas
       - Prioritize scouting enemy base (identify tech level, army composition)
       - Report findings: "Enemy has [unit types] at [location]"

    2. Sabotage opportunities:
       - Identify undefended high-value targets (power plants, refineries, tech labs)
       - Plan infiltration route (avoid detection zones)
       - Execute sabotage if success probability > 60%
       - Retreat after sabotage — don't overcommit

    3. Support Field Marshal:
       - Mark high-value targets in enemy army (artillery, support units)
       - Time sabotage to coincide with main army push (if pinged)
       - Hero unit: use at decisive moments, not casually

    4. Communication:
       - "Scouting [location]"
       - "Enemy building [structure] — they're teching to [tier]"
       - "Going for sabotage on their [target]"
       - "Sabotage successful / failed"
```

### Human Intent Tracker

All partner AIs share a system that tracks what the human is doing:

```
HumanIntentTracker:
    recent_pings: Vec<(PingType, Position, Timestamp)>
    recent_requests: Vec<(Request, Timestamp)>
    human_role_activity:
        camera_focus_area: Position      # where is human looking?
        last_action: Action              # what did they just do?
        action_frequency: f32            # how active are they?

    inferred_intent:
        - if camera on enemy base + producing lots of units → human is planning attack
        - if camera on expansion + recent "expand" pings → human wants to expand
        - if human is idle → AI should take more initiative
        - if human is very active → AI should be more supportive/reactive
```

This allows AI partners to adapt to how actively the human is playing, filling gaps rather than duplicating effort.

---

## 3. Shared AI Infrastructure

### Behavior Tree Framework

```
Nodes:
    Composite:
        - Sequence (AND — all children must succeed)
        - Selector (OR — first child that succeeds)
        - Parallel (run children simultaneously)

    Decorator:
        - Inverter (flip success/fail)
        - Repeater (repeat N times or until fail)
        - Cooldown (don't re-evaluate for N ticks)
        - Condition (only run child if condition met)

    Leaf:
        - Action (execute a game command)
        - Condition (check game state)
        - Wait (do nothing for N ticks)

Blackboard:
    Per-AI shared state:
        - Current strategic goal
        - Known enemy positions
        - Resource status
        - Pending commands
        - Recent communication
```

### Threat Assessment System

Shared between opponent and partner AIs:

```
assess_threat(position, radius) → ThreatInfo:
    enemy_units: Vec<(UnitType, Count, EstimatedStrength)>
    enemy_structures: Vec<(StructureType, Position)>
    overall_strength: f32
    composition_analysis: {
        anti_infantry: f32,
        anti_vehicle: f32,
        anti_air: f32,
        anti_structure: f32,
    }

estimate_army_strength(units) → f32:
    sum of (unit.health * unit.dps * type_multiplier)
    # Simple heuristic, not perfect — and that's fine
```

### Communication Protocol (AI ↔ Human)

AIs use the same communication systems humans use:

```
AI Communication Actions:
    ping_map(position, type)           # appears as map ping
    send_request(target_role, request) # appears in request queue
    send_status(message)               # appears in team chat
    acknowledge_ping(ping_id)          # "acknowledged" indicator

Rate Limiting:
    Max 1 ping per 5 seconds (don't spam)
    Max 1 status message per 10 seconds
    Requests: max 1 pending per target role
```

---

## 4. AI Development Iteration Plan

### Iteration 1: Scripted AI Opponent
- Follows a fixed build order
- Attacks at predetermined times
- No adaptation
- **Purpose:** Something to play against while developing other systems

### Iteration 2: Reactive AI Opponent
- Adapts build order based on scouting
- Chooses attack timing based on army strength comparison
- Retreats when losing
- **Purpose:** A real challenge, but predictable once you learn the patterns

### Iteration 3: Personality-Driven AI Opponent
- Utility-based decision making with personality weights
- Multiple distinct AI characters
- Multi-prong attacks, harassment, expansion
- **Purpose:** Replayable — different AI personality = different game

### Iteration 4: AI Partners
- Start with Quartermaster (most rule-based, easiest to get right)
- Then Field Marshal (most impactful, needs careful tuning)
- Then Commander (most complex decision space)
- Then Spec Ops (most situational, needs personality)
- **Purpose:** Enable solo play

### Iteration 5: Coordinated AI
- AI partners communicate with each other (not just with human)
- AI opponent reads team behavior and adapts strategy
- **Purpose:** AI feels alive, not mechanical
