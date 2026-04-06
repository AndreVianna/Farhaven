// ============================================================
// ResourceEditor — List View and Data Model (task-012)
// ============================================================

import { ProjectContext } from './file-discovery.js';

/**
 * Maps a parsed .tres ResourceDef to an editable JS model.
 * All fields mirror the ResourceDef GDScript class.
 */
export class ResourceDefModel {
  constructor() {
    /** @type {string} Filename stem e.g. 'wood' */
    this.id = '';
    /** @type {string} */
    this.display_name = '';
    /** @type {number} */
    this.gather_time = 0;
    /** @type {number} */
    this.gather_amount = 0;
    /** @type {string} */
    this.tool_required = '';
    /** @type {number} */
    this.respawn_time = 0;
    /** @type {string} */
    this.yield_type = '';
    /** @type {Object<string, number>} tool name -> speed multiplier */
    this.tool_speed = {};
    /** @type {number} */
    this.max_stack = 0;
    /** @type {string} */
    this.category = '';
    /** @type {string} */
    this.catalog_entry = '';
    /** @type {string} */
    this.catalog_category = '';
    /** @type {string} */
    this.placeholder_mesh_type = '';
    /** @type {Object<string, number>} */
    this.placeholder_params = {};
    /** @type {{r: number, g: number, b: number, a: number}} */
    this.placeholder_color = { r: 0, g: 0, b: 0, a: 1 };
    /** @type {string} */
    this.placeholder_depleted_type = '';
    /** @type {Object<string, number>} */
    this.placeholder_depleted_params = {};
    /** @type {{r: number, g: number, b: number, a: number}} */
    this.placeholder_depleted_color = { r: 0, g: 0, b: 0, a: 1 };
    // Round-trip metadata
    /** @type {string} */
    this._filename = '';
    /** @type {import('./tres-parser.js').TresFile|null} */
    this._raw = null;
  }

  /**
   * Create a ResourceDefModel from a ProjectContext resource entry.
   * @param {string} filename - e.g. 'wood.tres'
   * @param {{data: Object, raw: import('./tres-parser.js').TresFile}} entry
   * @returns {ResourceDefModel}
   */
  static fromEntry(filename, entry) {
    const model = new ResourceDefModel();
    model.id = filename.replace('.tres', '');
    model._filename = filename;
    model._raw = entry.raw;

    const d = entry.data;

    // Simple string fields (stored as stringname values in .tres, plain strings in data)
    model.display_name = _str(d.display_name);
    model.tool_required = _str(d.tool_required);
    model.yield_type = _str(d.yield_type);
    model.category = _str(d.category);
    model.catalog_entry = _str(d.catalog_entry);
    model.catalog_category = _str(d.catalog_category);
    model.placeholder_mesh_type = _str(d.placeholder_mesh_type);
    model.placeholder_depleted_type = _str(d.placeholder_depleted_type);

    // Numeric fields
    model.gather_time = _num(d.gather_time);
    model.gather_amount = _num(d.gather_amount);
    model.respawn_time = _num(d.respawn_time);
    model.max_stack = _num(d.max_stack);

    // Dict fields (TresParser stores as Map<string, TresValue>)
    model.tool_speed = _dictToObj(d.tool_speed);
    model.placeholder_params = _dictToObj(d.placeholder_params);
    model.placeholder_depleted_params = _dictToObj(d.placeholder_depleted_params);

    // Color fields (TresParser stores as {r, g, b, a})
    model.placeholder_color = _color(d.placeholder_color);
    model.placeholder_depleted_color = _color(d.placeholder_depleted_color);

    return model;
  }

