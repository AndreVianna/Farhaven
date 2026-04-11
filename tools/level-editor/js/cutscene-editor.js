// ============================================================
// CutsceneEditor — Master-Detail Split Layout (task-077)
// ============================================================
//
// CRUD editor for CutsceneDef .tres files. Follows the same
// master-detail pattern as event-editor.js and recipe-editor.js,
// but CutsceneDef has no sub_resources, so serialization is
// much simpler.
//
// Fields (from scripts/data/cutscene_def.gd):
//   - id              StringName   C-prefixed (e.g. C00001)
//   - display_name    String
//   - short_description String (from Gear base)
//   - long_description  String (from Gear base)
//   - video_path      String       path relative to res://
//   - trigger_event   StringName   id of a GameEvent (or "")
//   - duration_seconds int
//
// ============================================================

import { ProjectContext, FileDiscovery, nextId } from './file-discovery.js';
import { TresParser, TresFile } from './tres-parser.js';
import { renderGearHeader } from './editor-common.js';

// ============================================================
// CutsceneModel
// ============================================================

/**
 * Editable JS model for a CutsceneDef .tres file.
 */
export class CutsceneModel {
  constructor() {
    /** @type {string} ID e.g. 'C00001' */
    this.id = '';
    /** @type {string} */
    this.display_name = '';
    /** @type {string} */
    this.short_description = '';
    /** @type {string} */
    this.long_description = '';
    /** @type {string} path relative to res:// */
    this.video_path = '';
    /** @type {string} ID of a GameEvent (empty string = none) */
    this.trigger_event = '';
    /** @type {number} */
    this.duration_seconds = 0;

    // Round-trip metadata
    /** @type {string} */
    this._filename = '';
    /** @type {TresFile|null} */
    this._raw = null;
  }

  /**
   * Create a CutsceneModel from a ProjectContext cutscene entry.
   * @param {string} filename - e.g. 'C00001.tres'
   * @param {{data: Object, raw: TresFile}} entry
   * @returns {CutsceneModel}
   */
  static fromEntry(filename, entry) {
    const model = new CutsceneModel();
    model._filename = filename;
    model._raw = entry.raw;

    const d = entry.data || {};
    model.id = _str(d.id);
    model.display_name = _str(d.display_name);
    model.short_description = _str(d.short_description);
    model.long_description = _str(d.long_description);
    model.video_path = _str(d.video_path);
    model.trigger_event = _str(d.trigger_event);
    model.duration_seconds = _int(d.duration_seconds);

    return model;
  }
}

// ============================================================
// Internal helpers
// ============================================================

function _str(val) {
  if (val == null) return '';
  if (typeof val === 'object' && 'value' in val) return String(val.value);
  return String(val);
}

function _int(val) {
  if (val == null) return 0;
  if (typeof val === 'number') return val | 0;
  const n = parseInt(String(val), 10);
  return isNaN(n) ? 0 : n;
}

// ============================================================
// Form Data Collection
// ============================================================

/**
 * Collect cutscene form data from the form element into a CutsceneModel.
 * @param {HTMLFormElement} formElement
 * @returns {CutsceneModel}
 */
export function collectCutsceneFormData(formElement) {
  const model = new CutsceneModel();

  function val(name) {
    const el = formElement.querySelector(`[name="${name}"]`);
    return el ? /** @type {HTMLInputElement} */ (el).value : '';
  }

  function intVal(name) {
    const v = parseInt(val(name), 10);
    return isNaN(v) ? 0 : v;
  }

  model.id = val('id').trim();
  model.display_name = val('display_name').trim();
  model.short_description = val('short_description').trim();
  model.long_description = val('long_description').trim();
  model.video_path = val('video_path').trim();
  model.trigger_event = val('trigger_event').trim();
  model.duration_seconds = intVal('duration_seconds');

  return model;
}

// ============================================================
// Validation
// ============================================================

/**
 * Validate a cutscene model. Enforces C-prefix on ids.
 * @param {CutsceneModel} model
 * @param {boolean} isNew
 * @returns {{valid: boolean, errors: string[]}}
 */
