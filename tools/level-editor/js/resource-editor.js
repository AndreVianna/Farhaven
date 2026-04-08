// ============================================================
// ResourceEditor — Master-Detail Split Layout (A2 Tabbed Detail)
// ============================================================

import { ProjectContext, FileDiscovery } from './file-discovery.js';
import { TresParser, TresFile } from './tres-parser.js';
import { showInlineModal } from './panels.js';
import { CATEGORIES, ORIGINS, NATURAL_CATEGORIES, CATEGORY_TO_INT } from './hex-grid.js';

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
    // Editor-only placement defaults (not serialized to .tres)
    /** @type {string} Default prop category for placement */
    this.prop_category = 'plant';
    /** @type {string} Default origin for placement */
    this.prop_origin = 'natural';
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
// KV Editor & Color Field Helpers
// ============================================================

/**
 * Create a key-value editor for dict fields (string key -> number value).
 * @param {string} name - Base name for the editor
 * @param {Object<string, number>} data - Current key-value pairs
 * @returns {HTMLElement}
 */
function _createKvEditor(name, data) {
  const wrapper = document.createElement('div');
  wrapper.classList.add('prop-full');
  wrapper.dataset.kvName = name;

  const label = document.createElement('div');
  label.textContent = name.replace(/_/g, ' ');
  label.classList.add('prop-label');
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
    keyInput.classList.add('prop-input');
    keyInput.style.flex = '1';

    const valInput = document.createElement('input');
    valInput.type = 'number';
    valInput.value = String(val);
    valInput.step = 'any';
    valInput.placeholder = 'value';
    valInput.dataset.kvVal = name;
    valInput.classList.add('prop-input');
    valInput.style.flex = '1';

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
  wrapper.classList.add('prop-full');

  const label = document.createElement('label');
  label.textContent = labelText;
  label.classList.add('prop-label');
  wrapper.appendChild(label);

  const row = document.createElement('div');
  row.style.cssText = 'display:flex;gap:6px;align-items:center;';

  const input = document.createElement('input');
  input.type = 'color';
  input.name = name;
  input.value = _colorToHex(color);
  input.style.cssText = 'width:40px;height:28px;border:1px solid var(--border);border-radius:3px;cursor:pointer;padding:0;';

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
  alphaInput.classList.add('prop-input');
  alphaInput.style.width = '50px';

  row.appendChild(input);
  row.appendChild(alphaLabel);
  row.appendChild(alphaInput);
  wrapper.appendChild(row);

  return wrapper;
}

// ============================================================
// Master-Detail Split Layout
// ============================================================

/**
 * Render the resource editor as a persistent master-detail split view.
 * @param {HTMLElement} container - The #tab-resources element
 * @param {Object} [options] - Options object
 * @param {import('./commands.js').CommandHistory} [options.commandHistory] - Command history for undo/redo
 * @returns {void}
 */
