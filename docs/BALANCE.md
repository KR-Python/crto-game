# CRTO Balance Reference

> **Living document** — updated each balance pass. All DPS values = `damage × (1 / cooldown)`.
> Armor multipliers applied: `final_damage = base_damage × matrix[damage_type][armor_type]`

---

## Damage/Armor Matrix

| Damage Type | vs Light | vs Medium | vs Heavy | vs Building |
|-------------|----------|-----------|----------|-------------|
| **Kinetic**   | 1.00× | 0.75× | 0.50× | 0.25× |
| **Explosive** | 1.50× | 1.00× | 0.75× | 1.50× |
| **Energy**    | 0.75× | 1.00× | 1.25× | 1.00× |
| **Chemical**  | 1.50× | 1.25× | 0.50× | 0.25× |
| **Fire**      | 1.75× | 1.00× | 0.25× | 1.50× |

**Key insights:**
- Explosive is the universal solvent — decent vs everything, great vs buildings and light armor
- Energy is the anti-heavy specialist — worst vs light, best vs heavy
- Chemical/Fire excel vs light armor (infantry), but fall off sharply vs heavy/buildings
- Kinetic is reliable vs light but severely penalized vs heavy and buildings

---

## T1 Unit Comparison

| Unit | Faction | Cost | HP | Armor | DPS (raw) | Eff DPS vs Light | Eff DPS vs Heavy | Role | Counters | Countered By |
|------|---------|------|-----|-------|-----------|-----------------|-----------------|------|----------|--------------|
| Rifleman | AEGIS | 150 | 120 | Light | 15.0 (kinetic) | 15.0 | 7.5 | Combat infantry | Forge Conscript | Fire, AoE explosives |
| Engineer | AEGIS | 200 | 80 | Light | 4.2 (kinetic) | 4.2 | 2.1 | Repair/utility | — (utility) | Any combat unit |
| Harvester | AEGIS | 600 | 400 | Heavy | — (unarmed) | — | — | Economy | — | Any combat unit |
| Scout Buggy | AEGIS | 250 | 150 | Light | 16.0 (kinetic) | 16.0 | 8.0 | Recon/harassment | Slow infantry, harvesters | Forge Attack Bike |
| Conscript | FORGE | 100 | 85 | Light | 10.0 (kinetic) | 10.0 | 5.0 | Cheap swarm | Economy pressure | AEGIS Rifleman 1v1 |
| Saboteur | FORGE | 250 | 90 | Light | 15.0 (explosive) | 22.5 | 11.3 | Spec Ops/demo | Structures (C4), vehicles | Scout Buggy, massed Riflemen |
| Harvester | FORGE | 600 | 400 | Heavy | — (unarmed) | — | — | Economy | — | Any combat unit |
| Attack Bike | FORGE | 200 | 100 | Light | 12.5 (explosive) | 18.75 | 9.4 | Fast raider | Harvesters, scouts | Massed Riflemen, turrets |

**T1 Notes:**
- **Rifleman vs Conscript:** Rifleman wins 1v1 (15 DPS, 120 HP vs 10 DPS, 85 HP). But 3 Conscripts (300cr) handily beat 2 Riflemen (300cr). FORGE gets better cost efficiency in swarms.
- **Attack Bike** is the fastest T1 unit (7.5 speed) and deals explosive — excellent harasser, hard to catch.
- **Scout Buggy** has exceptional vision range (12 tiles), unique among T1 units.
- **Saboteur's Plant C4** (200 structure damage, 30s CD) is potent for structure snipes even at T1.

---

## T2 Unit Comparison

