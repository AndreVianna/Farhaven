// ============================================================
// Inline Modal Dialog (task-010)
// ============================================================

import { EditPropCommand, DeletePropCommand, SetTemperatureCommand } from './commands.js';
import { HexMath } from './hex-math.js';
import { CATEGORY_COLORS } from './hex-grid.js';
import { ProjectContext } from './file-discovery.js';

/**
 * Resolve a tile's biome id to the flattened hazard-cap payload from
 * ProjectContext. Returns null when the biome has no hazard or the
 * cache hasn't been populated. Cached per-biome so the hex inspector
 * doesn't re-walk the registry on every hover.
 *
 * @param {string} biomeId
 * @returns {{damage_type: string, health_damage: number[], thirst_drain: number[], hunger_drain: number[], oxygen_drain: number[]} | null}
 */
const _hazardCache = new Map();
function _getBiomeHazard(biomeId) {
  if (!biomeId) return null;
  if (_hazardCache.has(biomeId)) return _hazardCache.get(biomeId);
  const entry = ProjectContext && ProjectContext.files && ProjectContext.files.biomes
    ? ProjectContext.files.biomes.get(biomeId + '.tres')
    : null;
  const h = entry && entry.data && entry.data.hazard;
  // entry.data.hazard is either null or the flattened sub_resource
  // fields. Typed arrays come in as [{type:'int', value:N}, …] so
  // unwrap each element before caching.
  if (!h || typeof h !== 'object' || !h.damage_type) {
    _hazardCache.set(biomeId, null);
    return null;
  }
  const unwrap = (v) => {
    let list = Array.isArray(v) ? v : (v && Array.isArray(v.value) ? v.value : null);
    if (!list) return [];
    return list.map((x) => (typeof x === 'number') ? x : (x && typeof x === 'object' && Number.isFinite(x.value) ? x.value : 0));
  };
  const cap = {
    damage_type: h.damage_type,
    health_damage: unwrap(h.health_damage),
    thirst_drain:  unwrap(h.thirst_drain),
    hunger_drain:  unwrap(h.hunger_drain),
    oxygen_drain:  unwrap(h.oxygen_drain),
  };
  _hazardCache.set(biomeId, cap);
  return cap;
}

/** Invalidate the hazard cache — called when biomes are saved so the
 *  inspector picks up edited tables without a page reload. */
export function invalidateBiomeHazardCache() {
  _hazardCache.clear();
}

/**
 * Show an inline modal dialog with a text input.
 * @param {string} label
 * @param {string} defaultValue
 * @param {function(string|null):void} callback
 * @returns {void}
 */
export function showInlineModal(label, defaultValue, callback) {
  // Remove existing modal if any
  const existing = document.getElementById('inline-modal');
  if (existing) existing.remove();

  const overlay = document.createElement('div');
  overlay.id = 'inline-modal';
  overlay.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.5);z-index:500;display:flex;align-items:center;justify-content:center;';

  const dialog = document.createElement('div');
  dialog.style.cssText = 'background:var(--bg-secondary);border:1px solid var(--border);border-radius:8px;padding:20px;min-width:320px;color:var(--text-primary);';

  const labelEl = document.createElement('div');
  labelEl.textContent = label;
  labelEl.style.cssText = 'margin-bottom:8px;font-size:14px;';

  const input = document.createElement('input');
  input.type = 'text';
  input.value = defaultValue;
  input.classList.add('prop-input');
  input.style.marginBottom = '12px';

  const btnRow = document.createElement('div');
  btnRow.style.cssText = 'display:flex;justify-content:flex-end;gap:8px;';

  const btnCancel = document.createElement('button');
  btnCancel.textContent = 'Cancel';
  btnCancel.classList.add('prop-btn');

  const btnOk = document.createElement('button');
  btnOk.textContent = 'OK';
  btnOk.classList.add('prop-btn-primary');

  const cleanup = () => overlay.remove();

  btnCancel.addEventListener('click', () => { cleanup(); callback(null); });
  btnOk.addEventListener('click', () => { cleanup(); callback(input.value); });
  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { cleanup(); callback(input.value); }
    if (e.key === 'Escape') { cleanup(); callback(null); }
  });

  btnRow.appendChild(btnCancel);
  btnRow.appendChild(btnOk);
  dialog.appendChild(labelEl);
  dialog.appendChild(input);
  dialog.appendChild(btnRow);
  overlay.appendChild(dialog);
  document.body.appendChild(overlay);
  input.focus();
  input.select();
}

/**
 * Show an inline modal dialog with multiple text inputs. Callback receives
 * an Array<string> in the same order as the `fields` argument, or null on
 * cancel. Each field is { label, defaultValue, placeholder? }.
 * @param {string} title
 * @param {Array<{label: string, defaultValue?: string, placeholder?: string}>} fields
 * @param {function(Array<string>|null):void} callback
 * @returns {void}
 */
