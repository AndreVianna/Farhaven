'use strict';

// ============================================================
// App Bootstrap — imports all modules, wires DOM events
// ============================================================

import { TresParser } from './tres-parser.js';
import { HexGrid, loadMapIntoGrid, serializeGridToMapJson } from './hex-grid.js';
import { CommandHistory } from './commands.js';
import { ProjectContext, FileDiscovery } from './file-discovery.js';
import { HexCanvas } from './canvas.js';
import { HexInspector, showInlineModal } from './panels.js';
import { KeyboardManager } from './keyboard.js';
import { DirtyTracker } from './dirty-tracker.js';
import { ToolManager, STRUCTURE_FOOTPRINTS } from './tools.js';
import { validateMap } from './validator.js';
import { renderResourceList } from './resource-editor.js';
import { renderBiomeList } from './biome-editor.js';

// ============================================================
// Module-level state
// ============================================================

/** @type {string} Currently active tab — 'map' | 'resources' | 'biomes' */
let activeTab = 'map';

/** @type {HexGrid} Global hex grid model instance */
const hexGrid = new HexGrid();

/**
 * Camera state for pan and zoom.
 * @type {{ offsetX: number, offsetY: number, zoom: number }}
 */
const camera = { offsetX: 0, offsetY: 0, zoom: 1.0 };

/** @type {Map<string, string>} Biome name -> CSS color string, populated from .tres data */
const biomeColorMap = new Map();

/** @type {CommandHistory} */
const commandHistory = new CommandHistory();

/** @type {KeyboardManager} */
const keyboardManager = new KeyboardManager();

/** @type {ToolManager} */
const toolManager = new ToolManager(hexGrid, commandHistory);

/** @type {DirtyTracker} */
const dirtyTracker = new DirtyTracker();

/** @type {HexCanvas|null} */
let hexCanvas = null;

/** @type {HexInspector|null} */
let hexInspector = null;

// ============================================================
// Tab Switching (task-001)
// ============================================================

/** @type {Object<string, string>} Base labels for each tab */
const TAB_LABELS = {
  map: 'Map Editor',
  resources: 'Resources',
  biomes: 'Biomes',
};

/**
 * Switch to the specified tab.
 * @param {string} tabName - 'map' | 'resources' | 'biomes'
 * @returns {void}
 */
function switchTab(tabName) {
  if (!TAB_LABELS[tabName]) return;
  activeTab = tabName;

  // Update tab buttons
  document.querySelectorAll('.tab-btn').forEach(btn => {
    if (btn.dataset.tab === tabName) {
      btn.classList.add('active');
    } else {
      btn.classList.remove('active');
    }
  });

  // Update tab panels
  document.querySelectorAll('.tab-panel').forEach(panel => {
    if (panel.id === 'tab-' + tabName) {
      panel.classList.add('active');
    } else {
      panel.classList.remove('active');
    }
  });
}

// Wire tab click handlers
document.querySelectorAll('.tab-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    switchTab(btn.dataset.tab);
  });
});

// ============================================================
// UI Helpers
// ============================================================

/**
 * Show an error message in the status bar.
 * @param {string} message
 * @returns {void}
 */
function showError(message) {
  setStatus('Error: ' + message);
}

/**
 * Update the status bar text.
 * @param {string} text
 * @returns {void}
 */
function setStatus(text) {
  const el = document.getElementById('status-text');
  if (el) el.textContent = text;
}

// ============================================================
// Wire ToolManager onStatus callback
// ============================================================

toolManager.onStatus = (msg) => setStatus(msg);

// ============================================================
// selectTool — wires keyboard shortcuts to ToolManager (task-009)
// ============================================================

/**
 * Set the active tool via keyboard shortcut or UI.
 * @param {string|null} toolName
 * @returns {void}
 */
function selectTool(toolName) {
  // Preserve activeValue only if staying on the same tool type
  const value = (toolName === toolManager.activeToolType) ? toolManager.activeValue : null;
  toolManager.setTool(toolName, value);
  if (hexCanvas) {
    hexCanvas.toolManager = toolManager;
  }
  // Update tool indicator in toolbar
  const indicator = document.getElementById('tool-indicator');
  if (indicator) {
    indicator.textContent = toolName ? `Tool: ${toolName}` : '';
  }
  setStatus(toolName ? `Tool: ${toolName}` : 'No tool selected');
  updateSidebar();
}

