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
- Explosive is the universal solvent — decent vs everything, great vs buildings and light
- Energy is the anti-heavy specialist — worst vs light, best vs heavy
- Chemical/Fire excel vs light armor (infantry), but fall off sharply vs heavy/buildings
- Kinetic is reliable vs light but severely penalized vs heavy and buildings

---

## T1 Unit Comparison

| Unit | Faction | Cost | HP | Armor | DPS (raw) | Effective DPS vs Light | Effective DPS vs Heavy | Role | Counters | Countered By |
|------|---------|------|-----|-------|-----------|----------------------|----------------------|------|----------|--------------|
| Rifleman | AEGIS | 150 | 120 | Light | 15.0 (kinetic) | 15.0 | 7.5 | Combat infantry | Forge Conscript (1v1) | Fire weapons, AoE explosives |
| Engineer | AEGIS | 200 | 80 | Light | 4.2 (kinetic) | 4.2 | 2.1 | Support/repair | — (utility) | Any combat unit |
| Harvester | AEGIS | 600 | 400 | Heavy | — (unarmed) | — | — | Economy | — | Any combat unit |
| Scout Buggy | AEGIS | 250 | 150 | Light | 16.0 (kinetic) | 16.0 | 8.0 | Recon/harassment | Slow infantry | Forge Attack Bike |
| Conscript | FORGE | 100 | 85 | Light | 10.0 (kinetic) | 10.0 | 5.0 | Cheap swarm | Economy pressure | AEGIS Rifleman (1v1) |
| Saboteur | FORGE | 250 | 90 | Light | 15.0 (explosive) | 22.5 | 11.3 | Spec Ops/demo | Structures, vehicles | Scout Buggy, massed Riflemen |
| Harvester | FORGE | 600 | 400 | Heavy | — (unarmed) | — | — | Economy | — | Any combat unit |
| Attack Bike | FORGE | 200 | 100 | Light | 12.5 (explosive) | 18.75 | 9.4 | Fast raider | Harvesters, scouts | Massed Riflemen, turrets |

**T1 Notes:**
- Rifleman (150) vs Conscript (100): Rifleman wins 1v1 (15 DPS, 120 HP vs 10 DPS, 85 HP). But 3 Conscripts (300) handily beat 2 Riflemen (300). FORGE gets better cost efficiency in swarms.
- Attack Bike is the fastest T1 unit (7.5 speed) and has explosive damage — excellent harasser.
- Scout Buggy has exceptional vision range (12 tiles), unique among T1.
- Saboteur's Plant C4 ability (200 structure damage, 30s CD) is potentially powerful for structure snipes even at T1.

---

## T2 Unit Comparison

