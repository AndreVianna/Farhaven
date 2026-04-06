# task-005 State

**Status:** Done
**Started:** 2026-04-03
**Completed:** 2026-04-03
**Cycles:** 1

## Current Grade: A

## Artifacts

- `DirtyTracker` class in `tools/level-editor/index.html`
- Wired to `CommandHistory.onChange`: any execute/undo/redo marks command's tab dirty
- `updateTabIndicators()` function: ` *` suffix and `tab-dirty` CSS class
- CSS for dirty indicator: amber dot (8px circle, top-right)
- `beforeunload` handler with `hasUnsavedChanges()` guard
- `saveAll()` function: iterates tabs, saves dirty ones, clears on success, keeps dirty on failure
- `saveTab()` function: serializes map JSON and .tres files
- Ctrl+S wired to `saveAll()`
- Unit tests: 5 DirtyTracker tests, all passing

## Acceptance Criteria

- [x] Any command execution marks the affected tab as dirty
- [x] Tab buttons show ` *` suffix and amber dot indicator when dirty
- [x] Tab buttons show clean state after save
- [x] `beforeunload` warning fires when closing browser with unsaved changes
- [x] `beforeunload` does NOT fire when all changes are saved
- [x] `saveAll()` writes all dirty files and clears dirty state on success
- [x] `saveAll()` keeps dirty flag on save failure and shows error message
- [x] Project load clears all dirty state
- [x] Ctrl+S triggers `saveAll()`

## Review History

| # | Date | Grade | Notes |
|---|------|-------|-------|
| 1 | 2026-04-03 | A | All AC met. DirtyTracker fully integrated with CommandHistory and UI. |
