# task-005: Unsaved Changes -- DirtyTracker and beforeunload

**Type:** IMPLEMENT

**Source:** feature-009-unsaved-changes -> delivery-001

**Depends on:** task-004

**Scope:**
- Implement `DirtyTracker` class: `dirtyTabs` (Set), `onChange` callback
  - `markDirty(tab)`, `markClean(tab)`, `markAllClean()`, `isDirty(tab)`, `hasUnsavedChanges()`
- Wire `DirtyTracker` to `CommandHistory.onChange`: any execute/undo/redo marks the command's `tab` as dirty
- Implement `updateTabIndicators()`: iterate `.tab-btn` elements, append ` *` to label and add `tab-dirty` CSS class when dirty, remove when clean
- Implement CSS for dirty indicator: `.tab-dirty::after` amber dot (8px circle, top-right of tab button)
- Register `beforeunload` handler: triggers native browser warning when `dirtyTracker.hasUnsavedChanges()` is true
- Implement `saveAll()` function: iterate tabs, save dirty ones via `FileDiscovery.saveFile()`, call `markClean()` on success, show error and keep dirty flag on failure
- Implement `saveTab(tab)` function: serialize and write files for the given tab (map -> JSON.stringify, resources/biomes -> TresParser.serialize)
- Wire Ctrl+S shortcut to `saveAll()`
- Call `dirtyTracker.markAllClean()` on project load

**Acceptance Criteria:**
- [ ] Any command execution marks the affected tab as dirty
- [ ] Tab buttons show ` *` suffix and amber dot indicator when dirty
- [ ] Tab buttons show clean state (no indicator) after save
- [ ] `beforeunload` warning fires when closing browser with unsaved changes
- [ ] `beforeunload` does NOT fire when all changes are saved
- [ ] `saveAll()` writes all dirty files and clears dirty state on success
- [ ] `saveAll()` keeps dirty flag on save failure and shows error message
- [ ] Project load clears all dirty state
- [ ] Ctrl+S triggers `saveAll()`