export function renderResourceEditor(container, options) {
  container.innerHTML = '';

  const cmdHistory = options && options.commandHistory ? options.commandHistory : null;
  const onChange = options && typeof options.onChange === 'function' ? options.onChange : () => {};

  // --- Split layout ---
  const split = document.createElement('div');
  split.classList.add('editor-split');

  // --- Left panel ---
  const listPanel = document.createElement('div');
  listPanel.classList.add('editor-list-panel');

  const listHeader = document.createElement('div');
  listHeader.classList.add('editor-list-header');

  const filterInput = document.createElement('input');
  filterInput.type = 'text';
  filterInput.placeholder = 'Filter...';
  filterInput.classList.add('editor-filter');

  const newBtn = document.createElement('button');
  newBtn.textContent = '+ New';
  newBtn.classList.add('editor-new-btn');

  listHeader.appendChild(filterInput);
  listHeader.appendChild(newBtn);
  listPanel.appendChild(listHeader);

  const listItems = document.createElement('div');
  listItems.classList.add('editor-list-items');
  listPanel.appendChild(listItems);

  // --- Right panel ---
  const detailPanel = document.createElement('div');
  detailPanel.classList.add('editor-detail-panel');

  split.appendChild(listPanel);
  split.appendChild(detailPanel);
  container.appendChild(split);

  // --- State ---
  /** @type {string|null} */
  let selectedId = null;
  /** @type {string} */
  let activeTab = 'general';
  /** @type {boolean} */
  let isNewMode = false;
  /** @type {ResourceDefModel|null} */
  let editingModel = null;

  // --- Build the resource list ---
  /**
   * Rebuild the list items, optionally filtering.
   * @returns {void}
   */
  function refreshList() {
    listItems.innerHTML = '';
    const filter = filterInput.value.toLowerCase().trim();

    /** @type {ResourceDefModel[]} */
    const resources = [];
    for (const [filename, entry] of ProjectContext.files.resources) {
      resources.push(ResourceDefModel.fromEntry(filename, entry));
    }
    resources.sort((a, b) => a.id.localeCompare(b.id));

    for (const model of resources) {
      if (filter && !model.id.toLowerCase().includes(filter) && !model.display_name.toLowerCase().includes(filter)) {
        continue;
      }
      const item = document.createElement('div');
      item.classList.add('editor-list-item');
      if (model.id === selectedId && !isNewMode) {
        item.classList.add('active');
      }
      item.dataset.id = model.id;

      const swatch = document.createElement('div');
      swatch.classList.add('swatch');
      swatch.style.background = model.colorHex;

      const span = document.createElement('span');
      span.textContent = model.id;

      item.appendChild(swatch);
      item.appendChild(span);

      item.addEventListener('click', () => {
        isNewMode = false;
        selectedId = model.id;
        activeTab = 'general';
        // Re-read from ProjectContext so we get the latest data
        const entry = ProjectContext.files.resources.get(model.id + '.tres');
        if (entry) {
          editingModel = ResourceDefModel.fromEntry(model.id + '.tres', entry);
        } else {
          editingModel = model;
        }
        _updateListSelection();
        _renderDetail();
      });

      listItems.appendChild(item);
    }
  }

  /**
   * Update the .active class on list items without full re-render.
   * @returns {void}
   */
  function _updateListSelection() {
    for (const el of listItems.querySelectorAll('.editor-list-item')) {
      el.classList.toggle('active', !isNewMode && el.dataset.id === selectedId);
    }
  }

  // --- Detail panel rendering ---

  /**
   * Show the empty state in the detail panel.
   * @returns {void}
   */
  function _showEmpty() {
    detailPanel.innerHTML = '';
    const empty = document.createElement('div');
    empty.classList.add('editor-detail-empty');
    empty.textContent = 'Select a resource';
    detailPanel.appendChild(empty);
  }

  /**
   * Render the detail panel for the currently selected / new resource.
   * @returns {void}
   */
  function _renderDetail() {
    detailPanel.innerHTML = '';

    if (!editingModel) {
      _showEmpty();
      return;
    }

    const model = editingModel;
    const isNew = isNewMode;

    // Wrap in a form for collectFormData compatibility
    const form = document.createElement('form');
    form.style.cssText = 'display:flex;flex-direction:column;height:100%;';
    form.addEventListener('submit', (e) => e.preventDefault());

    // --- Header ---
    const header = document.createElement('div');
    header.classList.add('editor-detail-header');

    const h3 = document.createElement('h3');
    const headerSwatch = document.createElement('div');
    headerSwatch.classList.add('swatch');
    headerSwatch.style.cssText = `width:14px;height:14px;border-radius:2px;border:1px solid var(--border);background:${model.colorHex};`;
    const headerName = document.createElement('span');
    headerName.textContent = isNew ? 'New Resource' : model.id;
    h3.appendChild(headerSwatch);
    h3.appendChild(headerName);

    const btnGroup = document.createElement('div');
    btnGroup.classList.add('btn-group');

    const saveBtn = document.createElement('button');
    saveBtn.textContent = 'Save';
    saveBtn.type = 'button';
    saveBtn.classList.add('editor-btn-save');

    const deleteBtn = document.createElement('button');
    deleteBtn.textContent = 'Delete';
    deleteBtn.type = 'button';
    deleteBtn.classList.add('editor-btn-delete');

    btnGroup.appendChild(saveBtn);
    if (!isNew) {
      btnGroup.appendChild(deleteBtn);
    }

    header.appendChild(h3);
    header.appendChild(btnGroup);
    form.appendChild(header);

    // --- Error area ---
    const errorArea = document.createElement('div');
    errorArea.style.cssText = 'display:none;padding:6px 10px;margin:4px 12px 0;background:#4a1c1c;border:1px solid #7a3030;border-radius:4px;color:#ff9999;font-size:12px;';
    form.appendChild(errorArea);

    // --- Sub-tabs ---
    const tabsRow = document.createElement('div');
    tabsRow.classList.add('editor-detail-tabs');

    const generalTab = document.createElement('button');
    generalTab.textContent = 'General';
    generalTab.type = 'button';
    generalTab.classList.add('editor-detail-tab');
    if (activeTab === 'general') generalTab.classList.add('active');

    const visualsTab = document.createElement('button');
    visualsTab.textContent = 'Visuals';
    visualsTab.type = 'button';
    visualsTab.classList.add('editor-detail-tab');
    if (activeTab === 'visuals') visualsTab.classList.add('active');

    generalTab.addEventListener('click', () => {
      activeTab = 'general';
      _renderTabBody(body, model, isNew);
      generalTab.classList.add('active');
      visualsTab.classList.remove('active');
    });

    visualsTab.addEventListener('click', () => {
      activeTab = 'visuals';
      _renderTabBody(body, model, isNew);
      visualsTab.classList.remove('active');
      generalTab.classList.remove('active');
      visualsTab.classList.add('active');
    });

    tabsRow.appendChild(generalTab);
    tabsRow.appendChild(visualsTab);
    form.appendChild(tabsRow);

    // --- Body ---
    const body = document.createElement('div');
    body.classList.add('editor-detail-body');
    _renderTabBody(body, model, isNew);
    form.appendChild(body);

    detailPanel.appendChild(form);

    // --- Save handler ---
    saveBtn.addEventListener('click', () => {
      const collected = collectFormData(form);
      collected._filename = isNew ? collected.id + '.tres' : model._filename;
      collected._raw = model._raw;

      const validation = validateResourceForm(collected, isNew);
      if (!validation.valid) {
        errorArea.style.display = 'block';
        errorArea.textContent = validation.errors.join('; ');
        return;
      }

      if (isNew) {
        const cmd = new CreateResourceDefCommand(collected, cmdHistory);
        if (cmdHistory) {
          cmdHistory.execute(cmd);
        } else {
          cmd.execute();
        }
        // Switch to editing the newly created resource
        isNewMode = false;
        selectedId = collected.id;
        activeTab = 'general';
        const entry = ProjectContext.files.resources.get(collected.id + '.tres');
        if (entry) {
          editingModel = ResourceDefModel.fromEntry(collected.id + '.tres', entry);
        }
      } else {
        const cmd = new EditResourceDefCommand(model._filename, model, collected, cmdHistory);
        if (cmdHistory) {
          cmdHistory.execute(cmd);
        } else {
          cmd.execute();
        }
        // Refresh the editing model from ProjectContext
        const entry = ProjectContext.files.resources.get(model._filename);
        if (entry) {
          editingModel = ResourceDefModel.fromEntry(model._filename, entry);
        }
      }

      refreshList();
      _renderDetail();
      onChange();
    });

    // --- Delete handler ---
    deleteBtn.addEventListener('click', () => {
      const usages = findResourceUsage(model.id);
      if (usages.length > 0) {
        const usageList = usages.map(u => `${u.map} (${u.count} ref${u.count > 1 ? 's' : ''})`).join(', ');
        showInlineModal(
          `Resource "${model.id}" is referenced in: ${usageList}. Type "DELETE" to confirm deletion:`,
          '',
          (val) => {
            if (val === 'DELETE') {
              _doDelete(model);
            }
          }
        );
      } else {
        if (confirm(`Delete resource "${model.id}"? This cannot be undone without undo.`)) {
          _doDelete(model);
        }
      }
    });
  }

  /**
   * Execute delete and update UI.
   * @param {ResourceDefModel} model
   * @returns {void}
   */
  function _doDelete(model) {
    const cmd = new DeleteResourceDefCommand(model._filename, model, cmdHistory);
    if (cmdHistory) {
      cmdHistory.execute(cmd);
    } else {
      cmd.execute();
    }
    selectedId = null;
    editingModel = null;
    isNewMode = false;
    refreshList();
    _showEmpty();
    onChange();
  }

  /**
   * Render the active tab content into the body element.
   * Reads current form values first so switching tabs preserves edits.
   * @param {HTMLElement} body
   * @param {ResourceDefModel} model
   * @param {boolean} isNew
   * @returns {void}
   */
  function _renderTabBody(body, model, isNew) {
    // Before clearing, collect current form data to preserve edits across tab switches.
    // Only overwrite fields whose inputs exist in the current tab's DOM.
    const form = body.closest('form');
    if (form && body.children.length > 0) {
      try {
        const partial = collectFormData(form);
        // General tab fields
        const generalFields = ['id', 'display_name', 'prop_category', 'prop_origin',
          'gather_time', 'gather_amount',
          'tool_required', 'respawn_time', 'yield_type', 'tool_speed',
          'max_stack', 'category', 'catalog_entry', 'catalog_category'];
        // Visuals tab fields
        const visualFields = ['placeholder_mesh_type', 'placeholder_params',
          'placeholder_color', 'placeholder_depleted_type',
          'placeholder_depleted_params', 'placeholder_depleted_color'];
        // activeTab is already set to the NEW tab, so collect the OLD tab's fields
        // (the ones still in the DOM) onto the model
        const oldTabFields = activeTab === 'general' ? visualFields : generalFields;
        for (const f of oldTabFields) {
          model[f] = partial[f];
        }
      } catch (_e) {
        // ignore collection errors
      }
    }

    body.innerHTML = '';

    if (activeTab === 'general') {
      _renderGeneralTab(body, model, isNew);
    } else {
      _renderVisualsTab(body, model);
    }
  }

  /**
   * Render the General tab content.
   * @param {HTMLElement} body
   * @param {ResourceDefModel} model
   * @param {boolean} isNew
   * @returns {void}
   */
  function _renderGeneralTab(body, model, isNew) {
    const grid = document.createElement('div');
    grid.classList.add('prop-grid');

    // ID
    _addField(grid, 'ID', 'id', 'text', model.id, isNew ? { pattern: '^[a-zA-Z0-9_]+$' } : { disabled: '' });
    // Display Name
    _addField(grid, 'Display Name', 'display_name', 'text', model.display_name);

    // -- Placement Defaults (editor-only) --
    _addSeparator(grid, 'Placement Defaults');
    _addOriginCategoryFields(grid, model);

    // -- Gathering separator --
    _addSeparator(grid, 'Gathering');
    _addField(grid, 'Gather Time', 'gather_time', 'number', model.gather_time, { step: 'any', min: '0' });
    _addField(grid, 'Gather Amount', 'gather_amount', 'number', model.gather_amount, { step: '1', min: '0' });
    _addField(grid, 'Tool Required', 'tool_required', 'text', model.tool_required);
    _addField(grid, 'Respawn Time', 'respawn_time', 'number', model.respawn_time, { step: 'any', min: '0' });
    _addField(grid, 'Yield Type', 'yield_type', 'text', model.yield_type);
    grid.appendChild(_createKvEditor('tool_speed', model.tool_speed));

    // -- Inventory separator --
    _addSeparator(grid, 'Inventory');
    _addField(grid, 'Max Stack', 'max_stack', 'number', model.max_stack, { step: '1', min: '1' });
    _addField(grid, 'Category', 'category', 'text', model.category);

    // -- Catalog separator --
    _addSeparator(grid, 'Catalog');
    _addField(grid, 'Catalog Entry', 'catalog_entry', 'text', model.catalog_entry);
    _addField(grid, 'Catalog Cat', 'catalog_category', 'text', model.catalog_category);

    body.appendChild(grid);
  }

  /**
   * Render the Visuals tab content.
   * @param {HTMLElement} body
   * @param {ResourceDefModel} model
   * @returns {void}
   */
  function _renderVisualsTab(body, model) {
    const grid = document.createElement('div');
    grid.classList.add('prop-grid');

    _addField(grid, 'Mesh Type', 'placeholder_mesh_type', 'text', model.placeholder_mesh_type);
    grid.appendChild(_createKvEditor('placeholder_params', model.placeholder_params));
    grid.appendChild(_createColorField('Color', 'placeholder_color', model.placeholder_color));

    // -- Depleted separator --
    _addSeparator(grid, 'Depleted');
    _addField(grid, 'Depleted Mesh', 'placeholder_depleted_type', 'text', model.placeholder_depleted_type);
    grid.appendChild(_createKvEditor('placeholder_depleted_params', model.placeholder_depleted_params));
    grid.appendChild(_createColorField('Depleted Color', 'placeholder_depleted_color', model.placeholder_depleted_color));

    body.appendChild(grid);
  }

  // --- Wire up events ---
  filterInput.addEventListener('input', () => refreshList());

  newBtn.addEventListener('click', () => {
    isNewMode = true;
    selectedId = null;
    editingModel = new ResourceDefModel();
    activeTab = 'general';
    _updateListSelection();
    _renderDetail();
  });

  // --- Initial render ---
  refreshList();
  _showEmpty();
}

