# Requirements

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-30 | Initial interview started | /aid-interview |
| 2026-03-30 | Interview complete — approved | /aid-interview |
| 2026-03-30 | Cross-ref: Split Build vs Craft — Build button always visible for structures, Craft only near Workbench | /aid-interview (IQ1) |
| 2026-03-30 | Cross-ref: Storage Chest recipe changed to Raw-tier only for MVP; Campfire noted for future work | /aid-interview (IQ2) |
| 2026-03-30 | Cross-ref: Grassland defined as safe starter biome, distinct from Forest; progression curve established | /aid-interview (IQ3) |
| 2026-03-30 | Cross-ref: Water tiles as impassable terrain in worldgen; Bridge stays in MVP (6 Wood + 2 Fiber) | /aid-interview (IQ4) |
| 2026-03-30 | Added hex elevation system — tiles have height, steep elevation impassable in MVP (Climbing Gear deferred) | User request |
| 2026-03-30 | Deferred Bridge to future work — water tiles fully impassable in MVP | User request |
| 2026-03-31 | MAJOR REDESIGN — New identity (curiosity+story), episodic chapters, auto-interaction, scanner/catalog, journal, fauna/flora redesign, Tactical Brutalism discarded | User redesign |
| 2026-03-31 | Scanning as universal gate — ❓ = inert to auto-system. Surprise attack auto-catalogs hostile fauna. | User clarification |
| 2026-04-01 | §11 Game Initialization added — bootstrap sequence, extension points, dev environment | /audit-fix |
| 2026-04-01 | [PIVOT] §5 F2: joystick-only movement. Tap reserved for interactions. §9 AC2 updated. | /design-pivot |
| 2026-04-01 | [PIVOT] §5 F1: hand-crafted maps (MapLoader replaces WorldGenerator). Elevation 0-9, 3-tier traversal. §9 AC1+AC2 updated. | /design-pivot |
| 2026-04-01 | C1+C6: HEX_SIZE=3.0 and ELEVATION_STEP=0.5 added to §5 F1 Spatial Constants. Player occupancy ~30% noted. C2: Cliff faces added as current scope. | /pivot-cascade |
| 2026-04-02 | Scan redesign: F2 removed press-and-hold reference, F13 rewritten for proximity auto-scan + 3-state knowledge, AC2 removed scan hold criterion, AC11 rewritten for proximity scan + ENCOUNTERED state. §4 updated. | /scan-redesign-apply |
| 2026-04-03 | Review fixes: Grassland resources (Grass→Wood), build order notes updated | /aid-specify review |
| 2026-04-04 | ARCHITECTURE: Sub-hex grid (19 sub-hexes per main hex, axial sq/sr coords) for prop placement. Unified props[] list replaces separate resources/structure/anomaly fields on tiles. | Architecture decision (Andre + Lola) |

## 1. Objective

Build a mobile exploration/survival game (Android + iOS) using Godot 4.x and GDScript. An astronaut crash-lands on an alien planet. Explores a beautiful, mysterious hex-tile world. Gathers resources, builds shelter, catalogs flora/fauna/minerals with a scanner, and discovers that the supposedly "uninhabited" planet shows signs of civilization. The story is told through the astronaut's Journal, fed by scanner discoveries.

**Feeling references:**
- My Little Universe (progress satisfaction, walk around and things happen, visually pleasant)
- Subnautica (scanner as core mechanic, narrative mystery, beautiful but dangerous planet)
- The game evolves across chapters from MLU (casual, colorful, relaxed) toward Subnautica (deep, mysterious, narrative-driven)

**Tone and aesthetics:**
- Visually charming and pleasant — NOT dark
- NOT too difficult — challenge exists but is gentle
- The player's drive is CURIOSITY and STORY, not difficulty or punishment
- Colorful, warm, charming low-poly. Astroneer meets MLU — sci-fi but welcoming
- The planet is alien but beautiful, not hostile. Colors say "explore here"
- Tactical Brutalism is DISCARDED — wrong vibe. Design system TBD: vibrant colors, soft shapes, sci-fi but warm

**Success criteria:**
- Playable on Android + iOS in portrait mode, touch-first controls
- Engaging 15–30 minute sessions (commute-friendly chapters)
- Hand-crafted hex world with narrative elements
- Core loop: explore → gather → scan → catalog → discover story → progress
- Monetization: Chapter 1 free, Chapter 2+ ~$2.50 each (episodic)
- Performance: 60 fps on mid-range devices (2022+ phones)

