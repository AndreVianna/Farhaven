'use strict';

// ============================================================
// App Bootstrap — imports all modules, wires DOM events
// ============================================================

import { TresParser } from './tres-parser.js';
import { HexGrid, loadMapIntoGrid, serializeGridToMapJson, CATEGORIES, ORIGINS, NATURAL_CATEGORIES, CATEGORY_TO_INT, INT_TO_ORIGIN, defaultOrigin } from './hex-grid.js';
import { CommandHistory, EditPropCommand } from './commands.js';
import { ProjectContext, FileDiscovery } from './file-discovery.js';
import { HexCanvas } from './canvas.js';
import { HexInspector, showInlineModal, showInlineFormModal, showErrorListModal, showPropOverrideModal } from './panels.js';
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
import { showGeneratorDialog, generateMap } from './map-generator.js';
import { computePopulatePlan, buildPopulateCommand, computeClearNaturalsPlan, buildClearNaturalsCommand } from './populate.js';
import { mountTitlebar } from './titlebar.js';
import { mountSidebar, NAV } from './sidebar.js';
import { openCommandPalette } from './command-palette.js';
import { mountStatusbar } from './statusbar.js';
import { toggleTweaksPanel, applyPersistedTweaks } from './tweaks.js';

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
  settings: 'Settings',
};

/** Tab IDs that show the prop editor (one per category). */
const PROP_CATEGORY_TABS = [
  'mineral', 'plant', 'animal', 'fungi', 'ooze', 'liquid',
  'stuff', 'structure', 'equipment', 'vehicle', 'storage',
];

/**
 * Optional guards registered by editors to veto a tab switch when the
 * active editor has pending in-form state (not yet committed to the
 * model/dirtyTracker). Each guard returns `true` to allow the switch,
 * `false` to cancel. See prop-editor's _guardDirty for an example.
 * @type {Array<() => boolean>}
 */
const _tabSwitchGuards = [];

export function registerTabSwitchGuard(fn) {
  _tabSwitchGuards.push(fn);
}

/** @type {{refresh: () => void, setActive: (id: string) => void}|null} */
let sidebarHandle = null;

/** @type {{refresh: () => void, setBreadcrumb: (text: string) => void}|null} */
let titlebarHandle = null;

/** @type {{refresh: () => void}|null} */
let statusbarHandle = null;

/**
 * Switch to the specified route (tab). Updates the sidebar's active
 * state and shows the matching panel. No-op if the route id is
 * unknown. Runs tab-switch guards to protect unsaved form state.
 * @param {string} tabName
 * @returns {void}
 */
function switchTab(tabName) {
  if (!TAB_LABELS[tabName]) return;
  if (tabName === activeTab) return;
  for (const guard of _tabSwitchGuards) {
    if (guard() === false) return;
  }
  activeTab = tabName;

  document.querySelectorAll('.tab-panel').forEach(panel => {
    if (panel.id === 'tab-' + tabName) {
      panel.classList.add('active');
    } else {
      panel.classList.remove('active');
    }
  });

  if (sidebarHandle) sidebarHandle.setActive(tabName);
}

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

// Surface save failures. Previously every saveFile error was swallowed
// by the caller's `.catch(err => console.warn(...))` — the user only
// learned something went wrong when they later noticed the file hadn't
// updated. Centralized notifier means every failed save shows up in
// the status bar, and when saveFile offers a download-fallback path
// (server unreachable) the user is asked before the browser drops a
// stray copy in Downloads.
FileDiscovery.onSaveError = (path, err, opts) => {
  setStatus(`Save failed: ${path} — ${err.message}`);
  const options = opts || {};
  const hint = options.hint ? `\n\n${options.hint}` : '';
  if (options.canFallbackToDownload && typeof options.downloadFallback === 'function') {
    const download = confirm(
      `Failed to save ${path}\n\n${err.message}${hint}\n\n` +
      'Download a copy locally? (Click Cancel to abort — nothing is saved.)'
    );
    if (download) options.downloadFallback();
  } else {
    alert(`Failed to save ${path}\n\n${err.message}${hint}`);
  }
};

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
    // Clear hex selection for wall tool — the selection highlight
    // blocks the wall edge highlight.
    if (toolName === 'wall') {
      hexCanvas.selectedHex = null;
      hexCanvas.requestRender();
    }
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
keyboardManager.register('w', mapOnly(() => selectTool('wall')));
keyboardManager.register('d', mapOnly(() => selectTool('delete_hex')));
keyboardManager.register('h', mapOnly(() => { if (hexCanvas) hexCanvas.centerOnSpawn(); }));
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
 * Refresh sidebar counts / active state after data mutations.
 * Keeps the name for backwards-compatible call sites.
 * @returns {void}
 */
