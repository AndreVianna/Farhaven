// ============================================================
// editor-common.js — Shared helpers for Gear-derived editors
// ============================================================
//
// This module holds UI helpers that are reused across editors for
// Gear-derived types (Recipe, Prop, Event, Biome). The first helper
// is `renderGearHeader()` — a 2-column header form for the common
// id/display_name/short_description/long_description fields.
//
// Layout produced by renderGearHeader:
//
//   +-----------------------------------------------------+
//   | [ID] [Display Name]           | Long Description    |
//   | [Short Description         ]  |  (textarea, full    |
//   |                               |   height of right   |
//   |                               |   column)           |
//   +-----------------------------------------------------+
//
// The helper creates DOM nodes inside `container`, sets `name="..."`
// attributes on every input so form-collection code can still read
// them via querySelector('[name="..."]'), AND wires input-event
// listeners that write values back to the passed `model` in real
// time. Editors may use either pattern.
//
// ============================================================

/**
 * @typedef {Object} GearHeaderOptions
 * @property {string} [idFieldName='id']
 * @property {string} [nameFieldName='display_name']
 * @property {string} [shortDescFieldName='short_description']
 * @property {string} [longDescFieldName='long_description']
 * @property {boolean} [idReadonly=false] - When true, the ID input is disabled
 *   (typical for editing existing items where the ID is the filename).
 * @property {string} [idLabel='ID']
 * @property {string} [nameLabel='Display Name']
 * @property {string} [shortDescLabel='Short Description']
 * @property {string} [longDescLabel='Long Description']
 */

/**
 * Render the 2-column Gear-header into `container`.
 * The `model` is mutated live as the user edits inputs.
 *
 * @param {HTMLElement} container
 * @param {Object} model
 * @param {GearHeaderOptions} [options]
 * @returns {void}
 */
// Counter for generating unique input IDs (for label htmlFor association).
let _gearHeaderInputCounter = 0;

export function renderGearHeader(container, model, options) {
  const opts = options || {};
  const idField = opts.idFieldName || 'id';
  const nameField = opts.nameFieldName || 'display_name';
  const shortField = opts.shortDescFieldName || 'short_description';
  const longField = opts.longDescFieldName || 'long_description';
  const idReadonly = !!opts.idReadonly;
  const idLabel = opts.idLabel || 'ID';
  const nameLabel = opts.nameLabel || 'Display Name';
  const shortLabel = opts.shortDescLabel || 'Short Description';
  const longLabel = opts.longDescLabel || 'Long Description';

  // Generate unique IDs for this header instance (for accessibility).
  const headerId = `gear-header-${++_gearHeaderInputCounter}`;
  const idInputId = `${headerId}-${idField}`;
  const nameInputId = `${headerId}-${nameField}`;
  const shortInputId = `${headerId}-${shortField}`;
  const longInputId = `${headerId}-${longField}`;

  // Outer 2-column grid
  const grid = document.createElement('div');
  grid.classList.add('editor-2col', 'editor-gear-header');

  // --- Left column ---
  const left = document.createElement('div');
  left.classList.add('col-left');

  // Row 1: ID + Display Name side-by-side
  const idNameRow = document.createElement('div');
  idNameRow.classList.add('editor-header-grid');

  const idWrap = _makeLabelInputWrap(idLabel, idInputId);
  const idInput = document.createElement('input');
  idInput.type = 'text';
  idInput.id = idInputId;
  idInput.name = idField;
  idInput.value = String(model[idField] != null ? model[idField] : '');
  idInput.classList.add('prop-input');
  if (idReadonly) {
    idInput.disabled = true;
  } else {
    idInput.setAttribute('pattern', '^[a-zA-Z0-9_]+$');
  }
  idInput.addEventListener('input', () => { model[idField] = idInput.value; });
  idWrap.appendChild(idInput);

  const nameWrap = _makeLabelInputWrap(nameLabel, nameInputId);
  const nameInput = document.createElement('input');
  nameInput.type = 'text';
  nameInput.id = nameInputId;
  nameInput.name = nameField;
  nameInput.value = String(model[nameField] != null ? model[nameField] : '');
  nameInput.classList.add('prop-input');
  nameInput.addEventListener('input', () => { model[nameField] = nameInput.value; });
  nameWrap.appendChild(nameInput);

  idNameRow.appendChild(idWrap);
  idNameRow.appendChild(nameWrap);
  left.appendChild(idNameRow);

  // Row 2: Short Description (full width of left column)
  const shortWrap = _makeLabelInputWrap(shortLabel, shortInputId);
  const shortInput = document.createElement('input');
  shortInput.type = 'text';
  shortInput.id = shortInputId;
  shortInput.name = shortField;
  shortInput.value = String(model[shortField] != null ? model[shortField] : '');
  shortInput.classList.add('prop-input');
  shortInput.addEventListener('input', () => { model[shortField] = shortInput.value; });
  shortWrap.appendChild(shortInput);
  left.appendChild(shortWrap);

  // --- Right column ---
  const right = document.createElement('div');
  right.classList.add('col-right');

  const longWrap = _makeLabelInputWrap(longLabel, longInputId);
  longWrap.classList.add('full-height');
  const longInput = document.createElement('textarea');
  longInput.id = longInputId;
  longInput.name = longField;
  longInput.value = String(model[longField] != null ? model[longField] : '');
  longInput.classList.add('prop-input', 'full-height-textarea');
  longInput.addEventListener('input', () => { model[longField] = longInput.value; });
  longWrap.appendChild(longInput);
  right.appendChild(longWrap);

  grid.appendChild(left);
  grid.appendChild(right);
  container.appendChild(grid);
}

/** Build a label+input wrapper (label above the input). The label is
 * associated with the input via htmlFor when an inputId is provided. */
function _makeLabelInputWrap(labelText, inputId) {
  const wrap = document.createElement('div');
  wrap.classList.add('editor-field-wrap');
  const label = document.createElement('label');
  label.textContent = labelText;
  label.classList.add('prop-label');
  if (inputId) {
    label.htmlFor = inputId;
  }
  wrap.appendChild(label);
  return wrap;
}
