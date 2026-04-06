// ============================================================
// ResourceEditor — List View, Edit Form, Commands (task-012/013)
// ============================================================

import { ProjectContext, FileDiscovery } from './file-discovery.js';
import { TresParser, TresFile } from './tres-parser.js';
import { showInlineModal } from './panels.js';

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

// ============================================================
// List View Rendering
// ============================================================

/**
 * Render the resource list view into the Resources tab panel.
 * @param {HTMLElement} container - The #tab-resources element
 * @param {Object} [options] - Options object
 * @param {import('./commands.js').CommandHistory} [options.commandHistory] - Command history for undo/redo
 * @returns {void}
 */
export function renderResourceList(container, options) {
  container.innerHTML = '';

  const cmdHistory = options && options.commandHistory ? options.commandHistory : null;

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
    renderResourceForm(container, new ResourceDefModel(), true, {
      commandHistory: cmdHistory,
      onSave: () => renderResourceList(container, options),
      onCancel: () => renderResourceList(container, options),
    });
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
      renderResourceForm(container, model, false, {
        commandHistory: cmdHistory,
        onSave: () => renderResourceList(container, options),
        onCancel: () => renderResourceList(container, options),
        onDelete: () => renderResourceList(container, options),
      });
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

// ============================================================
// Form Rendering (task-013)
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
 * Create a key-value editor for dict fields (string key -> number value).
 * @param {string} name - Base name for the editor
 * @param {Object<string, number>} data - Current key-value pairs
 * @returns {HTMLElement}
 */
function _createKvEditor(name, data) {
  const wrapper = document.createElement('div');
  wrapper.style.cssText = 'grid-column:1/-1;';
  wrapper.dataset.kvName = name;

  const label = document.createElement('div');
  label.textContent = name.replace(/_/g, ' ');
  label.style.cssText = LABEL_STYLE;
  wrapper.appendChild(label);

  const rowsContainer = document.createElement('div');
  rowsContainer.dataset.kvRows = name;
  wrapper.appendChild(rowsContainer);

  /**
   * Add a key-value row to the editor.
   * @param {string} key
   * @param {number|string} val
   * @returns {void}
   */
  function addRow(key, val) {
    const row = document.createElement('div');
    row.style.cssText = 'display:flex;gap:4px;margin-bottom:4px;align-items:center;';

    const keyInput = document.createElement('input');
    keyInput.type = 'text';
    keyInput.value = key;
    keyInput.placeholder = 'key';
    keyInput.dataset.kvKey = name;
    keyInput.style.cssText = INPUT_STYLE + 'flex:1;';

    const valInput = document.createElement('input');
    valInput.type = 'number';
    valInput.value = String(val);
    valInput.step = 'any';
    valInput.placeholder = 'value';
    valInput.dataset.kvVal = name;
    valInput.style.cssText = INPUT_STYLE + 'flex:1;';

    const removeBtn = document.createElement('button');
    removeBtn.textContent = 'X';
    removeBtn.type = 'button';
    removeBtn.style.cssText = 'padding:2px 6px;border:1px solid var(--border);border-radius:3px;background:var(--bg-tertiary);color:var(--text-secondary);cursor:pointer;font-size:11px;';
    removeBtn.addEventListener('click', () => row.remove());

    row.appendChild(keyInput);
    row.appendChild(valInput);
    row.appendChild(removeBtn);
    rowsContainer.appendChild(row);
  }

  // Populate existing entries
  for (const [key, val] of Object.entries(data)) {
    addRow(key, val);
  }

  const addBtn = document.createElement('button');
  addBtn.textContent = '+ Add';
  addBtn.type = 'button';
  addBtn.style.cssText = 'padding:2px 8px;border:1px solid var(--border);border-radius:3px;background:var(--bg-tertiary);color:var(--text-primary);cursor:pointer;font-size:11px;margin-top:2px;';
  addBtn.addEventListener('click', () => addRow('', 0));
  wrapper.appendChild(addBtn);

  return wrapper;
}

/**
 * Create a color picker field with a 32x32 swatch preview.
 * @param {string} labelText
 * @param {string} name - Form input name
 * @param {{r: number, g: number, b: number, a: number}} color
 * @returns {HTMLElement}
 */
function _createColorField(labelText, name, color) {
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

  const alphaLabel = document.createElement('label');
  alphaLabel.textContent = 'A:';
  alphaLabel.style.cssText = 'font-size:11px;color:var(--text-secondary);';

  const alphaInput = document.createElement('input');
  alphaInput.type = 'number';
  alphaInput.name = name + '_alpha';
  alphaInput.value = String(color.a != null ? color.a : 1);
  alphaInput.step = '0.1';
  alphaInput.min = '0';
  alphaInput.max = '1';
  alphaInput.style.cssText = INPUT_STYLE + 'width:50px;';

  input.addEventListener('input', () => {
    swatch.style.background = input.value;
  });

  row.appendChild(input);
  row.appendChild(swatch);
  row.appendChild(alphaLabel);
  row.appendChild(alphaInput);
  wrapper.appendChild(row);

  return wrapper;
}

/**
 * Render the resource edit form into the container, replacing the list view.
 * @param {HTMLElement} container - The #tab-resources element
 * @param {ResourceDefModel} model - Resource model to edit
 * @param {boolean} isNew - True if creating a new resource
 * @param {Object} options
 * @param {import('./commands.js').CommandHistory} [options.commandHistory]
 * @param {function():void} [options.onSave]
 * @param {function():void} [options.onCancel]
 * @param {function():void} [options.onDelete]
 * @returns {void}
 */
export function renderResourceForm(container, model, isNew, options) {
  container.innerHTML = '';

  // Track initial state for dirty detection
  const initialJson = JSON.stringify(_modelToPlain(model));

  // Form element
  const form = document.createElement('form');
  form.style.cssText = 'padding:8px 12px;overflow-y:auto;max-height:calc(100vh - 100px);';
  form.addEventListener('submit', (e) => e.preventDefault());

  // Title
  const titleEl = document.createElement('h3');
  titleEl.textContent = isNew ? 'New Resource' : `Edit: ${model.id}`;
  titleEl.style.cssText = 'margin:0 0 8px 0;font-size:16px;color:var(--text-primary);';
  form.appendChild(titleEl);

  // Error display area
  const errorArea = document.createElement('div');
  errorArea.style.cssText = 'display:none;padding:6px 10px;margin-bottom:8px;background:#4a1c1c;border:1px solid #7a3030;border-radius:4px;color:#ff9999;font-size:12px;';
  form.appendChild(errorArea);

  // Section 1: Identity
  {
    const { details, content } = _createSection('Identity');
    content.appendChild(_createField('ID', 'id', 'text', model.id, isNew ? { pattern: '^[a-zA-Z0-9_]+$' } : { disabled: '' }));
    content.appendChild(_createField('Display Name', 'display_name', 'text', model.display_name));
    form.appendChild(details);
  }

  // Section 2: Gathering
  {
    const { details, content } = _createSection('Gathering');
    content.appendChild(_createField('Gather Time', 'gather_time', 'number', model.gather_time, { step: 'any', min: '0' }));
    content.appendChild(_createField('Gather Amount', 'gather_amount', 'number', model.gather_amount, { step: '1', min: '0' }));
    content.appendChild(_createField('Tool Required', 'tool_required', 'text', model.tool_required));
    content.appendChild(_createField('Respawn Time', 'respawn_time', 'number', model.respawn_time, { step: 'any', min: '0' }));
    content.appendChild(_createField('Yield Type', 'yield_type', 'text', model.yield_type));
    content.appendChild(_createKvEditor('tool_speed', model.tool_speed));
    form.appendChild(details);
  }

  // Section 3: Inventory
  {
    const { details, content } = _createSection('Inventory');
    content.appendChild(_createField('Max Stack', 'max_stack', 'number', model.max_stack, { step: '1', min: '1' }));
    content.appendChild(_createField('Category', 'category', 'text', model.category));
    form.appendChild(details);
  }

  // Section 4: Catalog
  {
    const { details, content } = _createSection('Catalog');
    content.appendChild(_createField('Catalog Entry', 'catalog_entry', 'text', model.catalog_entry));
    content.appendChild(_createField('Catalog Category', 'catalog_category', 'text', model.catalog_category));
    form.appendChild(details);
  }

  // Section 5: Visuals
  {
    const { details, content } = _createSection('Visuals');
    content.appendChild(_createField('Mesh Type', 'placeholder_mesh_type', 'text', model.placeholder_mesh_type));
    content.appendChild(_createKvEditor('placeholder_params', model.placeholder_params));
    content.appendChild(_createColorField('Color', 'placeholder_color', model.placeholder_color));
    content.appendChild(_createField('Depleted Mesh Type', 'placeholder_depleted_type', 'text', model.placeholder_depleted_type));
    content.appendChild(_createKvEditor('placeholder_depleted_params', model.placeholder_depleted_params));
    content.appendChild(_createColorField('Depleted Color', 'placeholder_depleted_color', model.placeholder_depleted_color));
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
    const collected = collectFormData(form);
    // Preserve round-trip metadata from original model
    collected._filename = isNew ? collected.id + '.tres' : model._filename;
    collected._raw = model._raw;

    const validation = validateResourceForm(collected, isNew);
    if (!validation.valid) {
      errorArea.style.display = 'block';
      errorArea.textContent = validation.errors.join('; ');
      return;
    }

    if (isNew) {
      const cmd = new CreateResourceDefCommand(collected, options.commandHistory);
      if (options.commandHistory) {
        options.commandHistory.execute(cmd);
      } else {
        cmd.execute();
      }
    } else {
      const cmd = new EditResourceDefCommand(model._filename, model, collected, options.commandHistory);
      if (options.commandHistory) {
        options.commandHistory.execute(cmd);
      } else {
        cmd.execute();
      }
    }

    if (options.onSave) options.onSave();
  });

  cancelBtn.addEventListener('click', () => {
    // Check if dirty
    const currentData = collectFormData(form);
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
      const usages = findResourceUsage(model.id);
      if (usages.length > 0) {
        const usageList = usages.map(u => `${u.map} (${u.count} ref${u.count > 1 ? 's' : ''})`).join(', ');
        showInlineModal(
          `Resource "${model.id}" is referenced in: ${usageList}. Type "DELETE" to confirm deletion:`,
          '',
          (val) => {
            if (val === 'DELETE') {
              _executeDelete(model, options);
            }
          }
        );
      } else {
        if (confirm(`Delete resource "${model.id}"? This cannot be undone without undo.`)) {
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
 * Execute the delete command for a resource.
 * @param {ResourceDefModel} model
 * @param {Object} options
 * @returns {void}
 */
function _executeDelete(model, options) {
  const cmd = new DeleteResourceDefCommand(model._filename, model, options.commandHistory);
  if (options.commandHistory) {
    options.commandHistory.execute(cmd);
  } else {
    cmd.execute();
  }
  if (options.onDelete) options.onDelete();
}

/**
 * Convert a model to a plain object for dirty comparison (excluding metadata fields).
 * @param {ResourceDefModel} model
 * @returns {Object}
 */
function _modelToPlain(model) {
  return {
    id: model.id,
    display_name: model.display_name,
    gather_time: model.gather_time,
    gather_amount: model.gather_amount,
    tool_required: model.tool_required,
    respawn_time: model.respawn_time,
    yield_type: model.yield_type,
    tool_speed: model.tool_speed,
    max_stack: model.max_stack,
    category: model.category,
    catalog_entry: model.catalog_entry,
    catalog_category: model.catalog_category,
    placeholder_mesh_type: model.placeholder_mesh_type,
    placeholder_params: model.placeholder_params,
    placeholder_color: model.placeholder_color,
    placeholder_depleted_type: model.placeholder_depleted_type,
    placeholder_depleted_params: model.placeholder_depleted_params,
    placeholder_depleted_color: model.placeholder_depleted_color,
  };
}

// ============================================================
// Form Data Collection (task-013)
// ============================================================

/**
 * Collect form data from a resource edit form and return a populated ResourceDefModel.
 * @param {HTMLFormElement} formElement
 * @returns {ResourceDefModel}
 */
export function collectFormData(formElement) {
  const model = new ResourceDefModel();

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
   * Get a float value from a named input.
   * @param {string} name
   * @returns {number}
   */
  function floatVal(name) {
    const v = parseFloat(val(name));
    return isNaN(v) ? 0 : v;
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
  model.id = val('id').trim();
  model.display_name = val('display_name').trim();

  // Gathering
  model.gather_time = floatVal('gather_time');
  model.gather_amount = intVal('gather_amount');
  model.tool_required = val('tool_required').trim();
  model.respawn_time = floatVal('respawn_time');
  model.yield_type = val('yield_type').trim();
  model.tool_speed = _collectKvData(formElement, 'tool_speed');

  // Inventory
  model.max_stack = intVal('max_stack');
  model.category = val('category').trim();

  // Catalog
  model.catalog_entry = val('catalog_entry').trim();
  model.catalog_category = val('catalog_category').trim();

  // Visuals
  model.placeholder_mesh_type = val('placeholder_mesh_type').trim();
  model.placeholder_params = _collectKvData(formElement, 'placeholder_params');
  model.placeholder_color = _hexToColor(val('placeholder_color'), floatVal('placeholder_color_alpha'));
  model.placeholder_depleted_type = val('placeholder_depleted_type').trim();
  model.placeholder_depleted_params = _collectKvData(formElement, 'placeholder_depleted_params');
  model.placeholder_depleted_color = _hexToColor(val('placeholder_depleted_color'), floatVal('placeholder_depleted_color_alpha'));

  return model;
}

/**
 * Collect key-value pairs from a kv-editor section.
 * @param {HTMLFormElement} formElement
 * @param {string} name - The kv editor name
 * @returns {Object<string, number>}
 */
function _collectKvData(formElement, name) {
  const result = {};
  const container = formElement.querySelector(`[data-kv-rows="${name}"]`);
  if (!container) return result;
  const rows = container.children;
  for (const row of rows) {
    const keyInput = row.querySelector(`[data-kv-key="${name}"]`);
    const valInput = row.querySelector(`[data-kv-val="${name}"]`);
    if (keyInput && valInput) {
      const k = /** @type {HTMLInputElement} */ (keyInput).value.trim();
      const v = parseFloat(/** @type {HTMLInputElement} */ (valInput).value);
      if (k) {
        result[k] = isNaN(v) ? 0 : v;
      }
    }
  }
  return result;
}

// ============================================================
// Form Validation (task-013)
// ============================================================

/**
 * Validate a resource form model.
 * @param {ResourceDefModel} model
 * @param {boolean} isNew
 * @returns {{ valid: boolean, errors: string[] }}
 */
export function validateResourceForm(model, isNew) {
  /** @type {string[]} */
  const errors = [];

  // ID validation
  if (!model.id) {
    errors.push('ID is required');
  } else if (!/^[a-zA-Z0-9_]+$/.test(model.id)) {
    errors.push('ID must contain only alphanumeric characters and underscores');
  } else if (isNew && ProjectContext.files.resources.has(model.id + '.tres')) {
    errors.push(`Resource "${model.id}" already exists`);
  }

  // Display name
  if (!model.display_name) {
    errors.push('Display Name is required');
  }

  // Numeric validations
  if (model.gather_time < 0) {
    errors.push('Gather Time must be >= 0');
  }
  if (model.gather_amount < 0) {
    errors.push('Gather Amount must be >= 0');
  }
  if (model.respawn_time < 0) {
    errors.push('Respawn Time must be >= 0');
  }
  if (model.max_stack < 1) {
    errors.push('Max Stack must be >= 1');
  }

  return { valid: errors.length === 0, errors };
}

// ============================================================
// Model -> TresFile Serialization (task-013)
// ============================================================

/**
 * Update a TresFile's resourceFields from a ResourceDefModel.
 * For new resources, creates a fresh TresFile with the standard ResourceDef structure.
 * @param {ResourceDefModel} model
 * @returns {TresFile}
 */
export function modelToRaw(model) {
  /** @type {TresFile} */
  let raw;

  if (model._raw) {
    // Update existing raw — preserve structure
    raw = model._raw;
  } else {
    // Create fresh TresFile for new resource
    raw = new TresFile();
    raw.scriptClass = 'ResourceDef';
    raw.headerLine = '[gd_resource type="Resource" script_class="ResourceDef" load_steps=2 format=3]';
    raw.extResources = ['[ext_resource type="Script" path="res://scripts/data/resource_def.gd" id="1_script"]'];
    raw.lineEnding = '\n';
  }

  // Build the resource fields map
  const fields = new Map();

  // Script line is always first
  fields.set('script', { type: 'ext_resource', value: 'ExtResource("1_script")' });

  // StringName fields
  fields.set('id', { type: 'stringname', value: model.id });
  fields.set('display_name', { type: 'string', value: model.display_name });

  // Float fields
  fields.set('gather_time', { type: 'float', value: model.gather_time });
  fields.set('gather_amount', { type: 'int', value: model.gather_amount });

  // StringName fields
  fields.set('tool_required', { type: 'stringname', value: model.tool_required });

  // Float fields
  fields.set('respawn_time', { type: 'float', value: model.respawn_time });

  // StringName fields
  fields.set('yield_type', { type: 'stringname', value: model.yield_type });

  // Dict: tool_speed
  fields.set('tool_speed', _objToTresDict(model.tool_speed, 'stringname', 'float'));

  // Int field
  fields.set('max_stack', { type: 'int', value: model.max_stack });

  // StringName fields
  fields.set('category', { type: 'stringname', value: model.category });
  fields.set('catalog_entry', { type: 'stringname', value: model.catalog_entry });
  fields.set('catalog_category', { type: 'stringname', value: model.catalog_category });

  // Placeholder fields
  fields.set('placeholder_mesh_type', { type: 'stringname', value: model.placeholder_mesh_type });
  fields.set('placeholder_params', _objToTresDict(model.placeholder_params, 'string', 'float'));
  fields.set('placeholder_color', _colorToTresValue(model.placeholder_color));
  fields.set('placeholder_depleted_type', { type: 'stringname', value: model.placeholder_depleted_type });
  fields.set('placeholder_depleted_params', _objToTresDict(model.placeholder_depleted_params, 'string', 'float'));
  fields.set('placeholder_depleted_color', _colorToTresValue(model.placeholder_depleted_color));

  raw.resourceFields = fields;
  return raw;
}

/**
 * Convert a plain JS object to a TresValue dict.
 * @param {Object<string, number>} obj
 * @param {string} keyStyle - 'stringname' or 'string'
 * @param {string} valType - 'float' or 'int'
 * @returns {import('./tres-parser.js').TresValue}
 */
function _objToTresDict(obj, keyStyle, valType) {
  const map = new Map();
  for (const [key, val] of Object.entries(obj)) {
    map.set(key, { type: valType, value: val });
  }
  return { type: 'dict', value: map, keyStyle, braceSpaces: true };
}

/**
 * Convert a {r,g,b,a} color to a TresValue color.
 * @param {{r: number, g: number, b: number, a: number}} c
 * @returns {import('./tres-parser.js').TresValue}
 */
function _colorToTresValue(c) {
  return {
    type: 'color',
    value: { r: c.r, g: c.g, b: c.b, a: c.a },
  };
}

// ============================================================
// Command Classes (task-013)
// ============================================================

/**
 * Command to create a new resource definition.
 */
export class CreateResourceDefCommand {
  /**
   * @param {ResourceDefModel} model
   * @param {import('./commands.js').CommandHistory} [commandHistory]
   */
  constructor(model, commandHistory) {
    this._model = model;
    this._filename = model.id + '.tres';
    this.tab = 'resources';
    this.type = 'CreateResourceDef';
  }

  execute() {
    const raw = modelToRaw(this._model);
    const content = TresParser.serialize(raw);

    // Build data object from resourceFields (mirrors _parseTresFile logic)
    const data = {};
    for (const [key, tv] of raw.resourceFields) {
      data[key] = tv.value;
    }

    // Add to ProjectContext
    ProjectContext.files.resources.set(this._filename, {
      handle: null,
      dir: 'data/resources',
      data,
      raw,
    });

    // Write file
    FileDiscovery.saveFile('data/resources', content, this._filename).catch((err) => {
      console.warn(`CreateResourceDefCommand: Failed to save "${this._filename}": ${err.message}`);
    });
  }

  undo() {
    ProjectContext.files.resources.delete(this._filename);
  }
}

/**
 * Command to edit an existing resource definition.
 */
export class EditResourceDefCommand {
  /**
   * @param {string} filename
   * @param {ResourceDefModel} oldModel
   * @param {ResourceDefModel} newModel
   * @param {import('./commands.js').CommandHistory} [commandHistory]
   */
  constructor(filename, oldModel, newModel, commandHistory) {
    this._filename = filename;
    this._oldModel = oldModel;
    this._newModel = newModel;
    this._oldRaw = oldModel._raw;
    this.tab = 'resources';
    this.type = 'EditResourceDef';
  }

  execute() {
    const raw = modelToRaw(this._newModel);
    const content = TresParser.serialize(raw);

    const data = {};
    for (const [key, tv] of raw.resourceFields) {
      data[key] = tv.value;
    }

    const entry = ProjectContext.files.resources.get(this._filename);
    if (entry) {
      entry.data = data;
      entry.raw = raw;
    }

    FileDiscovery.saveFile('data/resources', content, this._filename).catch((err) => {
      console.warn(`EditResourceDefCommand: Failed to save "${this._filename}": ${err.message}`);
    });
  }

  undo() {
    const raw = modelToRaw(this._oldModel);
    // Restore the original raw if available
    if (this._oldRaw) {
      const entry = ProjectContext.files.resources.get(this._filename);
      if (entry) {
        entry.raw = this._oldRaw;
        const data = {};
        for (const [key, tv] of this._oldRaw.resourceFields) {
          data[key] = tv.value;
        }
        entry.data = data;
      }

      const content = TresParser.serialize(this._oldRaw);
      FileDiscovery.saveFile('data/resources', content, this._filename).catch((err) => {
        console.warn(`EditResourceDefCommand.undo: Failed to save "${this._filename}": ${err.message}`);
      });
    } else {
      // Fall back to re-serializing old model
      const oldRaw = modelToRaw(this._oldModel);
      const content = TresParser.serialize(oldRaw);

      const data = {};
      for (const [key, tv] of oldRaw.resourceFields) {
        data[key] = tv.value;
      }

      const entry = ProjectContext.files.resources.get(this._filename);
      if (entry) {
        entry.data = data;
        entry.raw = oldRaw;
      }

      FileDiscovery.saveFile('data/resources', content, this._filename).catch((err) => {
        console.warn(`EditResourceDefCommand.undo: Failed to save "${this._filename}": ${err.message}`);
      });
    }
  }
}

/**
 * Command to delete a resource definition.
 */
export class DeleteResourceDefCommand {
  /**
   * @param {string} filename
   * @param {ResourceDefModel} model
   * @param {import('./commands.js').CommandHistory} [commandHistory]
   */
  constructor(filename, model, commandHistory) {
    this._filename = filename;
    this._model = model;
    this._savedEntry = null;
    this.tab = 'resources';
    this.type = 'DeleteResourceDef';
  }

  execute() {
    // Save entry for undo
    this._savedEntry = ProjectContext.files.resources.get(this._filename) || null;
    ProjectContext.files.resources.delete(this._filename);
  }

  undo() {
    if (this._savedEntry) {
      ProjectContext.files.resources.set(this._filename, this._savedEntry);

      // Re-write the file
      const content = TresParser.serialize(this._savedEntry.raw);
      FileDiscovery.saveFile('data/resources', content, this._filename).catch((err) => {
        console.warn(`DeleteResourceDefCommand.undo: Failed to save "${this._filename}": ${err.message}`);
      });
    }
  }
}

// ============================================================
// Delete Validation — Usage Scan (task-013)
// ============================================================

/**
 * Scan all loaded maps for props referencing this resource type.
 * @param {string} resourceId
 * @returns {Array<{map: string, count: number}>}
 */
export function findResourceUsage(resourceId) {
  /** @type {Array<{map: string, count: number}>} */
  const usages = [];
  for (const [mapName, mapEntry] of ProjectContext.files.maps) {
    let count = 0;
    for (const [key, tile] of Object.entries(mapEntry.data.tiles || {})) {
      if (tile.props) {
        count += tile.props.filter(p => p.category === 'resource' && p.type === resourceId).length;
      }
    }
    if (count > 0) usages.push({ map: mapName, count });
  }
  return usages;
}