function updateTabIndicators() {
  if (sidebarHandle) sidebarHandle.refresh();
  if (titlebarHandle) titlebarHandle.refresh();
  if (statusbarHandle) statusbarHandle.refresh();
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
      showError(`A map named "${filenameStem}" already exists. Use a different Chapter ID.`);
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
// Delete Map
// ============================================================

async function _deleteCurrentMap() {
  if (!activeMapFilename) {
    showError('No map is currently loaded.');
    return;
  }
  if (!confirm(`Delete "${activeMapFilename}" permanently? This cannot be undone.`)) return;

  try {
    await FileDiscovery.deleteFile('data/maps', activeMapFilename);
    ProjectContext.files.maps.delete(activeMapFilename);

    // Switch to another map or clear the grid
    const remaining = [...ProjectContext.files.maps.keys()];
    if (remaining.length > 0) {
      const nextMapFilename = remaining[0];
      const entry = ProjectContext.files.maps.get(nextMapFilename);
      const loadResult = loadMapIntoGrid(hexGrid, entry.data);
      if (!loadResult.success) {
        showError(`Deleted map, but failed to load "${nextMapFilename}": ${loadResult.error}`);
        activeMapFilename = null;
        hexGrid.clear();
        hexGrid.meta = { chapter_id: '', name: '', spawn: [0, 0], generator: null };
      } else {
        activeMapFilename = nextMapFilename;
      }
    } else {
      activeMapFilename = null;
      hexGrid.clear();
      hexGrid.meta = { chapter_id: '', name: '', spawn: [0, 0], generator: null };
    }

    commandHistory.clear();
    dirtyTracker.markAllClean();
    if (hexCanvas) {
      hexCanvas.requestRender();
      hexCanvas.centerOnSpawn();
    }
    _rebuildColorMaps();
    _refreshMapSelector();
    if (hexInspector) hexInspector.updateMapStats();
    setStatus(activeMapFilename ? `Deleted. Switched to "${activeMapFilename}".` : 'Map deleted. No maps remaining.');
  } catch (err) {
    showError(`Failed to delete map: ${err.message}`);
  }
}

// ============================================================
// Procedural Map Generator
// ============================================================

function _generateProceduralMap() {
  if (dirtyTracker.hasUnsavedChanges()) {
    if (!confirm('Unsaved changes will be lost. Continue?')) return;
  }
  showGeneratorDialog(async (mapData, opts) => {
    const filenameStem = `${opts.chapterId}.json`;
    if (ProjectContext.files.maps.has(filenameStem)) {
      if (!confirm(`Map "${filenameStem}" already exists. Overwrite?`)) return;
    }

    const result = loadMapIntoGrid(hexGrid, mapData);
    if (!result.success) {
      showError(`Failed to load generated map: ${result.error}`);
      return;
    }

    try {
      const json = JSON.stringify(mapData, null, '\t');
      await FileDiscovery.saveFile('data/maps', json, filenameStem);
      ProjectContext.files.maps.set(filenameStem, {
        handle: null,
        dir: 'data/maps',
        data: mapData,
      });
      activeMapFilename = filenameStem;
      commandHistory.clear();
      dirtyTracker.markAllClean();
      if (hexCanvas) {
        hexCanvas.requestRender();
        hexCanvas.centerOnSpawn();
      }
      _rebuildColorMaps();
      _refreshMapSelector();
      if (hexInspector) hexInspector.updateMapStats();
      const tileCount = Object.keys(mapData.tiles).length;
      setStatus(`Generated "${opts.mapName}" — ${tileCount} tiles (seed ${mapData.generator.seed}).`);
    } catch (err) {
      showError(`Failed to save generated map: ${err.message}`);
    }
  });
}

/**
 * Regenerate the current map using its stored generator params.
 * Called from the Map Info panel's Regenerate button.
 */
async function _regenerateMap() {
  const gen = hexGrid.meta.generator;
  if (!gen) return;

  if (!confirm('Regenerate this map? All manual edits will be lost.')) return;

  // Clamp params to safe bounds (same as showGeneratorDialog)
  const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
  const opts = {
    ...gen,
    radius: clamp(gen.radius || 20, 1, 500),
    frequency: clamp(gen.frequency || 0.05, 0.02, 0.15),
    warpStrength: clamp(gen.warpStrength || 0.5, 0, 2),
    peakHeight: clamp(gen.peakHeight || 200, 50, 500),
    redistPower: clamp(gen.redistPower || 2, 0.5, 5),
    erosionDrops: clamp(gen.erosionDrops || 5000, 0, 500000),
    erosionSteps: clamp(gen.erosionSteps || 30, 1, 100),
    riverThreshold: clamp(gen.riverThreshold || 15, 3, 100),
    moistureFalloff: clamp(gen.moistureFalloff || 0.85, 0.1, 0.99),
    crashRadius: clamp(gen.crashRadius || 3, 0, 10),
    chapterId: hexGrid.meta.chapter_id,
    mapName: hexGrid.meta.name,
  };

  const t0 = performance.now();
  const mapData = generateMap(opts);
  const elapsed = (performance.now() - t0).toFixed(0);

  const result = loadMapIntoGrid(hexGrid, mapData);
  if (!result.success) {
    showError(`Regeneration failed: ${result.error}`);
    return;
  }

  try {
    const filenameStem = activeMapFilename || `${opts.chapterId}.json`;
    const json = JSON.stringify(mapData, null, '\t');
    await FileDiscovery.saveFile('data/maps', json, filenameStem);
    ProjectContext.files.maps.set(filenameStem, {
      handle: null,
      dir: 'data/maps',
      data: mapData,
    });
    commandHistory.clear();
    dirtyTracker.markAllClean();
    if (hexCanvas) {
      hexCanvas.requestRender();
      hexCanvas.centerOnSpawn();
    }
    _rebuildColorMaps();
    if (hexInspector) hexInspector.updateMapStats();
    const tileCount = Object.keys(mapData.tiles).length;
    setStatus(`Regenerated — ${tileCount} tiles in ${elapsed}ms (seed ${mapData.generator.seed}).`);
  } catch (err) {
    showError(`Failed to save regenerated map: ${err.message}`);
  }
}

/**
 * Handle the Populate button — builds a distribution plan from the
 * active map's biomes, shows the user a summary dialog with a
 * Replace toggle, and on confirm commits the plan through the
 * CommandHistory as a single undoable batch.
 * @returns {void}
 */
function _populateMap() {
  if (!hexGrid || hexGrid.tiles.size === 0) {
    setStatus('Populate — no map loaded.');
    return;
  }
  _showPopulateDialog(false);
}

/**
 * Render the populate confirmation dialog. Recomputes the plan
 * whenever the user toggles "Replace existing", so the displayed
 * add/remove counts always match what Apply will do.
 * @param {boolean} initialReplace
 * @returns {void}
 */
function _showPopulateDialog(initialReplace) {
  const existing = document.getElementById('populate-modal');
  if (existing) existing.remove();

  const overlay = document.createElement('div');
  overlay.id = 'populate-modal';
  overlay.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.5);z-index:500;display:flex;align-items:center;justify-content:center;';
  const dialog = document.createElement('div');
  dialog.style.cssText = 'background:var(--bg-secondary);border:1px solid var(--border);border-radius:8px;padding:20px;min-width:420px;max-width:560px;color:var(--text-primary);display:flex;flex-direction:column;gap:10px;';

  const title = document.createElement('div');
  title.textContent = 'Populate Map';
  title.style.cssText = 'font-size:15px;font-weight:600;';
  dialog.appendChild(title);

  const hint = document.createElement('div');
  hint.classList.add('prop-hint');
  hint.style.fontSize = '12px';
  hint.textContent = 'Distributes natural props from each tile\'s biome rules. Deterministic per seed. Categories run in order Mineral → Liquid → Ooze → Fungi → Flora → Fauna so near_prop conditions see props placed earlier in the run.';
  dialog.appendChild(hint);

  const replaceRow = document.createElement('label');
  replaceRow.style.cssText = 'display:flex;gap:6px;align-items:center;font-size:13px;';
  const replaceCb = document.createElement('input');
  replaceCb.type = 'checkbox';
  replaceCb.checked = !!initialReplace;
  const replaceLbl = document.createElement('span');
  replaceLbl.textContent = 'Replace existing natural props (structures / equipment stay)';
  replaceRow.appendChild(replaceCb);
  replaceRow.appendChild(replaceLbl);
  dialog.appendChild(replaceRow);

  const summary = document.createElement('pre');
  summary.style.cssText = 'background:var(--bg-primary);border:1px solid var(--border);border-radius:4px;padding:8px;margin:0;font-family:monospace;font-size:12px;max-height:260px;overflow:auto;white-space:pre-wrap;';
  dialog.appendChild(summary);

  /** @type {import('./populate.js').PopulatePlan|null} */
  let currentPlan = null;

  const _refreshPlan = () => {
    currentPlan = computePopulatePlan(hexGrid, { replace: replaceCb.checked });
    const lines = [];
    lines.push(`seed:          ${currentPlan.seed}`);
    lines.push(`tiles touched: ${currentPlan.touchedTiles}`);
    lines.push(`props added:   ${currentPlan.props.length}`);
    if (currentPlan.removed.length > 0) {
      lines.push(`props removed: ${currentPlan.removed.length} (existing naturals)`);
    }
    lines.push('');
    lines.push('by type:');
    const sortedTypes = [...currentPlan.countByType.entries()].sort((a, b) => b[1] - a[1]);
    if (sortedTypes.length === 0) {
      lines.push('  (none — no biomes with natural_props conditions qualified)');
    } else {
      for (const [type, n] of sortedTypes) lines.push(`  ${type.padEnd(10)} ${n}`);
    }
    summary.textContent = lines.join('\n');
  };
  _refreshPlan();
  replaceCb.addEventListener('change', _refreshPlan);

  const btnRow = document.createElement('div');
  btnRow.style.cssText = 'display:flex;gap:8px;justify-content:flex-end;margin-top:4px;';
  const btnCancel = document.createElement('button');
  btnCancel.textContent = 'Cancel';
  btnCancel.classList.add('prop-btn');
  const btnApply = document.createElement('button');
  btnApply.textContent = 'Apply';
  btnApply.classList.add('prop-btn-primary');

  const cleanup = () => {
    overlay.remove();
    document.removeEventListener('keydown', keyHandler);
  };
  const keyHandler = (e) => { if (e.key === 'Escape') cleanup(); };
  btnCancel.addEventListener('click', cleanup);
  btnApply.addEventListener('click', () => {
    if (!currentPlan || (currentPlan.props.length === 0 && currentPlan.removed.length === 0)) {
      cleanup();
      setStatus('Populate — nothing to do.');
      return;
    }
    const cmd = buildPopulateCommand(hexGrid, currentPlan);
    commandHistory.execute(cmd);
    dirtyTracker.markDirty('map');
    if (hexCanvas) hexCanvas.requestRender();
    if (hexInspector) hexInspector.updateMapStats();
    setStatus(`Populated ${currentPlan.props.length} props across ${currentPlan.touchedTiles} tiles (seed ${currentPlan.seed}).`);
    cleanup();
  });
  btnRow.appendChild(btnCancel);
  btnRow.appendChild(btnApply);
  dialog.appendChild(btnRow);

  overlay.appendChild(dialog);
  document.body.appendChild(overlay);
  document.addEventListener('keydown', keyHandler);
  btnApply.focus();
}

