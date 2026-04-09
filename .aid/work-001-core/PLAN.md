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
| 008 Day/Night + Save | 001 (tile queries), 002 (tile_entered), lighting system (delivery-005a) | 007 (is_daytime, dawn), 010 (night/dawn signals), 011 (day_started) |
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
**Cumulative state:** Walk around an alien hex world, camera follow, HUD shell

Build order:
1. feature-001 (Hex Grid) — world exists
2. feature-012 (HUD) — UI framework ready for all future features to plug into
3. feature-002 (Player Movement) — player can explore

Playable: generate map, walk around, see biomes and elevation. HUD shows
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

### delivery-005a: Engine Refactor — Props, Recipes, Lighting, Inventory Weight

**Features:** TBD (see `delivery-005a/DETAIL.md` Open Questions §3 for feature numbering decision)
**Depends on:** delivery-004 + delivery-004b + post-PR#10 cleanup
**Cumulative state:** Engine ready for full survival gameplay loop — composable Props (capabilities + tags), unified Recipe system (crafting/cooking/refining/gathering/consuming/burning/decaying/growing all via the same machinery), weight-based Inventory, local lighting.

**Authoritative design doc:** `.aid/work-001-core/delivery-005a/DESIGN.md` (snapshot from 2026-04-08 design conversation).

Build order (tasks 039 + 046–052, parallel where possible):
1. task-039 (Local Lighting System) — replaces fog-reveal with shader-based local brightness; runs entirely in parallel with the Recipe stack
2. task-046 (PropDef refactor) — `Category` enum → capabilities + tags + `category_tag`
3. task-047 (Recipe schema + parser + RecipeRegistry) — `Recipe` resource + `data/recipes/` loader + indexes
4. task-048 (Predicate Evaluator "query item") — single source of truth for condition predicates
5. task-049 (Inventory weight refactor) — slot-count → weight-based, parallel with task-048
6. task-050 (Recipe Runtime + Discovery Watcher) — pending queue, tick loop, sustain checks, unlock_when watching
7. task-051 (Migrate AutoInteractionSystem + Catalog hooks) — delegate gather/cook/craft/etc to RecipeRuntime
8. task-052 (Documentation cascade) — knowledge folder + cross-links + PLAN.md sync

This is a pure engine refactor. No new gameplay. Enables delivery-005b.

**AC coverage:** none directly (infrastructure for AC6, AC9)

> **Note:** delivery-005 was split; see delivery-005a (engine refactor) first.
> **Revised 2026-04-08:** original tasks 040–044 (slot weight, yield tables, refinement chains, movable+cart, consumables) collapsed into the unified Recipe system (tasks 046–051). Task 039 (Lighting) preserved unchanged. See `delivery-005a/DESIGN.md` for the full design rationale.

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

### delivery-006a: Engine Refactors — Gear, Events, IDs, SSH

**Features:** Engine-level, no direct gameplay features
**Depends on:** delivery-005b
**Cumulative state:** Unified entity model (Gear hierarchy), Event system for milestones/flags/chapters, universal ID namespace, SSH spatial grid with mesh collision.

Build order:
1. Gear hierarchy (gear.gd → script_base.gd → recipe.gd + event.gd; element base → prop, biome)
2. Event system (Script kind=EVENT, count/max_count, world flags as event counts)
3. ID namespace (P/R/E/CS/J prefixes — universal unique Gear IDs)
4. Remove unlock_when from Recipe → migrate to Event .tres files with grant_script effect
5. SSH grid + mesh collision (3-level hex grid, abandon footprint arrays, 3D mesh collision)
6. Doc cascade

Pure engine refactor. No new gameplay. Schema changes propagate to delivery-006b (editor).

**AC coverage:** none directly (infrastructure for 006b + 006c)

> **Design specs:** `.aid/knowledge/data-model.md` (Gear Hierarchy + SSH Grid sections), `.aid/work-001-core/delivery-005a/DESIGN.md` (Recipe/Event decisions in decision log)

### delivery-006b: Editor Sync — All Pages for New Schema

**Features:** Level editor fully synchronized with Gear + SSH engine
**Depends on:** delivery-006a
**Cumulative state:** Editor supports creating/editing all Gear types (Props, Recipes, Events, Fauna), SSH-precision placement, and the new ID namespace.

Build order:
1. Editor: Prop page updated (PlaceableCap without footprint, SSH snap, new Gear base fields)
2. Editor: Recipe page updated (sync with Event system, no unlock_when)
3. Editor: Event page (NEW — create/edit milestones, chapter gates, world flags)
4. Editor: Fauna page (NEW — Fauna as special Prop with movement config)
5. Editor: Blueprint/Build recipe filtering (or integrated in Recipe page)
6. Editor: SSH grid support (2D top-down placement at 32cm resolution)
7. Editor: Biome page review (ensure sync with current schema)
8. Editor: ID namespace enforcement (prefix validation, auto-increment per type)

Editor-only delivery. No engine changes. All pages write valid .tres for the 006a schema.

**AC coverage:** none directly (tooling for content creation)

### delivery-006c: The Story — Journal, Cutscenes, Events

**Features:** 011 (Journal), Cutscene system, Chapter 1 narrative content
**Depends on:** delivery-006a (Event system) + delivery-006b (editor for content creation)
**Cumulative state:** Chapter 1 narrative arc complete. Milestones trigger cutscenes and journal entries. The game has a purpose.

Build order:
1. CutsceneManager autoload (Level A — play MP4 on EVENT trigger)
2. Journal system (JournalEntry as Gear, journal panel UI)
3. Editor: Journal Entry page (NEW)
4. Editor: Cutscene page (NEW — metadata, video path, trigger link)
5. Chapter 1 milestone events (.tres) — first shelter, first night, anomaly discovered, etc.
6. Chapter 1 cutscene content — AI-generated videos for milestone moments
7. Chapter 1 journal entries content
8. BDD scenarios for narrative flows

The game has a purpose. The Journal tells the player WHY they're exploring:
crash → Day 3 strange signal → find anomaly → scan → cutscene → cliffhanger.
Milestones fire EVENTs → EVENTs trigger cutscenes + journal entries.
This is the emotional hook for Chapter 2.

**AC coverage:** AC12 (journal)

> **Design specs:** `.aid/knowledge/game-lore.md` (4-act narrative, civilization), `.aid/knowledge/game-mechanics.md` (cutscene system, progression map)

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
| 2026-04-08 | delivery-005a task list rewritten after Props/Recipes design conversation. Tasks 040-044 collapsed into unified Recipe system (tasks 046-051). DESIGN.md created as authoritative spec. | Andre + Lola design conversation |
| 2026-04-08 | delivery-005a implementation complete (tasks 039, 046, 046b, 047, 048, 049, 050, 051, 052). Knowledge docs updated. | task-052 documentation cascade |
