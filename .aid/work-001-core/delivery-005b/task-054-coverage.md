# task-054: Test Coverage to 90% — Cyclic execution

**Status:** Ready for execution (after task-053 completes)
**Created:** 2026-04-09
**Source:** Code review audit — 46% coverage (26/57 scripts have tests)
**Branch:** delivery-005b
**Execution:** Cyclic elfo. Runs until coverage >= 90%. Each cycle: write tests → run → fix failures → measure coverage → repeat.

## Goal

Increase test coverage from 46% (26/57 scripts) to 90%+ (52+/57 scripts).

## Quality rules — NON-NEGOTIABLE

- **Good assertions.** Every test must assert something meaningful about behavior, not just "runs without error."
- **No repetition.** Don't write the same test with different variable names. Each test covers a unique code path or edge case.
- **No cheating.** Don't write tests that test nothing (empty bodies, assert_true(true), tests that only check type existence). Every test must be falsifiable — if the code had a bug, the test would catch it.
- **Real scenarios.** Test integration between systems, not just isolated getters/setters. Recipe → Inventory → Weight. Discovery → Catalog → Unlock. Lighting → Save/Load → Restore.
- **Edge cases matter.** Null inputs, empty arrays, boundary values, concurrent operations.

## Coverage targets by priority

### Priority 1: Scripts with 0 tests that handle critical logic

| Script | Lines | Why it matters |
|--------|-------|---------------|
| `scripts/recipes/world_context.gd` | ~50 | Data bag for all predicate evaluation |
| `scripts/recipes/recipe_effect.gd` | ~15 | Effect execution definitions |
| `scripts/recipes/recipe_condition.gd` | ~15 | Condition gate/sustain definitions |
| `scripts/recipes/recipe_input.gd` | ~20 | Input source routing |
| `scripts/recipes/recipe_output.gd` | ~15 | Output probability definitions |
| `scripts/data/capabilities/*.gd` (7 files) | ~15 each | Capability data classes |

### Priority 2: Scripts with integration-only tests that need unit tests

| Script | Lines | Current coverage |
|--------|-------|-----------------|
| `scripts/hex/hex_grid.gd` | 604 | Integration only (delivery tests) |
| `scripts/survival/survival_system.gd` | ~300 | Integration only |
| `scripts/scanner/scanner_system.gd` | ~250 | Unit tests exist but incomplete |
| `scripts/scanner/catalog.gd` | ~200 | Unit tests exist but incomplete |
| `scripts/inventory/inventory.gd` | ~300 | Good unit tests, missing weight edge cases |

### Priority 3: New delivery-005a systems needing deeper tests

| Script | Existing tests | Missing |
|--------|---------------|---------|
| `recipe_runtime.gd` | 22 tests | world_tile delivery, container delivery, overflow, concurrent recipes, save/load pending |
| `discovery_watcher.gd` | 14 tests | catalog signal → unlock chain, tool equip → unlock, multiple simultaneous unlocks |
| `predicate_evaluator.gd` | 51 tests | adjacent_to with real grid, prop_state with nested fields, container_has edge cases |
| `lighting_manager.gd` | 29 tests | save/load persistence, multiple lights same tile, player torch on load |
| `recipe_registry.gd` | 24 tests | duplicate ID detection, malformed .tres handling |

### Priority 4: UI and rendering (lower priority but still needed)

| Script | Lines | Notes |
|--------|-------|-------|
| `ui/catalog_panel.gd` | ~150 | Has some tests, needs category tab tests |
| `ui/crafting_panel.gd` | ~200 | Has tests but missing recipe refresh edge cases |
| `scripts/rendering/prop_renderer.gd` | ~473 | Has tests but missing structure rendering |
| `scripts/rendering/prop_label_renderer.gd` | ~200 | Has tests but missing anomaly label |

## Execution cycle (for the elfo)

```
REPEAT:
  1. Count scripts with tests vs without
  2. Pick the highest-priority untested script
  3. Write tests following the quality rules above
  4. Run ALL tests: godot --headless --script addons/gdUnit4/bin/GdUnitCmdTool.gd --add "res://tests/" --ignoreHeadlessMode
  5. Fix any failures (in TESTS, not in source code — if source code has a bug, document it as a finding and write the test to expect current behavior + add TODO comment)
  6. Count coverage: scripts_with_tests / total_scripts
  7. IF coverage < 90%: GOTO 1
  8. IF coverage >= 90%: STOP, report final count
UNTIL coverage >= 90%
```

## How to measure coverage

```bash
# Count scripts with dedicated test files
total=$(find scripts/ -name "*.gd" | wc -l)
tested=$(for f in $(find scripts/ -name "*.gd"); do
  base=$(basename "$f" .gd)
  if find tests/ -name "test_${base}.gd" -o -name "test_*${base}*.gd" | grep -q .; then
    echo "$f"
  fi
done | wc -l)
echo "Coverage: $tested / $total = $(( tested * 100 / total ))%"
```

Note: this is file-level coverage (does the script have a test file), not line-level coverage (GdUnit4 doesn't have line coverage). File-level coverage at 90% ensures every system has at least basic test verification.

## Constraints

- Do NOT modify source code to make tests pass (exception: if a test reveals a genuine bug, fix it and document the fix)
- Tests go in `tests/unit/` for unit tests and `tests/integration/` for cross-system tests
- Follow existing test patterns (extend GdUnitTestSuite, use assert_*, mock injectable dependencies)
- Each test file must have `class_name Test<ScriptName>` and `extends GdUnitTestSuite`
- Run the FULL test suite after each batch of new tests — no regressions allowed