| Unit | Faction | Cost | HP | Armor | DPS (raw) | Eff DPS vs Light | Eff DPS vs Heavy | Role | Counters | Countered By |
|------|---------|------|-----|-------|-----------|-----------------|-----------------|------|----------|--------------|
| Medic | AEGIS | 250+50sec | 90 | Light | — (no weapon) | — | — | Sustain healer | Attrition (heal aura) | Any combat unit |
| Rocket Trooper | AEGIS | 300 | 100 | Light | 26.0 (explosive) | 39.0 | 19.5 | Anti-vehicle infantry | Vehicles, tanks | Snipers, air units |
| Guardian APC | AEGIS | 500 | 300 | Medium | 25.0 (kinetic) | 25.0 | 12.5 | Transport/screen | Infantry positioning | Rocket Trooper, Battle Tank |
| Guardian Tank | AEGIS | 800 | 450 | Heavy | 42.5 (kinetic) | 42.5 | 21.3 | Main battle tank | Light vehicles, infantry, structures | Rocket Trooper, explosive |
| Skyguard AA | AEGIS | 600+100sec | 250 | Medium | 40.0 (energy) | 30.0 | 50.0* | Anti-air only | All air units | Ground units (helpless) |
| Interceptor | AEGIS | 700+150sec | 180 | Medium | 37.5 (energy) | 28.1 | 46.9* | Air superiority | Helicopters, all air | AA Vehicle, Skyguard |
| Grenadier | FORGE | 250 | 110 | Medium | 20.0 (explosive, AoE 2.0) | 30.0 | 15.0 | AoE anti-infantry | Infantry blobs, light vehicles | Tanks, long-range units |
| Flametrooper | FORGE | 200 | 100 | Light | 50.0 (fire, AoE 1.5) | **87.5** | 12.5 | Close-range AoE | Infantry, buildings | Long-range units, tanks |
| Crusher Tank | FORGE | 700 | 400 | Heavy | 41.7 (kinetic) | 41.7 | 20.8 | Main battle tank | Light vehicles, infantry, structures | Rocket Trooper, explosive |
| Rocket Buggy | FORGE | 450+50sec | 180 | Light | 22.0 (explosive) | 33.0 | 16.5 | Fast anti-vehicle | Tanks, heavy vehicles | Interceptors, infantry |
| Toxin Truck | FORGE | 550+100sec | 280 | Medium | 13.3 (chemical, AoE 3.0) | 20.0 | 6.7 | Area denial/DoT | Infantry, defensive positions | Snipers, long-range vehicles |
| Havoc Gunship | FORGE | 650+100sec | 220 | Medium | 25.0 (explosive, AoE 1.5) | 37.5 | 18.75 | Air gunship vs ground | Ground vehicles, structures | Interceptor, AA Vehicle |

*Air units use medium armor at T2; energy vs medium = 1.0× multiplier.

**T2 Notes:**
- **AEGIS gets dedicated Medic** (no FORGE equivalent at T2) — significant sustain advantage in infantry fights.
- **Flametrooper is the standout concern:** 50 raw DPS × 1.75 fire vs light = **87.5 effective DPS** at only 200cr primary. Highest DPS/cost at T2. Countered by range but can decimate blob infantry before dying. ⚠️ See FLAG-01.
- **FORGE has NO T2 air-to-air counter.** Havoc Gunship only targets ground. AEGIS Interceptor dominates the sky unopposed from T2. ⚠️ See FLAG-02.
- **Guardian Tank vs Crusher Tank:** AEGIS 42.5 DPS / 450 HP / 800cr vs FORGE 41.7 DPS / 400 HP / 700cr. FORGE tank is ~12.5% cheaper for nearly equal performance — slight FORGE advantage.

---

## T3 Unit Comparison

| Unit | Faction | Cost | HP | Armor | DPS (raw) | Eff DPS vs Heavy | Role | Counters | Countered By |
|------|---------|------|-----|-------|-----------|-----------------|------|----------|--------------|
| Shock Trooper | AEGIS | 600+200sec | 280 | Medium | 39.3 (energy) | 49.1 | Elite infantry | Infantry, vehicles | AoE chemical/fire |
| Longbow Sniper | AEGIS | 500+300sec | 100 | Light | 44.4 (kinetic) | 22.2 | Precision/detector | High-value inf, spec ops | AoE, fast flankers |
| Tempest Artillery | AEGIS | 1800+300sec | 400 | Medium | 30.0 (kinetic) | 15.0 | Siege | Structures, static defense | Fast flankers, air |
| Paladin Heavy Tank | AEGIS | 2200+400sec | 1200 | Heavy | 48.0+20.0 (energy+explosive) | 60.0+15.0 | Frontline assault | Vehicles, structures | Concentrated explosives |
| Sentinel Gunship | AEGIS | 1800+400sec | 500 | Medium | **87.5** (energy, ground+air) | 109.4 | Air attack | Ground + air simultaneously | Massed AA |
| Thunderhawk Bomber | AEGIS | 2000+500sec | 600 | Medium | 33.3 (explosive, AoE 3.0) | 25.0 | Carpet bombing | Structures, vehicle groups | AA units |
| Valkyrie Transport | AEGIS | 1200+200sec | 450 | Medium | — (unarmed) | — | Air transport | Paradrop, flanks | AA units |
| Commander Aria | AEGIS | 3500+1500sec | 2000 | Heavy | 55.6 (energy) + orbital | 69.4 | Hero/command | Everything | Overwhelming focus fire |
| Chem Trooper | FORGE | 550+200sec | 180 | Medium | 37.5 (chemical, AoE 2.0) | 18.75 | Area infantry denial | Infantry clusters | Energy weapons, long range |
| Iron Fang Commando | FORGE | 700+250sec | 200 | Medium | 40.0 (kinetic) + 500 demo | — | Spec Ops sabotage | Structures (C4 800dmg) | Detectors, combat units |
| Basilisk Siege Tank | FORGE | 1600+200sec | 500 | Medium | 32.7 (explosive) | 24.5 | Siege | Structures, static units | Fast flankers, air |
| Juggernaut (Mammoth) | FORGE | 2500+500sec | 1500 | Heavy | 50.0+50.0 (explosive+kinetic) | 37.5+25.0 | Super-heavy brawler | All ground units | Concentrated air power |
| Vulture Strike Bomber | FORGE | 1800+400sec | 500 | Medium | 15.0 (chemical, AoE 3.5) + DoT | — | Chemical bombing | Infantry, structures | AA units |
| Mule Transport | FORGE | 1200+200sec | 450 | Medium | — (unarmed) | — | Air transport | Paradrop, flanks | AA units |
| Iron Fist (Kael) | FORGE | 3000+1200sec | 1800 | Heavy | 75.0+33.3 (fire+kinetic) | 18.75+22.2 | Hero/brawler | Infantry, vehicles in melee | Energy weapons, AEGIS Hero |