/**
 * Track the Clear modal's latest cleanup function so re-entrancy
 * (user clicks Clear a second time before the first modal closes)
 * can dispose the stale keydown listener before installing the new
 * one. Without this, each re-open leaks another document-level
 * listener for the lifetime of the tab.
 * @type {(() => void) | null}
 */
let _clearModalCleanup = null;

/**
 * Handle the "Clear" button — wipes every natural-origin prop from
 * the map in a single undoable batch. Gated by a confirmation modal
 * because it's destructive; player-placed structures, anomalies
 * (explicitly filtered via category), and anything with a non-natural
 * origin stay put.
 * @returns {void}
 */
function _clearNaturalProps() {
  if (!hexGrid || hexGrid.tiles.size === 0) {
    setStatus('Clear — no map loaded.');
    return;
  }
  const plan = computeClearNaturalsPlan(hexGrid);
  if (plan.removed.length === 0) {
    setStatus('Clear — no natural props to remove.');
    return;
  }

  // Re-entrancy: dispose the previous modal (if any) via its own
  // cleanup so the document-level keydown listener is removed before
  // we install a new one.
  if (_clearModalCleanup) {
    try { _clearModalCleanup(); } catch (_e) { /* best-effort */ }
    _clearModalCleanup = null;
  }

  const overlay = document.createElement('div');
  overlay.id = 'clear-naturals-modal';
  overlay.setAttribute('role', 'dialog');
  overlay.setAttribute('aria-modal', 'true');
  overlay.setAttribute('aria-labelledby', 'clear-naturals-modal-title');
  overlay.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.5);z-index:500;display:flex;align-items:center;justify-content:center;';
  const dialog = document.createElement('div');
  dialog.style.cssText = 'background:var(--bg-secondary);border:1px solid var(--border);border-radius:8px;padding:20px;min-width:420px;max-width:560px;color:var(--text-primary);display:flex;flex-direction:column;gap:10px;';

  const title = document.createElement('div');
  title.id = 'clear-naturals-modal-title';
  title.textContent = 'Clear Natural Props';
  title.style.cssText = 'font-size:15px;font-weight:600;';
  dialog.appendChild(title);

  const hint = document.createElement('div');
  hint.classList.add('prop-hint');
  hint.style.fontSize = '12px';
  // textContent (not innerHTML) — values are safe integers but the
  // defensive choice removes any marginal XSS surface as this file
  // evolves.
  const hintStrong1 = document.createElement('strong');
  hintStrong1.textContent = String(plan.removed.length);
  const hintStrong2 = document.createElement('strong');
  hintStrong2.textContent = String(plan.touchedTiles);
  hint.append(
    'This will remove ', hintStrong1,
    ' natural props from ', hintStrong2,
    ' tiles. Player-placed structures, equipment, and anomalies are preserved (anomalies filtered by category, independent of origin). Undoable via Ctrl+Z.'
  );
  dialog.appendChild(hint);

  const summary = document.createElement('pre');
  summary.style.cssText = 'background:var(--bg-primary);border:1px solid var(--border);border-radius:4px;padding:8px;margin:0;font-family:monospace;font-size:12px;max-height:260px;overflow:auto;white-space:pre-wrap;';
  const lines = [];
  lines.push(`tiles touched: ${plan.touchedTiles}`);
  lines.push(`props removed: ${plan.removed.length}`);
  lines.push('');
  lines.push('by type:');
  const sortedTypes = [...plan.countByType.entries()].sort((a, b) => b[1] - a[1]);
  for (const [type, n] of sortedTypes) lines.push(`  ${type.padEnd(10)} ${n}`);
  summary.textContent = lines.join('\n');
  dialog.appendChild(summary);

  const btnRow = document.createElement('div');
  btnRow.style.cssText = 'display:flex;gap:8px;justify-content:flex-end;margin-top:4px;';
  const btnCancel = document.createElement('button');
  btnCancel.textContent = 'Cancel';
  btnCancel.classList.add('prop-btn');
  const btnApply = document.createElement('button');
  btnApply.textContent = 'Clear';
  btnApply.classList.add('prop-btn-primary');
  btnApply.style.background = 'var(--danger, #7a3030)';

  const cleanup = () => {
    overlay.remove();
    // MUST match the useCapture flag used on add (see below), or the
    // DOM leaves the listener attached — which would mean every
    // subsequent Ctrl+Z/Y/Shift+Z in the editor hits our stale
    // preventDefault wrapper and undo/redo silently stop working
    // globally (found in round-2 review).
    document.removeEventListener('keydown', keyHandler, true);
    overlay.removeEventListener('click', overlayClickHandler);
    if (_clearModalCleanup === cleanup) _clearModalCleanup = null;
  };
  // Swallow Ctrl+Z / Ctrl+Y / Ctrl+Shift+Z inside the modal so
  // the global KeyboardManager (document-level listener) doesn't
  // fire undo/redo against the editor history while the user is
  // looking at a destructive confirm dialog. Escape dismisses.
  const keyHandler = (e) => {
    if (e.key === 'Escape') {
      e.preventDefault();
      e.stopPropagation();
      cleanup();
      return;
    }
    const isUndoLike =
      (e.ctrlKey || e.metaKey) && (e.key === 'z' || e.key === 'Z' || e.key === 'y' || e.key === 'Y');
    if (isUndoLike) {
      e.preventDefault();
      e.stopPropagation();
    }
  };
  // Backdrop click dismisses — matches standard destructive-dialog UX.
  const overlayClickHandler = (e) => {
    if (e.target === overlay) cleanup();
  };

  btnCancel.addEventListener('click', cleanup);
  btnApply.addEventListener('click', () => {
    const cmd = buildClearNaturalsCommand(hexGrid, plan);
    commandHistory.execute(cmd);
    dirtyTracker.markDirty('map');
    // Invalidate stale prop selection — if the user had a natural
    // prop selected, its propIndex now points to nothing or shifts to
    // a surviving prop. Clearing avoids a misleading highlight.
    if (hexCanvas) {
      hexCanvas.selectedProp = null;
      hexCanvas.requestRender();
    }
    if (hexInspector) {
      hexInspector.updateMapStats();
      // Refresh the current hex details / prop editor panel so the
      // just-deleted props disappear from the sidebar, not just the
      // canvas.
      if (typeof hexInspector._refreshCurrentHex === 'function') {
        hexInspector._refreshCurrentHex();
      }
    }
    setStatus(`Cleared ${plan.removed.length} natural props across ${plan.touchedTiles} tiles.`);
    cleanup();
  });
  btnRow.appendChild(btnCancel);
  btnRow.appendChild(btnApply);
  dialog.appendChild(btnRow);

  overlay.appendChild(dialog);
  document.body.appendChild(overlay);
  document.addEventListener('keydown', keyHandler, true);  // capture so we beat KeyboardManager
  overlay.addEventListener('click', overlayClickHandler);
  _clearModalCleanup = cleanup;
  btnCancel.focus();  // focus Cancel by default — this is destructive
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
const btnGenerateMap = document.getElementById('btn-generate-map');
if (btnGenerateMap) btnGenerateMap.addEventListener('click', () => _generateProceduralMap());
const btnPopulateMap = document.getElementById('btn-populate-map');
if (btnPopulateMap) btnPopulateMap.addEventListener('click', () => _populateMap());
const btnClearProps = document.getElementById('btn-clear-props');
if (btnClearProps) btnClearProps.addEventListener('click', () => _clearNaturalProps());
const btnDeleteMap = document.getElementById('btn-delete-map');
if (btnDeleteMap) btnDeleteMap.addEventListener('click', () => _deleteCurrentMap());

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

