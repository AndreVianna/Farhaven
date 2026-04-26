# Fauna Spec — Farhaven

**Status:** Draft v4 — A0021 reduced-pair pass (Andre / 2026-04-26)
**Author:** Architect (Lola)
**Purpose:** Worldbuilding + technical foundation for the animal system. No code yet. All decisions citeable against the existing codebase.

**v2 changelog:** Added 2 biwing quadrupeds (A0023 Fan-Mantled Pacer, A0024 Cliff-Drop Pouncer); reworked A0022 Carrion Mound to a single-creature, one-per-corpse decomposer (no swarm/patch); swept microfauna wording (A0017 plankton → suspended algae; minor diet copy elsewhere); sharpened A0021 outlier lore (pre-bottleneck relict lineage).

**v3 changelog:** Reframed the six-limb body plan as the planet's *early/foundational* layout, not the result of a later "hexapod radiation" — it goes deep enough that even fish carry three pairs of lateral fins (pectoral, abdominal, pelvic). Removed all "mammal-analogue" language since the spec doesn't commit to mammal-grade biology (no claim about milk/lactation). Megafauna fur is reframed as the "non-plumed, non-scaled" coat — fur because the lineage isn't reptile-equivalent, not because of cold (think Earth giraffe / Megatherium / Lestodon: short hair on warm-climate megafauna). Reworked A0021 outlier story to drop the "displaced by hexapods" framing.

**v4 changelog:** A0021 Ash-Coat Pacer is no longer a true 4-limb outlier. The third pair of limbs hasn't disappeared — it's regressed into two small grasping appendages flanking the mouth, used for handling food before chewing (Andre's call). Net effect: 24 of 24 species now comply with the six-limb plan, and A0021 illustrates the plan flexing rather than breaking. Updated master table limbs column, §3.2 limb tally (added "reduced pair" body-plan row, removed the outlier row), §3.3 long-form description, §4.1 trophic chart (A0021 placed under primary consumers), §4.1 footer note (re-titled "Reduced-pair lineage").

---

## 0. Premise (one paragraph)

Farhaven life evolved on a world where the foundational body plan is **six-limbed**, not four. The pattern goes deep — three paired appendages is the layout that took hold early in the planet's evolutionary history, before the major lineages split. Even fish in Farhaven's oceans and rivers carry three pairs of lateral fins (pectoral, abdominal, pelvic), and the terrestrial radiations that followed inherited the same layout. Reptile-grade lineages on this world stayed small and convergently grew plumage instead of keeping scales. The largest land creatures are covered in fur — not because they need insulation, but because their lineage simply isn't reptile-equivalent (think Earth's giraffe, Megatherium, or Lestodon: short hair on warm-climate megafauna). The spec stops short of committing to mammal-grade biology — no firm claims about lactation, no mammals proper — but the visual / textural distinction holds: scaled or plumed for the reptile-equivalent line, fur or hide for everything large. Most life sits between rat and elephant×2 in size — no insects, no microfauna, no kaiju. The current code (`scripts/fauna/fauna_manager.gd`) treats fauna as cheap dictionaries spawned at night and despawned at dawn around a single placeholder species `P00108`. This spec scopes the leap from one placeholder to a populated, biome-coherent ecosystem of ~24 species the player can scan, fight, eat, flee, and (eventually) tame.

---

## 1. World rules (locked)

These are non-negotiable. Every species must comply or be flagged as an outlier.

