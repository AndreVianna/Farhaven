// ============================================================
// BiomeEditor — Master-Detail Split Layout (task-014/015)
// ============================================================

import { ProjectContext, FileDiscovery } from './file-discovery.js';
import { TresParser, TresFile, generateTresUid } from './tres-parser.js';
import { showInlineModal } from './panels.js';
import { renderGearHeader } from './editor-common.js';

/** @type {Set<string>} Biome IDs recognized by the game MapLoader */

/**
 * Maps a parsed .tres BiomeData to an editable JS model.
 * All fields mirror the BiomeData GDScript class.
 */
export class BiomeDataModel {
  constructor() {
    /** @type {string} Stable biome id, e.g. "B00001". Matches the filename stem. */
    this._id = '';
    /** @type {string} Human-readable display name (inherited from Gear). */
    this.display_name = '';
    /** @type {string} One-line summary for tooltips/lists (inherited from Gear). */
    this.short_description = '';
    /** @type {string} Long-form description for detail panels (inherited from Gear). */
    this.long_description = '';
    /** @type {{ r: number, g: number, b: number, a: number }} */
    this.color = { r: 0, g: 0, b: 0, a: 1 };
    /** @type {Array<{ r: number, g: number, b: number, a: number }>} */
    this.color_variations = [];
    /** @type {string[]} `res://...` paths to terrain texture variations
     *  (what the runtime hex shader samples). Order matters because the
     *  per-tile variation index % length selects one. */
    this.terrain_textures = [];
    // Round-trip metadata
    /** @type {string} */
    this._filename = '';
    /** @type {import('./tres-parser.js').TresFile|null} */
    this._raw = null;
  }

  /**
   * Stable biome id. Prefers the explicit `id` loaded from the .tres file;
   * falls back to the filename stem for legacy resources that haven't been
   * re-saved in the B00NNN format yet.
   */
  get id() {
    return this._id || this._filename.replace('.tres', '');
  }

  set id(value) {
    this._id = value;
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

    // id from the .tres file (e.g. "B00001"). Legacy files that only have
    // the old biome_name / filename-stem convention fall back to the stem.
    model._id = _str(d.id) || filename.replace('.tres', '');
    // display_name is the human-readable label. Accept either the new
    // `display_name` field or legacy `biome_name` for backward compat.
    model.display_name = _str(d.display_name) || _str(d.biome_name);
    model.short_description = _str(d.short_description);
    model.long_description = _str(d.long_description);

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

    // terrain_textures: array of ext_resource refs we resolve back to
    // the raw `res://...` path so the editor model is path-based.
    // Build an id -> path map from the [ext_resource ...] header lines
    // first, then map each array entry (ExtResource("id")) through it.
    if (Array.isArray(d.terrain_textures) && entry.raw) {
      const idToPath = new Map();
      for (const line of entry.raw.extResources || []) {
        const idM = /\bid="([^"]+)"/.exec(line);
        const pathM = /\bpath="([^"]+)"/.exec(line);
        if (idM && pathM) idToPath.set(idM[1], pathM[1]);
      }
      model.terrain_textures = d.terrain_textures.map((tv) => {
        const ref = (tv && typeof tv === 'object' && tv.type === 'ext_resource') ? tv.value
                  : (typeof tv === 'string') ? tv : '';
        const idM = /ExtResource\("([^"]+)"\)/.exec(ref);
        return idM ? (idToPath.get(idM[1]) || '') : '';
      }).filter(Boolean);
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

/**
 * Convert a model to a plain object for dirty comparison (excluding metadata fields).
 * @param {BiomeDataModel} model
 * @returns {Object}
 */
function _modelToPlain(model) {
  return {
    id: model.id,
    display_name: model.display_name,
    short_description: model.short_description,
    long_description: model.long_description,
    color: model.color,
    color_variations: model.color_variations,
    terrain_textures: model.terrain_textures,
  };
}

// ============================================================
// Master-Detail Split Layout
// ============================================================

/**
 * Render the biome editor as a master-detail split layout.
 * @param {HTMLElement} container - The #tab-biomes element
 * @param {Object} [options] - Options object
 * @param {import('./commands.js').CommandHistory} [options.commandHistory] - Command history for undo/redo
 * @param {Map<string, string>} [options.biomeColorMap] - Biome name -> CSS color string
 * @param {import('./canvas.js').HexCanvas} [options.hexCanvas] - Canvas for live preview
 * @returns {void}
 */
