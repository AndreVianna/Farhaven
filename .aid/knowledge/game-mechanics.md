# Game Mechanics

> **Status:** Active
> **Last Updated:** 2026-04-09 (consolidated from GDD, crash-landing-design, game-mechanics-redesign, feature-inventory, cutscene-vision)

---

## Overview

**Title:** Farhaven
**Genre:** Casual Survival / Crafting / Exploration
**Platform:** Android + iOS
**Engine:** Godot 4.x (GDScript)
**Monetization:** Free demo → $2.99 one-time unlock (no ads, no IAP, no premium currency)
**Target:** 13+, casual mobile gamers who like survival/craft but hate predatory monetization
**Inspiration:** My Little Universe (gameplay loop), Don't Starve (atmosphere/urgency), Islanders (hex aesthetics)
**Offline:** 100% offline. No server, no account, no telemetry.

**Elevator pitch:** You're an astronaut who crash-lands on an unknown planet. Explore a hex-tile world, gather resources, craft tools, build a base, survive the nights — and ultimately repair your ship to escape. No ads. No fake currency. No timers. Just a planet to escape.

---

## Core Gameplay Loop

```
EXPLORE → SCAN → GATHER → CRAFT → BUILD → SURVIVE
  ↑                                          |
  └──────────────────────────────────────────┘
```

Each "day" the player:
1. **Explores** new hex tiles (terrain always visible, mini-map tracks visited)
2. **Scans** flora, fauna, minerals, anomalies via bracelet scanner
3. **Gathers** resources from tiles (proximity auto-gather, recipe-gated)
4. **Crafts** tools and materials (recipe system, station-based)
5. **Builds** structures on hex tiles (shelter, machines, defenses)
6. **Survives** the night cycle (threats increase, lighting critical)

The loop is satisfying at every scale:
- **Micro (30 seconds):** Walk near tree → auto-gather wood → feels good
- **Meso (5 minutes):** Gather enough to craft a new tool → unlocks new resource type
- **Macro (hours):** Discover anomalies, piece together the story, progress through chapters

---

## Features

See **[feature-inventory.md](feature-inventory.md)** for the complete feature list with implementation status.

**Summary (13 features):**
- 8 implemented: hex grid, movement, gathering, inventory, crafting, scanner, HUD, auto-interaction
- 3 stubbed: survival system, building system, fauna/threats
- 1 implemented (lighting added 005a): day/night cycle
- 1 not started: journal & narrative

---

## Recipes & Capabilities

The unified Recipe system is the engine for all gameplay transformations: gathering, crafting, cooking, building, passive processes (rot, burn cycles), and discovery.

**Authoritative spec:** `.aid/work-001-core/delivery-005a/DESIGN.md`

**Key concepts:**
- **Recipe:** A transformation with inputs, outputs, effects, conditions, actions, and duration. Extends ScriptBase → Gear hierarchy (delivery-006a).
- **GameEvent:** Milestones, world flags, discovery triggers. Extends ScriptBase → Gear hierarchy. Discovery events fire `grant_recipe` effects to unlock recipes.
- **Capabilities:** Composable behavior on PropDefs (Portable, Placeable, Container, Light, Movable, Station, Catalogable) — replaces the old category-based system
- **Tags:** Free-form labels on PropDefs for flexible recipe matching (e.g. `BURNABLE.log`, `CONSUMABLE.edible`)
- **Predicates:** 15 condition kinds that gate recipe/event execution (has_tool, at_station, cataloged, etc.)
- **Discovery:** Recipes unlock when their corresponding GameEvent fires (event has `grant_recipe` effect). DiscoveryWatcher watches EventRegistry.

**Recipe kinds:** ASSEMBLE, TRANSFORM, BREAKDOWN, COMBINE (cosmetic classification)
**Current counts:** 26 recipe .tres files (R-prefixed), 12 event .tres files (discovery events)

---

## Building System

**Status:** Implemented (delivery-005b + delivery-006a)

Structure placement on hex tiles via the recipe system. Player crafts structures that are placed in the world at SSH-precision positions with mesh-based collision.

**Core structures:**

