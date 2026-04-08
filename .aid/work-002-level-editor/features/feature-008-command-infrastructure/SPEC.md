# Command Infrastructure

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | Extracted from feature-001 — undo/redo and keyboard shortcuts are cross-cutting foundation | Lola review |
| 2026-04-03 | Technical specification written | /aid-specify |
| 2026-04-03 | Review fixes: onChange signature, per-tab shortcut scoping, maxSize note, ProjectContext ref, selectTool(null) | /aid-specify review |
| 2026-04-04 | Unified props model: PlaceResource/RemoveResource/EditResourcePlacement/PlaceStructure/PlaceAnomaly commands replaced with AddPropCommand/EditPropCommand/DeletePropCommand. EraseHexContentCommand updated to clear props[]. | design change |

## Source

- REQUIREMENTS.md §5 F8 (Undo/Redo), F9 (Keyboard Shortcuts)

## Description

The command pattern infrastructure that underpins ALL editing operations across all three tabs. Every user action (paint hex, place resource, change biome color, edit .tres field, etc.) is wrapped in a Command object with execute/undo methods. This enables undo/redo with a 50+ step history stack. Also includes the keyboard shortcut system for tool switching (B for biome, E for elevation, R for resource, S for structure, etc.) and Ctrl+S for save.

**Why this is separate:** Undo/redo defines the data flow architecture. Every other feature's implementation depends on how commands are structured. Getting this wrong contaminates every feature. Getting it right makes everything else clean.

## User Stories

- As Andre, I want to undo/redo any editing operation across all tabs so that I can experiment without fear
- As Andre, I want keyboard shortcuts for fast tool switching so that editing flow is uninterrupted
- As Andre, I want Ctrl+S to save so that saving is muscle memory

## Priority

Must

## Acceptance Criteria

- [ ] Given 10 painting operations, when pressing Ctrl+Z 10 times, then all operations are undone in reverse order; pressing Ctrl+Shift+Z 5 times redoes 5
- [ ] Given a resource created in the Resource Editor, when pressing Ctrl+Z, then the resource is removed (undo works across tabs)
- [ ] Given a biome color changed in the Biome Editor, when pressing Ctrl+Z, then the color reverts and the map canvas updates
- [ ] Given more than 50 operations performed, when the 51st is executed, then the oldest command is dropped from history
- [ ] Given the keyboard shortcut B pressed, then the biome brush tool is activated
- [ ] Given Ctrl+S pressed, then all modified files are saved via File System Access API

---

## Technical Specification

### Data Model

#### `Command` interface

Every editing operation implements this interface as a plain JS object or class instance.

```js
// Command interface (duck-typed, not a formal JS interface)
{
  type: string,          // e.g. 'paint_biome', 'set_elevation', 'create_resource'
  description: string,   // human-readable, e.g. 'Paint hex (2,3) to Forest'
  tab: string,           // 'map' | 'resources' | 'biomes' — which tab this command affects
  execute(),             // Apply the change. Called on first execution and on redo.
  undo(),                // Reverse the change. Called on undo.
}
```

#### `CommandHistory`

Manages undo/redo stacks with a maximum of 50 entries.

```js
class CommandHistory {
  constructor() {
    this.undoStack = [];     // Array<Command>, most recent at end
    this.redoStack = [];     // Array<Command>, most recent at end
    this.maxSize = 50;       // satisfies "at least 50 steps" requirement — increase if needed
    this.onChange = null;     // callback: (action, command) => void
                             // action is 'execute' | 'undo' | 'redo'
  }

  // Execute a new command and push to undo stack.
  // Clears redo stack (new action invalidates redo history).
  // If undo stack exceeds maxSize, drop oldest entry.
  // Calls onChange('execute', command) after execution.
  execute(command)

  // Pop from undo stack, call command.undo(), push to redo stack.
  // Calls onChange('undo', command) after undo.
  // No-op if undo stack is empty.
  undo()

  // Pop from redo stack, call command.execute(), push to undo stack.
  // Calls onChange('redo', command) after redo.
  // No-op if redo stack is empty.
  redo()

  // Returns true if undo stack is non-empty.
  canUndo()

  // Returns true if redo stack is non-empty.
  canRedo()

  // Clears both stacks. Called on project load/new map.
  clear()
}
```

The `onChange` callback is the integration point for `DirtyTracker` (feature 009) and UI updates (enabling/disabling undo/redo buttons).

