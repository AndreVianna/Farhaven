# delivery-006a: Engine Refactors — Gear, Events, IDs, SSH

**Status:** Complete
**Created:** 2026-04-09
**Completed:** 2026-04-09
**Depends on:** delivery-005b
**Cumulative state:** Unified entity model, Event system, universal IDs, SSH spatial grid, mesh-based collision.

> **Design specs:**
> - `.aid/knowledge/data-model.md` §Gear Hierarchy + §SSH Grid
> - `.aid/work-001-core/delivery-005a/DESIGN.md` §Decision Log (EVENT, count/max_count, world flags)

## Tasks

| # | Name | Type | Est. hours | Status |
|---|------|------|-----------|--------|
| 055 | Gear base class (gear.gd) + ScriptBase (script_base.gd) | IMPLEMENT | 3 | DONE |
| 056 | Recipe extends ScriptBase (remove unlock_when, kind→cosmetic, time→duration) | REFACTOR | 4 | DONE |
| 057 | GameEvent extends ScriptBase (count, max_count) + EventRegistry autoload | IMPLEMENT | 3 | DONE |
| 058 | Migrate unlock_when → 12 discovery Event .tres files with grant_recipe effects | DATA | 3 | DONE |
| 059 | ID namespace — prefix system (P/R/E/CS/J) + rename all .tres | REFACTOR | 4 | DONE |
| 060 | SSH grid math (HexMath: snap_to_ssh, is_valid_ssh, get_all_sshs) | IMPLEMENT | 3 | DONE |
| 061 | Mesh collision (CollisionHelper + StructureRenderer StaticBody3D) | IMPLEMENT | 8 | DONE |
| 062 | PlaceableCap cleanup (remove footprint, blocks_movement) | REFACTOR | 2 | DONE |
| 063 | BuildingSystem update (SSH snap + physics overlap check) | REFACTOR | 4 | DONE |
| 064 | PropDef extends Gear (inherits id, display_name, short/long_description) | REFACTOR | 2 | DONE |
| 065 | Documentation cascade | DOCS | 3 | DONE |

**Estimated total: ~39h**

## Resolved questions
- **ID prefix format:** Single letter — P for props, R for recipes, E for events, CS for cutscenes, J for journal entries
- **SSH count per sub-hex:** 19 positions (center + 2 rings), same as sub-hex grid. `is_valid_ssh()` validates radius <= 2.
- **Mesh collision:** CollisionHelper generates CollisionShape3D from `placeholder_mesh_type` + `placeholder_params` automatically
- **Event processing:** EventRegistry fires events via `try_fire()`. DiscoveryWatcher listens to `event_fired` signal and processes `grant_recipe` effects. No separate EventRuntime needed.
