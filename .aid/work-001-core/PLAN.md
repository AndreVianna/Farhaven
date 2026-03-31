# Delivery Plan — work-001-core

**Status:** Approved
**Created:** 2026-03-31
**Features:** 8 (all SPECs Ready)

## Dependency Map

| Feature | Depends On | Enables |
|---------|-----------|---------|
| 001 Hex Grid | -- (foundation) | All features |
| 002 Player Movement | 001 | 003, 005, 006, 007, 008 |
| 003 Resource Gathering | 001, 002, 004 | 005 (discovery trigger) |
| 004 Inventory | 001 | 003, 005, 006, 008 |
| 005 Crafting | 004, 008 (Workbench) | 003 (tools unlock gated resources) |
| 006 Survival Stats | 002, 004, 007, 008 | -- |
| 007 Day/Night Cycle | 001, 002 | 006, 008 |
| 008 Building & Threats | 001, 002, 004, 007 | 005, 006 |

## Deliveries

### delivery-001: World Foundation

**Features:** feature-001-hex-grid, feature-002-player-movement
**Depends on:** -- (foundation)
**Cumulative state:** Walk and explore

Build order:
1. feature-001 (Hex Grid) — HexGrid autoload, HexTile, MultiMesh rendering, worldgen
2. feature-002 (Player Movement) — Player node, AStar2D, Camera, JoystickOverlay

The first playable moment: crash-land on a hex world, move around, reveal fog of war,
see biomes and elevation. Foundation for everything else.

**AC coverage:** AC1 (grid generation), AC2 (movement)

### delivery-002: Inventory + Gathering

**Features:** feature-004-inventory, feature-003-resource-gathering
**Depends on:** delivery-001
**Cumulative state:** Collect resources

Build order:
1. feature-004 (Inventory) — Inventory RefCounted, HUD CanvasLayer, InventoryPanel, tool slots
2. feature-003 (Resource Gathering) — GatherSystem, ResourceRenderer, respawn queue

First half of the core loop: explore, gather, carry. Limited to bare-hands resources
(berries, fiber, surface wood) since tools arrive in delivery-004. Tool-gated resources
show "Requires Stone Axe" feedback — not a silent fail.

**AC coverage:** AC3 (gathering), AC5 (inventory)

### delivery-003: Day/Night + Building & Threats

**Features:** feature-007-day-night-cycle, feature-008-building-threats
**Depends on:** delivery-001, delivery-002
**Cumulative state:** Survive the night

Build order:
1. feature-007 (Day/Night Cycle) — DayNightCycle autoload, SaveManager autoload, refresh_visibility, lighting, day counter HUD
2. feature-008 (Building & Threats) — BuildingSystem, FaunaManager, Build panel, structure/fauna rendering, combat

Game transforms from "walk and collect" into "survive the night." Day/night rhythm,
save/load, structures (Workbench, Shelter, Wall, Torch), fauna, combat. Meat drops
accumulate in inventory but have no stat effect until delivery-004.

**AC coverage:** AC6 (building), AC7 (day/night), AC9 (night threats), AC10 (save system)

### delivery-004: Crafting + Survival Stats

**Features:** feature-005-crafting, feature-006-survival-stats
**Depends on:** delivery-001, delivery-002, delivery-003
**Cumulative state:** Complete MVP loop

Build order:
1. feature-005 (Crafting) — CraftingSystem, recipe discovery, CraftingPanel, Workbench proximity
2. feature-006 (Survival Stats) — SurvivalSystem, stat bars, depletion/regen, death/respawn, ground items

Complete loop: explore, gather, build, craft, survive, repeat. Tools unlock gated
resources. Hunger/thirst create urgency. Death has consequences (50% inventory drop)
but not permadeath. Meat becomes useful (best hunger item).

**AC coverage:** AC4 (crafting), AC8 (survival stats, death/respawn)

## Notes

- Each delivery is playable and testable standalone
- Each builds on the previous with no unresolved dependencies
- delivery-002: tool-gated resources gracefully rejected with feedback until delivery-004
- delivery-003: meat accumulates with no effect until SurvivalSystem in delivery-004
- Circular dependency between 005/008 resolved: Building places Workbench, Crafting reads proximity

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | Plan created — 4 deliveries approved | /aid-plan |