**T3 Notes:**
- **AEGIS Sentinel Gunship**: 87.5 raw DPS (energy, range 7, hits ground + air simultaneously). Highest sustained DPS of all T3 units. Only countered by massed AA or overwhelming numbers.
- **Commander Aria vs Iron Fist:** Aria costs more but has Orbital Strike (800 AoE, 90s CD), Shield Boost, Inspire, and detector. Iron Fist has Rally Cry (+30% speed/+15% damage) and Berserker Charge. Aria is better in defensive/tech games; Iron Fist is better leading aggressive ground pushes.
- **AEGIS Sniper**: 200 kinetic per shot (44.4 DPS), range 11, **detector**, cloaks when stationary. Unique intel/counter-stealth tool — no FORGE equivalent.
- **Basilisk vs Tempest Artillery:** FORGE Basilisk is cheaper (1600+200sec vs 1800+300sec), deploys faster (2.5s vs 3.0s), and deals more damage per shot (180 explosive vs 150 kinetic). Explosive vs medium = 1.0×, kinetic vs medium = 0.75×. FORGE siege is arguably strictly better. ⚠️ See FLAG-06.

---

## Faction Asymmetry Analysis

### AEGIS Advantages
- **Air superiority lock at T2:** Interceptor + AA Vehicle gives complete sky control; FORGE has no T2 air-to-air response
- **Defensive layering:** Shield Generator mechanic, Shock Trooper personal shields, Paladin's Overcharge Shields — stacking mitigation
- **Sustain:** Medic (T2) + Engineer repair = best battlefield attrition survivability; no FORGE equivalent
- **Detector coverage:** Sniper (T3) + Commander Aria (hero) — better at countering FORGE spec ops infiltration
- **Commander Hero (Aria):** Shield Boost + Inspire + Orbital Strike = dominant in tech-defense games
- **Artillery parity:** Tempest matches Basilisk range (16 vs 15); kinetic vs explosive is the key trade-off

### FORGE Advantages
- **Cost efficiency swarm:** Conscript 100cr, Attack Bike 200cr, Flametrooper 200cr — massive cost advantage in T1/early T2
- **Faster T1 pressure:** Attack Bike (7.5 speed) is 25% faster than Scout Buggy (6.0) and 40% faster than Rifleman (3.0)
- **AoE denial breadth:** Grenadier, Flametrooper, Toxin Truck, Strike Bomber, Chem Trooper — more area denial than AEGIS at every tier
- **Chemical niche:** Persistent toxic fields from Toxin Truck and Strike Bomber that AEGIS cannot currently cleanse
- **Iron Fist hero:** Rally Cry + Berserker Charge = superior army-wide ground brawl performance; cheaper than Aria
- **Mammoth Tank:** 1500 HP self-repairing super-heavy vs Paladin's 1200 HP (Paladin has shields, Mammoth has raw bulk)
- **Cheaper Siege:** Basilisk undercuts Tempest on cost and deployment speed with competitive (arguably superior) stats