export function validateCutsceneForm(model, isNew) {
  const errors = [];

  if (!model.id) {
    errors.push('ID is required');
  } else if (!/^[a-zA-Z0-9_]+$/.test(model.id)) {
    errors.push('ID must contain only alphanumeric characters and underscores');
  } else if (!model.id.startsWith('C')) {
    errors.push('Cutscene ID must start with "C" (e.g. C00001)');
  } else if (isNew && ProjectContext.files.cutscenes.has(model.id + '.tres')) {
    errors.push(`Cutscene "${model.id}" already exists`);
  }

  if (!model.display_name) {
    errors.push('Display Name is required');
  }

  if (model.duration_seconds < 0) {
    errors.push('Duration must be >= 0');
  }

  // trigger_event may be empty (meaning "no trigger") but if set must look like an ID.
  if (model.trigger_event && !/^[a-zA-Z0-9_]+$/.test(model.trigger_event)) {
    errors.push('Trigger Event must be a valid ID');
  }

  return { valid: errors.length === 0, errors };
}

// ============================================================
// Model -> TresFile Serialization
// ============================================================

/**
 * Convert a model to a plain object for dirty comparison.
 * @param {CutsceneModel} model
 * @returns {Object}
 */
function _modelToPlain(model) {
  return {
    id: model.id,
    display_name: model.display_name,
    short_description: model.short_description,
    long_description: model.long_description,
    video_path: model.video_path,
    trigger_event: model.trigger_event,
    duration_seconds: model.duration_seconds,
  };
}

/**
 * Update a TresFile's resourceFields from a CutsceneModel. For new cutscenes,
 * creates a fresh TresFile. CutsceneDef has no sub_resources — this is just
 * a flat [resource] section plus the script ext_resource.
 * @param {CutsceneModel} model
 * @returns {TresFile}
 */
export function cutsceneModelToRaw(model) {
  let raw;
  if (model._raw) {
    raw = model._raw;
  } else {
    raw = new TresFile();
    raw.scriptClass = 'CutsceneDef';
    raw.lineEnding = '\n';
  }

  const scriptExtId = '1_cutscene';
  const extResources = [
    `[ext_resource type="Script" path="res://scripts/data/cutscene_def.gd" id="${scriptExtId}"]`,
  ];
  const subResources = [];

  // load_steps = extResources + subResources + 1 (main [resource] block).
  // Matches the ecosystem convention used by journal-editor.js and fixture .tres files.
  const loadSteps = extResources.length + subResources.length + 1;
  raw.headerLine = `[gd_resource type="Resource" script_class="CutsceneDef" load_steps=${loadSteps} format=3]`;
  raw.extResources = extResources;
  raw.subResources = subResources;

  const fields = new Map();
  fields.set('script', { type: 'ext_resource', value: `ExtResource("${scriptExtId}")` });
  fields.set('id', { type: 'stringname', value: model.id });
  fields.set('display_name', { type: 'string', value: model.display_name });

  if (model.short_description) {
    fields.set('short_description', { type: 'string', value: model.short_description });
  }
  if (model.long_description) {
    fields.set('long_description', { type: 'string', value: model.long_description });
  }

  // video_path — always serialized (empty string allowed during authoring).
  fields.set('video_path', { type: 'string', value: model.video_path || '' });

  // trigger_event — only serialized if non-empty (matches GDScript default).
  if (model.trigger_event) {
    fields.set('trigger_event', { type: 'stringname', value: model.trigger_event });
  }

  // duration_seconds — always serialized so the author's 0 is explicit.
  fields.set('duration_seconds', { type: 'int', value: model.duration_seconds });

  // Preserve any unknown fields from the original .tres file.
  if (model._raw && model._raw.resourceFields instanceof Map) {
    for (const [key, value] of model._raw.resourceFields) {
      if (!fields.has(key)) {
        fields.set(key, value);
      }
    }
  }

  raw.resourceFields = fields;
  return raw;
}

