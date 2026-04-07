// ============================================================
// Inline Modal Dialog (task-010)
// ============================================================

import { EditPropCommand, DeletePropCommand } from './commands.js';
import { HexMath } from './hex-math.js';
import { CATEGORY_COLORS } from './hex-grid.js';

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
  input.style.cssText = 'width:100%;padding:6px 8px;border:1px solid var(--border);border-radius:4px;background:var(--bg-tertiary);color:var(--text-primary);font-size:14px;margin-bottom:12px;box-sizing:border-box;';

  const btnRow = document.createElement('div');
  btnRow.style.cssText = 'display:flex;justify-content:flex-end;gap:8px;';

  const btnCancel = document.createElement('button');
  btnCancel.textContent = 'Cancel';
  btnCancel.style.cssText = 'padding:6px 16px;border:1px solid var(--border);border-radius:4px;background:var(--bg-tertiary);color:var(--text-primary);cursor:pointer;';

  const btnOk = document.createElement('button');
  btnOk.textContent = 'OK';
  btnOk.style.cssText = 'padding:6px 16px;border:none;border-radius:4px;background:var(--accent);color:var(--bg-primary);cursor:pointer;font-weight:600;';

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
  titleEl.style.cssText = 'margin-bottom:10px;font-size:15px;font-weight:600;color:#ff9999;';
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
    msg.style.cssText = 'color:#ff9999;flex:1;word-break:break-word;';
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
  btnClose.style.cssText = 'padding:6px 16px;border:none;border-radius:4px;background:var(--accent);color:var(--bg-primary);cursor:pointer;font-weight:600;';

  const cleanup = () => overlay.remove();
  btnClose.addEventListener('click', cleanup);

  const keyHandler = (e) => {
    if (e.key === 'Escape') {
      cleanup();
      document.removeEventListener('keydown', keyHandler);
    }
  };
  document.addEventListener('keydown', keyHandler);

  btnRow.appendChild(btnClose);
  dialog.appendChild(btnRow);
  overlay.appendChild(dialog);
  document.body.appendChild(overlay);
  btnClose.focus();
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
    input.className = 'stat-input';
    input.style.cssText = 'flex:1;padding:1px 4px;border:1px solid var(--border);border-radius:3px;background:var(--bg-tertiary);color:var(--text-primary);font-size:11px;min-width:0;';
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
