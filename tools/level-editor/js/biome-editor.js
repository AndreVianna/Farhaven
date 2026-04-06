// ============================================================
// BiomeEditor — List View and Data Model (task-014)
// ============================================================

import { ProjectContext } from './file-discovery.js';

/** @type {Set<string>} Biome IDs recognized by the game MapLoader */
const KNOWN_BIOMES = new Set(['crash_site', 'grassland', 'forest', 'rocky', 'water']);

/**
 * Maps a parsed .tres BiomeData to an editable JS model.
 * All fields mirror the BiomeData GDScript class.
 */
export class BiomeDataModel {
  constructor() {
    /** @type {string} */
    this.biome_name = '';
    /** @type {{ min: number, max: number }} From Vector2i(min, max) */
    this.elevation_range = { min: 0, max: 9 };
    /** @type {Array<{ type: string, chance: number, min_amount: number, max_amount: number }>} */
    this.resource_table = [];
    /** @type {{ r: number, g: number, b: number, a: number }} */
    this.color = { r: 0, g: 0, b: 0, a: 1 };
    /** @type {Array<{ r: number, g: number, b: number, a: number }>} */
    this.color_variations = [];
    // Round-trip metadata
    /** @type {string} */
    this._filename = '';
    /** @type {import('./tres-parser.js').TresFile|null} */
    this._raw = null;
  }

  /** Filename stem as key (e.g., 'forest') */
  get id() {
    return this._filename.replace('.tres', '');
  }

  /**
   * Get base color as a CSS hex string (e.g. '#268026').
   * @returns {string}
   */
  get colorHex() {
    const c = this.color;
    const r = Math.round((c.r || 0) * 255);
    const g = Math.round((c.g || 0) * 255);
    const b = Math.round((c.b || 0) * 255);
    return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
  }

  /**
   * Create a BiomeDataModel from a ProjectContext biome entry.
   * @param {string} filename - e.g. 'forest.tres'
   * @param {{ data: Object, raw: import('./tres-parser.js').TresFile }} entry
   * @returns {BiomeDataModel}
   */
  static fromEntry(filename, entry) {
    const model = new BiomeDataModel();
    model._filename = filename;
    model._raw = entry.raw;
    const d = entry.data;

    model.biome_name = _str(d.biome_name);

    // elevation_range: TresParser stores Vector2i value as { x, y }
    if (d.elevation_range && typeof d.elevation_range === 'object') {
      model.elevation_range = {
        min: typeof d.elevation_range.x === 'number' ? d.elevation_range.x : 0,
        max: typeof d.elevation_range.y === 'number' ? d.elevation_range.y : 9,
      };
    }

    // resource_table: TresParser stores as TresValue[] (untyped array).
    // Each element is a TresValue { type: 'dict', value: Map<string, TresValue> }.
    if (Array.isArray(d.resource_table)) {
      model.resource_table = d.resource_table.map(tv => {
        // Each tv is a TresValue with type 'dict' and value as Map<string, TresValue>
        if (tv && tv.type === 'dict' && tv.value instanceof Map) {
          return _dictEntryToResourceRow(tv.value);
        }
        // Fallback: plain object (shouldn't happen, but handle gracefully)
        if (tv && typeof tv === 'object' && 'type' in tv && typeof tv.type === 'string' && tv.type !== 'dict') {
          // It's a TresValue of another type — skip
          return { type: '', chance: 0, min_amount: 0, max_amount: 0 };
        }
        // Plain object fallback
        return {
          type: _str(tv.type),
          chance: _num(tv.chance),
          min_amount: _num(tv.min_amount),
          max_amount: _num(tv.max_amount),
        };
      });
    }

    // color: TresParser stores Color value as { r, g, b, a }
    if (d.color && typeof d.color === 'object' && 'r' in d.color) {
      model.color = { r: d.color.r || 0, g: d.color.g || 0, b: d.color.b || 0, a: d.color.a != null ? d.color.a : 1 };
    }

    // color_variations: TresParser stores as TresValue[] of color TresValues.
    // Each element is { type: 'color', value: { r, g, b, a } }.
    if (Array.isArray(d.color_variations)) {
      model.color_variations = d.color_variations.map(tv => {
        // TresValue color: { type: 'color', value: { r, g, b, a } }
        if (tv && tv.type === 'color' && tv.value && typeof tv.value === 'object') {
          return { r: tv.value.r || 0, g: tv.value.g || 0, b: tv.value.b || 0, a: tv.value.a != null ? tv.value.a : 1 };
        }
        // Plain color object fallback
        if (tv && typeof tv === 'object' && 'r' in tv) {
          return { r: tv.r || 0, g: tv.g || 0, b: tv.b || 0, a: tv.a != null ? tv.a : 1 };
        }
        return { r: 0, g: 0, b: 0, a: 1 };
      });
    }

    return model;
  }
}

// ============================================================
// Internal Helpers
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
 * Safely extract a numeric value, handling undefined/null.
 * @param {*} val
 * @returns {number}
 */
function _num(val) {
  if (typeof val === 'number') return val;
  return 0;
}

/**
 * Convert a dict Map<string, TresValue> to a resource table row.
 * @param {Map<string, *>} map - Map of key -> TresValue
 * @returns {{ type: string, chance: number, min_amount: number, max_amount: number }}
 */
function _dictEntryToResourceRow(map) {
  return {
    type: _tvStr(map.get('type')),
    chance: _tvNum(map.get('chance')),
    min_amount: _tvNum(map.get('min_amount')),
    max_amount: _tvNum(map.get('max_amount')),
  };
}

