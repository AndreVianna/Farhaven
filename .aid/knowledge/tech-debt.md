# Tech Debt

> **Source:** discovery-quality-assessor + pre-delivery-005 audit
> **Status:** Active
> **Last Updated:** 2026-04-08

## Summary

**Overall debt level: Medium-Low.** Post-PR#10 cleanup and the pre-delivery-005
functional audit closed most Critical/High save-load robustness gaps. The
remaining debt is scattered polish + a few items formally deferred to
delivery-005a or later.

## Deferred from 2026-04-08 pre-delivery-005 audit

These items were surfaced during the Fase 1 functional audit (game loop +
save/load + editor Prop/Biome pages) and explicitly deferred after discussion
with Andre. Critical items not listed here were fixed in the same session.

### [Medium] DayNightCycle writes `chapter_id` that is never read on load
- **Evidence:** `scripts/day_night/day_night_cycle.gd` `get_save_data()` writes
  `"chapter_id": 1` (hardcoded constant). `load_save_data()` never reads the
  key. Orphaned field.
- **Impact:** No functional impact today — chapter_id is always 1. But the
  field is misleading: it looks like multi-chapter persistence exists when it
  doesn't.
- **Effort:** 15 min to either remove the field or wire it into load + plumb
  through to the game when multi-chapter arrives.

### [Medium] Catalog legacy "discovered" key silently demotes ENCOUNTERED → CATALOGED
- **Evidence:** `scripts/scanner/catalog.gd:204-208`. Supports the pre-scan-redesign
  save format but collapses knowledge state nuance.
- **Impact:** Old saves lose the distinction between ENCOUNTERED fauna (seen
  but not cataloged) and CATALOGED. Acceptable for a one-time migration, but
  should emit a push_warning so players know their save was migrated.
- **Effort:** 10 min. Add warning when legacy key is consumed.

### [Medium] SurvivalSystem.load_save_data does not validate respawn_tile
- **Evidence:** `survival_system.gd:384-386` reads `respawn_tile_col`/`row`
  without confirming the tile still exists in HexGrid._tiles after load.
- **Impact:** If the shelter that set the respawn was destroyed and the save
  loaded, respawn silently falls back to Vector2i.ZERO instead of the latest
  valid shelter.
- **Effort:** 20 min. Validate against HexGrid._tiles after load, walk the
  structure list to find the current respawn point if the saved one is gone.

### [Medium] CraftingSystem.load_save_data does not validate recipe names
- **Evidence:** `crafting_system.gd:236-240` appends raw StringNames to
  `_discovered_recipes` without checking RECIPE_CONFIG membership.
- **Impact:** If a recipe is removed/renamed in code, stale entries persist in
  the player's discovered list forever. Low impact today (no recipes have been
  removed) but fragile.
- **Effort:** 10 min. Filter against RECIPE_CONFIG during load, log warning
  for dropped recipes.

### [Medium] ELEVATION_SCALE / ELEVATION_STEP duplicated
- **Evidence:** `player.gd:18` defines `ELEVATION_SCALE: float = 0.5` and
  `hex_grid.gd:19` defines `ELEVATION_STEP: float = 0.5`. Both represent the
  same value ("world Y per elevation level") with different names.
- **Impact:** Risk of drift — if one is updated the other silently becomes
  wrong, breaking player vs terrain Y alignment.
- **Effort:** 15 min. Promote to a single constant in HexGrid (or a shared
  constants module), have Player preload it, remove the duplicate.

### [Medium] tres-parser.js has no schema validation
- **Evidence:** `tools/level-editor/js/tres-parser.js:34-162, 500-560`.
  Parser accepts any field without checking required fields, no type coercion.
- **Impact:** Malformed `.tres` files load silently; corruption can spread on
  save. Practical risk is low because Godot writes well-formed .tres, but
  hand-edited files could cause silent editor corruption.
- **Effort:** 1-2 hours. Define a schema per known resource type and validate
  on parse. Probably worth batching with a larger editor hardening pass.

### [Low] BiomeData prop_table has unused fields `chance` / `min_amount`
- **Evidence:** `data/biomes/*.tres` entries write all four keys; `map_loader.gd`
  only reads `type` and `max_amount`.
- **Decision:** Kept intentionally — these fields are reserved for future
  procedural biome generation (see comment in `biome_data.gd`). Not debt,
  just pre-implementation data.
- **Effort:** 0 (no action needed — update was the comment in `biome_data.gd`).

### [Low] Map JSON `rotation` type inconsistency
- **Evidence:** `data/maps/ch1.json:21` writes `"rotation": 18` (integer degrees);
  `scripts/hex/map_loader.gd:107` reads as `float`. Implicit cast is safe.
