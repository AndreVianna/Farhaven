# ES Module Refactor — Level Editor

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the 3817-line monolithic `index.html` into ES modules with zero behavior change.

**Architecture:** Extract all JavaScript from the `<script>` block into separate `.js` files under `js/`. Each file exports its classes/functions. `app.js` is the bootstrap that imports everything and wires the DOM. `index.html` retains all HTML and CSS, replacing the `<script>` block with `<script type="module" src="js/app.js"></script>`. Tests import directly from modules instead of eval-ing HTML.

**Tech Stack:** Vanilla JS ES modules (native browser `import`/`export`), no bundler.

---

## Dependency Graph (no cycles)

```
hex-math.js          (no deps)
tres-parser.js       (no deps)
commands.js          (no deps — uses hex-math types but not imports)
keyboard.js          (no deps)
dirty-tracker.js     (no deps)

hex-grid.js          → hex-math.js
file-discovery.js    → tres-parser.js
tools.js             → hex-math.js, commands.js
canvas.js            → hex-math.js, hex-grid.js
panels.js            → commands.js

app.js               → all of the above (bootstrap)
```

## File Map

| New File | Exports | Source Lines (approx) |
|----------|---------|----------------------|
| `js/hex-math.js` | `HEX_SIZE`, `HexMath` | ~130 lines |
| `js/hex-grid.js` | `HexGrid`, `createTileData`, `createResourceInstance`, `loadMapIntoGrid`, `serializeGridToMapJson` | ~185 lines |
| `js/tres-parser.js` | `TresFile`, `TresParser`, `generateTresUid` | ~545 lines |
| `js/file-discovery.js` | `ProjectContext`, `FileDiscovery` | ~355 lines |
| `js/commands.js` | `CommandHistory`, `BatchCommand`, all `*Command` classes | ~260 lines |
| `js/keyboard.js` | `KeyboardManager` | ~80 lines |
| `js/tools.js` | `ToolType`, `ElevationMode`, `BaseTool`, `DragBrushTool`, all tool classes, `ToolManager` | ~320 lines |
| `js/canvas.js` | `HexCanvas`, `BIOME_FALLBACK_COLOR` | ~700 lines |
| `js/panels.js` | `ResourceDetailPanel`, `showInlineModal` | ~140 lines |
| `js/dirty-tracker.js` | `DirtyTracker` | ~100 lines |
| `js/app.js` | (no exports — bootstrap) | ~200 lines |

---

### Task 1: Create `js/hex-math.js`

**Files:**
- Create: `tools/level-editor/js/hex-math.js`
- Source: `index.html:1431-1561` (HexMath Module section)

- [ ] **Step 1: Create the module file**

Extract the `HEX_SIZE` constant and `HexMath` object. Add `export` keywords.

```js
// ============================================================
// HexMath Module (task-007)
// ============================================================

export const HEX_SIZE = 40;

export const HexMath = {
  DIRECTIONS: [
    { q: 1, r: 0 },
    { q: 1, r: -1 },
    { q: 0, r: -1 },
    { q: -1, r: 0 },
    { q: -1, r: 1 },
    { q: 0, r: 1 },
  ],

  // ... copy all methods exactly from index.html lines 1439-1561
  // axialToPixel, pixelToAxial, cubeRound, getNeighbors, distance, hexCorners, getEdgeIndex
};
```

Copy the entire HexMath section verbatim, adding `export` before `const HEX_SIZE` and `const HexMath`.

- [ ] **Step 2: Verify no DOM or global dependencies**

Scan the extracted code for references to `document`, `window`, `camera`, `hexGrid`, or any other global. HexMath should be pure math — confirm zero external references.

---

### Task 2: Create `js/hex-grid.js`

**Files:**
- Create: `tools/level-editor/js/hex-grid.js`
- Source: `index.html:1563-1748` (HexGrid Model section)

- [ ] **Step 1: Create the module file**

```js
// ============================================================
// HexGrid Model (task-007)
// ============================================================

import { HexMath } from './hex-math.js';

// ... copy createTileData, createResourceInstance, HexGrid class,
//     loadMapIntoGrid, serializeGridToMapJson from index.html

export { HexGrid, createTileData, createResourceInstance, loadMapIntoGrid, serializeGridToMapJson };
```

