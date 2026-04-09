# World Astrobiology — The Farhaven System

**Status:** Approved worldbuilding foundation
**Created:** 2026-04-09
**Authors:** Andre Vianna (concept + physics direction) + Lola (physics validation + documentation)

---

## The System

```
Star: Type G/K (Sun-like, slightly cooler)
  │
  └── Binary Pair (Pluto-Charon analog, ~1 AU from star)
        │
        ├── Super-Earth ("The Motherworld")
        │   Mass: ~2 M_Earth
        │   Radius: ~7,500 km (1.18 R_Earth)
        │   Surface gravity: ~1.1-1.2g
        │   Origin of the ancient alien civilization
        │
        └── The Moon ("Farhaven" — the game world)
            Mass: ~0.5 M_Earth
            Radius: ~5,000 km
            Surface gravity: ~0.8g
            Rocky, dense, geologically active (tidal heating)
            Tidally locked to the Super-Earth
            
Orbital separation: ~57,000 km center-to-center
Orbital period: ~24h (both tidally locked)
Barycenter: ~11,400 km from Super-Earth center
           = ~3,900 km above Super-Earth surface (in space)
           → True binary system, not planet-moon
```

## Physics Validation

### Orbital mechanics
- **Kepler's law confirms:** a binary of ~2.5 M_Earth total at ~57,000 km separation gives a ~24h orbital period. ✓
- **Roche limit safe:** rocky body Roche limit ~9,500 km. Separation is 57,000 km. No tidal disruption. ✓
- **Tidal locking plausible:** at 57,000 km with these masses, tidal locking timescale is geologically short. Both bodies locked. ✓
- **Barycenter in space:** with mass ratio ~4:1 (2.0 vs 0.5 M_Earth), barycenter is ~3,900 km above the Super-Earth's surface. This is a binary, not a traditional planet-moon. ✓

### Atmosphere and habitability
- 0.8g can retain a substantial atmosphere (Mars lost its atmosphere at 0.38g — 0.8g is much more secure)
- Tidal heating from the close binary provides geological energy (volcanism, hot springs, geothermal vents)
- The star's habitable zone determines surface temperature — standard G/K star at ~1 AU works
- Magnetic field plausible from a dense, geologically active body with a liquid iron core (tidal heating helps maintain core convection)

### Day/night from the far side
- Tidally locked: rotation period = orbital period = ~24h
- From the anti-planet hemisphere: the star rises and sets every 24h, identical to a normal planet
- No visible companion in the sky — player has no reason to suspect they're on a moon
- Only clues: 0.8g (subtle), unusual flora/fauna, alien artifacts

---

## Progressive Revelation — The Narrative Arc

### Act 1: The Far Side (Familiar)

**Player experience:** Everything feels normal. Crash landing. Day and night. Gravity close enough. Flora and fauna are alien but recognizable. Standard survival gameplay.

**What the player thinks:** "I crashed on a planet."

**Gameplay:** Chapters 1-2. Basic survival, crafting, building, scanning. Anomalies are mysterious but sparse. Fauna is nocturnal. The world is manageable.

**Lighting:** Clean sunrise/sunset cycle. No eclipses. Dark nights with player torch.

**Biomes:** Crash Site (center), Grassland, Forest, Rocky. Earth-analog vegetation adapted to 0.8g (taller, thinner structures — trees can grow taller with less gravity).

### Act 2: The Journey to the Horizon

**Trigger:** Player explores far enough from crash site, following anomaly breadcrumbs that increase in density toward the terminator zone.

**Progressive changes as player moves toward the planet-facing hemisphere:**

1. **Nights get brighter** — planet-shine (reflected starlight from the Super-Earth) creates ambient light on the near side. The closer to the terminator, the more noticeable.

2. **Anomalies increase** — alien artifacts become more frequent and complex. The civilization came from the planet direction.

3. **Geology changes** — tidal heating is strongest on the near side. More volcanic terrain, hot springs, crystal formations, geothermal vents. New biomes emerge.

4. **Flora changes** — plants adapted to planet-shine have different photosynthesis. Bioluminescence increases (evolved for the eclipse-dark periods).

5. **THE MOMENT** — the Super-Earth appears over the horizon.

**The "I Am Not In Kansas" Moment:**

The Super-Earth at 57,000 km subtends ~15° of arc — **30 times the apparent size of our Moon.** It rises slowly over the horizon as the player crests a ridge or hill. A massive, rocky, cloud-banded world dominating the sky.

This is a natural cutscene trigger. The most important `EVENT` in the game. The player understands: this is not a planet. This is a moon. And that thing in the sky is where they're really orbiting.

**Cutscene:** AI-generated cinematic showing the player character staring up at the Super-Earth. Camera pulls back to reveal the binary system from space. Music shifts. The game's title appears again — recontextualized.

### Act 3: The Near Side

**Player experience:** A different world. Same moon, but everything is affected by the Super-Earth's presence.

**Lighting changes:**
- **Planet-shine at night:** the Super-Earth reflects starlight back. Nights on the near side are never truly dark. Ambient luminosity changes gameplay — fauna behavior different, torch less critical, but NEW dangers emerge in the dim light.
- **Daily eclipses:** once per 24h cycle, the Super-Earth passes between the star and the moon. Brief period (10-20 minutes depending on geometry) of deep shadow during what should be daytime. The "Deep Eclipse" — sudden darkness in the middle of the day.
- **Eclipse gameplay:** fauna that normally only comes at night becomes active during the Deep Eclipse. Structures built for nighttime defense needed during the day too.