// ============================================================
// Command Classes
// ============================================================

export class CreateCutsceneCommand {
  constructor(model) {
    this._model = model;
    this._filename = model.id + '.tres';
    this.tab = 'cutscenes';
    this.type = 'CreateCutscene';
  }

  execute() {
    const raw = cutsceneModelToRaw(this._model);
    const content = TresParser.serialize(raw);

    const data = {};
    for (const [key, tv] of raw.resourceFields) {
      data[key] = tv.value;
    }

    ProjectContext.files.cutscenes.set(this._filename, {
      handle: null,
      dir: 'data/cutscenes',
      data,
      raw,
    });

    FileDiscovery.saveFile('data/cutscenes', content, this._filename).catch((err) => {
      console.warn(`CreateCutsceneCommand: Failed to save "${this._filename}": ${err.message}`);
    });
  }

  undo() {
    ProjectContext.files.cutscenes.delete(this._filename);
  }
}

export class EditCutsceneCommand {
  constructor(filename, oldModel, newModel) {
    this._filename = filename;
    this._oldModel = oldModel;
    this._newModel = newModel;
    this._oldRaw = oldModel ? oldModel._raw : null;
    this.tab = 'cutscenes';
    this.type = 'EditCutscene';
  }

  execute() {
    const raw = cutsceneModelToRaw(this._newModel);
    const content = TresParser.serialize(raw);

    const data = {};
    for (const [key, tv] of raw.resourceFields) {
      data[key] = tv.value;
    }

    const entry = ProjectContext.files.cutscenes.get(this._filename);
    if (entry) {
      entry.data = data;
      entry.raw = raw;
    }

    FileDiscovery.saveFile('data/cutscenes', content, this._filename).catch((err) => {
      console.warn(`EditCutsceneCommand: Failed to save "${this._filename}": ${err.message}`);
    });
  }

  undo() {
    if (this._oldRaw) {
      const entry = ProjectContext.files.cutscenes.get(this._filename);
      if (entry) {
        entry.raw = this._oldRaw;
        const data = {};
        for (const [key, tv] of this._oldRaw.resourceFields) {
          data[key] = tv.value;
        }
        entry.data = data;
      }
      const content = TresParser.serialize(this._oldRaw);
      FileDiscovery.saveFile('data/cutscenes', content, this._filename).catch((err) => {
        console.warn(`EditCutsceneCommand.undo: Failed to save "${this._filename}": ${err.message}`);
      });
    }
  }
}

export class DeleteCutsceneCommand {
  constructor(filename, model) {
    this._filename = filename;
    this._model = model;
    this._savedEntry = null;
    this.tab = 'cutscenes';
    this.type = 'DeleteCutscene';
  }

  execute() {
    this._savedEntry = ProjectContext.files.cutscenes.get(this._filename) || null;
    ProjectContext.files.cutscenes.delete(this._filename);
    // Intentionally DO NOT write an empty file to disk — that would corrupt
    // the .tres and break the next scan. ProjectContext is the in-memory
    // source of truth; the stale file on disk remains until the user
    // removes it manually or the editor gains a dedicated DELETE endpoint.
    // Mirrors DeleteJournalCommand behavior.
  }

  undo() {
    if (this._savedEntry) {
      ProjectContext.files.cutscenes.set(this._filename, this._savedEntry);
      const content = TresParser.serialize(this._savedEntry.raw);
      FileDiscovery.saveFile('data/cutscenes', content, this._filename).catch((err) => {
        console.warn(`DeleteCutsceneCommand.undo: Failed to save "${this._filename}": ${err.message}`);
      });
    }
  }
}

// ============================================================
// UI Rendering
// ============================================================

/**
 * Render the Cutscene Editor page.
 * @param {HTMLElement} container
 * @param {Object} [options]
 */