// Apply persisted accent/density tweaks before anything renders so the
// user's preference lands on first paint instead of flashing amber first.
applyPersistedTweaks();

autoLoadProject();

/**
 * Build the titlebar menus + wire their actions.
 * @returns {Array<{label: string, items: Array}>}
 */
function _buildTitlebarMenus() {
  return [
    {
      label: 'File',
      items: [
        { label: 'New Map…',    kbd: 'Ctrl+N',       action: () => _clickByIdIfExists('btn-new-map') },
        { label: 'Generate Procedural Map', action: () => _clickByIdIfExists('btn-generate-map') },
        { separator: true },
        { label: 'Save All',    kbd: 'Ctrl+S',       action: () => _clickByIdIfExists('btn-save') },
        { label: 'Save As…',    kbd: 'Ctrl+Shift+S', action: () => _clickByIdIfExists('btn-save-as') },
        { separator: true },
        { label: 'Delete Map…', danger: true,        action: () => _clickByIdIfExists('btn-delete-map') },
      ],
    },
    {
      label: 'Edit',
      items: [
        { label: 'Undo',        kbd: 'Ctrl+Z',       action: () => { if (commandHistory.canUndo()) commandHistory.undo(); if (hexCanvas) hexCanvas.requestRender(); updateTabIndicators(); }, disabled: () => !commandHistory.canUndo() },
        { label: 'Redo',        kbd: 'Ctrl+Shift+Z', action: () => { if (commandHistory.canRedo()) commandHistory.redo(); if (hexCanvas) hexCanvas.requestRender(); updateTabIndicators(); }, disabled: () => !commandHistory.canRedo() },
      ],
    },
    {
      label: 'View',
      items: [
        { label: 'Biome Preview: Color',   action: () => _clickByIdIfExists('btn-render-color') },
        { label: 'Biome Preview: Texture', action: () => _clickByIdIfExists('btn-render-texture') },
      ],
    },
    {
      label: 'Tools',
      items: [
        { label: 'Populate Natural Props…', action: () => _clickByIdIfExists('btn-populate-map') },
        { label: 'Clear Natural Props…',    danger: true, action: () => _clickByIdIfExists('btn-clear-props') },
      ],
    },
    {
      label: 'Run',
      items: [
        { label: 'Playtest in Godot', kbd: 'F5', disabled: () => true, action: () => {} },
      ],
    },
    {
      label: 'Help',
      items: [
        { label: 'Keyboard Shortcuts', kbd: '?', action: _toggleHelpOverlay },
      ],
    },
  ];
}