// ============================================================
// Prop-Grid Field Helpers
// ============================================================

/**
 * Add a label + input row to a prop-grid.
 * @param {HTMLElement} grid
 * @param {string} labelText
 * @param {string} name
 * @param {string} type
 * @param {string|number} value
 * @param {Object} [attrs]
 * @returns {void}
 */
function _addField(grid, labelText, name, type, value, attrs) {
  const label = document.createElement('label');
  label.textContent = labelText;
  label.classList.add('prop-label');

  const input = document.createElement('input');
  input.type = type;
  input.name = name;
  input.value = String(value);
  input.classList.add('prop-input');
  if (attrs) {
    for (const [k, v] of Object.entries(attrs)) {
      input.setAttribute(k, String(v));
    }
  }

  grid.appendChild(label);
  grid.appendChild(input);
}

/**
 * Add a separator row with optional label to a prop-grid.
 * @param {HTMLElement} grid
 * @param {string} [text]
 * @returns {void}
 */
function _addSeparator(grid, text) {
  const sep = document.createElement('div');
  sep.classList.add('prop-separator');
  if (text) {
    sep.style.cssText = 'font-size:10px;color:var(--text-secondary);text-transform:uppercase;letter-spacing:0.5px;padding-top:8px;border-top:1px solid var(--border);margin:6px 0;';
    sep.textContent = text;
  }
  grid.appendChild(sep);
}