Copy the entire HexGrid section. Add `import { HexMath } from './hex-math.js'` if HexMath is referenced (check — `loadMapIntoGrid` and `serializeGridToMapJson` may not need it, but verify). Export all public symbols.

- [ ] **Step 2: Verify dependencies**

The only import should be `hex-math.js` (if needed). No DOM references.

---

### Task 3: Create `js/tres-parser.js`

**Files:**
- Create: `tools/level-editor/js/tres-parser.js`
- Source: `index.html:320-864` (TresParser section)

- [ ] **Step 1: Create the module file**

```js
// ============================================================
// TresParser — Parse and Serialize .tres files (task-003)
// ============================================================

// ... copy TresFile class, generateTresUid, TresParser object

export { TresFile, TresParser, generateTresUid };
```

This is self-contained — no imports needed. Copy verbatim, add exports.

---

### Task 4: Create `js/file-discovery.js`

**Files:**
- Create: `tools/level-editor/js/file-discovery.js`
- Source: `index.html:865-1236` (ProjectContext + FileDiscovery sections)

- [ ] **Step 1: Create the module file**

```js
// ============================================================
// ProjectContext (task-002)
// ============================================================

import { TresParser } from './tres-parser.js';

export const ProjectContext = {
  // ... copy ProjectContext object
};

// ============================================================
// FileDiscovery (task-002)
// ============================================================

export class FileDiscovery {
  // ... copy all static methods
}
```