export function showInlineFormModal(title, fields, callback) {
  const existing = document.getElementById('inline-modal');
  if (existing) existing.remove();

  const overlay = document.createElement('div');
  overlay.id = 'inline-modal';
  overlay.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.5);z-index:500;display:flex;align-items:center;justify-content:center;';

  const dialog = document.createElement('div');
  dialog.style.cssText = 'background:var(--bg-secondary);border:1px solid var(--border);border-radius:8px;padding:20px;min-width:360px;color:var(--text-primary);';

  if (title) {
    const titleEl = document.createElement('div');
    titleEl.textContent = title;
    titleEl.style.cssText = 'margin-bottom:12px;font-size:16px;font-weight:600;';
    dialog.appendChild(titleEl);
  }

  /** @type {HTMLInputElement[]} */
  const inputs = [];
  for (const field of fields) {
    const labelEl = document.createElement('div');
    labelEl.textContent = field.label;
    labelEl.style.cssText = 'margin-bottom:4px;font-size:13px;';

    const input = document.createElement('input');
    input.type = 'text';
    input.value = field.defaultValue != null ? String(field.defaultValue) : '';
    if (field.placeholder) input.placeholder = field.placeholder;
    input.classList.add('prop-input');
    input.style.marginBottom = '10px';

    dialog.appendChild(labelEl);
    dialog.appendChild(input);
    inputs.push(input);
  }

  const btnRow = document.createElement('div');
  btnRow.style.cssText = 'display:flex;justify-content:flex-end;gap:8px;';

  const btnCancel = document.createElement('button');
  btnCancel.textContent = 'Cancel';
  btnCancel.classList.add('prop-btn');

  const btnOk = document.createElement('button');
  btnOk.textContent = 'OK';
  btnOk.classList.add('prop-btn-primary');

  const cleanup = () => overlay.remove();
  const confirm = () => { cleanup(); callback(inputs.map(i => i.value)); };

  btnCancel.addEventListener('click', () => { cleanup(); callback(null); });
  btnOk.addEventListener('click', confirm);
  for (const input of inputs) {
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') confirm();
      if (e.key === 'Escape') { cleanup(); callback(null); }
    });
  }

  btnRow.appendChild(btnCancel);
  btnRow.appendChild(btnOk);
  dialog.appendChild(btnRow);
  overlay.appendChild(dialog);
  document.body.appendChild(overlay);
  if (inputs.length > 0) {
    inputs[0].focus();
    inputs[0].select();
  }
}

/**
 * Show a modal dialog listing multiple errors. Each error can have
 * hex coordinates, a field name, and a message. Scrollable if long.
 * @param {string} title
 * @param {Array<{hex?: number[], field?: string, message: string}>} errors
 * @returns {void}
 */
export function showErrorListModal(title, errors) {
  const existing = document.getElementById('error-modal');
  if (existing) existing.remove();

  const overlay = document.createElement('div');
  overlay.id = 'error-modal';
  overlay.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.5);z-index:500;display:flex;align-items:center;justify-content:center;';

  const dialog = document.createElement('div');
  dialog.style.cssText = 'background:var(--bg-secondary);border:1px solid var(--border);border-radius:8px;padding:20px;min-width:480px;max-width:720px;max-height:80vh;display:flex;flex-direction:column;color:var(--text-primary);';

  const titleEl = document.createElement('div');
  titleEl.textContent = title;
  titleEl.style.cssText = 'margin-bottom:10px;font-size:15px;font-weight:600;color:var(--text-error);';
  dialog.appendChild(titleEl);

  const summary = document.createElement('div');
  summary.textContent = `${errors.length} error${errors.length === 1 ? '' : 's'} found:`;
  summary.style.cssText = 'margin-bottom:8px;font-size:12px;color:var(--text-secondary);';
  dialog.appendChild(summary);

  const list = document.createElement('div');
  list.style.cssText = 'flex:1;overflow-y:auto;border:1px solid var(--border);border-radius:4px;background:var(--bg-primary);padding:8px;margin-bottom:12px;font-size:12px;font-family:monospace;';

  for (const err of errors) {
    const row = document.createElement('div');
    row.style.cssText = 'padding:4px 6px;border-bottom:1px solid var(--border);display:flex;gap:8px;';

    const prefix = document.createElement('span');
    prefix.style.cssText = 'color:var(--accent);flex-shrink:0;min-width:90px;';
    if (err.hex && err.hex.length > 0) {
      prefix.textContent = `(${err.hex.join(',')})`;
    } else {
      prefix.textContent = '(map)';
    }

    const msg = document.createElement('span');
    msg.style.cssText = 'color:var(--text-error);flex:1;word-break:break-word;';
    msg.textContent = err.field ? `${err.field}: ${err.message}` : err.message;

    row.appendChild(prefix);
    row.appendChild(msg);
    list.appendChild(row);
  }
  dialog.appendChild(list);

  const btnRow = document.createElement('div');
  btnRow.style.cssText = 'display:flex;justify-content:flex-end;gap:8px;';

  const btnClose = document.createElement('button');
  btnClose.textContent = 'Close';
  btnClose.classList.add('prop-btn-primary');

  // Cleanup must remove BOTH the overlay AND the document keydown listener
  // — the listener stays attached to document (not the overlay), so
  // removing only the DOM leaked a handler per modal open.
  const keyHandler = (e) => {
    if (e.key === 'Escape') cleanup();
  };
  const cleanup = () => {
    overlay.remove();
    document.removeEventListener('keydown', keyHandler);
  };
  btnClose.addEventListener('click', cleanup);
  document.addEventListener('keydown', keyHandler);

  btnRow.appendChild(btnClose);
  dialog.appendChild(btnRow);
  overlay.appendChild(dialog);
  document.body.appendChild(overlay);
  btnClose.focus();
}

