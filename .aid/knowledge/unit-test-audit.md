# Unit Test Coverage Audit — delivery-006d task-084a

**Date:** 2026-04-11
**Branch:** delivery-006d (worktree: agent-adeff1cc)
**Baseline:** 1601 test cases / 1588 passing / 13 failing / 0 flaky / 0 skipped / 84 suites

> Run: `GODOT_BIN=/usr/local/bin/godot bash addons/gdUnit4/runtest.sh -a tests/unit -a tests/day_night -a tests/survival --ignoreHeadlessMode --headless`
>
> Note: the pre-006d DETAIL cited ~1349 cases with 13 failures. The case count has grown to 1601 (Wave 1 agents added tests), but the failure count is still 13 and concentrated in just **2 test files** — not 4 as the BDD agent reported. `test_building_placement.gd` and `test_building_system.gd` now **pass** cleanly, presumably fixed during delivery-006c.

## Summary

Coverage is surprisingly solid at first glance. Of **73 production scripts** under `scripts/` (excluding `main.gd`, `world.gd`, the 2-line `recipe.gd`/`predicate.gd` data containers, and debug helpers), **69 have a direct test file** — the 4 notable gaps are `hex_grid.gd` (389-line autoload — **critical**), `journal.gd` (100-line autoload — **critical**), and `cutscene_def.gd` / `journal_entry.gd` / `event.gd` (thin data classes, mostly covered by their parent registry tests). The 12 capability classes all have tests, and most autoloads have real behavior coverage (CutsceneManager, DayNightCycle, LightingManager, DiscoveryWatcher, RecipeRegistry, RecipeRuntime, PredicateEvaluator, JournalEntryRegistry, EventRegistry). The biggest risk concentration is two missing autoload tests (HexGrid, Journal) and one shallow-ish autoload test (SaveManager — tests file I/O only, not signal wiring). UI coverage is moderate: 4 of ~20 UI files have dedicated tests; several panels are exercised only via their public API surface through the panels we DO test. Pre-existing failures split into exactly 2 root causes: a data inventory mismatch in `test_catalog.gd` (12 failures against `test_catalogable_prop_defs_have_catalog_entries` — fauna PropDefs P00101–P00106 have `CatalogableCap` but no catalog entries exist for them), and a stale key-format assertion in `test_structure_renderer.gd::test_key_format_includes_coords_and_type` (expects `3,-2:P00103`, gets `3,-2:0,0:P00103` — the key format was extended to include sub-hex coordinates, the test wasn't updated).

## Pre-existing failures

| Test file | Failing case(s) | Error category | Root cause (brief) | Recommended fix |
|---|---|---|---|---|
| `tests/unit/test_catalog.gd` | `test_catalogable_prop_defs_have_catalog_entries` (12 failures, one per fauna PropDef) | Data inconsistency between code and data | Fauna PropDefs P00101–P00106 carry `CatalogableCap` but `Catalog._catalog` has no matching entries for them. The test walks `PropRegistry.get_all()` and expects every catalogable PropDef to have a matching `catalog.get_entry(def.id)` returning the PropDef itself. | Decide the policy: either (a) extend Catalog seed data to include fauna entries (most likely correct — fauna are encounter-first, so entries should exist in ENCOUNTERED state), or (b) narrow the test to skip fauna PropDefs and add a separate fauna-specific assertion. Do NOT just delete the test — it is validating a real contract. Fix is likely in `scripts/scanner/catalog.gd` seed logic, not the test. |
| `tests/unit/test_structure_renderer.gd` | `test_key_format_includes_coords_and_type` (1 failure) | Stale API assertion | The renderer's internal key format was extended from `"q,r:TYPE"` to `"q,r:sq,sr:TYPE"` to support sub-hex placement. The test's expected string was never updated. | One-line fix: update the expected string in the test to match the current sub-hex-aware key format. Verify no caller depends on the old format in other places (rg for `"{0},{1}:"` style patterns). |

**Previously flagged but now passing (no action needed):**
- `tests/unit/test_building_placement.gd` — 25 cases, 0 failures, passes cleanly (orphan-node warnings only)
- `tests/unit/test_building_system.gd` — 25 cases, 0 failures, passes cleanly

**Also worth noting:** suite reports `-2692 orphans` across all runs — several tests leak nodes during setup/teardown. Not a failure, but a clean-up opportunity for 084b/c/d if time permits. The biggest leakers are building/renderer/fauna tests.

## Coverage matrix

### Autoloads (HIGH priority)

| File | Test | Confidence | Notes |
|---|---|---|---|
| `scripts/data/prop_registry.gd` | `test_prop_registry.gd` (12 tests) | COMPLETE | has/get/all API + yield_type + tool_speed + edge cases. |
| `scripts/hex/hex_grid.gd` | **NONE** | **NONE** | 389-line autoload. Tile queries, neighbors, elevation traversal, spawn API, signals. `test_hex_grid_renderer.gd` touches it as a fixture but there is no direct unit test for the autoload's public API (`get_tile`, `has_tile`, `get_neighbors`, elevation rules, signal emission, starting_loadout round-trip). **BIGGEST HIGH-RISK GAP.** |
| `scripts/day_night/day_night_cycle.gd` | `tests/day_night/test_day_night_cycle.gd` (38 tests) + `test_day_night_lighting.gd` (10 tests) | COMPLETE | All phase transitions, signals, day count, multiple cycles. Best-covered autoload. |
| `scripts/lighting/lighting_manager.gd` | `test_lighting_manager.gd` (29 tests) | COMPLETE | Register/unregister on structure events, phase-gated active lights, player light, signals. |
| `scripts/recipes/recipe_registry.gd` | `test_recipe_registry.gd` (31 tests) | COMPLETE | Loads canonical recipes, find-by-input/action/station/tag exhaustively covered. |
| `scripts/core/event_registry.gd` | `test_event_registry.gd` (11 tests) | PARTIAL | Covers get_event, is_active, get_all, get_save_data, load_save_data. **Missing:** no signal emission check, no test of the `fire()` path through the registry (only directly on GameEvent), no test of ResourceLoader-based scan. |
| `scripts/recipes/discovery_watcher.gd` | `test_discovery_watcher.gd` (17 tests) | COMPLETE | End-to-end discovery with fake registry + catalog + event registry. Well mocked. |
| `scripts/recipes/recipe_runtime.gd` | `test_recipe_runtime.gd` (22 tests) | COMPLETE | Instant/timed/sustain/cancel, inputs/outputs, gates, signals, grant_recipe effect, multiple pending. |
| `scripts/journal/journal.gd` | **NONE** | **NONE** | 100-line autoload. Tracks unlocked JournalEntry resources. **add_entry idempotency, signals, save/load contract are ALL uncovered.** HIGH-RISK GAP (explicit contract called out in task-083 template). |
| `scripts/journal/journal_entry_registry.gd` | `test_journal_entry_registry.gd` (11 tests) | COMPLETE | Scans data/journal/, category filter, clear/register round-trip. |
| `scripts/cutscenes/cutscene_manager.gd` | `test_cutscene_manager.gd` (13 tests) | COMPLETE | play/skip/finished signal, single-playback policy, def injection for test. |
| `scripts/save/save_manager.gd` | `test_save_manager.gd` (18 tests) | PARTIAL | Covers save_game/load_game/has_save/delete_save/corrupt-file recovery at the file level. **Missing:** no test of the aggregate save data shape (which autoloads contribute), no signal wiring test, no multi-autoload round trip. Depends on 085 BDD to cover the full integration path. |

### Capability classes (HIGH priority)

| File | Test | Confidence | Notes |
|---|---|---|---|
| `scripts/data/capabilities/behavior_cap.gd` | `test_behavior_cap.gd` (16 tests) | COMPLETE | Defaults + all enums (ActivityCycle, GroupBehavior) + diet + reactions assignment. |
| `scripts/data/capabilities/catalogable_cap.gd` | `test_catalogable_cap.gd` | COMPLETE | Marker fields + discovery hook + show_as_anomaly. |
| `scripts/data/capabilities/combat_cap.gd` | `test_combat_cap.gd` (6 tests) | PARTIAL | Tests attacks/defenses array assignment. Cannot deep-test runtime because combat runtime is stub (deferred per DETAIL task-088). |
| `scripts/data/capabilities/container_cap.gd` | `test_container_cap.gd` (5 tests) | PARTIAL | Defaults + accepts_filter + capacity. **Missing:** no test of filter matching semantics with actual tagged items (needs integration). |
| `scripts/data/capabilities/endurance_cap.gd` | `test_endurance_cap.gd` (9 tests) | COMPLETE | hp + vulnerabilities/resistances/immunities round-trip. |
| `scripts/data/capabilities/light_cap.gd` | `test_light_cap.gd` (7 tests) | COMPLETE | radius/color/is_active + interplay with LightingManager via behavior test. |
| `scripts/data/capabilities/movable_cap.gd` | `test_movable_cap.gd` (4 tests) | PARTIAL | push_cost defaults + assignment. **Missing:** semantic meaning (what push_cost = 0 vs > 0 triggers in building system). |
| `scripts/data/capabilities/movement_cap.gd` | `test_movement_cap.gd` (15 tests) | COMPLETE | All Mode enum values, normal/max speed Dictionary round-trip — matches DETAIL.md task-085 requirement. |
| `scripts/data/capabilities/placeable_cap.gd` | `test_placeable_cap.gd` (2 tests) | SHALLOW | Just confirms it is a pure marker class with no fields. OK given the design — marker only. |
| `scripts/data/capabilities/portable_cap.gd` | `test_portable_cap.gd` (5 tests) | PARTIAL | size field defaults + assignment. **Missing:** no test of interaction with Inventory's slot-unit capacity enforcement. |
| `scripts/data/capabilities/spawnable_cap.gd` | `test_spawnable_cap.gd` | COMPLETE | Spawn timing + density + weight. |
| `scripts/data/capabilities/station_cap.gd` | `test_station_cap.gd` (5 tests) | PARTIAL | station_tags assignment. **Missing:** no test of the tag-lookup contract used by RecipeRuntime (which is covered in `test_recipe_runtime.gd` indirectly). |

### Data classes (HIGH priority)

| File | Test | Confidence | Notes |
|---|---|---|---|
| `scripts/core/gear.gd` | `test_gear.gd` (9 tests) | PARTIAL | id/display_name/short_description/long_description getters + setters + extends Resource. **Missing:** no test of derived class contract (that every Gear subclass correctly inherits). This is mostly fine since derived-class tests cover it. |
| `scripts/core/script_base.gd` | `test_script_base.gd` (14 tests) | COMPLETE | Inherits Gear, conditions/effects/actions arrays, duration, default values, Gear fields. |
| `scripts/core/event.gd` (GameEvent) | `test_game_event.gd` (18 tests) | COMPLETE | count/max_count semantics, is_active, can_fire, fire, reset, one-shot/unlimited/limited patterns. |
| `scripts/data/prop_def.gd` | `test_prop_def.gd` (21 tests) | COMPLETE | has_capability for all 12 caps, round-trip, fauna caps, tags, load from real .tres files, data invariants. |
| `scripts/data/cutscene_def.gd` | **NONE** (covered indirectly by `test_cutscene_manager.gd`) | SHALLOW | 20-line Gear-derived data class. CutsceneManager test injects CutsceneDefs so the fields (id, display_name, video_path) get exercised. No dedicated test file. |
| `scripts/journal/journal_entry.gd` | **NONE** (covered indirectly by `test_journal_entry_registry.gd`) | SHALLOW | 23-line Gear-derived data class. Registry test builds entries with id/display_name/category/body. No dedicated test. |
| `scripts/recipes/predicate.gd` | **NONE** (covered indirectly by `test_predicate_evaluator.gd`, 50+ tests) | COMPLETE-via-evaluator | 12-line data container (kind, params, op, threshold). PredicateEvaluator exhaustively tests every kind. No dedicated field-level test, but behavioral coverage is total. |
| `scripts/recipes/recipe.gd` | **NONE** (covered indirectly by `test_recipe_registry.gd` + `test_recipe_runtime.gd`) | COMPLETE-via-runtime | 9-line ScriptBase subclass. RecipeRegistry loads real .tres files and asserts field values; RecipeRuntime exercises every code path. No dedicated test file needed. |
| `scripts/recipes/recipe_input.gd` | `test_recipe_input.gd` (12 tests) | COMPLETE | scope, qty, tag, is_catalyst. |
| `scripts/recipes/recipe_output.gd` | `test_recipe_output.gd` (10 tests) | COMPLETE | prob, qty, type. |
| `scripts/recipes/recipe_effect.gd` | `test_recipe_effect.gd` (8 tests) | PARTIAL | kind + params. Semantics tested in RecipeRuntime tests. |
| `scripts/recipes/recipe_condition.gd` | `test_recipe_condition.gd` (7 tests) | PARTIAL | predicate link + must_sustain. Semantics tested in RecipeRuntime + PredicateEvaluator. |
| `scripts/recipes/world_context.gd` | `test_world_context.gd` (16 tests) | COMPLETE | Defaults for all fields + create factory + field assignment. |
| `scripts/hex/biome_data.gd` | `test_biome_data.gd` (3 tests) | SHALLOW | Load all biomes, verify color_variations count + validity. No field-level defaults/round-trip. |
| `scripts/hex/hex_tile.gd` | `test_hex_tile.gd` (19 tests) | COMPLETE | Coords, biome, walkable, props array, elevation. |

### Systems (MEDIUM priority)

| File | Test | Confidence | Notes |
|---|---|---|---|
| `scripts/auto_interaction/auto_interaction_system.gd` | `test_auto_interaction_system.gd` (38) + `test_auto_interaction_stubs.gd` (~40) + `test_auto_gather.gd` (~60) | COMPLETE | Three files totaling 1500+ LoC of coverage. Proximity detection, candidate sorting, tween gather, chaining, inventory-full, respawn queue. |
| `scripts/building/building_system.gd` | `test_building_system.gd` (25) + `test_building_placement.gd` (25) | COMPLETE | Placement mode, sub-hex overlap, material check, signals, storage chest expansion, shelter/torch/campfire placement. |
| `scripts/building/structure_renderer.gd` | `test_structure_renderer.gd` (25, 1 FAIL) | PARTIAL | 25 rendering tests. The one failure is the stale key-format assertion — fix makes it COMPLETE. |
| `scripts/crafting/crafting_system.gd` | `test_crafting_system.gd` (44 tests) | COMPLETE | Start/cancel/queue/resolve end-to-end, pending queue. |
| `scripts/fauna/fauna_manager.gd` | `test_fauna_manager.gd` (43) + `test_fauna_wiring.gd` (~18) | COMPLETE | Spawn rules, activity cycles, diet, group behavior, signal wiring. 989 LoC — most-tested file. |
| `scripts/fauna/fauna_renderer.gd` | `test_fauna_renderer.gd` (236 LoC) | PARTIAL | Render cycle, visibility filter. Does not test all edge cases. |
| `scripts/hex/map_loader.gd` | `test_map_loader.gd` (22 tests) | COMPLETE | Map format parsing, starting_loadout, sub-hex placement. |
| `scripts/inventory/inventory.gd` | `test_inventory.gd` (89 tests) | COMPLETE | Slot management, tool slots, stack math, capacity, save/load. Most exhaustive test in the suite. |
| `scripts/player/player.gd` | `test_player.gd` (26) | COMPLETE | Movement, stats, tool slot management. |
| `scripts/player/player_camera.gd` | `test_player_camera.gd` | COMPLETE | Camera follow + clamping. |
| `scripts/player/player_input.gd` | `test_player_input.gd` (269 LoC) | COMPLETE | Input mapping, action dispatch. |
| `scripts/player/player_pathfinder.gd` | `test_player_pathfinder.gd` (160 LoC) | COMPLETE | A* pathfinding + traversal rules. |
| `scripts/scanner/scanner_system.gd` | `test_scanner_system.gd` (26) + `test_catalog.gd` (57, 12 FAIL) | COMPLETE | Scan lifecycle + catalog state transitions. The failures are in data-seed assertions, not scanner behavior. |
| `scripts/scanner/catalog.gd` | `test_catalog.gd` (57, 12 FAIL) | PARTIAL | 45 of 57 tests pass — core catalog state machine is tested. The failures are all in one data-consistency test. |
| `scripts/survival/survival_system.gd` | `tests/survival/test_survival_system.gd` (60) + `test_survival_death.gd` (23) + `test_activity_costs.gd` (21) | COMPLETE | Depletion, HP drain, death/respawn, activity costs. |
| `scripts/survival/ground_item_renderer.gd` | `test_ground_item_renderer.gd` (221 LoC) | PARTIAL | Renders ground items, respawn behavior. |
| `scripts/rendering/prop_renderer.gd` | `test_prop_renderer.gd` (283 LoC) + `test_prop_renderers.gd` (216 LoC) | COMPLETE | Prop mesh setup, label display, visibility gating via catalog. |
| `scripts/rendering/prop_label_renderer.gd` | `test_prop_label_renderer.gd` (77 LoC) | PARTIAL | Label visibility states, but small test file. |
| `scripts/rendering/prop_utils.gd` | `test_prop_utils.gd` (59 LoC) | PARTIAL | Limited to a few static helpers. |
| `scripts/rendering/scan_progress_renderer.gd` | `test_scan_progress_renderer.gd` (169 LoC) | COMPLETE | Progress bar visualization. |
| `scripts/rendering/fly_to_player.gd` | `test_fly_to_player.gd` (39 LoC) | SHALLOW | Tween endpoint assertion only. |
| `scripts/hex/prop.gd` | `test_prop.gd` (148 LoC) | COMPLETE | Prop data + serialization. |
| `scripts/hex/prop_node.gd` | `test_prop_node.gd` (75 LoC) | PARTIAL | Node creation from Prop. |
| `scripts/core/collision_helper.gd` | `test_collision_helper.gd` (226 LoC) | COMPLETE | Sub-hex overlap, radius checks. |
| `scripts/core/script_base.gd` | `test_script_base.gd` | COMPLETE | (counted in Data classes) |

### UI panels (MEDIUM priority)

| File | Test | Confidence | Notes |
|---|---|---|---|
| `ui/build_panel.gd` | `test_build_panel.gd` (38 tests, 512 LoC) | COMPLETE | Build entries, material checks, placement mode transitions. |
| `ui/crafting_panel.gd` | `test_crafting_panel.gd` (33 tests) | COMPLETE | Recipe list, filter, craft trigger. |
| `ui/journal_panel.gd` | `test_journal_panel.gd` (15 tests) | PARTIAL | Covers category filter + entry display. **Missing:** unlock state signal handling, search/selection. |
| `ui/status_combined_panel.gd` | `test_status_combined_panel.gd` (32 tests) | COMPLETE | Stats bars, nav section, discoveries section integration. |
| `ui/catalog_panel.gd` | `test_catalog_panel_ui.gd` (30 tests) | COMPLETE | ENCOUNTERED vs CATALOGED state display, panel-opened signals. |
| `ui/inventory_panel.gd` | **NONE directly** (exercised via `test_inventory.gd` for data) | NONE | 89 unit tests on the Inventory *data*, but no test of the *panel* UI — drag/drop, tooltips, slot highlighting, tool-slot vs regular-slot rendering. GAP. |
| `ui/catalog_entry_ui.gd` | (via `test_catalog_panel_ui.gd`) | PARTIAL | Indirect coverage through panel tests. |
| `ui/build_entry_ui.gd` | (via `test_build_panel.gd`) | PARTIAL | Indirect. |
| `ui/recipe_entry_ui.gd` | (via `test_crafting_panel.gd`) | PARTIAL | Indirect. |
| `ui/inventory_slot_ui.gd` | **NONE** | NONE | No test. |
| `ui/tool_slot_ui.gd` | **NONE** | NONE | No test. Referenced by Inventory; tool/regular separation is critical per task-085 flow 7. |
| `ui/combined_panel_base.gd` | **NONE** | NONE | Base class — could be covered by derived panel tests. |
| `ui/gear_combined_panel.gd` | **NONE** | NONE | Rarely exercised. |
| `ui/log_combined_panel.gd` | **NONE** | NONE | No test. |
| `ui/status_stats_section.gd` | (via `test_status_combined_panel.gd`) | PARTIAL | Indirect. |
| `ui/status_nav_section.gd` | (via `test_status_combined_panel.gd`) | PARTIAL | Indirect. |
| `ui/status_discoveries_section.gd` | (via `test_status_combined_panel.gd`) | PARTIAL | Indirect. Note Copilot false-positive was rejected at line 68 in 2026-04-11. |
| `ui/joystick_overlay.gd` | **NONE** | NONE | Mobile-specific, likely LOW risk. |
| `ui/screen_fade.gd` | `test_screen_fade.gd` (113 LoC) | COMPLETE | Fade in/out + signals. |
| `scripts/hud/hud.gd` | **NONE** | NONE | 210-line HUD root. Referenced by other tests but not directly unit-tested. Includes StatusCombinedPanel composition — indirect coverage only. |
| `scripts/hud/craft_flash.gd` | `test_craft_flash.gd` (42 LoC) | COMPLETE | Flash animation. |
| `scripts/hud/day_counter.gd` | `test_day_counter.gd` (38 LoC) | PARTIAL | Count display + signal binding. |
| `scripts/hud/floating_text_manager.gd` | `test_floating_text_manager.gd` (18 LoC) | SHALLOW | Minimal — spawn + position assertion. |
| `scripts/hud/notification_manager.gd` | `test_notification_manager.gd` (53 LoC) | PARTIAL | Queue push + display, but limited. |
| `scripts/hud/stat_bars.gd` | `test_stat_bars.gd` (101 LoC) | COMPLETE | Bar updates + color coding. |

### Helpers and static utilities (LOW priority)

| File | Test | Confidence | Notes |
|---|---|---|---|
| `scripts/hex/hex_math.gd` | `test_hex_math.gd` (138 LoC) + `test_sub_hex_math.gd` (90) + `test_ssh_math.gd` (201) | COMPLETE | Three test files — hex math, sub-hex math, SSH (sub-sub-hex) math. Thorough. |
| `scripts/recipes/predicate_evaluator.gd` | `test_predicate_evaluator.gd` (50+ tests, 690 LoC) | COMPLETE | Exhaustive — every predicate kind tested with positive/negative/missing-context paths. One of the best tests in the suite. |
| `scripts/audio/gather_sound.gd` | `test_gather_sound.gd` (68 LoC) | PARTIAL | Sound trigger. |
| `scripts/main.gd` | **NONE** | N/A | Scene-specific bootstrap wiring. 204 LoC. Referenced by `test_fauna_wiring.gd` / `test_feedback_wiring.gd` for its signal wiring. Not directly testable as a unit — integration coverage is appropriate. |
| `scripts/world.gd` | **NONE** | N/A | 8 lines, connects lighting nodes to DayNightCycle. Trivial. |
| `scenes/world/hex_grid_renderer.gd` | `test_hex_grid_renderer.gd` (159 LoC) | COMPLETE | (not under scripts/ — scene script) |

## Gap-fill recommendations

### Task 084b (fix pre-existing failures) — priority order

1. **`tests/unit/test_structure_renderer.gd::test_key_format_includes_coords_and_type`** — trivial one-line fix (update expected string `3,-2:P00103` → `3,-2:0,0:P00103`). Do first: quick win, removes 1 failure. Before fixing, grep the codebase for any other place that builds or parses this key format to confirm no other consumer is stale.
2. **`tests/unit/test_catalog.gd::test_catalogable_prop_defs_have_catalog_entries`** — requires a design decision. Read `scripts/scanner/catalog.gd` seed logic; the test assumes every PropDef with `CatalogableCap` gets a catalog entry at init. Fauna (P00101–P00106) currently don't. Two valid fixes:
   - **(a, likely correct)** Update `Catalog` init to also register fauna PropDefs. This preserves the contract that "catalogable → has entry". Verify the rest of the catalog code handles ENCOUNTERED state correctly for fauna (which should be the normal flow — fauna are encountered before cataloged).
   - **(b, fallback)** Narrow the test to exclude fauna PropDefs (those with both `CatalogableCap` and `BehaviorCap`), and add a separate test asserting that fauna follow the encounter-first contract.
   - Root-cause the data inconsistency first; do NOT silence the test. 12 failures drop to 0 with this single fix.
3. **Orphan node warnings** — opportunistic cleanup in test_structure_renderer and test_building_* tests. Not blocking; deferrable.

### Task 084c (gap-fill HIGH-risk untested files) — priority order

1. **`tests/unit/test_hex_grid.gd`** (NEW) — highest-value missing test in the suite.
   - Construction + reset semantics
   - `has_tile` / `get_tile` / `get_all_tiles` / `get_tile_count` API contract
   - `get_neighbors` for center/edge/corner coords
   - Elevation traversal rules (`WALK_MAX_DIFF=2`, `JUMP_MAX_DIFF=4`, `_CORNER_NEIGHBOR_DIRS` logic)
   - `TraversalType` enum semantics (WALK/JUMP/DROP/BLOCKED)
   - Signal emission: `map_generated`, `tile_entered`, `tile_exited`, `prop_depleted`, `prop_respawned`, `structure_placed`, `structure_destroyed`
   - `spawn_tile`, `spawn_sub_hex`, `spawn_facing_deg`, `starting_loadout` round-trip
2. **`tests/unit/test_journal.gd`** (NEW) — covers the Journal autoload's explicit contract (task-083 template calls it out).
   - `add_entry(id)` idempotent — second call with same id does not re-emit
   - `has_entry(id)` / `get_unlocked_entries()` / count
   - Signal: `entry_unlocked(entry_id)` emits exactly once
   - Save/load round trip of unlocked set
   - Ordering stability
3. **`tests/unit/test_event_registry.gd` — fill missing areas** (edit existing). Add:
   - Signal emission when events fire via the registry
   - `fire_event(id, ctx)` path (currently only direct GameEvent tests exist)
   - ResourceLoader scan (or document explicitly why it's untestable in isolation)
4. **`tests/unit/test_save_manager.gd` — fill missing areas** (edit existing). Add:
   - Aggregate save shape: confirm all 12 autoloads contribute sections
   - Signal wiring (if any)
   - A test that the serialize format is JSON-parseable and round-trips (partial coverage exists)

### Task 084d (gap-fill MEDIUM-risk untested files) — priority order

1. **`tests/unit/test_inventory_panel.gd`** (NEW) — covers the UI layer for the most-exercised system. Drag/drop, tool slot vs regular slot distinction (per task-085 flow 7), tooltip display. MEDIUM-HIGH value.
2. **`tests/unit/test_tool_slot_ui.gd`** (NEW) — small file, but critical per flow 7 in task-085.
3. **`tests/unit/test_inventory_slot_ui.gd`** (NEW) — paired with tool slot test.
4. **`tests/unit/test_hud.gd`** (NEW) — 210-line HUD root. Smoke test child composition, signal routing.
5. **`tests/unit/test_fauna_renderer.gd`** — already exists, extend to cover the edge cases (visibility filter corner cases, renderer cleanup on fauna despawn).
6. **`tests/unit/test_prop_utils.gd`** — already exists (59 LoC), extend for uncovered helpers.
7. **`tests/unit/test_ground_item_renderer.gd`** — already exists, extend for respawn edge cases.
8. Container/Portable/Station caps — extend existing tests with semantic integration paths (currently data-only). Could also be handled in task-085 BDD (flows 4 and 7).

**Intentionally NOT recommending new tests for:**
- `scripts/main.gd` (scene bootstrap — integration test territory, not unit)
- `scripts/world.gd` (8 lines, trivial scene wiring)
- `scripts/recipes/recipe.gd` and `scripts/recipes/predicate.gd` (10-line data containers fully covered through their registry/evaluator tests)
- `scripts/data/cutscene_def.gd` and `scripts/journal/journal_entry.gd` (thin Gear subclasses, covered via their parent registries)
- `ui/joystick_overlay.gd` (mobile-specific, LOW risk per priority rules)
- Most static enum/marker cap tests (task-084 pitfall: don't chase coverage for trivial helpers)

**Total new test files recommended:** ~9 (2 autoload, 4 UI, 3 gap-fills of existing). Fits within the 084c (6h) + 084d (4h) budget.