// Map-only shortcut guard
/** @param {function():void} fn */
const mapOnly = (fn) => () => { if (activeTab !== 'map') return; fn(); };

// Register tool shortcuts (map-only)
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

// Global shortcuts
keyboardManager.register('ctrl+z', () => commandHistory.undo());
keyboardManager.register('ctrl+shift+z', () => commandHistory.redo());
keyboardManager.register('ctrl+s', () => saveAll());
keyboardManager.register('ctrl+n', () => newMap());

// ============================================================
// Wire DirtyTracker to CommandHistory
// ============================================================

commandHistory.onChange = (action, command) => {
  if (command && command.tab) {
    dirtyTracker.markDirty(command.tab);
  }
  updateUndoRedoButtons();
};

// Wire DirtyTracker to UI
dirtyTracker.onChange = () => {
  updateTabIndicators();
};

/**
 * Update tab button labels and dirty indicators.
 * @returns {void}
 */
function updateTabIndicators() {
  document.querySelectorAll('.tab-btn').forEach(btn => {
    const tab = btn.dataset.tab;
    const baseLabel = TAB_LABELS[tab];
    if (!baseLabel) return;
    if (dirtyTracker.isDirty(tab)) {
      btn.textContent = baseLabel + ' *';
      btn.classList.add('tab-dirty');
    } else {
      btn.textContent = baseLabel;
      btn.classList.remove('tab-dirty');
    }
  });
}

/**
 * Update undo/redo button states (placeholder for future toolbar buttons).
 * @returns {void}
 */
function updateUndoRedoButtons() {
  // Future: enable/disable undo/redo toolbar buttons
}

// ============================================================
// New Map (G3)
// ============================================================

/**
 * Clear the grid and start a new map, prompting for chapter ID and map name.
 * @returns {void}
 */
function newMap() {
  if (dirtyTracker.hasUnsavedChanges()) {
    if (!confirm('Unsaved changes will be lost. Continue?')) return;
  }
  showInlineModal('Chapter ID:', 'ch1', (chapterId) => {
    if (chapterId === null) return;
    showInlineModal('Map Name:', 'New Map', (mapName) => {
      if (mapName === null) return;
      hexGrid.clear();
      hexGrid.meta = { chapter_id: chapterId.trim() || 'ch1', name: mapName.trim() || 'New Map', spawn: [0, 0] };
      commandHistory.clear();
      dirtyTracker.markAllClean();
      if (hexCanvas) hexCanvas.requestRender();
      setStatus(`New map "${hexGrid.meta.name}" created.`);
    });
  });
}

// ============================================================
// Save Functions (task-005)
// ============================================================

/**
 * Save all dirty tabs.
 * @returns {Promise<void>}
 */
async function saveAll() {
  // Validate map before saving
  const knownBiomes = new Set([...ProjectContext.files.biomes.keys()].map(f => f.replace('.tres', '')));
  const knownResources = new Set([...ProjectContext.files.resources.keys()].map(f => f.replace('.tres', '')));
  const validation = validateMap(hexGrid, knownBiomes, knownResources);
  if (!validation.valid) {
    const firstError = validation.errors[0];
    const prefix = firstError.hex.length > 0 ? `Tile (${firstError.hex.join(',')}): ` : '';
    showError(`Validation: ${prefix}${firstError.message}`);
    return;
  }

  const tabs = ['map', 'resources', 'biomes'];
  let hadError = false;
  for (const tab of tabs) {
    if (dirtyTracker.isDirty(tab)) {
      try {
        await saveTab(tab);
        dirtyTracker.markClean(tab);
      } catch (err) {
        hadError = true;
        showError(`Save failed for ${tab}: ${err.message}`);
      }
    }
  }
  if (!hadError) {
    setStatus('All changes saved.');
  }
}

/**
 * Save files for a specific tab.
 * @param {string} tab - 'map' | 'resources' | 'biomes'
 * @returns {Promise<void>}
 */
