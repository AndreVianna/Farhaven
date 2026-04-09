// ============================================================
// RecipeEditor — Master-Detail Split Layout (task-039b)
// ============================================================

import { ProjectContext, FileDiscovery } from './file-discovery.js';
import { TresParser, TresFile } from './tres-parser.js';
import { showInlineModal } from './panels.js';

// ============================================================
// Constants
// ============================================================

/** Recipe kind enum values (mirrors Recipe.Kind in GDScript). */
export const RECIPE_KINDS = ['Assemble', 'Transform', 'Breakdown', 'Combine'];

/** Input source options (mirrors RecipeInput.source). */
export const INPUT_SOURCES = ['player_inventory', 'container', 'world_tile', 'world_anywhere'];

/** Known effect kinds (from DESIGN.md). */
export const EFFECT_KINDS = ['stat_delta', 'sound', 'fx', 'emit_light', 'spawn_heat', 'world_change', 'grant_recipe'];

/** Known predicate kinds (from DESIGN.md). */
export const PREDICATE_KINDS = [
  'has_tool', 'at_station', 'at_tile_type', 'player_stat', 'player_skill',
  'player_knows_recipe', 'time_of_day', 'weather', 'biome', 'adjacent_to',
  'prop_state', 'world_flag', 'animal_nearby', 'container_has', 'cataloged',
];

// ============================================================
// RecipeModel
// ============================================================

/**
 * Maps a parsed .tres Recipe to an editable JS model.
 * All fields mirror the Recipe GDScript class.
 */
export class RecipeModel {
  constructor() {
    /** @type {string} ID e.g. '00001' */
    this.id = '';
    /** @type {string} */
    this.display_name = '';
    /** @type {number} 0=Assemble, 1=Transform, 2=Breakdown, 3=Combine */
    this.kind = 0;
    /** @type {Array<{ref_or_tag: string, count: number, source: string, is_tag: boolean}>} */
    this.inputs = [];
    /** @type {Array<{prop_ref: string, count: number, prob: number}>} */
    this.outputs = [];
    /** @type {Array<{kind: string, params: Object<string, *>}>} */
    this.effects = [];
    /** @type {Array<{predicate_kind: string, predicate_params: Object<string, *>, must_sustain: boolean}>} */
    this.conditions = [];
    /** @type {string[]} */
    this.actions = [];
    /** @type {number} */
    this.time = 0;
    /** @type {Array<{kind: string, params: Object<string, *>}>} */
    this.unlock_when = [];

    // Round-trip metadata
    /** @type {string} */
    this._filename = '';
    /** @type {TresFile|null} */
    this._raw = null;
  }

  /**
   * Create a RecipeModel from a ProjectContext recipe entry.
   * The raw TresFile is used to resolve sub_resource references within arrays,
   * since _parseTresFile only resolves top-level sub_resource fields.
   * @param {string} filename - e.g. '00001.tres'
   * @param {{data: Object, raw: TresFile}} entry
   * @returns {RecipeModel}
   */
  static fromEntry(filename, entry) {
    const model = new RecipeModel();
    model.id = filename.replace('.tres', '');
    model._filename = filename;
    model._raw = entry.raw;

    // Build sub_resource lookup from raw TresFile
    const subMap = new Map();
    if (entry.raw && entry.raw.subResources) {
      for (const sub of entry.raw.subResources) {
        const subData = {};
        for (const [k, v] of sub.fields) {
          subData[k] = v.value;
        }
        subMap.set(sub.id, subData);
      }
    }

    /**
     * Resolve a value that might be a sub_resource reference or already resolved data.
     * Array elements from TresParser are TresValue objects {type:'sub_resource', value:'id'}.
     * Top-level fields from _parseTresFile are already resolved objects.
     */
    function resolve(item) {
      if (item && typeof item === 'object' && item.type === 'sub_resource' && typeof item.value === 'string') {
        return subMap.get(item.value) || null;
      }
      return item;
    }

    /** Resolve an array of potentially sub_resource TresValues. */
    function resolveArray(arr) {
      if (!Array.isArray(arr)) return [];
      return arr.map(resolve).filter(x => x != null);
    }

    const d = entry.data;

    model.display_name = _str(d.display_name);
    model.kind = _num(d.kind);
    model.time = _numFloat(d.time);

    // Actions (array of stringname values -> string[])
    model.actions = _strArray(d.actions);

    // Inputs — resolve sub_resource refs within the array
    const inputs = resolveArray(d.inputs);
    model.inputs = inputs.map(inp => {
      if (inp && typeof inp === 'object') {
        return {
          ref_or_tag: _str(inp.ref_or_tag),
          count: _num(inp.count) || 1,
          source: _str(inp.source) || 'player_inventory',
          is_tag: !!inp.is_tag,
        };
      }
      return { ref_or_tag: '', count: 1, source: 'player_inventory', is_tag: false };
    });

    // Outputs — resolve sub_resource refs within the array
    const outputs = resolveArray(d.outputs);
    model.outputs = outputs.map(out => {
      if (out && typeof out === 'object') {
        return {
          prop_ref: _str(out.prop_ref),
          count: _num(out.count) || 1,
          prob: out.prob != null ? _numFloat(out.prob) : 1.0,
        };
      }
      return { prop_ref: '', count: 1, prob: 1.0 };
    });

    // Effects — resolve sub_resource refs within the array
    const effects = resolveArray(d.effects);
    model.effects = effects.map(eff => {
      if (eff && typeof eff === 'object') {
        return {
          kind: _str(eff.kind),
          params: _dictToObj(eff.params),
        };
      }
      return { kind: '', params: {} };
    });

    // Conditions — resolve sub_resource refs (each has predicate + must_sustain)
    // The condition sub_resource has a 'predicate' field which is itself a sub_resource ref
    const conditions = resolveArray(d.conditions);
    model.conditions = conditions.map(cond => {
      if (cond && typeof cond === 'object') {
        // Resolve the nested predicate sub_resource reference
        let pred = cond.predicate;
        if (typeof pred === 'string') {
          // It's a sub_resource id string (from the resolved sub data)
          pred = subMap.get(pred) || {};
        }
        return {
          predicate_kind: _str(pred.kind),
          predicate_params: _dictToObj(pred.params),
          must_sustain: !!cond.must_sustain,
        };
      }
      return { predicate_kind: '', predicate_params: {}, must_sustain: false };
    });

    // unlock_when — resolve sub_resource refs (array of predicates)
    const unlockPreds = resolveArray(d.unlock_when);
    model.unlock_when = unlockPreds.map(pred => {
      if (pred && typeof pred === 'object') {
        return {
          kind: _str(pred.kind),
          params: _dictToObj(pred.params),
        };
      }
      return { kind: '', params: {} };
    });

    return model;
  }
}