  /**
   * Get placeholder_color as a CSS hex string (e.g. '#33b233').
   * @returns {string}
   */
  get colorHex() {
    const c = this.placeholder_color;
    const r = Math.round((c.r || 0) * 255);
    const g = Math.round((c.g || 0) * 255);
    const b = Math.round((c.b || 0) * 255);
    return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
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
 * Convert a TresParser dict Map<string, TresValue> to a plain object of primitives.
 * @param {*} val - Expected to be a Map from TresParser dict parsing
 * @returns {Object<string, number|string>}
 */
function _dictToObj(val) {
  if (!(val instanceof Map)) return {};
  const obj = {};
  for (const [key, tv] of val) {
    // TresValue objects have .value; plain values used as-is
    obj[key] = tv && typeof tv === 'object' && 'value' in tv ? tv.value : tv;
  }
  return obj;
}

/**
 * Safely extract a color value.
 * @param {*} val - Expected to be {r, g, b, a}
 * @returns {{r: number, g: number, b: number, a: number}}
 */
function _color(val) {
  if (val && typeof val === 'object' && 'r' in val) {
    return { r: val.r || 0, g: val.g || 0, b: val.b || 0, a: val.a != null ? val.a : 1 };
  }
  return { r: 0, g: 0, b: 0, a: 1 };
}

// ============================================================
// List View Rendering
// ============================================================

/**
 * Render the resource list view into the Resources tab panel.
 * @param {HTMLElement} container - The #tab-resources element
 * @returns {void}
 */
export function renderResourceList(container) {
  container.innerHTML = '';

  // Header bar with title and New Resource button
  const header = document.createElement('div');
  header.style.cssText = 'display:flex;justify-content:space-between;align-items:center;padding:8px 12px;';
  const title = document.createElement('h3');
  title.textContent = 'Resources';
  title.style.cssText = 'margin:0;font-size:16px;color:var(--text-primary);';
  const newBtn = document.createElement('button');
  newBtn.textContent = '+ New Resource';
  newBtn.style.cssText = 'padding:4px 12px;background:var(--accent);color:var(--bg-primary);border:none;border-radius:4px;cursor:pointer;font-size:12px;font-weight:600;';
  newBtn.addEventListener('click', () => {
    // TODO: navigate to new resource form (task-013)
    console.log('New Resource clicked');
  });
  header.appendChild(title);
  header.appendChild(newBtn);
  container.appendChild(header);

  // Build sorted list of resource models
  /** @type {ResourceDefModel[]} */
  const resources = [];
  for (const [filename, entry] of ProjectContext.files.resources) {
    resources.push(ResourceDefModel.fromEntry(filename, entry));
  }
  resources.sort((a, b) => a.id.localeCompare(b.id));

  // Empty state
  if (resources.length === 0) {
    const empty = document.createElement('div');
    empty.textContent = 'No resources found. Open a project folder to load resource definitions.';
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
  const columns = ['Color', 'ID', 'Display Name', 'Category', 'Gather Time'];
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
  for (const model of resources) {
    const row = document.createElement('tr');
    row.style.cssText = 'cursor:pointer;';
    row.addEventListener('mouseenter', () => { row.style.background = 'var(--bg-tertiary)'; });
    row.addEventListener('mouseleave', () => { row.style.background = ''; });
    row.addEventListener('click', () => {
      // TODO: navigate to edit form (task-013)
      console.log('Edit resource:', model.id);
    });

    // Color swatch
    const tdColor = document.createElement('td');
    tdColor.style.cssText = 'padding:6px 8px;';
    const swatch = document.createElement('div');
    swatch.style.cssText = `width:16px;height:16px;border-radius:2px;border:1px solid var(--border);background:${model.colorHex};`;
    tdColor.appendChild(swatch);
    row.appendChild(tdColor);

    // ID
    const tdId = document.createElement('td');
    tdId.textContent = model.id;
    tdId.style.cssText = 'padding:6px 8px;color:var(--accent);font-weight:600;';
    row.appendChild(tdId);

    // Display name
    const tdName = document.createElement('td');
    tdName.textContent = model.display_name;
    tdName.style.cssText = 'padding:6px 8px;';
    row.appendChild(tdName);

    // Category
    const tdCat = document.createElement('td');
    tdCat.textContent = model.category;
    tdCat.style.cssText = 'padding:6px 8px;color:var(--text-secondary);';
    row.appendChild(tdCat);

    // Gather time
    const tdGather = document.createElement('td');
    tdGather.textContent = model.gather_time > 0 ? `${model.gather_time}s` : '-';
    tdGather.style.cssText = 'padding:6px 8px;color:var(--text-secondary);';
    row.appendChild(tdGather);

    tbody.appendChild(row);
  }
  table.appendChild(tbody);
  container.appendChild(table);
}