/** @param {string} id */
function _clickByIdIfExists(id) {
  const el = document.getElementById(id);
  if (el && typeof el.click === 'function') el.click();
}

function _toggleHelpOverlay() {
  const overlay = document.getElementById('help-overlay');
  const backdrop = document.getElementById('help-overlay-backdrop');
  if (!overlay) return;
  const isVisible = overlay.classList.contains('visible');
  overlay.classList.toggle('visible', !isVisible);
  if (backdrop) backdrop.classList.toggle('visible', !isVisible);
}

function _openCommandPaletteWithCtx() {
  openCommandPalette({
    commands: {
      save: () => _clickByIdIfExists('btn-save'),
      undo: () => { if (commandHistory.canUndo()) { commandHistory.undo(); if (hexCanvas) hexCanvas.requestRender(); updateTabIndicators(); } },
      redo: () => { if (commandHistory.canRedo()) { commandHistory.redo(); if (hexCanvas) hexCanvas.requestRender(); updateTabIndicators(); } },
      newMap: () => _clickByIdIfExists('btn-new-map'),
      generateMap: () => _clickByIdIfExists('btn-generate-map'),
      populate: () => _clickByIdIfExists('btn-populate-map'),
      clearProps: () => _clickByIdIfExists('btn-clear-props'),
      help: _toggleHelpOverlay,
    },
    onRoute: (id) => switchTab(id),
  });
}

