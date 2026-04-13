'use strict';

// ============================================================
// App Bootstrap — imports all modules, wires DOM events
// ============================================================

import { TresParser } from './tres-parser.js';
import { HexGrid, loadMapIntoGrid, serializeGridToMapJson, CATEGORIES, ORIGINS, NATURAL_CATEGORIES, CATEGORY_TO_INT, INT_TO_ORIGIN, defaultOrigin } from './hex-grid.js';
import { CommandHistory } from './commands.js';
import { ProjectContext, FileDiscovery } from './file-discovery.js';
import { HexCanvas } from './canvas.js';
import { HexInspector, showInlineModal, showInlineFormModal, showErrorListModal } from './panels.js';
import { KeyboardManager } from './keyboard.js';
import { DirtyTracker } from './dirty-tracker.js';
import { ToolManager } from './tools.js';
import { validateMap } from './validator.js';
import { renderPropEditor } from './prop-editor.js';
import { renderBiomeEditor } from './biome-editor.js';
import { renderRecipeEditor } from './recipe-editor.js';
import { renderEventEditor } from './event-editor.js';
import { renderJournalEditor } from './journal-editor.js';
import { renderCutsceneEditor } from './cutscene-editor.js';
import { renderSettingsEditor } from './settings-editor.js';
import { clearBiomeTextureCache } from './biome-textures.js';

// ============================================================
// Module-level state
// ============================================================

/** @type {string} Currently active tab — 'map' | 'props' | 'biomes' */
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

/** @type {Map<string, string>} Prop type -> CSS color string, from placeholder_color */
const propColorMap = new Map();

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
  map: 'Maps',
  mineral: 'Minerals',
  plant: 'Flora',
  animal: 'Fauna',
  fungi: 'Fungi',
  ooze: 'Oozes',
  liquid: 'Liquids',
  stuff: 'Stuff',
  structure: 'Structures',
  equipment: 'Equipment',
  vehicle: 'Vehicles',
  storage: 'Containers',
  biomes: 'Biomes',
  recipes: 'Recipes',
  events: 'Events',
  journal: 'Journal',
  cutscenes: 'Cutscenes',
  settings: 'Game Settings',
};

/** Tab IDs that show the prop editor (one per category). */
const PROP_CATEGORY_TABS = [
  'mineral', 'plant', 'animal', 'fungi', 'ooze', 'liquid',
  'stuff', 'structure', 'equipment', 'vehicle', 'storage',
];

/**
 * Switch to the specified tab.
 * @param {string} tabName - 'map' | 'props' | 'biomes'
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
 * Safely extract a string value, handling undefined/null.
 * @param {*} val
 * @returns {string}
 */
function _str(val) {
  if (val == null) return '';
  return String(val);
}

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
keyboardManager.register('v', mapOnly(() => selectTool('select')));
keyboardManager.register('b', mapOnly(() => selectTool('biome')));
keyboardManager.register('e', mapOnly(() => selectTool('elevation')));
keyboardManager.register('r', mapOnly(() => selectTool('prop')));
keyboardManager.register('p', mapOnly(() => selectTool('spawn')));
keyboardManager.register('x', mapOnly(() => selectTool('eraser')));
keyboardManager.register('d', mapOnly(() => selectTool('delete_hex')));
keyboardManager.register('f', mapOnly(() => selectTool('flood_fill')));
keyboardManager.register('escape', mapOnly(() => selectTool('select')));