// ============================================================
// Internal Helpers
// ============================================================

function _str(val) {
  if (val == null) return '';
  return String(val);
}

function _strArray(val) {
  if (!Array.isArray(val)) return [];
  return val.map(item => {
    if (item && typeof item === 'object' && 'value' in item) return String(item.value);
    if (item == null) return '';
    return String(item);
  });
}

function _num(val) {
  if (typeof val === 'number') return val;
  const n = parseInt(String(val), 10);
  return isNaN(n) ? 0 : n;
}

function _numFloat(val) {
  if (typeof val === 'number') return val;
  const n = parseFloat(String(val));
  return isNaN(n) ? 0 : n;
}

function _dictToObj(val) {
  if (!(val instanceof Map)) {
    if (val && typeof val === 'object' && !(val instanceof Array)) {
      // Already a plain object — convert TresValue entries if needed
      const obj = {};
      for (const [key, tv] of Object.entries(val)) {
        obj[key] = tv && typeof tv === 'object' && 'value' in tv ? tv.value : tv;
      }
      return obj;
    }
    return {};
  }
  const obj = {};
  for (const [key, tv] of val) {
    obj[key] = tv && typeof tv === 'object' && 'value' in tv ? tv.value : tv;
  }
  return obj;
}

// ============================================================
// Form Data Collection
// ============================================================

/**
 * Collect recipe form data from the form element into a RecipeModel.
 * @param {HTMLFormElement} formElement
 * @returns {RecipeModel}
 */
export function collectRecipeFormData(formElement) {
  const model = new RecipeModel();

  function val(name) {
    const el = formElement.querySelector(`[name="${name}"]`);
    return el ? /** @type {HTMLInputElement} */ (el).value : '';
  }

  function floatVal(name) {
    const v = parseFloat(val(name));
    return isNaN(v) ? 0 : v;
  }

  function intVal(name) {
    const v = parseInt(val(name), 10);
    return isNaN(v) ? 0 : v;
  }

  model.id = val('id').trim();
  model.display_name = val('display_name').trim();
  model.kind = intVal('kind');
  model.time = floatVal('time');

  // Actions
  model.actions = _collectTagChips(formElement, 'actions');

  // Inputs
  model.inputs = _collectListSection(formElement, 'inputs', (row) => {
    return {
      ref_or_tag: _rowVal(row, 'ref_or_tag'),
      count: _rowInt(row, 'count') || 1,
      source: _rowVal(row, 'source') || 'player_inventory',
      is_tag: _rowChecked(row, 'is_tag'),
    };
  });

  // Outputs
  model.outputs = _collectListSection(formElement, 'outputs', (row) => {
    return {
      prop_ref: _rowVal(row, 'prop_ref'),
      count: _rowInt(row, 'count') || 1,
      prob: _rowFloat(row, 'prob'),
    };
  });

  // Effects
  model.effects = _collectListSection(formElement, 'effects', (row) => {
    return {
      kind: _rowVal(row, 'kind'),
      params: _collectRowKv(row),
    };
  });

  // Conditions
  model.conditions = _collectListSection(formElement, 'conditions', (row) => {
    return {
      predicate_kind: _rowVal(row, 'predicate_kind'),
      predicate_params: _collectRowKv(row),
      must_sustain: _rowChecked(row, 'must_sustain'),
    };
  });

  // unlock_when
  model.unlock_when = _collectListSection(formElement, 'unlock_when', (row) => {
    return {
      kind: _rowVal(row, 'kind'),
      params: _collectRowKv(row),
    };
  });

  return model;
}

function _rowVal(row, name) {
  const el = row.querySelector(`[data-field="${name}"]`);
  return el ? /** @type {HTMLInputElement} */ (el).value.trim() : '';
}

function _rowInt(row, name) {
  const v = parseInt(_rowVal(row, name), 10);
  return isNaN(v) ? 0 : v;
}

function _rowFloat(row, name) {
  const v = parseFloat(_rowVal(row, name));
  return isNaN(v) ? 0 : v;
}

function _rowChecked(row, name) {
  const el = row.querySelector(`[data-field="${name}"]`);
  return el ? /** @type {HTMLInputElement} */ (el).checked : false;
}

/** Collect key-value pairs from a row's kv-editor. */
function _collectRowKv(row) {
  const result = {};
  const container = row.querySelector('[data-kv-rows]');
  if (!container) return result;
  for (const kvRow of container.children) {
    const keyInput = kvRow.querySelector('[data-kv-key]');
    const valInput = kvRow.querySelector('[data-kv-val]');
    if (keyInput && valInput) {
      const k = /** @type {HTMLInputElement} */ (keyInput).value.trim();
      const rawVal = /** @type {HTMLInputElement} */ (valInput).value.trim();
      if (k) {
        // Try to parse as number, boolean, or keep as string
        if (rawVal === 'true') result[k] = true;
        else if (rawVal === 'false') result[k] = false;
        else {
          const num = parseFloat(rawVal);
          result[k] = isNaN(num) ? rawVal : num;
        }
      }
    }
  }
  return result;
}

/** Collect tag chips from a tag editor container. */
function _collectTagChips(formElement, name) {
  const result = [];
  const container = formElement.querySelector(`[data-tag-chips="${name}"]`);
  if (!container) return result;
  for (const chip of container.children) {
    const tag = /** @type {HTMLElement} */ (chip).dataset.tagValue;
    if (tag) result.push(tag);
  }
  return result;
}

/** Collect items from a list section. */
function _collectListSection(formElement, name, rowMapper) {
  const container = formElement.querySelector(`[data-list-rows="${name}"]`);
  if (!container) return [];
  const result = [];
  for (const row of container.children) {
    result.push(rowMapper(row));
  }
  return result;
}

// ============================================================
// Form Validation
// ============================================================

/**
 * Validate a recipe model.
 * @param {RecipeModel} model
 * @param {boolean} isNew
 * @returns {{ valid: boolean, errors: string[] }}
 */