#### Concrete Command Types

**Map Editor commands:**

| Command Class | `type` | Before State Captured | `execute()` | `undo()` |
|---|---|---|---|---|
| `PaintBiomeCommand` | `paint_biome` | `{ coords, oldBiome }` for each hex | Set biome on each hex | Restore old biome on each hex |
| `SetElevationCommand` | `set_elevation` | `{ coords, oldElevation }` for each hex | Set elevation on each hex | Restore old elevation |
| `AddPropCommand` | `add_prop` | n/a (new prop) | Push prop to tile.props | Remove prop from tile.props by index |
| `EditPropCommand` | `edit_prop` | `{ coords, propIndex, oldValues }` | Object.assign new values to prop | Restore old values |
| `DeletePropCommand` | `delete_prop` | `{ coords, propIndex, removedProp }` | Splice prop from tile.props | Re-insert prop at index |
| `SetSpawnCommand` | `set_spawn` | `{ oldSpawn: [q, r] or null }` | Set spawn to new coords | Restore old spawn |
| `EraseContentCommand` | `erase_content` | `{ coords, oldProps }` | Clear tile.props to [] | Restore props from snapshot |
| `DeleteHexCommand` | `delete_hex` | full tile data snapshot | Remove tile from map | Re-add tile with snapshot |
| `FloodFillCommand` | `flood_fill` | `{ affectedHexes: [{ coords, oldBiome }] }` | Set biome on all affected hexes | Restore old biome on each |

**Drag-painting batch handling:** When the user clicks and drags to paint biomes or elevations, individual per-hex changes during the drag are NOT separate commands. Instead, a single batch command is created on mouse-up that captures all hexes modified during the drag. This ensures Ctrl+Z undoes the entire drag stroke, not one hex at a time.

```js
// During drag:
let pendingBatch = { type: 'paint_biome', hexes: [] };
// On each new hex touched during drag:
pendingBatch.hexes.push({ coords, oldBiome, newBiome });
// On mouseup:
CommandHistory.execute(new PaintBiomeCommand(pendingBatch.hexes));
```

**Resource Editor commands (tab: 'resources'):**

| Command Class | `type` | Before State | `execute()` | `undo()` |
|---|---|---|---|---|
| `CreatePropDefCommand` | `create_resource` | n/a | Add new PropDef to `ProjectContext.files.resources` | Remove it |
| `EditPropDefCommand` | `edit_resource` | `{ filename, oldFields }` | Update fields in PropDef | Restore old fields |
| `DeletePropDefCommand` | `delete_resource` | `{ filename, fullData, raw }` | Remove from ProjectContext | Re-add with full data |

**Biome Editor commands (tab: 'biomes'):**

| Command Class | `type` | Before State | `execute()` | `undo()` |
|---|---|---|---|---|
| `CreateBiomeCommand` | `create_biome` | n/a | Add new BiomeData to `ProjectContext.files.biomes` | Remove it |
| `EditBiomeCommand` | `edit_biome` | `{ filename, oldFields }` | Update fields in BiomeData | Restore old fields |
| `DeleteBiomeCommand` | `delete_biome` | `{ filename, fullData, raw }` | Remove from ProjectContext | Re-add with full data |

`ProjectContext` is the global singleton defined in feature-007 (File Discovery). All `.files.*` maps are populated during project discovery.

### Feature Flow

1. **Command Execution** — Every user action that modifies data goes through `CommandHistory.execute(command)`:
   - The command's `execute()` method mutates the in-memory model (`ProjectContext.files.*` data and the canvas tile data).
   - The command is pushed onto the undo stack.
   - The redo stack is cleared.
   - `onChange` callback fires with `('execute', command)`.
   - The UI re-renders affected areas (canvas repaint, list update, etc.).

2. **Undo (Ctrl+Z)** — `CommandHistory.undo()`:
   - Pop from undo stack.
   - Call `command.undo()` which restores the captured before-state.
   - Push to redo stack.
   - `onChange` fires with `('undo', command)`.
   - UI re-renders.

3. **Redo (Ctrl+Shift+Z)** — `CommandHistory.redo()`:
   - Pop from redo stack.
   - Call `command.execute()` which re-applies the change.
   - Push to undo stack.
   - `onChange` fires with `('redo', command)`.
   - UI re-renders.