export function renderBiomeEditor(container, options) {
  container.innerHTML = '';

  const opts = options || {};
  const onChange = typeof opts.onChange === 'function' ? opts.onChange : () => {};
  const onSave = typeof opts.onSave === 'function' ? opts.onSave : onChange;

  // State for the editor
  /** @type {BiomeDataModel|null} */
  let selectedModel = null;
  /** @type {boolean} */
  let isNewMode = false;
  /** @type {string|null} */
  let originalColorRgb = null;
  /** @type {string} */
  let initialJson = '';
  // Build split layout
  const split = document.createElement('div');
  split.className = 'editor-split';

  // ── Left Panel ──
  const listPanel = document.createElement('div');
  listPanel.className = 'editor-list-panel';

  const listHeader = document.createElement('div');
  listHeader.className = 'editor-list-header';

  const filterInput = document.createElement('input');
  filterInput.type = 'text';
  filterInput.placeholder = 'Filter biomes...';
  filterInput.className = 'editor-filter prop-input';
  filterInput.addEventListener('input', () => _applyFilter());

  const newBtn = document.createElement('button');
  newBtn.textContent = '+ New';
  newBtn.className = 'editor-new-btn prop-btn';
  newBtn.addEventListener('click', () => {
    if (!_guardDirty()) return;
    _selectNew();
  });

  listHeader.appendChild(filterInput);
  listHeader.appendChild(newBtn);
  listPanel.appendChild(listHeader);

  const listItems = document.createElement('div');
  listItems.className = 'editor-list-items';
  listPanel.appendChild(listItems);

  // ── Right Panel ──
  const detailPanel = document.createElement('div');
  detailPanel.className = 'editor-detail-panel';

  split.appendChild(listPanel);
  split.appendChild(detailPanel);
  container.appendChild(split);

  // ── Populate list ──
  _refreshList();
  _showEmpty();

  // ============================================================
  // List helpers
  // ============================================================

  /**
   * Build sorted array of biome models from ProjectContext.
   * @returns {BiomeDataModel[]}
   */
  function _getBiomes() {
    /** @type {BiomeDataModel[]} */
    const biomes = [];
    for (const [filename, entry] of ProjectContext.files.biomes) {
      biomes.push(BiomeDataModel.fromEntry(filename, entry));
    }
    biomes.sort((a, b) => a.display_name.localeCompare(b.display_name));
    return biomes;
  }

  /** Refresh the list items. Preserves active selection if still present. */
  function _refreshList() {
    listItems.innerHTML = '';
    const biomes = _getBiomes();

    if (biomes.length === 0) {
      const empty = document.createElement('div');
      empty.textContent = 'No biomes found.';
      empty.style.cssText = 'padding:10px 8px;color:var(--text-secondary);font-size:12px;';
      listItems.appendChild(empty);
      return;
    }

    for (const model of biomes) {
      const item = document.createElement('div');
      item.className = 'editor-list-item';
      item.dataset.biomeId = model.id;

      if (selectedModel && !isNewMode && selectedModel.id === model.id) {
        item.classList.add('active');
      }

      const swatch = document.createElement('div');
      swatch.className = 'swatch';
      swatch.style.background = model.colorHex;

      const label = document.createElement('span');
      label.textContent = model.display_name || model.id;

      item.appendChild(swatch);
      item.appendChild(label);


      item.addEventListener('click', () => {
        if (selectedModel && !isNewMode && selectedModel.id === model.id) return;
        if (!_guardDirty()) return;
        _selectExisting(model);
      });

      listItems.appendChild(item);
    }

    _applyFilter();
  }

  /** Apply the filter input to the list items. */
  function _applyFilter() {
    const text = filterInput.value.trim().toLowerCase();
    const items = listItems.querySelectorAll('.editor-list-item');
    for (const item of items) {
      const el = /** @type {HTMLElement} */ (item);
      const id = (el.dataset.biomeId || '').toLowerCase();
      const name = (el.querySelector('span')?.textContent || '').toLowerCase();
      el.style.display = (!text || id.includes(text) || name.includes(text)) ? '' : 'none';
    }
  }

  /**
   * Mark an item as active in the list by biome ID.
   * @param {string|null} biomeId
   */
  function _setActiveItem(biomeId) {
    const items = listItems.querySelectorAll('.editor-list-item');
    for (const item of items) {
      const el = /** @type {HTMLElement} */ (item);
      if (biomeId && el.dataset.biomeId === biomeId) {
        el.classList.add('active');
      } else {
        el.classList.remove('active');
      }
    }
  }

  // ============================================================
  // Detail panel rendering
  // ============================================================

  /** Show the empty placeholder. */
  function _showEmpty() {
    detailPanel.innerHTML = '';
    const emptyEl = document.createElement('div');
    emptyEl.className = 'editor-detail-empty';
    emptyEl.textContent = 'Select a biome';
    detailPanel.appendChild(emptyEl);
  }

  /**
   * Select an existing biome for editing.
   * @param {BiomeDataModel} model
   */
  function _selectExisting(model) {
    selectedModel = model;
    isNewMode = false;
    originalColorRgb = (model.id && opts.biomeColorMap)
      ? opts.biomeColorMap.get(model.id) || null
      : null;
    initialJson = JSON.stringify(_modelToPlain(model));
    _setActiveItem(model.id);
    _renderDetail();
  }

  /** Start creating a new biome. */
  function _selectNew() {
    selectedModel = new BiomeDataModel();
    isNewMode = true;
    originalColorRgb = null;
    initialJson = JSON.stringify(_modelToPlain(selectedModel));
    _setActiveItem(null);
    _renderDetail();
  }

  /**
   * Check if the current form is dirty and guard navigation.
   * If dirty, asks the user to confirm discarding changes.
   * Also reverts live-preview color if cancelled or discarded.
   * @returns {boolean} true if safe to proceed
   */
  function _guardDirty() {
    if (!selectedModel) return true;
    const form = detailPanel.querySelector('form');
    if (!form) return true;

    const currentData = _collectBiomeFormData(/** @type {HTMLFormElement} */ (form));
    const currentJson = JSON.stringify(_modelToPlain(currentData));
    if (currentJson !== initialJson) {
      if (!confirm('Discard unsaved changes?')) return false;
    }

    // Revert live preview color on navigating away
    _revertLivePreview();
    return true;
  }

  /** Revert the biomeColorMap entry to original if it was changed via live preview. */
  function _revertLivePreview() {
    if (opts.biomeColorMap && selectedModel && selectedModel.id && originalColorRgb != null) {
      opts.biomeColorMap.set(selectedModel.id, originalColorRgb);
      if (opts.hexCanvas) opts.hexCanvas.requestRender();
    }
  }

  /** Render (or re-render) the detail panel for the currently selected biome. */
  function _renderDetail() {
    detailPanel.innerHTML = '';
    if (!selectedModel) {
      _showEmpty();
      return;
    }

    const model = selectedModel;
    const isNew = isNewMode;

    // ── Header ──
    const header = document.createElement('div');
    header.className = 'editor-detail-header';

    const h3 = document.createElement('h3');
    const headerSwatch = document.createElement('div');
    headerSwatch.className = 'swatch';
    headerSwatch.style.cssText = `width:14px;height:14px;border-radius:2px;border:1px solid var(--border);background:${model.colorHex};`;
    const headerTitle = document.createElement('span');
    headerTitle.textContent = isNew ? 'New Biome' : model.display_name;
    h3.appendChild(headerSwatch);
    h3.appendChild(headerTitle);

    const btnGroup = document.createElement('div');
    btnGroup.className = 'btn-group';

    const saveBtn = document.createElement('button');
    saveBtn.textContent = 'Save';
    saveBtn.type = 'button';
    saveBtn.className = 'editor-btn-save prop-btn-primary';

    const deleteBtn = document.createElement('button');
    deleteBtn.textContent = 'Delete';
    deleteBtn.type = 'button';
    deleteBtn.className = 'editor-btn-delete prop-btn';

    btnGroup.appendChild(saveBtn);
    if (!isNew) {
      btnGroup.appendChild(deleteBtn);
    }

    header.appendChild(h3);
    header.appendChild(btnGroup);

    // Wrap everything in a form
    const form = document.createElement('form');
    form.style.cssText = 'display:flex;flex-direction:column;height:100%;';
    form.addEventListener('submit', (e) => e.preventDefault());
    form.appendChild(header);

    // ── Error area ──
    const errorArea = document.createElement('div');
    errorArea.style.cssText = 'display:none;padding:6px 10px;margin:0;background:#4a1c1c;border-bottom:1px solid #7a3030;color:#ff9999;font-size:12px;';
    form.appendChild(errorArea);

    // ── Biome header (id + display_name + elevation min/max on one row) ──
    const biomeHeaderWrap = document.createElement('div');
    biomeHeaderWrap.style.cssText = 'padding:10px 14px 0;';
    renderGearHeader(biomeHeaderWrap, model, { idReadonly: true });
    form.appendChild(biomeHeaderWrap);

    // ── Two-column body (left: Resource Table, right: Colors) ──
    const columnsWrapper = document.createElement('div');
    columnsWrapper.style.cssText = 'display:flex;flex:1;overflow:hidden;';

    const leftBody = document.createElement('div');
    leftBody.classList.add('editor-detail-body');
    leftBody.style.cssText = 'flex:1;overflow-y:auto;';

    const rightBody = document.createElement('div');
    rightBody.classList.add('editor-detail-body');
    rightBody.style.cssText = 'flex:1;overflow-y:auto;border-left:1px solid var(--border);';

    const generalContent = _buildGeneralTab(model, isNew, form, errorArea);
    const colorsContent = _buildColorsTab(model, form, errorArea, headerSwatch);
    leftBody.appendChild(generalContent);
    rightBody.appendChild(colorsContent);

    columnsWrapper.appendChild(leftBody);
    columnsWrapper.appendChild(rightBody);
    form.appendChild(columnsWrapper);
    detailPanel.appendChild(form);

    // Recapture initialJson from the rendered form so comparisons are form-to-form
    initialJson = JSON.stringify(_modelToPlain(_collectBiomeFormData(form)));

    // ── Save handler ──
    saveBtn.addEventListener('click', () => {
      const collected = _collectBiomeFormData(form);
      if (isNew) {
        collected._id = _nextBiomeId();
        collected._filename = collected._id + '.tres';
      } else {
        collected._id = model._id;
        collected._filename = model._filename;
      }
      collected._raw = model._raw;

      const validation = _validateBiomeForm(collected, isNew);
      if (!validation.valid) {
        errorArea.style.display = 'block';
        errorArea.textContent = validation.errors.join('; ');
        return;
      }

      if (isNew) {
        const cmd = new CreateBiomeCommand(collected, opts.commandHistory);
        if (opts.commandHistory) {
          opts.commandHistory.execute(cmd);
        } else {
          cmd.execute();
        }
      } else {
        const cmd = new EditBiomeCommand(model._filename, model, collected, opts.commandHistory, opts);
        if (opts.commandHistory) {
          opts.commandHistory.execute(cmd);
        } else {
          cmd.execute();
        }
      }

      // After save: refresh list, select the saved biome
      const savedId = collected._filename.replace('.tres', '');
      const entry = ProjectContext.files.biomes.get(collected._filename);
      if (entry) {
        const savedModel = BiomeDataModel.fromEntry(collected._filename, entry);
        _refreshList();
        // Reset originalColorRgb to reflect the newly saved color
        originalColorRgb = opts.biomeColorMap ? opts.biomeColorMap.get(savedId) || null : null;
        selectedModel = savedModel;
        isNewMode = false;
        initialJson = JSON.stringify(_modelToPlain(savedModel));
        _setActiveItem(savedId);
        _renderDetail();
      } else {
        _refreshList();
        selectedModel = null;
        isNewMode = false;
        _showEmpty();
      }
      onSave();
    });

    // ── Delete handler ──
    deleteBtn.addEventListener('click', () => {
      const usages = findBiomeUsage(model.id);
      if (usages.length > 0) {
        const usageList = usages.map(u => `${u.map} (${u.count} tile${u.count > 1 ? 's' : ''})`).join(', ');
        showInlineModal(
          `Biome "${model.display_name}" is used in: ${usageList}. Type "DELETE" to confirm deletion:`,
          '',
          (val) => {
            if (val === 'DELETE') {
              _performDelete(model);
            }
          }
        );
      } else {
        if (confirm(`Delete biome "${model.display_name}"? This cannot be undone without undo.`)) {
          _performDelete(model);
        }
      }
    });
  }

  /**
   * Execute the delete command and refresh the UI.
   * @param {BiomeDataModel} model
   */
  function _performDelete(model) {
    _executeDelete(model, {
      commandHistory: opts.commandHistory,
      onDelete: () => {
        selectedModel = null;
        isNewMode = false;
        _refreshList();
        _showEmpty();
        onChange();
      },
    });
  }

  // ============================================================
  // General tab builder
  // ============================================================

  /**
   * Build the "General" tab content.
   * @param {BiomeDataModel} model
   * @param {boolean} isNew
   * @param {HTMLFormElement} form
   * @param {HTMLElement} errorArea
   * @returns {HTMLElement}
   */
  function _buildGeneralTab(model, isNew, form, errorArea) {
    const wrapper = document.createElement('div');
    wrapper.dataset.tab = 'general';

    const grid = document.createElement('div');
    grid.className = 'prop-grid';

    // Note: id/display_name/short_description/long_description are rendered
    // above this tab via the shared renderGearHeader() in _renderDetail.
    // Color/texture editing lives in its own tab. For now this "General"
    // tab is a placeholder — additional biome-level settings will land
    // here as they emerge.

    wrapper.appendChild(grid);
    return wrapper;
  }


  // ============================================================
  // Colors tab builder
  // ============================================================

  /**
   * Build the "Colors" tab content.
   * @param {BiomeDataModel} model
   * @param {HTMLFormElement} form
   * @param {HTMLElement} errorArea
   * @param {HTMLElement} headerSwatch - The swatch in the detail header for live update
   * @returns {HTMLElement}
   */
  function _buildColorsTab(model, form, errorArea, headerSwatch) {
    const wrapper = document.createElement('div');
    wrapper.dataset.tab = 'colors';

    const grid = document.createElement('div');
    grid.className = 'prop-grid';

    // Base Color — label
    const colorLabel = document.createElement('div');
    colorLabel.className = 'prop-label';
    colorLabel.textContent = 'Base Color';

    // Base Color — picker + swatch
    const colorCell = document.createElement('div');
    colorCell.style.cssText = 'display:flex;gap:6px;align-items:center;';

    const colorInput = document.createElement('input');
    colorInput.type = 'color';
    colorInput.name = 'color';
    colorInput.value = _colorToHex(model.color);
    colorInput.className = 'prop-input';
    colorInput.style.cssText = 'width:40px;height:28px;padding:0;cursor:pointer;';

    colorInput.addEventListener('input', () => {
      headerSwatch.style.background = colorInput.value;
      // Live preview: update biomeColorMap
      const hex = colorInput.value;
      const r = parseInt(hex.slice(1, 3), 16);
      const g = parseInt(hex.slice(3, 5), 16);
      const b = parseInt(hex.slice(5, 7), 16);
      if (opts.biomeColorMap && selectedModel && selectedModel.id) {
        opts.biomeColorMap.set(selectedModel.id, `rgb(${r},${g},${b})`);
        if (opts.hexCanvas) opts.hexCanvas.requestRender();
      }
      // Also update swatch in list panel
      const listItem = listItems.querySelector(`[data-biome-id="${selectedModel?.id}"] .swatch`);
      if (listItem) /** @type {HTMLElement} */ (listItem).style.background = colorInput.value;
    });

    colorCell.appendChild(colorInput);

    grid.appendChild(colorLabel);
    grid.appendChild(colorCell);

    // Separator — Variations
    const varSep = document.createElement('div');
    varSep.className = 'prop-separator';
    varSep.textContent = 'Variations';
    grid.appendChild(varSep);

    // Variations list — full width
    const varFull = document.createElement('div');
    varFull.className = 'prop-full';

    const variationsContainer = document.createElement('div');
    variationsContainer.dataset.variationsContainer = 'true';

    /**
     * Add a color variation entry.
     * @param {{ r: number, g: number, b: number, a: number }} varColor
     */
    function addVariationRow(varColor) {
      const row = document.createElement('div');
      row.style.cssText = 'display:flex;gap:6px;align-items:center;margin-bottom:4px;';

      const input = document.createElement('input');
      input.type = 'color';
      input.value = _colorToHex(varColor);
      input.dataset.variationColor = 'true';
      input.className = 'prop-input';
      input.style.cssText = 'width:40px;height:28px;padding:0;cursor:pointer;';

      const removeBtn = document.createElement('button');
      removeBtn.textContent = 'X';
      removeBtn.type = 'button';
      removeBtn.classList.add('prop-btn-icon');
      removeBtn.addEventListener('click', () => row.remove());

      row.appendChild(input);
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
    addVarBtn.classList.add('prop-btn');
    addVarBtn.style.marginTop = '2px';
    addVarBtn.addEventListener('click', () => {
      const currentCount = variationsContainer.querySelectorAll('[data-variation-color]').length;
      if (currentCount >= 10) {
        errorArea.style.display = 'block';
        errorArea.textContent = 'Maximum 10 color variations allowed.';
        return;
      }
      const baseHex = colorInput.value || '#000000';
      addVariationRow(_hexToColor(baseHex));
    });

    varFull.appendChild(variationsContainer);
    varFull.appendChild(addVarBtn);
    grid.appendChild(varFull);

    // ── Textures section ──
    const texSep = document.createElement('div');
    texSep.className = 'prop-separator';
    texSep.textContent = 'Terrain Textures';
    grid.appendChild(texSep);

    const texFull = document.createElement('div');
    texFull.className = 'prop-full';

    const texHint = document.createElement('div');
    texHint.style.cssText = 'color:var(--text-secondary);font-size:11px;margin-bottom:6px;';
    texHint.textContent = 'Hash-picked per tile at runtime. Add 2–4 for good variety; leave empty to fall back to the base color.';
    texFull.appendChild(texHint);

    const texContainer = document.createElement('div');
    texContainer.dataset.texturesContainer = 'true';
    texContainer.style.cssText = 'display:flex;flex-wrap:wrap;gap:6px;margin-bottom:6px;';

    function addTextureThumb(resPath) {
      const row = document.createElement('div');
      row.dataset.texturePath = resPath;
      row.style.cssText = 'position:relative;width:64px;height:64px;border:1px solid var(--border);border-radius:3px;background:var(--bg-tertiary);overflow:hidden;';

      const img = document.createElement('img');
      img.src = `/api/asset?path=${encodeURIComponent(resPath.replace(/^res:\/\//, ''))}`;
      img.alt = resPath.split('/').pop() || '';
      img.style.cssText = 'width:100%;height:100%;object-fit:cover;display:block;';
      row.appendChild(img);

      const caption = document.createElement('div');
      caption.textContent = resPath.split('/').pop() || '';
      caption.title = resPath;
      caption.style.cssText = 'position:absolute;bottom:0;left:0;right:0;padding:1px 3px;background:rgba(0,0,0,0.6);color:#fff;font-size:9px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;';
      row.appendChild(caption);

      const removeBtn = document.createElement('button');
      removeBtn.textContent = '×';
      removeBtn.type = 'button';
      removeBtn.title = 'Remove';
      removeBtn.style.cssText = 'position:absolute;top:2px;right:2px;width:18px;height:18px;padding:0;border:none;border-radius:50%;background:rgba(0,0,0,0.7);color:#fff;cursor:pointer;font-size:12px;line-height:1;';
      removeBtn.addEventListener('click', () => row.remove());
      row.appendChild(removeBtn);

      texContainer.appendChild(row);
    }

    for (const p of model.terrain_textures) addTextureThumb(p);

    const addTexBtn = document.createElement('button');
    addTexBtn.textContent = '+ Add Texture';
    addTexBtn.type = 'button';
    addTexBtn.classList.add('prop-btn');
    addTexBtn.style.marginTop = '2px';

    addTexBtn.addEventListener('click', async () => {
      // Pull the list of PNGs available under assets/textures/biomes/
      // from the dev server, subtract what's already on this biome, and
      // prompt the user to pick one.
      let listed = [];
      try {
        const resp = await fetch('/api/list-assets?dir=assets/textures/biomes&ext=.png');
        if (resp.ok) {
          const data = await resp.json();
          listed = Array.isArray(data.files) ? data.files : [];
        }
      } catch (err) {
        errorArea.style.display = 'block';
        errorArea.textContent = `Failed to list textures: ${err.message}`;
        return;
      }
      if (listed.length === 0) {
        errorArea.style.display = 'block';
        errorArea.textContent = 'No PNGs found in assets/textures/biomes/.';
        return;
      }
      const existing = new Set(Array.from(texContainer.querySelectorAll('[data-texture-path]'))
        .map((n) => /** @type {HTMLElement} */ (n).dataset.texturePath));
      const remaining = listed
        .map((name) => `res://assets/textures/biomes/${name}`)
        .filter((p) => !existing.has(p));
      if (remaining.length === 0) {
        errorArea.style.display = 'block';
        errorArea.textContent = 'All available textures are already assigned.';
        return;
      }
      _openTexturePicker(remaining, (picked) => {
        if (picked) addTextureThumb(picked);
      });
    });

    texFull.appendChild(texContainer);
    texFull.appendChild(addTexBtn);
    grid.appendChild(texFull);

    wrapper.appendChild(grid);
    return wrapper;
  }
}

/**
 * Modal picker for choosing one `res://...` texture path from a list.
 * Small enough to inline here so the rest of the editor doesn't gain
 * a new shared component for a biome-editor-only flow.
 * @param {string[]} paths
 * @param {(picked: string|null) => void} callback
 */
function _openTexturePicker(paths, callback) {
  const backdrop = document.createElement('div');
  backdrop.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,0.5);z-index:1000;display:flex;align-items:center;justify-content:center;';
  const panel = document.createElement('div');
  panel.style.cssText = 'background:var(--bg-secondary);border:1px solid var(--border);border-radius:4px;padding:12px;min-width:420px;max-width:80vw;max-height:80vh;overflow-y:auto;color:var(--text-primary);';

  const heading = document.createElement('h4');
  heading.textContent = 'Pick a terrain texture';
  heading.style.margin = '0 0 8px 0';
  panel.appendChild(heading);

  const grid = document.createElement('div');
  grid.style.cssText = 'display:flex;flex-wrap:wrap;gap:8px;';
  for (const p of paths) {
    const item = document.createElement('button');
    item.type = 'button';
    item.style.cssText = 'position:relative;width:96px;height:96px;padding:0;border:1px solid var(--border);border-radius:3px;background:var(--bg-tertiary);cursor:pointer;overflow:hidden;';
    const img = document.createElement('img');
    img.src = `/api/asset?path=${encodeURIComponent(p.replace(/^res:\/\//, ''))}`;
    img.style.cssText = 'width:100%;height:100%;object-fit:cover;display:block;';
    item.appendChild(img);
    const caption = document.createElement('div');
    caption.textContent = p.split('/').pop() || '';
    caption.style.cssText = 'position:absolute;bottom:0;left:0;right:0;padding:1px 3px;background:rgba(0,0,0,0.6);color:#fff;font-size:9px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;';
    item.appendChild(caption);
    item.addEventListener('click', () => {
      document.body.removeChild(backdrop);
      callback(p);
    });
    grid.appendChild(item);
  }
  panel.appendChild(grid);

  const cancel = document.createElement('button');
  cancel.type = 'button';
  cancel.textContent = 'Cancel';
  cancel.classList.add('prop-btn');
  cancel.style.marginTop = '10px';
  cancel.addEventListener('click', () => {
    document.body.removeChild(backdrop);
    callback(null);
  });
  panel.appendChild(cancel);

  backdrop.appendChild(panel);
  document.body.appendChild(backdrop);
}