### Risk / Dominant Patterns
- ⚠️ **FORGE early rush dominance:** Attack Bike + Conscript swarm in the first 2–3 minutes can overwhelm before AEGIS builds anti-vehicle options (Rocket Trooper is T2)
- ⚠️ **AEGIS T2 air gap for FORGE:** FORGE has zero air-to-air capability from T2 onward until Strike Bomber (T3). AEGIS Interceptors can roam freely for an entire tech tier.
- ⚠️ **Flametrooper cost-to-DPS imbalance:** 87.5 effective DPS at 200cr primary is the highest ratio in the game — potential to warp T2 infantry composition
- ⚠️ **AEGIS late game tech spike:** If FORGE cannot close before AEGIS reaches T3, Sentinel Gunship + Paladin + Commander Aria becomes extremely difficult to counter on the ground

---

## Known Balance Issues / Flags

1. **[FLAG-01] Flametrooper DPS/cost ratio** — At 200cr primary (no secondary), Flametrooper has 87.5 effective DPS vs light armor. The nearest AEGIS comparison (Rocket Trooper, 300cr) has 39.0 DPS vs light. Consider raising Flametrooper cost to 300cr primary, or reducing damage from 25 → 18 (~63 eff DPS vs light). **Playtest: 5 Flamers vs 5 Riflemen blobs, equal-cost fights.**

2. **[FLAG-02] FORGE has no T2 air-to-air counter** — AEGIS Interceptor can harass and scout freely throughout T2. FORGE's only aerial response is the T3 Strike Bomber (ground attack, not air-to-air). Consider adding limited AA capability to Rocket Buggy (targets: air) or a dedicated FORGE AA variant unit at T2. **Playtest: measure Interceptor impact in T2 matches with no FORGE counter.**

3. **[FLAG-03] Scout Buggy produced_at "aegis_barracks"** — A vehicle produced at barracks is architecturally inconsistent. If War Factory unlocks at T2, Scout Buggy needs a T1 production building. Either introduce a T1 vehicle bay structure for AEGIS or confirm barracks can produce light vehicles. **Design call needed before implementing production system.**

4. **[FLAG-04] FORGE T1 rush window** — Attack Bike (7.5 speed) reaches AEGIS base ~30% faster than any T1 AEGIS unit can intercept. AEGIS has no T1 anti-vehicle capability (Rocket Trooper is T2). Possible mitigations: add a cheap T1 bunker/barrier for AEGIS, or give Engineer a slow/snare ability. **Playtest: attack bike rush timing at 90s, 2min, 3min checkpoints.**

5. **[FLAG-05] Hero unit cost asymmetry** — AEGIS Commander Aria: 3500+1500sec. FORGE Iron Fist: 3000+1200sec. FORGE hero is 14% cheaper on primary and 20% cheaper on secondary, with competitive power (Rally Cry vs Inspire). Consider reducing Aria's secondary cost from 1500 → 1000, or buffing her base stats slightly. **Playtest: isolated hero 1v1 and army-with-hero fights.**

6. **[FLAG-06] Artillery (Basilisk vs Tempest) imbalance** — Forge Basilisk: 1600+200sec, 180 explosive dmg, range 15, 2.5s deploy. AEGIS Tempest: 1800+300sec, 150 kinetic dmg, range 16, 3.0s deploy. Basilisk is cheaper (+300cr+100sec cheaper), faster deploying (0.5s), and explosive vs medium = 1.0× while kinetic vs medium = 0.75×. FORGE siege is strictly superior on cost. **Consider:** raise Basilisk cost to 1800+300 to match, or increase Tempest damage to 175 kinetic.

7. **[FLAG-07] Toxin Truck DoT field — no AEGIS cleanse** — The Toxin Field ability (3-tile radius, 8 dmg/s for 10s) creates persistent area denial that AEGIS cannot purge. FORGE can indefinitely zone resource nodes and chokepoints with no counterplay. **Design call:** give AEGIS Engineer a "decontaminate" ability, or confirm this is intentional asymmetry.

8. **[FLAG-08] Medic has no FORGE counterpart** — AEGIS Medic (T2) heals 5 HP/s in a 3-tile aura, extending infantry blob lifespan significantly. FORGE has no healing unit at any tier. May be intentional (FORGE wins through aggression, not attrition) but creates a hard asymmetry in extended T2 fights. **Playtest: AEGIS infantry blob with 2 Medics vs equal-cost FORGE swarm.**

9. **[FLAG-09] YAML fix: aegis_artillery + aegis_heavy_tank produced_at** — Both units had `produced_at: "war_factory"` (invalid generic ID). Fixed to `"aegis_war_factory"` in this PR.

10. **[FLAG-10] Stale .json unit files removed** — The T2 data branch had duplicate `.json` versions of T1 unit files (`aegis_engineer.json`, `aegis_rifleman.json`, `forge_conscript.json`, etc.). These were stale artifacts and have been deleted. YAML files are canonical per the schema spec.
