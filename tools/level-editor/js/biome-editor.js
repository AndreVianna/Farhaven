// ============================================================
// BiomeEditor — List View, Edit Form, Commands (task-014/015)
// ============================================================

import { ProjectContext, FileDiscovery } from './file-discovery.js';
import { TresParser, TresFile, generateTresUid } from './tres-parser.js';
import { showInlineModal } from './panels.js';

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

/**
 * Convert an {r,g,b,a} color (0-1 floats) to a CSS hex string (#rrggbb).
 * @param {{r: number, g: number, b: number, a: number}} c
 * @returns {string}
 */
function _colorToHex(c) {
  const r = Math.round((c.r || 0) * 255);
  const g = Math.round((c.g || 0) * 255);
  const b = Math.round((c.b || 0) * 255);
  return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
}

/**
 * Convert a CSS hex string (#rrggbb) to an {r,g,b,a} color (0-1 floats).
 * @param {string} hex
 * @param {number} [alpha=1]
 * @returns {{r: number, g: number, b: number, a: number}}
 */
function _hexToColor(hex, alpha) {
  const h = hex.replace('#', '');
  return {
    r: parseInt(h.substring(0, 2), 16) / 255,
    g: parseInt(h.substring(2, 4), 16) / 255,
    b: parseInt(h.substring(4, 6), 16) / 255,
    a: alpha != null ? alpha : 1,
  };
}

/**
 * Convert a {r,g,b,a} color to a CSS rgb() string.
 * @param {{r: number, g: number, b: number, a: number}} c
 * @returns {string}
 */
function _colorToRgb(c) {
  return `rgb(${Math.round((c.r || 0) * 255)},${Math.round((c.g || 0) * 255)},${Math.round((c.b || 0) * 255)})`;
}

// ============================================================
// List View Rendering
// ============================================================

/**
 * Render the biome list view into the Biomes tab panel.
 * @param {HTMLElement} container - The #tab-biomes element
 * @param {Object} [options] - Options object
 * @param {import('./commands.js').CommandHistory} [options.commandHistory] - Command history for undo/redo
 * @param {Map<string, string>} [options.biomeColorMap] - Biome name -> CSS color string
 * @param {import('./canvas.js').HexCanvas} [options.hexCanvas] - Canvas for live preview
 * @returns {void}
 */
