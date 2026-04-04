# Test Landscape

> **Source:** discovery-quality-assessor
> **Status:** Active
> **Last Updated:** 2026-04-03

## Test Frameworks

| Framework | Version | Config Location |
|-----------|---------|-----------------|
| gdUnit4   | 6.0.3   | `addons/gdUnit4/plugin.cfg`, enabled in `project.godot` line 41 |

gdUnit4 is a GDScript-native unit testing framework for Godot. All test files extend `GdUnitTestSuite`.

## Test Types Found

- **Unit tests:** `tests/unit/` — 20 files, ~512 test functions (via `func test_*` convention)
- **Integration tests:** `tests/integration/` — 3 files (one per delivery phase), ~88 test functions
- **E2E tests:** None. No automated end-to-end or scene-runner-based tests found.
- **Other:** None. No snapshot, contract, or performance tests.

### Test File Inventory

| File | Test Count | Lines | Type |
|------|-----------|-------|------|
| test_delivery_001.gd | 31 | 572 | Integration |
| test_delivery_002.gd | 33 | 911 | Integration |
| test_delivery_003.gd | 24 | 1236 | Integration |
| test_auto_gather.gd | 33 | 781 | Unit |
| test_auto_interaction_stubs.gd | 23 | 639 | Unit |
| test_auto_interaction_system.gd | 37 | 235 | Unit |
| test_biome_data.gd | 3 | 29 | Unit |
| test_catalog.gd | 54 | 492 | Unit |
| test_catalog_panel_ui.gd | 30 | 300 | Unit |
| test_crafting_panel.gd | 33 | 431 | Unit |
| test_crafting_system.gd | 42 | 504 | Unit |
| test_feedback_wiring.gd | 21 | 458 | Unit |
| test_hex_grid_renderer.gd | 11 | 197 | Unit |
| test_hex_math.gd | 20 | 138 | Unit |
| test_inventory.gd | 60 | 447 | Unit |
| test_map_loader.gd | 23 | 342 | Unit |
| test_player.gd | 23 | 312 | Unit |
| test_player_input.gd | 19 | 228 | Unit |
| test_prop_renderers.gd | 11 | 231 | Unit |
| test_resource_renderer.gd | 32 | 378 | Unit |
| test_scan_progress_renderer.gd | 7 | 171 | Unit |
| test_scanner_system.gd | 29 | 558 | Unit |
| test_setup.gd | 1 | 4 | Smoke |

**Totals:** 23 test suites, ~600 test functions (512 unit + 88 integration), 9,594 lines of test code, 1,065 assertions.

## Coverage

- **Coverage tool:** None configured. gdUnit4 does not include built-in code coverage for GDScript.
- **Coverage percentage:** Unknown — no coverage tooling exists for GDScript in Godot 4.x.
- **Note:** GDScript lacks instrumentation-based coverage tools. Coverage can only be estimated by mapping test files to source files.

### Estimated Coverage by Module

| Module | Source Files | Test Files | Status |
|--------|-------------|------------|--------|
| hex/ | 6 files | 2 (hex_math, map_loader) | Partial — hex_grid, hex_tile, biome_data, resource_node untested directly |
| player/ | 4 files | 2 (player, player_input) | Partial — player_camera, player_pathfinder untested |
| inventory/ | 1 file | 1 (inventory) | Good |
| crafting/ | 1 file | 1 (crafting_system) | Good |
| scanner/ | 4 files | 2 (catalog, scanner_system) | Partial — catalog_data, catalog_entry untested |
| auto_interaction/ | 1 file | 3 (auto_gather, stubs, system) | Good |
| rendering/ | 5 files | 3 (resource_renderer, prop_renderers, scan_progress) | Partial — fly_to_player, prop_label_renderer untested |
| hud/ | 6 files | 1 (feedback_wiring) | Low — 5 of 6 files untested |
| ui/ | 8 files | 2 (crafting_panel, catalog_panel_ui) | Low — 6 of 8 files untested |
| data/ | 2 files | 0 | None |
| audio/ | 1 file | 0 | None |
| main.gd | 1 file | 0 | None |

## Test Commands

```bash
# Run all tests (from Godot editor)
# gdUnit4 runs inside the Godot editor via its built-in test runner panel.
# There is no standalone CLI test runner configured.

# Run tests via Godot headless
# godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/

# Run a single test suite
# godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/unit/test_hex_math.gd
```

Note: No CI/CD pipeline exists to run these commands automatically. Tests are run manually from the Godot editor.

## CI/CD Integration

**None.** No `.github/workflows/`, no `Jenkinsfile`, no `Makefile`, no build scripts exist.
Tests are editor-only. See `project-structure.md` observation #5.

## Testing Patterns

### Test Structure
- All test files extend `GdUnitTestSuite` and use `class_name Test*` convention.
- Setup/teardown via `before_test()` / `after_test()` hooks (used in 19 of 23 suites).
- Integration tests create HexGrid instances manually via `load().new()` + `add_child()` and free them in `after_test()`.

### Assertion Style
- Uses gdUnit4 fluent assertions: `assert_int()`, `assert_bool()`, `assert_str()`, `assert_float()`, `assert_array()`, `assert_dict()`, `assert_object()`.
- Example from `test_hex_math.gd` line 9:
  ```gdscript
  var neighbors: Array[Vector2i] = HexMath.get_neighbors(Vector2i(0, 0))
  assert_int(neighbors.size()).is_equal(6)
  ```

### Mocking / Stubbing
- Limited mock usage. Only 5 test files reference mock/stub/double patterns.
- `test_auto_interaction_stubs.gd` — dedicated stub file for auto-interaction testing.
- `test_crafting_panel.gd` and `test_crafting_system.gd` — use stub/mock objects.
- `test_player_input.gd` — minimal mock usage.
- Most tests use real objects instantiated directly via `preload().new()`.

### Data Loading
- Integration tests load the real map file (`res://data/maps/ch1.json`) for testing.
- Unit tests construct test data inline rather than using fixture files.

### Manual Verification Notes
- Integration test files document manual-only checks in header comments (e.g., `test_delivery_001.gd` lines 8-15: visual checks for biome colors, camera smoothness, joystick overlay).

## Gaps

1. **No coverage tooling** — impossible to measure actual code coverage. ⚠️ Inferred from absence of any coverage configuration.
2. **20 of 41 source files have no dedicated test file** — including core files like `hex_grid.gd`, `main.gd`, `hud.gd`, and all data model files.
3. **No CI/CD test execution** — tests only run manually in the editor.
4. **No E2E tests** — no scene_runner or automated UI interaction tests.
5. **No performance tests** — no benchmarks for rendering (ArrayMesh/MultiMesh with ~300 tiles).
6. **HUD subsystem poorly tested** — only `test_feedback_wiring.gd` covers the 6-file HUD module.
7. **Save/load serialization untested** — 5 scripts implement `get_save_data()`/`load_save_data()` but no tests exercise round-trip serialization.