**This work (core) is Chapter 1:** hex grid, movement, auto-gathering, basic crafting, day/night cycle, hunger/thirst/health, scanner/catalog basics, first anomaly, journal foundation. Enough to hook the player and make them want Chapter 2.

## 2. Problem Statement

Mobile survival/crafting games (e.g., My Little Universe) have a proven, satisfying core loop — but they monetize through ads, fake currencies, energy timers, and psychological pressure. Players enjoy the gameplay but resent the exploitation.

The few premium alternatives lack story and discovery. They're endless sandbox loops with no narrative reason to keep playing. And they're not designed for true mobile-first play: landscape orientation, long sessions, complex controls.

Farhaven fills the gap: the same satisfying exploration/gathering loop, a compelling mystery that drives curiosity, episodic chapters that respect your wallet, designed for how people actually play on phones.

**Target player:** A casual mobile gamer who likes to explore and wants a story. Not a hardcore gamer. Not an idle player. Someone who plays 15-30 minutes on their commute and wants to know what happens in the next chapter.

## 3. Users & Stakeholders

### Primary Users
- **Casual mobile gamers (13+)** who enjoy exploration/craft loops, want a story, and are frustrated by predatory monetization (ads, fake currencies, timers)

### Secondary Users
- **Indie/premium mobile game fans** — the "I'd rather pay $2.50 than see one ad" crowd. Active on r/AndroidGaming, TouchArcade, and similar communities. Drawn to narrative + discovery.

### Stakeholders
- **Andre Vianna & Lola Lovelace** — co-creators, design + development. No external investors, publisher, or client. 100% independent.

### Playtest Pipeline
1. Internal (Andre & Lola)
2. Friends & family
3. Small Discord community pre-launch

## 4. Scope

### In Scope (Chapter 1 / core MVP)
- Hex grid rendering + hand-crafted map loading
- 3 biomes (Grassland, Forest, Rocky) + Crash Site + Water tiles (impassable terrain)
- Player movement (virtual joystick only — tap reserved for interactions)
- Auto-interaction system (proximity-based gathering, auto-pickup, auto-defend)
- Resource gathering (Raw tier, tool-gated)
- Basic crafting (Workbench level)
- Basic inventory UI (resource slots + tool slots)
- Scanner system (proximity-based auto-scan of unknown elements, 3-state knowledge, catalog entries)
- Catalog UI (Flora, Fauna, Minerals, Anomalies categories)
- Journal foundation (story timeline + catalog sections, at least 1 anomaly + cutscene trigger)
- Day/night cycle with basic night threats
- Player stats: Hunger / Thirst / HP
- Building (Workbench, Shelter, Storage Chest, Wall, Torch)
- Portrait mode, touch-first UI
- Save system (serialize world state + player state to JSON)
- Architecture supports future chapters (modular content, chapter state tracking)

### Out of Scope (this work)
- Full 8 biomes (Volcanic, Swamp, Ruins, Desert, Water as full biome)
- Ship repair / escape ending
- Advanced crafting chains (Furnace, Lab, Launch Pad)
- Chapter 2+ content
- Chapter purchase / unlock implementation
- Audio / music
- Cloud save (Google Play Games + Apple Game Center)
- Store listings / publishing
- Climbing Gear (traversal over steep elevation — deferred)
- Bridge (crossing water tiles — deferred)
- Multiplayer (not "later" — never)
- In-app purchases (none, ever)
- Full cutscene production (Chapter 1 uses placeholder/comic panels)

### Monetization (full game context)
- **Episodic chapters.** Chapter 1 is free. Chapter 2+ are ~$2.50 each.
- Zero ads. Zero IAP. Zero premium currency. One-time payment per chapter, complete content.
- Like comic books — each chapter is an episode. Player buys the next when they want to know what happens.
- Day counter is the natural score. No formal scoring system in MVP.

**Planned narrative arc:**
1. Chapter 1 — Crash, survive, build base, discover first anomaly (FREE)
2. Chapter 2 — Explore further, lost civilization, another crash site
3. Chapter 3 — Escape the planet, intermediary space station
4. Chapter 4+ — Final destination, story resolution

## 5. Functional Requirements

