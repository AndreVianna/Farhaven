// ============================================================
// JournalEditor — Master-Detail Split Layout (task-076)
// ============================================================
//
// JournalEntry is a flat Gear-derived resource (no sub_resources).
// Fields:
//   - id (stringname, J-prefix)        ← from Gear
//   - display_name (string)            ← from Gear
//   - short_description (string)       ← from Gear (teaser / tooltip hook)
//   - long_description (string)        ← from Gear (summary)
//   - body (multi-line string)         ← JournalEntry's own long-form text
//   - category (stringname)            ← JournalEntry
//   - day_added (int)                  ← JournalEntry
//
// See scripts/journal/journal_entry.gd for the authoritative shape.
// ============================================================

import { ProjectContext, FileDiscovery, nextId } from './file-discovery.js';
import { TresParser, TresFile } from './tres-parser.js';
import { renderGearHeader } from './editor-common.js';

// ============================================================
// Constants
// ============================================================

/** Valid category StringNames (matches scripts/journal/journal_entry.gd defaults). */
export const JOURNAL_CATEGORIES = ['chapter', 'lore', 'tutorial'];

// ============================================================
// JournalModel
// ============================================================

/**
 * Maps a parsed .tres JournalEntry to an editable JS model.
 */
export class JournalModel {
  constructor() {
    /** @type {string} ID e.g. 'J00001' */
    this.id = '';
    /** @type {string} */
    this.display_name = '';
    /** @type {string} */
    this.short_description = '';
    /** @type {string} */
    this.long_description = '';
    /** @type {string} Multi-line body — the full journal page text */
    this.body = '';
    /** @type {string} Category StringName — one of JOURNAL_CATEGORIES */
    this.category = 'lore';
    /** @type {number} In-game day on which this entry becomes unlockable */
    this.day_added = 0;

    // Round-trip metadata
    /** @type {string} */
    this._filename = '';
    /** @type {TresFile|null} */
    this._raw = null;
  }

  /**
   * Create a JournalModel from a ProjectContext journal entry.
   * @param {string} filename - e.g. 'J00001.tres'
   * @param {{data: Object, raw: TresFile}} entry
   * @returns {JournalModel}
   */
  static fromEntry(filename, entry) {
    const model = new JournalModel();
    model._filename = filename;
    model._raw = entry.raw;

    const d = entry.data || {};
    model.id = _str(d.id);
    model.display_name = _str(d.display_name);
    model.short_description = _str(d.short_description);
    model.long_description = _str(d.long_description);
    // Body is escaped on disk (real newlines can't appear in a line-based .tres
    // field), so decode escape sequences when loading into the model.
    model.body = unescapeTresString(_str(d.body));
    model.category = _str(d.category) || 'lore';
    model.day_added = _int(d.day_added);

    return model;
  }
}

// ============================================================
// Internal Helpers
// ============================================================

/**
 * Escape a string for storage inside a line-oriented .tres field.
 * The TresParser is strictly line-based — a real newline inside a string
 * value would break `[resource]` parsing. So we encode:
 *   "\\" -> "\\\\"     (backslash)
 *   "\n" -> "\\n"      (newline)
 *   "\r" -> "\\r"      (carriage return)
 *   "\"" -> "\\\""     (quote)
 * Mirrors Godot's own .tres string escaping for multi-line strings.
 * @param {string} s
 * @returns {string}
 */