export function renderCutsceneEditor(container, options) {
  if (!container) return;
  container.innerHTML = '';

  const cmdHistory = options && options.commandHistory ? options.commandHistory : null;
  const onChange = options && typeof options.onChange === 'function' ? options.onChange : () => {};
  const onSave = options && typeof options.onSave === 'function' ? options.onSave : onChange;

  // --- Split layout ---
  const split = document.createElement('div');
  split.classList.add('editor-split');

  // --- Left panel (master list) ---
  const listPanel = document.createElement('div');
  listPanel.classList.add('editor-list-panel');

  const listHeader = document.createElement('div');
  listHeader.classList.add('editor-list-header');

  const filterInput = document.createElement('input');
  filterInput.type = 'text';
  filterInput.placeholder = 'Filter...';
  filterInput.classList.add('editor-filter');

  const newBtn = document.createElement('button');
  newBtn.textContent = '+ New Cutscene';
  newBtn.classList.add('editor-new-btn');

  listHeader.appendChild(filterInput);
  listHeader.appendChild(newBtn);
  listPanel.appendChild(listHeader);

  const listItems = document.createElement('div');
  listItems.classList.add('editor-list-items');
  listPanel.appendChild(listItems);

  // --- Right panel (detail) ---
  const detailPanel = document.createElement('div');
  detailPanel.classList.add('editor-detail-panel');

  split.appendChild(listPanel);
  split.appendChild(detailPanel);
  container.appendChild(split);

  // --- State ---
  let selectedId = null;
  let isNewMode = false;
  /** @type {CutsceneModel|null} */
  let editingModel = null;
  let initialJson = '';

  function _guardDirty() {
    if (!editingModel) return true;
    const form = detailPanel.querySelector('form');
    if (!form) return true;
    const currentData = collectCutsceneFormData(/** @type {HTMLFormElement} */ (form));
    const currentJson = JSON.stringify(_modelToPlain(currentData));
    if (currentJson !== initialJson) {
      return confirm('Discard unsaved changes?');
    }
    return true;
  }

  // --- Build the cutscene list ---
  function refreshList() {
    listItems.innerHTML = '';
    const textFilter = filterInput.value.toLowerCase().trim();

    const allCutscenes = [];
    for (const [filename, entry] of ProjectContext.files.cutscenes) {
      const model = CutsceneModel.fromEntry(filename, entry);
      allCutscenes.push({
        id: model.id,
        displayName: model.display_name || model.id,
        durationSeconds: model.duration_seconds,
      });
    }
    allCutscenes.sort((a, b) => a.id.localeCompare(b.id));

    for (const cs of allCutscenes) {
      if (textFilter
          && !cs.displayName.toLowerCase().includes(textFilter)
          && !cs.id.toLowerCase().includes(textFilter)) {
        continue;
      }

      const item = document.createElement('div');
      item.classList.add('editor-list-item');
      if (cs.id === selectedId && !isNewMode) {
        item.classList.add('active');
      }
      item.dataset.id = cs.id;

      const span = document.createElement('span');
      span.textContent = `${cs.id} — ${cs.displayName}`;
      item.appendChild(span);

      if (cs.durationSeconds > 0) {
        const badge = document.createElement('small');
        badge.textContent = `${cs.durationSeconds}s`;
        badge.style.cssText = 'margin-left:auto;font-size:10px;color:var(--text-secondary);';
        item.appendChild(badge);
      }

      item.addEventListener('click', () => {
        if (!_guardDirty()) return;
        isNewMode = false;
        selectedId = cs.id;
        const entry = ProjectContext.files.cutscenes.get(cs.id + '.tres');
        if (entry) {
          editingModel = CutsceneModel.fromEntry(cs.id + '.tres', entry);
        }
        initialJson = JSON.stringify(_modelToPlain(editingModel));
        _updateListSelection();
        _renderDetail();
      });

      listItems.appendChild(item);
    }
  }

  function _updateListSelection() {
    for (const el of listItems.querySelectorAll('.editor-list-item')) {
      el.classList.toggle('active', !isNewMode && el.dataset.id === selectedId);
    }
  }

  function _showEmpty() {
    detailPanel.innerHTML = '';
    const empty = document.createElement('div');
    empty.classList.add('editor-detail-empty');
    empty.textContent = 'Select a cutscene';
    detailPanel.appendChild(empty);
  }

  function _renderDetail() {
    detailPanel.innerHTML = '';

    if (!editingModel) {
      _showEmpty();
      return;
    }

    const model = editingModel;
    const isNew = isNewMode;

    const form = document.createElement('form');
    form.style.cssText = 'display:flex;flex-direction:column;height:100%;';
    form.addEventListener('submit', (e) => e.preventDefault());

    // --- Header ---
    const header = document.createElement('div');
    header.classList.add('editor-detail-header');

    const h3 = document.createElement('h3');
    const headerName = document.createElement('span');
    headerName.textContent = isNew ? 'New Cutscene' : `${model.id} — ${model.display_name}`;
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

    // --- Body ---
    const body = document.createElement('div');
    body.classList.add('editor-detail-body');
    body.style.cssText = 'flex:1;overflow-y:auto;';

    // --- Gear header: id / display_name / short_description | long_description ---
    renderGearHeader(body, model, { idReadonly: !isNew });

    // --- Cutscene-specific fields ---
    const csGrid = document.createElement('div');
    csGrid.classList.add('prop-grid');
    csGrid.style.cssText = 'padding:8px 12px;';

    _addVideoPathField(csGrid, 'Video Path', 'video_path', model.video_path);
    _addTriggerEventDropdown(csGrid, 'Trigger Event', 'trigger_event', model.trigger_event);
    _addField(csGrid, 'Duration (seconds)', 'duration_seconds', 'number', model.duration_seconds, { min: '0', step: '1' });

    body.appendChild(csGrid);
    form.appendChild(body);
    detailPanel.appendChild(form);

    // Recapture initialJson from the live form (reflects any defaults/normalization)
    initialJson = JSON.stringify(_modelToPlain(collectCutsceneFormData(/** @type {HTMLFormElement} */ (form))));

    // --- Save handler ---
    saveBtn.addEventListener('click', () => {
      const collected = collectCutsceneFormData(form);
      collected._filename = isNew ? collected.id + '.tres' : model._filename;
      collected._raw = isNew ? null : model._raw;

      const validation = validateCutsceneForm(collected, isNew);
      if (!validation.valid) {
        errorArea.style.display = 'block';
        errorArea.textContent = validation.errors.join('; ');
        return;
      }

      if (isNew) {
        const cmd = new CreateCutsceneCommand(collected);
        if (cmdHistory) { cmdHistory.execute(cmd); } else { cmd.execute(); }
        isNewMode = false;
        selectedId = collected.id;
        const entry = ProjectContext.files.cutscenes.get(collected.id + '.tres');
        if (entry) {
          editingModel = CutsceneModel.fromEntry(collected.id + '.tres', entry);
        }
      } else {
        const cmd = new EditCutsceneCommand(model._filename, model, collected);
        if (cmdHistory) { cmdHistory.execute(cmd); } else { cmd.execute(); }
        const entry = ProjectContext.files.cutscenes.get(model._filename);
        if (entry) {
          editingModel = CutsceneModel.fromEntry(model._filename, entry);
        }
      }

      refreshList();
      _renderDetail();
      onSave();
    });

    // --- Delete handler ---
    deleteBtn.addEventListener('click', () => {
      if (confirm(`Delete cutscene "${model.id}"? This cannot be undone without undo.`)) {
        const cmd = new DeleteCutsceneCommand(model._filename, model);
        if (cmdHistory) { cmdHistory.execute(cmd); } else { cmd.execute(); }
        selectedId = null;
        editingModel = null;
        isNewMode = false;
        refreshList();
        _showEmpty();
        onChange();
      }
    });
  }

  // --- Wire up events ---
  filterInput.addEventListener('input', () => refreshList());

  newBtn.addEventListener('click', () => {
    if (!_guardDirty()) return;
    isNewMode = true;
    selectedId = null;
    editingModel = new CutsceneModel();

    // Auto-increment ID with C prefix, scanning existing cutscenes.
    editingModel.id = nextId('C', ProjectContext.files.cutscenes);

    initialJson = JSON.stringify(_modelToPlain(editingModel));
    _updateListSelection();
    _renderDetail();
  });

  // --- Initial render ---
  refreshList();
  _showEmpty();
}