export function validateRecipeForm(model, isNew) {
  const errors = [];

  if (!model.id) {
    errors.push('ID is required');
  } else if (!/^[a-zA-Z0-9_]+$/.test(model.id)) {
    errors.push('ID must contain only alphanumeric characters and underscores');
  } else if (isNew && ProjectContext.files.recipes.has(model.id + '.tres')) {
    errors.push(`Recipe "${model.id}" already exists`);
  }

  if (!model.display_name) {
    errors.push('Display Name is required');
  }

  if (model.kind < 0 || model.kind > 3) {
    errors.push('Kind must be 0-3 (Assemble, Transform, Breakdown, Combine)');
  }

  if (model.time < 0) {
    errors.push('Time must be >= 0');
  }

  // Validate inputs
  for (let i = 0; i < model.inputs.length; i++) {
    const inp = model.inputs[i];
    if (!inp.ref_or_tag) {
      errors.push(`Input #${i + 1}: ref_or_tag is required`);
    }
    if (inp.count < 1) {
      errors.push(`Input #${i + 1}: count must be >= 1`);
    }
    if (!INPUT_SOURCES.includes(inp.source)) {
      errors.push(`Input #${i + 1}: invalid source "${inp.source}"`);
    }
  }

  // Validate outputs
  for (let i = 0; i < model.outputs.length; i++) {
    const out = model.outputs[i];
    if (!out.prop_ref) {
      errors.push(`Output #${i + 1}: prop_ref is required`);
    }
    if (out.count < 1) {
      errors.push(`Output #${i + 1}: count must be >= 1`);
    }
    if (out.prob < 0 || out.prob > 1) {
      errors.push(`Output #${i + 1}: prob must be in [0, 1]`);
    }
  }

  // Validate effects
  for (let i = 0; i < model.effects.length; i++) {
    const eff = model.effects[i];
    if (!eff.kind) {
      errors.push(`Effect #${i + 1}: kind is required`);
    }
  }

  // Validate conditions
  for (let i = 0; i < model.conditions.length; i++) {
    const cond = model.conditions[i];
    if (!cond.predicate_kind) {
      errors.push(`Condition #${i + 1}: predicate kind is required`);
    }
  }

  // Validate unlock_when
  for (let i = 0; i < model.unlock_when.length; i++) {
    const pred = model.unlock_when[i];
    if (!pred.kind) {
      errors.push(`Unlock predicate #${i + 1}: kind is required`);
    }
  }

  return { valid: errors.length === 0, errors };
}

// ============================================================
// Model -> TresFile Serialization
// ============================================================

/**
 * Convert a model to a plain object for dirty comparison.
 * @param {RecipeModel} model
 * @returns {Object}
 */
function _modelToPlain(model) {
  return {
    id: model.id,
    display_name: model.display_name,
    kind: model.kind,
    inputs: model.inputs,
    outputs: model.outputs,
    effects: model.effects,
    conditions: model.conditions,
    actions: model.actions,
    time: model.time,
    unlock_when: model.unlock_when,
  };
}

/**
 * Convert a dict-style params object to a TresValue dict.
 * @param {Object<string, *>} obj
 * @returns {import('./tres-parser.js').TresValue}
 */
function _paramsDictToTres(obj) {
  const map = new Map();
  for (const [key, val] of Object.entries(obj)) {
    if (typeof val === 'boolean') {
      map.set(key, { type: 'bool', value: val });
    } else if (typeof val === 'number') {
      map.set(key, { type: Number.isInteger(val) ? 'int' : 'float', value: val });
    } else if (typeof val === 'string') {
      // Check if it looks like a stringname reference (starts with &")
      map.set(key, { type: 'string', value: String(val) });
    } else {
      map.set(key, { type: 'string', value: String(val) });
    }
  }
  return { type: 'dict', value: map, braceSpaces: true };
}

/**
 * Update a TresFile's resourceFields from a RecipeModel.
 * For new recipes, creates a fresh TresFile.
 * @param {RecipeModel} model
 * @returns {TresFile}
 */