async function saveTab(tab) {
  if (tab === 'map') {
    // Serialize from the live HexGrid model
    const mapData = serializeGridToMapJson(hexGrid);
    for (const [filename, entry] of ProjectContext.files.maps) {
      entry.data = mapData;
      const json = JSON.stringify(entry.data, null, '\t');
      await FileDiscovery.saveFile(entry.dir || 'data/maps', json, filename);
    }
  } else if (tab === 'resources') {
    for (const [filename, entry] of ProjectContext.files.resources) {
      const text = TresParser.serialize(entry.raw);
      await FileDiscovery.saveFile(entry.dir || 'data/resources', text, filename);
    }
  } else if (tab === 'biomes') {
    for (const [filename, entry] of ProjectContext.files.biomes) {
      const text = TresParser.serialize(entry.raw);
      await FileDiscovery.saveFile(entry.dir || 'data/biomes', text, filename);
    }
  }
}

// Wire Save button
document.getElementById('btn-save').addEventListener('click', () => saveAll());

// ============================================================
// beforeunload protection (task-005)
// ============================================================

window.addEventListener('beforeunload', (event) => {
  if (dirtyTracker.hasUnsavedChanges()) {
    event.preventDefault();
    event.returnValue = '';
  }
});

// ============================================================
// Auto-load Project (replaces manual directory picker)
// ============================================================

/**
 * Auto-discover and load project files via the dev server API on page load.
 * @returns {Promise<void>}
 */
async function autoLoadProject() {
  console.log('autoLoadProject: starting...');
  setStatus('Loading project...');

  const result = await FileDiscovery.discoverViaApi();
  if (!result.success) {
    console.error(`autoLoadProject: Discovery failed — ${result.error}`);
    showError(result.error);
    return;
  }

  console.log('autoLoadProject: Discovery succeeded. Initializing...');
  dirtyTracker.markAllClean();
  commandHistory.clear();
  initializeAfterLoad();

  const mapCount = ProjectContext.files.maps.size;
  const resCount = ProjectContext.files.resources.size;
  const biomeCount = ProjectContext.files.biomes.size;
  setStatus(`Project loaded: ${mapCount} map(s), ${resCount} resource(s), ${biomeCount} biome(s)`);
  console.log('autoLoadProject: Workspace ready.');
}

autoLoadProject();

/**
 * Post-load initialization: load first map into grid, build biome color map.
 * @returns {void}
 */
function initializeAfterLoad() {
  console.group('initializeAfterLoad');

  // Build biome color map from loaded .tres data
  biomeColorMap.clear();
  for (const [filename, entry] of ProjectContext.files.biomes) {
    const colorField = entry.raw.resourceFields.get('color');
    if (colorField && colorField.type === 'color') {
      const biomeName = filename.replace('.tres', '');
      const c = colorField.value;
      const r = Math.round(c.r * 255);
      const g = Math.round(c.g * 255);
      const b = Math.round(c.b * 255);
      biomeColorMap.set(biomeName, `rgb(${r},${g},${b})`);
      console.log(`  Biome color: "${biomeName}" -> rgb(${r},${g},${b})`);
    } else {
      console.warn(`  Biome "${filename}" has no valid color field.`);
    }
  }
  console.log(`Biome color map built — ${biomeColorMap.size} entries.`);

  // Load first map into grid
  const firstMap = ProjectContext.files.maps.entries().next();
  if (!firstMap.done) {
    const [mapName, mapEntry] = firstMap.value;
    const tileCount = mapEntry.data.tiles ? Object.keys(mapEntry.data.tiles).length : 0;
    console.log(`Loading map "${mapName}" into grid — ${tileCount} tiles.`);
    const loadResult = loadMapIntoGrid(hexGrid, mapEntry.data);
    if (!loadResult.success) {
      console.error(`Failed to load map "${mapName}": ${loadResult.error}`);
      showError(`Loading map: ${loadResult.error}`);
    } else {
      console.log(`Grid loaded — ${hexGrid.tiles.size} tiles in HexGrid.`);
    }
  } else {
    console.warn('No maps found in ProjectContext. Grid will be empty.');
  }

  // Resize and center map — must happen after workspace is visible
  // so the canvas gets correct dimensions from its parent.
  if (hexCanvas) {
    hexCanvas._onResize();
    hexCanvas.fitToView();
    console.log('Canvas resized and map centered.');
  } else {
    console.warn('hexCanvas is null — canvas not initialized.');
  }

  // Render resource list in the Resources tab (task-012/013)
  const resourceTabEl = document.getElementById('tab-resources');
  if (resourceTabEl) {
    renderResourceList(resourceTabEl, { commandHistory });
    console.log('Resource list rendered.');
  }

  // Render biome list in the Biomes tab (task-014/015)
  const biomeTabEl = document.getElementById('tab-biomes');
  if (biomeTabEl) {
    renderBiomeList(biomeTabEl, { commandHistory, biomeColorMap, hexCanvas });
    console.log('Biome list rendered.');
  }

  // Initialize sidebar palettes and tool buttons (task-012b)
  initSidebar();
  console.log('Sidebar initialized.');

  // Update hex inspector map stats after loading
  if (hexInspector) {
    hexInspector.updateMapStats();
    console.log('Hex inspector map stats updated.');
  }

  console.groupEnd();
}