export function renderBiomeList(container, options) {
  container.innerHTML = '';

  const opts = options || {};

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
    renderBiomeForm(container, new BiomeDataModel(), true, {
      commandHistory: opts.commandHistory || null,
      biomeColorMap: opts.biomeColorMap || null,
      hexCanvas: opts.hexCanvas || null,
      onSave: () => renderBiomeList(container, options),
      onCancel: () => renderBiomeList(container, options),
    });
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
      renderBiomeForm(container, model, false, {
        commandHistory: opts.commandHistory || null,
        biomeColorMap: opts.biomeColorMap || null,
        hexCanvas: opts.hexCanvas || null,
        onSave: () => renderBiomeList(container, options),
        onCancel: () => renderBiomeList(container, options),
        onDelete: () => renderBiomeList(container, options),
      });
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

// ============================================================
// Form Rendering (task-015)
// ============================================================

/** Common input style for form fields */
const INPUT_STYLE = 'width:100%;padding:4px 6px;border:1px solid var(--border);border-radius:3px;background:var(--bg-tertiary);color:var(--text-primary);font-size:12px;box-sizing:border-box;';

/** Common label style for form fields */
const LABEL_STYLE = 'display:block;margin-bottom:2px;font-size:11px;color:var(--text-secondary);font-weight:600;';

/** Style for collapsible details sections */
const DETAILS_STYLE = 'margin-bottom:8px;border:1px solid var(--border);border-radius:4px;overflow:hidden;';

/** Style for details summary */
const SUMMARY_STYLE = 'padding:6px 10px;background:var(--bg-tertiary);cursor:pointer;font-size:13px;font-weight:600;color:var(--text-primary);';

/** Style for details content area */
const SECTION_CONTENT_STYLE = 'padding:8px 10px;display:grid;grid-template-columns:1fr 1fr;gap:6px 10px;';

/**
 * Create a labeled form field (label + input).
 * @param {string} labelText
 * @param {string} name - Form input name attribute
 * @param {string} type - Input type ('text', 'number', etc.)
 * @param {string|number} value
 * @param {Object} [attrs] - Additional attributes for the input
 * @returns {HTMLElement}
 */
function _createField(labelText, name, type, value, attrs) {
  const wrapper = document.createElement('div');
  const label = document.createElement('label');
  label.textContent = labelText;
  label.style.cssText = LABEL_STYLE;
  const input = document.createElement('input');
  input.type = type;
  input.name = name;
  input.value = String(value);
  input.style.cssText = INPUT_STYLE;
  if (attrs) {
    for (const [k, v] of Object.entries(attrs)) {
      input.setAttribute(k, String(v));
    }
  }
  wrapper.appendChild(label);
  wrapper.appendChild(input);
  return wrapper;
}

/**
 * Create a collapsible details/summary section.
 * @param {string} title
 * @param {boolean} [open=true]
 * @returns {{details: HTMLDetailsElement, content: HTMLDivElement}}
 */
function _createSection(title, open) {
  const details = document.createElement('details');
  details.style.cssText = DETAILS_STYLE;
  if (open !== false) details.open = true;
  const summary = document.createElement('summary');
  summary.textContent = title;
  summary.style.cssText = SUMMARY_STYLE;
  details.appendChild(summary);
  const content = document.createElement('div');
  content.style.cssText = SECTION_CONTENT_STYLE;
  details.appendChild(content);
  return { details, content };
}

/**
 * Create a color picker field with a 32x32 swatch preview.
 * @param {string} labelText
 * @param {string} name - Form input name
 * @param {{r: number, g: number, b: number, a: number}} color
 * @param {function(string):void} [onInput] - Callback on input event with hex value
 * @returns {HTMLElement}
 */
function _createColorField(labelText, name, color, onInput) {
  const wrapper = document.createElement('div');
  const label = document.createElement('label');
  label.textContent = labelText;
  label.style.cssText = LABEL_STYLE;
  wrapper.appendChild(label);

  const row = document.createElement('div');
  row.style.cssText = 'display:flex;gap:6px;align-items:center;';

  const input = document.createElement('input');
  input.type = 'color';
  input.name = name;
  input.value = _colorToHex(color);
  input.style.cssText = 'width:40px;height:28px;border:1px solid var(--border);border-radius:3px;cursor:pointer;padding:0;';

  const swatch = document.createElement('div');
  swatch.style.cssText = `width:32px;height:32px;border-radius:3px;border:1px solid var(--border);background:${_colorToHex(color)};`;
  swatch.dataset.swatch = name;

  input.addEventListener('input', () => {
    swatch.style.background = input.value;
    if (onInput) onInput(input.value);
  });

  row.appendChild(input);
  row.appendChild(swatch);
  wrapper.appendChild(row);

  return wrapper;
}

/**
 * Convert a model to a plain object for dirty comparison (excluding metadata fields).
 * @param {BiomeDataModel} model
 * @returns {Object}
 */
function _modelToPlain(model) {
  return {
    biome_name: model.biome_name,
    elevation_range: model.elevation_range,
    resource_table: model.resource_table,
    color: model.color,
    color_variations: model.color_variations,
  };
}

/**
 * Render the biome edit form into the container, replacing the list view.
 * @param {HTMLElement} container - The #tab-biomes element
 * @param {BiomeDataModel} model - Biome model to edit
 * @param {boolean} isNew - True if creating a new biome
 * @param {Object} options
 * @param {import('./commands.js').CommandHistory} [options.commandHistory]
 * @param {function():void} [options.onSave]
 * @param {function():void} [options.onCancel]
 * @param {function():void} [options.onDelete]
 * @param {Map<string, string>} [options.biomeColorMap]
 * @param {import('./canvas.js').HexCanvas} [options.hexCanvas]
 * @returns {void}
 */
export function renderBiomeForm(container, model, isNew, options) {
  container.innerHTML = '';

  // Track initial state for dirty detection
  const initialJson = JSON.stringify(_modelToPlain(model));

  // Save original color for cancel revert
  const originalColorRgb = model.id && options.biomeColorMap
    ? options.biomeColorMap.get(model.id) || null
    : null;

  // Form element
  const form = document.createElement('form');
  form.style.cssText = 'padding:8px 12px;overflow-y:auto;max-height:calc(100vh - 100px);';
  form.addEventListener('submit', (e) => e.preventDefault());

  // Title
  const titleEl = document.createElement('h3');
  titleEl.textContent = isNew ? 'New Biome' : `Edit: ${model.biome_name}`;
  titleEl.style.cssText = 'margin:0 0 8px 0;font-size:16px;color:var(--text-primary);';
  form.appendChild(titleEl);

  // Error display area
  const errorArea = document.createElement('div');
  errorArea.style.cssText = 'display:none;padding:6px 10px;margin-bottom:8px;background:#4a1c1c;border:1px solid #7a3030;border-radius:4px;color:#ff9999;font-size:12px;';
  form.appendChild(errorArea);

  // Section 1: Identity
  {
    const { details, content } = _createSection('Identity');
    content.appendChild(_createField('Biome Name', 'biome_name', 'text', model.biome_name, isNew ? {} : { disabled: '' }));
    form.appendChild(details);
  }

  // Section 2: Elevation
  {
    const { details, content } = _createSection('Elevation Range');
    content.appendChild(_createField('Min', 'elevation_min', 'number', model.elevation_range.min, { step: '1', min: '0', max: '9' }));
    content.appendChild(_createField('Max', 'elevation_max', 'number', model.elevation_range.max, { step: '1', min: '0', max: '9' }));
    form.appendChild(details);
  }

  // Section 3: Color with live preview
  {
    const { details, content } = _createSection('Color');
    content.style.cssText = SECTION_CONTENT_STYLE + 'grid-template-columns:1fr;';

    const colorField = _createColorField('Base Color', 'color', model.color, (hex) => {
      // Live preview: update biomeColorMap and request canvas re-render
      const r = parseInt(hex.slice(1, 3), 16);
      const g = parseInt(hex.slice(3, 5), 16);
      const b = parseInt(hex.slice(5, 7), 16);
      if (options.biomeColorMap && model.id) {
        options.biomeColorMap.set(model.id, `rgb(${r},${g},${b})`);
        if (options.hexCanvas) options.hexCanvas.requestRender();
      }
    });
    content.appendChild(colorField);

    // Color Variations
    const variationsWrapper = document.createElement('div');
    variationsWrapper.style.cssText = 'margin-top:6px;';
    const variationsLabel = document.createElement('div');
    variationsLabel.textContent = 'Color Variations';
    variationsLabel.style.cssText = LABEL_STYLE;
    variationsWrapper.appendChild(variationsLabel);

    const variationsContainer = document.createElement('div');
    variationsContainer.dataset.variationsContainer = 'true';
    variationsWrapper.appendChild(variationsContainer);

    /**
     * Add a color variation entry to the list.
     * @param {{ r: number, g: number, b: number, a: number }} varColor
     * @returns {void}
     */
    function addVariationRow(varColor) {
      const row = document.createElement('div');
      row.style.cssText = 'display:flex;gap:6px;align-items:center;margin-bottom:4px;';

      const input = document.createElement('input');
      input.type = 'color';
      input.value = _colorToHex(varColor);
      input.dataset.variationColor = 'true';
      input.style.cssText = 'width:40px;height:28px;border:1px solid var(--border);border-radius:3px;cursor:pointer;padding:0;';

      const swatch = document.createElement('div');
      swatch.style.cssText = `width:32px;height:32px;border-radius:3px;border:1px solid var(--border);background:${_colorToHex(varColor)};`;

      input.addEventListener('input', () => {
        swatch.style.background = input.value;
      });

      const removeBtn = document.createElement('button');
      removeBtn.textContent = 'X';
      removeBtn.type = 'button';
      removeBtn.style.cssText = 'padding:2px 6px;border:1px solid var(--border);border-radius:3px;background:var(--bg-tertiary);color:var(--text-secondary);cursor:pointer;font-size:11px;';
      removeBtn.addEventListener('click', () => row.remove());

      row.appendChild(input);
      row.appendChild(swatch);
      row.appendChild(removeBtn);
      variationsContainer.appendChild(row);
    }

    // Populate existing variations
    for (const vc of model.color_variations) {
      addVariationRow(vc);
    }

    const addVarBtn = document.createElement('button');
    addVarBtn.textContent = '+ Add Variation';
    addVarBtn.type = 'button';
    addVarBtn.style.cssText = 'padding:2px 8px;border:1px solid var(--border);border-radius:3px;background:var(--bg-tertiary);color:var(--text-primary);cursor:pointer;font-size:11px;margin-top:2px;';
    addVarBtn.addEventListener('click', () => {
      // Check max 10
      const currentCount = variationsContainer.querySelectorAll('[data-variation-color]').length;
      if (currentCount >= 10) {
        errorArea.style.display = 'block';
        errorArea.textContent = 'Maximum 10 color variations allowed.';
        return;
      }
      // Default to base color
      const colorInput = /** @type {HTMLInputElement|null} */ (form.querySelector('[name="color"]'));
      const baseHex = colorInput ? colorInput.value : '#000000';
      addVariationRow(_hexToColor(baseHex));
    });
    variationsWrapper.appendChild(addVarBtn);
    content.appendChild(variationsWrapper);

    form.appendChild(details);
  }

  // Section 4: Resource Table
  {
    const { details, content } = _createSection('Resource Table');
    content.style.cssText = SECTION_CONTENT_STYLE + 'grid-template-columns:1fr;';

    const tableWrapper = document.createElement('div');
    tableWrapper.dataset.resourceTableContainer = 'true';

    // Get known resource types from ProjectContext
    const knownResources = [];
    for (const [filename] of ProjectContext.files.resources) {
      knownResources.push(filename.replace('.tres', ''));
    }
    knownResources.sort();

    // Column headers
    const labelsRow = document.createElement('div');
    labelsRow.style.cssText = 'display:flex;gap:4px;width:100%;font-size:10px;color:var(--text-secondary);margin-bottom:2px;';
    labelsRow.innerHTML = '<span style="flex:2;min-width:80px">Type</span><span style="flex:1;min-width:60px">Chance</span><span style="flex:1;min-width:50px">Min</span><span style="flex:1;min-width:50px">Max</span><span style="width:26px"></span>';
    tableWrapper.appendChild(labelsRow);

    /**
     * Add a resource table row.
     * @param {{ type: string, chance: number, min_amount: number, max_amount: number }} entry
     * @returns {void}
     */
    function addResourceRow(entry) {
      const row = document.createElement('div');
      row.style.cssText = 'display:flex;gap:4px;margin-bottom:4px;align-items:center;';
      row.dataset.resourceRow = 'true';

      // Type select
      const typeSelect = document.createElement('select');
      typeSelect.dataset.rtType = 'true';
      typeSelect.style.cssText = INPUT_STYLE + 'flex:2;min-width:80px;';

      // Add option for current value if it's not in known resources
      const isUnknown = entry.type && !knownResources.includes(entry.type);

      for (const resName of knownResources) {
        const opt = document.createElement('option');
        opt.value = resName;
        opt.textContent = resName;
        if (resName === entry.type) opt.selected = true;
        typeSelect.appendChild(opt);
      }

      if (isUnknown && entry.type) {
        const opt = document.createElement('option');
        opt.value = entry.type;
        opt.textContent = entry.type + ' (unknown)';
        opt.selected = true;
        opt.style.color = '#ff6666';
        typeSelect.appendChild(opt);
        typeSelect.style.color = '#ff6666';
        typeSelect.addEventListener('change', () => {
          typeSelect.style.color = knownResources.includes(typeSelect.value) ? '' : '#ff6666';
        });
      }

      // If no resources and no entry type, add empty option
      if (knownResources.length === 0 && !entry.type) {
        const opt = document.createElement('option');
        opt.value = '';
        opt.textContent = '(no resources)';
        opt.disabled = true;
        opt.selected = true;
        typeSelect.appendChild(opt);
      }

      // Chance
      const chanceInput = document.createElement('input');
      chanceInput.type = 'number';
      chanceInput.dataset.rtChance = 'true';
      chanceInput.value = String(entry.chance);
      chanceInput.step = '0.01';
      chanceInput.min = '0';
      chanceInput.max = '1';
      chanceInput.placeholder = 'Chance';
      chanceInput.title = 'Chance (0.0 - 1.0)';
      chanceInput.style.cssText = INPUT_STYLE + 'flex:1;min-width:60px;';

      // Min amount
      const minInput = document.createElement('input');
      minInput.type = 'number';
      minInput.dataset.rtMin = 'true';
      minInput.value = String(entry.min_amount);
      minInput.step = '1';
      minInput.min = '0';
      minInput.placeholder = 'Min';
      minInput.title = 'Min Amount';
      minInput.style.cssText = INPUT_STYLE + 'flex:1;min-width:50px;';

      // Max amount
      const maxInput = document.createElement('input');
      maxInput.type = 'number';
      maxInput.dataset.rtMax = 'true';
      maxInput.value = String(entry.max_amount);
      maxInput.step = '1';
      maxInput.min = '0';
      maxInput.placeholder = 'Max';
      maxInput.title = 'Max Amount';
      maxInput.style.cssText = INPUT_STYLE + 'flex:1;min-width:50px;';

      // Remove button
      const removeBtn = document.createElement('button');
      removeBtn.textContent = 'X';
      removeBtn.type = 'button';
      removeBtn.style.cssText = 'padding:2px 6px;border:1px solid var(--border);border-radius:3px;background:var(--bg-tertiary);color:var(--text-secondary);cursor:pointer;font-size:11px;';
      removeBtn.addEventListener('click', () => row.remove());

      row.appendChild(typeSelect);
      row.appendChild(chanceInput);
      row.appendChild(minInput);
      row.appendChild(maxInput);
      row.appendChild(removeBtn);
      tableWrapper.appendChild(row);
    }

    // Populate existing entries
    for (const entry of model.resource_table) {
      addResourceRow(entry);
    }

    const addRowBtn = document.createElement('button');
    addRowBtn.textContent = '+ Add Row';
    addRowBtn.type = 'button';
    addRowBtn.style.cssText = 'padding:2px 8px;border:1px solid var(--border);border-radius:3px;background:var(--bg-tertiary);color:var(--text-primary);cursor:pointer;font-size:11px;margin-top:2px;';
    addRowBtn.addEventListener('click', () => {
      addResourceRow({ type: knownResources[0] || '', chance: 0.5, min_amount: 1, max_amount: 1 });
    });

    content.appendChild(tableWrapper);
    content.appendChild(addRowBtn);
    form.appendChild(details);
  }

  // Footer buttons
  const footer = document.createElement('div');
  footer.style.cssText = 'display:flex;gap:8px;padding:10px 0;border-top:1px solid var(--border);margin-top:8px;';

  const saveBtn = document.createElement('button');
  saveBtn.textContent = 'Save';
  saveBtn.type = 'button';
  saveBtn.style.cssText = 'padding:6px 16px;border:none;border-radius:4px;background:var(--accent);color:var(--bg-primary);cursor:pointer;font-weight:600;font-size:12px;';

  const cancelBtn = document.createElement('button');
  cancelBtn.textContent = 'Cancel';
  cancelBtn.type = 'button';
  cancelBtn.style.cssText = 'padding:6px 16px;border:1px solid var(--border);border-radius:4px;background:var(--bg-tertiary);color:var(--text-primary);cursor:pointer;font-size:12px;';

  saveBtn.addEventListener('click', () => {
    const collected = _collectBiomeFormData(form);
    // Preserve round-trip metadata from original model
    collected._filename = isNew ? _biomeNameToFilename(collected.biome_name) : model._filename;
    collected._raw = model._raw;

    const validation = _validateBiomeForm(collected, isNew);
    if (!validation.valid) {
      errorArea.style.display = 'block';
      errorArea.textContent = validation.errors.join('; ');
      return;
    }

    if (isNew) {
      const cmd = new CreateBiomeCommand(collected, options.commandHistory);
      if (options.commandHistory) {
        options.commandHistory.execute(cmd);
      } else {
        cmd.execute();
      }
    } else {
      const cmd = new EditBiomeCommand(model._filename, model, collected, options.commandHistory, options);
      if (options.commandHistory) {
        options.commandHistory.execute(cmd);
      } else {
        cmd.execute();
      }
    }

    if (options.onSave) options.onSave();
  });

  cancelBtn.addEventListener('click', () => {
    // Revert live preview color on cancel
    if (options.biomeColorMap && model.id && originalColorRgb != null) {
      options.biomeColorMap.set(model.id, originalColorRgb);
      if (options.hexCanvas) options.hexCanvas.requestRender();
    }

    // Check if dirty
    const currentData = _collectBiomeFormData(form);
    const currentJson = JSON.stringify(_modelToPlain(currentData));
    if (currentJson !== initialJson) {
      if (!confirm('Discard unsaved changes?')) return;
    }
    if (options.onCancel) options.onCancel();
  });

  footer.appendChild(saveBtn);
  footer.appendChild(cancelBtn);

  if (!isNew) {
    const deleteBtn = document.createElement('button');
    deleteBtn.textContent = 'Delete';
    deleteBtn.type = 'button';
    deleteBtn.style.cssText = 'padding:6px 16px;border:1px solid #7a3030;border-radius:4px;background:#4a1c1c;color:#ff9999;cursor:pointer;font-size:12px;font-weight:600;margin-left:auto;';

    deleteBtn.addEventListener('click', () => {
      const usages = findBiomeUsage(model.id);
      if (usages.length > 0) {
        const usageList = usages.map(u => `${u.map} (${u.count} tile${u.count > 1 ? 's' : ''})`).join(', ');
        showInlineModal(
          `Biome "${model.biome_name}" is used in: ${usageList}. Type "DELETE" to confirm deletion:`,
          '',
          (val) => {
            if (val === 'DELETE') {
              _executeDelete(model, options);
            }
          }
        );
      } else {
        if (confirm(`Delete biome "${model.biome_name}"? This cannot be undone without undo.`)) {
          _executeDelete(model, options);
        }
      }
    });

    footer.appendChild(deleteBtn);
  }

  form.appendChild(footer);
  container.appendChild(form);
}

/**
 * Execute the delete command for a biome.
 * @param {BiomeDataModel} model
 * @param {Object} options
 * @returns {void}
 */
function _executeDelete(model, options) {
  const cmd = new DeleteBiomeCommand(model._filename, model, options.commandHistory);
  if (options.commandHistory) {
    options.commandHistory.execute(cmd);
  } else {
    cmd.execute();
  }
  if (options.onDelete) options.onDelete();
}

// ============================================================
// Form Data Collection (task-015)
// ============================================================

/**
 * Convert a biome_name to a filename (lowercased, underscored).
 * @param {string} name
 * @returns {string}
 */
function _biomeNameToFilename(name) {
  return name.trim().toLowerCase().replace(/\s+/g, '_') + '.tres';
}

/**
 * Collect form data from a biome edit form and return a populated BiomeDataModel.
 * @param {HTMLFormElement} formElement
 * @returns {BiomeDataModel}
 */
function _collectBiomeFormData(formElement) {
  const model = new BiomeDataModel();

  /**
   * Get the value of a named input.
   * @param {string} name
   * @returns {string}
   */
  function val(name) {
    const el = formElement.querySelector(`[name="${name}"]`);
    return el ? /** @type {HTMLInputElement} */ (el).value : '';
  }

  /**
   * Get an int value from a named input.
   * @param {string} name
   * @returns {number}
   */
  function intVal(name) {
    const v = parseInt(val(name), 10);
    return isNaN(v) ? 0 : v;
  }

  // Identity
  model.biome_name = val('biome_name').trim();

  // Elevation
  model.elevation_range = {
    min: intVal('elevation_min'),
    max: intVal('elevation_max'),
  };

  // Color
  model.color = _hexToColor(val('color'));

  // Color variations
  model.color_variations = [];
  const variationInputs = formElement.querySelectorAll('[data-variation-color]');
  for (const input of variationInputs) {
    model.color_variations.push(_hexToColor(/** @type {HTMLInputElement} */ (input).value));
  }

  // Resource table
  model.resource_table = [];
  const resourceRows = formElement.querySelectorAll('[data-resource-row]');
  for (const row of resourceRows) {
    const typeSelect = /** @type {HTMLSelectElement|null} */ (row.querySelector('[data-rt-type]'));
    const chanceInput = /** @type {HTMLInputElement|null} */ (row.querySelector('[data-rt-chance]'));
    const minInput = /** @type {HTMLInputElement|null} */ (row.querySelector('[data-rt-min]'));
    const maxInput = /** @type {HTMLInputElement|null} */ (row.querySelector('[data-rt-max]'));

    if (typeSelect && chanceInput && minInput && maxInput) {
      model.resource_table.push({
        type: typeSelect.value,
        chance: parseFloat(chanceInput.value) || 0,
        min_amount: parseInt(minInput.value, 10) || 0,
        max_amount: parseInt(maxInput.value, 10) || 0,
      });
    }
  }

  return model;
}

// ============================================================
// Form Validation (task-015)
// ============================================================

/**
 * Validate a biome form model.
 * @param {BiomeDataModel} model
 * @param {boolean} isNew
 * @returns {{ valid: boolean, errors: string[] }}
 */
function _validateBiomeForm(model, isNew) {
  /** @type {string[]} */
  const errors = [];

  // Biome name validation
  if (!model.biome_name) {
    errors.push('Biome Name is required');
  } else if (isNew) {
    // Check uniqueness by filename
    const filename = _biomeNameToFilename(model.biome_name);
    if (ProjectContext.files.biomes.has(filename)) {
      errors.push(`Biome "${model.biome_name}" already exists`);
    }
  }

  // Elevation range
  if (model.elevation_range.min < 0 || model.elevation_range.min > 9) {
    errors.push('Elevation Min must be between 0 and 9');
  }
  if (model.elevation_range.max < 0 || model.elevation_range.max > 9) {
    errors.push('Elevation Max must be between 0 and 9');
  }
  if (model.elevation_range.min > model.elevation_range.max) {
    errors.push('Elevation Min must be <= Max');
  }

  // Resource table validation
  for (let i = 0; i < model.resource_table.length; i++) {
    const entry = model.resource_table[i];
    if (entry.chance < 0 || entry.chance > 1) {
      errors.push(`Resource row ${i + 1}: Chance must be between 0.0 and 1.0`);
    }
    if (entry.min_amount < 0) {
      errors.push(`Resource row ${i + 1}: Min Amount must be >= 0`);
    }
    if (entry.max_amount < entry.min_amount) {
      errors.push(`Resource row ${i + 1}: Max Amount must be >= Min Amount`);
    }
  }

  return { valid: errors.length === 0, errors };
}

// ============================================================
// Model -> TresFile Serialization (task-015)
// ============================================================

/**
 * Update a TresFile's resourceFields from a BiomeDataModel.
 * For new biomes, creates a fresh TresFile with the standard BiomeData structure.
 * @param {BiomeDataModel} model
 * @returns {TresFile}
 */
export function biomeModelToRaw(model) {
  /** @type {TresFile} */
  let raw;

  if (model._raw) {
    // Update existing raw — preserve structure
    raw = model._raw;
  } else {
    // Create fresh TresFile for new biome
    raw = new TresFile();
    raw.scriptClass = 'BiomeData';
    const uid = generateTresUid();
    raw.uid = uid;
    raw.headerLine = `[gd_resource type="Resource" script_class="BiomeData" load_steps=2 format=3 uid="${uid}"]`;
    raw.extResources = ['[ext_resource type="Script" path="res://scripts/hex/biome_data.gd" id="1_biome"]'];
    raw.lineEnding = '\n';
  }

  // Build the resource fields map
  const fields = new Map();

  // Script line is always first
  fields.set('script', { type: 'ext_resource', value: 'ExtResource("1_biome")' });

  // biome_name: string
  fields.set('biome_name', { type: 'string', value: model.biome_name });

  // elevation_range: Vector2i
  fields.set('elevation_range', { type: 'vector2i', value: { x: model.elevation_range.min, y: model.elevation_range.max } });

  // resource_table: untyped array of dicts
  // Each dict has string keys: "chance", "max_amount", "min_amount", "type"
  const resourceTableEntries = model.resource_table.map(entry => {
    const dictMap = new Map();
    // Alphabetical key order to match Godot's output
    dictMap.set('chance', { type: 'float', value: entry.chance });
    dictMap.set('max_amount', { type: 'int', value: entry.max_amount });
    dictMap.set('min_amount', { type: 'int', value: entry.min_amount });
    dictMap.set('type', { type: 'string', value: entry.type });
    return { type: 'dict', value: dictMap, keyStyle: 'string', braceSpaces: false };
  });
  fields.set('resource_table', { type: 'array', value: resourceTableEntries, elementType: null });

  // color: Color
  fields.set('color', {
    type: 'color',
    value: { r: model.color.r, g: model.color.g, b: model.color.b, a: model.color.a },
  });

  // color_variations: untyped array of Colors
  const colorVariationEntries = model.color_variations.map(vc => ({
    type: 'color',
    value: { r: vc.r, g: vc.g, b: vc.b, a: vc.a },
  }));
  fields.set('color_variations', { type: 'array', value: colorVariationEntries, elementType: null });

  raw.resourceFields = fields;
  return raw;
}

// ============================================================
// Command Classes (task-015)
// ============================================================

/**
 * Command to create a new biome definition.
 */
export class CreateBiomeCommand {
  /**
   * @param {BiomeDataModel} model
   * @param {import('./commands.js').CommandHistory} [commandHistory]
   */
  constructor(model, commandHistory) {
    this._model = model;
    this._filename = _biomeNameToFilename(model.biome_name);
    this.tab = 'biomes';
    this.type = 'CreateBiome';
  }

  execute() {
    const raw = biomeModelToRaw(this._model);
    const content = TresParser.serialize(raw);

    // Build data object from resourceFields (mirrors _parseTresFile logic)
    const data = {};
    for (const [key, tv] of raw.resourceFields) {
      data[key] = tv.value;
    }

    // Add to ProjectContext
    ProjectContext.files.biomes.set(this._filename, {
      handle: null,
      dir: 'data/biomes',
      data,
      raw,
    });

    // Write file
    FileDiscovery.saveFile('data/biomes', content, this._filename).catch((err) => {
      console.warn(`CreateBiomeCommand: Failed to save "${this._filename}": ${err.message}`);
    });
  }

  undo() {
    ProjectContext.files.biomes.delete(this._filename);
  }
}

/**
 * Command to edit an existing biome definition.
 */
export class EditBiomeCommand {
  /**
   * @param {string} filename
   * @param {BiomeDataModel} oldModel
   * @param {BiomeDataModel} newModel
   * @param {import('./commands.js').CommandHistory} [commandHistory]
   * @param {Object} [options]
   * @param {Map<string, string>} [options.biomeColorMap]
   * @param {import('./canvas.js').HexCanvas} [options.hexCanvas]
   */
  constructor(filename, oldModel, newModel, commandHistory, options) {
    this._filename = filename;
    this._oldModel = oldModel;
    this._newModel = newModel;
    this._oldRaw = oldModel._raw;
    this._options = options || {};
    this.tab = 'biomes';
    this.type = 'EditBiome';
  }

  execute() {
    const raw = biomeModelToRaw(this._newModel);
    const content = TresParser.serialize(raw);

    const data = {};
    for (const [key, tv] of raw.resourceFields) {
      data[key] = tv.value;
    }

    const entry = ProjectContext.files.biomes.get(this._filename);
    if (entry) {
      entry.data = data;
      entry.raw = raw;
    }

    // Update biomeColorMap
    if (this._options.biomeColorMap) {
      const biomeId = this._filename.replace('.tres', '');
      this._options.biomeColorMap.set(biomeId, _colorToRgb(this._newModel.color));
      if (this._options.hexCanvas) this._options.hexCanvas.requestRender();
    }

    FileDiscovery.saveFile('data/biomes', content, this._filename).catch((err) => {
      console.warn(`EditBiomeCommand: Failed to save "${this._filename}": ${err.message}`);
    });
  }

  undo() {
    if (this._oldRaw) {
      const entry = ProjectContext.files.biomes.get(this._filename);
      if (entry) {
        entry.raw = this._oldRaw;
        const data = {};
        for (const [key, tv] of this._oldRaw.resourceFields) {
          data[key] = tv.value;
        }
        entry.data = data;
      }

      const content = TresParser.serialize(this._oldRaw);
      FileDiscovery.saveFile('data/biomes', content, this._filename).catch((err) => {
        console.warn(`EditBiomeCommand.undo: Failed to save "${this._filename}": ${err.message}`);
      });
    } else {
      // Fall back to re-serializing old model
      const oldRaw = biomeModelToRaw(this._oldModel);
      const content = TresParser.serialize(oldRaw);

      const data = {};
      for (const [key, tv] of oldRaw.resourceFields) {
        data[key] = tv.value;
      }

      const entry = ProjectContext.files.biomes.get(this._filename);
      if (entry) {
        entry.data = data;
        entry.raw = oldRaw;
      }

      FileDiscovery.saveFile('data/biomes', content, this._filename).catch((err) => {
        console.warn(`EditBiomeCommand.undo: Failed to save "${this._filename}": ${err.message}`);
      });
    }

    // Revert biomeColorMap
    if (this._options.biomeColorMap) {
      const biomeId = this._filename.replace('.tres', '');
      this._options.biomeColorMap.set(biomeId, _colorToRgb(this._oldModel.color));
      if (this._options.hexCanvas) this._options.hexCanvas.requestRender();
    }
  }
}

/**
 * Command to delete a biome definition.
 */
export class DeleteBiomeCommand {
  /**
   * @param {string} filename
   * @param {BiomeDataModel} model
   * @param {import('./commands.js').CommandHistory} [commandHistory]
   */
  constructor(filename, model, commandHistory) {
    this._filename = filename;
    this._model = model;
    this._savedEntry = null;
    this.tab = 'biomes';
    this.type = 'DeleteBiome';
  }

  execute() {
    // Save entry for undo
    this._savedEntry = ProjectContext.files.biomes.get(this._filename) || null;
    ProjectContext.files.biomes.delete(this._filename);
  }

  undo() {
    if (this._savedEntry) {
      ProjectContext.files.biomes.set(this._filename, this._savedEntry);

      // Re-write the file
      const content = TresParser.serialize(this._savedEntry.raw);
      FileDiscovery.saveFile('data/biomes', content, this._filename).catch((err) => {
        console.warn(`DeleteBiomeCommand.undo: Failed to save "${this._filename}": ${err.message}`);
      });
    }
  }
}

// ============================================================
// Delete Validation — Usage Scan (task-015)
// ============================================================

/**
 * Scan all loaded maps for tiles using this biome.
 * @param {string} biomeId - The biome ID (filename stem, e.g. 'forest') to search for
 * @returns {Array<{map: string, count: number}>}
 */
export function findBiomeUsage(biomeId) {
  /** @type {Array<{map: string, count: number}>} */
  const usages = [];
  for (const [mapName, mapEntry] of ProjectContext.files.maps) {
    let count = 0;
    if (mapEntry.data.tiles) {
      for (const tile of Object.values(mapEntry.data.tiles)) {
        if (tile.biome === biomeId) count++;
      }
    }
    if (count > 0) usages.push({ map: mapName, count });
  }
  return usages;
}