/**
 * Extract string from a TresValue or plain value.
 * @param {*} tv - TresValue { type, value } or plain value
 * @returns {string}
 */
function _tvStr(tv) {
  if (tv == null) return '';
  if (tv && typeof tv === 'object' && 'value' in tv) return _str(tv.value);
  return _str(tv);
}

/**
 * Extract number from a TresValue or plain value.
 * @param {*} tv - TresValue { type, value } or plain value
 * @returns {number}
 */
function _tvNum(tv) {
  if (tv == null) return 0;
  if (tv && typeof tv === 'object' && 'value' in tv) return _num(tv.value);
  return _num(tv);
}

// ============================================================
// List View Rendering
// ============================================================

/**
 * Render the biome list view into the Biomes tab panel.
 * @param {HTMLElement} container - The #tab-biomes element
 * @returns {void}
 */
export function renderBiomeList(container) {
  container.innerHTML = '';

  // Header bar with title and New Biome button
  const header = document.createElement('div');
  header.style.cssText = 'display:flex;justify-content:space-between;align-items:center;padding:8px 12px;';
  const title = document.createElement('h3');
  title.textContent = 'Biomes';
  title.style.cssText = 'margin:0;font-size:16px;color:var(--text-primary);';
  const newBtn = document.createElement('button');
  newBtn.textContent = '+ New Biome';
  newBtn.style.cssText = 'padding:4px 12px;background:var(--accent);color:var(--bg-primary);border:none;border-radius:4px;cursor:pointer;font-size:12px;font-weight:600;';
  newBtn.addEventListener('click', () => {
    // TODO: navigate to new biome form (task-015)
    console.log('New Biome clicked');
  });
  header.appendChild(title);
  header.appendChild(newBtn);
  container.appendChild(header);

  // Build sorted list of biome models
  /** @type {BiomeDataModel[]} */
  const biomes = [];
  for (const [filename, entry] of ProjectContext.files.biomes) {
    biomes.push(BiomeDataModel.fromEntry(filename, entry));
  }
  biomes.sort((a, b) => a.biome_name.localeCompare(b.biome_name));

  // Empty state
  if (biomes.length === 0) {
    const empty = document.createElement('div');
    empty.textContent = 'No biomes found. Open a project folder to load biome definitions.';
    empty.style.cssText = 'padding:12px;color:var(--text-secondary);font-size:13px;';
    container.appendChild(empty);
    return;
  }

  // Table
  const table = document.createElement('table');
  table.style.cssText = 'width:100%;border-collapse:collapse;font-size:12px;';

  // Header row
  const thead = document.createElement('thead');
  const headerRow = document.createElement('tr');
  /** @type {string[]} */
  const columns = ['Color', 'Biome Name', 'Elevation Range', 'Resources'];
  for (const col of columns) {
    const th = document.createElement('th');
    th.textContent = col;
    th.style.cssText = 'text-align:left;padding:6px 8px;border-bottom:1px solid var(--border);color:var(--text-secondary);font-weight:600;';
    headerRow.appendChild(th);
  }
  thead.appendChild(headerRow);
  table.appendChild(thead);

  // Data rows
  const tbody = document.createElement('tbody');
  for (const model of biomes) {
    const row = document.createElement('tr');
    row.style.cssText = 'cursor:pointer;';
    row.addEventListener('mouseenter', () => { row.style.background = 'var(--bg-tertiary)'; });
    row.addEventListener('mouseleave', () => { row.style.background = ''; });
    row.addEventListener('click', () => {
      // TODO: navigate to edit form (task-015)
      console.log('Edit biome:', model.id);
    });

    // Color swatch
    const tdColor = document.createElement('td');
    tdColor.style.cssText = 'padding:6px 8px;';
    const swatch = document.createElement('div');
    swatch.style.cssText = `width:16px;height:16px;border-radius:2px;border:1px solid var(--border);background:${model.colorHex};`;
    tdColor.appendChild(swatch);
    row.appendChild(tdColor);

    // Biome Name (with warning badge for custom biomes)
    const tdName = document.createElement('td');
    tdName.style.cssText = 'padding:6px 8px;color:var(--accent);font-weight:600;';
    const nameSpan = document.createElement('span');
    nameSpan.textContent = model.biome_name;
    tdName.appendChild(nameSpan);

    if (!KNOWN_BIOMES.has(model.id)) {
      const warn = document.createElement('span');
      warn.textContent = ' !';
      warn.title = 'Custom biome \u2014 not recognized by game MapLoader';
      warn.style.cssText = 'color:var(--warning, #f0ad4e);font-weight:700;margin-left:4px;cursor:help;';
      tdName.appendChild(warn);
    }
    row.appendChild(tdName);

    // Elevation Range
    const tdElev = document.createElement('td');
    tdElev.textContent = `${model.elevation_range.min}\u2013${model.elevation_range.max}`;
    tdElev.style.cssText = 'padding:6px 8px;color:var(--text-secondary);';
    row.appendChild(tdElev);

    // Resources (count)
    const tdRes = document.createElement('td');
    tdRes.textContent = String(model.resource_table.length);
    tdRes.style.cssText = 'padding:6px 8px;color:var(--text-secondary);';
    row.appendChild(tdRes);

    tbody.appendChild(row);
  }
  table.appendChild(tbody);
  container.appendChild(table);
}
