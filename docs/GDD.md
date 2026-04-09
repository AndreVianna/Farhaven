> **SUPERSEDED:** This document is historical. The authoritative version is `.aid/knowledge/game-mechanics.md`.

# FARHAVEN — Game Design Document

**Working Title:** Farhaven
**Genre:** Casual Survival / Crafting / Exploration
**Platform:** Android + iOS
**Engine:** Godot 4.x (GDScript)
**Monetization:** Free demo → $2.99 one-time unlock (no ads, no IAP, no premium currency)
**Target:** 13+, casual mobile gamers who like survival/craft but hate predatory monetization
**Inspiration:** My Little Universe (gameplay loop), Don't Starve (atmosphere/urgency), Islanders (hex aesthetics)
**Authors:** Andre Vianna & Lola Lovelace
**Date:** 2026-03-30

---

## 1. Elevator Pitch

You're an astronaut who crash-lands on an unknown planet. Explore a hex-tile world, gather resources, craft tools, build a base, survive the nights — and ultimately repair your ship to escape. 

**No ads. No fake currency. No timers. Just a planet to escape.**

---

## 2. Core Fantasy

The player IS the lone survivor. No backstory dump, no cutscenes. You wake up next to a wrecked ship on an alien planet. Everything you need to know is visible: broken ship, strange terrain, a setting sun. Figure it out or die here.

---

## 3. Core Loop

```
EXPLORE → GATHER → CRAFT → BUILD → SURVIVE → ESCAPE
  ↑                                          |
  └──────────────────────────────────────────┘
```

Each "day" the player:
1. **Explores** new hex tiles (fog of war reveals on move/adjacency)
2. **Gathers** resources from tiles (chop, mine, collect)
3. **Crafts** tools and materials at workbench/base
4. **Builds** structures on hex tiles (shelter, machines, defenses)
5. **Survives** the night cycle (threats increase)
6. **Progresses** toward the escape goal (ship parts)

The loop is satisfying at every scale:
- **Micro (30 seconds):** Tap tree → get wood → feels good
- **Meso (5 minutes):** Gather enough to craft a new tool → unlocks new resource type
- **Macro (hours):** Find last ship component → build launch pad → escape

---

## 4. The World

### 4.1 Hex Grid
- Procedurally generated hex map per playthrough
- Fog of war — tiles reveal when adjacent to player or explored
- Each hex has a **biome type** that determines resources and hazards
- Map size: ~200-300 tiles (enough to explore across the full game without feeling infinite)
- Ship crash site is always near center

### 4.2 Biome Types

| Biome | Color | Resources | Hazard |
|-------|-------|-----------|--------|
| **Forest** | Green | Wood, Fiber, Berries | Thorns (damage) |
| **Rocky** | Grey | Stone, Ore, Crystals | Rockslide (blocks path) |
| **Water** | Blue | Water, Fish, Algae | Drowning (impassable without bridge) |
| **Desert** | Yellow | Sand, Glass, Fuel Deposits | Heat (faster thirst drain) |
| **Swamp** | Dark green | Mud, Bio-matter, Rare Herbs | Poison (slow damage) |
| **Ruins** | Purple | Alien Tech, Circuits, Data Cores | Traps (one-time damage) |
| **Volcanic** | Red/Orange | Metal, Magma Crystal, Energy | Eruption (timed area damage) |
| **Crash Site** | Unique | Scrap Metal, Wiring | Starting area, safe |

### 4.3 Day/Night Cycle
- **Day:** Safe exploration. Full visibility on revealed tiles. ~3 minutes real time.
- **Dusk:** Warning phase. Screen tints. 30 seconds to get back to shelter.
- **Night:** Dangerous. Visibility reduced to 1 hex. Hostile fauna active. Temperature drops. ~1.5 minutes.
- **Dawn:** Night ends. New day counter.

One full day/night cycle = ~5 minutes real time.

---

## 5. Player

### 5.1 Character
- Unnamed astronaut in a suit
- Simple silhouette design (like MLU bean but sci-fi)
- No dialogue, no personality — the player IS the character
- Visible equipment changes (better tools, upgraded suit)