FileDiscovery references `TresParser` and `ProjectContext`. Import TresParser, keep ProjectContext in same file (they're tightly coupled).

---

### Task 5: Create `js/commands.js`

**Files:**
- Create: `tools/level-editor/js/commands.js`
- Source: `index.html:1237-1346` (CommandHistory) + `index.html:2546-2896` (Command Classes + BatchCommand)

- [ ] **Step 1: Create the module file**

```js
// ============================================================
// CommandHistory (task-004)
// ============================================================

export class CommandHistory {
  // ... copy from index.html
}

// ============================================================
// Command Classes (task-009 + task-010)
// ============================================================

export class BatchCommand {
  // ... copy
}

export class SetBiomeCommand {
  // ... copy — references createTileData, but we'll pass grid methods, not import
}

// ... all other command classes
```

Command classes reference `createTileData` (from hex-grid.js) in `SetBiomeCommand.execute()` and `SetElevationCommand.execute()`. Import it:

```js
import { createTileData } from './hex-grid.js';
```

Export all classes: `CommandHistory`, `BatchCommand`, `SetBiomeCommand`, `SetElevationCommand`, `AddResourceCommand`, `EditResourceCommand`, `DeleteResourceCommand`, `SetStructureCommand`, `SetAnomalyCommand`, `SetSpawnCommand`, `EraseContentCommand`, `DeleteHexCommand`.

---

### Task 6: Create `js/keyboard.js`

**Files:**
- Create: `tools/level-editor/js/keyboard.js`
- Source: `index.html:1347-1430` (KeyboardManager section)

- [ ] **Step 1: Create the module file**

```js
// ============================================================
// KeyboardManager (task-004)
// ============================================================

export class KeyboardManager {
  // ... copy from index.html
}
```

KeyboardManager references `document` for `addEventListener` and `activeElement`. It receives `document` in constructor or uses the global — check. If it uses global `document`, that's fine for browser modules.

---

### Task 7: Create `js/tools.js`

**Files:**
- Create: `tools/level-editor/js/tools.js`
- Source: `index.html:2522-2545` (ToolType/ElevationMode enums) + `index.html:2897-3248` (Tool Classes + ToolManager)

- [ ] **Step 1: Create the module file**

```js
// ============================================================
// Tool Types and Enums (task-009)
// ============================================================

import { HexMath } from './hex-math.js';
import {
  SetBiomeCommand, SetElevationCommand, BatchCommand,
  EraseContentCommand, DeleteHexCommand,
  AddResourceCommand, SetStructureCommand, SetAnomalyCommand, SetSpawnCommand,
  createResourceInstance
} from './commands.js';

export const ToolType = { ... };
export const ElevationMode = { ... };

// ... BaseTool, DragBrushTool, BiomeBrush, ElevationBrush, FloodFillTool, EraserTool
// ... ResourcePlacer, StructurePlacer, AnomalyMarker, SpawnMarker, DeleteHexTool
// ... ToolManager

export { BaseTool, DragBrushTool, BiomeBrush, ElevationBrush, FloodFillTool, EraserTool };
export { ResourcePlacer, StructurePlacer, AnomalyMarker, SpawnMarker, DeleteHexTool };
export { ToolManager };
```

**Dependencies:**
- `hex-math.js` — FloodFillTool uses `HexMath.getNeighbors`
- `commands.js` — all tools create command objects
- Tools reference `createTileData` and `createResourceInstance` — these need to be imported. `createTileData` is in `hex-grid.js`, `createResourceInstance` is in `hex-grid.js`.
- `showInlineModal` is used by AnomalyMarker — import from `panels.js`. **Circular risk:** panels.js imports commands.js, tools.js imports panels.js. To avoid this, `showInlineModal` should be in its own file or passed as a dependency. **Solution:** keep `showInlineModal` in `panels.js` but import it in `tools.js` — panels.js only imports from commands.js, tools.js imports from panels.js, no cycle.
- `setStatus` is used by FloodFillTool — this is a DOM helper. Pass it as a callback or import from app.js. **Solution:** FloodFillTool calls `setStatus()` — move `setStatus` to a tiny `js/ui-helpers.js` or have tools.js import from app.js. Since app.js imports tools.js, that's circular. **Better:** extract `setStatus` into tools.js or pass it at construction. **Simplest:** remove the `setStatus` call from FloodFillTool (it was added for the safety limit warning) — use `console.warn` only, or pass a callback. Let's use a callback pattern: ToolManager gets a `statusCallback` that app.js sets.

- [ ] **Step 2: Handle the `setStatus` dependency**

In ToolManager constructor, add an optional `onStatus` callback:

```js
class ToolManager {
  constructor(grid, cmdHistory) {
    // ... existing
    this.onStatus = null; // set by app.js
  }
}
```

In FloodFillTool, replace `setStatus(...)` with:
```js
if (this.toolManager.onStatus) {
  this.toolManager.onStatus(`Warning: flood fill stopped at ${SAFETY_LIMIT} tile limit.`);
}
```

---

### Task 8: Create `js/canvas.js`

**Files:**
- Create: `tools/level-editor/js/canvas.js`
- Source: `index.html:1749-2521` (HexCanvas section)

- [ ] **Step 1: Create the module file**

```js
// ============================================================
// HexCanvas — Rendering and Interaction (task-008)
// ============================================================

import { HEX_SIZE, HexMath } from './hex-math.js';

export const BIOME_FALLBACK_COLOR = '#888888';

export class HexCanvas {
  // ... copy entire class from index.html
}
```

**Dependencies:**
- `hex-math.js` — `HEX_SIZE`, `HexMath` (axialToPixel, hexCorners, getNeighbors, pixelToAxial)
- References global `camera` and `biomeColorMap` — these are module-level state. **Solution:** `camera` and `biomeColorMap` are created in `app.js` and passed to HexCanvas via constructor or property. Currently HexCanvas reads the global `camera` object. Refactor: pass `camera` and `biomeColorMap` as constructor params.

```js
constructor(canvasElement, grid, camera, biomeColorMap) {
  this.canvas = canvasElement;
  this.ctx = canvasElement && typeof canvasElement.getContext === 'function'
    ? canvasElement.getContext('2d') : null;
  this.grid = grid;
  this.camera = camera;
  this.biomeColorMap = biomeColorMap;
  // ... rest
}
```

Replace all references to the bare `camera` global with `this.camera` and `biomeColorMap` with `this.biomeColorMap` inside the class.

---

### Task 9: Create `js/panels.js`

**Files:**
- Create: `tools/level-editor/js/panels.js`
- Source: `index.html:3253-3461` (Inline Modal + ResourceDetailPanel)

- [ ] **Step 1: Create the module file**

```js
// ============================================================
// Inline Modal Dialog (task-010)
// ============================================================

export function showInlineModal(label, defaultValue, callback) {
  // ... copy from index.html
}

// ============================================================
// ResourceDetailPanel (task-010)
// ============================================================

import { EditResourceCommand, DeleteResourceCommand } from './commands.js';

export class ResourceDetailPanel {
  // ... copy from index.html
}
```

ResourceDetailPanel creates `EditResourceCommand` and `DeleteResourceCommand` — import from commands.js.

---

### Task 10: Create `js/dirty-tracker.js`

**Files:**
- Create: `tools/level-editor/js/dirty-tracker.js`
- Source: `index.html:3505-3610` (DirtyTracker section)

- [ ] **Step 1: Create the module file**

```js
// ============================================================
// DirtyTracker (task-005)
// ============================================================

export class DirtyTracker {
  // ... copy from index.html
}
```

Self-contained — no imports needed. References `document.getElementById` for tab label updates — that's fine in browser modules.

---

### Task 11: Create `js/app.js` — Bootstrap

**Files:**
- Create: `tools/level-editor/js/app.js`
- Source: remaining glue code from index.html (tab switching, global state, keyboard wiring, save functions, auto-load, canvas init)

- [ ] **Step 1: Create the bootstrap module**

```js
'use strict';

// ============================================================
// Imports
// ============================================================

import { HEX_SIZE, HexMath } from './hex-math.js';
import { HexGrid, createTileData, createResourceInstance, loadMapIntoGrid, serializeGridToMapJson } from './hex-grid.js';
import { TresFile, TresParser, generateTresUid } from './tres-parser.js';
import { ProjectContext, FileDiscovery } from './file-discovery.js';
import { CommandHistory, BatchCommand } from './commands.js';
import { KeyboardManager } from './keyboard.js';
import { ToolType, ElevationMode, ToolManager } from './tools.js';
import { HexCanvas, BIOME_FALLBACK_COLOR } from './canvas.js';
import { ResourceDetailPanel, showInlineModal } from './panels.js';
import { DirtyTracker } from './dirty-tracker.js';

// ============================================================
// Module-level state
// ============================================================

let activeTab = 'map';
const camera = { offsetX: 0, offsetY: 0, zoom: 1.0 };
const biomeColorMap = new Map();
const hexGrid = new HexGrid();
const commandHistory = new CommandHistory();
const keyboardManager = new KeyboardManager();
const toolManager = new ToolManager(hexGrid, commandHistory);
const dirtyTracker = new DirtyTracker();
let hexCanvas = null;
let resourceDetailPanel = null;

// ============================================================
// Tab Switching (task-001)
// ============================================================
// ... copy tab switching code

// ============================================================
// selectTool wiring
// ============================================================
// ... copy selectTool function, keyboard registrations

// ============================================================
// Save Functions (task-005)
// ============================================================
// ... copy saveAll, saveTab

// ============================================================
// UI Helpers
// ============================================================
// ... copy setStatus, showError

// ============================================================
// Auto-load Project
// ============================================================
// ... copy autoLoadProject, initializeAfterLoad

// ============================================================
// beforeunload protection
// ============================================================
// ... copy beforeunload listener

// ============================================================
// Canvas Initialization (task-008)
// ============================================================
// ... copy canvas init block, pass camera and biomeColorMap to HexCanvas constructor

// Wire ToolManager status callback
toolManager.onStatus = (msg) => setStatus(msg);

// Wire CommandHistory onChange for dirty tracking
commandHistory.onChange = (action, command) => {
  if (command && command.tab) {
    dirtyTracker.markDirty(command.tab);
  }
};
```

The key change: `HexCanvas` constructor now receives `camera` and `biomeColorMap`:
```js
hexCanvas = new HexCanvas(canvasEl, hexGrid, camera, biomeColorMap);
```

- [ ] **Step 2: Verify all globals are accounted for**

Check that every symbol previously accessed as a global is now either imported or defined in app.js. Key globals to track:
- `activeTab`, `camera`, `biomeColorMap`, `hexGrid`, `commandHistory`, `keyboardManager`, `toolManager`, `dirtyTracker`, `hexCanvas`, `resourceDetailPanel` — all in app.js
- `HEX_SIZE`, `HexMath` — imported
- `setStatus` — defined in app.js (and passed to ToolManager as callback)

---

### Task 12: Update `index.html` — Replace script block

**Files:**
- Modify: `tools/level-editor/index.html`

- [ ] **Step 1: Replace the `<script>` block**

Remove everything between `<script>` and `</script>` (lines 264-3815). Replace with:

```html
<script type="module" src="js/app.js"></script>
```

Keep all HTML and CSS exactly as-is.

- [ ] **Step 2: Verify in browser**

Open `http://localhost:8080` (restart server if needed). The editor should load and work exactly as before. Check:
- Map loads with biome colors
- Ghost grid visible
- Hover tooltips work
- Pan/zoom works
- Keyboard shortcuts (B, E, R, S, etc.)
- Ctrl+Z undo
- Save button

---

### Task 13: Update test files

**Files:**
- Modify: `tools/level-editor/test-unit.mjs`
- Modify: `tools/level-editor/test-roundtrip.mjs`

- [ ] **Step 1: Update `test-unit.mjs`**

Replace the HTML-parsing eval approach with direct imports:

```js
/**
 * Unit tests for level editor modules.
 * Run: node tools/level-editor/test-unit.mjs
 */

// Minimal DOM mocks for modules that reference document/window
globalThis.document = {
  querySelectorAll: () => [],
  getElementById: () => ({
    addEventListener: () => {},
    classList: { add: () => {}, remove: () => {} },
    textContent: '',
    style: {},
  }),
  activeElement: null,
  addEventListener: () => {},
  createElement: () => ({ click: () => {}, href: '', download: '', style: {}, appendChild: () => {}, remove: () => {} }),
  body: { appendChild: () => {}, removeChild: () => {} },
};
globalThis.window = { addEventListener: () => {} };
globalThis.requestAnimationFrame = (cb) => setTimeout(cb, 0);

import { HEX_SIZE, HexMath } from './js/hex-math.js';
import { HexGrid, createTileData, createResourceInstance, loadMapIntoGrid, serializeGridToMapJson } from './js/hex-grid.js';
import { TresFile, TresParser, generateTresUid } from './js/tres-parser.js';
import { ProjectContext, FileDiscovery } from './js/file-discovery.js';
import { CommandHistory, BatchCommand, SetBiomeCommand, SetElevationCommand, /* ... all commands */ } from './js/commands.js';
import { KeyboardManager } from './js/keyboard.js';
import { ToolType, ElevationMode, ToolManager, BiomeBrush, ElevationBrush, FloodFillTool, EraserTool, ResourcePlacer, StructurePlacer, SpawnMarker, DeleteHexTool } from './js/tools.js';
import { DirtyTracker } from './js/dirty-tracker.js';

// ... rest of test code (test/assert functions, all test cases) stays the same
// just remove the HTML-extraction and eval block
```

- [ ] **Step 2: Update `test-roundtrip.mjs`**

```js
/**
 * Round-trip test for TresParser.
 * Run: node tools/level-editor/test-roundtrip.mjs
 */
import { readFileSync, readdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

// Minimal DOM mocks
globalThis.document = { getElementById: () => null, addEventListener: () => {}, querySelectorAll: () => [] };
globalThis.window = { addEventListener: () => {} };

import { TresParser } from './js/tres-parser.js';

// ... rest stays the same, just remove the HTML extraction
```

- [ ] **Step 3: Run tests**

```bash
node tools/level-editor/test-unit.mjs
node tools/level-editor/test-roundtrip.mjs
```

Expected: all tests pass with same counts as before.

---

### Task 14: Commit

- [ ] **Step 1: Verify everything works**

1. Restart server: `.\tools\serve.ps1`
2. Open `http://localhost:8080` — full editor functionality
3. Run `node tools/level-editor/test-unit.mjs` — all pass
4. Run `node tools/level-editor/test-roundtrip.mjs` — all pass

- [ ] **Step 2: Commit**

```bash
git add tools/level-editor/js/ tools/level-editor/index.html tools/level-editor/test-unit.mjs tools/level-editor/test-roundtrip.mjs
git commit -m "refactor: split editor into ES modules — zero behavior change"
```