| Rule | Specifics |
|------|-----------|
| **Six-limb dominance** | Default body plan is six limbs (three paired appendages), inherited from very early in the planet's evolutionary history. Variants: 6 legs (hexapods), 4 wings + 2 legs, 2 wings + 4 legs, 6 mixed-use (climber/grasper), or 4 + 2 reduced (one pair regressed into a vestige with a niche role — A0021's mouth-graspers). Fish carry the same plan as 3 pairs of lateral fins (pectoral, abdominal, pelvic). True 4-limb forms (no third pair at all) are not authored in this spec. |
| **No giant reptiles** | The "scaly" lineage on Farhaven stayed small and convergently grew plumage. No T-rex analogues. Largest "reptile-like" creature: dog-sized. |
| **Furry megafauna** | Animals over Large size (>2.5 m) are typically fur-covered. Fur here means "not scaled and not plumed" — it's the coat type for the non-reptile lineage, not an adaptation to cold. Earth analogues: giraffe (short hair, warm climate), Megatherium / Lestodon (long hair, also warm climate). The spec does not commit to mammal-grade biology. |
| **Size band** | Smallest ~0.2 m body length (rat scale). Largest ~10 m tall / 15 m long (~2× elephant). No insects, no whales. |
| **Biome scope** | All biomes get life **except Volcanic** (`B00006`). Crash Site, Grassland, Forest, Rocky, Water, Alpine, Shoreline, River, Coastal Rocks. |
| **Reptile alt-name** | Use **"plumed"** rather than "feathered" in flavour text — distinguishes the scaly-lineage convergence from the bird-equivalent (which doesn't exist; aerial niches are filled by tetrawing pterosaur-analogues with leathery skin). |

---

## 2. Naming conventions

- **Species ID:** `A0001` … `A9999`. Padded to 4 digits. Animals get a separate namespace from props (`P00001`+). The CHAPTER1_SPECIES constant currently uses `P00108` (`scripts/fauna/fauna_manager.gd:24`); the migration is discussed in §6.1.
- **Display names:** Two-word evocative compounds. Texture/material/behaviour first, body-plan second when needed. Avoid Earth species names (no "deer", no "wolf"). Acceptable patterns:
  - `<Material> <Form>` — *Glasswing Strider*, *Tide-Mantled Hexapod*
  - `<Behaviour> <Form>` — *Dawn-Calling Quadbeak*, *Burrow-Mother*
  - `<Place> <Form>` — *Shoreline Skimmer*, *Alpine Mantle*
- **Tone match:** The biome long_descriptions in `data/biomes/*.tres` are sparse, observational, slightly forensic ("Drinkable, swimmable, impassable until you build a way across"). Match that tone in fauna descriptions — not flowery, not heroic. The player is a survivor cataloguing what's around them.
- **Limb count is a flavour gift.** Mention it in the long_description when it matters ("The forelegs are slim and used for grasping; the four hind legs do the running").

---

## 3. Species Roster (24 species)

Roster is sized for variety without sprawl. Fourteen land creatures (including two biwing quadrupeds), five aquatic, four aerial-dominant, one decomposer.

### 3.1 Master table

| ID    | Name                  | Size      | Body length | Limbs                         | Covering          | Locomotion (1°/2°)  | Diet              | Temperament    | Day/Night    | Primary biomes               | Player role            |
|-------|-----------------------|-----------|-------------|-------------------------------|-------------------|---------------------|-------------------|----------------|--------------|------------------------------|------------------------|
| A0001 | Dryweed Grazer        | Small     | 0.7 m       | 6 walking legs                | Short fur         | walk / sprint       | grazer (P00001 Blade Grass, P01001) | skittish         | diurnal      | Grassland (B00002)           | meat/hide harvest      |
| A0002 | Six-Step Strider      | Medium    | 1.6 m       | 6 walking legs                | Short fur         | walk / sprint       | browser (P00021 Canopy leaves, low ferns) | skittish, herd defensive | crepuscular | Grassland, Shoreline | meat, bone, sinew      |
| A0003 | Mantled Burrower      | Small     | 0.6 m       | 6 (4 dig + 2 push)            | Coarse fur        | burrow / walk       | omnivore (roots, small fauna) | territorial    | nocturnal    | Grassland, Shoreline (B00008)| navigation hazard, fur |
| A0004 | Plumed Stalker        | Small     | 0.9 m       | 6 walking legs                | Plumage (down)    | walk / sprint       | carnivore (small fauna) | aggressive, ambush | crepuscular | Forest (B00003)              | early threat, plume    |
| A0005 | Glasswing Strider     | Tiny      | 0.3 m       | 4 wings + 2 legs              | Iridescent skin   | fly / glide         | nectar/pollen-analogue   | peaceful       | diurnal      | Grassland, Forest, Shoreline | lore, dye source       |
| A0006 | Lantern-Belly Glider  | Small     | 0.5 m       | 4 wings + 2 legs              | Plumage           | glide / climb       | piscivore (river fish)   | skittish       | crepuscular  | River (B00009), Forest edge  | bioluminescent navigation aid |
| A0007 | Quadbeak Caller       | Medium    | 1.2 m       | 4 wings + 2 legs              | Plumage           | fly / walk          | omnivore (carrion, fruit)| aggressive when grouped | diurnal | Rocky (B00004), Coastal Rocks (B00010) | scavenger, raid threat |
| A0008 | Stone-Mantle Hexapod  | Large     | 3.2 m       | 6 walking legs                | Hide + dorsal plates | walk             | grazer (lichen, dryweed) | territorial    | cathemeral   | Rocky, Alpine (B00007) edge  | tank prey, plate armor |
| A0009 | Snow-Mantle Behemoth  | Huge      | 7 m / 4 m tall | 6 walking legs            | Long shaggy fur   | walk                | browser (alpine moss, bark) | peaceful unless cornered | diurnal | Alpine                      | endgame megafauna, fur |
| A0010 | Glacier Stalker       | Large     | 3.5 m       | 6 walking legs                | Dense fur         | walk / climb        | carnivore (Snow-Mantle calves, Stone-Mantle) | predatory, pack | nocturnal | Alpine, Rocky border        | apex predator, fur     |
| A0011 | Brachi-Climber        | Medium    | 1.5 m       | 6 (alternating climb/grasp)   | Short fur + bare hands | climb / walk    | omnivore (fruit, eggs, small fauna) | territorial, vocal | diurnal | Forest                      | tree-canopy threat     |
| A0012 | Forest Floor Shuffler | Small     | 0.6 m       | 6 walking legs                | Plumage           | walk / burrow       | detritivore + fungivore   | peaceful       | nocturnal    | Forest, Shoreline            | catalog flavour, eggs  |
| A0013 | Tide-Mantled Hexapod  | Medium    | 1.8 m       | 6 (4 walk + 2 paddle)         | Smooth scaled hide| walk / swim         | filter-feeder + scavenger | skittish       | cathemeral   | Shoreline, Coastal Rocks, Water shallows | shell, hide |
| A0014 | Reef Six-Limb         | Small     | 0.8 m       | 6 (4 walk + 2 paddle)         | Smooth shell      | swim / walk         | grazer (algae)            | peaceful       | diurnal      | Coastal Rocks, Water        | meat, shell crafting   |
| A0015 | Bladefin Hunter       | Medium    | 2.0 m       | 6 fins                        | Smooth skin       | swim                | piscivore (Reef Six-Limb, fish) | predatory  | cathemeral   | Water (B00005), River deep   | water hazard           |
| A0016 | River Skimmer         | Small     | 0.7 m       | 4 fins + 2 legs               | Smooth scaled hide| swim / walk (brief) | piscivore (small river life) | skittish | crepuscular | River, Shoreline             | meat                   |
| A0017 | Bog-Drinker           | Medium    | 1.4 m       | 6 (4 walk + 2 grasp)          | Plumage           | walk                | filter-feeder (river silt + suspended algae) | peaceful, herd | diurnal | River edge, Shoreline | herd target, meat      |
| A0018 | Cliff-Anchor          | Small     | 0.5 m       | 6 (4 cling + 2 fold-wing)     | Plumage + hide    | climb / glide       | piscivore (dives from cliffs) | peaceful, colonial | diurnal | Coastal Rocks               | egg harvest, lore      |
| A0019 | Crash-Site Scavenger  | Small     | 0.4 m       | 6 walking legs                | Patchy plumage    | walk / sprint       | scavenger (carrion, scrap-organic) | curious, skittish | cathemeral | Crash Site (B00001), Shoreline | first encounter, lore  |
| A0020 | Glow-Tendril Drifter  | Small     | 0.6 m       | 6 (water-suspended fronds)    | Translucent membrane | swim (passive)   | filter-feeder + chemosynth | peaceful, hazardous on contact | nocturnal | Water deep, River deep  | bioluminescent hazard  |
| A0021 | Ash-Coat Pacer        | Medium    | 1.5 m       | 4 walking legs + 2 vestigial mouth-graspers | Short fur         | walk / sprint       | omnivore             | territorial    | crepuscular  | Rocky, Crash Site            | reduced-pair lineage; lore detail in §3.3 |
| A0022 | Carrion Mound         | Small     | 0.4 m       | 6 vestigial nubs              | Slick mucal skin  | walk (slow crawl)   | detritivore (single corpse) | peaceful       | always       | All non-Volcanic            | corpse decomposition mechanism |
| A0023 | Fan-Mantled Pacer     | Large     | 2.8 m / 2.2 m tall | 4 walking legs + 2 short wings | Plumage + dorsal fan | walk / sprint   | grazer (Blade Grass, low ferns) | territorial males, herd otherwise | diurnal | Grassland (B00002), Coastal Rocks (B00010) edge | display species, plumage harvest |
| A0024 | Cliff-Drop Pouncer    | Medium    | 1.7 m       | 4 walking legs + 2 wings (one-shot glide) | Short fur + plumed wings | climb / glide / sprint | carnivore (mid-size grazers) | predatory ambush | crepuscular | Coastal Rocks (B00010), Rocky (B00004) ledges | aerial-ambush threat, claw + plume harvest |

**Counts:** 24 species. 14 land (incl. 2 biwing quadrupeds A0023-A0024), 4 aerial-dominant (A0005-A0007 + A0018), 5 aquatic/semi-aquatic (A0013-A0017, A0020). 1 decomposer (A0022). All 24 species comply with the six-limb plan; A0021 carries a reduced/atrophied pair rather than a true 4-limb body, so the spec has zero true outliers.

### 3.2 Limb-count tally (compliance check)

| Body plan         | Count | Species |
|-------------------|-------|---------|
| 6 walking legs    | 9     | A0001, A0002, A0004, A0008, A0009, A0010, A0012, A0019, A0022 |
| 6 mixed-use       | 6     | A0003, A0011, A0013, A0014, A0017, A0018 |
| 4 wings + 2 legs (tetrawing biped) | 3 | A0005, A0006, A0007 |
| 4 legs + 2 wings (biwing quadruped) | 2 | A0023, A0024 |
| 4 legs + 2 vestigial graspers (reduced pair) | 1 | A0021 |
| 6 fins            | 1     | A0015 |
| 4 fins + 2 legs   | 1     | A0016 |
| 6 fronds          | 1     | A0020 |

24 of 24 species comply with the six-limb plan. A0021 is the only species in which one of the three pairs has regressed: its third pair is reduced to small mouth-side graspers (food-handling vestiges, see §3.3). Both six-limbed winged patterns from §1 are represented (tetrawing biped: 4+2, biwing quadruped: 2+4).

### 3.3 Per-species detail (long form)

For the MVP cut (§6.7), full PropDef-ready descriptions:

**A0001 Dryweed Grazer.** Small herd grazer. Six identical walking legs, short tan fur, dark eye-stripe, no horns. Subsists on Blade Grass (P00001) and the mat-forming `P01001` ground cover. Gives meat (3 units), hide (1), sinew (1) on harvest. The introductory "is this thing dangerous?" species — players see one before meeting any predator.

**A0002 Six-Step Strider.** Larger grazer/browser, herd defensive. 1.6 m at the shoulder, lean, long legged for sprinting. Will form a defensive ring around herd-mates and headbutt predators. When attacked, the herd flees in formation rather than scattering. Yields 6 meat, 2 hide, 2 sinew, 1 horn-analogue.

**A0004 Plumed Stalker.** First real threat. Down-covered, blue-grey, predator. Ambushes from low cover at dusk. Lunges from 2 hexes; if it misses, it flees rather than commits. HP equivalent ~25. Yields plumage (1, dye material), meat (poor quality), claw (1, weapon component).

**A0008 Stone-Mantle Hexapod.** Large hide + dorsal-plate grazer. Slow. Territorial: charges if approached within 2 hexes during day, ignores at night. Plates make it tough — needs an axe-tier weapon to crack. Yields 4 hide, 2 plate (armour component), 8 meat.

**A0010 Glacier Stalker.** Apex predator, pack hunter (3-5). Active at night. Tracks player by scent across hexes. Each attack ~25 damage. Yields heavy fur (3, cold-resist gear), claws (2), meat (4, low quality).

**A0019 Crash-Site Scavenger.** First encounter. Patchy off-white plumage. Curious — approaches wreckage, flees player. Already eating the pod insulation when player wakes up. No threat, no harvest, but scanning it is the player's first ENCOUNTERED → CATALOGED transition for an animal. Sets tone: alien, opportunistic, alive.

**A0022 Carrion Mound.** A single low-slung decomposer — not a swarm, not a patch. Roughly 0.4 m long, slick mucal skin, six vestigial nubs that propel a slow shuffling crawl. One Mound attaches to one corpse; over several hours of game time it breaks the corpse down into reusable detritus. Cannot move between corpses: when "its" corpse is fully consumed, the Mound itself decomposes and despawns alongside it. Implementation note: this is the corpse-cleanup mechanism, not a huntable target — catalog entry only, no harvest yields. Spawns when a corpse prop appears nearby; lifetime is bounded by the corpse's lifetime.

**A0021 Ash-Coat Pacer.** Mid-size grazer-omnivore, ash-coloured short fur, locomotes on four sturdy walking legs. **Distinguishing feature — the reduced pair:** the third pair of limbs has regressed across this lineage's history into two small grasping appendages flanking the mouth, no longer load-bearing and used only for handling food before chewing (think Earth's mantis foreclaws shrunk and migrated up to the jawline, or a hermit crab's chelipeds reduced to picker-size). They are visible up close — short, dexterous, fur-flecked — and the catalog entry calls them out as the spec's clearest illustration that the six-limb plan persists even where evolution has demoted one of the pairs to a niche role. Behaviourally the Pacer is territorial in the Rocky and Crash Site margins, where the narrow niche it occupies (it browses tougher fibrous matter than the herd grazers) keeps competition manageable. The player meets it as quiet evidence that the three-pair body plan flexes — a pair can shrink, migrate, or specialise — without breaking.

**A0023 Fan-Mantled Pacer.** Large biwing quadruped (2.8 m long, 2.2 m at the shoulder). Four sturdy walking legs, plus a pair of short wings that fold flat against the back as a dorsal fan when at rest. The wings are not used for sustained flight — they are display structures, raised in mating bouts and territorial standoffs, and unfurled to dump heat in midday Grassland sun. Males are territorial during display season; outside it, herds of 5-12 graze peacefully on Blade Grass and low ferns. Yields: 4 hide, 6 meat, 2 plumage (a high-value dye material from the fan), 1 sinew. Threat tier 2 (territorial males), 0 (females, off-season). Spans Grassland and the Coastal Rocks edge — herds drift to the rocks during display season for the wind that lifts the fans.

**A0024 Cliff-Drop Pouncer.** Medium biwing quadruped predator (1.7 m). Four strong runner's legs, plus a pair of broad plumed wings used for one-shot glide-pounces from height. Hunts by perching on Coastal Rocks ledges or Rocky cliff edges; when prey passes below, drops, glides 4-8 hexes, lands biting. After a kill it climbs back up the cliff using all four legs (wings folded) and re-perches. Cannot launch from flat ground — needs an elevation drop to glide. This makes the player's vertical position matter: the lower hex is the danger hex, the upper hex is safe. Yields: 2 hide, 3 meat (fair), 2 claws, 1 plumage. Threat tier 3.

(Phase 2 species — A0003, A0005-A0007, A0009, A0011-A0018, A0020 — get long-form treatment when promoted.)

---

## 4. Ecology

### 4.1 Trophic structure

```
Producers (already in code as plants/fungi)
  └─> Primary consumers (grazers, browsers, filter-feeders)
        ├─ A0001 Dryweed Grazer       (grass)
        ├─ A0002 Six-Step Strider     (browse)
        ├─ A0008 Stone-Mantle Hexapod (lichen, dryweed)
        ├─ A0009 Snow-Mantle Behemoth (alpine moss, bark)
        ├─ A0014 Reef Six-Limb        (algae)
        ├─ A0017 Bog-Drinker          (silt + suspended algae)
        ├─ A0013 Tide-Mantled Hexapod (filter + scavenge drift detritus)
        ├─ A0020 Glow-Tendril Drifter (filter drift detritus + chemosynth)
        ├─ A0005 Glasswing Strider    (nectar-analogue)
        ├─ A0021 Ash-Coat Pacer       (tougher fibrous matter; mouth-graspers handle food)
        └─ A0023 Fan-Mantled Pacer    (Blade Grass, low ferns)
  └─> Secondary consumers (small predators, omnivores, scavengers)
        ├─ A0004 Plumed Stalker       (small fauna)
        ├─ A0011 Brachi-Climber       (eggs, small fauna, fruit)
        ├─ A0007 Quadbeak Caller      (carrion + fruit)
        ├─ A0019 Crash-Site Scavenger (carrion)
        ├─ A0006 Lantern-Belly Glider (river fish)
        ├─ A0016 River Skimmer        (river fish)
        ├─ A0018 Cliff-Anchor         (sea-fish, dives)
        └─ A0003 Mantled Burrower     (roots + small fauna)
  └─> Apex predators
        ├─ A0010 Glacier Stalker      (eats Snow-Mantle calves, Stone-Mantle)
        ├─ A0015 Bladefin Hunter      (eats Reef Six-Limb)
        └─ A0024 Cliff-Drop Pouncer   (eats A0001, A0023 sub-adults, A0019)
  └─> Decomposers
        └─ A0022 Carrion Mound        (one Mound per corpse → corpse cycle)
```

**Reduced-pair lineage:** A0021 Ash-Coat Pacer — primary consumer (browser); the species is in the trophic chart but called out separately because its morphology illustrates the three-pair body plan flexing, not breaking.

### 4.2 Predator-prey pairings

| Predator             | Prey (primary)               | Prey (secondary)        |
|----------------------|------------------------------|-------------------------|
| A0004 Plumed Stalker | A0001 Dryweed Grazer (juvenile) | A0012 Forest Floor Shuffler |
| A0007 Quadbeak Caller| Any corpse                   | A0019 Crash-Site Scavenger if cornered |
| A0010 Glacier Stalker| A0009 Snow-Mantle (calves)   | A0008 Stone-Mantle      |
| A0015 Bladefin Hunter| A0014 Reef Six-Limb          | A0016 River Skimmer     |
| A0011 Brachi-Climber | A0018 Cliff-Anchor (eggs)    | A0005 Glasswing Strider |
| A0024 Cliff-Drop Pouncer | A0001 Dryweed Grazer     | A0023 Fan-Mantled Pacer (sub-adults), A0019 |
| Player (us)          | All harvestable              | —                       |

These pairings drive Phase-2 ecology: predator presence in a hex should reduce prey spawn there.

### 4.3 Per-biome cast list

| Biome (id)              | Resident species                                                      |
|-------------------------|------------------------------------------------------------------------|
| Crash Site (B00001)     | A0019 Crash-Site Scavenger, A0007 Quadbeak Caller (visiting), A0022 Carrion Mound (corpse-triggered) |
| Grassland (B00002)      | A0001 Dryweed Grazer, A0002 Six-Step Strider, A0003 Mantled Burrower, A0005 Glasswing Strider, A0021 Ash-Coat Pacer, A0023 Fan-Mantled Pacer |
| Forest (B00003)         | A0004 Plumed Stalker, A0011 Brachi-Climber, A0012 Forest Floor Shuffler, A0005 Glasswing Strider, A0006 Lantern-Belly Glider (edge) |
| Rocky (B00004)          | A0007 Quadbeak Caller, A0008 Stone-Mantle Hexapod, A0021 Ash-Coat Pacer, A0024 Cliff-Drop Pouncer (ledges) |
| Water (B00005)          | A0014 Reef Six-Limb, A0015 Bladefin Hunter, A0020 Glow-Tendril Drifter |
| Alpine (B00007)         | A0008 Stone-Mantle (high edge), A0009 Snow-Mantle Behemoth, A0010 Glacier Stalker |
| Shoreline (B00008)      | A0002 Six-Step Strider (visit), A0013 Tide-Mantled Hexapod, A0017 Bog-Drinker, A0019 Crash-Site Scavenger, A0005 Glasswing Strider |
| River (B00009)          | A0006 Lantern-Belly Glider, A0015 Bladefin Hunter (deep), A0016 River Skimmer, A0017 Bog-Drinker |
| Coastal Rocks (B00010)  | A0007 Quadbeak Caller, A0013 Tide-Mantled Hexapod, A0014 Reef Six-Limb, A0018 Cliff-Anchor, A0023 Fan-Mantled Pacer (display-season visit), A0024 Cliff-Drop Pouncer |
| Decomposer (cross-biome)| A0022 Carrion Mound — one per corpse, in any non-Volcanic biome |

Each non-Volcanic biome has 3-6 resident species. Some species (A0005, A0007, A0019, A0008, A0023) span multiple biomes — they are the migratory connectors. Coastal Rocks now has 2 unique species (A0018, A0024) plus a seasonal A0023 visit, in addition to the shared A0007/A0013/A0014.

### 4.4 Inter-biome stories (Phase-2 hooks, not implemented in MVP)

- **Snow-Mantle migration (Alpine ↔ Rocky):** Snow-Mantle Behemoths drift downhill as the day-count increases (proxy for "season"), pulling Glacier Stalkers with them. By day 30 the player can find apex predators in the Rocky biome.
- **Coastal raids:** Quadbeak Caller flocks in Coastal Rocks expand into Crash Site when corpses accumulate. Encourages players to clean up after themselves.
- **River salmon-run analogue:** River Skimmers (A0016) gather in pre-spawn density at river hexes adjacent to Shoreline — temporary food bonanza for the player and for Lantern-Belly Gliders.

---

## 5. Player-facing roles

Every species answers "what does the player do with this?". Categories:

| Role                        | Species                                                            |
|-----------------------------|--------------------------------------------------------------------|
| Harvest target (meat/hide/material) | A0001, A0002, A0008, A0009, A0013, A0014, A0017, A0023         |
| Threat to manage (combat)   | A0004, A0007, A0010, A0011, A0015, A0024                           |
| Navigation hazard (avoid)   | A0003 (burrow ambush), A0020 (contact damage), A0015 (water), A0024 (cliff-drop) |
| Lore / scan-only            | A0005, A0006, A0019, A0021, A0022                                  |
| Egg / passive harvest       | A0012, A0018                                                       |
| Future taming candidate (out of MVP) | A0001, A0002 (mounts), A0006 (light source companion), A0023 (display herd) |
| Decomposer (mechanism)      | A0022                                                              |

---

## 6. Implementation roadmap

### 6.1 Data model decision: extend `PropDef`, do **not** introduce `FaunaDef`

**Recommendation:** keep using `PropDef` (`scripts/data/prop_def.gd:1`) for fauna species, with the existing capabilities (`endurance`, `movement`, `behavior`, `combat`, `spawnable`, `catalogable`, `harvestable`). Reasons:

1. The codebase already does this. `FaunaManager._get_species_def` (`scripts/fauna/fauna_manager.gd:458`) goes through `PropRegistry`, which iterates `PropDef` resources. The `CHAPTER1_SPECIES` array (`fauna_manager.gd:24`) holds PropDef ids.
2. `Prop.Category.ANIMAL` already exists (`scripts/hex/prop.gd:8`) and `Catalog._is_displayable` (`scripts/scanner/catalog.gd:71`) routes ANIMAL props into the catalog UI bucket alongside PLANT and MINERAL.
3. The existing capabilities cover ~90% of what fauna needs. The only missing pieces (route definitions, pack coordination, scent tracking) are net-new and fit naturally as new caps; introducing a parallel `FaunaDef` would force every consumer (renderer, catalog, scanner, auto-defend) to learn two paths.

**Concrete:**
- Species PropDefs live in `data/fauna/A####.tres`. Why a new directory? The current `data/props/` already has 58 entries; mixing 22 more makes browsing harder, and biome `natural_props` arrays don't reference fauna ids anyway. The `PropRegistry` autoload globs all .tres under `data/`, so the new directory is invisible to the runtime — it's just for human organisation.
- `category` field on PropDef set to `&"animal"`. (Already a valid value per `prop_def.gd:5`.)
- `prop_category` (the int field) set to `Prop.Category.ANIMAL = 2`. Required for `Catalog._is_displayable`.
- IDs use the `A####` namespace. Migration: rename `P00108` → `A0001` (Dryweed Grazer). Update `CHAPTER1_SPECIES`.

### 6.2 Capabilities

#### 6.2.1 Existing capabilities — reuse with new authored values

| Cap                | Used for                                                     | Notes |
|--------------------|--------------------------------------------------------------|-------|
| `EnduranceCap`     | `hp`, `vulnerabilities`, `resistances`, `immunities`         | Already supports per-species HP. Plate-mantled species use `resistances = [&"PIERCING"]` so a knife is a poor choice; `vulnerabilities = [&"BLUNT"]` would invite hammer use later. |
| `MovementCap`      | `modes`: `WALK`, `SWIM`, `FLY`, `BURROW`, `CLIMB`, `JUMP`    | All six modes already enumerated (`movement_cap.gd:5`). MVP uses WALK + JUMP only. SWIM needs FaunaManager passability change (it currently blocks water — `fauna_manager.gd:151,257`). |
| `BehaviorCap`      | `detection_range`, `activity_cycle`, `group_behavior`, `diet`, `reactions` | Already defines `DIURNAL`, `NOCTURNAL`, `CREPUSCULAR`, `ALWAYS` (`behavior_cap.gd:8`) and `SOLO`, `PAIR`, `PACK`, `HERD`, `SWARM` (`behavior_cap.gd:13`). FaunaManager only reads `detection_range` today (`fauna_manager.gd:489`); the other fields are authored-but-ignored until Phase 2. |
| `CombatCap`        | `attacks`, `defenses` (Array of GameEvent)                   | Schema is in place. Needs the GameEvent runtime to land before authored attacks fire — until then we rely on `DEFAULT_CONTACT_DAMAGE = 10` (`fauna_manager.gd:21`). |
| `SpawnableCap`     | `spawn_min`, `spawn_max`, `first_spawn_day`, `spawn_min_distance`, `allowed_biomes` | All five used today. `allowed_biomes` is currently an authored-but-not-enforced field — FaunaManager spawns anywhere passable. **Proposal:** start enforcing `allowed_biomes` in `_is_valid_spawn_tile` (`fauna_manager.gd:137`). |
| `CatalogableCap`   | `scan_time`, `properties`                                    | Per `catalogable_cap.gd:11`, plant + mineral schemas are documented. **Animal schema below is new.** |
| `HarvestableCap`   | `yields`, `respawn_conditions`                               | The fauna death path bypasses this today — `_drop_loot` reads the deprecated `yield_type` field (`fauna_manager.gd:374`). Needs migration: harvest a corpse prop, not the live fauna. |
| `PlaceableCap`     | `meshes`, `collision_shapes`, `placement`, `slope_blend`, `max_allowed_slope` | Author at least 1 mesh per species; FaunaRenderer currently uses a single red sphere (`fauna_renderer.gd:24`). Phase 2 swaps to per-species mesh. |

#### 6.2.2 New capabilities — propose authoring these

| New cap            | Purpose (1 sentence)                                                     | Key fields |
|--------------------|---------------------------------------------------------------------------|------------|
| `RouteCap` *(proposal)* | Defines a patrol path the creature follows when not engaged.         | `waypoints: Array[Vector2i]`, `loop: bool`, `pause_seconds: float`, `wander_radius: int` |
| `PackCap` *(proposal)* | Coordinates spawning + behaviour of a multi-creature group.         | `group_size_min/max: int`, `cohesion_radius: int`, `alpha_role: bool`, `flee_threshold: float` (% of pack dead before route flips to retreat) |
| `FlightCap` *(proposal)* | Aerial-specific tuning beyond MovementCap.FLY.                      | `cruise_altitude: int`, `landing_biomes: Array[StringName]`, `dive_attack: bool` |
| `AmbushCap` *(proposal)* | Pre-attack hidden state with surprise damage bonus.                  | `hide_in_tags: Array[StringName]` (e.g. `&"DENSE_FOLIAGE"`), `surprise_multiplier: float`, `reveal_range: int` |
| `ScentCap` *(proposal)* | Predator memory: tracks the player across hexes after losing sight. | `memory_seconds: float`, `decay_per_step: float`, `reacquire_range: int` |
| `BreakdownCap` *(proposal)* | Corpse → loot resolution. The death path places a corpse prop; this cap on the **corpse** (not the live fauna) drives what the harvest recipe yields. | `yields: Array[HarvestYield]`, `decay_seconds: float`, `decay_creates: StringName` (creates A0022 Carrion Mound prop) |

**Author count:** 6 new caps. In MVP we author `BreakdownCap` only (replaces the deprecated `yield_type` path). The other five land in Phase 2 alongside the species that use them.

#### 6.2.3 Animal catalog schema (new — for `CatalogableCap.properties`)

Following the plant + mineral schema convention in `catalogable_cap.gd:11-37`. Fields populated when the species is CATALOGED:

```
size_class:        String  "tiny" | "small" | "medium" | "large" | "huge" | "colossal"
limb_count:        int     6 (4 walking + 2 reduced graspers count as 6)
body_plan:         String  "hexapod" | "tetrawing_biped" | "biwing_quadruped"
                          | "hex_climber" | "fin_hexapod" | "reduced_pair"
covering:          String  "fur" | "plumage" | "scaled_hide" | "smooth_skin"
                          | "hide_plate" | "membrane" | "shell"
diet_class:        String  "grazer" | "browser" | "carnivore" | "piscivore"
                          | "scavenger" | "omnivore" | "filter_feeder" | "detritivore"
                          | "fungivore" | "nectarivore"
locomotion_primary: String "walk" | "sprint" | "fly" | "glide" | "swim" | "dive"
                          | "burrow" | "climb"
activity_cycle:    String  "diurnal" | "nocturnal" | "crepuscular" | "cathemeral"
group_size:        String  "solo" | "pair" | "small_group" | "herd" | "colony"
threat_level:      int     0-5 (0=harmless, 3=dangerous, 5=apex)
edible:            bool
notable_trait:     String  freeform single sentence (bioluminescence, plate armor, etc.)
```

12 fields. Renders cleanly in the existing catalog UI grid.

### 6.3 Spawn system — three modes

The current FaunaManager has exactly one spawn mode: "at night, around the player, on passable unlit tiles" (`fauna_manager.gd:97-121`). We need three.

| Mode                    | Description                                                                 | Species using it                                 |
|-------------------------|-----------------------------------------------------------------------------|--------------------------------------------------|
| **Procedural ambient**  | Like the current behaviour, but extend to day spawns and biome-filter via `SpawnableCap.allowed_biomes`. | Most non-apex: A0001, A0002, A0005, A0007, A0012, A0013, A0014, A0017, A0019, A0020 |
| **Route-based**         | Creature spawns at a specific tile authored in the editor; follows a `RouteCap` waypoint chain; respawns at start after a despawn cycle. | A0008 (territory patrol), A0009 (Alpine corridor), A0010 (pack patrol), A0011 (canopy loop), A0018 (cliff colony) |
| **Triggered / scripted**| Spawned by an in-fiction event (corpse appears, player crosses threshold). | A0022 (corpse trigger), A0007 raids (after corpse density threshold) |

**Code touch points:**
- `_on_night` (`fauna_manager.gd:81`) becomes `_spawn_tick`, called on `night` AND `dawn` (or every N seconds during day for diurnal species).
- New method `_spawn_route_based` reads `RouteCap.waypoints[0]` from the species def, ignores light filter (the spawn point is authored).
- New autoload event hook: `prop_added` with category=corpse → triggers A0022 spawn nearby.

### 6.4 Movement primitives

The current movement loop is a single greedy best-neighbour towards the player (`fauna_manager.gd:219-244`). We need verbs that do more than chase.

| Verb            | Means                                                                    | Implemented via |
|-----------------|--------------------------------------------------------------------------|-----------------|
| `idle_wander`   | Random adjacent step every cooldown when player out of range             | Replace `if dist > detection_range: continue` with `_pick_random_neighbour()` |
| `patrol_route`  | Step toward next waypoint in `RouteCap`; advance when reached            | New: `_step_along_route(fauna)` |
| `chase`         | Current behaviour — greedy towards player                                | Existing `_find_best_move` |
| `flee`          | Greedy *away* from player (max-distance neighbour instead of min)        | Mirror of `_find_best_move`, comparator inverted |
| `swim`          | Same as walk but water tiles passable, land tiles blocked                | Add `Mode.SWIM` branch to `_is_fauna_passable` (`fauna_manager.gd:247`) |
| `dive`          | Two-phase: surface → submerged, submerged → invisible to renderer        | `fauna["submerged"] = bool`; renderer skips submerged instances |
| `fly`           | Pathing ignores ground props and elevation entirely                      | New `Mode.FLY` branch; max_jump effectively unlimited |
| `glide`         | Flying with one-direction lock; ends on land                             | New cap `FlightCap`; route is straight-line until `landing_biomes` |
| `burrow`        | On chase, vanish from grid for 1-3 ticks then reappear adjacent          | `fauna["burrowed_until"] = tick + N`; renderer + auto-defend skip |
| `herd_follow`   | Move toward herd centroid when player not detected                       | `PackCap.cohesion_radius`; pre-pass computes centroid per herd |

`HexMath.distance` (used at `fauna_manager.gd:159, 194, 287, 491`) and `_HexMath.get_neighbors` (`fauna_manager.gd:222`) cover the geometry. New verbs all reduce to "pick a different best-neighbour comparator".

### 6.5 Combat & damage

**Today:** `auto_defend_triggered` fires when a hostile cataloged fauna moves adjacent (`auto_interaction_system.gd:485-529`). Damage is looked up from `WEAPON_DAMAGE` (auto_interaction_system.gd:26-29), a tiny constant table. Cooldown is 1.0 second (`auto_interaction_system.gd:42-44`), range is 1 hex.

**Spec:**
- **Threat tiers** drive HP / damage / cooldown:

| Tier (from catalog `threat_level`) | HP    | Contact damage | Move cooldown | Detection range | Example         |
|------------------------------------|-------|----------------|---------------|-----------------|------------------|
| 0 (harmless)                       | 8     | 0              | 1.5 s         | 0 (no chase)    | A0001 Grazer     |
| 1 (skittish)                       | 12    | 0              | 1.2 s         | 0 (flees only)  | A0002, A0019     |
| 2 (territorial)                    | 25    | 8              | 1.0 s         | 3               | A0008 Stone-Mantle |
| 3 (dangerous)                      | 35    | 12             | 0.8 s         | 4               | A0004 Plumed Stalker |
| 4 (predatory pack)                 | 30    | 15             | 0.7 s         | 5               | A0010 Glacier Stalker |
| 5 (apex)                           | 80    | 25             | 0.9 s         | 5               | A0009 Behemoth (defensive only) |

These map onto existing fields: HP → `EnduranceCap.hp`; cooldown → `MovementCap.modes[WALK][0]` (since cooldown derives from speed at `fauna_manager.gd:500`); detection → `BehaviorCap.detection_range`. Damage is the only one without a home — until GameEvent attacks land, encode it as a stopgap field on `BehaviorCap` (`contact_damage: int`, replaces `DEFAULT_CONTACT_DAMAGE`).

- **Attack range** stays at 1 hex per the existing AUTO_DEFEND_CONFIG. Apex predators that should hit at range need `CombatCap.attacks[]` GameEvents — defer until the combat runtime lands.
- **Cooldown:** keep the per-fauna `cooldown_remaining` (`fauna_manager.gd:114`) as the attack rate. A predator's "next swing" is one move-tick away; we don't add a separate attack cooldown.
- **Vulnerabilities/resistances** already work via `EnduranceCap.vulnerabilities` and `resistances` (`endurance_cap.gd:8,11`). Author them per species (knives are good vs A0004, bad vs A0008).

### 6.6 Catalog integration

Three knowledge states already exist (`scripts/scanner/catalog.gd:7`): UNKNOWN → ENCOUNTERED → CATALOGED.

| Acquisition path           | Triggered by                                                                                                | Species using it                                                            |
|----------------------------|-------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------|
| Encounter on attack        | `fauna_attacked_player` → `ScannerSystem.on_fauna_attacked_player` (`scanner_system.gd:162`) → label "Hostile" | All hostile species (A0004, A0007, A0010, A0011, A0015)                      |
| Encounter on flee          | `ScannerSystem.on_fauna_fled` (`scanner_system.gd:175`) — exists but not wired to a fauna signal yet → label "Shy" | Skittish species (A0001, A0002, A0019)                                       |
| Scan to catalog            | Player is adjacent for `CatalogableCap.scan_time` seconds                                                    | Only static species, OR fauna in CATALOG state requires a stationary creature (corpse, sleeping creature, calm grazer) |
| Encounter via lore prop    | Reading a journal entry adds knowledge (already in `JournalEntry` infra)                                     | A0021 Ash-Coat Pacer — if we want one species discoverable via lore         |

**Hard problem with scan-to-catalog for live fauna:** the scanner requires the player to remain within `SCAN_RANGE = 1` (`scanner_system.gd:21`) for `scan_time` seconds (`scanner_system.gd:87-93`). A creature with `detection_range > 0` will run from / chase the player, breaking the scan. Three options:
  1. **Scan corpses, not creatures.** Corpse props (placed by `_place_corpse` `fauna_manager.gd:350`) get the species' `CatalogableCap`. ENCOUNTERED-state animals upgrade to CATALOGED via corpse scan. Catalog already excludes ENCOUNTERED animals from proximity scan (`catalog.gd:237`) — extending corpses bypasses that gate cleanly.
  2. **Scan-while-following.** Player needs an upgrade item ("long-range scanner") to scan from 3+ hexes. Out of MVP.
  3. **Calm species are scannable live.** A0001 Dryweed Grazer with `detection_range=0` doesn't flee until attacked, so the player can scan it. Works for grazers and lore-only species but not predators.

**Recommendation:** Option 1 is the MVP path. Author `CatalogableCap` on the *corpse* prop, not the live fauna. Live fauna only carry the encounter info. This means each huntable species needs both an `A####` (live) and a `P00###_corpse` (dead) PropDef, paired via the corpse mapping in `_get_corpse_type` (`fauna_manager.gd:361`). Phase 2 adds the live-scan upgrade.

**Scan-time tiers:**

| Size class | Scan time | Rationale                                                |
|------------|-----------|----------------------------------------------------------|
| Tiny       | 1.5 s     | Less to study                                            |
| Small      | 2.0 s     | Default plants are 1.0 s — fauna takes longer            |
| Medium     | 3.0 s     | Worth the time gate                                      |
| Large      | 4.5 s     | A real research moment                                   |
| Huge       | 6.0 s     | Player is leaning forward                                |
| Colossal   | 8.0 s     | (No species here yet; reserved)                          |

Cross-references `catalogable_cap.gd:38` and the `DEFAULT_SCAN_DURATION = 2.0` fallback at `scanner_system.gd:16`.

### 6.7 Editor support

The level editor has a "Fauna" sidebar tab already (`tools/level-editor/js/sidebar.js:42` — `{ id: 'animal', label: 'Fauna' }`) and "animal" is in `PROP_CATEGORY_TABS` (`app.js:196`). The plumbing is in place; what's missing is **editor surfaces** for fauna-specific data:

| Need                            | Where it lives now                          | Required change                                  |
|---------------------------------|---------------------------------------------|---------------------------------------------------|
| Author A#### species PropDefs   | `prop-editor.js` works for any PropDef       | Already supported — but needs UI surfaces for new caps (RouteCap, PackCap, etc.) when they land |
| Place a route waypoint on the map | No tool exists                            | New tool in `tools.js` — "route brush" — click to add waypoints to the active species patrol; right-click to close the loop |
| Pin initial spawn locations     | Currently fauna spawn procedurally          | New "spawn marker" prop placed on a tile; FaunaManager reads markers at game start as authored spawns |
| Per-tile fauna preview          | None — fauna are runtime-only               | Defer: editor doesn't need to render live fauna, only the spawn markers and routes |

**MVP editor work:** None beyond what's already there. The MVP roster (§6.8) uses procedural spawn only; the existing prop editor authors the species PropDefs.

### 6.8 Phasing

#### MVP (5 species, simplest behaviours, procedural spawn only)

Pick the smallest set that exercises every player-facing role:

| ID    | Name                  | Role                              | Behaviour          |
|-------|-----------------------|-----------------------------------|--------------------|
| A0001 | Dryweed Grazer        | Harvest, calm scan target         | idle_wander, flee on attack |
| A0004 | Plumed Stalker        | First real combat threat          | chase + retreat-on-miss   |
| A0008 | Stone-Mantle Hexapod  | Tanky territorial, axe-tier prey  | territorial chase within 2 hexes |
| A0019 | Crash-Site Scavenger  | First encounter, lore             | flee on approach   |
| A0022 | Carrion Mound         | Decomposer mechanism              | one per corpse, slow crawl, despawns with corpse |

5 species. Cover: harvest target, threat, tank, encounter-on-flee, decomposer. **Do not** include aerial, aquatic, biwing-quadruped, or routed species in MVP — they require new caps (FlightCap, RouteCap) and FaunaManager passability changes. A0023 Fan-Mantled Pacer and A0024 Cliff-Drop Pouncer are explicitly Phase 2.

**MVP FaunaManager changes (concrete):**
1. Replace `CHAPTER1_SPECIES = [&"P00108"]` (`fauna_manager.gd:24`) with the 5 A-IDs above.
2. Make `_on_night` (`fauna_manager.gd:81`) honour `BehaviorCap.activity_cycle` — diurnal species spawn at `dawn`, nocturnal at `night`, crepuscular at both, `ALWAYS` at both.
3. Enforce `SpawnableCap.allowed_biomes` in `_is_valid_spawn_tile` (`fauna_manager.gd:137`).
4. Add `idle_wander` and `flee` modes selected by a `BehaviorCap.movement_mode` field (new int enum).
5. Replace the hardcoded `DEFAULT_CONTACT_DAMAGE` with `BehaviorCap.contact_damage` (new int field) until GameEvents land.
6. Move the `_get_corpse_type` mapping (`fauna_manager.gd:361`) to a field on `BehaviorCap.corpse_def`.
7. Drop the deprecated `yield_type` reading in `_drop_loot` (`fauna_manager.gd:374`); have the corpse PropDef carry the harvest yields via the existing `HarvestableCap`.
8. Author `data/fauna/A0001.tres` … `A0019.tres` + 4 corpse PropDefs.

#### Phase 2 (full ~20 species + ecology)

- Add the remaining 19 species, including aerials, aquatics, and the two biwing quadrupeds (A0023, A0024).
- Author `RouteCap`, `PackCap`, `FlightCap`, `AmbushCap`, `ScentCap`, `BreakdownCap`.
- Extend FaunaManager passability for SWIM/FLY/CLIMB modes.
- Editor: route brush + spawn marker tools.
- Predator-prey loop: predator species reduce prey spawn frequency in their hex.
- Snow-Mantle migration as a day-count-driven `allowed_biomes` shift.
- Per-species mesh in FaunaRenderer (replace the red-sphere placeholder at `fauna_renderer.gd:24`).
- Live-scan upgrade: a craftable item that lets the player scan creatures at range 3.

#### Phase 3 (taming / persistence / pets)

Out of the present spec; flagged in §7 below.

---

## 7. Open questions for Andre

These materially change the implementation. Each gets a recommendation but the call is yours.

### 7.1 Combat input on mobile

**Question:** Is combat tap-to-attack, or auto-defend only?
**Why it matters:** The mobile UX target shapes the entire combat loop. Auto-defend (current path, `auto_interaction_system.gd:485`) means the player just walks away from threats they can't handle and combat is reactive. Tap-to-attack adds an offensive verb the player invokes deliberately — different feel, different threat curve.
**Recommendation:** Auto-defend stays as the floor; add a "stalk" mode where tapping a fauna sets it as a target and auto-defend attacks even when not adjacent (within range). MVP: auto-defend only.

### 7.2 Fauna respawn rules

**Question:** We just removed plant/mineral respawn. Do animals respawn?
**Why it matters:** If yes, we need a respawn timer per species; if no, a successful hunting trip permanently depletes that hex. Current code already supports both: `HarvestableCap.respawn_conditions` has the schema but it's a no-op for fauna because death is via `_on_fauna_death` (`fauna_manager.gd:332`), not the harvest path.
**Recommendation:** Yes, but indirectly — fauna instances despawn at dawn (`_on_dawn` `fauna_manager.gd:388`) and the next night's spawn cycle generates fresh ones at fresh tiles. So *individuals* don't respawn but the *species pool* refreshes nightly. Rare species (apex predators) get a `first_spawn_day` cooldown on top: A0010 only spawns every 4 days.

### 7.3 Day/night meaning

**Question:** Is night meaningfully different from day yet, or do all creatures behave the same?
**Why it matters:** The MVP code only spawns at night (`_on_night` `fauna_manager.gd:81`). If diurnal species have to spawn during day, we need a `_on_dawn` spawn hook AND every consumer (FaunaRenderer, Catalog, AutoDefend) has to work in daylight. Several already do — Catalog and AutoDefend are time-agnostic. FaunaRenderer is fine. Just FaunaManager needs the additional hook.
**Recommendation:** Add the day-spawn hook in MVP. Cost is small (one `dnc.dawn.connect`); benefit is ecological coherence (a Dryweed Grazer at midnight is wrong).

### 7.4 Pet / companion / taming

**Question:** Out of scope for MVP, or worth designing toward?
**Why it matters:** If taming is on the roadmap, we want capabilities now that won't need rewriting later — specifically a `TameableCap` slot on the species def. Not authoring it doesn't cost anything; designing assuming it exists prevents wedging it in later.
**Recommendation:** Design toward it but don't author. Reserve a `tameable: TameableCap` slot in the eventual `prop_def.gd` extension (will need a 1-line addition like `@export var tameable: TameableCap = null`). Leave the cap class undefined until Phase 3.

### 7.5 Persistence across saves

**Question:** Do animals survive saves/reloads with their position + state, or are they re-rolled?
**Why it matters:** `FaunaManager` uses pure dictionaries (`fauna_manager.gd:41`) and has no save/load methods. The save system exists for the catalog (`scanner_system.gd:286-294`) but not for fauna instances. If we want continuity ("the wounded predator I left on the cliff is still there when I return"), we need to add `get_save_data` / `load_save_data` to FaunaManager.
**Recommendation:** Re-roll on load for MVP — fauna are transient anyway (despawn at dawn, `fauna_manager.gd:388`). For Phase 2, the only state worth persisting is the catalog knowledge state (already saved). Routed species (A0008, A0009, A0010) eventually need persistence so a wandering pack can maintain its territory across saves; this is a Phase-2 concern.

### 7.6 Scale of routes

**Question:** Hex-by-hex waypoints, or higher-level "patrol this region" hints?
**Why it matters:** Hex waypoints give precise authoring control but force the editor into a click-by-click chore for large patrols. Region hints (e.g. "anywhere in the Alpine biome on tiles >50 elevation") are fast to author but produce wandering creatures that may not feel "directed."
**Recommendation:** Both, in `RouteCap`:
  - `waypoints: Array[Vector2i]` — explicit list (used when authored)
  - `region_filter: Dictionary` — when waypoints empty, fauna picks random tile matching `{biome: B00007, min_elevation: 5, max_dist_from_anchor: 4}`

This also lets the editor's "route brush" generate waypoints OR the user can leave it empty for region-roaming creatures.

### 7.7 Are corpse harvests gated by tools?

**Question:** Do you need a knife to butcher? An axe to crack a Stone-Mantle's plates?
**Why it matters:** The `HarvestableCap.yields[].conditions` field (`harvest_yield.gd`) supports tool gates already; the question is whether the design wants them. Tool gates increase the meaningfulness of the inventory but add friction.
**Recommendation:** Yes, but cheap. Bare-hands harvest yields meat only. Knife unlocks hide, sinew. Axe (or better) unlocks plates from A0008. Consistent with the recipe-condition pattern in `auto_interaction_system.gd:269-285`.

### 7.8 Damage type — bringing GameEvents forward

**Question:** Push the GameEvent / CombatCap runtime into MVP, or stay with `DEFAULT_CONTACT_DAMAGE`?
**Why it matters:** The clean answer is GameEvents — they're already authored on `CombatCap.attacks` (`combat_cap.gd:6`), and using them removes the stopgap I'm proposing on `BehaviorCap.contact_damage`. The schedule reality is the runtime hasn't landed. If it lands close to fauna MVP, we should align.
**Recommendation:** Watch the combat-runtime ETA. If it's not ready by the time fauna MVP needs to ship, use `BehaviorCap.contact_damage` and migrate later. Document the migration path in the spec (this section).

---

## 8. Glossary

- **Hexapod:** Six-legged walking creature. Default body plan.
- **Tetrawing biped:** Four wings + two legs. Aerial form.
- **Biwing quadruped:** Two wings + four legs. Aerial form (ground-dwelling, glides).
- **Hex climber:** Six mixed-use limbs (alternating climb + grasp).
- **Plumed:** Down/feather covering on a small "scaled-lineage" creature. Convergent with Earth birds.
- **Apex:** Threat tier 5; rare, single creature per biome at most.
- **Encounter:** First-meeting catalog state (ENCOUNTERED). Fauna-specific knowledge step before CATALOGED.
- **Live-scan:** Scanning a creature without killing it. Phase 2; requires a craftable upgrade.
- **Carrion Mound:** A0022 — corpse decomposer; the in-fiction reason corpse props vanish.
- **A####:** Species ID namespace. `A0001` Dryweed Grazer, etc.

---

## 9. References (code citations)

- `scripts/data/prop_def.gd:1-110` — PropDef structure, all caps, `category` and `prop_category` fields.
- `scripts/data/capabilities/movement_cap.gd:5,18` — `Mode.WALK..JUMP` enum and the `modes` dict layout.
- `scripts/data/capabilities/behavior_cap.gd:8,13` — `ActivityCycle` and `GroupBehavior` enums.
- `scripts/data/capabilities/spawnable_cap.gd:1-18` — spawn parameters, `allowed_biomes`.
- `scripts/data/capabilities/catalogable_cap.gd:11-37` — schema convention to follow for the new animal schema.
- `scripts/fauna/fauna_manager.gd:21,24` — `DEFAULT_CONTACT_DAMAGE = 10`, `CHAPTER1_SPECIES = [&"P00108"]`.
- `scripts/fauna/fauna_manager.gd:81-121` — `_on_night` and `_spawn_species`; entry point for new spawn modes.
- `scripts/fauna/fauna_manager.gd:137-176` — spawn candidate filtering; where `allowed_biomes` enforcement should land.
- `scripts/fauna/fauna_manager.gd:219-244` — `_find_best_move`; where the new movement verbs hook in.
- `scripts/fauna/fauna_manager.gd:332-384` — death → corpse → loot; needs migration from `yield_type` to `BreakdownCap`.
- `scripts/fauna/fauna_renderer.gd:24` — current red-sphere placeholder; Phase-2 mesh swap target.
- `scripts/scanner/scanner_system.gd:162-182` — `on_fauna_attacked_player` and `on_fauna_fled`; the encounter-state hooks.
- `scripts/scanner/catalog.gd:7,237` — `KnowledgeState` enum and the ENCOUNTERED-animals exclusion from proximity scan.
- `scripts/auto_interaction/auto_interaction_system.gd:26,42-44,485-529` — WEAPON_DAMAGE table, AUTO_DEFEND_CONFIG, `_on_fauna_moved`.
- `scripts/hex/prop.gd:7-15` — `Prop.Category` and `Prop.Origin` enums.
- `tools/level-editor/js/sidebar.js:42`, `tools/level-editor/js/app.js:195` — Fauna tab + `PROP_CATEGORY_TABS`.
- `data/biomes/B0000{1..10}.tres` — biome flavour anchors; B00006 is Volcanic and is excluded.
- `tests/features/fauna.feature` — current behavioural contract; spawn day-4 gate, contact damage, shelter immunity, corpse-on-death.

---

## 10. Out of scope (explicit)

- Volcanic biome (B00006) life — excluded by world rule.
- Insects, microfauna — excluded by size band.
- Marine megafauna (whale-analogues) — excluded by size band.
- Permanent persistent fauna (the same individual across save loads) — Phase 2+.
- Taming, mounts, pets — Phase 3.
- Inter-fauna combat (predator hunts prey on its own) — Phase 2.
- Scent tracking — Phase 2 (`ScentCap`).
- Ranged predator attacks — blocked on combat runtime; until GameEvents land, all attacks are contact at range 1.
- Respawn-as-individual (a wounded creature returns wounded) — out of scope.
- Day/night ambient species swap-out simulation (i.e. the diurnal species "leave" at dusk) — Phase 2; MVP relies on despawn-at-dawn for nocturnal and a separate dawn spawn for diurnal.

---

*End of spec.*