| Unit | Faction | Cost | HP | Armor | DPS (raw) | Effective DPS vs Light | Effective DPS vs Heavy | Role | Counters | Countered By |
|------|---------|------|-----|-------|-----------|----------------------|----------------------|------|----------|--------------|
| Medic | AEGIS | 250+50sec | 90 | Light | — (no weapon) | — | — | Support healer | Attrition (sustains blob) | Any combat unit |
| Rocket Trooper | AEGIS | 300 | 100 | Light | 26.0 (explosive) | 39.0 | 19.5 | Anti-vehicle inf | Vehicles, tanks | Snipers, Interceptors |
| APC | AEGIS | 500 | 300 | Medium | 25.0 (kinetic) | 25.0 | 12.5 | Transport/screen | Infantry positioning | Rocket Trooper, Battle Tank |
| Medium Tank | AEGIS | 800 | 450 | Heavy | 42.5 (kinetic) | 42.5 | 21.3 | Main battle tank | Light vehicles, infantry, structures | Rocket Trooper, explosive units |
| AA Vehicle (Skyguard) | AEGIS | 600+100sec | 250 | Medium | 40.0 (energy) | 30.0 | 50.0 (vs air med) | Anti-air | All air units | Ground units (can't shoot ground) |
| Interceptor | AEGIS | 700+150sec | 180 | Medium | 37.5 (energy) | 28.1 | 46.9 | Air superiority | Helicopters, enemy air | AA Vehicle, Skyguard |
| Grenadier | FORGE | 250 | 110 | Medium | 20.0 (explosive, AoE 2.0) | 30.0 | 15.0 | AoE anti-infantry | Infantry blobs, light vehicles | Snipers, long-range units |
| Flametrooper | FORGE | 200 | 100 | Light | 50.0 (fire, AoE 1.5) | 87.5 | 12.5 | Close-range AoE | Infantry, buildings | Long-range units, tanks |
| Battle Tank (Crusher) | FORGE | 700 | 400 | Heavy | 41.7 (kinetic) | 41.7 | 20.8 | Main battle tank | Light vehicles, infantry, structures | Rocket Trooper, explosive units |
| Rocket Buggy | FORGE | 450+50sec | 180 | Light | 22.0 (explosive) | 33.0 | 16.5 | Fast anti-vehicle | Tanks, heavy vehicles | Interceptors, infantry |
| Toxin Truck | FORGE | 550+100sec | 280 | Medium | 13.3 (chemical, AoE 3.0) | 20.0 | 6.7 | Area denial/DoT | Infantry, defensive positions | Snipers, long-range vehicles |
| Helicopter (Havoc) | FORGE | 650+100sec | 220 | Medium | 25.0 (explosive, AoE 1.5) | 37.5 | 18.75 | Air gunship | Ground vehicles, structures | Interceptor, AA Vehicle |

**T2 Notes:**
- AEGIS gets dedicated Medic (no FORGE equivalent at T2) — significant sustain advantage in infantry fights
- Flametrooper is an outlier: 50 raw DPS, ×1.75 vs light = **87.5 effective DPS** at 200 cost — highest DPS/cost at T2; countered by range but can devastate blob infantry before dying
- FORGE has NO dedicated air-to-air counter at T2. Helicopter vs Interceptor: Helicopter only targets ground. AEGIS can freely air-scout and Interceptor dominates air unopposed.
- Rocket Buggy (450+50sec) is excellent value vs tanks; fast enough to kite medium tanks
- AEGIS Medium Tank vs FORGE Battle Tank: AEGIS 42.5 DPS, 450 HP, costs 800. FORGE 41.7 DPS, 400 HP, costs 700. FORGE tank is 12.5% cheaper for roughly equal performance — slight FORGE edge

---

## T3 Unit Comparison

| Unit | Faction | Cost | HP | Armor | DPS (raw) | Effective DPS vs Heavy | Role | Counters | Countered By |
|------|---------|------|-----|-------|-----------|----------------------|------|----------|--------------|
| Shock Trooper | AEGIS | 600+200sec | 280 | Medium | 39.3 (energy) | 49.1 | Elite infantry | Infantry, vehicles | AoE chemical/fire |
| Sniper | AEGIS | 500+300sec | 100 | Light | 44.4 (kinetic) | 22.2 | Precision/detector | High-value inf/vehicles | AoE, fast flankers |
| Artillery (Tempest) | AEGIS | 1800+300sec | 400 | Medium | 30.0 (kinetic) | 15.0 | Siege | Structures, static defense | Fast flankers, air |
| Heavy Tank (Paladin) | AEGIS | 2200+400sec | 1200 | Heavy | 48.0+20.0 (energy+explosive) | 60.0+15.0 | Frontline tank | Vehicles, structures | Lots of explosives |
| Gunship (Sentinel) | AEGIS | 1800+400sec | 500 | Medium | 87.5 (energy) | 109.4 | Air attack | Ground+air | Massed AA, Interceptors |
| Bomber (Thunderhawk) | AEGIS | 2000+500sec | 600 | Medium | 33.3 (explosive, AoE 3.0) | 25.0 | Bombing run | Structures, vehicle groups | AA units |
| Transport (Valkyrie) | AEGIS | 1200+200sec | 450 | Medium | — (unarmed) | — | Air transport | Flanks, paradrop | AA units |
| Commander Unit (Aria) | AEGIS | 3500+1500sec | 2000 | Heavy | 55.6 (energy) + orbital | 69.4 | Hero/command | Everything | Overwhelming focus fire |
| Chem Trooper | FORGE | 550+200sec | 180 | Medium | 37.5 (chemical, AoE 2.0) | 18.75 | Area infantry denial | Infantry | Energy weapons, long range |
| Commando | FORGE | 700+250sec | 200 | Medium | 40.0 (kinetic) + 500 demo | — | Spec Ops sabotage | Structures (C4 800dmg) | Detectors, combat units |
| Siege Tank (Basilisk) | FORGE | 1600+200sec | 500 | Medium | 32.7 (explosive) | 24.5 | Siege | Structures, static | Fast flankers, air |
| Mammoth Tank (Juggernaut) | FORGE | 2500+500sec | 1500 | Heavy | 50.0+50.0 (explosive+kinetic) | 37.5+25.0 | Super-heavy | Everything on the ground | Overwhelming air power |
| Strike Bomber (Vulture) | FORGE | 1800+400sec | 500 | Medium | 15.0 (chemical, AoE 3.5) + DoT | — | Chemical bombing | Infantry clusters, structures | AA units |
| Transport (Mule) | FORGE | 1200+200sec | 450 | Medium | — (unarmed) | — | Air transport | Flanks, paradrop | AA units |
| Iron Fist (Warlord Kael) | FORGE | 3000+1200sec | 1800 | Heavy | 75.0+33.3 (fire+kinetic) | 18.75+22.2 | Hero/brawler | Infantry, vehicles | Energy weapons, AEGIS Hero |

**T3 Notes:**
- AEGIS Gunship: 87.5 raw DPS (energy, hits ground+air) — highest sustained DPS of any T3 unit; only countered by massed AA
- FORGE Mammoth Tank: Dual weapons, self-repair — strongest ground bruiser but countered by AEGIS air dominance
- AEGIS Commander Unit has Orbital Strike (800 dmg, 4-tile radius, 90s CD) — massive zoning tool
- FORGE Iron Fist has Rally Cry (+30% speed, +15% damage, 8-tile AoE) — transforms army fights
- AEGIS Sniper has detector + 200 kinetic damage per shot (44.4 raw DPS, range 11, cloaks when stationary) — unique intel tool
- FORGE Strike Bomber drops chemical with persistent DoT field — uniquely counters turtling

---

## Faction Asymmetry Analysis

### AEGIS Advantages
- **Air superiority at T2**: Interceptor + AA Vehicle give total sky control; FORGE has no T2 air-to-air
- **Defensive tools**: Shield Generator (structure mechanic), Shock Trooper personal shields, Paladin's Overcharge Shields — layers of defensive mitigation
- **Sustain**: Medic (T2, no FORGE equiv) + Engineer repair = best battlefield sustain
- **Detector units**: Sniper (T3) + engineer vision — better at spotting stealth
- **Commander Hero (Aria)**: Shield Boost + Inspire + Orbital Strike = dominant hero in late game
- **Siege parity**: Tempest Artillery matches Basilisk range (16 vs 15 tiles); AEGIS deploys faster (3s vs 2.5s but higher damage)

### FORGE Advantages
- **Cost efficiency at T1-T2**: Conscript 100cr, Attack Bike 200cr — FORGE can swarm economically
- **Early aggression**: Attack Bike (7.5 speed, explosive) is the fastest T1 unit by far; can harass harvesters before AEGIS stabilizes
- **AoE pressure**: Grenadier, Flametrooper, Toxin Truck, Strike Bomber — more area denial tools
- **Flametrooper value**: 200cr for 87.5 effective DPS vs light is oppressive cost efficiency
- **Iron Fist Hero**: Rally Cry + Berserker Charge = better at winning massed ground brawls
- **Mammoth Tank**: 1500 HP self-repairing heavy vs Paladin's 1200 HP (but Paladin has shields)
- **Chemical niche**: Strike Bomber + Chem Trooper create persistent zone denial AEGIS cannot replicate

### Risk / Dominant Patterns
- ⚠️ **FORGE early rush is strong**: Attack Bike + Conscript swarm at minute 1-3 can overwhelm before AEGIS builds anti-vehicle options
- ⚠️ **AEGIS air gap**: FORGE has NO dedicated air-to-air at T2; Interceptors can roam freely until T3 Strike Bomber
- ⚠️ **Flametrooper cost-efficiency**: 200cr for ~87.5 DPS vs light may be too efficient in early T2; needs stress-testing vs Rifleman blobs
- ⚠️ **AEGIS late game tech spike**: If FORGE can't close out by T3, AEGIS Gunship + Paladin + Commander Aria becomes very difficult to counter

---

## Known Balance Issues / Flags

1. **[FLAG-01] Flametrooper DPS/cost ratio** — At 200cr primary (no secondary), Flametrooper has 87.5 effective DPS vs light armor. Nearest AEGIS comparison (Rocket Trooper, 300cr) has 39.0 DPS vs light. Consider raising Flametrooper cost to 300cr primary, or reducing damage from 25 to 18 (would yield ~63 effective DPS vs light). **Playtest: send 5 Flamers into 5 Riflemen blobs.**

2. **[FLAG-02] FORGE has no T2 air-to-air counter** — AEGIS Interceptor can harass freely in T2. FORGE only gets Strike Bomber at T3. Consider adding a limited AA capability to Rocket Buggy (targets: air) or creating a FORGE AA variant unit. **Playtest: how impactful is 2x Interceptors in a T2 game without FORGE AA?**

3. **[FLAG-03] AEGIS Scout Buggy produced_at "aegis_barracks"** — This vehicle coming from barracks is odd. If War Factory is T2, Scout Buggy needs a T1 production building. Either this is intentional design or it needs its own `aegis_vehicle_bay` T1 structure. **Design call needed.**

4. **[FLAG-04] FORGE early rush window** — Attack Bike (7.5 speed) reaches AEGIS base ~30% faster than any T1 AEGIS unit can react. First 3 minutes are highly favorable FORGE. AEGIS has no T1 dedicated anti-vehicle (only Rocket Trooper at T2). Possible mitigations: give AEGIS Engineer a repair-snare ability, or add a cheap T1 barrier/bunker option for AEGIS. **Playtest: rush pressure timeline at 90s, 2min, 3min.**

5. **[FLAG-05] Hero unit cost asymmetry** — AEGIS Commander Aria: 3500+1500sec. FORGE Iron Fist: 3000+1200sec. FORGE hero is cheaper AND has competitive power (Rally Cry vs Inspire). Aria's Orbital Strike is strong but on a 90s cooldown. Consider reducing Aria's secondary cost from 1500 to 1000, or reducing Iron Fist's health from 1800 to 1600. **Playtest: 1v1 hero matchup in isolation.**

6. **[FLAG-06] Artillery siege timer asymmetry** — AEGIS Tempest Artillery deploys in 3.0s and has 150 kinetic damage. FORGE Basilisk deploys in 2.5s with 180 explosive damage. FORGE siege unit is cheaper (1600 vs 1800), faster to deploy, and deals more damage per shot with explosive (better vs buildings). AEGIS secondary cost of +300 vs FORGE +200 makes this gap more pronounced. **Consider:** raise Basilisk cost to 1800+300 to match Tempest, or increase Tempest damage to 175.

7. **[FLAG-07] Toxin Truck DoT field vs no AEGIS counter** — The Toxin Field ability (3-tile radius, 8 damage/s for 10s) creates persistent area denial that AEGIS cannot purge (no AoE cleanse ability exists). FORGE can zone resource nodes indefinitely. **Design call:** should AEGIS Engineer have a "decontaminate" ability, or is this an intentional FORGE niche?

8. **[FLAG-08] Duplicate .json files removed** — The T2 data branch had duplicate `.json` versions of T1 unit files (aegis_engineer.json, aegis_rifleman.json, etc.). These were stale artifacts and have been deleted from this branch. No content loss — YAML files are canonical.

9. **[FLAG-09] aegis_artillery + aegis_heavy_tank produced_at field** — Both had `produced_at: "war_factory"` (generic, invalid ID). Fixed to `"aegis_war_factory"` in this PR.

10. **[FLAG-10] Medic has no FORGE counterpart** — AEGIS Medic (T2) provides passive heal-aura that significantly extends infantry blob lifespan. FORGE has no healing unit at any tier (Iron Fist self-sustains, Mammoth Tank self-repairs, but no battlefield medic). This may be intentional asymmetry (FORGE wins through aggression before attrition matters) but worth confirming in extended fights. **Playtest: AEGIS infantry blob with 2 Medics vs same-cost FORGE swarm.**