export function escapeTresString(s) {
  if (s == null) return '';
  return String(s)
    .replace(/\\/g, '\\\\')
    .replace(/\r/g, '\\r')
    .replace(/\n/g, '\\n')
    .replace(/"/g, '\\"');
}

/**
 * Inverse of escapeTresString.
 * @param {string} s
 * @returns {string}
 */
export function unescapeTresString(s) {
  if (s == null) return '';
  // Single pass to avoid double-expanding sequences.
  let out = '';
  const str = String(s);
  for (let i = 0; i < str.length; i++) {
    const ch = str[i];
    if (ch === '\\' && i + 1 < str.length) {
      const next = str[i + 1];
      if (next === 'n') { out += '\n'; i++; continue; }
      if (next === 'r') { out += '\r'; i++; continue; }
      if (next === 't') { out += '\t'; i++; continue; }
      if (next === '"') { out += '"'; i++; continue; }
      if (next === '\\') { out += '\\'; i++; continue; }
      // Unknown escape — pass through as-is.
      out += ch;
    } else {
      out += ch;
    }
  }
  return out;
}

function _str(val) {
  if (val == null) return '';
  if (typeof val === 'object' && 'value' in val) return String(val.value);
  return String(val);
}

function _int(val) {
  if (typeof val === 'number') return Math.trunc(val);
  if (val && typeof val === 'object' && 'value' in val) {
    const n = parseInt(String(val.value), 10);
    return isNaN(n) ? 0 : n;
  }
  const n = parseInt(String(val), 10);
  return isNaN(n) ? 0 : n;
}

// ============================================================
// Form Data Collection
// ============================================================

/**
 * Collect journal form data from the form element into a JournalModel.
 * @param {HTMLFormElement} formElement
 * @returns {JournalModel}
 */
export function collectJournalFormData(formElement) {
  const model = new JournalModel();

  function val(name) {
    const el = formElement.querySelector(`[name="${name}"]`);
    return el ? /** @type {HTMLInputElement|HTMLTextAreaElement|HTMLSelectElement} */ (el).value : '';
  }

  function intVal(name) {
    const v = parseInt(val(name), 10);
    return isNaN(v) ? 0 : v;
  }

  model.id = val('id').trim();
  model.display_name = val('display_name').trim();
  model.short_description = val('short_description').trim();
  model.long_description = val('long_description').trim();
  // NOTE: body is multi-line — preserve internal newlines, just trim outer whitespace.
  model.body = val('body').replace(/^\n+|\n+$/g, '');
  model.category = val('category').trim() || 'lore';
  model.day_added = intVal('day_added');

  return model;
}

// ============================================================
// Form Validation
// ============================================================

/**
 * Validate a journal model.
 * @param {JournalModel} model
 * @param {boolean} isNew
 * @returns {{ valid: boolean, errors: string[] }}
 */
export function validateJournalForm(model, isNew) {
  const errors = [];

  if (!model.id) {
    errors.push('ID is required');
  } else if (!/^[a-zA-Z0-9_]+$/.test(model.id)) {
    errors.push('ID must contain only alphanumeric characters and underscores');
  } else if (!model.id.startsWith('J')) {
    errors.push('Journal ID must start with "J" (e.g. J00001)');
  } else if (isNew && ProjectContext.files.journal.has(model.id + '.tres')) {
    errors.push(`Journal entry "${model.id}" already exists`);
  }

  if (!model.display_name) {
    errors.push('Display Name is required');
  }

  if (!JOURNAL_CATEGORIES.includes(model.category)) {
    errors.push(`Category must be one of: ${JOURNAL_CATEGORIES.join(', ')}`);
  }

  if (!Number.isFinite(model.day_added) || model.day_added < 0) {
    errors.push('Day Added must be a non-negative integer');
  }

  return { valid: errors.length === 0, errors };
}

// ============================================================
// Model <-> TresFile Serialization
// ============================================================

/**
 * Convert a model to a plain object for dirty comparison.
 * @param {JournalModel} model
 * @returns {Object}
 */
function _modelToPlain(model) {
  return {
    id: model.id,
    display_name: model.display_name,
    short_description: model.short_description,
    long_description: model.long_description,
    body: model.body,
    category: model.category,
    day_added: model.day_added,
  };
}

/**
 * Update or create a TresFile from a JournalModel.
 * JournalEntry is flat — no sub_resources, single ext_resource (the script).
 * @param {JournalModel} model
 * @returns {TresFile}
 */
export function journalModelToRaw(model) {
  let raw;

  if (model._raw) {
    raw = model._raw;
  } else {
    raw = new TresFile();
    raw.scriptClass = 'JournalEntry';
    raw.lineEnding = '\n';
  }

  // Single ext_resource: the JournalEntry script
  const scriptExtId = '1_journal';
  const extResources = [
    `[ext_resource type="Script" path="res://scripts/journal/journal_entry.gd" id="${scriptExtId}"]`,
  ];

  // Header: load_steps = 1 (script) + 0 sub_resources + 1 ([resource] itself)
  // Match the existing ecosystem convention: load_steps = extResources.length + subResources.length + 1
  // (see event .tres files: 4 ext + 3 sub => load_steps=8 — that's 4+3+1)
  const loadSteps = extResources.length + 0 + 1;
  raw.headerLine = `[gd_resource type="Resource" script_class="JournalEntry" load_steps=${loadSteps} format=3]`;
  raw.extResources = extResources;
  raw.subResources = [];

  // Build [resource] fields in a deterministic, readable order.
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

  // Body — always write it (even if empty), so the shape is stable.
  // Escape newlines so the line-based TresParser can round-trip the field.
  fields.set('body', { type: 'string', value: escapeTresString(model.body || '') });
  fields.set('category', { type: 'stringname', value: model.category || 'lore' });
  fields.set('day_added', { type: 'int', value: model.day_added | 0 });

  // Preserve any unknown fields from the original .tres (forward compat).
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

export class CreateJournalCommand {
  constructor(model) {
    this._model = model;
    this._filename = model.id + '.tres';
    this.tab = 'journal';
    this.type = 'CreateJournal';
  }

  execute() {
    const raw = journalModelToRaw(this._model);
    const content = TresParser.serialize(raw);

    const data = {};
    for (const [key, tv] of raw.resourceFields) {
      data[key] = tv.value;
    }

    ProjectContext.files.journal.set(this._filename, {
      handle: null,
      dir: 'data/journal',
      data,
      raw,
    });

    FileDiscovery.saveFile('data/journal', content, this._filename).catch((err) => {
      console.warn(`CreateJournalCommand: Failed to save "${this._filename}": ${err.message}`);
    });
  }

  undo() {
    ProjectContext.files.journal.delete(this._filename);
  }
}

export class EditJournalCommand {
  constructor(filename, oldModel, newModel) {
    this._filename = filename;
    this._oldModel = oldModel;
    this._newModel = newModel;
    this._oldRaw = oldModel && oldModel._raw ? oldModel._raw : null;
    this.tab = 'journal';
    this.type = 'EditJournal';
  }

  execute() {
    const raw = journalModelToRaw(this._newModel);
    const content = TresParser.serialize(raw);

    const data = {};
    for (const [key, tv] of raw.resourceFields) {
      data[key] = tv.value;
    }

    const entry = ProjectContext.files.journal.get(this._filename);
    if (entry) {
      entry.data = data;
      entry.raw = raw;
    }

    FileDiscovery.saveFile('data/journal', content, this._filename).catch((err) => {
      console.warn(`EditJournalCommand: Failed to save "${this._filename}": ${err.message}`);
    });
  }

  undo() {
    if (this._oldRaw) {
      const entry = ProjectContext.files.journal.get(this._filename);
      if (entry) {
        entry.raw = this._oldRaw;
        const data = {};
        for (const [key, tv] of this._oldRaw.resourceFields) {
          data[key] = tv.value;
        }
        entry.data = data;
      }
      const content = TresParser.serialize(this._oldRaw);
      FileDiscovery.saveFile('data/journal', content, this._filename).catch((err) => {
        console.warn(`EditJournalCommand.undo: Failed to save "${this._filename}": ${err.message}`);
      });
    }
  }
}

export class DeleteJournalCommand {
  constructor(filename, model) {
    this._filename = filename;
    this._model = model;
    this._savedEntry = null;
    this.tab = 'journal';
    this.type = 'DeleteJournal';
  }

  execute() {
    this._savedEntry = ProjectContext.files.journal.get(this._filename) || null;
    ProjectContext.files.journal.delete(this._filename);
  }

  undo() {
    if (this._savedEntry) {
      ProjectContext.files.journal.set(this._filename, this._savedEntry);
      if (this._savedEntry.raw) {
        const content = TresParser.serialize(this._savedEntry.raw);
        FileDiscovery.saveFile('data/journal', content, this._filename).catch((err) => {
          console.warn(`DeleteJournalCommand.undo: Failed to save "${this._filename}": ${err.message}`);
        });
      }
    }
  }
}

// ============================================================
// UI Rendering
// ============================================================

/**
 * Render the Journal Entry Editor page.
 * @param {HTMLElement} container
 * @param {Object} [options]
 */
export function renderJournalEditor(container, options) {
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
  newBtn.textContent = '+ New Journal Entry';
  newBtn.classList.add('editor-new-btn');

  listHeader.appendChild(filterInput);
  listHeader.appendChild(newBtn);
  listPanel.appendChild(listHeader);

  const listItems = document.createElement('div');
  listItems.classList.add('editor-list-items');
  listPanel.appendChild(listItems);

  // --- Right panel (detail editor) ---
  const detailPanel = document.createElement('div');
  detailPanel.classList.add('editor-detail-panel');

  split.appendChild(listPanel);
  split.appendChild(detailPanel);
  container.appendChild(split);

  // --- State ---
  let selectedId = null;
  let isNewMode = false;
  /** @type {JournalModel|null} */
  let editingModel = null;
  let initialJson = '';

  function _guardDirty() {
    if (!editingModel) return true;
    const form = detailPanel.querySelector('form');
    if (!form) return true;
    const currentData = collectJournalFormData(/** @type {HTMLFormElement} */ (form));
    const currentJson = JSON.stringify(_modelToPlain(currentData));
    if (currentJson !== initialJson) {
      return confirm('Discard unsaved changes?');
    }
    return true;
  }

  // --- Build the journal list ---
  function refreshList() {
    listItems.innerHTML = '';
    const textFilter = filterInput.value.toLowerCase().trim();

    const allEntries = [];
    for (const [filename, entry] of ProjectContext.files.journal) {
      const model = JournalModel.fromEntry(filename, entry);
      allEntries.push({
        id: model.id || filename.replace('.tres', ''),
        displayName: model.display_name || model.id || filename,
        category: model.category,
      });
    }
    allEntries.sort((a, b) => a.id.localeCompare(b.id));

    for (const je of allEntries) {
      if (textFilter
        && !je.displayName.toLowerCase().includes(textFilter)
        && !je.id.toLowerCase().includes(textFilter)) {
        continue;
      }

      const item = document.createElement('div');
      item.classList.add('editor-list-item');
      if (je.id === selectedId && !isNewMode) {
        item.classList.add('active');
      }
      item.dataset.id = je.id;

      const span = document.createElement('span');
      span.textContent = `${je.id} — ${je.displayName}`;
      item.appendChild(span);

      const badge = document.createElement('small');
      badge.textContent = je.category || 'lore';
      badge.style.cssText = 'margin-left:auto;font-size:10px;color:var(--text-secondary);';
      item.appendChild(badge);

      item.addEventListener('click', () => {
        if (!_guardDirty()) return;
        isNewMode = false;
        selectedId = je.id;
        const entry = ProjectContext.files.journal.get(je.id + '.tres');
        if (entry) {
          editingModel = JournalModel.fromEntry(je.id + '.tres', entry);
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
    empty.textContent = 'Select a journal entry';
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
    headerName.textContent = isNew ? 'New Journal Entry' : `${model.id} — ${model.display_name}`;
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
    const bodyWrap = document.createElement('div');
    bodyWrap.classList.add('editor-detail-body');
    bodyWrap.style.cssText = 'flex:1;overflow-y:auto;';

    // --- Gear base-fields header (id / display_name / short_description / long_description) ---
    renderGearHeader(bodyWrap, model, { idReadonly: !isNew });

    // --- Journal-specific fields ---
    // Two columns: left = Category + Day Added (compact), right will nest inside grid.
    const metaGrid = document.createElement('div');
    metaGrid.classList.add('prop-grid');
    metaGrid.style.cssText = 'margin:8px 12px 4px;';

    _addSeparator(metaGrid, 'Journal Metadata');
    _addSelectField(metaGrid, 'Category', 'category', model.category,
      JOURNAL_CATEGORIES.map(c => ({ value: c, label: c })));
    _addField(metaGrid, 'Day Added', 'day_added', 'number', model.day_added, { min: '0', step: '1' });
    bodyWrap.appendChild(metaGrid);

    // --- Body textarea (the full journal page text) ---
    const bodyGrid = document.createElement('div');
    bodyGrid.classList.add('prop-grid');
    bodyGrid.style.cssText = 'margin:4px 12px 12px;';
    _addSeparator(bodyGrid, 'Body');
    _addLargeTextareaField(bodyGrid, 'Body text', 'body', model.body);
    bodyWrap.appendChild(bodyGrid);

    form.appendChild(bodyWrap);
    detailPanel.appendChild(form);

    // Recapture initialJson from the current form state (after render).
    initialJson = JSON.stringify(_modelToPlain(collectJournalFormData(/** @type {HTMLFormElement} */ (form))));

    // --- Save handler ---
    saveBtn.addEventListener('click', () => {
      const collected = collectJournalFormData(/** @type {HTMLFormElement} */ (form));
      collected._filename = isNew ? collected.id + '.tres' : model._filename;
      collected._raw = isNew ? null : model._raw;

      const validation = validateJournalForm(collected, isNew);
      if (!validation.valid) {
        errorArea.style.display = 'block';
        errorArea.textContent = validation.errors.join('; ');
        return;
      }

      errorArea.style.display = 'none';

      if (isNew) {
        const cmd = new CreateJournalCommand(collected);
        if (cmdHistory) { cmdHistory.execute(cmd); } else { cmd.execute(); }
        isNewMode = false;
        selectedId = collected.id;
        const entry = ProjectContext.files.journal.get(collected.id + '.tres');
        if (entry) {
          editingModel = JournalModel.fromEntry(collected.id + '.tres', entry);
        }
      } else {
        const cmd = new EditJournalCommand(model._filename, model, collected);
        if (cmdHistory) { cmdHistory.execute(cmd); } else { cmd.execute(); }
        const entry = ProjectContext.files.journal.get(model._filename);
        if (entry) {
          editingModel = JournalModel.fromEntry(model._filename, entry);
        }
      }

      refreshList();
      _renderDetail();
      onSave();
    });

    // --- Delete handler ---
    deleteBtn.addEventListener('click', () => {
      if (confirm(`Delete journal entry "${model.id}"? This cannot be undone without undo.`)) {
        const cmd = new DeleteJournalCommand(model._filename, model);
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
    editingModel = new JournalModel();

    // Auto-increment ID with J prefix.
    editingModel.id = nextId('J', ProjectContext.files.journal);
    editingModel.category = 'lore';
    editingModel.day_added = 0;

    initialJson = JSON.stringify(_modelToPlain(editingModel));
    _updateListSelection();
    _renderDetail();
  });

  // --- Initial render ---
  refreshList();
  _showEmpty();
}

// ============================================================
// UI Field Helpers (mirroring event-editor pattern)
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

function _addSelectField(grid, labelText, name, value, options) {
  const label = document.createElement('label');
  label.textContent = labelText;
  label.classList.add('prop-label');
  grid.appendChild(label);

  const select = document.createElement('select');
  select.name = name;
  select.classList.add('prop-input');
  for (const opt of options) {
    const o = document.createElement('option');
    o.value = opt.value;
    o.textContent = opt.label;
    if (opt.value === value) o.selected = true;
    select.appendChild(o);
  }
  grid.appendChild(select);
}

function _addLargeTextareaField(grid, labelText, name, value) {
  const label = document.createElement('label');
  label.textContent = labelText;
  label.classList.add('prop-label');
  label.style.alignSelf = 'start';
  grid.appendChild(label);

  const textarea = document.createElement('textarea');
  textarea.name = name;
  textarea.value = value || '';
  textarea.classList.add('prop-input');
  textarea.rows = 20;
  textarea.style.cssText = 'min-height:300px;font-family:inherit;resize:vertical;white-space:pre-wrap;';
  grid.appendChild(textarea);
}

function _addSeparator(grid, text) {
  const sep = document.createElement('div');
  sep.classList.add('prop-separator');
  sep.textContent = text;
  grid.appendChild(sep);
}
