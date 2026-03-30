# Requirements

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-30 | Initial interview started | /aid-interview |
| 2026-03-30 | Interview complete — approved | /aid-interview |

## 1. Objective

Build a mobile survival/crafting game (Android + iOS) using Godot 4.x and GDScript. The player is an astronaut who crash-lands on an alien planet and must explore a procedurally generated hex-tile world, gather resources, craft tools, build structures, survive threats, and ultimately escape.

**Success criteria:**
- Playable on Android + iOS in portrait mode, touch-first controls
- Engaging 15–30 minute sessions (pick up, survive a few days, put down)
- Procedurally generated hex world (full game: 8 biome types)
- Core loop feels satisfying at every timescale: explore → gather → craft → survive → progress → escape
- Monetization: free demo (Days 1–5) with content gate → $2.99 one-time unlock
- Performance: 60 fps on mid-range devices (2022+ phones)

**This work (core) is the MVP:** hex grid rendering, player movement, resource gathering, basic crafting, day/night cycle, hunger/thirst/health, and 2–3 biomes. Not the full 8 biomes, not the escape ending, not all crafting recipes — just enough to prove the loop is fun.

## 2. Problem Statement

Mobile survival/crafting games (e.g., My Little Universe) have a proven, satisfying core loop — but they monetize through ads, fake currencies, energy timers, and psychological pressure. Players enjoy the gameplay but resent the exploitation.

The few premium alternatives that exist are not designed for true mobile-first play: they assume landscape orientation, long sessions, or complex controls. There is no ad-free, pay-once survival/craft game built specifically for portrait mode, quick 15–30 minute sessions, and simple touch controls.

Farhaven fills this gap: the same dopamine loop, none of the abuse, designed for how people actually play on phones.

## 3. Users & Stakeholders

### Primary Users
- **Casual mobile gamers (13+)** who enjoy survival/craft loops but are frustrated by predatory monetization (ads, fake currencies, timers)

### Secondary Users
- **Indie/premium mobile game fans** — the "I'd rather pay $3 than see one ad" crowd. Active on r/AndroidGaming, TouchArcade, and similar communities. Actively seek paid alternatives.

### Stakeholders
- **Andre Vianna & Lola Lovelace** — co-creators, design + development. No external investors, publisher, or client. 100% independent.

### Playtest Pipeline
1. Internal (Andre & Lola)
2. Friends & family
3. Small Discord community pre-launch

## 4. Scope

### In Scope (core MVP)
- Hex grid rendering + procedural map generation
- 3 procedural biomes (Grassland, Forest, Rocky) + Crash Site as scripted start zone
- Player movement (tap-to-move + virtual joystick)
- Resource gathering (Raw tier minimum)
- Basic crafting (Workbench level)
- Basic inventory UI (view gathered items, select crafting recipes)
- Day/night cycle with basic night threats
- Player stats: Hunger / Thirst / HP
- Portrait mode, touch-first UI
- Save system (serialize world state + player state to JSON)

