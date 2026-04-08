# Tech Debt

> **Source:** discovery-quality-assessor
> **Status:** Active
> **Last Updated:** 2026-04-03

## Summary

**Overall debt level: Medium.** The codebase is young (~60 source files, ~5,400 lines) and generally well-structured. The primary debt is in missing infrastructure (no CI/CD, no export config) and incomplete test coverage for key modules. No critical blockers, but several high-priority items will become painful as the project grows.

## Debt Items

### [High] No CI/CD Pipeline

- **Evidence:** No .github/workflows/, no Jenkinsfile, no Makefile, no build scripts anywhere in the repository. Confirmed in project-structure.md observation #5.
- **Impact:** Tests only run when a developer manually opens the Godot editor and triggers them. Regressions can ship undetected. No automated build validation for PRs.
- **Effort:** 2-4 hours. gdUnit4 supports headless CLI execution. A GitHub Actions workflow with godot --headless is straightforward.

### [High] No Export Configuration

- **Evidence:** No export_presets.cfg file exists. Confirmed in project-structure.md observation #4 and external-sources.md Source 4 discrepancies.
- **Impact:** Cannot produce Android APK/AAB or iOS builds. Blocks any real-device testing or store submission. The game targets mobile but has never been built for mobile.
- **Effort:** 1-2 hours for Android export preset. iOS requires macOS access (unconfirmed availability per external-sources.md Source 5).

### [High] 20 of 41 Source Files Have No Test Coverage

- **Evidence:** Files without corresponding tests (see test-landscape.md for full list):
  - Core: hex_grid.gd, hex_tile.gd, prop_node.gd, main.gd
  - HUD: hud.gd, stat_bars.gd, notification_manager.gd, floating_text_manager.gd, day_counter.gd, craft_flash.gd
  - Data: prop_def.gd, prop_registry.gd
  - Player: player_camera.gd, player_pathfinder.gd
  - Rendering: fly_to_player.gd, prop_label_renderer.gd, prop_utils.gd
  - Scanner: catalog_data.gd, catalog_entry.gd
  - Audio: gather_sound.gd
- **Impact:** 50% of source files can break without any test catching it. Particularly concerning for hex_grid.gd (220 lines, singleton, used everywhere) and player_pathfinder.gd (core movement logic).
- **Effort:** 8-16 hours for critical files (hex_grid, player_pathfinder, main). Lower priority files (HUD, audio) can be deferred.

### [High] Save/Load Serialization Has No Tests

- **Evidence:** 5 scripts implement get_save_data()/load_save_data() (hex_grid.gd, player.gd, inventory.gd, crafting_system.gd, catalog.gd). No test file exercises round-trip serialization.
- **Impact:** Save corruption bugs will not be caught until players lose progress. Save/load is the most critical data integrity feature in a single-player game.
- **Effort:** 2-4 hours to write round-trip tests for all 5 serializers.

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

### [Medium] Save Data Lacks Validation on Load

- **Evidence:** hex_grid.gd line 204 uses bracket access td["tile_col"] without .get() fallback -- will crash if key is missing. inventory.gd line 213 uses mini() for bounds checking (better). Inconsistent validation across the 5 serializable modules.
- **Impact:** Corrupted or hand-edited save files could crash the game rather than failing gracefully. Users lose trust.
- **Effort:** 2-3 hours to add defensive validation to all load_save_data() methods.

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