export function recipeModelToRaw(model) {
  let raw;

  if (model._raw) {
    raw = model._raw;
  } else {
    raw = new TresFile();
    raw.scriptClass = 'Recipe';
    raw.lineEnding = '\n';
  }

  const extResources = [];
  const subResources = [];
  const fields = new Map();
  let extId = 1;

  // Recipe script is always ext_resource #1
  const scriptExtId = '1_recipe';
  extResources.push(`[ext_resource type="Script" path="res://scripts/recipes/recipe.gd" id="${scriptExtId}"]`);
  extId++;

  // Collect which ext_resource scripts we need
  const needInput = model.inputs.length > 0;
  const needOutput = model.outputs.length > 0;
  const needEffect = model.effects.length > 0;
  const needCondition = model.conditions.length > 0;
  const needPredicate = model.conditions.length > 0 || model.unlock_when.length > 0;

  let inputExtId = '';
  let outputExtId = '';
  let effectExtId = '';
  let conditionExtId = '';
  let predicateExtId = '';

  if (needInput) {
    inputExtId = `${extId}_input`;
    extResources.push(`[ext_resource type="Script" path="res://scripts/recipes/recipe_input.gd" id="${inputExtId}"]`);
    extId++;
  }
  if (needOutput) {
    outputExtId = `${extId}_output`;
    extResources.push(`[ext_resource type="Script" path="res://scripts/recipes/recipe_output.gd" id="${outputExtId}"]`);
    extId++;
  }
  if (needEffect) {
    effectExtId = `${extId}_effect`;
    extResources.push(`[ext_resource type="Script" path="res://scripts/recipes/recipe_effect.gd" id="${effectExtId}"]`);
    extId++;
  }
  if (needCondition) {
    conditionExtId = `${extId}_condition`;
    extResources.push(`[ext_resource type="Script" path="res://scripts/recipes/recipe_condition.gd" id="${conditionExtId}"]`);
    extId++;
  }
  if (needPredicate) {
    predicateExtId = `${extId}_predicate`;
    extResources.push(`[ext_resource type="Script" path="res://scripts/recipes/predicate.gd" id="${predicateExtId}"]`);
    extId++;
  }

  // Build sub_resources for inputs
  const inputSubIds = [];
  for (let i = 0; i < model.inputs.length; i++) {
    const inp = model.inputs[i];
    const subId = `input_${i + 1}`;
    const subFields = new Map();
    subFields.set('script', { type: 'ext_resource', value: `ExtResource("${inputExtId}")` });
    subFields.set('ref_or_tag', { type: 'stringname', value: inp.ref_or_tag });
    subFields.set('count', { type: 'int', value: inp.count });
    if (inp.source && inp.source !== 'player_inventory') {
      subFields.set('source', { type: 'stringname', value: inp.source });
    }
    if (inp.is_tag) {
      subFields.set('is_tag', { type: 'bool', value: true });
    }
    subResources.push({ type: 'Resource', id: subId, fields: subFields });
    inputSubIds.push(subId);
  }

  // Build sub_resources for outputs
  const outputSubIds = [];
  for (let i = 0; i < model.outputs.length; i++) {
    const out = model.outputs[i];
    const subId = `output_${i + 1}`;
    const subFields = new Map();
    subFields.set('script', { type: 'ext_resource', value: `ExtResource("${outputExtId}")` });
    subFields.set('prop_ref', { type: 'stringname', value: out.prop_ref });
    subFields.set('count', { type: 'int', value: out.count });
    if (out.prob !== 1.0) {
      subFields.set('prob', { type: 'float', value: out.prob });
    }
    subResources.push({ type: 'Resource', id: subId, fields: subFields });
    outputSubIds.push(subId);
  }

  // Build sub_resources for effects
  const effectSubIds = [];
  for (let i = 0; i < model.effects.length; i++) {
    const eff = model.effects[i];
    const subId = `effect_${i + 1}`;
    const subFields = new Map();
    subFields.set('script', { type: 'ext_resource', value: `ExtResource("${effectExtId}")` });
    subFields.set('kind', { type: 'stringname', value: eff.kind });
    if (Object.keys(eff.params).length > 0) {
      subFields.set('params', _paramsDictToTres(eff.params));
    }
    subResources.push({ type: 'Resource', id: subId, fields: subFields });
    effectSubIds.push(subId);
  }

  // Build sub_resources for conditions (each has a predicate sub_resource)
  const conditionSubIds = [];
  for (let i = 0; i < model.conditions.length; i++) {
    const cond = model.conditions[i];
    // Create the predicate sub_resource first
    const predSubId = `cond_pred_${i + 1}`;
    const predFields = new Map();
    predFields.set('script', { type: 'ext_resource', value: `ExtResource("${predicateExtId}")` });
    predFields.set('kind', { type: 'stringname', value: cond.predicate_kind });
    if (Object.keys(cond.predicate_params).length > 0) {
      predFields.set('params', _paramsDictToTres(cond.predicate_params));
    }
    subResources.push({ type: 'Resource', id: predSubId, fields: predFields });

    // Create the condition sub_resource
    const condSubId = `condition_${i + 1}`;
    const condFields = new Map();
    condFields.set('script', { type: 'ext_resource', value: `ExtResource("${conditionExtId}")` });
    condFields.set('predicate', { type: 'sub_resource', value: predSubId });
    condFields.set('must_sustain', { type: 'bool', value: cond.must_sustain });
    subResources.push({ type: 'Resource', id: condSubId, fields: condFields });
    conditionSubIds.push(condSubId);
  }

  // Build sub_resources for unlock_when (array of predicates)
  const unlockSubIds = [];
  for (let i = 0; i < model.unlock_when.length; i++) {
    const pred = model.unlock_when[i];
    const subId = `unlock_pred_${i + 1}`;
    const subFields = new Map();
    subFields.set('script', { type: 'ext_resource', value: `ExtResource("${predicateExtId}")` });
    subFields.set('kind', { type: 'stringname', value: pred.kind });
    if (Object.keys(pred.params).length > 0) {
      subFields.set('params', _paramsDictToTres(pred.params));
    }
    subResources.push({ type: 'Resource', id: subId, fields: subFields });
    unlockSubIds.push(subId);
  }

  // Update header
  const loadSteps = extResources.length + subResources.length;
  raw.headerLine = `[gd_resource type="Resource" script_class="Recipe" load_steps=${loadSteps} format=3]`;
  raw.extResources = extResources;
  raw.subResources = subResources;

  // Build [resource] fields
  fields.set('script', { type: 'ext_resource', value: `ExtResource("${scriptExtId}")` });
  fields.set('id', { type: 'stringname', value: model.id });
  fields.set('display_name', { type: 'string', value: model.display_name });
  fields.set('kind', { type: 'int', value: model.kind });

  if (inputSubIds.length > 0) {
    fields.set('inputs', {
      type: 'array', elementType: null,
      value: inputSubIds.map(id => ({ type: 'sub_resource', value: id })),
    });
  }

  if (outputSubIds.length > 0) {
    fields.set('outputs', {
      type: 'array', elementType: null,
      value: outputSubIds.map(id => ({ type: 'sub_resource', value: id })),
    });
  } else if (model._raw) {
    // Preserve explicit empty outputs array if it was in the original
    const origOutputs = model._raw.resourceFields.get('outputs');
    if (origOutputs) {
      fields.set('outputs', { type: 'array', elementType: null, value: [] });
    }
  }

  if (effectSubIds.length > 0) {
    fields.set('effects', {
      type: 'array', elementType: null,
      value: effectSubIds.map(id => ({ type: 'sub_resource', value: id })),
    });
  }

  if (conditionSubIds.length > 0) {
    fields.set('conditions', {
      type: 'array', elementType: null,
      value: conditionSubIds.map(id => ({ type: 'sub_resource', value: id })),
    });
  }

  if (model.actions.length > 0) {
    fields.set('actions', {
      type: 'array', elementType: null,
      value: model.actions.map(a => ({ type: 'stringname', value: a })),
    });
  }

  if (model.time !== 0) {
    fields.set('time', { type: 'float', value: model.time });
  }

  if (unlockSubIds.length > 0) {
    fields.set('unlock_when', {
      type: 'array', elementType: null,
      value: unlockSubIds.map(id => ({ type: 'sub_resource', value: id })),
    });
  }

  // Preserve any unknown fields from the original .tres
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

export class CreateRecipeCommand {
  constructor(model) {
    this._model = model;
    this._filename = model.id + '.tres';
    this.tab = 'recipes';
    this.type = 'CreateRecipe';
  }

  execute() {
    const raw = recipeModelToRaw(this._model);
    const content = TresParser.serialize(raw);

    const data = {};
    for (const [key, tv] of raw.resourceFields) {
      data[key] = tv.value;
    }

    ProjectContext.files.recipes.set(this._filename, {
      handle: null,
      dir: 'data/recipes',
      data,
      raw,
    });

    FileDiscovery.saveFile('data/recipes', content, this._filename).catch((err) => {
      console.warn(`CreateRecipeCommand: Failed to save "${this._filename}": ${err.message}`);
    });
  }

  undo() {
    ProjectContext.files.recipes.delete(this._filename);
  }
}

export class EditRecipeCommand {
  constructor(filename, oldModel, newModel) {
    this._filename = filename;
    this._oldModel = oldModel;
    this._newModel = newModel;
    this._oldRaw = oldModel._raw;
    this.tab = 'recipes';
    this.type = 'EditRecipe';
  }

  execute() {
    const raw = recipeModelToRaw(this._newModel);
    const content = TresParser.serialize(raw);

    const data = {};
    for (const [key, tv] of raw.resourceFields) {
      data[key] = tv.value;
    }

    const entry = ProjectContext.files.recipes.get(this._filename);
    if (entry) {
      entry.data = data;
      entry.raw = raw;
    }

    FileDiscovery.saveFile('data/recipes', content, this._filename).catch((err) => {
      console.warn(`EditRecipeCommand: Failed to save "${this._filename}": ${err.message}`);
    });
  }

  undo() {
    if (this._oldRaw) {
      const entry = ProjectContext.files.recipes.get(this._filename);
      if (entry) {
        entry.raw = this._oldRaw;
        const data = {};
        for (const [key, tv] of this._oldRaw.resourceFields) {
          data[key] = tv.value;
        }
        entry.data = data;
      }
      const content = TresParser.serialize(this._oldRaw);
      FileDiscovery.saveFile('data/recipes', content, this._filename).catch((err) => {
        console.warn(`EditRecipeCommand.undo: Failed to save "${this._filename}": ${err.message}`);
      });
    }
  }
}

export class DeleteRecipeCommand {
  constructor(filename, model) {
    this._filename = filename;
    this._model = model;
    this._savedEntry = null;
    this.tab = 'recipes';
    this.type = 'DeleteRecipe';
  }

  execute() {
    this._savedEntry = ProjectContext.files.recipes.get(this._filename) || null;
    ProjectContext.files.recipes.delete(this._filename);
  }

  undo() {
    if (this._savedEntry) {
      ProjectContext.files.recipes.set(this._filename, this._savedEntry);
      const content = TresParser.serialize(this._savedEntry.raw);
      FileDiscovery.saveFile('data/recipes', content, this._filename).catch((err) => {
        console.warn(`DeleteRecipeCommand.undo: Failed to save "${this._filename}": ${err.message}`);
      });
    }
  }
}

// ============================================================
// UI Rendering
// ============================================================

/**
 * Render the Recipe Editor page.
 * @param {HTMLElement} container
 * @param {Object} [options]
 */
export function renderRecipeEditor(container, options) {
  container.innerHTML = '';

  const cmdHistory = options && options.commandHistory ? options.commandHistory : null;
  const onChange = options && typeof options.onChange === 'function' ? options.onChange : () => {};
  const onSave = options && typeof options.onSave === 'function' ? options.onSave : onChange;

  // --- Split layout ---
  const split = document.createElement('div');
  split.classList.add('editor-split');

  // --- Left panel ---
  const listPanel = document.createElement('div');
  listPanel.classList.add('editor-list-panel');

  const listHeader = document.createElement('div');
  listHeader.classList.add('editor-list-header');

  // Kind filter
  const kindLabel = document.createElement('label');
  kindLabel.textContent = 'Kind:';
  kindLabel.style.cssText = 'font-size:10px;color:var(--text-secondary);';
  const kindFilter = document.createElement('select');
  kindFilter.classList.add('editor-filter');
  kindFilter.style.marginBottom = '4px';
  const kindAll = document.createElement('option');
  kindAll.value = 'all'; kindAll.textContent = 'All'; kindAll.selected = true;
  kindFilter.appendChild(kindAll);
  for (let i = 0; i < RECIPE_KINDS.length; i++) {
    const opt = document.createElement('option');
    opt.value = String(i); opt.textContent = RECIPE_KINDS[i];
    kindFilter.appendChild(opt);
  }

  // Text filter
  const filterInput = document.createElement('input');
  filterInput.type = 'text';
  filterInput.placeholder = 'Filter...';
  filterInput.classList.add('editor-filter');

  const newBtn = document.createElement('button');
  newBtn.textContent = '+ New';
  newBtn.classList.add('editor-new-btn');

  listHeader.appendChild(kindLabel);
  listHeader.appendChild(kindFilter);
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
  let selectedId = null;
  let isNewMode = false;
  let editingModel = null;
  let initialJson = '';

  function _guardDirty() {
    if (!editingModel) return true;
    const form = detailPanel.querySelector('form');
    if (!form) return true;
    const currentData = collectRecipeFormData(/** @type {HTMLFormElement} */ (form));
    const currentJson = JSON.stringify(_modelToPlain(currentData));
    if (currentJson !== initialJson) {
      return confirm('Discard unsaved changes?');
    }
    return true;
  }

  // --- Build the recipe list ---
  function refreshList() {
    listItems.innerHTML = '';
    const textFilter = filterInput.value.toLowerCase().trim();
    const kindVal = kindFilter.value;

    const allRecipes = [];
    for (const [filename, entry] of ProjectContext.files.recipes) {
      const model = RecipeModel.fromEntry(filename, entry);
      allRecipes.push({ id: model.id, displayName: model.display_name || model.id, kind: model.kind });
    }
    allRecipes.sort((a, b) => a.id.localeCompare(b.id));

    for (const recipe of allRecipes) {
      if (kindVal !== 'all' && String(recipe.kind) !== kindVal) continue;
      if (textFilter && !recipe.displayName.toLowerCase().includes(textFilter) && !recipe.id.toLowerCase().includes(textFilter)) continue;

      const item = document.createElement('div');
      item.classList.add('editor-list-item');
      if (recipe.id === selectedId && !isNewMode) {
        item.classList.add('active');
      }
      item.dataset.id = recipe.id;

      const span = document.createElement('span');
      span.textContent = `${recipe.id} — ${recipe.displayName}`;
      item.appendChild(span);

      const kindBadge = document.createElement('small');
      kindBadge.textContent = RECIPE_KINDS[recipe.kind] || '?';
      kindBadge.style.cssText = 'margin-left:auto;font-size:10px;color:var(--text-secondary);';
      item.appendChild(kindBadge);

      item.addEventListener('click', () => {
        if (!_guardDirty()) return;
        isNewMode = false;
        selectedId = recipe.id;
        const entry = ProjectContext.files.recipes.get(recipe.id + '.tres');
        if (entry) {
          editingModel = RecipeModel.fromEntry(recipe.id + '.tres', entry);
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
    empty.textContent = 'Select a recipe';
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
    headerName.textContent = isNew ? 'New Recipe' : `${model.id} — ${model.display_name}`;
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

    const grid = document.createElement('div');
    grid.classList.add('prop-grid');

    // ID
    _addField(grid, 'ID', 'id', 'text', model.id, isNew ? { pattern: '^[a-zA-Z0-9_]+$' } : { disabled: '' });
    // Display Name
    _addField(grid, 'Display Name', 'display_name', 'text', model.display_name);
    // Kind
    _addSelectField(grid, 'Kind', 'kind', model.kind, RECIPE_KINDS.map((k, i) => ({ value: String(i), label: k })));
    // Time
    _addField(grid, 'Time (seconds)', 'time', 'number', model.time, { step: 'any', min: '0' });

    // --- Actions ---
    _addSeparator(grid, 'Actions');
    grid.appendChild(_createActionsEditor(model.actions));

    // --- Inputs ---
    _addSeparator(grid, 'Inputs');
    grid.appendChild(_createInputListEditor(model.inputs));

    // --- Outputs ---
    _addSeparator(grid, 'Outputs');
    grid.appendChild(_createOutputListEditor(model.outputs));

    // --- Effects ---
    _addSeparator(grid, 'Effects');
    grid.appendChild(_createEffectListEditor(model.effects));

    // --- Conditions ---
    _addSeparator(grid, 'Conditions');
    grid.appendChild(_createConditionListEditor(model.conditions));

    // --- Unlock When ---
    _addSeparator(grid, 'Unlock When');
    grid.appendChild(_createPredicateListEditor('unlock_when', model.unlock_when));

    body.appendChild(grid);
    form.appendChild(body);
    detailPanel.appendChild(form);

    // Recapture initialJson
    initialJson = JSON.stringify(_modelToPlain(collectRecipeFormData(/** @type {HTMLFormElement} */ (form))));

    // --- Save handler ---
    saveBtn.addEventListener('click', () => {
      const collected = collectRecipeFormData(form);
      collected._filename = isNew ? collected.id + '.tres' : model._filename;
      collected._raw = model._raw;

      const validation = validateRecipeForm(collected, isNew);
      if (!validation.valid) {
        errorArea.style.display = 'block';
        errorArea.textContent = validation.errors.join('; ');
        return;
      }

      if (isNew) {
        const cmd = new CreateRecipeCommand(collected, cmdHistory);
        if (cmdHistory) { cmdHistory.execute(cmd); } else { cmd.execute(); }
        isNewMode = false;
        selectedId = collected.id;
        const entry = ProjectContext.files.recipes.get(collected.id + '.tres');
        if (entry) {
          editingModel = RecipeModel.fromEntry(collected.id + '.tres', entry);
        }
      } else {
        const cmd = new EditRecipeCommand(model._filename, model, collected, cmdHistory);
        if (cmdHistory) { cmdHistory.execute(cmd); } else { cmd.execute(); }
        const entry = ProjectContext.files.recipes.get(model._filename);
        if (entry) {
          editingModel = RecipeModel.fromEntry(model._filename, entry);
        }
      }

      refreshList();
      _renderDetail();
      onSave();
    });

    // --- Delete handler ---
    deleteBtn.addEventListener('click', () => {
      if (confirm(`Delete recipe "${model.id}"? This cannot be undone without undo.`)) {
        const cmd = new DeleteRecipeCommand(model._filename, model, cmdHistory);
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
  kindFilter.addEventListener('change', () => refreshList());

  newBtn.addEventListener('click', () => {
    if (!_guardDirty()) return;
    isNewMode = true;
    selectedId = null;
    editingModel = new RecipeModel();

    // Auto-increment ID
    let maxId = 0;
    for (const [filename] of ProjectContext.files.recipes) {
      const numId = parseInt(filename.replace('.tres', ''), 10);
      if (!isNaN(numId) && numId > maxId) maxId = numId;
    }
    editingModel.id = String(maxId + 1).padStart(5, '0');

    initialJson = JSON.stringify(_modelToPlain(editingModel));
    _updateListSelection();
    _renderDetail();
  });

  // --- Initial render ---
  refreshList();
  _showEmpty();
}

// ============================================================
// UI Field Helpers (matching prop-editor pattern)
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
    const option = document.createElement('option');
    option.value = opt.value;
    option.textContent = opt.label;
    if (String(value) === opt.value) option.selected = true;
    select.appendChild(option);
  }
  grid.appendChild(select);
}

function _addSeparator(grid, text) {
  const sep = document.createElement('div');
  sep.classList.add('prop-separator');
  sep.textContent = text;
  grid.appendChild(sep);
}

// ============================================================
// Actions Tag Editor
// ============================================================

function _createActionsEditor(actions) {
  const wrapper = document.createElement('div');
  wrapper.classList.add('prop-full');

  const chipsContainer = document.createElement('div');
  chipsContainer.dataset.tagChips = 'actions';
  chipsContainer.style.cssText = 'display:flex;flex-wrap:wrap;gap:4px;margin-bottom:4px;';
  wrapper.appendChild(chipsContainer);

  function addChip(tag) {
    const chip = document.createElement('span');
    chip.style.cssText = 'display:inline-flex;align-items:center;gap:2px;padding:2px 6px;background:var(--bg-tertiary);border:1px solid var(--border);border-radius:10px;font-size:11px;color:var(--text-primary);';
    chip.dataset.tagValue = tag;

    const text = document.createElement('span');
    text.textContent = tag;
    chip.appendChild(text);

    const removeBtn = document.createElement('button');
    removeBtn.textContent = '\u00d7';
    removeBtn.type = 'button';
    removeBtn.style.cssText = 'border:none;background:none;color:var(--text-secondary);cursor:pointer;font-size:13px;padding:0 2px;line-height:1;';
    removeBtn.addEventListener('click', () => chip.remove());
    chip.appendChild(removeBtn);

    chipsContainer.appendChild(chip);
  }

  for (const action of actions) {
    addChip(action);
  }

  const addRow = document.createElement('div');
  addRow.style.cssText = 'display:flex;gap:4px;';

  const addInput = document.createElement('input');
  addInput.type = 'text';
  addInput.placeholder = 'New action...';
  addInput.classList.add('prop-input');
  addInput.style.flex = '1';

  const addBtn = document.createElement('button');
  addBtn.textContent = '+ Add';
  addBtn.type = 'button';
  addBtn.style.cssText = 'padding:2px 8px;border:1px solid var(--border);border-radius:3px;background:var(--bg-tertiary);color:var(--text-primary);cursor:pointer;font-size:11px;';
  addBtn.addEventListener('click', () => {
    const val = addInput.value.trim();
    if (val) { addChip(val); addInput.value = ''; }
  });

  addInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { e.preventDefault(); addBtn.click(); }
  });

  addRow.appendChild(addInput);
  addRow.appendChild(addBtn);
  wrapper.appendChild(addRow);

  return wrapper;
}

// ============================================================
// Input List Editor
// ============================================================

function _createInputListEditor(inputs) {
  const wrapper = document.createElement('div');
  wrapper.classList.add('prop-full');

  const rowsContainer = document.createElement('div');
  rowsContainer.dataset.listRows = 'inputs';
  wrapper.appendChild(rowsContainer);

  function addRow(inp) {
    const row = document.createElement('div');
    row.style.cssText = 'display:flex;flex-wrap:wrap;gap:4px;margin-bottom:6px;padding:6px;border:1px solid var(--border);border-radius:4px;align-items:center;';

    _appendInput(row, 'ref_or_tag', 'text', inp.ref_or_tag, 'Prop ID or Tag', { flex: '2' });
    _appendInput(row, 'count', 'number', inp.count, 'Count', { width: '60px', min: '1', step: '1' });
    _appendSelect(row, 'source', inp.source, INPUT_SOURCES.map(s => ({ value: s, label: s })));
    _appendCheckbox(row, 'is_tag', inp.is_tag, 'Tag?');
    _appendRemoveBtn(row);

    rowsContainer.appendChild(row);
  }

  for (const inp of inputs) { addRow(inp); }

  const addBtn = document.createElement('button');
  addBtn.textContent = '+ Add Input';
  addBtn.type = 'button';
  addBtn.style.cssText = 'padding:2px 8px;border:1px solid var(--border);border-radius:3px;background:var(--bg-tertiary);color:var(--text-primary);cursor:pointer;font-size:11px;margin-top:2px;';
  addBtn.addEventListener('click', () => addRow({ ref_or_tag: '', count: 1, source: 'player_inventory', is_tag: false }));
  wrapper.appendChild(addBtn);

  return wrapper;
}

// ============================================================
// Output List Editor
// ============================================================

function _createOutputListEditor(outputs) {
  const wrapper = document.createElement('div');
  wrapper.classList.add('prop-full');

  const rowsContainer = document.createElement('div');
  rowsContainer.dataset.listRows = 'outputs';
  wrapper.appendChild(rowsContainer);

  function addRow(out) {
    const row = document.createElement('div');
    row.style.cssText = 'display:flex;flex-wrap:wrap;gap:4px;margin-bottom:6px;padding:6px;border:1px solid var(--border);border-radius:4px;align-items:center;';

    _appendInput(row, 'prop_ref', 'text', out.prop_ref, 'Prop ID', { flex: '2' });
    _appendInput(row, 'count', 'number', out.count, 'Count', { width: '60px', min: '1', step: '1' });
    _appendInput(row, 'prob', 'number', out.prob, 'Prob', { width: '70px', min: '0', max: '1', step: '0.01' });
    _appendRemoveBtn(row);

    rowsContainer.appendChild(row);
  }

  for (const out of outputs) { addRow(out); }

  const addBtn = document.createElement('button');
  addBtn.textContent = '+ Add Output';
  addBtn.type = 'button';
  addBtn.style.cssText = 'padding:2px 8px;border:1px solid var(--border);border-radius:3px;background:var(--bg-tertiary);color:var(--text-primary);cursor:pointer;font-size:11px;margin-top:2px;';
  addBtn.addEventListener('click', () => addRow({ prop_ref: '', count: 1, prob: 1.0 }));
  wrapper.appendChild(addBtn);

  return wrapper;
}

// ============================================================
// Effect List Editor
// ============================================================

function _createEffectListEditor(effects) {
  const wrapper = document.createElement('div');
  wrapper.classList.add('prop-full');

  const rowsContainer = document.createElement('div');
  rowsContainer.dataset.listRows = 'effects';
  wrapper.appendChild(rowsContainer);

  function addRow(eff) {
    const row = document.createElement('div');
    row.style.cssText = 'margin-bottom:6px;padding:6px;border:1px solid var(--border);border-radius:4px;';

    const topRow = document.createElement('div');
    topRow.style.cssText = 'display:flex;gap:4px;align-items:center;margin-bottom:4px;';
    _appendSelect(topRow, 'kind', eff.kind, EFFECT_KINDS.map(k => ({ value: k, label: k })));
    _appendRemoveBtn(topRow);
    row.appendChild(topRow);

    row.appendChild(_createInlineKvEditor(eff.params));
    rowsContainer.appendChild(row);
  }

  for (const eff of effects) { addRow(eff); }

  const addBtn = document.createElement('button');
  addBtn.textContent = '+ Add Effect';
  addBtn.type = 'button';
  addBtn.style.cssText = 'padding:2px 8px;border:1px solid var(--border);border-radius:3px;background:var(--bg-tertiary);color:var(--text-primary);cursor:pointer;font-size:11px;margin-top:2px;';
  addBtn.addEventListener('click', () => addRow({ kind: EFFECT_KINDS[0], params: {} }));
  wrapper.appendChild(addBtn);

  return wrapper;
}

// ============================================================
// Condition List Editor
// ============================================================

function _createConditionListEditor(conditions) {
  const wrapper = document.createElement('div');
  wrapper.classList.add('prop-full');

  const rowsContainer = document.createElement('div');
  rowsContainer.dataset.listRows = 'conditions';
  wrapper.appendChild(rowsContainer);

  function addRow(cond) {
    const row = document.createElement('div');
    row.style.cssText = 'margin-bottom:6px;padding:6px;border:1px solid var(--border);border-radius:4px;';

    const topRow = document.createElement('div');
    topRow.style.cssText = 'display:flex;gap:4px;align-items:center;margin-bottom:4px;';
    _appendSelect(topRow, 'predicate_kind', cond.predicate_kind, PREDICATE_KINDS.map(k => ({ value: k, label: k })));
    _appendCheckbox(topRow, 'must_sustain', cond.must_sustain, 'Sustain?');
    _appendRemoveBtn(topRow);
    row.appendChild(topRow);

    row.appendChild(_createInlineKvEditor(cond.predicate_params));
    rowsContainer.appendChild(row);
  }

  for (const cond of conditions) { addRow(cond); }

  const addBtn = document.createElement('button');
  addBtn.textContent = '+ Add Condition';
  addBtn.type = 'button';
  addBtn.style.cssText = 'padding:2px 8px;border:1px solid var(--border);border-radius:3px;background:var(--bg-tertiary);color:var(--text-primary);cursor:pointer;font-size:11px;margin-top:2px;';
  addBtn.addEventListener('click', () => addRow({ predicate_kind: PREDICATE_KINDS[0], predicate_params: {}, must_sustain: false }));
  wrapper.appendChild(addBtn);

  return wrapper;
}

// ============================================================
// Predicate List Editor (for unlock_when)
// ============================================================

function _createPredicateListEditor(name, predicates) {
  const wrapper = document.createElement('div');
  wrapper.classList.add('prop-full');

  const rowsContainer = document.createElement('div');
  rowsContainer.dataset.listRows = name;
  wrapper.appendChild(rowsContainer);

  function addRow(pred) {
    const row = document.createElement('div');
    row.style.cssText = 'margin-bottom:6px;padding:6px;border:1px solid var(--border);border-radius:4px;';

    const topRow = document.createElement('div');
    topRow.style.cssText = 'display:flex;gap:4px;align-items:center;margin-bottom:4px;';
    _appendSelect(topRow, 'kind', pred.kind, PREDICATE_KINDS.map(k => ({ value: k, label: k })));
    _appendRemoveBtn(topRow);
    row.appendChild(topRow);

    row.appendChild(_createInlineKvEditor(pred.params));
    rowsContainer.appendChild(row);
  }

  for (const pred of predicates) { addRow(pred); }

  const addBtn = document.createElement('button');
  addBtn.textContent = '+ Add Predicate';
  addBtn.type = 'button';
  addBtn.style.cssText = 'padding:2px 8px;border:1px solid var(--border);border-radius:3px;background:var(--bg-tertiary);color:var(--text-primary);cursor:pointer;font-size:11px;margin-top:2px;';
  addBtn.addEventListener('click', () => addRow({ kind: PREDICATE_KINDS[0], params: {} }));
  wrapper.appendChild(addBtn);

  return wrapper;
}

// ============================================================
// Inline KV Editor (for params dicts)
// ============================================================

function _createInlineKvEditor(data) {
  const wrapper = document.createElement('div');

  const rowsContainer = document.createElement('div');
  rowsContainer.dataset.kvRows = '';
  wrapper.appendChild(rowsContainer);

  function addKvRow(key, val) {
    const row = document.createElement('div');
    row.style.cssText = 'display:flex;gap:4px;margin-bottom:4px;align-items:center;';

    const keyInput = document.createElement('input');
    keyInput.type = 'text';
    keyInput.value = key;
    keyInput.placeholder = 'key';
    keyInput.dataset.kvKey = '';
    keyInput.classList.add('prop-input');
    keyInput.style.flex = '1';

    const valInput = document.createElement('input');
    valInput.type = 'text';
    valInput.value = String(val);
    valInput.placeholder = 'value';
    valInput.dataset.kvVal = '';
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

  for (const [key, val] of Object.entries(data)) {
    addKvRow(key, val);
  }

  const addBtn = document.createElement('button');
  addBtn.textContent = '+ Param';
  addBtn.type = 'button';
  addBtn.style.cssText = 'padding:2px 8px;border:1px solid var(--border);border-radius:3px;background:var(--bg-tertiary);color:var(--text-primary);cursor:pointer;font-size:11px;margin-top:2px;';
  addBtn.addEventListener('click', () => addKvRow('', ''));
  wrapper.appendChild(addBtn);

  return wrapper;
}

// ============================================================
// Row Component Helpers
// ============================================================

function _appendInput(parent, fieldName, type, value, placeholder, styles) {
  const input = document.createElement('input');
  input.type = type;
  input.value = String(value != null ? value : '');
  input.placeholder = placeholder || '';
  input.dataset.field = fieldName;
  input.classList.add('prop-input');
  if (styles) {
    for (const [k, v] of Object.entries(styles)) {
      input.style[k] = v;
    }
  }
  parent.appendChild(input);
}

function _appendSelect(parent, fieldName, value, options) {
  const select = document.createElement('select');
  select.dataset.field = fieldName;
  select.classList.add('prop-input');
  for (const opt of options) {
    const option = document.createElement('option');
    option.value = opt.value;
    option.textContent = opt.label;
    if (String(value) === opt.value) option.selected = true;
    select.appendChild(option);
  }
  parent.appendChild(select);
}

function _appendCheckbox(parent, fieldName, checked, label) {
  const wrapper = document.createElement('label');
  wrapper.style.cssText = 'display:flex;align-items:center;gap:3px;font-size:11px;color:var(--text-secondary);white-space:nowrap;';
  const cb = document.createElement('input');
  cb.type = 'checkbox';
  cb.checked = !!checked;
  cb.dataset.field = fieldName;
  wrapper.appendChild(cb);
  wrapper.appendChild(document.createTextNode(label));
  parent.appendChild(wrapper);
}

function _appendRemoveBtn(parent) {
  const removeBtn = document.createElement('button');
  removeBtn.textContent = 'X';
  removeBtn.type = 'button';
  removeBtn.style.cssText = 'padding:2px 6px;border:1px solid var(--border);border-radius:3px;background:var(--bg-tertiary);color:var(--text-secondary);cursor:pointer;font-size:11px;margin-left:auto;';
  removeBtn.addEventListener('click', () => {
    const row = removeBtn.closest('[data-list-rows] > div, [data-list-rows] > div');
    if (row) row.remove();
    else removeBtn.parentElement.parentElement.remove();
  });
  parent.appendChild(removeBtn);
}
