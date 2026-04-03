# Feature Inventory

> **Source:** Discovery Q&A (user-confirmed) + codebase analysis
> **Status:** Active
> **Last Updated:** 2026-04-03

## Features

| # | Feature | Description | Status | Modules | Key Files | Data Entities |
|---|---------|-------------|--------|---------|-----------|---------------|
| 1 | Hex Grid / Map | Axial-coordinate hex grid with flat-top orientation, biomes, elevation, fog of war, hand-designed JSON maps | Implemented | Hex Grid Core, Data Layer | hex_math.gd, hex_tile.gd, hex_grid.gd, map_loader.gd, biome_data.gd | HexTile, BiomeData, ch1.json |
| 2 | Player Movement | Joystick continuous movement, traversal types (WALK/JUMP/DROP/BLOCKED), slide mechanics, elevation transitions | Implemented | Player | player.gd, player_input.gd, player_camera.gd | player_pathfinder.gd exists as orphan (joystick pivot removed A* for player) |
| 3 | Resource Gathering | Proximity-based auto-gather with tool gates, yield amounts, gather radius, resource depletion and respawn timers | Implemented | Auto-Interaction | auto_interaction_system.gd | ResourceNode, ResourceDef |
| 4 | Inventory | Slot-based inventory (12 resource slots + 4 tool slots), stack limits, StringName-keyed items | Implemented | Inventory | inventory.gd | ITEM_CONFIG dictionary |
| 5 | Crafting | Recipe-based crafting with material requirements, workbench proximity gate, pre-discovered recipes (stone tools), discovery via materials | Implemented | Crafting | crafting_system.gd | RECIPE_CONFIG dictionary |
| 6 | Scanner / Catalog | Proximity auto-scan, knowledge states (UNKNOWN→ENCOUNTERED→CATALOGED), catalog entries with discovery tracking | Implemented | Scanner/Catalog | scanner_system.gd, catalog.gd, catalog_data.gd, catalog_entry.gd | CatalogEntry, CatalogData |
| 7 | HUD / UI | Stat bars, day counter, notifications, floating text, three bottom-drawer panels (inventory, crafting, catalog), joystick overlay | Implemented | HUD, UI Panels | hud.gd, stat_bars.gd, notification_manager.gd, floating_text_manager.gd, inventory_panel.gd, crafting_panel.gd, catalog_panel.gd | — |
| 8 | Auto-Interaction | Proximity-based system for auto-gather, auto-scan, with configurable radii and cooldowns | Implemented | Auto-Interaction | auto_interaction_system.gd | — |
| 9 | Survival System | Health, hunger, stamina mechanics with environmental effects | Stubbed | — | Referenced in auto_interaction_system.gd | — |
| 10 | Building System | Structure placement, crafting-driven construction, player-built shelters/workbenches | Stubbed | — | BuildingSystem (stubbed) | WALKABLE_STRUCTURES constant |
| 11 | Day/Night Cycle | Time progression, lighting changes, survival pressure from nighttime | Stubbed | — | DayNightCycle (stubbed), day_counter.gd (UI ready) | — |
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
- Features 9-12 have stubs/references scattered in existing code (e.g., WALKABLE_STRUCTURES includes building types, catalog has fauna entries, HUD has day_counter)
- Feature 13 (Journal & Narrative) is a new addition from user input, not referenced in current codebase
- Map generation is hand-designed only (no procedural generation planned)
- Monetization model (episodic vs single-unlock) is undecided; does not affect Ch1 MVP