| Structure | Function |
|-----------|----------|
| Workbench | Basic crafting station |
| Shelter | Safe at night, save point |
| Storage Chest | Expanded inventory |
| Furnace | Smelting, advanced crafting |
| Wall | Block fauna movement (via mesh collision) |
| Torch | Extends night visibility |
| Campfire | Cooking station, warmth, light |

**Placement model (updated delivery-006a):**
- Structures snap to SSH (sub-sub-hex) centers at 32cm resolution
- 3-level grid: Hex (6m) → Sub-hex (1.39m) → SSH (0.32m)
- Collision is mesh-based (CollisionHelper generates CollisionShape3D, StructureRenderer adds StaticBody3D)
- No footprint arrays or blocks_movement flags — collision detection uses Godot physics (3D mesh overlap)
- Multiple structures per hex allowed if meshes don't overlap
- Build panel UI shows available recipes filtered by known recipes + available materials

See [data-model.md](data-model.md) §Spatial System for SSH grid math details.

---

## Survival Stats

**Status:** Stubbed

Three stats tracked via bracelet biometrics (diegetic UI):

| Stat | Depletion | Zero Effect | Restore |
|------|-----------|-------------|---------|
| **Health (HP)** | Damage from hazards, fauna, traps | Death | Med kit, regen during day |
| **Hunger** | Depletes over time | HP drain | Eat food (berries, cooked meat, rations) |
| **Thirst** | Depletes faster than hunger | HP drain (faster) | Drink water |

**No stamina bar** — no artificial movement limits. Player can always run.

**Environmental modifiers:**
- Heat (desert biome): Thirst drains 2x
- Cold (night): Hunger drains 1.5x
- Poison (swamp biome): Slow HP drain for 30s

**Emergency kit (Chapter 1 start):**
- 3 days of rations
- 3 days of water
- 3 uses of med kit
- The "Rule of Three" — all consumables expire around the same time, pushing the player out of crash site

---

## Day/Night Cycle

**Status:** Implemented (lighting added delivery-005a)

| Phase | Duration | Gameplay |
|-------|----------|----------|
| **Day** | ~3 min real time | Safe exploration, full visibility |
| **Dusk** | ~30 sec | Warning phase, screen tints, get to shelter |
| **Night** | ~1.5 min | Dangerous — visibility reduced, hostile fauna active, temperature drops |
| **Dawn** | Transition | Night ends, new day counter |

One full cycle = ~5 minutes real time.

**Lighting model:**
- Day: full natural light
- Night: bracelet flashlight illuminates ~2 hex range
- Structures with LightCap (torch, campfire) provide local illumination via LightingManager
- No fog of war in 3D world — visibility is lighting-based, not overlay-based

**Phase-based fauna triggers:**
- Night fauna spawn outside lit/walled areas
- Move toward player if within 2 hexes
- Despawn at dawn
- Night is a timer/pressure mechanic, not a combat game

**Future (Act 3+):** Daily eclipse sub-phase on the near side. Planet-shine ambient light. See [game-lore.md](game-lore.md) §Act 3.

---

## Fauna

**Status:** Implemented (delivery-005b) + design expanded (2026-04-10)

### FaunaCap (on PropDef — defines WHAT the species IS)

```yaml
FaunaCap:
  # Movement capabilities (speed range per mode, [0,0] = can't)
  movement:
    walk: [min, max]
    swim: [min, max]
    fly: [min, max]
    burrow: [min, max]
    can_climb: bool

  # Activity cycle
  activity: Nocturnal | Diurnal | Crepuscular | Always

  # Stats (rolled on spawn between min/max)
  hp: [min, max]

  # World interaction
  diet: Herbivore | Carnivore | Scavenger | Omnivore

  # Group behavior
  group: Lonely | Herd | Swarm | Following

  # ALL behavior = event lists (no hardcoded enums)
  reactions: [Event refs]   # evaluated every game loop
  attacks: [Event refs]     # evaluated when attacking
  defenses: [Event refs]    # evaluated when defending
```

### Behavior is 100% event-driven

Instead of enums like `reaction: Aggressive | Timid`, behavior is defined as Event references:

**Reactions (every loop):**
- `condition(player_distance <= 5) → effect(flee)` — timid
- `condition(player_distance <= 3) → effect(attack)` — aggressive
- `condition(player_in_territory) → effect(hunt)` — predatorial
- `condition(player_distance <= 10) → effect(ignore)` — indifferent
- `condition(near_structure + structure_has: EMITS_LIGHT) → effect(move_away)` — avoids light
- `condition(near_structure) → effect(attack_structure)` — siege behavior
- `condition(hp_percent < 0.2) → effect(flee)` — flee when hurt
- `condition(hp_percent < 0.5) → effect(call_nearby_fauna)` — call for help

**Attacks (during combat, attacker's turn):**
- `condition(is_fighting + hit_success) → effect(do_damage: base_damage)`
- `condition(is_fighting + special_ready) → effect(do_damage: special_damage)`

**Defenses (during combat, defender's turn):**
- `condition(is_fighting + defense_fails) → effect(take_damage)`
- `condition(is_fighting + on_shelter) → effect(block_all)`

Adding a new species with unique behavior = adding Event .tres files. Zero code changes.

### Territory (lives on the MAP, not on PropDef)

Fauna zones are defined in the map data (ch1.json or editor), not on the species:

```yaml
fauna_zones:
  - species: thornback
    density: [1, 3]           # min/max simultaneous individuals
    movement_type: random     # random | path | static
    area: [hex coords]        # spawn + wander zone

  - species: cave_lurker
    density: [1, 1]
    movement_type: static     # stays at point
    point: [hex coord]

  - species: grazer
    density: [3, 6]
    movement_type: path       # follows trajectory
    path: [hex coord sequence]
```

Movement types:
- **Random** — wander randomly within area
- **Path** — follow predefined trajectory (loop or ping-pong)
- **Static** — stay at a fixed point (ambush, nesting, hiding)

### Spawn rules
- Spawn governed by zone density + species activity cycle
- Days 1-3: No night fauna (learning period)
- Days 4+: Fauna spawns per zone density and activity
- Spawn tiles: within zone area, passable, no structures, outside active light radius

**Death drops:** Breakdown recipe (fauna_death_* .tres) — corpse prop → items. No hardcoded drops.

**Catalog integration:** Fauna has ENCOUNTERED state (first contact from darkness) before CATALOGED (full scan).

## Combat System — Universal Event-Driven

**Status:** Design (2026-04-10) — Andre's design

**One combat engine for fauna AND player.** Both use the same 3 event lists:

```yaml
# Player combat config (same structure as FaunaCap)
player_combat:
  hp: [100, 100]

  reactions: [
    # condition(fauna_adjacent + fauna_aggressive) → effect(enter_combat)
    # condition(hp < 20%) → effect(screen_flash_red)
  ]

  attacks: [
    # condition(has_tool: weapon) → effect(do_damage: weapon.damage)
    # condition(has_tool: axe) → effect(do_damage: axe.damage * 0.7)
    # condition(no_tool) → effect(do_damage: 1)  # fist
  ]

  defenses: [
    # condition(on_shelter) → effect(block_all)
    # condition(has_armor) → effect(reduce_damage: armor.value)
    # condition(default) → effect(take_damage: full)
  ]
```

The combat loop:
1. Reactions evaluated every game tick (proximity triggers, flee thresholds, call for help)
2. When in combat: attacker evaluates `attacks` list → resolver picks matching event
3. Defender evaluates `defenses` list → resolver picks matching event
4. Effects applied (damage, flee, block, special)

Adding new weapons, armor, special attacks, boss mechanics = adding Event .tres files. The combat engine evaluates events — it doesn't know what "sword" or "armor" means.

---

## Inventory

**Status:** Implemented (refactored delivery-005a)

**Weight-based system:**
- Primary constraint: total weight capacity (default 50.0)
- Items stored in 12 base slots + 4 tool slots
- Item weight from PropDef.portable.weight
- Items exceeding capacity rejected entirely (transport via MOVABLE + CONTAINER props)

**Storage tiers:**
- Backpack: 12 slots (diegetic — the backpack IS the inventory)
- Chest: 12 slots (static, craftable)
- Cart: mobile storage, movement speed penalty (future)

**Authoritative spec:** `.aid/work-001-core/delivery-005a/DESIGN.md`

See [data-model.md](data-model.md) §Inventory for the full schema.

---

## Scanning & Discovery

**Status:** Implemented

**The Bracelet** — military equipment worn on wrist. All HUD is diegetic (exists in game world via bracelet display).

**Bracelet functions:**
| Function | Role |
|----------|------|
| Biometrics | Health, hunger, thirst bars (suit sensors) |
| Scanner | Proximity scan — catalogs flora, fauna, minerals, anomalies |
| Flashlight | Night illumination (~2 hex range) |
| Mini-map | Terrain mapping (builds as player explores) |
| Beacon locator | Direction/distance back to pod |

**Two-tier scanning:**

| Tier | Range | Reveals | Mechanism |
|------|-------|---------|-----------|
| Long-range (Scanned) | Line of sight | Origin only (Natural vs Anomaly) | Automatic |
| Short-range (Identified) | 1 hex proximity | Category + full details | Auto-scan with progress bar |

**Scan time by origin:** Natural 1x, Crafted 0x (skip), Human 5x, Native Alien 20x, Unknown 50x

**Knowledge states:** UNKNOWN → ENCOUNTERED → CATALOGED

**Anomaly (derived state):** A prop is anomalous when scanned but not identified and origin is non-Natural/non-Crafted. Once identified, true origin is revealed.

**Recipe unlocking chain:** Catalog a prop → DiscoveryWatcher re-evaluates pending discovery Events → EventRegistry.try_fire() → grant_recipe effect → recipes granted → new gathering/crafting options appear. The scanner drives the entire progression.

---

## Cutscene System

### Level A — MVP (delivery-006 scope)

Pre-generated AI video cutscenes, shipped with the game as MP4 files.

- Cutscenes created offline using AI video generation tools (Sora, Kling, Runway, etc.)
- Triggered by gameplay events: anomaly discovered, first night survived, chapter milestones
- Played fullscreen via a `CutsceneManager` autoload
- Videos are FIXED — they don't change based on world state

**Trigger chain:** Player scans anomaly → Catalog.entry_cataloged → check properties.cutscene_id → CutsceneManager.play(id) → video plays → cutscene_finished → journal unlocks

**What's needed:**
- `CutsceneManager` autoload: receives cutscene_id, loads + plays video, emits cutscene_finished
- `data/cutscenes/` directory with MP4 files
- Trigger wiring from catalog events
- UI: fullscreen video player with skip button

**Art pipeline:** AI-generated with consistent style guide for visual coherence across videos.

### Level B — Vision (future R&D)

Dynamic cutscenes generated at runtime based on world state.

- Video generation API call with prompt built from current game state (biome, structures, time of day, inventory, discoveries)
- Each playthrough generates UNIQUE cutscenes
- Requires: API access, acceptable latency, prompt engineering, caching strategy

**Problems to solve:**
- Latency (seconds to minutes per generation)
- Cost (API calls per cutscene per player)
- Consistency (style anchoring across generated videos)
- Storage (caching — don't regenerate same state twice)
- Offline (mobile games need offline — Level B may require wifi)

**Decision (Andre, 2026-04-09):** Level A goes into delivery-006. Level B is R&D, not scheduled.

### Why This Is Differentiating

1. **AI-generated cinematics in a mobile indie game** — most indie games use static art or pixel animation. AI video generation collapses the AAA gap.
2. **Narrative stitching** — cutscene world IS the game world. Player agency bleeds into cinematic.
3. **Low marginal cost** — 15-second AI cutscene cheaper than hiring an animator.
4. **Emotional impact** — contrast between hex-grid gameplay and cinematic beauty creates emotional gut-punch at narrative beats.

---

## Progression Map

| Act | Zone | Mechanics That Activate | See Lore |
|-----|------|------------------------|----------|
| 1 | Far side (crash site area) | Basic survival, crafting, scanning, building, night fauna | [game-lore.md](game-lore.md) §Act 1 |
| 2 | Terminator zone | Planet-shine lighting, new biomes (volcanic, crystal), increased anomalies | [game-lore.md](game-lore.md) §Act 2 |
| 3 | Near side | Daily eclipse phase, tidal biomes, planet-shine fauna behavior | [game-lore.md](game-lore.md) §Act 3 |
| 4 | Super-Earth | 1.2g movement modifier, alien tech crafting, radiation hazards | [game-lore.md](game-lore.md) §Act 4 |

**Chapter 1 progression (free demo):**
- Days 1-2: Basic survival — gather, eat, drink, explore crash site
- Days 3-4: First nights with hostile fauna → shelter becomes urgent
- Days 5+: Shelter → workbench → tool upgrades → access blocked area → find anomaly
- Climax: Discover crashed pod + alien structure (dual cliffhanger)

**Difficulty curve:**
- Days 1-3: Peaceful. No night fauna. Learn the loop.
- Days 4-7: Mild night fauna. Build walls/shelter.
- Days 8-14: Stronger fauna. New biomes needed for advanced resources.
- Days 15+: Volcanic area accessible. Final push.

---

## Monetization

### Model: Free Demo + Premium Unlock

**Free:**
- Full gameplay for Days 1-5 (~25-30 minutes)
- All core mechanics available
- ~40% of map explorable
- Soft gate: "Your adventure continues..." + single non-intrusive unlock prompt

**Premium ($2.99 one-time):**
- Full game unlocked permanently
- All biomes, all resources, all crafting, escape ending
- Zero ads. Zero IAP. Zero premium currency.

**Future chapters:** ~$2.50 each (episodic model TBD)

### Anti-Patterns We Will NOT Do

- No ads between actions
- No "watch ad for 2x resources"
- No energy/timer systems
- No multiple currencies / premium currency
- No loot boxes / gacha / battle passes
- No "special offers" popups
- No social pressure mechanics

**Store description leads with:** "No ads. No fake coins. Pay once. Escape."

---

## Controls

**Mobile-first:**
- **Virtual joystick:** Hold anywhere on lower screen → joystick appears → free movement
- **Tap-to-move:** Tap a hex → character pathfinds to it (toggle in settings)
- **Tap resource** to gather (when adjacent)
- **Tap structure** to interact
- **Inventory button** — opens pack

**Camera:** Fixed isometric (no rotation). Player model rotates to face movement direction (smooth lerp). Same approach as My Little Universe.

**Rationale:** Rotating camera on mobile = motion sickness + fat finger issues. Fixed camera = consistent spatial awareness.

---

## Hex Scale — Physical Dimensions

| Measurement | Value |
|-------------|-------|
| Hex diameter | 6 meters |
| Hex area | ~28 m² |
| Human height | 1.80m (30% of hex diameter) |
| HEX_SIZE (Godot) | 3.0 units |
| Scale factor | 1 Godot unit = 2 real meters |

**Gameplay ranges:**

| System | Range | Real Distance |
|--------|-------|---------------|
| Auto-gather | ~1.5m circle | Arm's reach |
| Auto-scan | 1 hex (~6m) | "I can see what that is from here" |
| Camera viewport | ~8-12 hexes (~48-72m) | Natural mobile screen limit |

---

## Visual Style

- **Low-poly 3D** — stylized, runs on any device
- **Hex tiles clearly visible** — clean geometric aesthetic
- **Alien planet palette:** Teal sky, amber terrain, purple ruins, bioluminescent nights
- **Minimal HUD:** Day counter, stat bars (top), inventory button (bottom right)
- **No clutter** — no premium currency display, no offer buttons

---

## Technical Constraints

- **Min specs:** Android 8.0+ / iOS 14+, 2GB RAM
- **Target FPS:** 60 on mid-range, 30 on low-end
- **Performance budget:** <500 tris per object, <100 draw calls, <200MB memory, <100MB APK
- **Renderer:** Compatibility (decided, not yet applied)
- **Save system:** Local Dictionary serialization via FileAccess
- **No multiplayer**

---

*Consolidated 2026-04-09. Sources: GDD.md, crash-landing-design.md, game-mechanics-redesign-2026-04-06.md, feature-inventory.md, cutscene-vision.md*
