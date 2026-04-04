# Unsaved Changes Protection

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | New feature — protection against accidental data loss | Lola review |
| 2026-04-03 | Technical specification written | /aid-specify |
| 2026-04-03 | Review fixes: saveAll error handling, auto-save deferral note | /aid-specify review |

## Source

- REQUIREMENTS.md §5 F14 (Unsaved Changes Protection), §9 AC8

## Description

Protection against accidental data loss. The editor tracks dirty state across all three tabs (map, resource, biome). When unsaved changes exist: a visual indicator (asterisk in tab title or dot on tab) is shown, and attempting to close/refresh the browser triggers a `beforeunload` warning. Saving clears the dirty state and the indicator.

**Deferred: periodic auto-save.** REQUIREMENTS F14 lists auto-save as optional. File System Access API file handles are retained (saving is cheap), so auto-save is technically feasible. Deferred to post-MVP — the `beforeunload` guard provides sufficient protection for an internal tool.

## User Stories

- As Andre, I want to see which tabs have unsaved changes so that I know what needs saving
- As Andre, I want the browser to warn me before losing unsaved work so that accidental tab closes don't lose data

## Priority

Must

## Acceptance Criteria

- [ ] Given unsaved changes in the map tab, when the tab title is rendered, then an asterisk or visual indicator is visible
- [ ] Given unsaved changes in any tab, when attempting to close or refresh the browser, then a beforeunload warning dialog appears
- [ ] Given all changes saved, when the tab title is rendered, then no unsaved indicator is visible
- [ ] Given unsaved changes, when pressing Ctrl+S (save), then the dirty state clears and the indicator disappears

---

## Technical Specification

### Data Model

#### `DirtyTracker`

Tracks per-tab dirty state. A tab is dirty when it has unsaved modifications.

```js
class DirtyTracker {
  constructor() {
    this.dirtyTabs = new Set();  // Set<string> — 'map' | 'resources' | 'biomes'
    this.onChange = null;         // callback: () => void — called when dirty state changes
  }

  // Mark a tab as dirty. Called by CommandHistory.onChange.
  markDirty(tab)

  // Clear dirty flag for a tab. Called after successful save.
  markClean(tab)

  // Clear all dirty flags. Called after "Save All".
  markAllClean()

  // Returns true if the given tab has unsaved changes.
  isDirty(tab)

  // Returns true if ANY tab has unsaved changes.
  hasUnsavedChanges()
}
```

#### State Mapping

The `DirtyTracker` determines which tab to mark dirty based on the `command.tab` field from `CommandHistory`:

| `command.tab` | Dirty Tab |
|---|---|
| `'map'` | `'map'` |
| `'resources'` | `'resources'` |
| `'biomes'` | `'biomes'` |

### Feature Flow

1. **Integration with CommandHistory** — On `CommandHistory.onChange`:
   - `action === 'execute'` -> `dirtyTracker.markDirty(command.tab)`
   - `action === 'undo'` -> `dirtyTracker.markDirty(command.tab)` (undo is still a change relative to last save)
   - `action === 'redo'` -> `dirtyTracker.markDirty(command.tab)`
   - All three actions mark the tab dirty because the in-memory state now differs from the last-saved state.

   Note: A more precise approach would track a "save point" index in the command history and compare against the current position. However, the simpler "any command marks dirty, only save clears" approach is sufficient because: (a) the user saves infrequently relative to edits, and (b) saving an already-clean file is harmless.

2. **Save clears dirty state** — When `saveAll()` or `saveTab(tab)` completes successfully:
   - `dirtyTracker.markClean(tab)` for each tab that was saved.
   - `onChange` fires, UI updates.

3. **UI Indicator Update** — When `dirtyTracker.onChange` fires:
   - For each tab button/label element, check `dirtyTracker.isDirty(tabName)`.
   - If dirty: append ` *` to the displayed tab title (e.g. "Map Editor *") and add a CSS class `tab-dirty` that shows a small colored dot indicator.
   - If clean: remove the ` *` suffix and the `tab-dirty` class.