### 5.2 Stats (minimal, visible)
- **HP** — damage from hazards, fauna, traps. Regen slowly during day. 
- **Hunger** — depletes over time. Eat food to restore. Zero = HP drain.
- **Thirst** — depletes faster than hunger. Drink water. Zero = HP drain faster.
- **No stamina bar** — no artificial movement limits. You can always run.

### 5.3 Controls
- **Tap-to-move** mode: Tap a hex → character pathfinds to it
- **Virtual joystick** mode: Hold anywhere on lower screen → joystick appears → free movement
- Toggle in Settings. Both always available.
- **Tap resource** to gather (when adjacent)
- **Tap workbench/structure** to interact
- **Inventory button** — opens pack (grid-based, limited slots)

---

## 6. Resources & Crafting

### 6.1 Resource Tiers

| Tier | Examples | Source | Unlocked By |
|------|----------|--------|-------------|
| **Raw** | Wood, Stone, Water, Berries | Direct gathering | Start |
| **Processed** | Planks, Cut Stone, Clean Water, Rope | Workbench | Workbench craft |
| **Advanced** | Metal Ingots, Circuits, Glass, Fuel | Furnace/Lab | Furnace craft |
| **Alien** | Data Cores, Alien Alloy, Quantum Cells | Ruins exploration | Decryptor craft |

### 6.2 Tool Progression

| Tool | Crafted From | Unlocks |
|------|-------------|---------|
| **Bare Hands** | — | Wood, Berries, Fiber |
| **Stone Axe** | Wood + Stone | Faster wood, access to thick trees |
| **Stone Pickaxe** | Wood + Stone | Ore, Crystals |
| **Metal Axe** | Wood + Metal Ingot | Hardwood, rare plants |
| **Metal Pickaxe** | Wood + Metal Ingot | Deep ore, gems |
| **Alien Multi-tool** | Metal + Alien Alloy + Circuit | All resources, faster |

### 6.3 Craft Tree (simplified)

```
Raw Materials
  └→ Workbench (Wood + Stone)
       ├→ Tools (axes, picks, bridges)
       ├→ Shelter (walls, roof, door → safe at night)
       └→ Storage (expand inventory)
  
  └→ Furnace (Stone + Ore + Fiber)
       ├→ Metal Ingots
       ├→ Glass (Sand)
       └→ Processed materials

  └→ Lab (Metal + Crystal + Circuit)
       ├→ Decryptor (read alien tech)
       ├→ Fuel Refinery
       └→ Ship Components

  └→ Launch Pad (final build)
       ├→ Hull Plates (Metal + Alien Alloy)
       ├→ Engine (Metal + Fuel + Magma Crystal)
       ├→ Nav Computer (Circuit + Data Core × 3)
       ├→ Fuel Tank (Metal + Fuel × lots)
       └→ 🚀 ESCAPE
```

---

## 7. Building

- Place structures on hex tiles
- Each structure occupies one hex
- Structures have HP (can be damaged at night by fauna)
- Core structures:

| Structure | Cost | Function |
|-----------|------|----------|
| **Workbench** | 5 Wood + 3 Stone | Basic crafting |
| **Shelter** | 10 Wood + 5 Stone + 3 Fiber | Safe at night, save point |
| **Storage Chest** | 8 Wood + 2 Metal | +12 inventory slots |
| **Furnace** | 10 Stone + 5 Ore + 3 Fiber | Smelting, advanced crafting |
| **Lab** | 5 Metal + 3 Crystal + 2 Circuit | Alien tech crafting |
| **Wall** | 3 Stone or 3 Wood | Block fauna movement |
| **Bridge** | 5 Wood + 2 Rope | Cross water tiles |
| **Torch** | 2 Wood + 1 Fiber | Extends night visibility +1 hex |
| **Fuel Refinery** | 8 Metal + 3 Glass + 2 Circuit | Converts deposits → Fuel |
| **Launch Pad** | 15 Metal + 10 Stone + 5 Alien Alloy | Final structure — escape |

---

## 8. Threats