4. **Stack Overflow** — When undo stack exceeds 50 entries, `undoStack.shift()` drops the oldest command.

5. **History Reset** — On project load or new map creation, `CommandHistory.clear()` empties both stacks.

### Layers & Components

#### `CommandHistory` (singleton)

Single global instance. All tabs share one history, enabling cross-tab undo. The `tab` field on each command enables `DirtyTracker` to know which tab was affected.

```js
const commandHistory = new CommandHistory();
```

#### `KeyboardManager`

Registers global keyboard shortcuts via a single `document.addEventListener('keydown', ...)` handler. Dispatches based on key combinations.

```js
class KeyboardManager {
  constructor() {
    this.shortcuts = new Map();  // key combo string -> handler function
    this.enabled = true;         // disabled when text inputs are focused
  }

  // Register a shortcut. combo format: 'ctrl+z', 'shift+ctrl+z', 'b', 'escape'
  register(combo, handler)

  // Unregister a shortcut.
  unregister(combo)

  // Internal: normalize KeyboardEvent to combo string.
  // Modifier order: ctrl+shift+alt+key (lowercase).
  _normalizeEvent(event)

  // Internal: keydown handler.
  // Skips dispatch when activeElement is <input>, <textarea>, or [contenteditable].
  _handleKeydown(event)
}
```

#### Initialization

```js
const keyboardManager = new KeyboardManager();

// Tool shortcuts — scoped to Map Editor tab via guard check.
// Each handler returns early if activeTab !== 'map', avoiding the need to
// register/unregister shortcuts on tab switch. `activeTab` is a module-level
// variable updated by the tab switching logic (feature-007 app shell).
const mapOnly = (fn) => () => { if (activeTab !== 'map') return; fn(); };
keyboardManager.register('b', mapOnly(() => selectTool('biome')));
keyboardManager.register('e', mapOnly(() => selectTool('elevation')));
keyboardManager.register('r', mapOnly(() => selectTool('resource')));
keyboardManager.register('s', mapOnly(() => selectTool('structure')));
keyboardManager.register('a', mapOnly(() => selectTool('anomaly')));
keyboardManager.register('p', mapOnly(() => selectTool('spawn')));
keyboardManager.register('x', mapOnly(() => selectTool('eraser')));
keyboardManager.register('d', mapOnly(() => selectTool('delete_hex')));
keyboardManager.register('f', mapOnly(() => selectTool('flood_fill')));
keyboardManager.register('escape', mapOnly(() => selectTool(null)));

// Global shortcuts (always active)
keyboardManager.register('ctrl+z', () => commandHistory.undo());
keyboardManager.register('ctrl+shift+z', () => commandHistory.redo());
keyboardManager.register('ctrl+s', () => saveAll());
```

### Keyboard Shortcut Reference

| Key | Action | Scope |
|---|---|---|
| B | Biome brush tool | Map Editor tab |
| E | Elevation brush tool | Map Editor tab |
| R | Resource placer tool | Map Editor tab |
| S | Structure placer tool | Map Editor tab |
| A | Anomaly marker tool | Map Editor tab |
| P | Spawn marker tool | Map Editor tab |
| X | Eraser tool | Map Editor tab |
| D | Delete hex tool | Map Editor tab |
| F | Flood fill tool | Map Editor tab |
| Escape | Deselect current tool (`selectTool(null)` — sets `toolManager.activeTool` to null, clears selection highlight in sidebar) | Map Editor tab |
| Ctrl+Z | Undo | Global |
| Ctrl+Shift+Z | Redo | Global |
| Ctrl+S | Save all modified files | Global |

### Input Suppression

When a text `<input>`, `<textarea>`, or `[contenteditable]` element is focused, all single-key shortcuts (B, E, R, etc.) are suppressed so the user can type normally. Modifier shortcuts (Ctrl+Z, Ctrl+S, etc.) remain active since they do not conflict with text editing.

### Cross-Tab Undo Behavior

Because all tabs share one `CommandHistory`, the following scenario works correctly:
1. User paints hexes on the Map Editor tab (commands with `tab: 'map'`).
2. User switches to Resource Editor, creates a new resource (command with `tab: 'resources'`).
3. User presses Ctrl+Z — the resource creation is undone (most recent command).
4. User presses Ctrl+Z again — the last map paint is undone.

The `tab` field is used by `DirtyTracker` (feature 009) to mark the correct tab dirty, not to filter the undo stack.