**Biomes:** Volcanic, Crystal Caverns, Geothermal Plains, Tidal Flats (near coast areas affected by extreme tides from the Super-Earth's gravity). Alien ruins become architectural — not just beacons but buildings, roads, infrastructure.

**Narrative:** The alien civilization colonized this moon from the Super-Earth. The beacons are navigation/communication devices. The ruins tell a story — why did they leave? (Or did they?)

### Act 4: The Ship / The Super-Earth

**Trigger:** Player finds their crashed ship in orbit (or repairs it), or discovers an alien vessel.

**The Super-Earth:**
- Surface gravity: 1.1-1.2g — player moves slower, jumps lower, everything feels heavier
- Atmosphere: denser, maybe different composition (breathable but with effects)
- Flora/fauna: completely alien — this is where the native biology evolved
- Technology: advanced alien civilization remnants — cities, machines, archives
- The revelation: the "ancient aliens" of the moon ARE from here. The moon was their colony/outpost.

**Gameplay:** new movement mechanics (heavier gravity), new crafting recipes (alien materials), new threats (native fauna evolved at 1.2g — stronger, tougher). The survival skills from the moon transfer but the rules change.

---

## Engine Implications

| Feature | Mechanism | When |
|---------|-----------|------|
| 0.8g movement | Gravity multiplier on Player movement + jump | delivery-005b (subtle, barely noticeable at first) |
| Planet-shine | Global ambient light modifier per chapter/zone | delivery-006+ |
| Super-Earth in sky | Skybox/billboard that grows as player moves toward near side | delivery-006+ |
| Deep Eclipse | DayNightCycle sub-phase triggered by player zone | delivery-006+ |
| Planet-shine fauna | Fauna config per zone (active in dim light, not just darkness) | delivery-006+ |
| Gravity change on Super-Earth | Movement speed/jump height modifier per chapter | Far future |
| Different biomes near/far | Already supported by biome system — just new biome .tres files | delivery-006+ |

**What already works:**
- Hex grid supports any biome arrangement — hemispheric zones are just map design
- LightingManager can handle planet-shine as an additional global light source
- DayNightCycle phases can be extended with eclipse sub-phases
- EVENT recipes can trigger the Kansas Moment cutscene
- The biome system is data-driven — new biomes = new .tres files

**What needs new systems:**
- Skybox rendering (Super-Earth in the sky — grows with player position)
- Zone-based environmental modifiers (gravity, ambient light, fauna rules)
- Orbital ship / planet transition (major — likely a separate game mode)

---

## Biological Compatibility — DECIDED

**Chemistry is universal. RNA/DNA is universal.** (Andre's call, 2026-04-09)

Proteins are analogous across both worlds. Some things are edible, some are toxic — the scanner detects compatibility. This isn't coincidence or terraforming — it's the natural consequence of universal biochemistry. Carbon-based, water-solvent, nucleic-acid-coded life converges across any world with similar conditions.

The gameplay mechanic (scan to discover edible vs toxic) is the in-game expression of this principle: the player's scanner analyzes molecular compatibility, not "alien vs familiar."

---

## The Ancient Civilization — DECIDED

**Origin:** Super-Earth natives. Evolved at 1.1-1.2g — physically stocky, dense-boned, strong.

**Technology level:** Comparable to Earth's 20th century. Rockets, radio, nuclear power. NOT hyper-advanced — recognizable to the player. "That's a radio." "That's a motor."

**Extinction:** Nuclear war, tens of thousands of years before the player arrives. Self-destruction — the universal tragedy. Ruins are eroded but identifiable. Radiological contamination persists in some zones (gameplay: radiation hazard areas, especially on Super-Earth).

**Inter-body travel:** Trivially achievable with their tech level:
- Only 57,000 km separation (vs Earth-Moon 384,000 km = 6.7× closer)
- Barycenter in space = lower delta-v for orbital transfers
- Moon's 0.8g = easier to escape than Earth's 1.0g
- Chemical rockets sufficient for regular shuttle service
- Settlements on BOTH bodies — the moon was not just a base, it was a colony with permanent population

**What the player finds:**
- Act 1 (far side): scattered beacons — automated navigation/communication relays, solar-powered, still operational after millennia because they were built to last
- Act 2 (terminator): larger structures — research stations, mining operations, supply depots for the inter-body shuttle route
- Act 3 (near side): architectural ruins — residential districts, cultural centers, the spaceport that connected the two worlds
- Act 4 (Super-Earth): the civilization's homeland — cities (ruined), archives (partially intact), impact craters from the war, radiation zones, the answer to "what happened"

**The narrative irony:** A civilization with TWO worlds destroyed itself. The player, a lone human crash-landed on the remains, has to survive using what they left behind. The beacons still transmit to a civilization that no longer listens.

**The beacons still work because:** automated systems running on solar/geothermal power. Simple, robust, designed for millennia of unattended operation. Like Voyager probes — built once, run forever. Nobody turned them off because nobody was left to.

---

*This document is worldbuilding foundation. It feeds into the GDD, chapter design, biome creation, narrative writing, and cutscene prompts. It should be kept in sync with gameplay decisions.*