### Out of Scope (this work)
- Full 8 biomes (Volcanic, Swamp, Ruins, Desert, Water)
- Ship repair / escape ending
- Advanced crafting chains (Furnace, Lab, Launch Pad)
- Monetization / demo gate implementation
- Audio / music
- Cloud save (Google Play Games + Apple Game Center — planned for later work)
- Store listings / publishing
- Multiplayer (not "later" — never. Game is designed single-player, architecture doesn't need networking)
- In-app purchases (none, ever — the entire product identity is anti-predatory)

### Monetization (full game context)
- $2.99 one-time unlock. No ads. No IAP. No premium currency.
- Future monetization only via cosmetic DLC or expansion packs, never consumable IAP.
- Day counter is the natural score. No formal scoring system in MVP. Post-MVP: speedrun timer, achievements, escape stats screen.

## 5. Functional Requirements

### F1. Hex Grid & World Generation
- Procedural hex map using axial/cube coordinates (~200–300 tiles)
- Biome assignment: Grassland, Forest, Rocky (weighted distribution + adjacency rules)
- Crash Site placed near center (scripted, not random)
- Fog of war — tiles reveal when player moves adjacent to them (not passively)

### F2. Player Movement & Controls
- Tap-to-move with A* pathfinding on hex grid
- Floating joystick: touch-and-hold anywhere on screen → joystick appears at touch point. Not a fixed button or zone.
- Hold = joystick (fine movement), Tap = pathfind (navigation). Both work simultaneously, no toggle needed.
- Ignore touches on HUD elements
- No stamina bar — player can always move, no artificial movement limits

### F3. Resource Gathering
- Tap resource when adjacent to gather
- Raw tier resources per biome (Wood, Stone, Berries, Fiber, etc.)
- Tool-gated resources:
  - Bare hands: Wood, Berries, Fiber
  - Stone Axe: thick trees, faster wood
  - Stone Pickaxe: Ore, Crystals
- Resource respawn: resources regenerate on tiles outside player's visible range. Respawn timer varies by resource type (values TBD). Some resources may not respawn (TBD). Resources never respawn while tile is visible.
- Gathering feedback (animation/SFX, even placeholder for MVP)

### F4. Crafting
- Workbench structure (5 Wood + 3 Stone) — required for crafting
- Progressive recipe discovery: recipes unlock when the player gathers a new material (avoids overwhelm early on)
- MVP recipes:
  - Tools: Stone Axe (Wood + Stone), Stone Pickaxe (Wood + Stone)
  - Structures: Shelter, Storage Chest, Wall, Torch, Bridge

### F5. Inventory
- Grid-based, limited slots (~12 base slots)
- View items and quantities
- Select items for crafting
- Expandable via Storage Chest (+12 slots per chest)

### F6. Building
- Place structures on hex tiles (one structure per tile)
- Structures have HP (can be damaged by night fauna)
- Structures block movement (walls, workbench) — important for night defense
- Shelter = safe zone at night (core purpose: player sleeps through night safely)

### F7. Day/Night Cycle
- Day (~3 min real time) → Dusk (30s warning, screen tint) → Night (~1.5 min) → Dawn
- Visual shift (lighting, tint changes)
- Night: visibility reduced to 1 hex around player

### F8. Survival Stats
- HP, Hunger, Thirst — visible HUD bars at top of screen
- Hunger depletes over time; zero = HP drain
- Thirst depletes faster than hunger; zero = faster HP drain
- Eat/drink to restore
- HP regenerates slowly during day
- No stamina bar (see F2)

### F9. Night Threats
- Days 1–3: peaceful, no fauna (onboarding period)
- Day 4+: simple fauna spawn at night outside lit/walled areas
- Fauna move toward player within 2 hexes, deal damage on contact
- Despawn at dawn
- Player can fight back with tools (slow, costly) or shelter (smart play)

### F10. Save System
- Auto-save at dawn (each new day) — mobile-friendly, no manual save needed
- Serialize world state + player state to local JSON via Godot FileAccess
- Single save slot (MVP)
- Corrupt/missing save = fresh start without crash
- Future: cloud save via Google Play Games + Apple Game Center (out of scope for core MVP)

### F11. Death & Respawn
- HP reaches 0 → respawn at Shelter (if built) or Crash Site (if not)
- Drop 50% of inventory (random items scatter on nearby tiles, recoverable)
- Day counter continues, doesn't reset
- If death at night → respawn at dawn
- No permadeath

### F12. HUD Layout
- Top: HP, Hunger, Thirst bars (compact horizontal)
- Top-right: Day counter ("Day 7") + time-of-day icon
- Bottom-right: Inventory button, Crafting button (when near Workbench)
- No fixed joystick zone (floating, appears at touch point)
- No minimap (fog of war is the point)
- Minimal, translucent — screen is the game, not the UI

## 6. Non-Functional Requirements

### Performance
- 60 fps on mid-range devices (2022+); 30 fps acceptable on low-end
- <500 tris per object, <100 draw calls per frame
- <200MB memory usage, <100MB APK size

### Platform
- Android 8.0+ / iOS 14+, 2GB RAM minimum
- 100% offline — no server, no account, no telemetry
- Portrait mode, 1080×1920 viewport

### Code Quality
- **Linting:** Godot built-in warnings (zero tolerance) + gdtoolkit/gdlint for automated checks
- **Naming:** snake_case (GDScript standard), PascalCase for class names only
- **Build policy:** Zero warnings. Manual export for MVP; GitHub Actions CI later.

### Testing
- **Framework:** GdUnit4 for unit tests
- **Coverage:** Critical pure-logic systems only — hex math, crafting recipes, survival stats, save/load. No coverage target number.
- **No render/UI tests** — manual playtesting for visual and interaction quality

### Accessibility (MVP)
- Touch targets sized for mobile (min 48×48 dp)
- Clear visual contrast between biome types
- (Further accessibility — font scaling, colorblind modes — deferred per GDD §16)

## 7. Constraints

### Technical
- **Engine:** Godot 4.x, GDScript only (no C#, no GDExtension)
- **No native plugins:** Everything via Godot APIs. No Google Play Games, Firebase, analytics SDKs. Keeps build simple and 100% offline.

### Team
- 2 people + AI agents: Andre (supervision, implementation oversight), Lola (design, coordination). AI agents (Claude Code, Codex) handle implementation. Not "2 devs" in the traditional sense.

### Budget (low, self-funded)
- ~$77 for art pipeline (Sloyd for base models + Tripo for refinement/variations)
- $25/year Apple Developer + $25 one-time Google Play
- Godot = free, GitHub = free
- Time is invested, not "free"

### Art Pipeline (decided — see docs/02-visual-assets-pipeline.md)
- Sloyd for base 3D models (account created)
- Tripo for refinement/variations (~$77 for ~150 models estimated)
- Low-poly aesthetic, stylized not realistic
- MVP uses placeholder art (colored hex tiles + primitive shapes); real assets later

### Timeline
- No hard deadline — "done when it's done"
- Soft goal: playable prototype (core loop working, placeholder art) within ~4–6 weeks
- If not playable in 6 weeks, the approach needs revisiting (gut check, not deadline)

## 8. Assumptions & Dependencies

### Assumptions
- Godot 4.x latest stable is mature enough for mobile export (Android + iOS)
- Single-threaded GDScript performance is adequate for ~300-tile hex map with simple AI (A* on 300 nodes is trivial; fauna AI is O(n) with n ≈ 5–10 creatures). Rendering is the bottleneck, not logic.
- Hex grid math (axial/cube coordinates) maps cleanly to Godot's node system — well-documented via Red Blob Games
- Touch input latency on mobile Godot is acceptable (<100ms for tap-to-move responsiveness)
- Godot's FileAccess is reliable for local save/load on both Android and iOS sandboxes
- Placeholder art is sufficient to validate the core loop with playtesters
- $2.99 price point is viable for indie mobile market (validated by comparables: Stardew Valley mobile, Slay the Spire, etc.)
- **No multiplayer, ever.** This is a design decision, not a deferral. Architecture does not need to account for networking, sync, or shared state.

### Dependencies

**Code dependencies:**
- Godot 4.x latest stable (engine)
- GdUnit4 (unit test framework)
- gdtoolkit/gdlint (linting)

**Design dependency:**
- Red Blob Games hexagonal grids guide — reference implementation for all hex math

**Build dependencies:**
- Godot Export Templates: Android (SDK/NDK) + iOS (Xcode on Mac)
- Sloyd + Tripo accounts (art assets, post-MVP)

## 9. Acceptance Criteria

### AC1 — Hex Grid & World Gen
- [ ] Generate 3 different maps → all have 200–300 tiles
- [ ] All 3 biomes + Crash Site present in every map
- [ ] Crash Site within 3 hexes of center
- [ ] No two adjacent tiles with same biome exceed cluster of 5
- [ ] Fog tiles not visible until player moves adjacent

### AC2 — Movement
- [ ] Tap any revealed tile → character arrives via shortest path
- [ ] Path avoids impassable tiles (water, structures)
- [ ] Joystick appears at touch point on hold, character moves continuously
- [ ] Both input modes work without settings toggle
- [ ] Input-to-first-movement-frame < 100ms (measured)

### AC3 — Gathering
- [ ] Tap tree with bare hands → +1 Wood in inventory
- [ ] Tap ore with bare hands → nothing happens (tool-gated)
- [ ] Tap ore with Stone Pickaxe equipped → +1 Ore
- [ ] Resource node depletes after N gathers and visually changes
- [ ] Depleted resource on non-visible tile regenerates after type-specific timer

### AC4 — Crafting
- [ ] Player has 5 Wood + 3 Stone → Workbench recipe visible
- [ ] Player has 2 Wood + 0 Stone → Workbench recipe greyed out
- [ ] Player gathers Stone for first time → Stone Axe recipe appears
- [ ] Craft Stone Axe → materials consumed, tool in inventory

### AC5 — Inventory
- [ ] Start with 12 empty slots
- [ ] Pick up 13th unique item without Storage Chest → rejected with feedback
- [ ] Build Storage Chest → inventory expands to 24 slots
- [ ] Items stack with quantity display

### AC6 — Building
- [ ] Place Workbench on empty hex → occupied, blocks movement
- [ ] Try to place on occupied hex → rejected
- [ ] Shelter built → player inside at night takes 0 damage
- [ ] Wall built → fauna pathfinding routes around it
- [ ] Fauna attacks unprotected structure → HP decreases

### AC7 — Day/Night
- [ ] Full cycle completes in 5 min ±15s (measurable)
- [ ] Dusk warning visible/audible 30s before night
- [ ] Night: only tiles within 1 hex of player visible
- [ ] Torch placed: extends visibility to 2 hexes around torch

### AC8 — Survival Stats
- [ ] HUD shows 3 bars at all times
- [ ] Hunger reaches 0 → HP decreases by X/sec
- [ ] Eat Berries → Hunger increases by defined amount
- [ ] All three stats at 0 → player dies → respawn with 50% inventory drop

### AC9 — Night Threats
- [ ] Day 3 night → zero fauna spawn
- [ ] Day 4 night → 1–3 fauna spawn outside lit/walled area
- [ ] Fauna within 2 hexes → moves toward player
- [ ] Fauna contacts player → HP damage (defined amount)
- [ ] Dawn → all fauna despawn within 1 cycle

### AC10 — Save System
- [ ] Dawn triggers → save file exists on disk
- [ ] Kill app → reopen → world state matches (tiles, structures, resources)
- [ ] Kill app → reopen → player state matches (inventory, stats, position, day count)
- [ ] Corrupt/delete save → game starts fresh without crash

## 10. Priority

### P0 — Foundation
| Feature | Rationale |
|---------|-----------|
| F1 Hex Grid | Can see the world |
| F2 Movement | Can move in the world |

### P0 — Core Loop
| Feature | Rationale |
|---------|-----------|
| F3 Gathering | First interaction with the world |
| F5 Inventory | Store what you gathered |
| F4 Crafting | Transform resources into tools/structures |
| F8 Survival Stats | Stakes — hunger/thirst create urgency |

### P0 — Persistence
| Feature | Rationale |
|---------|-----------|
| F7 Day/Night | Time pressure, pacing |
| F10 Save | Don't lose progress — essential for playtesting iteration |

### P1 — Tension
| Feature | Rationale |
|---------|-----------|
| F6 Building | Shelter, walls, defense — gives crafting purpose |
| F9 Night Threats | Stakes for the night cycle — makes building matter |

### Build Order Notes
- **Linear dependency chain within P0:** Grid → Movement → Gathering → Inventory → Crafting (each depends on the previous)
- **Day/Night and Save can be built in parallel** with the Crafting stage
- Save should be implemented incrementally: start with hex grid + stats serialization, add fields as features come online
- **P1 is playable-without, not unimportant.** The core loop works without building/threats (boring, but testable). Without inventory or crafting, there's no game at all.