// Global keyboard shortcut: Ctrl/⌘+K opens the palette.
document.addEventListener('keydown', (e) => {
  const mod = e.ctrlKey || e.metaKey;
  if (mod && (e.key === 'k' || e.key === 'K')) {
    // Don't swallow if a modal input has focus on something that
    // might care about ⌘K (unlikely, but defensive).
    e.preventDefault();
    _openCommandPaletteWithCtx();
  }
});

/**
 * Mount the new shell (titlebar + sidebar). Called once after
 * ProjectContext + commandHistory + dirtyTracker are available.
 * @returns {void}
 */
function _mountShell() {
  const titlebarEl = document.getElementById('titlebar');
  if (titlebarEl) {
    titlebarHandle = mountTitlebar(titlebarEl, {
      menus: _buildTitlebarMenus(),
      onCommandPalette: _openCommandPaletteWithCtx,
      onUndo: () => { if (commandHistory.canUndo()) commandHistory.undo(); if (hexCanvas) hexCanvas.requestRender(); updateTabIndicators(); },
      onRedo: () => { if (commandHistory.canRedo()) commandHistory.redo(); if (hexCanvas) hexCanvas.requestRender(); updateTabIndicators(); },
      onSave: () => _clickByIdIfExists('btn-save'),
      onPlaytest: _launchPlaytest,
      onTweaks: toggleTweaksPanel,
      isDirty: () => dirtyTracker.hasUnsavedChanges(),
    });
  }

  const sidebarEl = document.getElementById('sidebar-nav');
  if (sidebarEl) {
    sidebarHandle = mountSidebar(sidebarEl, {
      onRouteChange: (id) => switchTab(id),
      activeRouteId: () => activeTab,
    });
  }

  const statusbarEl = document.getElementById('status-bar');
  if (statusbarEl) {
    statusbarHandle = mountStatusbar(statusbarEl, {
      route: () => activeTab,
      isDirty: () => dirtyTracker.hasUnsavedChanges(),
      chapter: () => {
        const first = ProjectContext.files.maps.entries().next();
        if (first.done) return 'ch?';
        const [name, entry] = first.value;
        return (entry && entry.data && entry.data.chapter_id) || name.replace(/\.json$/i, '');
      },
    });
  }
}