// ============================================================
// Prop Override Modal (feature-011)
// ============================================================

/**
 * Per-instance override editor opened via right-click on a placed prop.
 * Lets the user pin placement preset, mesh variant, scale, and rotation
 * for a single Prop instance — the PropRenderer consults these before
 * falling back to the seeded scatter algorithm.
 *
 * Rules (from feature-011 spec):
 *  - When the effective preset is SINGLE, variant / scale / rotation are
 *    editable. Reset clears all four overrides at once.
 *  - When the effective preset is anything else, the three non-placement
 *    fields become read-only and show "(seeded)" because the engine
 *    only applies them to a SINGLE render and scatter copies would
 *    diverge from the pinned center visually.
 *
 * @param {{
 *   prop: Object,
 *   def: Object|null,            // PropDef data for this prop (meshes, placement default)
 *   onSave: (overrides: {
 *     placement_override: number,
 *     variant_override: number,
 *     scale_override: number,
 *     rotation_override: number,
 *   }) => void,
 * }} opts
 */
export function showPropOverrideModal(opts) {
  const { prop, def, onSave } = opts;
  const existing = document.getElementById('prop-override-modal');
  if (existing) existing.remove();

  const PRESET_LABELS = ['Single', 'Normal', 'Dense', 'Sprouting', 'Spread', 'Full'];
  const overlay = document.createElement('div');
  overlay.id = 'prop-override-modal';
  overlay.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.5);z-index:500;display:flex;align-items:center;justify-content:center;';

  const dialog = document.createElement('div');
  dialog.style.cssText = 'background:var(--bg-secondary);border:1px solid var(--border);border-radius:8px;padding:20px;min-width:360px;max-width:480px;color:var(--text-primary);display:flex;flex-direction:column;gap:12px;';

  const titleEl = document.createElement('div');
  // Show "P00001 — Blade Grass" when the PropDef is resolvable; fall
  // back to just the id for orphan refs. Makes the modal useful for
  // debugging placements without cross-referencing another panel.
  const displayName = def && typeof def.display_name === 'string' ? def.display_name : '';
  titleEl.textContent = displayName
    ? `Prop Overrides — ${prop.type} — ${displayName}`
    : `Prop Overrides — ${prop.type}`;
  titleEl.style.cssText = 'font-size:15px;font-weight:600;';
  dialog.appendChild(titleEl);

  const subtitle = document.createElement('div');
  subtitle.textContent = `sub-hex (${prop.sq ?? 0}, ${prop.sr ?? 0})`;
  subtitle.style.cssText = 'font-size:11px;color:var(--text-secondary);margin-top:-8px;';
  dialog.appendChild(subtitle);

  // --- Placement override ---
  const defPlacement = (def && def.placeable && typeof def.placeable.placement === 'number') ? def.placeable.placement : 0;
  const currPlacement = (typeof prop.placement_override === 'number' && prop.placement_override >= 0)
    ? prop.placement_override : -1;

  const placementRow = document.createElement('div');
  placementRow.style.cssText = 'display:flex;align-items:center;gap:8px;';
  const placementLabel = document.createElement('label');
  placementLabel.textContent = 'Placement';
  placementLabel.style.cssText = 'min-width:90px;font-size:12px;';
  const placementSelect = document.createElement('select');
  placementSelect.classList.add('prop-input');
  placementSelect.style.flex = '1';
  const inheritOpt = document.createElement('option');
  inheritOpt.value = '-1';
  inheritOpt.textContent = `Inherit (${PRESET_LABELS[defPlacement] || 'Single'})`;
  placementSelect.appendChild(inheritOpt);
  for (let i = 0; i < PRESET_LABELS.length; i++) {
    const opt = document.createElement('option');
    opt.value = String(i);
    opt.textContent = PRESET_LABELS[i];
    placementSelect.appendChild(opt);
  }
  placementSelect.value = String(currPlacement);
  placementRow.appendChild(placementLabel);
  placementRow.appendChild(placementSelect);
  dialog.appendChild(placementRow);

  // --- Variant / scale / rotation ---
  // Effective preset = override if set, else def default. Only SINGLE (0)
  // supports per-instance overrides for these three.
  const meshCount = (def && def.placeable && Array.isArray(def.placeable.meshes)) ? def.placeable.meshes.length : 0;

  const variantRow = document.createElement('div');
  variantRow.style.cssText = 'display:flex;align-items:center;gap:8px;';
  const variantLabel = document.createElement('label');
  variantLabel.textContent = 'Variant';
  variantLabel.style.cssText = 'min-width:90px;font-size:12px;';
  const variantSelect = document.createElement('select');
  variantSelect.classList.add('prop-input');
  variantSelect.style.flex = '1';
  const seededVariantOpt = document.createElement('option');
  seededVariantOpt.value = '-1';
  seededVariantOpt.textContent = 'Seeded (random)';
  variantSelect.appendChild(seededVariantOpt);
  for (let i = 0; i < meshCount; i++) {
    const opt = document.createElement('option');
    opt.value = String(i);
    opt.textContent = `Variant ${i + 1}`;
    variantSelect.appendChild(opt);
  }
  variantSelect.value = (typeof prop.variant_override === 'number' && prop.variant_override >= 0)
    ? String(prop.variant_override) : '-1';
  variantRow.appendChild(variantLabel);
  variantRow.appendChild(variantSelect);
  dialog.appendChild(variantRow);

  const scaleRow = document.createElement('div');
  scaleRow.style.cssText = 'display:flex;align-items:center;gap:8px;';
  const scaleLabel = document.createElement('label');
  scaleLabel.textContent = 'Scale';
  scaleLabel.style.cssText = 'min-width:90px;font-size:12px;';
  const scaleInput = document.createElement('input');
  scaleInput.type = 'number';
  scaleInput.step = '0.01';
  scaleInput.min = '0.01';
  scaleInput.max = '10';
  scaleInput.placeholder = 'Seeded';
  scaleInput.classList.add('prop-input');
  scaleInput.style.flex = '1';
  if (typeof prop.scale_override === 'number' && prop.scale_override > 0) {
    scaleInput.value = String(prop.scale_override);
  }
  scaleRow.appendChild(scaleLabel);
  scaleRow.appendChild(scaleInput);
  dialog.appendChild(scaleRow);

  const rotationRow = document.createElement('div');
  rotationRow.style.cssText = 'display:flex;align-items:center;gap:8px;';
  const rotationLabel = document.createElement('label');
  rotationLabel.textContent = 'Rotation °';
  rotationLabel.style.cssText = 'min-width:90px;font-size:12px;';
  const rotationInput = document.createElement('input');
  rotationInput.type = 'number';
  rotationInput.step = '1';
  rotationInput.min = '0';
  rotationInput.max = '359';
  rotationInput.placeholder = 'Seeded';
  rotationInput.classList.add('prop-input');
  rotationInput.style.flex = '1';
  if (typeof prop.rotation_override === 'number' && prop.rotation_override >= 0) {
    rotationInput.value = String(prop.rotation_override);
  }
  rotationRow.appendChild(rotationLabel);
  rotationRow.appendChild(rotationInput);
  dialog.appendChild(rotationRow);

  const hint = document.createElement('div');
  hint.classList.add('prop-hint');
  hint.style.fontSize = '11px';
  dialog.appendChild(hint);

  // --- Enable/disable variant/scale/rotation based on effective preset ---
  // Critically, we DO NOT clear the inputs when disabling — the user
  // may have authored overrides under SINGLE previously, and wiping
  // them while merely browsing a scatter preset would silently lose
  // that data on Apply. Instead we disable editing and preserve the
  // values. Use Reset to clear explicitly.
  const _refreshEnabled = () => {
    const effective = parseInt(placementSelect.value, 10) >= 0
      ? parseInt(placementSelect.value, 10) : defPlacement;
    const isSingle = effective === 0;
    variantSelect.disabled = !isSingle;
    scaleInput.disabled = !isSingle;
    rotationInput.disabled = !isSingle;
    if (!isSingle) {
      hint.textContent = `Scatter preset (${PRESET_LABELS[effective]}) renders procedurally — variant / scale / rotation are ignored by the engine under this preset but preserved on save. Switch to Single to pin specific values, or Reset to clear.`;
    } else {
      hint.textContent = 'Leave variant/scale/rotation empty to use seeded defaults.';
    }
  };
  placementSelect.addEventListener('change', _refreshEnabled);
  _refreshEnabled();

  // --- Buttons ---
  const btnRow = document.createElement('div');
  btnRow.style.cssText = 'display:flex;justify-content:space-between;gap:8px;margin-top:4px;';

  const btnReset = document.createElement('button');
  btnReset.textContent = 'Reset';
  btnReset.classList.add('prop-btn');
  btnReset.addEventListener('click', () => {
    placementSelect.value = '-1';
    variantSelect.value = '-1';
    scaleInput.value = '';
    rotationInput.value = '';
    _refreshEnabled();
  });

  const rightRow = document.createElement('div');
  rightRow.style.cssText = 'display:flex;gap:8px;';
  const btnCancel = document.createElement('button');
  btnCancel.textContent = 'Cancel';
  btnCancel.classList.add('prop-btn');
  const btnOk = document.createElement('button');
  btnOk.textContent = 'Apply';
  btnOk.classList.add('prop-btn-primary');
  rightRow.appendChild(btnCancel);
  rightRow.appendChild(btnOk);

  btnRow.appendChild(btnReset);
  btnRow.appendChild(rightRow);
  dialog.appendChild(btnRow);

  const cleanup = () => {
    overlay.remove();
    document.removeEventListener('keydown', keyHandler);
  };
  const keyHandler = (e) => {
    if (e.key === 'Escape') cleanup();
    else if (e.key === 'Enter' && e.target !== scaleInput && e.target !== rotationInput) {
      e.preventDefault();
      _commit();
    }
  };

  const _commit = () => {
    const placementVal = parseInt(placementSelect.value, 10);
    const variantVal = parseInt(variantSelect.value, 10);
    const scaleStr = scaleInput.value.trim();
    const rotationStr = rotationInput.value.trim();
    const overrides = {
      placement_override: Number.isFinite(placementVal) ? placementVal : -1,
      variant_override: Number.isFinite(variantVal) ? variantVal : -1,
      scale_override: scaleStr === '' ? -1 : parseFloat(scaleStr),
      rotation_override: rotationStr === '' ? -1 : parseFloat(rotationStr),
    };
    if (!Number.isFinite(overrides.scale_override) || overrides.scale_override <= 0) {
      overrides.scale_override = -1;
    }
    if (!Number.isFinite(overrides.rotation_override) || overrides.rotation_override < 0) {
      overrides.rotation_override = -1;
    }
    cleanup();
    onSave(overrides);
  };

  btnCancel.addEventListener('click', cleanup);
  btnOk.addEventListener('click', _commit);
  document.addEventListener('keydown', keyHandler);

  overlay.appendChild(dialog);
  document.body.appendChild(overlay);
  placementSelect.focus();
}

