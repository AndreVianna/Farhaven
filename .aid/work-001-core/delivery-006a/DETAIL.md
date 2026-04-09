# delivery-006a: Engine Refactors — Gear, Events, IDs, SSH

**Status:** Planning
**Created:** 2026-04-09
**Depends on:** delivery-005b
**Cumulative state:** Unified entity model, Event system, universal IDs, SSH spatial grid.

> **Design specs:**
> - `.aid/knowledge/data-model.md` §Gear Hierarchy + §SSH Grid
> - `.aid/work-001-core/delivery-005a/DESIGN.md` §Decision Log (EVENT, count/max_count, world flags)

## Tasks (preliminary — to be detailed during planning)

| # | Name | Type | Est. hours |
|---|------|------|-----------|
| 055 | Gear base class (gear.gd) + Script base (script_base.gd) | IMPLEMENT | 3 |
| 056 | Recipe extends Script (remove unlock_when, kind→cosmetic) | REFACTOR | 4 |
| 057 | Event extends Script (count, max_count) | IMPLEMENT | 3 |
| 058 | Migrate unlock_when → Event .tres files with grant_script | DATA | 3 |
| 059 | ID namespace — prefix system (P/R/E/CS/J) + rename all .tres | REFACTOR | 4 |
| 060 | SSH grid math (HexMath additions) | IMPLEMENT | 3 |
| 061 | Mesh collision (replace footprint with CollisionShape3D) | IMPLEMENT | 8 |
| 062 | PlaceableCap cleanup (remove footprint, blocks_movement) | REFACTOR | 2 |
| 063 | BuildingSystem update (SSH snap + physics overlap check) | REFACTOR | 4 |
| 064 | PropDef + Element extends Gear (add short/long_description) | REFACTOR | 2 |
| 065 | Doc cascade | DOCS | 3 |

**Estimated total: ~39h**

## Open questions (resolve during planning)
- ID prefix format: single letter (P, R, E) or multi-letter (PR, RC, EV)?
- SSH: sub-sub-hex count per sub-hex — is it 19 (2 rings) or configurable?
- Mesh collision: generate CollisionShape3D from placeholder_mesh_params automatically, or define separately per PropDef?
- Event: does RecipeRuntime process Events, or do we need an EventRuntime? (Lean: same runtime, dispatch on type)