/**
 * Launch Godot in a subprocess via the dev server /playtest endpoint.
 * Server returns 200 on success, 500 otherwise; either way we just show
 * a status line — the player then pops up in a new OS window.
 */
async function _launchPlaytest() {
  setStatus('Launching Godot…');
  try {
    const resp = await fetch('/playtest', { method: 'POST' });
    if (!resp.ok) {
      const msg = await resp.text().catch(() => '');
      setStatus(`Playtest failed: ${msg || resp.status}`);
      return;
    }
    setStatus('Godot launched.');
  } catch (err) {
    setStatus(`Playtest error: ${err.message || err}`);
  }
}

/**
 * Post-load initialization: load first map into grid, build biome color map.
 * @returns {void}
 */
function initializeAfterLoad() {
  console.group('initializeAfterLoad');

  // Mount titlebar + sidebar now that ProjectContext has data and the
  // callback wiring targets (commandHistory, dirtyTracker) are live.
  _mountShell();

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
  // Virtual water type entries — keep B00005 as alias for leveled
  if (biomeColorMap.has('B00005')) {
    biomeColorMap.set('B00005', 'rgb(30,80,160)');       // base = leveled color
    biomeColorMap.set('B00005:leveled', 'rgb(30,80,160)');
    biomeColorMap.set('B00005:flowing', 'rgb(70,150,220)');
  }
  console.log(`Biome color map built — ${biomeColorMap.size} entries.`);

  // Build prop color map from category (placeholder_color was removed in favor
  // of real meshes + reference PNGs; category-tinted icons are a pragmatic
  // fallback until the map view shows thumbnails directly).
  propColorMap.clear();
  for (const [filename, entry] of ProjectContext.files.props) {
    const propName = filename.replace('.tres', '');
    const category = entry.data && entry.data.category ? String(entry.data.category) : '';
    propColorMap.set(propName, _colorForPropCategory(category));
  }
  console.log(`Prop color map built — ${propColorMap.size} entries (category-tinted).`);

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
    hexCanvas.centerOnSpawn();
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
        registerGuard: registerTabSwitchGuard,
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
    hexInspector.onRegenerate = () => _regenerateMap();
  }

  // Wire canvas hover to hex inspector
  if (hexCanvas) {
    hexCanvas.onHexHover = (hex, subHex) => {
      if (hexInspector) hexInspector.updateHex(hex, subHex);
    };
    // Right-click on a placed prop → open the per-instance override
    // modal. canvas.js hit-tests and fires this callback only when the
    // click lands on an actual prop sub-hex (plain empty-tile right
    // clicks are swallowed server-side).
    hexCanvas.onPropContextMenu = (ctx) => {
      const entry = ProjectContext.files.props.get(ctx.prop.type + '.tres');
      const def = entry ? entry.data : null;
      showPropOverrideModal({
        prop: ctx.prop,
        def,
        onSave: (overrides) => {
          const oldValues = {
            placement_override: typeof ctx.prop.placement_override === 'number' ? ctx.prop.placement_override : -1,
            variant_override: typeof ctx.prop.variant_override === 'number' ? ctx.prop.variant_override : -1,
            scale_override: typeof ctx.prop.scale_override === 'number' ? ctx.prop.scale_override : -1,
            rotation_override: typeof ctx.prop.rotation_override === 'number' ? ctx.prop.rotation_override : -1,
          };
          // Skip the undo stack entry when nothing actually changed.
          if (oldValues.placement_override === overrides.placement_override
            && oldValues.variant_override === overrides.variant_override
            && oldValues.scale_override === overrides.scale_override
            && oldValues.rotation_override === overrides.rotation_override) return;
          const cmd = new EditPropCommand(hexGrid, ctx.hexQ, ctx.hexR, ctx.propIndex, oldValues, overrides);
          commandHistory.execute(cmd);
          hexCanvas.requestRender();
        },
      });
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
 * @type {Array<{group: string, tools: Array<{type: string, label: string, shortcut: string, action?: boolean}>}>}
 */
const TOOL_GROUPS = [
  { group: 'General', tools: [
    { type: 'select',     label: 'Select',     shortcut: 'V' },
    { type: 'home',       label: 'Home',       shortcut: 'H', action: true },
  ]},
  { group: 'Hex Tools', tools: [
    { type: 'biome',      label: 'Biome',      shortcut: 'B' },
    { type: 'elevation',  label: 'Elevation',   shortcut: 'E' },
    { type: 'wall',       label: 'Wall',        shortcut: 'W' },
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
  // Virtual water type entries — keep B00005 as alias for leveled
  if (biomeColorMap.has('B00005')) {
    biomeColorMap.set('B00005', 'rgb(30,80,160)');
    biomeColorMap.set('B00005:leveled', 'rgb(30,80,160)');
    biomeColorMap.set('B00005:flowing', 'rgb(70,150,220)');
  }

  propColorMap.clear();
  for (const [filename, entry] of ProjectContext.files.props) {
    const propName = filename.replace('.tres', '');
    const category = entry.data && entry.data.category ? String(entry.data.category) : '';
    propColorMap.set(propName, _colorForPropCategory(category));
  }
}

/**
 * Fallback color for a prop on the map view, keyed by its category.
 * Used until the map palette displays reference thumbnails directly.
 * @param {string} category
 * @returns {string}
 */
function _colorForPropCategory(category) {
  switch (String(category || '').toLowerCase()) {
    case 'plant': return 'rgb(110, 160, 80)';
    case 'mineral': return 'rgb(130, 115, 95)';
    case 'animal': return 'rgb(180, 90, 80)';
    case 'fungi': return 'rgb(150, 90, 170)';
    case 'ooze': return 'rgb(90, 160, 150)';
    case 'liquid': return 'rgb(70, 120, 180)';
    case 'structure': return 'rgb(120, 120, 140)';
    default: return 'rgb(130, 130, 130)';
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
    hexCanvas.clearBiomeTextureCache();
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
      btn.textContent = `${def.label} [${def.shortcut}]`;
      btn.title = `${def.label} — shortcut: ${def.shortcut}`;
      if (def.action) {
        // One-shot action button (not a toggle tool)
        btn.addEventListener('click', () => {
          if (def.type === 'home' && hexCanvas) hexCanvas.centerOnSpawn();
        });
      } else {
        btn.addEventListener('click', () => {
          if (toolManager.activeToolType === def.type && def.type !== 'select') {
            selectTool('select');
          } else {
            selectTool(def.type);
          }
        });
      }
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
      hexCanvas.centerOnSpawn();
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

  for (const [paletteKey, color] of biomeColorMap) {
    const item = document.createElement('div');
    item.className = 'palette-item';
    item.dataset.value = paletteKey;

    const swatch = document.createElement('span');
    swatch.className = 'biome-swatch';
    swatch.style.backgroundColor = color;

    // Parse compound key: 'B00005:leveled' → biomeId='B00005', waterType='leveled'
    const [biomeId, waterType] = paletteKey.includes(':') ? paletteKey.split(':') : [paletteKey, null];

    // Show display name from .tres if available
    const biomeEntry = ProjectContext.files.biomes.get(biomeId + '.tres');
    const entryData = biomeEntry && biomeEntry.data;
    let displayName = (entryData && (entryData.display_name || entryData.biome_name))
      ? String(entryData.display_name || entryData.biome_name)
      : biomeId;
    if (waterType) {
      displayName += waterType === 'leveled' ? ' (Leveled)' : ' (Flowing)';
    }
    const label = document.createElement('span');
    label.textContent = displayName;

    item.appendChild(swatch);
    item.appendChild(label);

    item.addEventListener('click', () => {
      toolManager.setTool('biome', paletteKey);
      if (hexCanvas) hexCanvas.toolManager = toolManager;
      updateSidebar();
      setStatus(`Tool: biome — ${displayName}`);
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

      // Read category (StringName field)
      const resCat = (typeof d.category === 'string' && d.category) ? d.category : 'plant';
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
