# Delivery Plan — work-001-core (Post-Redesign)

**Status:** Approved
**Created:** 2026-03-31
**Features:** 12 SPECs (14 functional requirements, all Ready)
**Replaces:** Pre-redesign plan (8 features, 4 deliveries — invalidated)

## Dependency Map

| Feature | Depends On | Enables |
|---------|-----------|---------|
| 001 Hex Grid | -- (foundation) | All features |
| 002 Player Movement | 001 | 003, 004, 008, 009, 010, 011 |
| 012 HUD & UI Framework | -- (framework) | All features (feedback, panels, buttons) |
| 003 Scanner & Catalog | 001, 002 | 004 (catalog gate), 010 (surprise catalog), 011 (anomaly trigger) |
| 005 Inventory | -- (standalone RefCounted) | 004 (add_item), 006 (has/remove/set_tool), 007 (item_used, drops), 009 (has/remove for building) |
| 004 Auto-Interaction | 003 (catalog gate), 005 (inventory). Auto-defend stub: 010. Auto-pickup stub: 007. | 012 (floating text feedback) |
| 006 Crafting | 005 (inventory API), 009 (workbench must exist) | 004 (tools unlock gated resources) |
| 008 Day/Night + Save | 001 (refresh_visibility), 002 (tile_entered) | 007 (is_daytime, dawn), 010 (night/dawn signals), 011 (day_started) |
| 007 Survival Stats | 005 (item_used, remove_item), 008 (is_daytime, dawn) | 004 (ground item API) |
| 009 Building | 001 (tile queries), 005 (materials) | 002 (pathfind update), 006 (workbench), 007 (shelter respawn), 008 (torch tracking), 010 (wall/shelter/torch) |
| 010 Night Threats | 001, 008 (night/dawn), 003 (surprise catalog) | 004 (auto-defend activates), 007 (meat drops, take_damage) |
| 011 Journal | 003 (entry_cataloged), 008 (day_started) | -- (terminal — narrative payoff) |

**Key dependency notes:**
- F-005 (Inventory) has zero feature dependencies — standalone RefCounted
- F-004 (Auto-Interaction) auto-gather needs only F-003 + F-005. Auto-defend (F-010) and auto-pickup (F-007) are stubs that activate when those features arrive. Core loop is NOT blocked by P1.
- F-012 (HUD) consumes signals from all features but has no upstream dependency

## Deliveries

### delivery-001: Foundation — Walk the World

**Features:** 001 (Hex Grid) + 002 (Player Movement) + 012 (HUD & UI Framework)
**Depends on:** --
**Cumulative state:** Walk around an alien hex world with fog of war, camera follow, HUD shell

Build order:
1. feature-001 (Hex Grid) — world exists
2. feature-012 (HUD) — UI framework ready for all future features to plug into
3. feature-002 (Player Movement) — player can explore

Playable: generate map, walk around, reveal fog, see biomes and elevation. HUD shows
placeholder stat bars, day counter, button slots. Every subsequent feature plugs into
this foundation.

**AC coverage:** AC1 (grid), AC2 (movement, partial — no scan input yet)

### delivery-002: See and Know — Scanner + Inventory

**Features:** 003 (Scanner & Catalog) + 005 (Inventory)
**Depends on:** delivery-001
**Cumulative state:** Scan ❓ elements, build catalog, carry items

Build order:
1. feature-005 (Inventory) — standalone, no dependencies
2. feature-003 (Scanner & Catalog) — needs player_input scan signals from F-002

These two are independent of each other but both are needed by delivery-003. Building
them together means the player can scan the world AND has somewhere to put items.
The ❓ → walk near → proximity scan → identified loop is the game's identity.

**AC coverage:** AC5 (inventory), AC11 (scanner/catalog), AC2 (scan input complete)

### delivery-003: Movement IS Interaction — Auto-Gather + Crafting

**Features:** 004 (Auto-Interaction, auto-gather active) + 006 (Crafting)
**Depends on:** delivery-002
**Cumulative state:** Walk near cataloged resources → auto-gather → craft tools

Build order:
1. feature-004 (Auto-Interaction) — auto-gather active, auto-defend = stub, auto-pickup = stub
2. feature-006 (Crafting) — needs Inventory (delivered) + Workbench (F-009 not yet, but
   crafting system works once a Workbench is manually placed for testing)

**Core loop complete:** explore → scan → catalog → auto-gather → craft tools → unlock
gated resources → explore further. This is the game.

**F-004 stub strategy:** Auto-defend checks `FaunaManager.get_fauna_adjacent_to()` — if
FaunaManager doesn't exist yet (F-010 not delivered), returns empty array. No fauna =
no auto-defend. Stub is just "feature not present = no-op." Same for auto-pickup: if
SurvivalSystem._ground_items is empty (F-007 not delivered), nothing to pick up.

**AC coverage:** AC3 (gathering), AC4 (crafting)

### delivery-004: Time and Consequence — Day/Night + Survival

**Features:** 008 (Day/Night + Save) + 007 (Survival Stats)
**Depends on:** delivery-003
**Cumulative state:** Day/night rhythm, hunger/thirst/HP, death/respawn, auto-save

Build order:
1. feature-008 (Day/Night + Save) — phase timer, lighting, visibility radius, SaveManager
2. feature-007 (Survival Stats) — needs is_daytime from F-008, Inventory item_used from F-005