// ============================================================
// HexInspector — Right sidebar panel (replaces PropDetailPanel)
// ============================================================

export class HexInspector {
  /**
   * @param {HTMLElement} container - The #sidebar element
   * @param {import('./hex-grid.js').HexGrid} grid
   * @param {import('./commands.js').CommandHistory} cmdHistory
   * @param {Map<string, string>} biomeColorMap
   */
  constructor(container, grid, cmdHistory, biomeColorMap) {
    this.container = container;
    this.grid = grid;
    this.commandHistory = cmdHistory;
    this.biomeColorMap = biomeColorMap;
    this.mapStatsEl = container.querySelector('#map-stats-content');
    this.hexInfoEl = container.querySelector('#hex-info-content');
    this.propEditorEl = container.querySelector('#prop-editor-content');
    /** @type {function():void|null} Callback for Regenerate button */
    this.onRegenerate = null;
    /** @type {{ q: number, r: number }|null} */
    this.currentHex = null;
  }

  /**
   * Update map-level statistics in the top section.
   * @returns {void}
   */
  updateMapStats() {
    if (!this.mapStatsEl) return;
    // Clear previous content
    while (this.mapStatsEl.firstChild) {
      this.mapStatsEl.removeChild(this.mapStatsEl.firstChild);
    }

    const tiles = this.grid.tiles;
    const totalHexes = tiles.size;

    if (totalHexes === 0) {
      const empty = document.createElement('span');
      empty.className = 'text-muted';
      empty.textContent = 'No tiles loaded';
      this.mapStatsEl.appendChild(empty);
      return;
    }

    let minQ = Infinity, maxQ = -Infinity;
    let minR = Infinity, maxR = -Infinity;
    /** @type {Map<string, number>} */
    const biomeCounts = new Map();

    for (const [key, tile] of tiles) {
      const parts = key.split(',');
      const q = parseInt(parts[0], 10);
      const r = parseInt(parts[1], 10);
      if (q < minQ) minQ = q;
      if (q > maxQ) maxQ = q;
      if (r < minR) minR = r;
      if (r > maxR) maxR = r;
      const biome = tile.biome || '(none)';
      biomeCounts.set(biome, (biomeCounts.get(biome) || 0) + 1);
    }

    // Editable map identity (chapter_id and name)
    this.mapStatsEl.appendChild(this._createEditableStatRow('Map ID', this.grid.meta.chapter_id || '', (value) => {
      this.grid.meta.chapter_id = value;
      if (this.onMapMetaChange) this.onMapMetaChange();
    }));
    this.mapStatsEl.appendChild(this._createEditableStatRow('Name', this.grid.meta.name || '', (value) => {
      this.grid.meta.name = value;
      if (this.onMapMetaChange) this.onMapMetaChange();
    }));
    // Total hexes
    this.mapStatsEl.appendChild(this._createStatRow('Total hexes', String(totalHexes)));
    // Q range with distance in meters (each hex = 6m)
    const qSpan = (maxQ - minQ + 1) * 6;
    this.mapStatsEl.appendChild(this._createStatRow('Q range', `${minQ} to ${maxQ} (${qSpan}m)`));
    // R range with distance in meters
    const rSpan = (maxR - minR + 1) * 6;
    this.mapStatsEl.appendChild(this._createStatRow('R range', `${minR} to ${maxR} (${rSpan}m)`));

    // Biome distribution header
    const biomeHeader = document.createElement('div');
    biomeHeader.style.cssText = 'margin-top:6px;margin-bottom:2px;font-size:11px;color:var(--text-secondary);';
    biomeHeader.textContent = 'Biome distribution:';
    this.mapStatsEl.appendChild(biomeHeader);

    // Sort biomes by count descending
    const sorted = [...biomeCounts.entries()].sort((a, b) => b[1] - a[1]);
    for (const [biome, count] of sorted) {
      const row = document.createElement('div');
      row.className = 'biome-stat-row';

      const swatch = document.createElement('span');
      swatch.className = 'biome-swatch';
      swatch.style.backgroundColor = this.biomeColorMap.get(biome) || '#888';
      swatch.style.borderRadius = '2px';
      swatch.style.border = '1px solid var(--border)';
      row.appendChild(swatch);

      const label = document.createElement('span');
      label.textContent = `${biome}: ${count}`;
      row.appendChild(label);

      this.mapStatsEl.appendChild(row);
    }

    // Generator params (if this map was procedurally generated)
    const gen = this.grid.meta.generator;
    if (gen) {
      const genHeader = document.createElement('div');
      genHeader.style.cssText = 'margin-top:8px;margin-bottom:4px;font-size:11px;color:var(--text-secondary);border-top:1px solid var(--border);padding-top:6px;';
      genHeader.textContent = 'Generator params:';
      this.mapStatsEl.appendChild(genHeader);

      // Editable generator param fields — changes write back to grid.meta.generator
      // Each field has [label, key, type, min, max] for safe clamping.
      const editableParams = [
        ['Seed', 'seed', 'int', -2147483648, 2147483647],
        ['Radius', 'radius', 'int', 1, 500],
        ['Frequency', 'frequency', 'float', 0.02, 0.15],
        ['Domain Warp', 'warpStrength', 'float', 0, 2],
        ['Peak Height', 'peakHeight', 'int', 50, 500],
        ['Redistribution', 'redistPower', 'float', 0.5, 5],
        ['Erosion Drops', 'erosionDrops', 'int', 0, 500000],
        ['Erosion Steps', 'erosionSteps', 'int', 1, 100],
        ['River Sensitivity', 'riverThreshold', 'int', 3, 100],
        ['Moisture Falloff', 'moistureFalloff', 'float', 0.1, 0.99],
        ['Crash Radius', 'crashRadius', 'int', 0, 10],
      ];

      for (const [label, key, type, lo, hi] of editableParams) {
        if (gen[key] == null) continue;
        const display = type === 'float' ? String(gen[key]) : String(Math.round(gen[key]));
        this.mapStatsEl.appendChild(this._createEditableStatRow(label, display, (value) => {
          const raw = type === 'float' ? parseFloat(value) : parseInt(value, 10);
          if (!Number.isFinite(raw)) return;
          const clamped = Math.min(hi, Math.max(lo, type === 'int' ? Math.round(raw) : raw));
          gen[key] = clamped;
          if (this.onMapMetaChange) this.onMapMetaChange();
        }));
      }

      if (this.onRegenerate) {
        const btn = document.createElement('button');
        btn.textContent = 'Regenerate';
        btn.classList.add('prop-btn-primary');
        btn.style.cssText = 'margin-top:6px;width:100%;';
        btn.addEventListener('click', () => this.onRegenerate());
        this.mapStatsEl.appendChild(btn);
      }
    }
  }