### 8.1 Night Fauna
- Simple creatures that spawn at night outside lit/walled areas
- Move toward player if within 2 hexes
- Deal damage on contact
- Despawn at dawn
- **NOT the focus of the game** — night is a timer/pressure, not a combat game
- Player can fight back with tools (slow, costly) or hide in shelter (smart)

### 8.2 Environmental
- **Heat** (desert): Thirst drains 2×
- **Cold** (night): Hunger drains 1.5×
- **Poison** (swamp): Slow HP drain for 30s
- **Eruption** (volcanic): Timed AoE damage — get off the tile
- **Traps** (ruins): One-time damage when entering, then safe

### 8.3 Difficulty Curve
- Days 1-3: Peaceful. Learn the loop. No night fauna.
- Days 4-7: Night fauna appear. Mild. Build walls/shelter.
- Days 8-14: Fauna stronger. New biomes needed for advanced resources.
- Days 15+: Volcanic area accessible. Final push. Fauna aggressive.

---

## 9. Progression & Win Condition

### 9.1 Main Goal
Repair your ship and escape the planet.

**Ship requires 4 components** (each a significant crafting chain):
1. **Hull Plates** — Metal Ingots + Alien Alloy (need ruins exploration)
2. **Engine** — Metal + Fuel + Magma Crystal (need volcanic biome)
3. **Nav Computer** — Circuits + 3 Data Cores (scattered in ruins across map)
4. **Fuel Tank** — Metal + large quantity of refined Fuel

### 9.2 Natural Task System
No explicit quest log. The ship at crash site visually shows what's missing. Player sees:
- Empty hull frame → need Hull Plates
- No engine → need Engine
- Dark cockpit → need Nav Computer
- Empty fuel gauge → need Fuel

Each component installed = visible change on the ship. The ship IS the progress bar.

### 9.3 Estimated Playtime
- **Free demo (Days 1-5):** ~25-30 minutes. Player builds base, crafts first tools, explores nearby biomes, encounters first night. Hook is set.
- **Full game (Days 1-20+):** ~3-5 hours total. Enough for a satisfying arc, short enough to replay.

---

## 10. Monetization

### 10.1 Model: Free Demo + Premium Unlock

**Free:**
- Full gameplay for Days 1-5
- All core mechanics available
- Player can build base, craft tools, explore ~40% of map
- Ends with a soft gate: "Your adventure continues..." + single non-intrusive unlock prompt

**Premium ($2.99 one-time):**
- Full game unlocked permanently
- All biomes, all resources, all crafting, escape ending
- Zero ads ever. Zero IAP ever. Zero premium currency ever.

### 10.2 Anti-patterns We Will NOT Do
- ❌ Ads between actions
- ❌ "Watch ad for 2× resources"
- ❌ Energy/timer systems
- ❌ Multiple currencies
- ❌ Premium currency
- ❌ Loot boxes / gacha
- ❌ Battle passes
- ❌ "Special offers" popups
- ❌ Social pressure mechanics

### 10.3 Pricing Rationale
- $2.99 is impulse-buy territory
- "No ads" is a selling point, not a punishment
- Target: players frustrated with predatory mobile games
- Store description leads with: **"No ads. No fake coins. Pay once. Escape."**

---

## 11. Visual Style

### 11.1 Art Direction
- **Low-poly 3D** — similar vibe to MLU but with sci-fi palette
- **Hex tiles clearly visible** — clean geometric aesthetic (Islanders-like)
- **Alien planet palette:** Teal sky, amber terrain, purple ruins, bioluminescent nights
- **No realistic textures** — stylized, runs on any device
- **Planet curvature optional** — if feasible in Godot, adds charm (MLU does this well)

### 11.2 UI
- **Minimal HUD:** Day counter, HP/Hunger/Thirst bars (top), inventory button (bottom right)
- **No clutter** — no premium currency display, no offer buttons, no notification badges
- **Task hint** (optional): Small text showing current logical next step. Non-intrusive. Can be disabled.
- **Ship status:** Visible at crash site. 4 component slots. Visual progress.

### 11.3 Audio
- Ambient alien planet sounds (wind, distant fauna, crystal hums)
- Satisfying gathering SFX (chop, mine, splash, craft complete)
- Night: tense ambient shift, distant growls
- Minimal music — ambient pads, not memorable themes (saves budget, fits mood)

