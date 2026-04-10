# Feature Inventory

> **Source:** Discovery Q&A (user-confirmed) + codebase analysis
> **Status:** Active
> **Last Updated:** 2026-04-08 (updated for delivery-005a: Props & Recipes engine)

## Features

| # | Feature | Description | Status | Modules | Key Files | Data Entities |
|---|---------|-------------|--------|---------|-----------|---------------|
| 1 | Hex Grid / Map | Axial-coordinate hex grid with flat-top orientation, biomes, elevation, hand-designed JSON maps | Implemented | Hex Grid Core, Data Layer | hex_math.gd, hex_tile.gd, hex_grid.gd, map_loader.gd, biome_data.gd | HexTile, BiomeData, ch1.json |
| 2 | Player Movement | Joystick continuous movement, traversal types (WALK/JUMP/DROP/BLOCKED), slide mechanics, elevation transitions | Implemented | Player | player.gd, player_input.gd, player_camera.gd | player_pathfinder.gd exists as orphan (joystick pivot removed A* for player) |
| 3 | Resource Gathering | Proximity-based auto-gather via Recipe system — queries RecipeRegistry for gather recipes matching nearby props, filters by known recipes and predicate conditions. Legacy direct-gather fallback for uncovered props. | Implemented (refactored 005a) | Auto-Interaction, Recipes | auto_interaction_system.gd, recipe_registry.gd, recipe_runtime.gd | Recipe .tres files, PropDef |
| 4 | Inventory | Slot-size based inventory (12 base slots + 4 tool slots, capacity_size=50.0). Primary constraint is total size; items grouped by type for display. | Implemented (refactored 005a) | Inventory | inventory.gd | PropDef.portable.size |
| 5 | Crafting | Recipe-based crafting via unified Recipe system — RecipeRegistry + RecipeRuntime. 16 recipe .tres files. Discovery via DiscoveryWatcher (catalog-driven, tool-driven, event-driven unlocks). Legacy CraftingSystem still present. | Implemented (refactored 005a) | Recipes, Crafting | recipe_registry.gd, recipe_runtime.gd, discovery_watcher.gd, crafting_system.gd | Recipe .tres files |
| 6 | Scanner / Catalog | Proximity auto-scan, knowledge states (UNKNOWN→ENCOUNTERED→CATALOGED), catalog entries with discovery tracking | Implemented | Scanner/Catalog | scanner_system.gd, catalog.gd, catalog_data.gd, catalog_entry.gd | CatalogEntry, CatalogData |
| 7 | HUD / UI | Stat bars, day counter, notifications, floating text, three bottom-drawer panels (inventory, crafting, catalog), joystick overlay | Implemented | HUD, UI Panels | hud.gd, stat_bars.gd, notification_manager.gd, floating_text_manager.gd, inventory_panel.gd, crafting_panel.gd, catalog_panel.gd | — |
| 8 | Auto-Interaction | Proximity-based system for auto-gather, auto-scan, with configurable radii and cooldowns | Implemented | Auto-Interaction | auto_interaction_system.gd | — |
| 9 | Survival System | Health, hunger, stamina mechanics with environmental effects | Stubbed | — | Referenced in auto_interaction_system.gd | — |
| 10 | Building System | Structure placement, crafting-driven construction, player-built shelters/workbenches | Stubbed | — | BuildingSystem (stubbed) | WALKABLE_STRUCTURES constant |
| 11 | Day/Night Cycle | Time progression, phase-based lighting (local lights via LightingManager at night/dusk), survival pressure from nighttime | Implemented (lighting added 005a) | Lighting | day_night_cycle.gd, lighting_manager.gd, day_counter.gd | — |
| 12 | Fauna / Threats | Wildlife encounters, threat mechanics, combat or evasion | Stubbed | — | FaunaManager (stubbed), catalog fauna entries exist | CatalogEntry (fauna category) |
| 13 | Journal & Narrative | Story progression, lore discovery, chapter narrative, player journal | Not Started | — | — | — |

## Status Legend

| Status | Meaning |
|--------|---------|
| Implemented | Feature is coded and functional |
| Stubbed | References exist in code (signals, constants, UI hooks) but core logic not implemented |
| Not Started | No code exists yet |

## Notes

- Features 1-8 are implemented and tested (varying coverage levels)
- delivery-005a (2026-04-08) refactored features 3 (Gathering), 4 (Inventory), and 5 (Crafting) to use the unified Recipe system and weight-based inventory. Also added local lighting to feature 11.
- The Recipe system (RecipeRegistry, RecipeRuntime, DiscoveryWatcher, PredicateEvaluator) is an engine-level system, not a standalone feature. It enables features 3, 5, and future gameplay.
- Features 9-12 have stubs/references scattered in existing code (e.g., WALKABLE_STRUCTURES includes building types, catalog has fauna entries, HUD has day_counter)
- Feature 13 (Journal & Narrative) is a new addition from user input, not referenced in current codebase
- Map generation is hand-designed only (no procedural generation planned)
- Monetization model (episodic vs single-unlock) is undecided; does not affect Ch1 MVP