### F1. Hex Grid & World
- **[PIVOT] Hand-crafted hex maps** loaded from JSON level files. Each chapter has a designed map (~200–300 tiles). MapLoader replaces WorldGenerator.
- Biome types: Grassland, Forest, Rocky, Crash Site, Water
  - **Grassland:** Open, safe starter biome. Resources: Wood, Berries, Fiber. No hazards.
  - **Forest:** Dense, more wood. Resources: Wood, Fiber, Berries (thick trees tool-gated). Hazard: Thorns (damage).
  - **Rocky:** Stone, Ore, Crystals. Hazard: Rockslide (blocks path).
- Natural progression curve: Crash Site → Grassland → Forest → Rocky
- Crash Site at map origin (0,0)
- Water tiles: impassable terrain barriers. Impassable in core MVP (Bridge deferred).
- **[PIVOT] Elevation 0–9 per tile.** 3-tier traversal:
  - Diff 0–1: Walk (smooth mesh transition)
  - Diff 2–3: Auto-jump up / auto-drop down (gap, no connecting mesh)
  - Diff 4+: Blocked (cliff, future wall texture)
  - Asymmetric gravity: dropping faster than jumping. Both auto-triggered, no input.
- **Spatial constants (define world scale):**
  - `HEX_SIZE = 3.0` — world-space size of one hex (center to corner). Diameter = 6.0m. All spatial calculations derive from this constant.
  - `SUB_HEX_SIZE = HEX_SIZE / 5.0` (0.6) — sub-hex center to corner. Diameter = 1.2m.
  - `ELEVATION_STEP = 0.5` — world units of Y offset per elevation level. Total height range: 0–4.5 world units.
  - Player visual occupies ~30% of hex width (~0.9 units at HEX_SIZE=3.0)
- **Sub-hex grid (prop placement granularity):**
  - Each main hex contains 19 sub-hexes: 1 center + 6 inner ring + 12 outer ring
  - Sub-hexes use axial coordinates (sq, sr) — same system as the main grid at smaller scale
  - Center = (0,0). Inner ring = radius 1 neighbors. Outer ring = radius 2 neighbors.
  - Full world address of any prop: (q, r, sq, sr) — main hex + sub-hex position
  - World position: `hex_center(q, r) + axial_to_pixel(sq, sr) * sub_scale`
  - **Main hex** = unit of gameplay (movement, fog, biome, elevation, pathfinding)
  - **Sub-hex** = unit of placement (where props sit WITHIN the hex)
- **Unified props model:**
  - Each tile has a single `props[]` list containing ALL placed content: resources, structures, anomalies, spawn markers
  - Each prop has: `type` (StringName), `sub_hex` (Vector2i — sq, sr), `category` (resource/structure/anomaly/spawn)
  - Structures have `footprint: Array[Vector2i]` — the sub-hexes they occupy
  - The hex is a container. The prop's type/category defines its behavior.
  - See `docs/design/sub-hex-grid-impact.md` for full architecture decision.
- **Cliff faces:** Flat vertical quads between adjacent hexes at different elevations. Higher tile's biome color × 0.6. Part of the hex ArrayMesh (zero extra draw calls). Current scope, not deferred.
- Fog of war — tiles reveal when player moves adjacent
- **Anomaly tiles:** Hand-placed by level designer as props with `category: "anomaly"`. Scanned to unlock story content.

### F2. Player Movement & Controls
- **[PIVOT] Joystick-only movement.** Floating joystick: touch-and-drag anywhere on screen → joystick appears at touch point. Continuous movement (not tile-snapped during motion).
- **Tap on world = no movement.** Tap is reserved for UI buttons and world interactions (building placement, future object inspect).
- **Proximity auto-scan:** walking near unknown elements starts scanning automatically (see F13)
- Ignore touches on HUD elements
- **[PIVOT] 3-tier elevation traversal:** Walk (0-1), auto-jump/drop (2-3), blocked (4+)
- Player position is continuous; `current_tile` is derived from position
- On joystick release, player snaps to current tile center
- No stamina bar