// ============================================================
// Form Data Collection (task-015)
// ============================================================

/**
 * Compute the next available biome id in the B00NNN convention. Scans the
 * existing biomes in ProjectContext and returns one higher than the highest
 * valid id found. Returns "B00001" when no biomes exist yet.
 * @returns {string} e.g. "B00006"
 */
function _nextBiomeId() {
  let maxNum = 0;
  for (const filename of ProjectContext.files.biomes.keys()) {
    const stem = filename.replace('.tres', '');
    const match = stem.match(/^B(\d{5})$/);
    if (match) {
      const n = parseInt(match[1], 10);
      if (!isNaN(n) && n > maxNum) maxNum = n;
    }
  }
  return 'B' + String(maxNum + 1).padStart(5, '0');
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

  // Identity (Gear fields)
  model.display_name = val('display_name').trim();
  model.short_description = val('short_description').trim();
  model.long_description = val('long_description');

  // Color
  model.color = _hexToColor(val('color'));

  // Color variations
  model.color_variations = [];
  const variationInputs = formElement.querySelectorAll('[data-variation-color]');
  for (const input of variationInputs) {
    model.color_variations.push(_hexToColor(/** @type {HTMLInputElement} */ (input).value));
  }

  // Terrain textures — keep the DOM order (hash-picked variation index
  // is order-sensitive, so removing from the middle doesn't scramble
  // the remaining tiles' textures in the game).
  model.terrain_textures = [];
  const textureNodes = formElement.querySelectorAll('[data-texture-path]');
  for (const node of textureNodes) {
    const p = /** @type {HTMLElement} */ (node).dataset.texturePath;
    if (p) model.terrain_textures.push(p);
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

  // Display name validation
  if (!model.display_name) {
    errors.push('Display Name is required');
  } else if (isNew) {
    // Check display-name uniqueness across all existing biomes.
    const lower = model.display_name.toLowerCase();
    for (const entry of ProjectContext.files.biomes.values()) {
      const existingName = _str(entry.data && entry.data.display_name || entry.data && entry.data.biome_name);
      if (existingName.toLowerCase() === lower) {
        errors.push(`Biome "${model.display_name}" already exists`);
        break;
      }
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
    raw.extResources = [];
    raw.lineEnding = '\n';
  }

  // Rebuild ext_resources deterministically: Script first, then one
  // Texture2D line per terrain_textures entry. We preserve existing
  // uid="..." hints when we can recover them from the previous raw,
  // so a round-trip without edits stays byte-identical; new entries
  // omit uid (Godot will backfill on its next save).
  const prevIdByPath = new Map();
  if (model._raw && Array.isArray(model._raw.extResources)) {
    for (const line of model._raw.extResources) {
      const idM = /\bid="([^"]+)"/.exec(line);
      const pathM = /\bpath="([^"]+)"/.exec(line);
      const uidM = /\buid="([^"]+)"/.exec(line);
      if (idM && pathM) {
        prevIdByPath.set(pathM[1], { id: idM[1], uid: uidM ? uidM[1] : null });
      }
    }
  }

  const scriptExtId = '1_biome';
  const newExtResources = [
    `[ext_resource type="Script" path="res://scripts/hex/biome_data.gd" id="${scriptExtId}"]`,
  ];
  const texIds = []; // parallel to model.terrain_textures
  let nextTexIdx = 2;
  for (const resPath of model.terrain_textures) {
    const prev = prevIdByPath.get(resPath);
    const texId = (prev && prev.id && prev.id !== scriptExtId) ? prev.id : `${nextTexIdx++}_tex`;
    texIds.push(texId);
    const uidAttr = prev && prev.uid ? ` uid="${prev.uid}"` : '';
    newExtResources.push(`[ext_resource type="Texture2D"${uidAttr} path="${resPath}" id="${texId}"]`);
  }
  raw.extResources = newExtResources;

  // Keep the header's load_steps in sync so Godot doesn't warn about
  // a mismatch between declared count and actual resources.
  const loadSteps = newExtResources.length + (Array.isArray(raw.subResources) ? raw.subResources.length : 0) + 1;
  const uidAttr = raw.uid ? ` uid="${raw.uid}"` : '';
  raw.headerLine = `[gd_resource type="Resource" script_class="BiomeData" load_steps=${loadSteps} format=3${uidAttr}]`;

  // Build the resource fields map
  const fields = new Map();

  // Script line is always first
  fields.set('script', { type: 'ext_resource', value: `ExtResource("${scriptExtId}")` });

  // id: StringName (from Gear)
  fields.set('id', { type: 'stringname', value: model.id });

  // display_name: string (from Gear)
  fields.set('display_name', { type: 'string', value: model.display_name });

  // short_description and long_description: only emitted when non-empty so
  // freshly-created biomes don't carry empty placeholder lines.
  if (model.short_description) {
    fields.set('short_description', { type: 'string', value: model.short_description });
  }
  if (model.long_description) {
    fields.set('long_description', { type: 'string', value: model.long_description });
  }

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

  // terrain_textures: Array[Texture2D] referencing the ext_resource ids
  // we just emitted. Only write the field when the list is non-empty so
  // biomes without textures stay byte-clean (color-only rendering).
  if (model.terrain_textures.length > 0) {
    const texEntries = texIds.map((id) => ({ type: 'ext_resource', value: `ExtResource("${id}")` }));
    // Untyped array literal (matches the `[ExtResource(...), ...]` format
    // the existing hand-authored biome .tres files use).
    fields.set('terrain_textures', { type: 'array', value: texEntries, elementType: null });
  }

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
    // Model carries its own id (B00NNN); filename is id + .tres.
    // Fall back to deriving from model._filename when callers set the
    // filename directly (legacy paths) instead of the id.
    this._filename = model._filename || (model.id + '.tres');
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
// Delete Helpers
// ============================================================

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