---

## 12. Technical

### 12.1 Stack
- **Engine:** Godot 4.x
- **Language:** GDScript (Python-like, native to Godot — stable mobile export, zero marshalling overhead)
- **Platforms:** Android (Google Play) + iOS (App Store)
- **Min specs:** Android 8.0+ / iOS 14+, 2GB RAM
- **Target FPS:** 60 on mid-range, 30 on low-end
- **Offline:** 100% offline. No server, no account, no telemetry.

### 12.2 Architecture Considerations
- Hex grid system (axial/cube coordinates)
- Procedural map generation with biome rules (adjacency, distribution)
- Simple state machine for day/night cycle
- Node-based architecture (Godot's scene tree, not ECS)
- Save system: local JSON via Godot's FileAccess per slot
- No multiplayer (scope control)

### 12.3 Performance Budget
- Low-poly models: <500 tris per object
- Texture atlas: single atlas per biome
- Draw calls: target <100 per frame
- Memory: <200MB total
- APK size: target <100MB

---

## 13. Scope Control

### 13.1 MVP (v1.0 — Launch)
- ✅ Hex grid procedural map (5 biome types: Forest, Rocky, Water, Desert, Ruins)
- ✅ Player movement (tap + joystick)
- ✅ Resource gathering (3 tiers: Raw, Processed, Advanced)
- ✅ Crafting system (workbench → furnace → lab → launch pad)
- ✅ Building (shelter, storage, walls, bridge, torch)
- ✅ Day/night cycle with night fauna
- ✅ Hunger + Thirst
- ✅ Ship repair (4 components) + escape ending
- ✅ Free demo (Days 1-5) + $2.99 unlock
- ✅ Android + iOS

### 13.2 Post-Launch (v1.1+) — Only If Traction
- 🔜 Volcanic + Swamp biomes
- 🔜 Alien Multi-tool
- 🔜 Planet variety (different seed = different planet type)
- 🔜 Achievements
- 🔜 Leaderboard (fastest escape time)
- 🔜 Daily challenge planets

### 13.3 Will NOT Build (scope creep traps)
- ❌ Multiplayer
- ❌ Base defense tower-defense mode
- ❌ Complex combat system
- ❌ NPC dialogue / story quests
- ❌ Pets / companions
- ❌ Seasonal events
- ❌ Cloud save (v1.0 — consider later)

---

## 14. Competitive Positioning

| Feature | My Little Universe | Farhaven |
|---------|-------------------|---------|
| Genre | Casual Survival/Craft | Casual Survival/Craft |
| Grid | Organic tiles | Hex grid (strategic) |
| Theme | Fantasy/Nature | Sci-fi/Alien planet |
| Win condition | None (endless) | Escape the planet |
| Day/Night | No | Yes (adds urgency) |
| Monetization | Ads + 3 currencies + IAP | Free demo → $2.99 once |
| Ads | Constant, intrusive | Zero |
| Premium currency | Yes (gems, coins) | None |
| Offline | Yes | Yes |
| Combat | Minimal | Minimal (survival, not combat) |

**Our positioning:** The survival/craft game that respects your time and money.

---

## 15. Success Metrics

### Launch (Month 1)
- 1,000+ downloads (organic + launch push)
- 4.5+★ rating
- >5% free→paid conversion

### Traction (Month 3)
- 10,000+ downloads
- Positive reviews mentioning "no ads" as differentiator
- Conversion rate stable >5%

### Growth (Month 6)
- 50,000+ downloads
- Revenue covering development cost
- Community forming (Discord/Reddit)

---

## 16. Open Questions

1. **Planet curvature** — Is it technically feasible in Godot with hex grid? Research needed.
2. **Art pipeline** — Low-poly 3D models: asset store, AI-generated, or hand-made?
3. **Sound** — License ambient packs or generate?
4. **Name** — "Farhaven" is working title. Final name TBD. Needs to be searchable and memorable.
5. **Localization** — English + Portuguese (BR) at launch? More languages later?
6. **Accessibility** — Font scaling, colorblind modes, one-handed play?

---

*"The same dopamine. None of the abuse."*