### F3. Resource Gathering — AUTO-INTERACTION
- **Auto-gather on proximity — cataloged elements only.** Player moves adjacent to a cataloged resource → gathering starts automatically. No tap required. **Uncataloged elements (❓) do NOT auto-gather.** Player must scan first (F13).
- Once cataloged: auto-gather works forever for that species/type. Toxic flora also auto-gathers after cataloging (player collects it knowingly — it's a resource, just dangerous to consume).
- Raw tier resources per biome (Wood, Stone, Berries, Fiber, etc.)
- Tool-gated resources: bare hands (Wood, Berries, Fiber), Stone Axe (thick trees), Stone Pickaxe (Ore, Crystals). Tool-gating applies after cataloging — uncataloged minerals don't auto-gather regardless of tools.
- Resource respawn: regenerate on tiles outside visible range. Never respawn while visible.
- Gathering feedback (floating text, animation/SFX placeholder)

### F4. Crafting
- Crafting (item recipes) requires being near a Workbench — Craft button appears only when adjacent
- Progressive recipe discovery: recipes unlock when player gathers a new material
- MVP craft recipes: Stone Axe (2 Wood + 1 Stone), Stone Pickaxe (3 Wood + 2 Stone)

### F5. Inventory
- Grid-based, limited slots (~12 base resource/consumable slots)
- 4 fixed tool slots (Axe, Pickaxe, Weapon, Scanner) — separate from resource slots
- Tools auto-used, no manual equip/unequip
- View items and quantities
- Tap consumable to use (with scan-safety check — see F13)
- Expandable via Storage Chest (+12 slots per chest)

### F6. Building
- Build button always visible in HUD — opens menu of structures placeable on adjacent tiles
- Building is separate from Crafting: Build = place structures, Craft = make items
- Workbench is the first thing the player builds
- **Structures are props** — placed into `tile.props[]` with `category: "structure"` and a `footprint` (list of sub-hexes they occupy). Multiple structures per hex allowed if sub-hexes don't overlap.
- Placement: select structure → enter placement mode → choose target hex → choose sub-hex position → validate footprint (no overlap) → place
- Structures are indestructible in MVP
- Walkability: Shelter, Torch, Campfire = walkable. Wall = blocks movement. Workbench, Storage Chest = walkable (but their footprint sub-hexes are occupied for placement purposes).
- Shelter = safe zone at night
- MVP structures: Workbench, Shelter, Storage Chest, Wall, Torch, Campfire
- Raw-tier recipes only

### F7. Day/Night Cycle
- Day (~3 min) → Dusk (30s warning) → Night (~1.5 min) → Dawn
- Visual shift (lighting, tint changes — warm palette, not dark/oppressive)
- Night: visibility reduced to 1 hex around player
- Auto-save at dawn

### F8. Survival Stats
- HP, Hunger, Thirst — visible HUD bars
- Hunger depletes over time; zero = HP drain
- Thirst depletes faster; zero = faster HP drain
- Eat/drink to restore — **but unknown flora requires scanning first** (see F13)
- HP regenerates slowly during day
- No stamina bar

### F9. Night Threats
- Days 1–3: peaceful (onboarding)
- Day 4+: fauna spawn at night outside lit/walled areas
- **Before cataloging:** All creatures appear as ❓ — player doesn't know if hostile. No auto-defend.
- **Surprise attack:** Uncataloged hostile fauna attacks → player takes first hit (surprise damage). That species is AUTOMATICALLY cataloged as hostile. Auto-defend activates immediately for all subsequent attacks in that encounter AND all future encounters.
- **Two paths to catalog hostile fauna:**
  - Smart path: See ❓ → scan from safe distance → cataloged as hostile → auto-defend ready, zero damage
  - Hard path: Didn't scan → creature attacks → take first hit → auto-cataloged → auto-defend kicks in
- **After cataloging:** Auto-identified (red icon), auto-defend when adjacent (player auto-attacks with equipped weapon, no tap)
- Fauna move toward player within 2 hexes, deal damage on contact
- Despawn at dawn
- **Fauna drops:** Meat on kill (best hunger item, reward for combat risk)

### F10. Save System
- Auto-save at dawn
- Serialize world + player + catalog + journal state to local JSON
- Single save slot (MVP)
- Corrupt/missing save = fresh start without crash
- **Chapter state tracking:** Save includes chapter ID and progress markers for future extensibility

### F11. Death & Respawn
- HP reaches 0 → fade to black → respawn at Shelter or Crash Site
- Drop 50% of each resource/consumable stack (rounded down). Tool slots safe.
- Day counter continues
- Night death → respawn at dawn (stay on black screen until dawn)
- No permadeath

### F12. HUD Layout
- Top-left: HP, Hunger, Thirst bars (compact)
- Top-right: Day counter + time-of-day icon
- Bottom-right: Inventory button, Build button (always visible), Crafting button (near Workbench only), Scanner/Catalog button
- No fixed joystick zone (floating)
- No minimap
- Minimal, translucent, warm palette — screen is the game, not the UI
- **Design system TBD** — vibrant colors, soft shapes, sci-fi but warm. NOT Tactical Brutalism.

### F13. Scanner & Catalog System (NEW)
- **Scanner tool:** Always available (Scanner tool slot, starts equipped)
- **The scanner is the universal gate.** ❓ = inert to the auto-system. Scan → cataloged → auto-interaction unlocked for that type forever.
- **Proximity auto-scan:** Player walks adjacent to an unknown element (❓ icon) → scan starts automatically (no press-and-hold) → scan progress bar (2-3 seconds while in range) → entry added to Catalog. Moving out of range interrupts scan and resets progress immediately. One scan at a time, nearest prop first.
- **Three-state knowledge system:**
  - **UNKNOWN (❓):** Never seen. No auto-interaction. No info.
  - **ENCOUNTERED (⚠️):** Fauna only — hostile fauna that attacked (label: "Unidentified Fauna (Hostile)") or passive fauna that fled (label: "Unidentified Fauna (Shy)"). Auto-defend activates for hostile. No species name, no details until CATALOGED.
  - **CATALOGED (✅):** Fully identified. Full auto-interaction. All details known (name, drops, edible, etc.).
- **State transitions:**
  - Flora & Mineral: UNKNOWN → CATALOGED (proximity scan, no ENCOUNTERED state)
  - Fauna Hostile: UNKNOWN → ENCOUNTERED (first attack auto-registers). ENCOUNTERED → CATALOGED (Sneak Scan, deferred post-MVP)
  - Fauna Passive: UNKNOWN → ENCOUNTERED (fauna flees on approach). ENCOUNTERED → CATALOGED (Trap mechanic, deferred post-MVP)
  - Anomaly: UNKNOWN → CATALOGED (proximity scan, no ENCOUNTERED state)
- **Passive identification:** Already-cataloged elements auto-identified when entering scanner range (correct icon: green for passive, red for hostile, resource type icon for minerals)
- **What can be scanned (proximity):**
  - Flora: identifies edible vs toxic. Uncataloged = no auto-gather. Cataloged edible = auto-gather. Cataloged toxic = auto-gather (player collects knowingly).
  - Minerals: identifies resource type and tool required. Uncataloged = no auto-gather. Cataloged = auto-gather with tool-gating.
  - Anomalies: narrative trigger — scanning unlocks cutscene/journal entry
  - Fauna: NOT proximity-scannable in MVP. Hostile → ENCOUNTERED on first hit (auto-defend activates). Full catalog requires Sneak Scan (deferred). Passive → ENCOUNTERED when fleeing. Full catalog requires Trap (deferred).
- **Before scanning:** Elements show ❓ icon. Player doesn't know properties. Real risk on first encounters.
- **Biome discovery loop:** Arrive → everything is ❓ → walk near to scan (tension, discovery) → catalog everything → biome becomes "conquered" (progress satisfaction) → auto-interaction makes the routine fluid
- **Catalog UI:** Accessible via Scanner button. Categories: Flora, Fauna, Minerals, Anomalies. Counter shows total entries (ENCOUNTERED + CATALOGED). ENCOUNTERED entries show "Unidentified Fauna (Hostile/Shy)" with no details. CATALOGED entries show full info.
- **Save data:** Per-entry knowledge state (UNKNOWN/ENCOUNTERED/CATALOGED) + encounter labels

### F14. Journal System (NEW)
- **The Journal is the emotional heart of the game — the astronaut's logbook**
- **Two sections:**
  - **Story Timeline:** Unlocked cutscenes, ordered chronologically. Player can revisit any narrative moment. Example: "Day 1: Crash Landing" → "Day 3: Strange Signal" → "Day 7: The Ruins"
  - **Catalog:** Scanner discoveries (cross-references with Story Timeline)
- **Trigger system:** Anomaly scan or story milestone → unlock cutscene → add to Journal
- **Cutscenes (Chapter 1):** Static comic panels (cheap, beautiful, matches episodic model). Architecture supports: trigger → show cutscene → mark as seen → add to Journal.
- **The Journal IS the purpose.** The real loop is explore → scan → catalog → discover story. Gather/craft/build are means, not ends.

## 6. Non-Functional Requirements

### Performance
- 60 fps on mid-range devices (2022+); 30 fps acceptable on low-end
- <500 tris per object, <100 draw calls per frame
- <200MB memory usage, <100MB APK size

### Platform
- Android 8.0+ / iOS 14+, 2GB RAM minimum
- 100% offline — no server, no account, no telemetry
- Portrait mode, 1080×1920 viewport

### Visual Design
- **Tactical Brutalism is DISCARDED.** Wrong vibe for "charming and pleasant."
- New design system TBD: vibrant colors, soft shapes, sci-fi but warm
- Astroneer meets MLU aesthetic — colorful, welcoming, low-poly
- HUD: translucent, warm-toned, minimal. NOT mil-spec/cyan/dark.
- Placeholder art for MVP; final design system developed alongside art pipeline

### Code Quality
- **Linting:** Godot built-in warnings (zero tolerance) + gdtoolkit/gdlint
- **Naming:** snake_case (GDScript standard), PascalCase for class names only
- **Build policy:** Zero warnings. Manual export for MVP.

### Testing
- **Framework:** GdUnit4 for unit tests
- **Coverage:** Critical pure-logic systems only — hex math, crafting recipes, survival stats, scanner/catalog logic, save/load.
- **No render/UI tests** — manual playtesting

### Accessibility (MVP)
- Touch targets sized for mobile (min 48×48 dp)
- Clear visual contrast between biome types and element states (unknown ❓ vs identified)
- (Further accessibility deferred)

## 7. Constraints

### Technical
- **Engine:** Godot 4.x, GDScript only (no C#, no GDExtension)
- **No native plugins:** Everything via Godot APIs. 100% offline.
- **Chapter architecture:** Content must be modular — future chapters add biomes, catalog entries, cutscenes, recipes without modifying core systems. Chapter state tracked in save data.

### Team
- 2 people + AI agents: Andre (supervision, implementation oversight), Lola (design, coordination). AI agents handle implementation.

### Budget (low, self-funded)
- ~$77 for art pipeline (Sloyd + Tripo)
- $25/year Apple Developer + $25 one-time Google Play
- Godot = free, GitHub = free

### Art Pipeline (decided — see docs/02-visual-assets-pipeline.md)
- Sloyd for base 3D models
- Tripo for refinement/variations
- Low-poly aesthetic, colorful and charming (NOT dark/gritty)
- MVP uses placeholder art

### Timeline
- No hard deadline
- Soft goal: playable prototype within ~4–6 weeks

## 8. Assumptions & Dependencies

### Assumptions
- Godot 4.x latest stable is mature enough for mobile export
- Single-threaded GDScript performance adequate for ~300-tile hex map + simple AI + scanner logic
- Hex grid math maps cleanly to Godot's node system (Red Blob Games reference)
- Touch input latency acceptable (<100ms)
- Godot FileAccess reliable for local save/load on Android + iOS
- Placeholder art sufficient to validate core loop + scanner/catalog feel
- ~$2.50/chapter price point viable for episodic mobile (validated by comparables: Alto's Odyssey chapters, Monument Valley 2)
- Episodic model requires strong Chapter 1 hook — free chapter must end on a narrative cliffhanger
- **No multiplayer, ever.** Design decision, not deferral.

### Dependencies

**Code dependencies:**
- Godot 4.x latest stable (engine)
- GdUnit4 (unit test framework)
- gdtoolkit/gdlint (linting)

**Design dependency:**
- Red Blob Games hexagonal grids guide
- New design system (TBD — vibrant, warm, sci-fi)

**Build dependencies:**
- Godot Export Templates: Android (SDK/NDK) + iOS (Xcode on Mac)
- Sloyd + Tripo accounts (art assets, post-MVP)

## 9. Acceptance Criteria

### AC1 — Hex Grid & World
- [ ] Load Chapter 1 map from JSON → 200–300 tiles
- [ ] All 3 biomes + Crash Site present
- [ ] Crash Site at origin (0,0)
- [ ] Fog tiles not visible until player moves adjacent
- [ ] At least 1 anomaly tile in map data
- [ ] Elevation 0–9 per tile, 3-tier traversal enforced (walk/jump/blocked)

### AC2 — Movement
- [ ] Joystick appears at touch point on drag, character moves continuously
- [ ] Player avoids BLOCKED tiles (water, structures, elevation diff 4+) — slides along boundary
- [ ] Elevation diff 2-3: auto-jump (up ~0.3s) / auto-drop (down ~0.2s) with arc
- [ ] Elevation diff 0-1: smooth walk with Y interpolation
- [ ] Tap on world = no movement (reserved for interactions)
- [ ] On joystick release, player snaps to current tile center
- [ ] Input-to-first-movement-frame < 100ms (measured)

### AC3 — Gathering (Auto-Interaction)
- [ ] Player moves adjacent to uncataloged resource (❓) → nothing happens (scan gate)
- [ ] Player scans unknown wood resource → cataloged → auto-gather starts on next proximity
- [ ] Player moves adjacent to cataloged wood → auto-gather, +1 Wood in inventory
- [ ] Player moves adjacent to cataloged ore without Stone Pickaxe → nothing (tool-gated)
- [ ] Player moves adjacent to cataloged ore with Stone Pickaxe → auto-gather, +1 Ore
- [ ] Resource node depletes after N gathers and visually changes
- [ ] Depleted resource on non-visible tile regenerates after type-specific timer

### AC4 — Crafting
- [ ] Player has 5 Wood + 3 Stone → Workbench recipe visible in Build menu
- [ ] Player has 2 Wood + 0 Stone → Workbench recipe greyed out
- [ ] Player gathers Stone for first time → Stone Axe recipe appears in Craft menu
- [ ] Craft Stone Axe → materials consumed, tool in axe slot

### AC5 — Inventory
- [ ] Start with 12 empty resource slots + 4 tool slots
- [ ] Auto-pickup 13th unique item without Storage Chest → rejected with feedback
- [ ] Build Storage Chest → inventory expands to 24 resource slots
- [ ] Items stack with quantity display

### AC6 — Building
- [ ] Place Workbench on hex with free sub-hexes → prop added to tile.props[]
- [ ] Try to place structure on sub-hexes already occupied → rejected
- [ ] Multiple structures in same hex allowed if footprints don't overlap
- [ ] Shelter built → player inside at night takes 0 damage
- [ ] Wall built → fauna pathfinding routes around it (main-hex level traversal check)
- [ ] Structures are indestructible — fauna cannot damage them

### AC7 — Day/Night
- [ ] Full cycle completes in 5 min ±15s (measurable)
- [ ] Dusk warning visible 30s before night
- [ ] Night: only tiles within 1 hex of player visible
- [ ] Torch placed: extends visibility to 2 hexes around torch

### AC8 — Survival Stats
- [ ] HUD shows 3 bars at all times
- [ ] Hunger reaches 0 → HP decreases at defined rate
- [ ] Eat scanned-safe Berries → Hunger increases by defined amount
- [ ] All three stats at 0 → player dies → fade to black → respawn with 50% inventory drop

### AC9 — Night Threats
- [ ] Day 3 night → zero fauna spawn
- [ ] Day 4 night → 1–3 fauna spawn outside lit/walled area
- [ ] Uncataloged fauna show ❓ icon, no auto-defend
- [ ] Uncataloged hostile fauna attacks → player takes surprise damage → species auto-cataloged
- [ ] After cataloging (scan or surprise): auto-defend active for all future encounters
- [ ] Dawn → all fauna despawn

### AC10 — Save System
- [ ] Dawn triggers → save file exists on disk
- [ ] Kill app → reopen → world state matches (tiles, structures, resources, catalog, journal)
- [ ] Kill app → reopen → player state matches (inventory, stats, position, day count)
- [ ] Corrupt/delete save → game starts fresh without crash

### AC11 — Scanner & Catalog (NEW)
- [ ] Unknown flora shows ❓ icon — no auto-gather
- [ ] Walk adjacent to unknown flora → scan progress bar starts automatically → catalog entry created
- [ ] Leave range during scan → progress resets immediately (no grace period)
- [ ] After cataloging: flora auto-identified + auto-gather unlocked for that species
- [ ] Unknown fauna shows ❓ — no auto-defend
- [ ] Hostile fauna attacks uncataloged → ENCOUNTERED state → "Unidentified Fauna (Hostile)" label → auto-defend activates
- [ ] Passive fauna flees on approach → ENCOUNTERED state → "Unidentified Fauna (Shy)" label
- [ ] Unknown mineral shows ❓ — no auto-gather. Proximity scan → cataloged → auto-gather with tool-gating
- [ ] Anomaly scanned → cutscene triggered → journal entry added
- [ ] Catalog UI shows entries with counter ("X entries" — ENCOUNTERED + CATALOGED both count)
- [ ] ENCOUNTERED entries show "Unidentified Fauna (Hostile/Shy)" with no details
- [ ] CATALOGED entries show full info (name, drops, edible, etc.)
- [ ] Only one proximity scan at a time, nearest prop first

### AC12 — Journal (NEW)
- [ ] Journal accessible via UI button
- [ ] Story Timeline shows unlocked cutscenes in chronological order
- [ ] Catalog section shows scanner discoveries
- [ ] Scanning anomaly adds entry to both Catalog and Story Timeline
- [ ] Cutscene plays on first anomaly scan (placeholder comic panel)

## 11. Game Initialization & Bootstrap

The game startup sequence must be explicitly defined. Each system initializes in order, and later deliveries extend this sequence.

### Bootstrap Sequence (delivery-001 baseline)
1. `Main._ready()` → create `MapLoader(HexGrid)` → `load_map("res://data/maps/ch1.json")` → map populated
2. `Player._ready()` → spawn at map's spawn tile (0,0) → snap to tile center
3. `HexGrid.refresh_visibility([{coords: player.current_tile, radius: 2}])` → initial fog reveal
4. `HexGridRenderer` receives `map_generated` → builds ArrayMesh (single draw call)
5. `HexGridRenderer` receives `tile_visibility_changed` → updates vertex colors per tile
6. `PlayerCamera._ready()` → targets Player → isometric overhead angle (rotation.x ≈ -34°)
7. `HUD._ready()` → stat bars (placeholder), day counter (placeholder), 5 action buttons, CraftButton hidden

### Extension Points
Each delivery that adds systems MUST document how it extends this sequence:
- **delivery-002:** ScannerSystem + Inventory initialize after Player (no dependencies on other new systems)
- **delivery-003:** AutoInteractionSystem connects to tile_entered signal after Player ready
- **delivery-004:** DayNightCycle autoload starts phase timer. SurvivalSystem connects to phase signals. SaveManager connects to day_started for auto-save. Visibility radius changes per phase (day=2, night=1). DayNightCycle takes ownership of refresh_visibility calls (replaces delivery-001 player-driven calls)
- **delivery-005:** BuildingSystem + FaunaManager initialize as Player children. Torch placement registers visibility sources with DayNightCycle
- **delivery-006:** JournalSystem connects to entry_cataloged + day_started signals

### Dev Environment Requirements
- **Desktop testing requires mouse→touch emulation:** `project.godot` must include `[input_devices]` section with `pointing/emulate_touch_from_mouse=true`
- **Headless testing:** GdUnit4 requires `--ignoreHeadlessMode` flag. HTML reporter has cosmetic errors in Godot 4.6 — not project bugs

## 12. Priority

### P0 — Foundation
| Feature | Rationale |
|---------|-----------|
| F1 Hex Grid | Can see the world |
| F2 Movement | Can move in the world |

### P0 — Core Loop
| Feature | Rationale |
|---------|-----------|
| F3 Gathering (auto) | First interaction — walk near things, collect them |
| F5 Inventory | Store what you gathered |
| F13 Scanner/Catalog | Core mechanic — identify the unknown, drive curiosity |
| F4 Crafting | Transform resources into tools |
| F8 Survival Stats | Stakes — hunger/thirst create gentle urgency |

### P0 — Persistence
| Feature | Rationale |
|---------|-----------|
| F7 Day/Night | Time pressure, pacing |
| F10 Save | Don't lose progress |

### P0 — Story Hook
| Feature | Rationale |
|---------|-----------|
| F14 Journal | The reason to keep playing — narrative discovery |

### P1 — Tension
| Feature | Rationale |
|---------|-----------|
| F6 Building | Shelter, walls, defense |
| F9 Night Threats | Stakes for the night cycle |

### Build Order Notes
- **Scanner/Catalog is P0 Core Loop** — it's the central mechanic, not a nice-to-have
- Journal is P0 Story Hook — without it, Chapter 1 has no narrative cliffhanger
- Auto-interaction simplifies F3 (no tap disambiguation) but adds proximity detection
- Feature SPECs (001-012) reconciled with redesign. 14 functional requirements (F1-F14) across 12 feature SPECs.
- Scanner/Catalog (F13) and Journal (F14) decomposed and specified.

## §13 Prop Taxonomy & Sub-Hex Architecture

See `docs/design/prop-taxonomy.md` for the 4-category prop classification (Decoration, Resource, Structure, Entity) and render pipeline.

See `docs/design/sub-hex-grid-impact.md` for the sub-hex grid architecture decision, unified props[] model, and full impact analysis across all systems.