Stakes exist. Time passes. Stats deplete. Eating matters (scan to know what's safe!).
Death has consequences. Progress saves. The world feels alive.

**AC coverage:** AC7 (day/night), AC8 (survival), AC10 (save)

### delivery-005a: Engine Refactor — Lighting, Yields, Refinement, Inventory Weight

**Features:** TBD (likely 016 Lighting, 017 Yield System, 018 Refinement Chains, 019 Inventory Weight)
**Depends on:** delivery-004 + delivery-004b + post-PR#10 cleanup
**Cumulative state:** Engine ready for full survival gameplay loop — local lighting, multi-tool yields, world refinement chains, weighted inventory, robust consumables.

Build order (tasks 039–045, parallel where possible):
1. task-039 (Local Lighting System) — replaces fog-reveal with shader-based local brightness; restores meaning to torches/campfires
2. task-040 (Slot-based inventory weight) — `slot_size: float` on PropDef, fractional inventory math
3. task-041 (Yield tables with tool variation) — single yield → dictionary keyed by tool
4. task-042 (Refinement chains in world) — Tree → Fallen Tree → Log → Firewood, in-place replacement
5. task-043 (Movable flag + Cart system foundations) — large Sources transportable via Cart
6. task-044 (Robust consumables) — buffs, delayed effects, HUD status icons, cooldowns
7. task-045 (Documentation cascade) — data-model, architecture, module-map, glossary, feature-inventory

This is a pure engine refactor. No new gameplay. Enables delivery-005b.

**AC coverage:** none directly (infrastructure for AC6, AC9)

### delivery-005b: Night Falls — Building + Threats

**Features:** 009 (Building) + 010 (Night Threats)
**Depends on:** delivery-004 + delivery-005a
**Cumulative state:** Place structures, fauna at night, auto-defend + auto-pickup activate

Build order:
1. feature-009 (Building) — structures as props with sub-hex footprints, walls, shelter, torch, workbench
2. feature-010 (Night Threats) — fauna spawn, AI, contact damage, surprise catalog

When this lands:
- F-004 auto-defend activates (FaunaManager now exists, returns real fauna data)
- F-004 auto-pickup activates (ground items from meat drops + death drops now exist)
- Building gives crafting its workbench (F-006 workbench proximity gate deferred; CraftButton is recipe-discovery-gated instead — shows permanently after first recipe discovered. MVP: pre-discovered at startup.)
- Shelter protects player, walls redirect fauna, torches extend visibility (via delivery-005a lighting system)
- Meat drops give survival a new food source
- **Sub-hex architecture:** Structures placed at specific sub-hex positions within a tile. Multiple structures per hex allowed if footprints don't overlap. Torch tracking uses props[] query instead of dedicated structure field.
- **Fog removal impact:** several task-034/037 criteria reference fog-based mechanics that need redesign before implementation (see delivery-005b/DETAIL.md "Scope updates after fog removal").

**AC coverage:** AC6 (building), AC9 (night threats)

### delivery-006: The Story — Journal + Narrative

**Features:** 011 (Journal)
**Depends on:** delivery-002 (entry_cataloged signal) + delivery-004 (day_started signal)
**Cumulative state:** Chapter 1 narrative arc complete

Build order:
1. feature-011 (Journal) — trigger system, cutscene viewer, journal panel

The game has a purpose. The Journal tells the player WHY they're exploring:
crash → Day 3 strange signal → find anomaly → scan → cutscene → cliffhanger.

This is the emotional hook for Chapter 2. Without it, the game is a loop without
meaning. With it, the player wants to know what happens next.

**AC coverage:** AC12 (journal)

## Delivery Progression — The Story of a Session

```
delivery-001: Walk       → "Where am I? Let me explore this beautiful alien world."
delivery-002: See        → "What are these ❓ things? Let me walk near them to scan and discover."
delivery-003: Interact   → "Resources auto-gather! I can craft tools! The world responds to me."
delivery-004: Survive    → "Time passes. I need to eat. I died... but I came back."
delivery-005a: Refactor → (engine-only — no new gameplay; enables 005b)
delivery-005b: Defend    → "Night is dangerous. I built shelter. I killed a creature and got meat!"
delivery-006: Understand → "There were people here before. What happened? I need to find out..."
```

Each delivery is playable and testable standalone. Each builds on the previous.
The core loop (deliveries 1-3) has zero P1 dependencies.

## Notes

- F-004 stubs: auto-defend and auto-pickup activate naturally when F-010/F-007 arrive. No code changes needed — just "feature not present = empty query results = no-op."
- F-006 (Crafting) MVP recipes are `pre_discovered: true` and `requires_workbench: false` — craftable anywhere, no Workbench needed for testing. Workbench gate activates when post-MVP recipes are added.
- Old PLAN.md (4 deliveries, 8 features) is replaced. Old delivery DETAIL.md files in delivery-001 through delivery-004 are invalidated.

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | Plan created — 6 deliveries, 12 features (post-redesign) | /aid-plan |
| 2026-04-02 | Scan redesign: delivery-002 description updated (proximity scan, not press-hold). Delivery progression language updated. | /scan-redesign-apply |
| 2026-04-03 | Review cascade: F006 pre_discovered/requires_workbench, F009 6 structures (campfire added, only Wall blocks), F012 CraftButton recipe-discovery-gated, signal names synced | /aid-specify review |
| 2026-04-04 | Architecture: sub-hex grid + unified props[]. Impacts delivery-005 (building uses props + footprints), delivery-001 (HexTile data model). See docs/design/sub-hex-grid-impact.md | Architecture decision |
| 2026-04-08 | Split delivery-005 into 005a (Engine Refactor — lighting, yields, refinement chains, inventory weight, consumables) and 005b (Night Falls — Building + Threats, formerly delivery-005). Fog of war removal in post-PR#10 cleanup flagged several 005b criteria for redesign. | post-PR#10 review |
