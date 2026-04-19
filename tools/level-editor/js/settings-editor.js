// ============================================================
// SettingsEditor — singleton GameSettings.tres editor
// ============================================================
//
// GameSettings is a plain Resource singleton (one instance,
// `data/game_settings.tres`) that carries engine-wide startup choices
// — currently just `starting_map`, which feeds the game/save boot
// precedence in `SaveManager.get_current_map_or_default(settings)`.
//
// Unlike props/biomes/etc, we don't want a master-detail list: there
// is exactly one file. This editor renders a single form bound to the
// one resource and writes back via the dev-server API. It intentionally
// does NOT live in `ProjectContext.files` — adding it there would mean
// touching the three discovery code paths for a single-instance file.
// ============================================================

import { TresParser, TresFile } from './tres-parser.js';
import { FileDiscovery, ProjectContext } from './file-discovery.js';

const FILE_DIR = 'data';
const FILE_NAME = 'game_settings.tres';
const FILE_PATH = `${FILE_DIR}/${FILE_NAME}`;
const SCRIPT_CLASS = 'GameSettings';
const SCRIPT_PATH = 'res://scripts/data/game_settings.gd';

/**
 * Editable model for GameSettings. Plain Resource — not a Gear — so no
 * id / display_name / descriptions; just engine-level knobs.
 */
export class GameSettingsModel {
  constructor() {
    /** @type {string} Filename relative to data/maps (e.g. "ch1.json"). */
    this.starting_map = 'ch1.json';
    /**
     * @type {number} View-distance radius (hex tiles) for streaming
     * natural prop meshes + their scanner labels. 0 = unlimited
     * (every tile renders). Mirror of GameSettings.prop_stream_radius.
     */
    this.prop_stream_radius = 0;
    /** @type {TresFile|null} Round-trip handle to preserve unknown fields. */
    this._raw = null;
  }

  static fromTres(raw) {
    const model = new GameSettingsModel();
    model._raw = raw;
    const data = {};
    for (const [k, tv] of raw.resourceFields) {
      data[k] = tv.value;
    }
    if (data.starting_map != null) model.starting_map = String(data.starting_map);
    if (typeof data.prop_stream_radius === 'number') {
      model.prop_stream_radius = data.prop_stream_radius;
    }
    return model;
  }
}

/**
 * Serialize a model back to a TresFile, preserving unknown fields.
 * @param {GameSettingsModel} model
 * @returns {TresFile}
 */
function modelToRaw(model) {
  const raw = model._raw ? model._raw : new TresFile();
  raw.scriptClass = SCRIPT_CLASS;
  if (!raw.lineEnding) raw.lineEnding = '\n';

  const scriptExtId = '1_script';
  const extResources = [
    `[ext_resource type="Script" path="${SCRIPT_PATH}" id="${scriptExtId}"]`,
  ];
  const loadSteps = extResources.length + 0 + 1;
  raw.headerLine = `[gd_resource type="Resource" script_class="${SCRIPT_CLASS}" load_steps=${loadSteps} format=3]`;
  raw.extResources = extResources;
  raw.subResources = [];

  const fields = new Map();
  fields.set('script', { type: 'ext_resource', value: `ExtResource("${scriptExtId}")` });
  fields.set('starting_map', { type: 'string', value: model.starting_map || 'ch1.json' });
  // Emit prop_stream_radius ALWAYS — the UI-known set. Previous
  // "skip when 0 to stay byte-clean" combined with the forward-compat
  // preservation loop below silently restored the prior on-disk
  // value whenever the user edited the field back to 0, so switching
  // the map to unlimited mode was a no-op save (ultrareview finding
  // 2026-04-19). Settings-tres is a singleton with ~2 fields today —
  // there's no byte-churn cost worth the footgun.
  const radius = Number.isFinite(model.prop_stream_radius) ? model.prop_stream_radius | 0 : 0;
  fields.set('prop_stream_radius', { type: 'int', value: radius });

  // Preserve forward-compat fields (future additions we don't edit here).
  // Guarded by fields.has(k) above — every key the UI manages is
  // already set, so the loop never overwrites a just-written value.
  if (model._raw && model._raw.resourceFields instanceof Map) {
    for (const [k, v] of model._raw.resourceFields) {
      if (!fields.has(k)) fields.set(k, v);
    }
  }

  raw.resourceFields = fields;
  return raw;
}

async function loadSettings() {
  try {
    const resp = await fetch(`/api/file?path=${encodeURIComponent(FILE_PATH)}`);
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    const text = await resp.text();
    const raw = TresParser.parse(text);
    if (raw.scriptClass !== SCRIPT_CLASS) {
      console.warn(`SettingsEditor: ${FILE_NAME} scriptClass "${raw.scriptClass}" != "${SCRIPT_CLASS}". Using defaults.`);
      return new GameSettingsModel();
    }
    return GameSettingsModel.fromTres(raw);
  } catch (err) {
    console.warn(`SettingsEditor: could not load ${FILE_PATH}: ${err.message}. Starting from defaults.`);
    return new GameSettingsModel();
  }
}