4. **Browser Close/Refresh Protection** — Register a `beforeunload` handler:

   ```js
   window.addEventListener('beforeunload', (event) => {
     if (dirtyTracker.hasUnsavedChanges()) {
       event.preventDefault();
       // Modern browsers ignore custom messages, but returnValue must be set.
       event.returnValue = '';
     }
   });
   ```

   This causes the browser to show its native "Changes you made may not be saved" dialog. The handler is always registered but only triggers the warning when `hasUnsavedChanges()` returns true.

5. **Project Load Reset** — When a new project is loaded or a new map is created, `dirtyTracker.markAllClean()` is called (the freshly loaded state matches disk).

### Layers & Components

#### `DirtyTracker` (singleton)

Single global instance, created alongside `CommandHistory`.

```js
const dirtyTracker = new DirtyTracker();

// Wire up to CommandHistory
commandHistory.onChange = (action, command) => {
  dirtyTracker.markDirty(command.tab);
  updateUndoRedoButtons();  // enable/disable based on canUndo/canRedo
};

// Wire up to UI
dirtyTracker.onChange = () => {
  updateTabIndicators();
};
```

#### Tab UI Indicators

Each tab in the editor header is rendered as a button element:

```html
<button class="tab-btn" data-tab="map">Map Editor</button>
<button class="tab-btn" data-tab="resources">Resources</button>
<button class="tab-btn" data-tab="biomes">Biomes</button>
```

The `updateTabIndicators()` function iterates all `.tab-btn` elements:

```js
function updateTabIndicators() {
  document.querySelectorAll('.tab-btn').forEach(btn => {
    const tab = btn.dataset.tab;
    const baseLabel = { map: 'Map Editor', resources: 'Resources', biomes: 'Biomes' }[tab];
    if (dirtyTracker.isDirty(tab)) {
      btn.textContent = baseLabel + ' *';
      btn.classList.add('tab-dirty');
    } else {
      btn.textContent = baseLabel;
      btn.classList.remove('tab-dirty');
    }
  });
}
```

#### CSS for dirty indicator

```css
.tab-dirty {
  position: relative;
}
.tab-dirty::after {
  content: '';
  position: absolute;
  top: 4px;
  right: 4px;
  width: 8px;
  height: 8px;
  background: #e8a020;
  border-radius: 50%;
}
```

The amber dot appears in the top-right corner of the tab button. Combined with the asterisk in the label text, this provides both a visual and textual unsaved changes indicator.

#### Save Integration

```js
async function saveAll() {
  const tabs = ['map', 'resources', 'biomes'];
  for (const tab of tabs) {
    if (dirtyTracker.isDirty(tab)) {
      try {
        await saveTab(tab);
        dirtyTracker.markClean(tab);
      } catch (err) {
        // Dirty flag NOT cleared on failure — matches edge case table.
        // Continue saving other tabs; don't abort on partial failure.
        showError(`Save failed for ${tab}: ${err.message}`);
      }
    }
  }
}

async function saveTab(tab) {
  if (tab === 'map') {
    // Serialize map data to JSON, write via FileDiscovery.saveFile()
    for (const [filename, entry] of ProjectContext.files.maps) {
      const json = JSON.stringify(entry.data, null, '\t');
      await FileDiscovery.saveFile(entry.handle, json, filename);
    }
  } else if (tab === 'resources') {
    for (const [filename, entry] of ProjectContext.files.resources) {
      const text = TresParser.serialize(entry.raw);
      await FileDiscovery.saveFile(entry.handle, text, filename);
    }
  } else if (tab === 'biomes') {
    for (const [filename, entry] of ProjectContext.files.biomes) {
      const text = TresParser.serialize(entry.raw);
      await FileDiscovery.saveFile(entry.handle, text, filename);
    }
  }
}
```

### Edge Cases

| Scenario | Behavior |
|---|---|
| Undo all changes back to last save point | Tab remains marked dirty (no save-point tracking). Saving clears it. |
| Save fails (e.g. permission denied) | Dirty flag is NOT cleared. Error shown to user. |
| New project loaded while dirty | No automatic save prompt (the `beforeunload` handler only fires on browser close/refresh). Loading a new project within the editor clears dirty state. If needed, a future enhancement could add an in-app "unsaved changes" confirmation dialog. |
| Multiple files in one tab modified | The entire tab is marked dirty, not individual files. Save writes all files for that tab. |
