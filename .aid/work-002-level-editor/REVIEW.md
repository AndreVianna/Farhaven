# Code Review: Level Editor -- Code Quality Review

**Date:** 2026-04-04
**Reviewer:** Critic Agent
**Branch:** editor/delivery-002
**Scope:** All 12 JS modules in tools/level-editor/js/ + test-unit.mjs
**Focus:** Clean Code, DRY, YAGNI, Separation of Concerns, Readability, Consistency

---

## Overall Grade: **A-**

The codebase is well-organized with clear module boundaries, good separation of concerns, comprehensive JSDoc, consistent naming conventions, and 225 passing unit tests. The architecture (command pattern, tool hierarchy, model/view separation) is sound. The two previous P2 blockers (N1 eraser sub-hex, N2 load return value) are now fixed.

Issues found are primarily P3 DRY violations and P4 consistency nitpicks. For an internal editor tool, the code is above the bar. The two carry-over P3 SPEC deviations (flat error strings, hardcoded newMap metadata) remain but are not quality regressions.

---

## Previous P2 Verification

| ID | Issue | Status | Evidence |
|----|-------|--------|----------|
| N1 | Eraser never receives sub-hex | **FIXED** | canvas.js:433 -- _isPlacementTool() now includes eraser |
| N2 | loadMapIntoGrid return value discarded | **FIXED** | app.js:378-384 -- return checked, error shown via setStatus() |

## Previous P3 Verification

| ID | Issue | Status | Evidence |
|----|-------|--------|----------|
| N3 | Validator missing structure type validation | **FIXED** | validator.js:60-62 |
| N4 | Validator missing rotation range check | **FIXED** | validator.js:65-69 |
| N5 | Validator missing knownStructures param | **FIXED** | validator.js:16 |
| N6 | Validator error format is flat strings | **OPEN** | Still string[], SPEC wants {field, message, hex} objects |
| N7 | newMap() hardcodes metadata | **OPEN** | app.js:230 still sets chapter_id: new, name: New Map |

---

## Test Results

225 assertions: 225 passed, 0 failed. Exit code: 0. All tests pass. No regressions.

---

## New Issues

### DRY Violations

**D1.** [CODE] [P3] Hex polygon path drawing duplicated 8 times | canvas.js:200-206, 282-290, 306-313, 454-462, 493-498, 505-510, 533-540, 773-783 | Principle: DRY
- The pattern beginPath / moveTo(corners[0]) / for(i=1..5) lineTo(corners[i]) / closePath is repeated 8 times across _drawHex, _drawSelection, _drawHoverHighlight, _drawSubHexGrid, _drawSubHexOccupancy (x2), _drawSubHexHover, and _drawGhostHex.
- Should be extracted to a _traceHexPath(corners) helper.

**D2.** [CODE] [P3] Key parsing pattern duplicated 6 times | canvas.js:120-122, 128-130, 747-749, 813-815 + validator.js:31-33 + hex-grid.js:143-144 | Principle: DRY
- The sequence (split comma, parseInt both parts) appears 6 times across 3 files.
- HexGrid already has getKey(q, r). A symmetric parseKey(key) method would centralize this.

**D3.** [CODE] [P3] File discovery load-and-store pattern repeated 3 times | file-discovery.js:98-165, 172-235, 277-339 | Principle: DRY
- discoverProject, discoverFromFileList, and discoverViaApi each contain nearly identical for-loops for maps, resources, and biomes.
- A shared _loadFileSet helper would eliminate around 100 lines of duplication.

**D4.** [CODE] [P4] World-to-screen + hex corner computation repeated in every draw method | canvas.js (12 occurrences) | Principle: DRY
- The 3-line sequence (axialToPixel, worldToScreen, HEX_SIZE * zoom) appears in 12 different draw methods.
- A _getHexScreenPos(q, r) helper returning {screen, size} would reduce noise.

### Magic Values