async function saveSettings(model) {
  const raw = modelToRaw(model);
  const content = TresParser.serialize(raw);
  await FileDiscovery.saveFile(FILE_DIR, content, FILE_NAME);
  model._raw = raw;
}

/**
 * Render the Game Settings editor into `container`.
 * @param {HTMLElement} container
 * @param {{ onSave?: () => void }} [options]
 */
export async function renderSettingsEditor(container, options) {
  container.innerHTML = '';
  const opts = options || {};

  const model = await loadSettings();

  // Header note
  const info = document.createElement('p');
  info.style.color = 'var(--text-secondary)';
  info.style.margin = '0 0 12px 0';
  info.textContent = `Editing ${FILE_PATH} (singleton). Changes persist on Save.`;
  container.appendChild(info);

  // starting_map dropdown (with text-input fallback)
  const startWrap = document.createElement('div');
  startWrap.style.marginTop = '16px';
  const startLabel = document.createElement('label');
  startLabel.textContent = 'Starting Map';
  startLabel.classList.add('prop-label');
  startLabel.style.display = 'block';
  startWrap.appendChild(startLabel);

  const startSelect = document.createElement('select');
  startSelect.classList.add('prop-input');
  startSelect.style.width = '100%';
  startSelect.style.maxWidth = '400px';

  const knownMaps = Array.from(ProjectContext.files.maps.keys()).sort();
  if (!knownMaps.includes(model.starting_map) && model.starting_map) {
    // Current value isn't in the known maps (e.g. map was deleted) —
    // still offer it so the field round-trips without silently mutating.
    knownMaps.unshift(model.starting_map);
  }
  if (knownMaps.length === 0) {
    const opt = document.createElement('option');
    opt.value = model.starting_map || 'ch1.json';
    opt.textContent = `${model.starting_map || 'ch1.json'} (no maps discovered)`;
    startSelect.appendChild(opt);
  } else {
    for (const name of knownMaps) {
      const opt = document.createElement('option');
      opt.value = name;
      opt.textContent = name;
      if (name === model.starting_map) opt.selected = true;
      startSelect.appendChild(opt);
    }
  }
  startSelect.addEventListener('change', () => {
    model.starting_map = startSelect.value;
  });
  startWrap.appendChild(startSelect);

  const startHint = document.createElement('div');
  startHint.style.color = 'var(--text-secondary)';
  startHint.style.fontSize = '0.85em';
  startHint.style.marginTop = '4px';
  startHint.textContent = 'Loaded on a fresh game. Save files override this once the player progresses.';
  startWrap.appendChild(startHint);

  container.appendChild(startWrap);

  // prop_stream_radius number input
  const radiusWrap = document.createElement('div');
  radiusWrap.style.marginTop = '16px';
  const radiusLabel = document.createElement('label');
  radiusLabel.textContent = 'Prop Render Radius (hex tiles)';
  radiusLabel.classList.add('prop-label');
  radiusLabel.style.display = 'block';
  radiusWrap.appendChild(radiusLabel);

  const radiusInput = document.createElement('input');
  radiusInput.type = 'number';
  radiusInput.min = '0';
  radiusInput.max = '60';
  radiusInput.step = '1';
  radiusInput.value = String(model.prop_stream_radius);
  radiusInput.classList.add('prop-input');
  radiusInput.style.maxWidth = '160px';
  radiusInput.addEventListener('change', () => {
    const v = parseInt(radiusInput.value, 10);
    model.prop_stream_radius = Number.isFinite(v) ? Math.max(0, Math.min(60, v)) : 0;
    radiusInput.value = String(model.prop_stream_radius);
  });
  radiusWrap.appendChild(radiusInput);

  const radiusHint = document.createElement('div');
  radiusHint.style.color = 'var(--text-secondary)';
  radiusHint.style.fontSize = '0.85em';
  radiusHint.style.marginTop = '4px';
  radiusHint.innerHTML = '<strong>0 = unlimited</strong> — every tile on the map renders its natural props + scanner labels. ' +
    'Higher values stream only tiles within N hexes of the player (trade visible range for perf).';
  radiusWrap.appendChild(radiusHint);

  container.appendChild(radiusWrap);

  // Save button + status
  const actionRow = document.createElement('div');
  actionRow.style.marginTop = '20px';
  actionRow.style.display = 'flex';
  actionRow.style.gap = '12px';
  actionRow.style.alignItems = 'center';

  const saveBtn = document.createElement('button');
  saveBtn.textContent = 'Save';
  saveBtn.classList.add('btn-primary', 'prop-btn-primary');

  const statusEl = document.createElement('span');
  statusEl.style.color = 'var(--text-secondary)';

  saveBtn.addEventListener('click', async () => {
    saveBtn.disabled = true;
    statusEl.textContent = 'Saving…';
    try {
      await saveSettings(model);
      statusEl.textContent = `Saved to ${FILE_PATH}.`;
      if (opts.onSave) opts.onSave();
    } catch (err) {
      statusEl.textContent = `Save failed: ${err.message}`;
    } finally {
      saveBtn.disabled = false;
    }
  });

  actionRow.appendChild(saveBtn);
  actionRow.appendChild(statusEl);
  container.appendChild(actionRow);
}
