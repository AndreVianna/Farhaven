# Briefing for Analyst — Vision Pivot (work-001-core re-interview)

> **⚠️ SUPERSEDED (2026-04-02):** The scan mechanic described in this document (press-and-hold) has been replaced by proximity-based auto-scan. See [`docs/design/scan-redesign-2026-04-02.md`](design/scan-redesign-2026-04-02.md) for the current design. All references to "press and hold" scanning in this document are historical.

---

## Context

We have fundamentally revised Farhaven's identity and game design after analyzing My Little Universe (SayGames, 30M+ downloads, ~$10M revenue) as a primary reference. The changes affect monetization, visual identity, core mechanics, and narrative. The existing REQUIREMENTS.md needs to be updated with everything below. The technical specs for all 8 features need to be reconciled with this new vision.

---

## 1. NEW GAME IDENTITY

**Updated elevator pitch:** An astronaut crash-lands on an alien planet. Explores a beautiful, mysterious hex-tile procedural world. Gathers resources, builds shelter, catalogs flora/fauna/minerals with a scanner, and discovers that the supposedly "uninhabited" planet shows signs of civilization. The story is told through the astronaut's Journal, fed by scanner discoveries.

**Feeling references:**
- My Little Universe (progress satisfaction, walk around and things happen, visually pleasant)
- Subnautica (scanner as core mechanic, narrative mystery, beautiful but dangerous planet)
- The game evolves across chapters from MLU (casual, colorful, relaxed) toward Subnautica (deep, mysterious, narrative-driven)

**Tone and aesthetics:**
- Visually charming and pleasant — NOT dark
- NOT too difficult — challenge exists but is gentle
- The player's drive is CURIOSITY and STORY, not difficulty or punishment
- Colorful, warm, charming low-poly. Think Astroneer meets MLU — sci-fi but welcoming
- The planet is alien but beautiful, not hostile. Colors say "explore here"
- **Tactical Brutalism is DISCARDED** — it was visually striking but the wrong vibe. Dark, mil-spec, cyan-on-black doesn't match "charming" and "pleasant"
- The design system needs to be redone: vibrant colors, soft shapes, sci-fi but warm

**Target player:** A casual mobile gamer who likes to explore and wants a story. Not a hardcore gamer. Not an idle player. Someone who plays 15-30 minutes on their commute and wants to know what happens in the next chapter.

---

## 2. NEW MONETIZATION — EPISODIC CHAPTERS

**The $2.99 single unlock model is discarded.**

**New model:**
- **Chapter 1: FREE** — crash, basic survival, build shelter, first anomaly detected. This is the hook. The player experiences the full gameplay loop without paying anything.
- **Chapter 2+: ~$2.50 each** — paid narrative expansions. Each chapter adds: new planet area, new catalog entries, new cutscenes, new mechanics/recipes, story continuation.
- **Like comic books** — each chapter is an episode. The player buys the next one when they want to know what happens.
- **Zero IAP, zero ads, zero fake currencies** — this doesn't change. One-time payment per chapter, complete content.

**Planned narrative arc (affects world design):**
1. Chapter 1 — Crash, survive, build base, discover first anomaly (FREE)
2. Chapter 2 — Explore further, lost civilization, another crash site
3. Chapter 3 — Escape the planet, intermediary space station
4. Chapter 4+ — Final destination, story resolution

**For the MVP (work-001-core), the scope is Chapter 1 only.** But the architecture must support future chapters (modular content, chapter state tracking).

---

## 3. NEW CORE MECHANIC — MOVEMENT IS INTERACTION (auto-interaction)

**Fundamental principle: the player controls WHERE to go. The game handles the rest.**

**The multi-tap input model is discarded.** Replaced by passive proximity-based interactions:

- **Resource in range:** player approaches → auto-gather starts (no tap)
- **Cataloged hostile creature approaches:** auto-defend (no tap)
- **Cataloged creature/plant/mineral in scanner range:** auto-identified with icon (no tap)
- **Ground item on tile:** auto-pickup (we already had this)

**What this eliminates from current specs:**
- Tap adjacent = gather → ELIMINATED (auto-gather by proximity)
- Tap adjacent = attack → ELIMINATED (auto-defend when hostile approaches)
- Input priority stack (fauna > resource > movement) → NEARLY GONE
- Tap disambiguation flow (complex 4-way) → NO LONGER NEEDED
- Feature-002 pathfinding tap vs joystick remains as the only navigation input

**What KEEPS an active tap:**
- Tap/joystick to MOVE (sole gameplay input)
- Tap to OPEN inventory/build/craft/journal panels (UI buttons)
- Tap to PLACE structure in build mode (intentional decision)
- Tap to USE consumable in inventory
- **PRESS AND HOLD to SCAN** (new mechanic — see below)

---

## 4. NEW CORE MECHANIC — SCANNER + CATALOG SYSTEM

**The scanner changes from a passive tool slot to THE CENTRAL TOOL OF THE GAME.**

**Dual mode — passive + active:**