**M1.** [CODE] [P3] Magic color strings in canvas rendering | canvas.js:110, 262, 288, 348, 385, 400, 412 | Principle: Clean Code -- named constants
- Background (#1a1a2e), cliff edge (#8B4513), selection (#ffffff), spawn (#ffcc00), resource badge (#4488ff), structure badge (#ffaa44), anomaly badge (#b444ff) are all inline magic strings.
- BIOME_FALLBACK_COLOR at line 8 shows the right pattern already exists but was not applied to the other colors.

**M2.** [CODE] [P4] Magic color strings duplicated between canvas.js and panels.js | canvas.js:385,400,412 vs panels.js:144-145 | Principle: DRY
- Category colors (resource, structure, anomaly) are defined independently in both files.
- These could live in a shared CATEGORY_COLORS constant.

**M3.** [CODE] [P4] Magic numbers in canvas rendering | canvas.js:227, 326-327, 344, 374, 382-393, 399, 404, 709
- Font size calculations, position offsets (0.35, 0.3, 0.25), and zoom limits (0.2, 3.0) are inline magic numbers.
- Tolerable for an internal rendering tool but could improve readability if named.

### Long Functions

**L1.** [CODE] [P3] _renderContent() is 120 lines | panels.js:110-230 | Principle: Clean Code -- functions should do one thing
- This method builds DOM for: header with close button, empty state, and per-prop rows.
- Could be decomposed into _renderHeader(), _renderPropRow(prop, index), and _renderEmptyState().

**L2.** [CODE] [P4] render() is 72 lines | canvas.js:104-176 | Principle: Clean Code -- single level of abstraction
- Sequential composition of drawing calls. Each step delegated to a helper. Acceptable but could benefit from grouping phases.

**L3.** [CODE] [P4] loadMapIntoGrid() is 94 lines | hex-grid.js:127-221 | Principle: Clean Code -- single level of abstraction
- Mixes legacy format detection with the main load loop. The legacy parsing block (lines 158-214) could be extracted to _parseLegacyTile(tileJson).

### Separation of Concerns

**S1.** [CODE] [P3] Tool imports UI function from panels.js | tools.js:17 imports showInlineModal | Principle: Separation of Concerns
- AnomalyMarker.onMouseDown() directly invokes a UI modal dialog. This couples the tool layer to the presentation layer.
- A cleaner pattern: AnomalyMarker signals that it needs user input, and the UI layer provides the modal.

### Consistency

**C1.** [CODE] [P4] Inconsistent onChange pattern: single callback slot | hex-grid.js:53, commands.js:16, dirty-tracker.js:10
- All three use a single onChange callback. canvas.js:65 overwrites grid.onChange. Comment on hex-grid.js:48-53 acknowledges this limitation.

**C2.** [CODE] [P4] Inconsistent error reporting in app.js | app.js:110-112, 119-122, 251, 329, 380-381
- showError() wraps with Error prefix, but some call sites add their own prefix, and others use setStatus directly.

### Carry-Over Issues (Noted, Not New)

**CO1.** [SPEC] [P3] Validator error format is flat strings | validator.js:100-103 | SPEC feature-004 line 84
- Currently only consumed by app.js:251 which reads errors[0] as a string. No immediate breakage, but deviates from SPEC contract.

**CO2.** [SPEC] [P3] newMap() hardcodes metadata | app.js:230 | SPEC feature-004 lines 160-163
- All new maps get identical metadata. Low impact since users can edit metadata in JSON.

**CO3.** [CODE] [P4] No test coverage for validator.js | test-unit.mjs | Previous review N8
- validateMap has non-trivial logic (overlap detection, sub-hex validation, rotation range) with zero test assertions.

---

## Summary

| Severity | Count | Category |
|----------|-------|----------|
| P2 (Major) | 0 | none |
| P3 (Minor) | 7 | D1, D2, D3, M1, L1, S1, + 2 carry-over |
| P4 (Nitpick) | 8 | D4, M2, M3, L2, L3, C1, C2, CO3 |
| **Total** | **15** |  |

---

## Verdict

**Grade: A-** -- Passes quality gate. Ships.

The codebase demonstrates good engineering discipline: clear module boundaries, command pattern for undo/redo, tool inheritance hierarchy, proper model/view separation, and thorough test coverage of core logic. The issues found are DRY violations and cosmetic inconsistencies, not architectural problems.

**Recommended improvements for next cycle (priority order):**
1. Extract _traceHexPath(corners) helper in canvas.js (D1) -- highest impact, simplest fix
2. Add parseKey(key) utility to eliminate key-parsing duplication (D2)
3. Extract shared file-loading logic in file-discovery.js (D3)
4. Name the magic colors as constants (M1, M2)
5. Decompose _renderContent() in panels.js (L1)
6. Add validator.js unit tests (CO3)

None of these block shipping. The two carry-over SPEC deviations (CO1, CO2) are acknowledged technical debt.