/**
 * Add a label + select dropdown row to a prop-grid.
 * @param {HTMLElement} grid
 * @param {string} labelText
 * @param {string} name
 * @param {string} value - Currently selected value
 * @param {string[]} options - Available option values
 * @returns {void}
 */
function _addSelectField(grid, labelText, name, value, options) {
  const label = document.createElement('label');
  label.textContent = labelText;
  label.classList.add('prop-label');
  const select = document.createElement('select');
  select.name = name;
  select.classList.add('prop-input');
  for (const opt of options) {
    const option = document.createElement('option');
    option.value = opt;
    option.textContent = opt;
    if (opt === value) option.selected = true;
    select.appendChild(option);
  }
  grid.appendChild(label);
  grid.appendChild(select);
}

/** Natural category names. */
const _NATURAL_CAT_NAMES = CATEGORIES.filter((_, i) => NATURAL_CATEGORIES.has(i));
/** Non-natural category names. */
const _NON_NATURAL_CAT_NAMES = CATEGORIES.filter((_, i) => !NATURAL_CATEGORIES.has(i));

/**
 * Add linked Origin → Category dropdowns to the prop-grid.
 * Changing origin resets category to the first valid option.
 * Natural origin → natural categories only; other origins → non-natural only.
 * @param {HTMLElement} grid
 * @param {ResourceDefModel} model
 * @returns {void}
 */