**Active (press and hold) — FIRST ENCOUNTER with any new element:**
- Player sees something unknown → ❓ icon appears in the world
- Press and hold toward the element → scan progress bar (2-3 seconds)
- Scan complete → entry added to the CATALOG
- From that point on, this element type is auto-identified forever

**What can be scanned:**
- Flora: identifies edible vs toxic (before scanning, the player doesn't know — real risk)
- Fauna: identifies hostile vs passive (before scanning, all creatures are ❓ — tension on first encounter)
- Minerals: identifies which resource it contains and what tool is needed
- Anomalies: "man-made things" on a planet that should be uninhabited — NARRATIVE TRIGGER, each scanned anomaly can unlock a cutscene

**Passive (automatic) — ALREADY CATALOGED elements:**
- Auto-identified when entering scanner range
- Correct icon appears automatically (green for passive, red for hostile, etc.)
- Auto-interaction happens normally

**Smart scan tension:**
- Scanning requires proximity + press and hold (takes 2-3 seconds)
- Unknown creature that might be hostile? Must get close and hold while it could attack you
- Unknown plant? Could be toxic, but must scan to know before eating
- Real risk vs reward decision on every first encounter

**CATALOG:**
- UI accessible via Scanner button
- Categories: Flora, Fauna, Minerals, Anomalies
- Each entry: name, icon, short description, properties
- Discovery counter: "12/47 cataloged" — completion drive
- Per-chapter: each chapter adds new entries to the world
- Save data: array of discovered catalog entry IDs

---

## 5. NEW FEATURE — JOURNAL (narrative + cutscenes)

**The Journal is the emotional heart of the game. It is the astronaut's logbook.**

**Two integrated sections:**

**Story Timeline:**
- Unlocked cutscenes live here for rewatching
- Ordered chronologically — the adventure timeline
- Example: "Day 1: Crash Landing" → "Day 3: Strange Signal" → "Day 7: The Ruins"
- Player can revisit any narrative moment

**Catalog:**
- Scanner discoveries (flora, fauna, minerals, anomalies)
- Practical info for each entry

**The two cross-reference each other.** A scanned anomaly adds a catalog entry AND unlocks a cutscene in the timeline. The player feels they're assembling a narrative puzzle.

**The Journal IS the purpose of the game.** The real loop is not gather/craft/build — those are means. The goal is to FILL THE JOURNAL, understand what happened on this planet, and eventually escape.

**Cutscenes:**
- For mobile/low-poly, they don't need to be cinematic
- Suggested approach: static comic panels (cheap, beautiful, matches the "chapters like comics" model)
- Can be a mix: comic panels for major moments + simple in-engine sequences for smaller moments
- Exact implementation TBD, but the architecture must support: trigger (anomaly scan, story milestone) → show cutscene → mark as seen → add to Journal

---

## 6. FAUNA AND FLORA REDESIGN

**Fauna:**
- No longer just "attack at night" — creatures have personality
- Types: hostile, passive, possibly useful (future chapters)
- Before cataloging: all creatures are ❓ — player doesn't know if they're dangerous
- After cataloging: auto-identified, auto-interaction

**Flora:**
- No longer just "berries" — plants can be toxic
- Edible vs toxic determined by scan
- Before cataloging: player DOESN'T KNOW if they can eat it (real risk if eaten without scanning)
- Adds a decision: scan first (safe) or risk eating without knowing?

---

## 7. WHAT DOESN'T CHANGE (confirm these stay)

- Hex grid, axial coordinates, biome system
- World generation (procedural, seed-based)
- Fog of war and tile reveal
- Day/night cycle (timing, phases)
- Building system (workbench, shelter, storage, wall, torch)
- Crafting system (workbench proximity, recipes)
- Inventory (slot-based, tool slots, resource slots)
- Save system (local JSON, auto-save at dawn)
- Performance targets (<100 draw calls, 60fps, <200MB RAM)
- Platform targets (Android 8+, iOS 14+, portrait 1080x1920, 100% offline)
- GDScript only, Godot 4.x, no native plugins

---

## 8. IMPACT ON EXISTING FEATURES

| Feature | Impact |
|---|---|
| F-001 Hex Grid | LOW — grid math unchanged. May need catalog data association per tile |
| F-002 Movement | MEDIUM — tap-to-move stays, but tap-to-interact mostly eliminated. Joystick+pathfind unchanged. Add press-and-hold input for scanning |
| F-003 Gathering | HIGH — auto-gather on proximity replaces tap-to-gather. Tool gating stays. GatherFeedback stays. Remove tap disambiguation entirely |
| F-004 Inventory | LOW — slot structure unchanged. Scanner tool slot may change role |
| F-005 Crafting | LOW — workbench proximity, recipes mostly unchanged |
| F-006 Survival | MEDIUM — stats system stays but flora toxic/edible scan adds food risk. Death/respawn mostly unchanged |
| F-007 Day/Night | LOW — timing unchanged, lighting unchanged |
| F-008 Building/Threats | MEDIUM — building unchanged. Fauna behavior richer (scan-first, hostile/passive personality). Combat becomes auto-defend |
| NEW: Catalog/Scanner | HIGH — completely new feature |
| NEW: Journal/Narrative | HIGH — completely new feature |