- **Impact:** None functionally. Inconsistent schema.
- **Effort:** 5 min. Either normalize editor output to float or document the
  integer-degrees convention.

### [Low] Mixed numeric vs semantic StringName IDs across the code base
- **Evidence:** PropDef IDs are numeric StringNames (`&"00001"`, `&"00010"`,
  etc.), but catalog entry IDs, recipe keys, tool slot names, and category
  names are still semantic strings (`&"wood_tree"`, `&"survival_knife"`,
  `&"pickaxe"`).
- **Impact:** Confusing for new contributors. Rename windows (like PR #10)
  become error-prone because the same "id-like" StringName can mean different
  things in different layers.
- **Effort:** Architectural discussion first. Either migrate everything to
  numeric (with a display_name lookup layer) or keep the hybrid and document
  the convention clearly.

### [Low] prop-editor.js `prop_origin` / `origin` field asymmetry
- **Evidence:** Editor model stores `prop_origin`; `.tres` files use `origin`.
  The fromEntry/propModelToRaw pair translates both directions correctly but
  the asymmetry is surprising.
- **Decision:** Intentional — the editor namespaces all Prop-placement
  defaults with a `prop_` prefix in the model, and the .tres field is the
  one PropDef actually exports. Comment at `prop-editor.js:127-129` explains
  it, but could be clearer.
- **Effort:** 5 min to add a clarifying note, or defer the naming cleanup.

### [Low] No UI for yield_type variations, placeholder shape preview,
prop rename cascade, or dirty-state window-close warning
- **Evidence:** Editor lacks UX polish items flagged by the 2026-04-08 audit.
- **Decision:** yield_type variations go into delivery-005a (task-041).
  Others are defer-pending-need.

## Pre-existing items (from 2026-04-03 discovery)

## Debt Items

### [High] No CI/CD Pipeline

- **Evidence:** No .github/workflows/, no Jenkinsfile, no Makefile, no build scripts anywhere in the repository. Confirmed in project-structure.md observation #5.
- **Impact:** Tests only run when a developer manually opens the Godot editor and triggers them. Regressions can ship undetected. No automated build validation for PRs.
- **Effort:** 2-4 hours. gdUnit4 supports headless CLI execution. A GitHub Actions workflow with godot --headless is straightforward.

### [High] No Export Configuration

- **Evidence:** No export_presets.cfg file exists. Confirmed in project-structure.md observation #4 and external-sources.md Source 4 discrepancies.
- **Impact:** Cannot produce Android APK/AAB or iOS builds. Blocks any real-device testing or store submission. The game targets mobile but has never been built for mobile.
- **Effort:** 1-2 hours for Android export preset. iOS requires macOS access (unconfirmed availability per external-sources.md Source 5).

### [High] Some Source Files Still Have No Direct Test Coverage

- **Evidence:** 2026-04-03 audit flagged 20 files. Post-PR#10 status:
  - `prop_node.gd` — DELETED, replaced by unified `prop.gd` (has tests).
  - `hex_grid.gd` — now exercised by integration tests (`test_delivery_001`,
    `test_delivery_004`) and indirectly via every renderer test.
  - `main.gd` — still untested (bootstrap).
  - HUD files: still largely untested.
  - `player_pathfinder.gd` — still untested.
  - `prop_utils.gd`, `catalog_data.gd`, `catalog_entry.gd`, `gather_sound.gd`
    — still untested.
- **Impact:** Regressed files would still escape CI. Less urgent than in
  April since critical data paths are covered, but HUD + audio are growing.
- **Effort:** 6-10 hours for the remaining non-trivial files.

### ~~[High] Save/Load Serialization Has No Tests~~ — RESOLVED 2026-04-08

- **Status:** Resolved during delivery-004 + post-PR#10 cleanup. Save/load
  round-trip is now exercised by `test_delivery_004.gd` (DayNightCycle +
  HexGrid), `test_survival_death.gd` (SurvivalSystem + ground items),
  `test_survival_integration.gd` (full survival stack), and `test_inventory.gd`
  (Inventory with bonus_slots expansion).

### [High] Renderer Mismatch: Mobile vs. Compatibility

- **Evidence:** project.godot line 49 sets renderer/rendering_method="mobile" (Vulkan Mobile). docs/01-godot-engine-setup.md recommends Compatibility renderer for broadest device support. Noted in external-sources.md Source 2 and Source 4 discrepancies.
- **Impact:** The Mobile renderer requires Vulkan-capable devices. Older Android devices (pre-2018, some budget devices) lack Vulkan support and will not run the game. This directly conflicts with the GDD casual mobile audience target.
- **Effort:** 1 hour to switch and test. May require shader adjustments. Decision should be made deliberately.

### [Medium] Large File: prop_renderer.gd (473 lines)

- **Evidence:** scripts/rendering/prop_renderer.gd -- 473 lines, largest source file in the project.
- **Impact:** Harder to navigate, test, and maintain. The file handles MultiMesh pooling, mesh generation, visibility updates, resource depletion/respawn, and fog state -- multiple responsibilities.
- **Effort:** 2-4 hours to extract mesh generation and pool management into separate files.

### [Medium] Large File: auto_interaction_system.gd (409 lines)

- **Evidence:** scripts/auto_interaction/auto_interaction_system.gd -- 409 lines.
- **Impact:** Complex system with proximity detection, auto-gather, and auto-scan logic in one file. Well-tested (3 test files) but size makes changes risky.
- **Effort:** 2-3 hours to split into focused subsystems.

### ~~[Medium] Save Data Lacks Validation on Load~~ — PARTIALLY RESOLVED 2026-04-08

- **Status:** HexGrid, Inventory, and DayNightCycle were hardened in the
  post-PR#10 cleanup. HexGrid now uses `.get()` with defaults + skips
  malformed tile entries. Inventory preserves slots beyond current capacity
  with a push_warning instead of silent truncation. DayNightCycle validates
  the phase enum and clamps phase_elapsed.
- **Remaining:** SurvivalSystem respawn_tile + CraftingSystem recipe name
  validation are still deferred — see the 2026-04-08 section above.

### [Medium] No Save Persistence Layer

- **Evidence:** get_save_data() and load_save_data() methods exist but no code writes to or reads from disk. No FileAccess.open(path, WRITE) call outside of map loading (which is read-only).
- **Impact:** The game cannot save or load progress. This is a planned feature but represents incomplete infrastructure.
- **Effort:** 2-4 hours for a basic JSON save/load manager.

### [Medium] Heavy Addon Footprint

- **Evidence:** addons/gdUnit4/ contains 934 files vs. 59 project source files. Noted in project-structure.md observation #6.
- **Impact:** Repository clones are slower, git operations on the addon directory add noise. Not a functional issue but adds friction.
- **Effort:** Low. Could use git submodule or Godot Asset Library for gdUnit4 instead of vendoring.

### [Low] Scripts Split Across Two Locations

- **Evidence:** Most scripts in scripts/, but UI scripts in ui/ and one renderer in scenes/world/. Noted in project-structure.md observation #2.
- **Impact:** Minor confusion for new contributors. Consistent convention would improve navigability.
- **Effort:** 1 hour to relocate, but requires updating all scene references.

### [Low] .uid Files Committed to Repository

- **Evidence:** 28+ .uid files in scripts/ and ui/ directories. These are Godot 4.x UID tracking files. Noted in project-structure.md observation #3.
- **Impact:** Repository noise. These files are auto-generated and could be gitignored, but Godot documentation is ambiguous about whether they should be committed.
- **Effort:** Minimal. Add *.uid to .gitignore if confirmed safe.

### [Low] No Automated Code Quality Checks

- **Evidence:** No linter, no static analysis, no pre-commit hooks. GDScript has limited tooling (gdtoolkit/gdlint exists but is not configured).
- **Impact:** Style inconsistencies possible, though current codebase is consistent.
- **Effort:** 1-2 hours to set up gdtoolkit if desired.

## Metrics

- **TODO/FIXME count:** 0 in project source files (scripts/, ui/, scenes/). All TODO/FIXME hits are inside the vendored addons/gdUnit4/ directory.
- **Files > 500 lines (source):** None. Largest is prop_renderer.gd at 473 lines.
- **Files > 500 lines (tests):** test_delivery_003.gd (1,236), test_delivery_002.gd (911), test_auto_gather.gd (781), test_auto_interaction_stubs.gd (639), test_delivery_001.gd (572), test_scanner_system.gd (558), test_crafting_system.gd (504).
- **Files > 1000 lines:** test_delivery_003.gd (1,236 lines) -- acceptable for an integration test file.
- **Test-to-code ratio:** 9,594 test lines / 5,519 source lines = 1.74:1 -- strong ratio for a game project.
- **Assertion density:** 1,065 assertions across ~518 test functions = ~2.1 assertions per test -- adequate.
- **Signal count:** 59 signal declarations across source files -- moderate coupling through observer pattern.
- **class_name registrations:** 30 of 41 source files -- most scripts register a global class name. 11 exceptions: autoloads (hex_grid.gd, prop_registry.gd), bootstrap (main.gd), player core (player.gd, player_camera.gd), map_loader.gd, renderers (prop_renderer.gd, prop_label_renderer.gd, scan_progress_renderer.gd, hex_grid_renderer.gd), and crafting_system.gd.