function _addOriginCategoryFields(grid, model) {
  // Origin
  const originLabel = document.createElement('label');
  originLabel.textContent = 'Origin';
  originLabel.classList.add('prop-label');
  const originSelect = document.createElement('select');
  originSelect.name = 'prop_origin';
  originSelect.classList.add('prop-input');
  for (const o of ORIGINS) {
    const opt = document.createElement('option');
    opt.value = o;
    opt.textContent = o;
    if (o === model.prop_origin) opt.selected = true;
    originSelect.appendChild(opt);
  }
  grid.appendChild(originLabel);
  grid.appendChild(originSelect);

  // Category
  const catLabel = document.createElement('label');
  catLabel.textContent = 'Prop Category';
  catLabel.classList.add('prop-label');
  const catSelect = document.createElement('select');
  catSelect.name = 'prop_category';
  catSelect.classList.add('prop-input');
  grid.appendChild(catLabel);
  grid.appendChild(catSelect);

  /** Rebuild category options based on origin. */
  function _refreshCategories() {
    const origin = originSelect.value;
    const allowed = origin === 'natural' ? _NATURAL_CAT_NAMES : _NON_NATURAL_CAT_NAMES;
    const prev = catSelect.value;
    catSelect.innerHTML = '';
    for (const c of allowed) {
      const opt = document.createElement('option');
      opt.value = c;
      opt.textContent = c;
      if (c === prev) opt.selected = true;
      catSelect.appendChild(opt);
    }
    // If previous value not in new list, select first
    if (!allowed.includes(prev) && allowed.length > 0) {
      catSelect.value = allowed[0];
    }
  }

  _refreshCategories();
  originSelect.addEventListener('change', _refreshCategories);
}

// ============================================================
// Form Data Collection
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

  // Placement defaults (editor-only)
  model.prop_category = val('prop_category') || 'plant';
  model.prop_origin = val('prop_origin') || 'natural';

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
// Form Validation
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
// Model -> TresFile Serialization
// ============================================================

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
// Command Classes
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
    this.tab = 'props';
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
    this.tab = 'props';
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
    this.tab = 'props';
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
// Delete Validation — Usage Scan
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
        count += tile.props.filter(p => p.type === resourceId).length;
      }
    }
    if (count > 0) usages.push({ map: mapName, count });
  }
  return usages;
}