  /**
   * Update when hovering a hex. Called on every mousemove from canvas.
   * @param {{ q: number, r: number }|null} hex
   * @param {{ q: number, r: number }|null} subHex
   * @returns {void}
   */
  updateHex(hex, subHex) {
    if (!hex) {
      this.currentHex = null;
      this._clearEl(this.hexInfoEl);
      const muted = document.createElement('span');
      muted.className = 'text-muted';
      muted.textContent = 'Hover a hex to inspect';
      if (this.hexInfoEl) this.hexInfoEl.appendChild(muted);
      this._clearEl(this.propEditorEl);
      return;
    }

    this.currentHex = { q: hex.q, r: hex.r };

    this._renderHexInfo(hex.q, hex.r);
    this._renderPropEditor(hex.q, hex.r);
  }

  /**
   * Force re-render the current hex (e.g. after editing a prop).
   * @returns {void}
   */
  _refreshCurrentHex() {
    if (!this.currentHex) return;
    const { q, r } = this.currentHex;
    this._renderHexInfo(q, r);
    this._renderPropEditor(q, r);
  }

  /**
   * Render hex details in the middle section.
   * @param {number} q
   * @param {number} r
   * @returns {void}
   */
  _renderHexInfo(q, r) {
    this._clearEl(this.hexInfoEl);
    if (!this.hexInfoEl) return;

    const tile = this.grid.getTile(q, r);

    // Coordinates
    const coordRow = document.createElement('div');
    coordRow.className = 'hex-info-row';
    const coordLabel = document.createElement('span');
    coordLabel.textContent = `Coordinates: (${q}, ${r})`;
    coordRow.appendChild(coordLabel);
    this.hexInfoEl.appendChild(coordRow);

    if (!tile) {
      const ghostNote = document.createElement('div');
      ghostNote.className = 'hex-info-row';
      const ghostSpan = document.createElement('span');
      ghostSpan.className = 'text-muted';
      ghostSpan.textContent = 'Empty (ghost cell)';
      ghostNote.appendChild(ghostSpan);
      this.hexInfoEl.appendChild(ghostNote);
      return;
    }

    // Biome with color swatch
    const biomeRow = document.createElement('div');
    biomeRow.className = 'hex-info-row';
    const biomeSwatch = document.createElement('span');
    biomeSwatch.className = 'biome-swatch';
    biomeSwatch.style.backgroundColor = this.biomeColorMap.get(tile.biome) || '#888';
    biomeSwatch.style.borderRadius = '3px';
    biomeSwatch.style.border = '1px solid var(--border)';
    biomeRow.appendChild(biomeSwatch);
    const biomeText = document.createElement('span');
    biomeText.textContent = `Biome: ${tile.biome || '(none)'}`;
    biomeRow.appendChild(biomeText);
    this.hexInfoEl.appendChild(biomeRow);

    // Elevation
    const elevRow = document.createElement('div');
    elevRow.className = 'hex-info-row';
    const elevText = document.createElement('span');
    elevText.textContent = `Elevation: ${tile.elevation}`;
    elevRow.appendChild(elevText);
    this.hexInfoEl.appendChild(elevRow);

    // Hazard Level — only surfaced when the tile's biome has a hazard
    // cap OR the tile already carries a non-zero level. For thermally
    // neutral biomes (no hazard) we stay out of the UI to avoid
    // confusing the user with a setting that has no effect. The
    // on-disk field is still `temperature` (data contract), but the
    // label says "Hazard Level" because the value drives heat, cold,
    // oxygen drain, and any future damage_type.
    const hazard = _getBiomeHazard(tile.biome);
    const showTemp = hazard || (typeof tile.temperature === 'number' && tile.temperature !== 0);
    if (showTemp) {
      const tempRow = document.createElement('div');
      tempRow.className = 'hex-info-row';
      tempRow.style.cssText = 'display:flex;align-items:center;gap:6px;';
      const label = document.createElement('span');
      const capLen = hazard && Array.isArray(hazard.health_damage) ? hazard.health_damage.length : 0;
      const hint = hazard ? ` (${hazard.damage_type}, 0-${capLen})` : '';
      label.textContent = `Hazard Level${hint}:`;
      const input = document.createElement('input');
      input.type = 'number';
      input.min = '0';
      input.max = '99';
      input.step = '1';
      input.className = 'prop-input';
      input.style.cssText = 'width:60px;';
      input.value = String(tile.temperature | 0);
      input.addEventListener('change', () => {
        const next = Math.max(0, Math.min(99, parseInt(input.value, 10) || 0));
        const current = tile.temperature | 0;
        if (next === current) return;
        const cmd = new SetTemperatureCommand(this.grid, q, r, current, next);
        if (this.commandHistory) this.commandHistory.execute(cmd);
        else cmd.execute();
        this._renderHexInfo(q, r);
      });
      tempRow.appendChild(label);
      tempRow.appendChild(input);
      this.hexInfoEl.appendChild(tempRow);
    }

    // Water level — only for water tiles (also shows in inspector for
    // existing Water biomes, and now Shoreline-on-waterline edge cases
    // where an author explicitly set waterLevel).
    if (typeof tile.waterLevel === 'number') {
      const wlRow = document.createElement('div');
      wlRow.className = 'hex-info-row';
      const wlText = document.createElement('span');
      const depth = tile.waterLevel - tile.elevation;
      wlText.textContent = `Water level: ${tile.waterLevel}  (depth ${depth})`;
      wlRow.appendChild(wlText);
      this.hexInfoEl.appendChild(wlRow);
    }

    // Prop summary
    if (tile.props && tile.props.length > 0) {
      const propSummary = document.createElement('div');
      propSummary.className = 'hex-info-row';
      const propText = document.createElement('span');
      propText.textContent = `Props: ${tile.props.length}`;
      propSummary.appendChild(propText);
      this.hexInfoEl.appendChild(propSummary);
    }
  }