// ============================================================
// Canvas Initialization (task-008)
// ============================================================

{
  const canvasEl = document.getElementById('hex-canvas');
  if (canvasEl && typeof canvasEl.getContext === 'function') {
    hexCanvas = new HexCanvas(/** @type {HTMLCanvasElement} */ (canvasEl), hexGrid, camera, biomeColorMap);
    hexCanvas.toolManager = toolManager;
    hexCanvas.init();
  }

  // Wire coordinates toggle
  const chkCoords = document.getElementById('chk-coordinates');
  if (chkCoords) {
    chkCoords.addEventListener('change', (e) => {
      if (hexCanvas) {
        hexCanvas.showCoordinates = /** @type {HTMLInputElement} */ (e.target).checked;
        hexCanvas.requestRender();
      }
    });
  }

  // Initialize HexInspector (right sidebar)
  const sidebarEl = document.getElementById('sidebar');
  if (sidebarEl) {
    hexInspector = new HexInspector(sidebarEl, hexGrid, commandHistory, biomeColorMap);
  }

  // Wire canvas hover to hex inspector
  if (hexCanvas) {
    hexCanvas.onHexHover = (hex, subHex) => {
      if (hexInspector) hexInspector.updateHex(hex, subHex);
    };
  }
}

// ============================================================
// Sidebar — Tool Selector, Palettes, Map Dropdown (task-012b)
// ============================================================

/** @type {string|null} Currently selected map filename in the dropdown */
let activeMapFilename = null;

/**
 * Tool definitions for the tool button grid.
 * @type {Array<{type: string, label: string, shortcut: string}>}
 */
const TOOL_DEFS = [
  { type: 'biome',      label: 'Biome',      shortcut: 'B' },
  { type: 'elevation',  label: 'Elevation',   shortcut: 'E' },
  { type: 'resource',   label: 'Resource',    shortcut: 'R' },
  { type: 'structure',  label: 'Structure',   shortcut: 'S' },
  { type: 'anomaly',    label: 'Anomaly',     shortcut: 'A' },
  { type: 'spawn',      label: 'Spawn',       shortcut: 'P' },
  { type: 'eraser',     label: 'Eraser',      shortcut: 'X' },
  { type: 'delete_hex', label: 'Delete Hex',  shortcut: 'D' },
  { type: 'flood_fill', label: 'Flood Fill',  shortcut: 'F' },
];

/**
 * Initialize the sidebar: populate tool buttons, palettes, map dropdown.
 * Called after project files are loaded (from initializeAfterLoad).
 * @returns {void}
 */
function initSidebar() {
  _initToolButtons();
  _initMapSelector();
  _initBiomePalette();
  _initResourcePalette();
  _initStructurePalette();
  _initElevationControls();
  updateSidebar();

  // Trigger canvas resize to account for sidebar width
  if (hexCanvas) hexCanvas._onResize();
}

/**
 * Create tool buttons in the tool grid.
 * @returns {void}
 */