// ============================================================
// UI Field Helpers
// ============================================================

function _addField(grid, labelText, name, type, value, attrs) {
  const label = document.createElement('label');
  label.textContent = labelText;
  label.classList.add('prop-label');
  grid.appendChild(label);

  const input = document.createElement('input');
  input.type = type;
  input.name = name;
  input.value = String(value != null ? value : '');
  input.classList.add('prop-input');
  if (attrs) {
    for (const [k, v] of Object.entries(attrs)) {
      if (k === 'disabled') { input.disabled = true; }
      else { input.setAttribute(k, v); }
    }
  }
  grid.appendChild(input);
}

/**
 * Render a text input for a path relative to res:// with a hint caption.
 * No file-picker helper exists in the level editor yet, so we use a plain
 * text input and a small hint. When a shared picker lands, swap this out.
 */
function _addVideoPathField(grid, labelText, name, value) {
  const label = document.createElement('label');
  label.textContent = labelText;
  label.classList.add('prop-label');
  grid.appendChild(label);

  const wrap = document.createElement('div');
  wrap.style.cssText = 'display:flex;flex-direction:column;gap:2px;';

  const input = document.createElement('input');
  input.type = 'text';
  input.name = name;
  input.value = String(value != null ? value : '');
  input.placeholder = 'media/cutscenes/intro.ogv';
  input.classList.add('prop-input');
  wrap.appendChild(input);

  const hint = document.createElement('small');
  hint.textContent = 'Path relative to res:// (e.g. media/cutscenes/intro.ogv). May be empty during authoring.';
  hint.style.cssText = 'font-size:10px;color:var(--text-secondary);';
  wrap.appendChild(hint);

  grid.appendChild(wrap);
}