  /**
   * Render the prop editor in the bottom section.
   * @param {number} q
   * @param {number} r
   * @returns {void}
   */
  _renderPropEditor(q, r) {
    this._clearEl(this.propEditorEl);
    if (!this.propEditorEl) return;

    const tile = this.grid.getTile(q, r);
    if (!tile || !tile.props || tile.props.length === 0) {
      const empty = document.createElement('span');
      empty.className = 'text-muted';
      empty.textContent = 'No props on this hex';
      this.propEditorEl.appendChild(empty);
      return;
    }

    tile.props.forEach((prop, index) => {
      this.propEditorEl.appendChild(this._renderPropCard(prop, index, q, r, tile));
    });
  }

  /**
   * Render a single editable prop card.
   * @param {Object} prop
   * @param {number} index
   * @param {number} q
   * @param {number} r
   * @param {Object} tile
   * @returns {HTMLElement}
   */
  _renderPropCard(prop, index, q, r, tile) {
    const card = document.createElement('div');
    card.className = 'prop-card';

    // Type label with category badge (safe DOM — no innerHTML)
    const header = document.createElement('div');
    header.className = 'prop-card-header';
    const catColors = CATEGORY_COLORS[prop.category] || CATEGORY_COLORS.plant;
    const typeSpan = document.createElement('span');
    typeSpan.style.cssText = `color:${catColors.badge};font-weight:600;font-size:12px;`;
    typeSpan.textContent = String(prop.type);
    const categorySpan = document.createElement('span');
    categorySpan.style.cssText = 'color:var(--text-secondary);font-size:10px;';
    categorySpan.textContent = ` [${String(prop.category)}]`;
    header.appendChild(typeSpan);
    header.appendChild(categorySpan);
    card.appendChild(header);

    // Build fields based on category
    const fields = [
      { name: 'sq', value: prop.sq, min: -2, max: 2, step: 1 },
      { name: 'sr', value: prop.sr, min: -2, max: 2, step: 1 },
    ];

    fields.push({ name: 'rotation', value: prop.rotation || 0, min: 0, max: 359, step: 1 });

    const fieldsRow = document.createElement('div');
    fieldsRow.className = 'prop-card-fields';

    for (const field of fields) {
      const label = document.createElement('label');
      label.textContent = field.name + ':';
      const input = document.createElement('input');
      input.type = 'number';
      input.value = String(Math.round(field.value));
      input.min = String(field.min);
      input.max = String(field.max);
      input.step = String(field.step);
      input.dataset.propIndex = String(index);
      input.dataset.field = field.name;
      input.classList.add('prop-input');

      const origValue = field.value;
      const handleChange = () => {
        const newVal = parseInt(input.value, 10);
        if (isNaN(newVal)) return;
        const clamped = Math.max(field.min, Math.min(field.max, newVal));

        // Validate sub-hex position when sq or sr changes
        if (field.name === 'sq' || field.name === 'sr') {
          const testSq = field.name === 'sq' ? clamped : prop.sq;
          const testSr = field.name === 'sr' ? clamped : prop.sr;
          if (!HexMath.isValidSubHex(testSq, testSr)) return;
        }

        if (clamped === origValue) return;
        const oldValues = { [field.name]: origValue };
        const newValues = { [field.name]: clamped };
        const cmd = new EditPropCommand(this.grid, q, r, index, oldValues, newValues);
        this.commandHistory.execute(cmd);
        this._refreshCurrentHex();
      };

      input.addEventListener('blur', handleChange);
      input.addEventListener('keydown', (e) => { if (e.key === 'Enter') handleChange(); });
      label.appendChild(input);
      fieldsRow.appendChild(label);
    }

    // Delete button
    const delBtn = document.createElement('button');
    delBtn.className = 'prop-delete-btn';
    delBtn.textContent = 'X';
    delBtn.title = 'Delete prop';
    delBtn.addEventListener('click', () => {
      const removed = tile.props[index];
      const cmd = new DeletePropCommand(this.grid, q, r, index, removed);
      this.commandHistory.execute(cmd);
      this._refreshCurrentHex();
    });
    fieldsRow.appendChild(delBtn);

    card.appendChild(fieldsRow);

    // Show origin
    if (prop.origin) {
      const originRow = document.createElement('div');
      originRow.className = 'prop-card-fields';
      const originLabel = document.createElement('label');
      originLabel.style.cssText = 'font-size:11px;color:var(--text-secondary);';
      originLabel.textContent = 'Origin: ' + String(prop.origin);
      originRow.appendChild(originLabel);
      card.appendChild(originRow);
    }

    // Footprint display for structures
    if (prop.category === 'structure' && prop.footprint) {
      const fpLabel = document.createElement('div');
      fpLabel.className = 'prop-footprint';
      fpLabel.textContent = 'Footprint: ' + prop.footprint.map(f => `(${f.q},${f.r})`).join(' ');
      card.appendChild(fpLabel);
    }

    return card;
  }

