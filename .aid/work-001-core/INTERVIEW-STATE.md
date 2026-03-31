# INTERVIEW-STATE.md

**Status:** Approved
**Grade:** A
**Minimum Grade:** A

## Section Status

| # | Section | Status | Last Updated |
|---|---------|--------|--------------|
| 1 | Objective | Complete | 2026-03-30 |
| 2 | Problem Statement | Complete | 2026-03-30 |
| 3 | Users & Stakeholders | Complete | 2026-03-30 |
| 4 | Scope | Complete | 2026-03-30 |
| 5 | Functional Requirements | Complete | 2026-03-30 |
| 6 | Non-Functional Requirements | Complete | 2026-03-30 |
| 7 | Constraints | Complete | 2026-03-30 |
| 8 | Assumptions & Dependencies | Complete | 2026-03-30 |
| 9 | Acceptance Criteria | Complete | 2026-03-30 |
| 10 | Priority | Complete | 2026-03-30 |

## Pending Q&A

### IQ1: [Crafting Flow: Medium]

**Question:** How does the player build the first Workbench? The crafting button only appears near a Workbench (F12), creating a chicken-and-egg problem. Should there be a separate "build" menu always available for placeable structures (Workbench, Shelter, Wall, etc.) that doesn't require being near a Workbench?
**Context:** F4 says crafting requires a Workbench. F12 says crafting button appears only near Workbench. No mechanism described for placing the first Workbench. This is a core flow blocker — without it, the player can never start crafting.
**Source:** /aid-interview (cross-reference)
**Suggested:** Add a separate "Build" button (always visible in HUD) for placing structures directly on adjacent hex tiles. The Crafting button (near Workbench) is for crafting tools/items from recipes. Build = place structures, Craft = make items.
**Answer:** Accepted with detail: Build button (always visible) → menu of structures placeable on adjacent hex (Workbench, Shelter, Storage Chest, etc.). Craft button (only near Workbench) → item recipe menu (Stone Axe, Stone Pickaxe, etc.). Workbench is the first thing the player builds.
**Status:** Answered

### IQ2: [Inventory: Medium]

**Question:** The GDD says Storage Chest costs 8 Wood + 2 Metal, but Metal requires a Furnace which is out of scope for this work. Should we change the Storage Chest recipe to use only Raw-tier materials (e.g., 8 Wood + 4 Stone) so it's craftable in MVP? Or is Storage Chest deferred?
**Context:** AC5 explicitly tests "Build Storage Chest → inventory expands to 24 slots" so it must be in scope. But the GDD recipe is impossible without a Furnace. The recipe needs to change.
**Source:** /aid-interview (cross-reference)
**Suggested:** Change Storage Chest recipe to 8 Wood + 4 Stone (Raw-tier only) for MVP. Revisit when Furnace is in scope.
**Answer:** Accepted. Storage Chest uses Raw-tier materials for MVP. Additional note: before having a Furnace, the survivor should maintain a Campfire — a pre-Furnace structure for future work (not core MVP scope).
**Status:** Answered

### IQ3: [World Gen: Low]

**Question:** REQUIREMENTS §4 lists "Grassland" as a biome, but the GDD has no Grassland — it uses Forest as the green/starter biome. Is Grassland a new biome you want to add (distinct from Forest), or should it replace one of the existing biomes?
**Context:** GDD biomes are: Forest, Rocky, Water, Desert, Swamp, Ruins, Volcanic, Crash Site. Requirements say core MVP has Grassland, Forest, Rocky. If Grassland is new, it needs resources/hazards defined. If it replaces something, the GDD needs updating.
**Source:** /aid-interview (cross-reference)
**Suggested:** Grassland is the open/safe starter biome (grass, berries, basic fiber) — distinct from Forest (denser, more wood, thorns hazard). Keeps Forest's identity intact from GDD while adding a gentler starting zone.
**Answer:** Accepted. Grassland = safe starter biome (grass, berries, fiber). Forest = denser, more wood, thorns hazard. Natural progression curve: Crash Site → Grassland → Forest → Rocky.
**Status:** Answered

### IQ4: [Scope: Low]

**Question:** Bridge is listed as an MVP recipe in F4, but there's no Water biome in core scope (only Grassland, Forest, Rocky). Should Bridge be removed from core MVP scope and deferred until the Water biome is added?
**Context:** Without water tiles, Bridge has no function. Including it adds implementation work with no gameplay payoff in this work.
**Source:** /aid-interview (cross-reference)
**Suggested:** Remove Bridge from core MVP recipes. Defer to the work that adds the Water biome.
**Answer:** Keep water tiles in world generation as impassable terrain barriers (no Water biome resources/hazards needed for MVP). Bridge stays in scope as the way to cross them. Recipe: 6 Wood + 2 Fiber (Raw-tier). Water tiles are not a full biome — just impassable terrain clusters between biomes that create chokepoints and guide early-game exploration. Worldgen distributes water tile clusters to force the player to explore around rather than beeline in any direction.
**Status:** Answered

## Review History

| # | Date | Grade | Source | Notes |
|---|------|-------|--------|-------|
| 1 | 2026-03-30 | — | /aid-interview | Interview complete — approved |
| 2 | 2026-03-30 | — | Feature Decomposition | 8 features created |
| 3 | 2026-03-30 | A | /aid-interview (cross-reference) | 4 findings (2 Medium, 2 Low), all resolved. Build/Craft split, Storage Chest recipe, Grassland biome, Water tiles as terrain. |
| 4 | 2026-03-30 | — | User request | Added hex elevation system to F1, F2, AC1, AC2 |
| 5 | 2026-03-31 | — | User redesign | MAJOR REDESIGN: New identity (curiosity+story), episodic chapters, auto-interaction, scanner/catalog (F13), journal (F14), fauna/flora personality, Tactical Brutalism discarded. All sections updated. Existing feature SPECs need reconciliation. |
| 6 | 2026-03-31 | — | Feature Decomposition | 12 features created (replacing old 8). Old features 003-008 archived. New: 003-scanner-catalog, 004-auto-interaction, 005-inventory, 006-crafting, 007-survival-stats, 008-day-night-cycle, 009-building, 010-night-threats, 011-journal, 012-hud. Features 001-002 kept with stale warning. |