function _initToolButtons() {
  const container = document.getElementById('tool-buttons');
  if (!container) return;
  container.innerHTML = '';
  for (const def of TOOL_DEFS) {
    const btn = document.createElement('button');
    btn.className = 'tool-btn';
    btn.dataset.tool = def.type;
    btn.textContent = `${def.label} (${def.shortcut})`;
    btn.title = `${def.label} — shortcut: ${def.shortcut}`;
    btn.addEventListener('click', () => {
      // If clicking the already-active tool, deselect it
      if (toolManager.activeToolType === def.type) {
        selectTool(null);
      } else {
        selectTool(def.type);
      }
    });
    container.appendChild(btn);
  }
}

/**
 * Populate the map dropdown from ProjectContext.files.maps.
 * @returns {void}
 */
function _initMapSelector() {
  const selector = /** @type {HTMLSelectElement|null} */ (document.getElementById('map-selector'));
  if (!selector) return;
  selector.innerHTML = '';

  const maps = ProjectContext.files.maps;
  if (maps.size === 0) {
    const opt = document.createElement('option');
    opt.textContent = '(no maps)';
    opt.disabled = true;
    selector.appendChild(opt);
    return;
  }

  let first = true;
  for (const [filename] of maps) {
    const opt = document.createElement('option');
    opt.value = filename;
    opt.textContent = filename;
    if (first) {
      opt.selected = true;
      activeMapFilename = filename;
      first = false;
    }
    selector.appendChild(opt);
  }

  selector.addEventListener('change', () => {
    const selectedFilename = selector.value;
    if (selectedFilename === activeMapFilename) return;

    if (dirtyTracker.hasUnsavedChanges()) {
      if (!confirm('Unsaved changes will be lost. Switch map?')) {
        // Revert dropdown
        selector.value = activeMapFilename || '';
        return;
      }
    }

    const mapEntry = ProjectContext.files.maps.get(selectedFilename);
    if (!mapEntry) return;

    activeMapFilename = selectedFilename;
    loadMapIntoGrid(hexGrid, mapEntry.data);
    commandHistory.clear();
    dirtyTracker.markAllClean();
    if (hexCanvas) {
      hexCanvas.fitToView();
      hexCanvas.requestRender();
    }
    if (hexInspector) {
      hexInspector.updateMapStats();
    }
    setStatus(`Map "${selectedFilename}" loaded.`);
  });
}

/**
 * Populate the biome palette from biomeColorMap.
 * @returns {void}
 */
function _initBiomePalette() {
  const container = document.getElementById('palette-biome-list');
  if (!container) return;
  container.innerHTML = '';

  for (const [biomeName, color] of biomeColorMap) {
    const item = document.createElement('div');
    item.className = 'palette-item';
    item.dataset.value = biomeName;

    const swatch = document.createElement('span');
    swatch.className = 'biome-swatch';
    swatch.style.backgroundColor = color;

    const label = document.createElement('span');
    label.textContent = biomeName;

    item.appendChild(swatch);
    item.appendChild(label);

    item.addEventListener('click', () => {
      toolManager.setTool('biome', biomeName);
      if (hexCanvas) hexCanvas.toolManager = toolManager;
      updateSidebar();
      setStatus(`Tool: biome — ${biomeName}`);
    });

    container.appendChild(item);
  }
}

/**
 * Populate the resource palette from ProjectContext.files.resources.
 * @returns {void}
 */
function _initResourcePalette() {
  const container = document.getElementById('palette-resource-list');
  if (!container) return;
  container.innerHTML = '';

  for (const [filename] of ProjectContext.files.resources) {
    const resourceName = filename.replace('.tres', '');
    const item = document.createElement('div');
    item.className = 'palette-item';
    item.dataset.value = resourceName;

    const label = document.createElement('span');
    label.textContent = resourceName;
    item.appendChild(label);

    item.addEventListener('click', () => {
      toolManager.setTool('resource', resourceName);
      if (hexCanvas) hexCanvas.toolManager = toolManager;
      updateSidebar();
      setStatus(`Tool: resource — ${resourceName}`);
    });

    container.appendChild(item);
  }
}

/**
 * Populate the structure palette from STRUCTURE_FOOTPRINTS.
 * @returns {void}
 */