  /**
   * Create a stat row with label and value.
   * @param {string} label
   * @param {string} value
   * @returns {HTMLElement}
   */
  _createStatRow(label, value) {
    const row = document.createElement('div');
    row.className = 'stat-row';
    const labelEl = document.createElement('span');
    labelEl.className = 'stat-label';
    labelEl.textContent = label;
    const valueEl = document.createElement('span');
    valueEl.className = 'stat-value';
    valueEl.textContent = value;
    row.appendChild(labelEl);
    row.appendChild(valueEl);
    return row;
  }

  /**
   * Create a stat row with an editable text input.
   * @param {string} label
   * @param {string} value
   * @param {function(string):void} onChange - called with trimmed value on blur/Enter
   * @returns {HTMLElement}
   */
  _createEditableStatRow(label, value, onChange) {
    const row = document.createElement('div');
    row.className = 'stat-row';
    const labelEl = document.createElement('span');
    labelEl.className = 'stat-label';
    labelEl.textContent = label;
    const input = document.createElement('input');
    input.type = 'text';
    input.value = value;
    input.className = 'stat-input prop-input';
    input.style.cssText = 'flex:1;min-width:0;';
    /** @type {string} */
    let lastValue = value;
    const commit = () => {
      const trimmed = input.value.trim();
      if (trimmed !== lastValue) {
        lastValue = trimmed;
        onChange(trimmed);
      }
    };
    input.addEventListener('blur', commit);
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') { e.preventDefault(); input.blur(); }
      if (e.key === 'Escape') { input.value = lastValue; input.blur(); }
    });
    row.appendChild(labelEl);
    row.appendChild(input);
    return row;
  }

  /**
   * Clear all child nodes from an element safely.
   * @param {HTMLElement|null} el
   * @returns {void}
   */
  _clearEl(el) {
    if (!el) return;
    while (el.firstChild) {
      el.removeChild(el.firstChild);
    }
  }
}