/**
 * Render a dropdown populated from ProjectContext.files.events. Includes a
 * "(none)" option mapped to empty string (meaning "no trigger").
 */
function _addTriggerEventDropdown(grid, labelText, name, value) {
  const label = document.createElement('label');
  label.textContent = labelText;
  label.classList.add('prop-label');
  grid.appendChild(label);

  const select = document.createElement('select');
  select.name = name;
  select.classList.add('prop-input');

  const noneOpt = document.createElement('option');
  noneOpt.value = '';
  noneOpt.textContent = '(none)';
  if (!value) noneOpt.selected = true;
  select.appendChild(noneOpt);

  // Collect event IDs from ProjectContext.files.events. The map keys are
  // filenames (e.g. "E00001.tres"), but the displayed ID is the model.id.
  const eventIds = [];
  for (const [, entry] of ProjectContext.files.events) {
    const d = entry && entry.data ? entry.data : {};
    const id = d.id != null ? String(d.id.value != null ? d.id.value : d.id) : '';
    const displayName = d.display_name != null
      ? String(d.display_name.value != null ? d.display_name.value : d.display_name)
      : '';
    if (id) {
      eventIds.push({ id, displayName });
    }
  }
  eventIds.sort((a, b) => a.id.localeCompare(b.id));

  // If the current value isn't in the known list (e.g. dangling reference),
  // add it so it stays selected and visible to the author.
  let valueFound = !value;
  for (const e of eventIds) {
    const opt = document.createElement('option');
    opt.value = e.id;
    opt.textContent = e.displayName ? `${e.id} — ${e.displayName}` : e.id;
    if (e.id === value) { opt.selected = true; valueFound = true; }
    select.appendChild(opt);
  }
  if (!valueFound && value) {
    const opt = document.createElement('option');
    opt.value = value;
    opt.textContent = `${value} (not found)`;
    opt.selected = true;
    select.appendChild(opt);
  }

  grid.appendChild(select);
}