function _initStructurePalette() {
  const container = document.getElementById('palette-structure-list');
  if (!container) return;
  container.innerHTML = '';

  for (const [structName, footprint] of Object.entries(STRUCTURE_FOOTPRINTS)) {
    const item = document.createElement('div');
    item.className = 'palette-item';
    item.dataset.value = structName;

    const label = document.createElement('span');
    label.textContent = `${structName} (${footprint.length})`;
    item.appendChild(label);

    item.addEventListener('click', () => {
      toolManager.setTool('structure', structName);
      if (hexCanvas) hexCanvas.toolManager = toolManager;
      updateSidebar();
      setStatus(`Tool: structure — ${structName}`);
    });

    container.appendChild(item);
  }
}

/**
 * Wire elevation control buttons and input.
 * @returns {void}
 */
function _initElevationControls() {
  // Mode toggle buttons
  const modeBtns = document.querySelectorAll('.elev-mode-btn');
  const setControls = document.getElementById('elev-set-controls');
  const incControls = document.getElementById('elev-inc-controls');

  modeBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      const mode = btn.dataset.mode;
      toolManager.elevationMode = mode;

      modeBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');

      if (mode === 'set') {
        if (setControls) setControls.style.display = '';
        if (incControls) incControls.style.display = 'none';
      } else {
        if (setControls) setControls.style.display = 'none';
        if (incControls) incControls.style.display = '';
      }
    });
  });

  // SET mode value input
  const elevValue = /** @type {HTMLInputElement|null} */ (document.getElementById('elev-value'));
  if (elevValue) {
    elevValue.addEventListener('input', () => {
      const val = parseInt(elevValue.value, 10);
      if (!isNaN(val)) {
        toolManager.elevationValue = Math.max(0, Math.min(9, val));
      }
    });
  }

  // INCREMENT mode buttons
  const elevDec = document.getElementById('elev-dec');
  const elevInc = document.getElementById('elev-inc');
  if (elevDec) {
    elevDec.addEventListener('click', () => {
      toolManager.elevationDelta = -1;
      setStatus('Elevation: decrement by 1');
    });
  }
  if (elevInc) {
    elevInc.addEventListener('click', () => {
      toolManager.elevationDelta = 1;
      setStatus('Elevation: increment by 1');
    });
  }
}

/**
 * Update the sidebar to reflect current tool state.
 * Highlights active tool button, shows relevant palette, updates display.
 * @returns {void}
 */
function updateSidebar() {
  const activeType = toolManager.activeToolType;
  const activeValue = toolManager.activeValue;

  // Update tool buttons highlight
  document.querySelectorAll('#tool-buttons .tool-btn').forEach(btn => {
    if (btn.dataset.tool === activeType) {
      btn.classList.add('active');
    } else {
      btn.classList.remove('active');
    }
  });

  // Show/hide palettes based on active tool
  const palettes = ['biome', 'resource', 'structure', 'elevation'];
  for (const p of palettes) {
    const el = document.getElementById('palette-' + p);
    if (!el) continue;
    if (p === activeType) {
      el.classList.remove('hidden');
    } else {
      el.classList.add('hidden');
    }
  }

  // Also show biome palette for flood_fill tool (it paints biomes)
  const biomePalette = document.getElementById('palette-biome');
  if (biomePalette && activeType === 'flood_fill') {
    biomePalette.classList.remove('hidden');
  }

  // Highlight selected value in palettes
  document.querySelectorAll('.palette-item').forEach(item => {
    if (item.dataset.value === activeValue) {
      item.classList.add('selected');
    } else {
      item.classList.remove('selected');
    }
  });

  // Update active tool display
  const display = document.getElementById('active-tool-display');
  if (display) {
    if (!activeType) {
      display.textContent = 'No tool selected';
    } else if (activeValue) {
      display.textContent = `${activeType}: ${activeValue}`;
    } else {
      display.textContent = activeType;
    }
  }

  // Update toolbar indicator too
  const indicator = document.getElementById('tool-indicator');
  if (indicator) {
    if (!activeType) {
      indicator.textContent = '';
    } else if (activeValue) {
      indicator.textContent = `Tool: ${activeType} — ${activeValue}`;
    } else {
      indicator.textContent = `Tool: ${activeType}`;
    }
  }
}
