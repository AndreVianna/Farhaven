# task-053: Code Cleanup — Fix Critical + High + Medium findings

**Status:** Ready for execution
**Created:** 2026-04-09
**Source:** Code review audit (post delivery-005a)
**Branch:** delivery-005b
**Execution:** Delegate to elfo(s). Can split into parallel sub-agents by category.

## Goal

Fix ALL Critical (8), High (19), and Medium (14) findings from the code review audit. Leave only Low (4) items as accepted tech debt.

## Findings to fix (grouped for efficient execution)

### Group A: Runtime Safety (Critical — fix first)

1. **`discovery_watcher.gd:67`** — Type annotation mismatch `WorldContext` vs `_WorldContext`. Fix: standardize to class_name usage or match preload.
2. **`recipe_runtime.gd:167-178`** — `_deliver_output()` only delivers to inventory. Implement 3-way delivery: inventory → world_tile → overflow to ground. Emit signal on failure.
3. **`lighting_manager.gd:101-109`** — `scan_existing_lights()` key collision with multiple lights on same tile. Fix key to include sub_hex: `"%s:%s:%s" % [coords, type, prop.sub_hex]`
4. **`lighting_manager.gd:90-109`** — `scan_existing_lights()` no null check on `_grid._tiles`. Add guard.
5. **`discovery_watcher.gd:24-27`** — `_ready()` calls `_populate_initial_known()` before PropRegistry may be ready. Add null guard.
6. **`recipe_runtime.gd:235-262`** — `_consume_single_input()` no validation of source string. Add assertion for known values.
7. **`auto_interaction_system.gd:368-372`** — Legacy fallback accesses deprecated fields without PropRegistry null check. Add guard.
8. **`predicate_evaluator.gd`** — Unimplemented predicates return false with push_warning. Change to push_error for stubs that should never be called in current data.

### Group B: API Encapsulation (Critical + High)

9. **HexGrid private field access** — 5+ scripts access `_grid._tiles` directly. Add public methods to HexGrid: `get_all_tiles() -> Dictionary`, `has_tile(coords) -> bool`. Update all callers: `map_loader.gd`, `crafting_system.gd`, `lighting_manager.gd`, `scanner_system.gd`.
10. **Catalog private field access** — `scanner_system.gd` accesses `_catalog._all_entries`. Add public `has_entry(id) -> bool` method to Catalog.

### Group C: Deprecated Field Cleanup (High + Medium)

11. **`emits_light` bool redundancy** — PropDef has BOTH old `emits_light: bool` + new `light: LightCap`. LightingManager checks old bool. Migrate to `light != null` check. Remove `emits_light` and `light_radius` from all 28 .tres files (keep only `light` capability).
12. **`footprint` field duplication** — PropDef has top-level `footprint` AND `placeable.footprint`. Add deprecation warning; point callers to `placeable.footprint`.
13. **`prop_def.gd` deprecated fields** — Add explicit `# DEPRECATED: removed in task-053` comments with target replacement for each remaining deprecated field.

### Group D: Code Quality (High + Medium)

14. **`auto_interaction_system.gd:201-282`** — Extract `_find_gather_candidates()` into 3 focused methods.
15. **`main.gd:58-132`** — Extract `_wire_systems()` into subsystem-specific wiring methods.
16. **`crafting_system.gd:145-146`** — Add footprint overlap check to temporary `_place_structure_at_player()`.

### Group E: Signal Cleanup (High)

17. **`auto_interaction_system.gd:382`** — Add `_exit_tree()` to disconnect tween signal.
18. **`scanner_system.gd:70-130`** — Add `_exit_tree()` to disconnect grid signals.
19. **`crafting_system.gd:69-80`** — Add `_exit_tree()` to disconnect grid signals.

### Group F: Consistency (Medium)

20. **Preload vs class_name** — Standardize WorldContext, PredicateEvaluator references across recipe scripts.
21. **Recipe ID validation** — Add assertion in RecipeRegistry._ready() for 5-digit numeric IDs.
22. **`save_manager.gd:69,87`** — Change file I/O push_warning to push_error.

## Verification

After all fixes:
```bash
cd /home/andre/projects/Farhaven && godot --headless --script addons/gdUnit4/bin/GdUnitCmdTool.gd --add "res://tests/" --ignoreHeadlessMode 2>&1 | tail -5
cd /home/andre/projects/Farhaven/tools/level-editor && node test-unit.mjs 2>&1 | tail -3
```

All existing 1151 Godot + 587 JS tests must still pass. Zero regressions.

## Commit strategy

One commit per group (A through F), or one big commit if all changes are clean. Push to delivery-005b branch.