// Global shortcuts
keyboardManager.register('ctrl+z', () => commandHistory.undo());
keyboardManager.register('ctrl+shift+z', () => commandHistory.redo());
keyboardManager.register('ctrl+s', () => saveAll());
keyboardManager.register('ctrl+shift+s', () => saveMapAs());
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
    // Category tabs share the 'props' dirty bucket since they all edit prop files
    const dirtyKey = PROP_CATEGORY_TABS.includes(tab) ? 'props' : tab;
    if (dirtyTracker.isDirty(dirtyKey)) {
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
 * Clear the grid and start a new map, prompting for chapter ID and map
 * name in a single dialog, then immediately persisting an empty map
 * file so the user has something on disk right after clicking New.
 * @returns {void}
 */
function newMap() {
  if (dirtyTracker.hasUnsavedChanges()) {
    if (!confirm('Unsaved changes will be lost. Continue?')) return;
  }
  showInlineFormModal('Create New Map', [
    { label: 'Chapter ID', defaultValue: 'ch1', placeholder: 'e.g. ch1' },
    { label: 'Map Name', defaultValue: 'New Map', placeholder: 'Human-readable name' },
  ], async (values) => {
    if (values === null) return;
    const chapterId = (values[0] || '').trim() || 'ch1';
    const mapName = (values[1] || '').trim() || 'New Map';
    // Filename is derived from the Chapter ID so the on-disk name
    // matches how the game references maps (GameSettings.starting_map
    // and SaveManager.current_map both use short filenames like
    // "ch1.json").
    const filenameStem = `${chapterId}.json`;

    if (ProjectContext.files.maps.has(filenameStem)) {
      showError(`A map named "${filenameStem}" already exists. Pick a different filename.`);
      return;
    }

    hexGrid.clear();
    hexGrid.meta = { chapter_id: chapterId, name: mapName, spawn: [0, 0] };
    commandHistory.clear();

    // Persist the fresh empty map immediately so New creates a real file
    // on disk, not just in-memory state.
    try {
      const mapData = serializeGridToMapJson(hexGrid);
      const json = JSON.stringify(mapData, null, '\t');
      await FileDiscovery.saveFile('data/maps', json, filenameStem);
      ProjectContext.files.maps.set(filenameStem, {
        handle: null,
        dir: 'data/maps',
        data: mapData,
      });
      activeMapFilename = filenameStem;
      dirtyTracker.markAllClean();
      if (hexCanvas) hexCanvas.requestRender();
      _rebuildColorMaps();
      _refreshMapSelector();
      setStatus(`New map "${mapName}" created (${filenameStem}).`);
    } catch (err) {
      showError(`Failed to save new map: ${err.message}`);
    }
  });
}

/**
 * Save the current map to a new filename. Prompts for the filename,
 * validates the map, then writes via the server API. Switches the
 * active map to the new file on success.
 * @returns {void}
 */
function saveMapAs() {
  // Validate first so we don't create a broken file
  const knownBiomes = new Set([...ProjectContext.files.biomes.keys()].map(f => f.replace('.tres', '')));
  const knownProps = new Set([...ProjectContext.files.props.keys()].map(f => f.replace('.tres', '')));
  const validation = validateMap(hexGrid, knownBiomes, knownProps);
  if (!validation.valid) {
    showErrorListModal('Map validation failed — Save As blocked', validation.errors);
    setStatus(`Save As blocked: ${validation.errors.length} validation error(s)`);
    return;
  }

  const defaultName = hexGrid.meta.chapter_id || 'map';
  showInlineModal('Save As (filename):', defaultName, async (filename) => {
    if (filename === null) return;
    const name = filename.trim();
    if (!name) {
      setStatus('Save As cancelled: empty filename.');
      return;
    }
    const finalName = name.endsWith('.json') ? name : name + '.json';
    if (ProjectContext.files.maps.has(finalName)) {
      if (!confirm(`Map "${finalName}" already exists. Overwrite?`)) return;
    }
    try {
      const mapData = serializeGridToMapJson(hexGrid);
      const json = JSON.stringify(mapData, null, '\t');
      await FileDiscovery.saveFile('data/maps', json, finalName);
      // Register in ProjectContext so the dropdown picks it up
      ProjectContext.files.maps.set(finalName, {
        handle: null,
        dir: 'data/maps',
        data: mapData,
      });
      activeMapFilename = finalName;
      dirtyTracker.markClean('map');
      _refreshMapSelector();
      setStatus(`Saved as "${finalName}".`);
    } catch (err) {
      showError(`Save As failed: ${err.message}`);
    }
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
  const knownProps = new Set([...ProjectContext.files.props.keys()].map(f => f.replace('.tres', '')));
  const validation = validateMap(hexGrid, knownBiomes, knownProps);
  if (!validation.valid) {
    showErrorListModal('Map validation failed — save blocked', validation.errors);
    setStatus(`Save blocked: ${validation.errors.length} validation error(s)`);
    return;
  }

  const tabs = ['map', 'props', 'biomes', 'recipes', 'events', 'journal', 'cutscenes'];
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
 * @param {string} tab - 'map' | 'props' | 'biomes' | 'recipes' | 'events'
 * @returns {Promise<void>}
 */
async function saveTab(tab) {
  if (tab === 'map') {
    // Serialize from the live HexGrid model — only save the active map
    const mapData = serializeGridToMapJson(hexGrid);
    const entry = activeMapFilename ? ProjectContext.files.maps.get(activeMapFilename) : null;
    if (entry) {
      entry.data = mapData;
      const json = JSON.stringify(entry.data, null, '\t');
      await FileDiscovery.saveFile(entry.dir || 'data/maps', json, activeMapFilename);
    }
  } else if (tab === 'props') {
    for (const [filename, entry] of ProjectContext.files.props) {
      const text = TresParser.serialize(entry.raw);
      await FileDiscovery.saveFile(entry.dir || 'data/props', text, filename);
    }
  } else if (tab === 'biomes') {
    for (const [filename, entry] of ProjectContext.files.biomes) {
      const text = TresParser.serialize(entry.raw);
      await FileDiscovery.saveFile(entry.dir || 'data/biomes', text, filename);
    }
  } else if (tab === 'recipes') {
    for (const [filename, entry] of ProjectContext.files.recipes) {
      const text = TresParser.serialize(entry.raw);
      await FileDiscovery.saveFile(entry.dir || 'data/recipes', text, filename);
    }
  } else if (tab === 'events') {
    for (const [filename, entry] of ProjectContext.files.events) {
      const text = TresParser.serialize(entry.raw);
      await FileDiscovery.saveFile(entry.dir || 'data/events', text, filename);
    }
  } else if (tab === 'journal') {
    // Edits are persisted per-command by journal-editor.js (Create/Edit/Delete).
    // This pass re-serializes any entries that still have raw data so an
    // unmodified round-trip stays byte-clean on explicit Save.
    for (const [filename, entry] of ProjectContext.files.journal) {
      if (!entry || !entry.raw) continue;
      const text = TresParser.serialize(entry.raw);
      await FileDiscovery.saveFile(entry.dir || 'data/journal', text, filename);
    }
  } else if (tab === 'cutscenes') {
    // Edits are persisted per-command by cutscene-editor.js (Create/Edit/Delete).
    // This pass re-serializes any entries that still have raw data so an
    // unmodified round-trip stays byte-clean on explicit Save.
    for (const [filename, entry] of ProjectContext.files.cutscenes) {
      if (!entry || !entry.raw) continue;
      const text = TresParser.serialize(entry.raw);
      await FileDiscovery.saveFile(entry.dir || 'data/cutscenes', text, filename);
    }
  }
}

// Wire Save button
document.getElementById('btn-save').addEventListener('click', () => saveAll());
const btnSaveAs = document.getElementById('btn-save-as');
if (btnSaveAs) btnSaveAs.addEventListener('click', () => saveMapAs());
const btnNewMap = document.getElementById('btn-new-map');
if (btnNewMap) btnNewMap.addEventListener('click', () => newMap());

// Biome render-mode toggle (Color | Texture). Texture mode mirrors the
// runtime hash-picked variation + rotation so the editor preview matches
// what the player sees in Godot.
function _setBiomeRenderMode(mode) {
  if (!hexCanvas) return;
  hexCanvas.biomeRenderMode = mode;
  const colorBtn = document.getElementById('btn-render-color');
  const textureBtn = document.getElementById('btn-render-texture');
  if (colorBtn) colorBtn.classList.toggle('active', mode === 'color');
  if (textureBtn) textureBtn.classList.toggle('active', mode === 'texture');
  hexCanvas.requestRender();
}
const btnRenderColor = document.getElementById('btn-render-color');
if (btnRenderColor) btnRenderColor.addEventListener('click', () => _setBiomeRenderMode('color'));
const btnRenderTexture = document.getElementById('btn-render-texture');
if (btnRenderTexture) btnRenderTexture.addEventListener('click', () => _setBiomeRenderMode('texture'));

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
  const propCount = ProjectContext.files.props.size;
  const biomeCount = ProjectContext.files.biomes.size;
  setStatus(`Project loaded: ${mapCount} map(s), ${propCount} prop(s), ${biomeCount} biome(s)`);
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

  // Build prop color map from loaded .tres data (stored in files.props)
  propColorMap.clear();
  for (const [filename, entry] of ProjectContext.files.props) {
    const colorField = entry.raw.resourceFields.get('placeholder_color');
    if (colorField && colorField.type === 'color') {
      const propName = filename.replace('.tres', '');
      const c = colorField.value;
      const r = Math.round(c.r * 255);
      const g = Math.round(c.g * 255);
      const b = Math.round(c.b * 255);
      propColorMap.set(propName, `rgb(${r},${g},${b})`);
      console.log(`  Prop color: "${propName}" -> rgb(${r},${g},${b})`);
    } else {
      console.warn(`  Prop "${filename}" has no valid placeholder_color field.`);
    }
  }
  console.log(`Prop color map built — ${propColorMap.size} entries.`);

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

  // Render prop editor in each category tab with the category filter locked.
  for (const cat of PROP_CATEGORY_TABS) {
    const tabEl = document.getElementById(`tab-${cat}`);
    if (tabEl) {
      renderPropEditor(tabEl, {
        commandHistory,
        categoryFilter: cat,
        onChange: refreshPalettes,
        onSave: () => { refreshPalettes(); dirtyTracker.markClean('props'); },
      });
    }
  }
  console.log('Prop editors rendered (one per category tab).');

  // Render biome list in the Biomes tab (task-014/015)
  const biomeTabEl = document.getElementById('tab-biomes');
  if (biomeTabEl) {
    renderBiomeEditor(biomeTabEl, {
      commandHistory,
      biomeColorMap,
      hexCanvas,
      onChange: refreshPalettes,
      onSave: () => { refreshPalettes(); dirtyTracker.markClean('biomes'); },
    });
    console.log('Biome editor rendered.');
  }

  // Render recipe editor in the Recipes tab (task-039b)
  const recipeTabEl = document.getElementById('tab-recipes');
  if (recipeTabEl) {
    renderRecipeEditor(recipeTabEl, {
      commandHistory,
      onChange: refreshPalettes,
      onSave: () => { refreshPalettes(); dirtyTracker.markClean('recipes'); },
    });
    console.log('Recipe editor rendered.');
  }

  // Render event editor in the Events tab
  const eventTabEl = document.getElementById('tab-events');
  if (eventTabEl) {
    renderEventEditor(eventTabEl, {
      commandHistory,
      onChange: refreshPalettes,
      onSave: () => { refreshPalettes(); dirtyTracker.markClean('events'); },
    });
    console.log('Event editor rendered.');
  }

  // Render journal editor in the Journal tab (task-076)
  const journalTabEl = document.getElementById('tab-journal');
  if (journalTabEl) {
    renderJournalEditor(journalTabEl, {
      commandHistory,
      onChange: refreshPalettes,
      onSave: () => { dirtyTracker.markClean('journal'); },
    });
    console.log('Journal editor rendered.');
  }

  // Render cutscene editor in the Cutscenes tab (task-077)
  const cutsceneTabEl = document.getElementById('tab-cutscenes');
  if (cutsceneTabEl) {
    renderCutsceneEditor(cutsceneTabEl, {
      commandHistory,
      onChange: refreshPalettes,
      onSave: () => { dirtyTracker.markClean('cutscenes'); },
    });
    console.log('Cutscene editor rendered.');
  }

  // Render Game Settings editor (singleton form — data/game_settings.tres)
  const settingsTabEl = document.getElementById('tab-settings');
  if (settingsTabEl) {
    renderSettingsEditor(settingsTabEl, {
      onSave: () => setStatus('Game settings saved.'),
    }).catch((err) => console.warn(`Settings editor failed to load: ${err.message}`));
    console.log('Settings editor rendered.');
  }

  // Initialize sidebar palettes and tool buttons (task-012b)
  initSidebar();
  console.log('Sidebar initialized.');

  // Update hex inspector map stats after loading
  if (hexInspector) {
    hexInspector.updateMapStats();
    console.log('Hex inspector map stats updated.');
  }

  // Start with Select tool active
  selectTool('select');

  console.groupEnd();
}

// ============================================================
// Canvas Initialization (task-008)
// ============================================================

{
  const canvasEl = document.getElementById('hex-canvas');
  if (canvasEl && typeof canvasEl.getContext === 'function') {
    hexCanvas = new HexCanvas(/** @type {HTMLCanvasElement} */ (canvasEl), hexGrid, camera, biomeColorMap, propColorMap);
    hexCanvas.toolManager = toolManager;
    hexCanvas.init();
  }

  // Initialize HexInspector (right sidebar)
  const sidebarEl = document.getElementById('sidebar');
  if (sidebarEl) {
    hexInspector = new HexInspector(sidebarEl, hexGrid, commandHistory, biomeColorMap);
    // Editing chapter_id or name marks the map dirty
    hexInspector.onMapMetaChange = () => {
      dirtyTracker.markDirty('map');
    };
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
 * Tool definitions grouped by scope.
 * @type {Array<{group: string, tools: Array<{type: string, label: string, shortcut: string}>}>}
 */
const TOOL_GROUPS = [
  { group: 'General', tools: [
    { type: 'select',     label: 'Select',     shortcut: 'V' },
  ]},
  { group: 'Hex Tools', tools: [
    { type: 'biome',      label: 'Biome',      shortcut: 'B' },
    { type: 'elevation',  label: 'Elevation',   shortcut: 'E' },
    { type: 'flood_fill', label: 'Flood Fill',  shortcut: 'F' },
    { type: 'delete_hex', label: 'Delete Hex',  shortcut: 'D' },
  ]},
  { group: 'Sub-Hex Tools', tools: [
    { type: 'prop',       label: 'Prop',        shortcut: 'R' },
    { type: 'spawn',      label: 'Spawn',       shortcut: 'P' },
    { type: 'eraser',     label: 'Eraser',      shortcut: 'X' },
  ]},
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
  _initPropPalette();
  _initElevationControls();
  updateSidebar();

  // Trigger canvas resize to account for sidebar width
  if (hexCanvas) hexCanvas._onResize();
}

/**
 * Rebuild biomeColorMap and propColorMap from current ProjectContext.
 * Called after prop/biome edits so the canvas and palettes update.
 * @returns {void}
 */
function _rebuildColorMaps() {
  biomeColorMap.clear();
  for (const [filename, entry] of ProjectContext.files.biomes) {
    const colorField = entry.raw && entry.raw.resourceFields.get('color');
    if (colorField && colorField.type === 'color') {
      const biomeName = filename.replace('.tres', '');
      const c = colorField.value;
      const r = Math.round(c.r * 255);
      const g = Math.round(c.g * 255);
      const b = Math.round(c.b * 255);
      biomeColorMap.set(biomeName, `rgb(${r},${g},${b})`);
    }
  }
  propColorMap.clear();
  for (const [filename, entry] of ProjectContext.files.props) {
    const colorField = entry.raw && entry.raw.resourceFields.get('placeholder_color');
    if (colorField && colorField.type === 'color') {
      const propName = filename.replace('.tres', '');
      const c = colorField.value;
      const r = Math.round(c.r * 255);
      const g = Math.round(c.g * 255);
      const b = Math.round(c.b * 255);
      propColorMap.set(propName, `rgb(${r},${g},${b})`);
    }
  }
}

/**
 * Rebuild the sidebar palettes and color maps. Called by the prop/biome
 * editors after create/edit/delete operations so the map tab reflects changes.
 * @returns {void}
 */
function refreshPalettes() {
  _rebuildColorMaps();
  _initBiomePalette();
  _initPropPalette();
  updateSidebar();
  // Biome texture lists may have changed (the user could have added or
  // removed entries from terrain_textures in a .tres). Drop both the
  // shared loader cache and the per-canvas cache so the next render in
  // Texture mode re-fetches.
  clearBiomeTextureCache();
  if (hexCanvas) {
    hexCanvas._biomeTextures.clear();
    hexCanvas._biomeTexturesRequested.clear();
    hexCanvas.requestRender();
  }
  if (hexInspector) hexInspector.updateMapStats();
}

/**
 * Create tool buttons in the tool grid.
 * @returns {void}
 */
function _initToolButtons() {
  const container = document.getElementById('tool-buttons');
  if (!container) return;
  container.innerHTML = '';
  for (const group of TOOL_GROUPS) {
    const header = document.createElement('div');
    header.className = 'tool-group-header';
    header.textContent = group.group;
    container.appendChild(header);

    const grid = document.createElement('div');
    grid.className = 'tool-grid';
    for (const def of group.tools) {
      const btn = document.createElement('button');
      btn.className = 'tool-btn';
      btn.dataset.tool = def.type;
      btn.textContent = `${def.label} (${def.shortcut})`;
      btn.title = `${def.label} — shortcut: ${def.shortcut}`;
      btn.addEventListener('click', () => {
        if (toolManager.activeToolType === def.type && def.type !== 'select') {
          selectTool('select');
        } else {
          selectTool(def.type);
        }
      });
      grid.appendChild(btn);
    }
    container.appendChild(grid);
  }
}

/**
 * Populate the map dropdown from ProjectContext.files.maps.
 * @returns {void}
 */
/**
 * Rebuild the map selector <option> list from ProjectContext.
 * Keeps the current active map selected if still present.
 * @returns {void}
 */
function _refreshMapSelector() {
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
  for (const [filename] of maps) {
    const opt = document.createElement('option');
    opt.value = filename;
    opt.textContent = filename;
    if (filename === activeMapFilename) opt.selected = true;
    selector.appendChild(opt);
  }
}

function _initMapSelector() {
  const selector = /** @type {HTMLSelectElement|null} */ (document.getElementById('map-selector'));
  if (!selector) return;

  const maps = ProjectContext.files.maps;
  if (maps.size > 0 && !activeMapFilename) {
    activeMapFilename = maps.keys().next().value;
  }
  _refreshMapSelector();

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

    // Show display name from .tres if available, otherwise the ID.
    // Accepts `display_name` (Gear-based B00NNN format) or the legacy
    // `biome_name` for any files that haven't been re-saved yet.
    const biomeEntry = ProjectContext.files.biomes.get(biomeName + '.tres');
    const entryData = biomeEntry && biomeEntry.data;
    const displayName = (entryData && (entryData.display_name || entryData.biome_name))
      ? String(entryData.display_name || entryData.biome_name)
      : biomeName;
    const label = document.createElement('span');
    label.textContent = displayName;

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

/** Natural category names (indices 0-5). */
const NATURAL_CATEGORY_NAMES = CATEGORIES.filter((_, i) => NATURAL_CATEGORIES.has(i));
/** Non-natural category names (indices 6-9). */
const NON_NATURAL_CATEGORY_NAMES = CATEGORIES.filter((_, i) => !NATURAL_CATEGORIES.has(i));

/**
 * Populate the prop palette with origin + category dropdowns and type list.
 * Origin → Category (filtered) → Type list (filtered).
 * @returns {void}
 */
function _initPropPalette() {
  const originSelect = /** @type {HTMLSelectElement|null} */ (document.getElementById('prop-origin-select'));
  const categorySelect = /** @type {HTMLSelectElement|null} */ (document.getElementById('prop-category-select'));
  const listContainer = document.getElementById('palette-prop-list');
  if (!originSelect || !categorySelect || !listContainer) return;

  // --- Populate origin dropdown ---
  originSelect.innerHTML = '';
  const originAll = document.createElement('option');
  originAll.value = 'all';
  originAll.textContent = 'All';
  originAll.selected = true;
  originSelect.appendChild(originAll);
  for (const o of ORIGINS) {
    const opt = document.createElement('option');
    opt.value = o;
    opt.textContent = o;
    originSelect.appendChild(opt);
  }

  /**
   * Get the list of categories allowed for the selected origin.
   * @param {string} origin - origin name or 'all'
   * @returns {string[]}
   */
  function _categoriesForOrigin(origin) {
    if (origin === 'all') return [...CATEGORIES];
    if (origin === 'natural') return [...NATURAL_CATEGORY_NAMES];
    return [...NON_NATURAL_CATEGORY_NAMES];
  }

  /**
   * Rebuild the category dropdown for the current origin selection.
   * @param {string} origin
   * @returns {void}
   */
  function _populateCategories(origin) {
    categorySelect.innerHTML = '';
    const catAll = document.createElement('option');
    catAll.value = 'all';
    catAll.textContent = 'All';
    catAll.selected = true;
    categorySelect.appendChild(catAll);
    for (const c of _categoriesForOrigin(origin)) {
      const opt = document.createElement('option');
      opt.value = c;
      opt.textContent = c;
      categorySelect.appendChild(opt);
    }
  }

  /**
   * Rebuild the type list based on the selected origin and category.
   * @param {string} origin - 'all' or an origin name
   * @param {string} category - 'all' or a category name
   * @returns {void}
   */
  function _populateTypeList(origin, category) {
    listContainer.innerHTML = '';
    const allowedCats = _categoriesForOrigin(origin);
    const showCats = category === 'all' ? allowedCats : [category];

    // All props come from ProjectContext.files.props
    for (const [filename, entry] of ProjectContext.files.props) {
      const propName = filename.replace('.tres', '');
      const d = entry.data;

      // Only show placeable props on the map
      if (!d.placeable) continue;

      // Read prop_category (int) and convert to category name
      const catInt = d.prop_category != null ? Number(d.prop_category) : 0;
      const resCat = CATEGORIES[catInt] || 'plant';
      if (!showCats.includes(resCat)) continue;

      // Read origin (int) and convert to origin name
      const originInt = d.origin != null ? Number(d.origin) : 0;
      const resOrigin = ORIGINS[originInt] || 'natural';
      if (origin !== 'all' && resOrigin !== origin) continue;

      const displayName = _str(d.display_name) || propName;
      _addTypeItem(propName, displayName, resCat, resOrigin);
    }

    if (listContainer.children.length === 0) {
      const empty = document.createElement('div');
      empty.style.cssText = 'padding:8px;color:var(--text-secondary);font-size:11px;';
      empty.textContent = 'No prop types available for this filter.';
      listContainer.appendChild(empty);
    }
  }

  /**
   * Add a clickable type item to the list.
   * @param {string} typeName - The prop type ID (used for tool value)
   * @param {string} displayName - Human-readable name shown in the list
   * @param {string} cat
   * @param {string} originName
   */
  function _addTypeItem(typeName, displayName, cat, originName) {
    const item = document.createElement('div');
    item.className = 'palette-item';
    item.dataset.value = typeName;
    const label = document.createElement('span');
    label.textContent = displayName;
    item.appendChild(label);
    item.addEventListener('click', () => {
      toolManager.setTool('prop', typeName);
      toolManager.activeCategory = cat;
      toolManager.activeOrigin = originName;
      if (hexCanvas) hexCanvas.toolManager = toolManager;
      updateSidebar();
      setStatus(`Tool: prop — ${originName}/${cat}/${typeName}`);
    });
    listContainer.appendChild(item);
  }

  // Initial population
  _populateCategories('all');
  _populateTypeList('all', 'all');

  // Wire origin change → reset category to All, rebuild both
  originSelect.addEventListener('change', () => {
    const origin = originSelect.value;
    _populateCategories(origin);
    _populateTypeList(origin, 'all');
  });

  // Wire category change → rebuild type list
  categorySelect.addEventListener('change', () => {
    const origin = originSelect.value;
    const category = categorySelect.value;
    _populateTypeList(origin, category);
  });
}

/**
 * Elevation now only has one gesture pattern (left click = +1, right
 * click = -1) so there's nothing to wire from the sidebar. Kept as a
 * no-op so existing call sites don't break.
 * @returns {void}
 */
function _initElevationControls() {}

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
  const palettes = ['biome', 'prop', 'elevation'];
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
