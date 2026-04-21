// ============================================================
// PropEditor — Master-Detail Split Layout (Side-by-Side Detail)
// ============================================================

import { ProjectContext, FileDiscovery, nextId } from './file-discovery.js';
import { TresParser, TresFile } from './tres-parser.js';
import { showInlineModal } from './panels.js';
import { CATEGORIES, RARITIES, ORIGINS, NATURAL_CATEGORIES, ORIGIN_TO_INT } from './hex-grid.js';
import { renderGearHeader } from './editor-common.js';
import { getRefIndex, renderRefPanel } from './cross-refs.js';

/**
 * Render the preview column for a prop's detail pane:
 * DROP SOURCES on top + REFERENCES (concept art thumbnails) below.
 * @param {HTMLElement} container
 * @param {string} propId
 */
function _renderPropDropSources(container, propId) {
  container.innerHTML = '';

  // Drop sources (biomes that spawn this prop)
  const dropWrap = document.createElement('div');
  container.appendChild(dropWrap);
  const rows = getRefIndex().forProp(propId).map(s => ({
    swatch: s.biomeColor,
    label: s.biomeName,
    meta: `${Math.round(s.frequency * 100)}%  ${s.groupRange[0]}-${s.groupRange[1]}`,
  }));
  renderRefPanel(dropWrap, 'DROP SOURCES', rows,
    propId ? 'No biome spawns this prop.' : 'Save the new prop to see drop sources.');

  // References (concept art thumbnails) — fills the otherwise empty
  // bottom of the preview column. 3 slots (reference_v1/v2/v3.png);
  // server returns 404 for any that don't exist and the <img> onerror
  // handler hides those thumbnails so authors don't see broken icons.
  if (propId) {
    const refsTitle = document.createElement('div');
    refsTitle.className = 'section-title';
    refsTitle.textContent = 'REFERENCES';
    refsTitle.style.marginTop = '16px';
    container.appendChild(refsTitle);

    const grid = document.createElement('div');
    grid.style.cssText = 'display:grid;grid-template-columns:1fr 1fr;gap:6px;';
    for (let v = 1; v <= 3; v++) {
      const thumb = document.createElement('div');
      thumb.style.cssText = 'aspect-ratio:1;background:var(--bg-2);border:1px solid var(--line);border-radius:3px;overflow:hidden;display:flex;align-items:center;justify-content:center;position:relative;';
      const img = document.createElement('img');
      img.style.cssText = 'width:100%;height:100%;object-fit:cover;display:block;';
      img.alt = `Reference v${v}`;
      img.src = `/api/asset?path=${encodeURIComponent(`assets/props/${propId}/reference_v${v}.png`)}`;
      img.onerror = () => { thumb.style.display = 'none'; };
      const label = document.createElement('span');
      label.style.cssText = 'position:absolute;bottom:2px;left:4px;font-family:var(--font-mono);font-size:9.5px;color:var(--text-0);background:rgba(0,0,0,0.55);padding:1px 4px;border-radius:2px;';
      label.textContent = `v${v}`;
      thumb.appendChild(img);
      thumb.appendChild(label);
      grid.appendChild(thumb);
    }
    container.appendChild(grid);
  }
}

/**
 * Maps a parsed .tres PropDef to an editable JS prop model.
 * All fields mirror the PropDef GDScript class.
 *
 * Capability fields are nullable objects — null means the capability is not present.
 */
export class PropDefModel {
  constructor() {
    /** @type {string} Filename stem e.g. '00010' */
    this.id = '';
    /** @type {string} */
    this.display_name = '';

    // --- Tags ---
    /** @type {string[]} Free-form tag list */
    this.tags = [];

    // --- Capabilities (null = not enabled) ---
    /** @type {{ slot_shape: Array<{x:number,y:number}> }|null} */
    this.portable = null;
    /** @type {{ footprint: Array<{x:number,y:number}>, blocks_movement: boolean, rotation_snap: number }|null} */
    this.placeable = null;
    /** @type {{ grid_width: number, grid_height: number, accepts_filter: string[] }|null} */
    this.container = null;
    /** @type {{ radius: number, color: {r:number,g:number,b:number,a:number}, flicker: boolean }|null} */
    this.light = null;
    /** @type {{ push_cost: number }|null} */
    this.movable = null;
    /** @type {{ station_tags: string[] }|null} */
    this.station = null;
    /** @type {{ scan_time: number, show_as_anomaly: boolean, properties: Object }|null} */
    this.catalogable = null;
    /** @type {{ hp: number, vulnerabilities: string[], resistances: string[], immunities: string[] }|null} */
    this.endurance = null;
    /**
     * Movement cap: array of {mode, normal, max} rows.
     * null = capability disabled; [] = enabled but no modes yet.
     * @type {{ modes: Array<{mode: number, normal: number, max: number}> }|null}
     */
    this.movement = null;
    /** @type {{ attacks: Array, defenses: Array }|null} */
    this.combat = null;
    /** @type {{ detection_range: number, activity_cycle: number, group_behavior: number, diet: string[], reactions: Array }|null} */
    this.behavior = null;
    /** @type {{ spawn_min: number, spawn_max: number, first_spawn_day: number, spawn_min_distance: number, allowed_biomes: string[] }|null} */
    this.spawnable = null;
    /** @type {{ yields: Array<{item_id: string, amount: number, conditions: string[]}>, respawn_conditions: string[] }|null} */
    this.harvestable = null;

    // --- Gear base fields ---
    /** @type {string} One-line summary for tooltips */
    this.short_description = '';
    /** @type {string} Full description for detail panels */
    this.long_description = '';

    // --- Inventory ---
    /** @type {number} */
    this.max_stack = 99;

    // --- Classification ---
    /** @type {string} Primary category (plant/mineral/animal/fungi/ooze/liquid/stuff/structure/equipment/vehicle/storage) */
    this.category = '';
    /** @type {string} Rarity tier (common/uncommon/rare) */
    this.rarity = 'common';

    // --- Placement ---
    /** @type {string} Default origin for placement */
    this.prop_origin = 'natural';
    /** @type {Array<{x: number, y: number}>} Legacy footprint (top-level, alongside PLACEABLE) */
    this.footprint = [];

    // --- Tool ---
    /** @type {string} Tool slot name (e.g. "axe", "pickaxe"). Empty = not a tool. */
    this.tool_slot = '';

    // --- Visuals ---
    // Placeholder fields removed — all visual rendering now comes from
    // PlaceableCap.meshes (visible/placed) and HarvestableCap.depleted_meshes
    // (after harvest). See assets/props/{id}/reference_v{n}.png for preview.

    // --- Legacy fields (DEPRECATED — kept for round-trip during transition) ---
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
    /** @type {Object<string, number>} */
    this.tool_speed = {};
    /** @type {boolean} */
    this.emits_light = false;
    /** @type {number} */
    this.light_radius = 0;
    /** @type {boolean} */
    this.is_respawn_point = false;
    /** @type {boolean} */
    this.is_crafting_station = false;
    /** @type {boolean} */
    this.is_consumable = false;
    /** @type {number} */
    this.hunger_restore = 0;
    /** @type {number} */
    this.thirst_restore = 0;
    /** @type {number} */
    this.health_restore = 0;

    // Round-trip metadata
    /** @type {string} */
    this._filename = '';
    /** @type {import('./tres-parser.js').TresFile|null} */
    this._raw = null;
  }

  /**
   * Create a PropDefModel from a ProjectContext prop definition entry.
   * @param {string} filename - e.g. '00010.tres'
   * @param {{data: Object, raw: import('./tres-parser.js').TresFile}} entry
   * @returns {PropDefModel}
   */
  static fromEntry(filename, entry) {
    const model = new PropDefModel();
    model.id = filename.replace('.tres', '');
    model._filename = filename;
    model._raw = entry.raw;

    const d = entry.data;

    // Simple string fields
    model.display_name = _str(d.display_name);
    model.short_description = _str(d.short_description);
    model.long_description = _str(d.long_description);
    model.tool_slot = _str(d.tool_slot);

    // Tags (array of stringname values -> string[])
    model.tags = _strArray(d.tags);

    // Numeric fields (max_stack still read for round-trip but no longer shown in UI)
    model.max_stack = _num(d.max_stack) || 99;

    // Legacy footprint (top-level)
    model.footprint = _footprintArray(d.footprint);

    // Classification
    model.category = _str(d.category);
    model.rarity = _str(d.rarity) || 'common';
    // Placement defaults
    model.prop_origin = ORIGINS[_num(d.origin)] || 'natural';

    // --- Capabilities (resolved sub_resource data from file-discovery) ---
    if (d.portable && typeof d.portable === 'object') {
      model.portable = {
        slot_shape: _vector2iArray(d.portable.slot_shape, [{x:0,y:0}]),
      };
    }

    if (d.placeable && typeof d.placeable === 'object') {
      // Parse meshes (Array[Resource] of MeshVariant sub_resources). Nested
      // array refs stay as { type: 'sub_resource', value: 'id' } and need
      // lookup via entry.raw.subResources, same pattern as harvestable yields.
      const subMap = new Map();
      if (entry.raw && entry.raw.subResources) {
        for (const sub of entry.raw.subResources) {
          const subData = {};
          for (const [k, v] of sub.fields) subData[k] = v.value;
          subMap.set(sub.id, subData);
        }
      }
      // TresParser wraps `Array[Resource]([...])` as an outer array of one
      // inner array TresValue. Unwrap to the inner refs. Plain `[...]` parses
      // as the flat list directly.
      let meshRefs = Array.isArray(d.placeable.meshes) ? d.placeable.meshes : [];
      if (meshRefs.length === 1 && meshRefs[0] && meshRefs[0].type === 'array' && Array.isArray(meshRefs[0].value)) {
        meshRefs = meshRefs[0].value;
      }
      const meshes = [];
      for (const ref of meshRefs) {
        let md = null;
        if (ref && typeof ref === 'object' && ref.type === 'sub_resource') {
          md = subMap.get(ref.value) || null;
        } else if (ref && typeof ref === 'object') {
          md = ref;
        }
        if (md) {
          meshes.push({
            scene: _resolveExtResourcePath(md.scene, entry.raw),
            scale: _num(md.scale) || 1.0,
          });
        }
      }

      // Parse collision_shapes (Array[Resource] of CollisionShape sub_resources).
      // Same outer-array unwrap as meshes above.
      let collisionRefs = Array.isArray(d.placeable.collision_shapes) ? d.placeable.collision_shapes : [];
      if (collisionRefs.length === 1 && collisionRefs[0] && collisionRefs[0].type === 'array' && Array.isArray(collisionRefs[0].value)) {
        collisionRefs = collisionRefs[0].value;
      }
      const collision_shapes = [];
      for (const ref of collisionRefs) {
        let cd = null;
        if (ref && typeof ref === 'object' && ref.type === 'sub_resource') {
          cd = subMap.get(ref.value) || null;
        } else if (ref && typeof ref === 'object') {
          cd = ref;
        }
        if (cd) {
          const sz = cd.size;
          const off = cd.offset;
          collision_shapes.push({
            shape_type: _str(cd.shape_type) || 'box',
            size: sz && typeof sz === 'object' ? { x: _num(sz.x), y: _num(sz.y), z: _num(sz.z) } : { x: 1, y: 1, z: 1 },
            offset: off && typeof off === 'object' ? { x: _num(off.x), y: _num(off.y), z: _num(off.z) } : { x: 0, y: 0, z: 0 },
          });
        }
      }

      // feature-011: scatter preset lives inside PlaceableCap as a
      // plain int (default SINGLE = 0).
      const placement = Number.isInteger(d.placeable.placement) ? d.placeable.placement : 0;
      // Slope handling (2026-04-21): max_allowed_slope (degrees, 0-90)
      // gates Populate; slope_blend (0-1) controls runtime terrain-
      // normal tilt.
      const max_allowed_slope = Number.isFinite(d.placeable.max_allowed_slope)
        ? d.placeable.max_allowed_slope : 90;
      const slope_blend = typeof d.placeable.slope_blend === 'number'
        ? d.placeable.slope_blend : 1.0;
      model.placeable = { meshes, collision_shapes, placement, max_allowed_slope, slope_blend };
    }

    if (d.container && typeof d.container === 'object') {
      model.container = {
        grid_width: _num(d.container.grid_width != null ? d.container.grid_width : 30),
        grid_height: _num(d.container.grid_height != null ? d.container.grid_height : 40),
        accepts_filter: _strArray(d.container.accepts_filter),
      };
    }

    if (d.light && typeof d.light === 'object') {
      model.light = {
        radius: _num(d.light.radius),
        color: _color(d.light.color),
        flicker: !!d.light.flicker,
      };
    }

    if (d.movable && typeof d.movable === 'object') {
      model.movable = {
        push_cost: _num(d.movable.push_cost != null ? d.movable.push_cost : 1.0),
      };
    }

    if (d.station && typeof d.station === 'object') {
      model.station = {
        station_tags: _strArray(d.station.station_tags),
      };
    }

    if (d.catalogable && typeof d.catalogable === 'object') {
      model.catalogable = {
        scan_time: _num(d.catalogable.scan_time != null ? d.catalogable.scan_time : 1.0),
        show_as_anomaly: !!d.catalogable.show_as_anomaly,
        properties: _dictToObj(d.catalogable.properties),
      };
    }

    if (d.endurance && typeof d.endurance === 'object') {
      model.endurance = {
        hp: _num(d.endurance.hp != null ? d.endurance.hp : 1),
        vulnerabilities: _strArray(d.endurance.vulnerabilities),
        resistances: _strArray(d.endurance.resistances),
        immunities: _strArray(d.endurance.immunities),
      };
    }

    if (d.movement && typeof d.movement === 'object') {
      model.movement = {
        modes: _movementModes(d.movement.modes),
      };
    }

    if (d.combat && typeof d.combat === 'object') {
      model.combat = {
        attacks: [],   // TODO: wire GameEvent refs when editor supports them
        defenses: [],
      };
    }

    if (d.behavior && typeof d.behavior === 'object') {
      model.behavior = {
        detection_range: _num(d.behavior.detection_range != null ? d.behavior.detection_range : 2),
        activity_cycle: _num(d.behavior.activity_cycle),
        group_behavior: _num(d.behavior.group_behavior),
        diet: _strArray(d.behavior.diet),
        reactions: [],  // TODO: wire GameEvent refs
      };
    }

    if (d.spawnable && typeof d.spawnable === 'object') {
      model.spawnable = {
        spawn_min: _num(d.spawnable.spawn_min != null ? d.spawnable.spawn_min : 1),
        spawn_max: _num(d.spawnable.spawn_max != null ? d.spawnable.spawn_max : 1),
        first_spawn_day: _num(d.spawnable.first_spawn_day != null ? d.spawnable.first_spawn_day : 1),
        spawn_min_distance: _num(d.spawnable.spawn_min_distance != null ? d.spawnable.spawn_min_distance : 3),
        allowed_biomes: _strArray(d.spawnable.allowed_biomes),
      };
    }

    if (d.harvestable && typeof d.harvestable === 'object') {
      // Resolve nested sub_resource refs in yields array. file-discovery
      // only resolves top-level refs; array elements stay as
      // { type: 'sub_resource', value: 'yield_id' } and need lookup.
      const subMap = new Map();
      if (entry.raw && entry.raw.subResources) {
        for (const sub of entry.raw.subResources) {
          const subData = {};
          for (const [k, v] of sub.fields) subData[k] = v.value;
          subMap.set(sub.id, subData);
        }
      }
      const yieldRefs = Array.isArray(d.harvestable.yields) ? d.harvestable.yields : [];
      const yields = [];
      for (const ref of yieldRefs) {
        let yd = null;
        if (ref && typeof ref === 'object' && ref.type === 'sub_resource') {
          yd = subMap.get(ref.value) || null;
        } else if (ref && typeof ref === 'object') {
          yd = ref; // already resolved
        }
        if (yd) {
          yields.push({
            item_id: _str(yd.item_id),
            amount: _num(yd.amount) || 1,
            conditions: _strArray(yd.conditions),
          });
        }
      }
      model.harvestable = {
        yields: yields,
        respawn_conditions: _strArray(d.harvestable.respawn_conditions),
      };
    }

    // --- Legacy fields (still in .tres during transition, kept for round-trip) ---
    model.gather_time = _num(d.gather_time);
    model.gather_amount = _num(d.gather_amount);
    model.tool_required = _str(d.tool_required);
    model.respawn_time = _num(d.respawn_time);
    model.yield_type = _str(d.yield_type);
    model.tool_speed = _dictToObj(d.tool_speed);
    model.emits_light = !!d.emits_light;
    model.light_radius = _num(d.light_radius);
    model.is_respawn_point = !!d.is_respawn_point;
    model.is_crafting_station = !!d.is_crafting_station;
    model.is_consumable = !!d.is_consumable;
    model.hunger_restore = _num(d.hunger_restore);
    model.thirst_restore = _num(d.thirst_restore);
    model.health_restore = _num(d.health_restore);

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
 * Safely extract a string array value. Handles TresValue arrays and plain arrays.
 * @param {*} val
 * @returns {string[]}
 */
function _strArray(val) {
  if (!Array.isArray(val)) return [];
  return val.map(item => {
    if (item && typeof item === 'object' && 'value' in item) return String(item.value);
    if (item == null) return '';
    return String(item);
  });
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
 * Convert a parsed movement `modes` dict into the editor model's array form.
 * Input is a Map<int, TresValue> where each value is an array TresValue of
 * two float TresValues: [normal_speed, max_speed].
 * Also tolerates plain objects/arrays for robustness in tests.
 * @param {*} val
 * @returns {Array<{mode: number, normal: number, max: number}>}
 */
function _movementModes(val) {
  const result = [];
  if (val == null) return result;

  /**
   * Normalize a "speeds" entry to [normal, max] numbers.
   * @param {*} speeds
   * @returns {[number, number]}
   */
  function _speedPair(speeds) {
    // TresValue array: { type: 'array', value: [ {type:'float',value:n}, ... ] }
    if (speeds && typeof speeds === 'object' && 'type' in speeds && speeds.type === 'array') {
      const elems = Array.isArray(speeds.value) ? speeds.value : [];
      const n = elems[0] && typeof elems[0] === 'object' && 'value' in elems[0] ? elems[0].value : 0;
      const m = elems[1] && typeof elems[1] === 'object' && 'value' in elems[1] ? elems[1].value : 0;
      return [Number(n) || 0, Number(m) || 0];
    }
    // Plain array with TresValue or primitive numbers
    if (Array.isArray(speeds)) {
      const n = speeds[0] && typeof speeds[0] === 'object' && 'value' in speeds[0] ? speeds[0].value : speeds[0];
      const m = speeds[1] && typeof speeds[1] === 'object' && 'value' in speeds[1] ? speeds[1].value : speeds[1];
      return [Number(n) || 0, Number(m) || 0];
    }
    return [0, 0];
  }

  if (val instanceof Map) {
    for (const [k, speeds] of val) {
      const [n, m] = _speedPair(speeds);
      result.push({ mode: Number(k) || 0, normal: n, max: m });
    }
    return result;
  }
  if (typeof val === 'object') {
    for (const [k, speeds] of Object.entries(val)) {
      const [n, m] = _speedPair(speeds);
      result.push({ mode: parseInt(k, 10) || 0, normal: n, max: m });
    }
  }
  return result;
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
 * Parse a footprint field into an array of {x, y} offsets.
 * Handles TresValue objects and plain {x,y} objects.
 * @param {*} val
 * @returns {Array<{x: number, y: number}>}
 */
function _footprintArray(val) {
  if (!Array.isArray(val)) return [];
  return val.map(item => {
    // TresValue: { type: 'vector2i', value: { x, y } }
    if (item && typeof item === 'object' && item.type === 'vector2i' && item.value) {
      return { x: item.value.x, y: item.value.y };
    }
    // Plain { x, y }
    if (item && typeof item === 'object' && 'x' in item) {
      return { x: item.x, y: item.y };
    }
    return { x: 0, y: 0 };
  });
}

/**
 * Parse a Vector2i array from parsed .tres data, with fallback.
 * Handles both TresValue objects ({type:'vector2i', value:{x,y}}) and plain {x,y} objects.
 * @param {*} val - Parsed value (array or undefined/null)
 * @param {Array<{x:number,y:number}>} fallback - Default if val is not a valid array
 * @returns {Array<{x:number,y:number}>}
 */
function _vector2iArray(val, fallback) {
  if (!Array.isArray(val) || val.length === 0) return fallback;
  return val.map(item => {
    if (item && typeof item === 'object' && item.type === 'vector2i' && item.value) {
      return { x: item.value.x, y: item.value.y };
    }
    if (item && typeof item === 'object' && 'x' in item) {
      return { x: item.x, y: item.y };
    }
    return { x: 0, y: 0 };
  });
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
    removeBtn.classList.add('prop-btn-icon');
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
  addBtn.classList.add('prop-btn');
  addBtn.addEventListener('click', () => addRow('', 0));
  wrapper.appendChild(addBtn);

  return wrapper;
}

/**
 * Create a footprint editor with Vector2i rows (x, y pairs).
 * @param {Array<{x: number, y: number}>} footprint
 * @returns {HTMLElement}
 */
function _createFootprintEditor(footprint) {
  const wrapper = document.createElement('div');
  wrapper.classList.add('prop-full');

  const label = document.createElement('div');
  label.textContent = 'Footprint cells (x, y)';
  label.classList.add('prop-label');
  wrapper.appendChild(label);

  const rowsContainer = document.createElement('div');
  rowsContainer.dataset.footprintRows = '';
  wrapper.appendChild(rowsContainer);

  /**
   * Add a footprint row.
   * @param {number} x
   * @param {number} y
   * @returns {void}
   */
  function addRow(x, y) {
    const row = document.createElement('div');
    row.style.cssText = 'display:flex;gap:4px;margin-bottom:4px;align-items:center;';

    const xInput = document.createElement('input');
    xInput.type = 'number';
    xInput.value = String(x);
    xInput.step = '1';
    xInput.placeholder = 'x';
    xInput.dataset.fpX = '';
    xInput.classList.add('prop-input');
    xInput.style.flex = '1';

    const yInput = document.createElement('input');
    yInput.type = 'number';
    yInput.value = String(y);
    yInput.step = '1';
    yInput.placeholder = 'y';
    yInput.dataset.fpY = '';
    yInput.classList.add('prop-input');
    yInput.style.flex = '1';

    const removeBtn = document.createElement('button');
    removeBtn.textContent = 'X';
    removeBtn.type = 'button';
    removeBtn.classList.add('prop-btn-icon');
    removeBtn.addEventListener('click', () => row.remove());

    row.appendChild(xInput);
    row.appendChild(yInput);
    row.appendChild(removeBtn);
    rowsContainer.appendChild(row);
  }

  // Populate existing entries
  for (const cell of footprint) {
    addRow(cell.x, cell.y);
  }

  const addBtn = document.createElement('button');
  addBtn.textContent = '+ Add Cell';
  addBtn.type = 'button';
  addBtn.classList.add('prop-btn');
  addBtn.addEventListener('click', () => addRow(0, 0));
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
// Tag Editor
// ============================================================

/**
 * Create a chip/tag input editor for StringName tags.
 * @param {string[]} tags - Current tag values
 * @returns {HTMLElement}
 */
function _createTagEditor(tags) {
  const wrapper = document.createElement('div');
  wrapper.classList.add('prop-full');
  wrapper.dataset.tagEditor = '';

  const label = document.createElement('div');
  label.textContent = 'Tags';
  label.classList.add('prop-label');
  wrapper.appendChild(label);

  const chipsContainer = document.createElement('div');
  chipsContainer.dataset.tagChips = '';
  chipsContainer.style.cssText = 'display:flex;flex-wrap:wrap;gap:4px;margin-bottom:4px;';
  wrapper.appendChild(chipsContainer);

  /** @param {string} tag */
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
    removeBtn.classList.add('prop-btn-icon');
    removeBtn.addEventListener('click', () => chip.remove());
    chip.appendChild(removeBtn);

    chipsContainer.appendChild(chip);
  }

  for (const tag of tags) {
    addChip(tag);
  }

  const addRow = document.createElement('div');
  addRow.style.cssText = 'display:flex;gap:4px;';

  const addInput = document.createElement('input');
  addInput.type = 'text';
  addInput.placeholder = 'New tag...';
  addInput.classList.add('prop-input');
  addInput.style.flex = '1';

  const addBtn = document.createElement('button');
  addBtn.textContent = '+ Add';
  addBtn.type = 'button';
  addBtn.classList.add('prop-btn');
  addBtn.addEventListener('click', () => {
    const val = addInput.value.trim();
    if (val) {
      addChip(val);
      addInput.value = '';
    }
  });

  addInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      addBtn.click();
    }
  });

  addRow.appendChild(addInput);
  addRow.appendChild(addBtn);
  wrapper.appendChild(addRow);

  return wrapper;
}

// ============================================================
// Capability Panel
// ============================================================

/**
 * Create a collapsible capability panel with enable/disable checkbox.
 * Fields are only shown when the capability is enabled.
 * @param {string} capName - Capability name (e.g. 'portable')
 * @param {string} label - Display label (e.g. 'Portable')
 * @param {Object|null} capData - Current capability data (null = disabled)
 * @param {function(HTMLElement): void} renderFields - Function to render fields into the panel
 * @returns {HTMLElement}
 */
function _createCapabilityPanel(capName, label, capData, renderFields) {
  const wrapper = document.createElement('div');
  wrapper.classList.add('prop-full');
  wrapper.dataset.capPanel = capName;
  wrapper.style.cssText = 'border:1px solid var(--border);border-radius:4px;padding:6px 8px;margin-bottom:6px;';

  const header = document.createElement('div');
  header.style.cssText = 'display:flex;align-items:center;gap:6px;';

  const checkbox = document.createElement('input');
  checkbox.type = 'checkbox';
  checkbox.name = 'cap_' + capName + '_enabled';
  checkbox.checked = capData != null;

  const headerLabel = document.createElement('span');
  headerLabel.textContent = label;
  headerLabel.style.cssText = 'font-size:11px;font-weight:bold;text-transform:uppercase;letter-spacing:0.5px;color:var(--text-secondary);';

  header.appendChild(checkbox);
  header.appendChild(headerLabel);
  wrapper.appendChild(header);

  const fieldsContainer = document.createElement('div');
  fieldsContainer.classList.add('prop-grid');
  fieldsContainer.dataset.capFields = capName;
  fieldsContainer.style.display = capData != null ? '' : 'none';

  renderFields(fieldsContainer);
  wrapper.appendChild(fieldsContainer);

  checkbox.addEventListener('change', () => {
    fieldsContainer.style.display = checkbox.checked ? '' : 'none';
  });

  return wrapper;
}

// ============================================================
// Capability Footprint Editor (for PLACEABLE)
// ============================================================

/**
 * Create a footprint editor for a capability's footprint field.
 * @param {Array<{x: number, y: number}>} footprint
 * @returns {HTMLElement}
 */
function _createCapFootprintEditor(footprint) {
  const wrapper = document.createElement('div');
  wrapper.classList.add('prop-full');

  const label = document.createElement('div');
  label.textContent = 'Footprint cells (x, y)';
  label.classList.add('prop-label');
  wrapper.appendChild(label);

  const rowsContainer = document.createElement('div');
  rowsContainer.dataset.capFootprintRows = '';
  wrapper.appendChild(rowsContainer);

  function addRow(x, y) {
    const row = document.createElement('div');
    row.style.cssText = 'display:flex;gap:4px;margin-bottom:4px;align-items:center;';

    const xInput = document.createElement('input');
    xInput.type = 'number';
    xInput.value = String(x);
    xInput.step = '1';
    xInput.placeholder = 'x';
    xInput.dataset.capFpX = '';
    xInput.classList.add('prop-input');
    xInput.style.flex = '1';

    const yInput = document.createElement('input');
    yInput.type = 'number';
    yInput.value = String(y);
    yInput.step = '1';
    yInput.placeholder = 'y';
    yInput.dataset.capFpY = '';
    yInput.classList.add('prop-input');
    yInput.style.flex = '1';

    const removeBtn = document.createElement('button');
    removeBtn.textContent = 'X';
    removeBtn.type = 'button';
    removeBtn.classList.add('prop-btn-icon');
    removeBtn.addEventListener('click', () => row.remove());

    row.appendChild(xInput);
    row.appendChild(yInput);
    row.appendChild(removeBtn);
    rowsContainer.appendChild(row);
  }

  for (const cell of footprint) {
    addRow(cell.x, cell.y);
  }

  const addBtn = document.createElement('button');
  addBtn.textContent = '+ Add Cell';
  addBtn.type = 'button';
  addBtn.classList.add('prop-btn');
  addBtn.addEventListener('click', () => addRow(0, 0));
  wrapper.appendChild(addBtn);

  return wrapper;
}

// ============================================================
// ============================================================
// Shape Grid Editor (for PORTABLE slot_shape)
// ============================================================

/**
 * Create a clickable 10x10 grid for editing a slot_shape.
 * Clicking a cell toggles it on/off. "On" cells are the shape.
 * @param {string} fieldId - Identifier for the grid widget
 * @param {Array<{x:number,y:number}>} shape - Current shape cells
 * @returns {HTMLElement}
 */
function _createShapeEditor(fieldId, shape) {
  const GRID_SIZE = 10;
  const CELL_PX = 20;

  const wrapper = document.createElement('div');
  wrapper.classList.add('prop-full');
  wrapper.dataset.shapeEditor = fieldId;

  const label = document.createElement('div');
  label.textContent = 'Slot Shape (click to toggle cells)';
  label.classList.add('prop-label');
  wrapper.appendChild(label);

  const countLabel = document.createElement('span');
  countLabel.style.cssText = 'font-size:11px;color:var(--text-secondary);margin-left:6px;';
  countLabel.dataset.shapeCount = fieldId;
  label.appendChild(countLabel);

  // Build a set of active cells for quick lookup
  const activeSet = new Set(shape.map(c => `${c.x},${c.y}`));

  const grid = document.createElement('div');
  grid.style.cssText = `display:inline-grid;grid-template-columns:repeat(${GRID_SIZE},${CELL_PX}px);gap:1px;border:1px solid var(--border);border-radius:3px;padding:2px;background:var(--bg-tertiary);`;

  function updateCount() {
    const on = wrapper.querySelectorAll(`[data-shape-cell][data-active="1"]`);
    countLabel.textContent = ` (${on.length} cell${on.length !== 1 ? 's' : ''})`;
  }

  for (let y = 0; y < GRID_SIZE; y++) {
    for (let x = 0; x < GRID_SIZE; x++) {
      const cell = document.createElement('div');
      const key = `${x},${y}`;
      const isActive = activeSet.has(key);
      cell.dataset.shapeCell = key;
      cell.dataset.active = isActive ? '1' : '0';
      cell.style.cssText = `width:${CELL_PX}px;height:${CELL_PX}px;border:1px solid var(--border);border-radius:2px;cursor:pointer;transition:background 0.1s;`;
      cell.style.background = isActive ? 'var(--accent, #4a9eff)' : 'transparent';
      cell.title = `(${x}, ${y})`;
      cell.addEventListener('click', () => {
        const nowActive = cell.dataset.active === '1';
        cell.dataset.active = nowActive ? '0' : '1';
        cell.style.background = nowActive ? 'transparent' : 'var(--accent, #4a9eff)';
        updateCount();
      });
      grid.appendChild(cell);
    }
  }

  wrapper.appendChild(grid);
  updateCount();
  return wrapper;
}

// ============================================================
// Collision Shapes Editor (PlaceableCap.collision_shapes)
// ============================================================

const COLLISION_SHAPE_TYPES = ['box', 'cylinder', 'sphere'];

// Which size components are relevant per shape type. Helps the UI dim
// irrelevant inputs so authors don't waste attention on them.
const COLLISION_SIZE_LABELS = {
  box:      { x: 'Width',  y: 'Height', z: 'Depth'  },
  cylinder: { x: 'Radius', y: 'Height', z: '—'      },
  sphere:   { x: 'Radius', y: '—',      z: '—'      },
};

/**
 * Create the collision_shapes editor (list of box/cylinder/sphere entries).
 * @param {Array<{shape_type:string, size:{x:number,y:number,z:number}, offset:{x:number,y:number,z:number}}>} shapes
 * @returns {HTMLElement}
 */
function _createCollisionShapesEditor(shapes) {
  const wrapper = document.createElement('div');
  wrapper.dataset.collisionShapesEditor = '1';
  wrapper.classList.add('prop-full');
  wrapper.style.cssText = 'margin-top: 14px; display: flex; flex-direction: column; gap: 8px;';

  const header = document.createElement('div');
  header.style.cssText = 'display:flex;align-items:baseline;justify-content:space-between;';
  const title = document.createElement('div');
  title.textContent = 'Collision Shapes';
  title.classList.add('prop-label');
  header.appendChild(title);
  const hint = document.createElement('span');
  hint.textContent = 'empty = walkthrough prop';
  hint.style.cssText = 'font-size:11px; color: var(--text-secondary); font-style: italic;';
  header.appendChild(hint);
  wrapper.appendChild(header);

  const list = document.createElement('div');
  list.dataset.collisionShapesList = '1';
  list.style.cssText = 'display:flex;flex-direction:column;gap:6px;';
  wrapper.appendChild(list);

  const addBtn = document.createElement('button');
  addBtn.type = 'button';
  addBtn.textContent = '+ Add Shape';
  addBtn.classList.add('prop-btn');
  addBtn.style.alignSelf = 'flex-start';
  addBtn.addEventListener('click', () => {
    list.appendChild(_buildCollisionShapeRow({
      shape_type: 'box',
      size: { x: 1, y: 1, z: 1 },
      offset: { x: 0, y: 0, z: 0 },
    }));
  });
  wrapper.appendChild(addBtn);

  for (const s of shapes) {
    list.appendChild(_buildCollisionShapeRow(s));
  }

  return wrapper;
}

function _buildCollisionShapeRow(shape) {
  const row = document.createElement('div');
  row.dataset.collisionShapeRow = '1';
  row.classList.add('prop-card');
  row.style.cssText = 'display:grid;grid-template-columns: 90px repeat(3, 1fr) 14px repeat(3, 1fr) 28px;gap:4px;align-items:center;padding:6px;font-size:11px;';

  // Shape type dropdown.
  const typeSelect = document.createElement('select');
  typeSelect.dataset.field = 'shape_type';
  for (const t of COLLISION_SHAPE_TYPES) {
    const opt = document.createElement('option');
    opt.value = t;
    opt.textContent = t;
    if (t === shape.shape_type) opt.selected = true;
    typeSelect.appendChild(opt);
  }
  typeSelect.classList.add('prop-input');
  row.appendChild(typeSelect);

  // Size inputs (x, y, z).
  const sxLabel = document.createElement('span');
  const syLabel = document.createElement('span');
  const szLabel = document.createElement('span');
  const sx = _numCell('size_x', shape.size.x);
  const sy = _numCell('size_y', shape.size.y);
  const sz = _numCell('size_z', shape.size.z);
  const sizeWrapX = _titledCell(sxLabel, sx);
  const sizeWrapY = _titledCell(syLabel, sy);
  const sizeWrapZ = _titledCell(szLabel, sz);
  row.appendChild(sizeWrapX);
  row.appendChild(sizeWrapY);
  row.appendChild(sizeWrapZ);

  // Divider between size and offset.
  const divider = document.createElement('span');
  divider.textContent = '·';
  divider.style.cssText = 'text-align:center;color:var(--text-secondary);';
  row.appendChild(divider);

  // Offset inputs (x, y, z).
  const ox = _numCell('offset_x', shape.offset.x);
  const oy = _numCell('offset_y', shape.offset.y);
  const oz = _numCell('offset_z', shape.offset.z);
  row.appendChild(_titledCell(_makeSpan('X'), ox));
  row.appendChild(_titledCell(_makeSpan('Y'), oy));
  row.appendChild(_titledCell(_makeSpan('Z'), oz));

  // Remove button.
  const removeBtn = document.createElement('button');
  removeBtn.type = 'button';
  removeBtn.textContent = '×';
  removeBtn.classList.add('prop-btn-icon');
  removeBtn.title = 'Remove shape';
  removeBtn.addEventListener('click', () => row.remove());
  row.appendChild(removeBtn);

  // Update size labels when type changes.
  const refreshLabels = () => {
    const t = typeSelect.value;
    const labels = COLLISION_SIZE_LABELS[t] || COLLISION_SIZE_LABELS.box;
    sxLabel.textContent = labels.x;
    syLabel.textContent = labels.y;
    szLabel.textContent = labels.z;
    sy.disabled = labels.y === '—';
    sz.disabled = labels.z === '—';
  };
  typeSelect.addEventListener('change', refreshLabels);
  refreshLabels();

  return row;
}

function _numCell(fieldName, value) {
  const input = document.createElement('input');
  input.type = 'number';
  input.step = 'any';
  input.value = String(value);
  input.dataset.field = fieldName;
  input.classList.add('prop-input');
  return input;
}

function _titledCell(labelSpan, input) {
  const w = document.createElement('label');
  w.style.cssText = 'display:flex;flex-direction:column;gap:1px;font-size:10px;color:var(--text-secondary);';
  labelSpan.style.cssText = 'font-size:10px;';
  w.appendChild(labelSpan);
  w.appendChild(input);
  return w;
}

function _makeSpan(text) {
  const s = document.createElement('span');
  s.textContent = text;
  return s;
}

/**
 * Collect MeshVariant entries from the form.
 * @param {HTMLFormElement} formElement
 * @returns {Array<{scene:string, scale:number}>}
 */
function _collectMeshVariantsData(formElement) {
  const list = formElement.querySelector('[data-mesh-variants-list]');
  if (!list) return [];
  const rows = list.querySelectorAll('[data-mesh-variant-row]');
  const out = [];
  for (const row of rows) {
    const scaleEl = /** @type {HTMLInputElement} */ (row.querySelector('input[data-field="scale"]'));
    const scale = scaleEl ? parseFloat(scaleEl.value) : 1;
    out.push({
      scene: /** @type {HTMLElement} */ (row).dataset.meshScene || '',
      scale: Number.isFinite(scale) ? scale : 1,
    });
  }
  return out;
}

/**
 * Collect collision_shapes from the form.
 * @param {HTMLFormElement} formElement
 * @returns {Array<{shape_type:string, size:{x:number,y:number,z:number}, offset:{x:number,y:number,z:number}}>}
 */
function _collectCollisionShapesData(formElement) {
  const wrapper = formElement.querySelector('[data-collision-shapes-editor]');
  if (!wrapper) return [];
  const rows = wrapper.querySelectorAll('[data-collision-shape-row]');
  const out = [];
  for (const row of rows) {
    const typeEl = /** @type {HTMLSelectElement} */ (row.querySelector('select[data-field="shape_type"]'));
    const getNum = (field) => {
      const el = /** @type {HTMLInputElement} */ (row.querySelector(`input[data-field="${field}"]`));
      if (!el) return 0;
      const v = parseFloat(el.value);
      return Number.isFinite(v) ? v : 0;
    };
    out.push({
      shape_type: typeEl ? typeEl.value : 'box',
      size: { x: getNum('size_x'), y: getNum('size_y'), z: getNum('size_z') },
      offset: { x: getNum('offset_x'), y: getNum('offset_y'), z: getNum('offset_z') },
    });
  }
  return out;
}

/**
 * Collect shape data from a shape grid editor.
 * @param {HTMLFormElement} formElement - The form containing the editor
 * @param {string} fieldId - Identifier for the grid widget
 * @returns {Array<{x:number,y:number}>}
 */
function _collectShapeData(formElement, fieldId) {
  const result = [];
  const wrapper = formElement.querySelector(`[data-shape-editor="${fieldId}"]`);
  if (!wrapper) return [{ x: 0, y: 0 }];
  const cells = wrapper.querySelectorAll('[data-shape-cell][data-active="1"]');
  for (const cell of cells) {
    const parts = /** @type {HTMLElement} */ (cell).dataset.shapeCell.split(',');
    result.push({ x: parseInt(parts[0], 10), y: parseInt(parts[1], 10) });
  }
  return result.length > 0 ? result : [{ x: 0, y: 0 }];
}

// ============================================================
// String Array Editor (for accepts_filter, station_tags)
// ============================================================

/**
 * Create a string array editor (add/remove items).
 * @param {string} name - Base name for data attributes
 * @param {string} labelText - Display label
 * @param {string[]} values - Current values
 * @returns {HTMLElement}
 */
function _createStringArrayEditor(name, labelText, values) {
  const wrapper = document.createElement('div');
  wrapper.classList.add('prop-full');
  wrapper.dataset.stringArrayName = name;

  const label = document.createElement('div');
  label.textContent = labelText;
  label.classList.add('prop-label');
  wrapper.appendChild(label);

  const rowsContainer = document.createElement('div');
  rowsContainer.dataset.stringArrayRows = name;
  wrapper.appendChild(rowsContainer);

  function addRow(val) {
    const row = document.createElement('div');
    row.style.cssText = 'display:flex;gap:4px;margin-bottom:4px;align-items:center;';

    const input = document.createElement('input');
    input.type = 'text';
    input.value = val;
    input.placeholder = 'value';
    input.dataset.stringArrayVal = name;
    input.classList.add('prop-input');
    input.style.flex = '1';

    const removeBtn = document.createElement('button');
    removeBtn.textContent = 'X';
    removeBtn.type = 'button';
    removeBtn.classList.add('prop-btn-icon');
    removeBtn.addEventListener('click', () => row.remove());

    row.appendChild(input);
    row.appendChild(removeBtn);
    rowsContainer.appendChild(row);
  }

  for (const v of values) {
    addRow(v);
  }

  const addBtn = document.createElement('button');
  addBtn.textContent = '+ Add';
  addBtn.type = 'button';
  addBtn.classList.add('prop-btn');
  addBtn.addEventListener('click', () => addRow(''));
  wrapper.appendChild(addBtn);

  return wrapper;
}

/** Harvestable condition types. */
const _CONDITION_TYPES = [
  'tool', 'time_elapsed', 'time_of_day', 'skill', 'weather', 'season', 'biome',
];

/**
 * Render the Harvestable capability editor into the given panel.
 * Shows a list of yields (each with item_id/amount/conditions) and
 * a list of respawn conditions.
 * @param {HTMLElement} panel
 * @param {{yields: Array<{item_id: string, amount: number, conditions: string[]}>, respawn_conditions: string[]}|null} cap
 */
function _addHarvestableEditor(panel, cap) {
  const currentYields = cap && Array.isArray(cap.yields) ? cap.yields : [];
  const currentRespawn = cap && Array.isArray(cap.respawn_conditions) ? cap.respawn_conditions : [];

  // --- Yields section ---
  const yieldsLabel = document.createElement('div');
  yieldsLabel.textContent = 'Yields';
  yieldsLabel.classList.add('prop-label');
  yieldsLabel.style.gridColumn = '1 / -1';
  panel.appendChild(yieldsLabel);

  const yieldsContainer = document.createElement('div');
  yieldsContainer.dataset.harvestableYields = '1';
  yieldsContainer.style.cssText = 'grid-column: 1 / -1; display: flex; flex-direction: column; gap: 6px;';
  panel.appendChild(yieldsContainer);

  function _addConditionRow(container, type, value) {
    const row = document.createElement('div');
    row.style.cssText = 'display:flex;gap:4px;align-items:center;margin-left:16px;';
    row.dataset.conditionRow = '1';

    const typeSel = document.createElement('select');
    typeSel.dataset.conditionType = '1';
    typeSel.classList.add('prop-input');
    typeSel.style.cssText = 'flex:0 0 120px;';
    for (const t of _CONDITION_TYPES) {
      const opt = document.createElement('option');
      opt.value = t;
      opt.textContent = t;
      if (t === type) opt.selected = true;
      typeSel.appendChild(opt);
    }

    const valInput = document.createElement('input');
    valInput.type = 'text';
    valInput.placeholder = 'value (e.g. cutting_tool, 2_days)';
    valInput.value = value;
    valInput.dataset.conditionValue = '1';
    valInput.classList.add('prop-input');
    valInput.style.cssText = 'flex:1;';

    const removeBtn = document.createElement('button');
    removeBtn.textContent = 'X';
    removeBtn.type = 'button';
    removeBtn.classList.add('prop-btn-icon');
    removeBtn.addEventListener('click', () => row.remove());

    row.appendChild(typeSel);
    row.appendChild(valInput);
    row.appendChild(removeBtn);
    container.appendChild(row);
  }

  function _addYieldRow(y) {
    const wrapper = document.createElement('div');
    wrapper.dataset.harvestYield = '1';
    wrapper.style.cssText = 'border:1px solid var(--border);border-radius:3px;padding:6px;background:var(--bg-tertiary);';

    const header = document.createElement('div');
    header.style.cssText = 'display:flex;gap:4px;align-items:center;margin-bottom:4px;';

    const itemInput = document.createElement('input');
    itemInput.type = 'text';
    itemInput.placeholder = 'item_id (e.g. plant_fiber)';
    itemInput.value = y.item_id || '';
    itemInput.dataset.yieldItemId = '1';
    itemInput.classList.add('prop-input');
    itemInput.style.cssText = 'flex:1;';

    const amountInput = document.createElement('input');
    amountInput.type = 'number';
    amountInput.step = '1';
    amountInput.min = '1';
    amountInput.value = Number.isFinite(y.amount) ? y.amount : 1;
    amountInput.dataset.yieldAmount = '1';
    amountInput.classList.add('prop-input');
    amountInput.style.cssText = 'flex:0 0 80px;';

    const removeYieldBtn = document.createElement('button');
    removeYieldBtn.textContent = 'Remove Yield';
    removeYieldBtn.type = 'button';
    removeYieldBtn.classList.add('prop-btn-icon');
    removeYieldBtn.addEventListener('click', () => wrapper.remove());

    header.appendChild(itemInput);
    header.appendChild(amountInput);
    header.appendChild(removeYieldBtn);
    wrapper.appendChild(header);

    const condLabel = document.createElement('div');
    condLabel.textContent = 'Conditions (all must match to yield):';
    condLabel.style.cssText = 'font-size:11px;color:var(--text-secondary);margin:4px 0 2px 0;';
    wrapper.appendChild(condLabel);

    const condContainer = document.createElement('div');
    condContainer.dataset.yieldConditions = '1';
    condContainer.style.cssText = 'display:flex;flex-direction:column;gap:3px;';
    wrapper.appendChild(condContainer);

    for (const c of (y.conditions || [])) {
      const [type, ...rest] = String(c).split(':');
      _addConditionRow(condContainer, type || 'tool', rest.join(':'));
    }

    const addCondBtn = document.createElement('button');
    addCondBtn.textContent = '+ Condition';
    addCondBtn.type = 'button';
    addCondBtn.classList.add('prop-btn');
    addCondBtn.style.cssText = 'margin-top:4px;margin-left:16px;';
    addCondBtn.addEventListener('click', () => _addConditionRow(condContainer, 'tool', ''));
    wrapper.appendChild(addCondBtn);

    yieldsContainer.appendChild(wrapper);
  }

  for (const y of currentYields) _addYieldRow(y);

  const addYieldBtn = document.createElement('button');
  addYieldBtn.textContent = '+ Add Yield';
  addYieldBtn.type = 'button';
  addYieldBtn.classList.add('prop-btn');
  addYieldBtn.style.cssText = 'grid-column: 1 / -1; justify-self: start;';
  addYieldBtn.addEventListener('click', () => _addYieldRow({ item_id: '', amount: 1, conditions: [] }));
  panel.appendChild(addYieldBtn);

  // --- Respawn conditions section ---
  const respawnLabel = document.createElement('div');
  respawnLabel.textContent = 'Respawn Conditions (empty = never respawns)';
  respawnLabel.classList.add('prop-label');
  respawnLabel.style.gridColumn = '1 / -1';
  respawnLabel.style.marginTop = '8px';
  panel.appendChild(respawnLabel);

  const respawnContainer = document.createElement('div');
  respawnContainer.dataset.harvestableRespawn = '1';
  respawnContainer.style.cssText = 'grid-column: 1 / -1; display:flex; flex-direction:column; gap:3px;';
  panel.appendChild(respawnContainer);

  for (const c of currentRespawn) {
    const [type, ...rest] = String(c).split(':');
    _addConditionRow(respawnContainer, type || 'time_elapsed', rest.join(':'));
  }

  const addRespawnBtn = document.createElement('button');
  addRespawnBtn.textContent = '+ Respawn Condition';
  addRespawnBtn.type = 'button';
  addRespawnBtn.classList.add('prop-btn');
  addRespawnBtn.style.cssText = 'grid-column: 1 / -1; justify-self: start;';
  addRespawnBtn.addEventListener('click', () => _addConditionRow(respawnContainer, 'time_elapsed', ''));
  panel.appendChild(addRespawnBtn);
}

/** Mode int value -> label used by the movement editor dropdown. */
const _MOVEMENT_MODE_OPTIONS = [
  { value: 0, label: 'WALK' },
  { value: 1, label: 'SWIM' },
  { value: 2, label: 'FLY' },
  { value: 3, label: 'BURROW' },
  { value: 4, label: 'CLIMB' },
  { value: 5, label: 'JUMP' },
];

/**
 * Create an editor for the MovementCap modes dictionary.
 * Renders one row per {mode, normal, max} entry with an Add button below.
 * @param {Array<{mode: number, normal: number, max: number}>} modes
 * @returns {HTMLElement}
 */
function _createMovementModesEditor(modes) {
  const wrapper = document.createElement('div');
  wrapper.classList.add('prop-full');
  wrapper.dataset.movementModes = '';

  const label = document.createElement('div');
  label.textContent = 'Modes (Mode → [normal, max] speeds)';
  label.classList.add('prop-label');
  wrapper.appendChild(label);

  const rowsContainer = document.createElement('div');
  rowsContainer.dataset.movementModesRows = '';
  wrapper.appendChild(rowsContainer);

  /**
   * Add one {mode, normal, max} row.
   * @param {number} mode
   * @param {number} normal
   * @param {number} max
   */
  function addRow(mode, normal, max) {
    const row = document.createElement('div');
    row.style.cssText = 'display:flex;gap:4px;margin-bottom:4px;align-items:center;';
    row.dataset.movementModeRow = '';

    const modeSelect = document.createElement('select');
    modeSelect.dataset.movementModeMode = '';
    modeSelect.classList.add('prop-input');
    modeSelect.style.flex = '1';
    for (const opt of _MOVEMENT_MODE_OPTIONS) {
      const option = document.createElement('option');
      option.value = String(opt.value);
      option.textContent = `${opt.value} — ${opt.label}`;
      if (opt.value === mode) option.selected = true;
      modeSelect.appendChild(option);
    }

    const normalInput = document.createElement('input');
    normalInput.type = 'number';
    normalInput.step = 'any';
    normalInput.min = '0';
    normalInput.placeholder = 'normal';
    normalInput.value = String(normal);
    normalInput.dataset.movementModeNormal = '';
    normalInput.classList.add('prop-input');
    normalInput.style.flex = '1';

    const maxInput = document.createElement('input');
    maxInput.type = 'number';
    maxInput.step = 'any';
    maxInput.min = '0';
    maxInput.placeholder = 'max';
    maxInput.value = String(max);
    maxInput.dataset.movementModeMax = '';
    maxInput.classList.add('prop-input');
    maxInput.style.flex = '1';

    const removeBtn = document.createElement('button');
    removeBtn.textContent = 'X';
    removeBtn.type = 'button';
    removeBtn.classList.add('prop-btn-icon');
    removeBtn.addEventListener('click', () => row.remove());

    row.appendChild(modeSelect);
    row.appendChild(normalInput);
    row.appendChild(maxInput);
    row.appendChild(removeBtn);
    rowsContainer.appendChild(row);
  }

  for (const entry of modes) {
    addRow(entry.mode, entry.normal, entry.max);
  }

  const addBtn = document.createElement('button');
  addBtn.textContent = '+ Add Mode';
  addBtn.type = 'button';
  addBtn.classList.add('prop-btn');
  addBtn.addEventListener('click', () => addRow(0, 1.0, 1.0));
  wrapper.appendChild(addBtn);

  return wrapper;
}

// ============================================================
// Master-Detail Split Layout
// ============================================================

/**
 * Render the prop editor as a persistent master-detail split view.
 * @param {HTMLElement} container - The #tab-props element
 * @param {Object} [options] - Options object
 * @param {import('./commands.js').CommandHistory} [options.commandHistory] - Command history for undo/redo
 * @returns {void}
 */
export function renderPropEditor(container, options) {
  container.innerHTML = '';

  const cmdHistory = options && options.commandHistory ? options.commandHistory : null;
  const onChange = options && typeof options.onChange === 'function' ? options.onChange : () => {};
  const onSave = options && typeof options.onSave === 'function' ? options.onSave : onChange;
  /** @type {string|null} If set, locks the category filter to this value and hides the dropdowns. */
  const lockedCategory = options && options.categoryFilter ? options.categoryFilter : null;
  /** @type {((guard: () => boolean) => void) | null} Registers the editor's dirty guard with the tab switcher. */
  const registerGuard = options && typeof options.registerGuard === 'function' ? options.registerGuard : null;

  // --- Split layout ---
  const split = document.createElement('div');
  split.classList.add('editor-split');

  // --- Left panel ---
  const listPanel = document.createElement('div');
  listPanel.classList.add('editor-list-panel');

  const listHeader = document.createElement('div');
  listHeader.classList.add('editor-list-header');

  // Origin filter
  const originLabel = document.createElement('label');
  originLabel.textContent = 'Origin:';
  originLabel.style.cssText = 'font-size:10px;color:var(--text-secondary);';
  const originFilter = document.createElement('select');
  originFilter.classList.add('editor-filter');
  originFilter.style.marginBottom = '4px';
  const originAll = document.createElement('option');
  originAll.value = 'all'; originAll.textContent = 'All'; originAll.selected = true;
  originFilter.appendChild(originAll);
  for (const o of ORIGINS) {
    const opt = document.createElement('option');
    opt.value = o; opt.textContent = o;
    originFilter.appendChild(opt);
  }

  // Category filter
  const catLabel = document.createElement('label');
  catLabel.textContent = 'Category:';
  catLabel.style.cssText = 'font-size:10px;color:var(--text-secondary);';
  const catFilter = document.createElement('select');
  catFilter.classList.add('editor-filter');
  catFilter.style.marginBottom = '4px';

  const naturalCatNames = CATEGORIES.filter((_, i) => NATURAL_CATEGORIES.has(i));
  const nonNaturalCatNames = CATEGORIES.filter((_, i) => !NATURAL_CATEGORIES.has(i));

  /** Rebuild category options based on selected origin. */
  function _refreshCatOptions() {
    const origin = originFilter.value;
    const allowed = origin === 'all' ? CATEGORIES
      : origin === 'natural' ? naturalCatNames : nonNaturalCatNames;
    const prev = catFilter.value;
    catFilter.innerHTML = '';
    const allOpt = document.createElement('option');
    allOpt.value = 'all'; allOpt.textContent = 'All';
    catFilter.appendChild(allOpt);
    for (const c of allowed) {
      const opt = document.createElement('option');
      opt.value = c; opt.textContent = c;
      catFilter.appendChild(opt);
    }
    if (allowed.includes(prev)) catFilter.value = prev;
    else catFilter.value = 'all';
  }
  _refreshCatOptions();

  // Text filter
  const filterInput = document.createElement('input');
  filterInput.type = 'text';
  filterInput.placeholder = 'Filter...';
  filterInput.classList.add('editor-filter');

  const newBtn = document.createElement('button');
  newBtn.textContent = '+ New';
  newBtn.classList.add('editor-new-btn');

  if (!lockedCategory) {
    listHeader.appendChild(originLabel);
    listHeader.appendChild(originFilter);
    listHeader.appendChild(catLabel);
    listHeader.appendChild(catFilter);
  }
  listHeader.appendChild(filterInput);
  listHeader.appendChild(newBtn);

  // If category is locked by parent (tab-per-category UI), force the filter
  if (lockedCategory) {
    catFilter.value = lockedCategory;
  }
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
  /** @type {boolean} */
  let isNewMode = false;
  /** @type {PropDefModel|null} */
  let editingModel = null;
  /** @type {string} Serialized initial state for dirty detection */
  let initialJson = '';

  /**
   * Check if the current form is dirty and guard navigation.
   * If dirty, asks the user to confirm discarding changes.
   * @returns {boolean} true if safe to proceed
   */
  function _guardDirty() {
    if (!editingModel) return true;
    const form = detailPanel.querySelector('form');
    if (!form) return true;
    const currentData = collectPropFormData(/** @type {HTMLFormElement} */ (form));
    const currentJson = JSON.stringify(_modelToPlain(currentData));
    if (currentJson !== initialJson) {
      return confirm('Discard unsaved changes?');
    }
    return true;
  }

  if (registerGuard) {
    // Only the currently-visible prop editor should veto tab changes —
    // each category tab instantiates its own renderPropEditor, so they
    // all register a guard, but only the one whose tab panel is `.active`
    // has a live form to dirty-check.
    registerGuard(() => {
      if (!container.closest('.tab-panel.active')) return true;
      return _guardDirty();
    });
  }

  // --- Build the prop list ---
  /**
   * Rebuild the list items, optionally filtering.
   * @returns {void}
   */
  function refreshList() {
    listItems.innerHTML = '';
    const textFilter = filterInput.value.toLowerCase().trim();
    const originVal = originFilter.value;
    const catVal = catFilter.value;

    // Build list from all prop definitions in ProjectContext (stored in files.props map)
    /** @type {Array<{id: string, displayName: string, isPropDef: boolean, propCat: string, propOrigin: string}>} */
    const allProps = [];

    for (const [filename, entry] of ProjectContext.files.props) {
      const model = PropDefModel.fromEntry(filename, entry);
      allProps.push({ id: model.id, displayName: model.display_name || model.id, isPropDef: true, propCat: model.category, propOrigin: model.prop_origin });
    }
    allProps.sort((a, b) => a.displayName.localeCompare(b.displayName));

    for (const prop of allProps) {
      // Origin filter
      if (originVal !== 'all' && prop.propOrigin !== originVal) continue;
      // Category filter
      if (catVal !== 'all' && prop.propCat !== catVal) continue;
      // Text filter
      if (textFilter && !prop.displayName.toLowerCase().includes(textFilter) && !prop.id.toLowerCase().includes(textFilter)) continue;

      const item = document.createElement('div');
      item.classList.add('editor-list-item');
      if (prop.id === selectedId && !isNewMode) {
        item.classList.add('active');
      }
      item.dataset.id = prop.id;
      item.dataset.isPropDef = String(prop.isPropDef);

      const span = document.createElement('span');
      span.textContent = prop.displayName;
      item.appendChild(span);

      item.addEventListener('click', () => {
        if (!_guardDirty()) return;
        isNewMode = false;
        selectedId = prop.id;
        // Re-read from ProjectContext so we get the latest data
        const entry = ProjectContext.files.props.get(prop.id + '.tres');
        if (entry) {
          editingModel = PropDefModel.fromEntry(prop.id + '.tres', entry);
        } else {
          // Non-definition prop (e.g. structure) — create a minimal model
          editingModel = new PropDefModel();
          editingModel.id = prop.id;
          editingModel.display_name = prop.id;
          editingModel.category = prop.propCat;
          editingModel.prop_origin = prop.propOrigin;
        }
        initialJson = JSON.stringify(_modelToPlain(editingModel));
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
    empty.textContent = 'Select a prop';
    detailPanel.appendChild(empty);
  }

  /**
   * Render the detail panel for the currently selected / new prop.
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

    // Wrap in a form for collectPropFormData compatibility
    const form = document.createElement('form');
    form.style.cssText = 'display:flex;flex-direction:column;height:100%;';
    form.addEventListener('submit', (e) => e.preventDefault());
    // Stash fields that have no UI surface yet so collect can round-trip
    // them instead of emitting empty defaults on save. Keeps
    // CatalogableCap.properties (plant/mineral schemas used by the
    // scanner) intact until the rich properties editor lands.
    if (model.catalogable && model.catalogable.properties) {
      try { form.dataset.catalogableProps = JSON.stringify(model.catalogable.properties); }
      catch (_) { /* best effort */ }
    }

    // --- Header ---
    const header = document.createElement('div');
    header.classList.add('editor-detail-header');

    const h3 = document.createElement('h3');
    const headerSwatch = document.createElement('div');
    headerSwatch.classList.add('swatch');
    headerSwatch.style.cssText = `width:14px;height:14px;border-radius:2px;border:1px solid var(--border);background:${model.colorHex};`;
    const headerName = document.createElement('span');
    headerName.textContent = isNew ? 'New Prop' : model.id;
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

    // Issue 4: Hide Save/Delete for props without a .tres file
    const isReadOnly = !isNew && !model._filename;

    if (!isReadOnly) {
      btnGroup.appendChild(saveBtn);
    }
    if (!isNew && !isReadOnly) {
      btnGroup.appendChild(deleteBtn);
    }
    if (isReadOnly) {
      const readOnlyNote = document.createElement('span');
      readOnlyNote.textContent = '(read-only \u2014 no .tres file)';
      readOnlyNote.style.cssText = 'font-size:11px;color:var(--text-secondary);font-style:italic;';
      btnGroup.appendChild(readOnlyNote);
    }

    header.appendChild(h3);
    header.appendChild(btnGroup);
    form.appendChild(header);

    // --- Error area ---
    const errorArea = document.createElement('div');
    errorArea.style.cssText = 'display:none;padding:6px 10px;margin:4px 12px 0;background:var(--bg-error);border:1px solid var(--line-error);border-radius:4px;color:var(--text-error);font-size:12px;';
    form.appendChild(errorArea);

    // --- Gear base-fields header (2-col: id/name/short | long) ---
    const gearHeaderWrap = document.createElement('div');
    gearHeaderWrap.style.cssText = 'padding:10px 14px 0;';
    renderGearHeader(gearHeaderWrap, model, { idReadonly: !isNew });
    form.appendChild(gearHeaderWrap);

    // --- Two-column body (left: General/Capabilities, right: Visuals) ---
    const columnsWrapper = document.createElement('div');
    columnsWrapper.style.cssText = 'display:flex;flex:1;overflow:hidden;';

    const leftBody = document.createElement('div');
    leftBody.classList.add('editor-detail-body');
    leftBody.style.cssText = 'flex:1;overflow-y:auto;';
    _renderGeneralTab(leftBody, model, isNew);

    const rightBody = document.createElement('div');
    rightBody.classList.add('editor-detail-body');
    rightBody.style.cssText = 'flex:1;overflow-y:auto;border-left:1px solid var(--border);';
    _renderVisualsTab(rightBody, model);

    columnsWrapper.appendChild(leftBody);
    columnsWrapper.appendChild(rightBody);

    // ── Cross-refs preview column (Phase 4) ─────────────────────────────
    // "DROP SOURCES" panel lists every biome that includes this prop in
    // its natural_props table, with spawn frequency + grouping range.
    const refCol = document.createElement('div');
    refCol.className = 'detail-preview';
    _renderPropDropSources(refCol, model.id);
    columnsWrapper.appendChild(refCol);

    form.appendChild(columnsWrapper);

    detailPanel.appendChild(form);

    // Recapture initialJson from the rendered form so comparisons are form-to-form
    initialJson = JSON.stringify(_modelToPlain(collectPropFormData(/** @type {HTMLFormElement} */ (form))));

    // --- Save handler ---
    saveBtn.addEventListener('click', () => {
      const collected = collectPropFormData(form);
      collected._filename = isNew ? collected.id + '.tres' : model._filename;
      collected._raw = model._raw;

      const validation = validatePropForm(collected, isNew);
      if (!validation.valid) {
        errorArea.style.display = 'block';
        errorArea.textContent = validation.errors.join('; ');
        return;
      }

      if (isNew) {
        const cmd = new CreatePropDefCommand(collected, cmdHistory);
        if (cmdHistory) {
          cmdHistory.execute(cmd);
        } else {
          cmd.execute();
        }
        // Switch to editing the newly created prop
        isNewMode = false;
        selectedId = collected.id;
        const entry = ProjectContext.files.props.get(collected.id + '.tres');
        if (entry) {
          editingModel = PropDefModel.fromEntry(collected.id + '.tres', entry);
        }
      } else {
        const cmd = new EditPropDefCommand(model._filename, model, collected, cmdHistory);
        if (cmdHistory) {
          cmdHistory.execute(cmd);
        } else {
          cmd.execute();
        }
        // Refresh the editing model from ProjectContext
        const entry = ProjectContext.files.props.get(model._filename);
        if (entry) {
          editingModel = PropDefModel.fromEntry(model._filename, entry);
        }
      }

      refreshList();
      _renderDetail();
      onSave();
    });

    // --- Delete handler ---
    deleteBtn.addEventListener('click', () => {
      const usages = findPropUsage(model.id);
      if (usages.length > 0) {
        const usageList = usages.map(u => `${u.map} (${u.count} ref${u.count > 1 ? 's' : ''})`).join(', ');
        showInlineModal(
          `Prop "${model.id}" is referenced in: ${usageList}. Type "DELETE" to confirm deletion:`,
          '',
          (val) => {
            if (val === 'DELETE') {
              _doDelete(model);
            }
          }
        );
      } else {
        if (confirm(`Delete prop "${model.id}"? This cannot be undone without undo.`)) {
          _doDelete(model);
        }
      }
    });
  }

  /**
   * Execute delete and update UI.
   * @param {PropDefModel} model
   * @returns {void}
   */
  function _doDelete(model) {
    const cmd = new DeletePropDefCommand(model._filename, model, cmdHistory);
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
   * Render the General tab content.
   * @param {HTMLElement} body
   * @param {PropDefModel} model
   * @param {boolean} isNew
   * @returns {void}
   */
  function _renderGeneralTab(body, model, isNew) {
    const grid = document.createElement('div');
    grid.classList.add('prop-grid');

    // Note: id/display_name/short_description/long_description are rendered
    // above this tab via renderGearHeader() in _renderDetail.

    // -- Tags --
    _addSeparator(grid, 'Tags');
    grid.appendChild(_createTagEditor(model.tags));

    // -- Placement Defaults (editor-only) --
    _addSeparator(grid, 'Placement Defaults');
    _addOriginCategoryFields(grid, model);

    // -- Capabilities --
    // Capabilities with visual impact (Portable, Placeable, Harvestable)
    // live in the right-side Visuals tab. Data-only capabilities stay here.
    _addSeparator(grid, 'Capabilities');

    // CONTAINER
    grid.appendChild(_createCapabilityPanel('container', 'Container', model.container, (panel) => {
      _addField(panel, 'Grid Width', 'cap_container_grid_width', 'number', model.container ? model.container.grid_width : 30, { step: '1', min: '1' });
      _addField(panel, 'Grid Height', 'cap_container_grid_height', 'number', model.container ? model.container.grid_height : 40, { step: '1', min: '1' });
      panel.appendChild(_createStringArrayEditor('cap_container_accepts_filter', 'Accepts Filter', model.container ? model.container.accepts_filter : []));
    }));

    // EMITS_LIGHT
    grid.appendChild(_createCapabilityPanel('light', 'Emits Light', model.light, (panel) => {
      _addField(panel, 'Radius', 'cap_light_radius', 'number', model.light ? model.light.radius : 0, { step: 'any', min: '0' });
      panel.appendChild(_createColorField('Color', 'cap_light_color', model.light ? model.light.color : { r: 1, g: 0.7, b: 0.3, a: 1 }));
      _addCheckbox(panel, 'Flicker', 'cap_light_flicker', model.light ? model.light.flicker : false);
    }));

    // MOVABLE
    grid.appendChild(_createCapabilityPanel('movable', 'Movable', model.movable, (panel) => {
      _addField(panel, 'Push Cost', 'cap_movable_push_cost', 'number', model.movable ? model.movable.push_cost : 1.0, { step: 'any', min: '0' });
    }));

    // STATION
    grid.appendChild(_createCapabilityPanel('station', 'Station', model.station, (panel) => {
      panel.appendChild(_createStringArrayEditor('cap_station_station_tags', 'Station Tags', model.station ? model.station.station_tags : []));
    }));

    // CATALOGABLE
    grid.appendChild(_createCapabilityPanel('catalogable', 'Catalogable', model.catalogable, (panel) => {
      _addField(panel, 'Scan Time', 'cap_catalogable_scan_time', 'number', model.catalogable ? model.catalogable.scan_time : 1.0, { step: 'any', min: '0' });
      _addCheckbox(panel, 'Show as Anomaly', 'cap_catalogable_show_as_anomaly', model.catalogable ? model.catalogable.show_as_anomaly : false);
    }));

    // ENDURANCE
    grid.appendChild(_createCapabilityPanel('endurance', 'Endurance', model.endurance, (panel) => {
      _addField(panel, 'HP', 'cap_endurance_hp', 'number', model.endurance ? model.endurance.hp : 1, { step: '1', min: '1' });
      _addCsvField(panel, 'Vulnerabilities (comma-separated)', 'cap_endurance_vulnerabilities', model.endurance ? model.endurance.vulnerabilities : []);
      _addCsvField(panel, 'Resistances (comma-separated)', 'cap_endurance_resistances', model.endurance ? model.endurance.resistances : []);
      _addCsvField(panel, 'Immunities (comma-separated)', 'cap_endurance_immunities', model.endurance ? model.endurance.immunities : []);
    }));

    // MOVEMENT
    grid.appendChild(_createCapabilityPanel('movement', 'Movement', model.movement, (panel) => {
      panel.appendChild(_createMovementModesEditor(model.movement ? model.movement.modes : []));
    }));

    // COMBAT
    grid.appendChild(_createCapabilityPanel('combat', 'Combat', model.combat, (panel) => {
      _addPlaceholderNote(panel, 'Attacks/defenses will be wired when GameEvent picker is implemented');
    }));

    // BEHAVIOR
    grid.appendChild(_createCapabilityPanel('behavior', 'Behavior', model.behavior, (panel) => {
      _addField(panel, 'Detection Range', 'cap_behavior_detection_range', 'number', model.behavior ? model.behavior.detection_range : 2, { step: '1', min: '0' });
      _addIntSelectField(panel, 'Activity Cycle', 'cap_behavior_activity_cycle', model.behavior ? model.behavior.activity_cycle : 0, [
        { value: 0, label: 'ALWAYS' },
        { value: 1, label: 'DIURNAL' },
        { value: 2, label: 'NOCTURNAL' },
        { value: 3, label: 'CREPUSCULAR' },
      ]);
      _addIntSelectField(panel, 'Group Behavior', 'cap_behavior_group_behavior', model.behavior ? model.behavior.group_behavior : 0, [
        { value: 0, label: 'SOLO' },
        { value: 1, label: 'PAIR' },
        { value: 2, label: 'PACK' },
        { value: 3, label: 'HERD' },
        { value: 4, label: 'SWARM' },
      ]);
      _addCsvField(panel, 'Diet (comma-separated)', 'cap_behavior_diet', model.behavior ? model.behavior.diet : []);
      _addPlaceholderNote(panel, 'Reactions will be wired when GameEvent picker is implemented');
    }));

    // SPAWNABLE
    grid.appendChild(_createCapabilityPanel('spawnable', 'Spawnable', model.spawnable, (panel) => {
      _addField(panel, 'Spawn Min', 'cap_spawnable_spawn_min', 'number', model.spawnable ? model.spawnable.spawn_min : 1, { step: '1', min: '1' });
      _addField(panel, 'Spawn Max', 'cap_spawnable_spawn_max', 'number', model.spawnable ? model.spawnable.spawn_max : 1, { step: '1', min: '1' });
      _addField(panel, 'First Spawn Day', 'cap_spawnable_first_spawn_day', 'number', model.spawnable ? model.spawnable.first_spawn_day : 1, { step: '1', min: '1' });
      _addField(panel, 'Spawn Min Distance', 'cap_spawnable_spawn_min_distance', 'number', model.spawnable ? model.spawnable.spawn_min_distance : 3, { step: '1', min: '0' });
      _addCsvField(panel, 'Allowed Biomes (comma-separated, empty = any)', 'cap_spawnable_allowed_biomes', model.spawnable ? model.spawnable.allowed_biomes : []);
    }));

    body.appendChild(grid);
  }

  /**
   * Render the Visuals tab content — capabilities that affect what the prop
   * looks like or how it interacts in the world live here so the author can
   * see visual + data side-by-side with the left column.
   * @param {HTMLElement} body
   * @param {PropDefModel} model
   * @returns {void}
   */
  function _renderVisualsTab(body, model) {
    const grid = document.createElement('div');
    grid.classList.add('prop-grid');

    _addSeparator(grid, 'Visual Capabilities');

    // PORTABLE — inventory shape + (future) inventory icon/thumb.
    grid.appendChild(_createCapabilityPanel('portable', 'Portable', model.portable, (panel) => {
      panel.appendChild(_createShapeEditor('cap_portable_shape', model.portable ? model.portable.slot_shape : [{x:0,y:0}]));
    }));

    // PLACEABLE — world mesh variants + collision shape composition +
    // scatter preset (feature-011). One capability box bundles everything
    // the renderer needs to place this prop in the world.
    grid.appendChild(_createCapabilityPanel('placeable', 'Placeable', model.placeable, (panel) => {
      const meshes = model.placeable && Array.isArray(model.placeable.meshes)
        ? model.placeable.meshes
        : [];
      if (meshes.length > 0) {
        panel.appendChild(_renderMeshVariantList(meshes));
      } else {
        const empty = document.createElement('div');
        empty.textContent = 'No mesh variants authored. Add MeshVariant entries to placeable.meshes in .tres.';
        empty.style.cssText = 'padding: 12px; border: 1px dashed var(--border); border-radius: 4px; color: var(--text-secondary); font-size: 12px;';
        panel.appendChild(empty);
      }

      const collisionShapes = model.placeable && Array.isArray(model.placeable.collision_shapes)
        ? model.placeable.collision_shapes
        : [];
      panel.appendChild(_createCollisionShapesEditor(collisionShapes));

      // Scatter preset dropdown — inline as a placeable sub-section.
      panel.appendChild(_renderPlacementSection(model));
    }));

    // HARVESTABLE — yields + respawn conditions + (future) depleted meshes.
    grid.appendChild(_createCapabilityPanel('harvestable', 'Harvestable', model.harvestable, (panel) => {
      _addHarvestableEditor(panel, model.harvestable);
      const depletedNote = document.createElement('div');
      depletedNote.textContent = 'Depleted mesh variants (harvestable.depleted_meshes) will appear here once authored in .tres.';
      depletedNote.style.cssText = 'margin-top: 12px; padding: 10px; color: var(--text-secondary); font-size: 11px; font-style: italic; border-left: 2px solid var(--border); padding-left: 10px;';
      panel.appendChild(depletedNote);
    }));

    body.appendChild(grid);
  }

  /**
   * PlacementCap editor — dropdown of the 5 presets with short descriptions.
   * Reads from model.placeable.placement — feature-011 post-refactor,
   * scatter preset lives inside PlaceableCap rather than as a separate
   * capability. Falls back to SINGLE (0) when unset.
   */
  function _renderPlacementSection(model) {
    const wrap = document.createElement('div');
    wrap.classList.add('prop-full');
    wrap.style.cssText = 'display: flex; flex-direction: column; gap: 10px; margin-top: 10px;';

    const heading = document.createElement('div');
    heading.textContent = 'Scatter Placement';
    heading.style.cssText = 'font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; color: var(--text-secondary);';
    wrap.appendChild(heading);

    const PRESETS = [
      { value: 0, label: 'Single',    desc: '1 instance at sub-hex center. Default for boulders, structures, authored props.' },
      { value: 1, label: 'Normal',    desc: '7 instances (center + 6 scattered). Sibling scale 0.5. Default for plants.' },
      { value: 2, label: 'Dense',     desc: '13 instances (center + 12 scattered). Sibling scale 0.5. Thick vegetation.' },
      { value: 3, label: 'Sprouting', desc: '7 instances, sibling scale 0.3. Small satellites around parent — young growth, mineral clusters.' },
      { value: 4, label: 'Spread',    desc: '13 instances, sibling scale 1.0. Uniform coverage — pasture, moss fields.' },
    ];

    const current = (model.placeable && Number.isInteger(model.placeable.placement))
      ? model.placeable.placement : 0;

    const row = document.createElement('div');
    row.style.cssText = 'display: flex; gap: 8px; align-items: center;';
    const label = document.createElement('span');
    label.textContent = 'Preset';
    label.classList.add('prop-hint');
    const select = document.createElement('select');
    select.dataset.field = 'placement_preset';
    select.classList.add('prop-input');
    select.style.flex = '1';
    for (const p of PRESETS) {
      const opt = document.createElement('option');
      opt.value = String(p.value);
      opt.textContent = p.label;
      if (p.value === current) opt.selected = true;
      select.appendChild(opt);
    }
    row.appendChild(label);
    row.appendChild(select);
    wrap.appendChild(row);

    const desc = document.createElement('div');
    desc.style.cssText = 'font-size: 11px; color: var(--text-secondary); padding: 8px 10px; border-left: 2px solid var(--border); background: var(--bg-secondary);';
    const _refreshDesc = () => {
      const p = PRESETS.find(x => x.value === parseInt(select.value, 10)) || PRESETS[0];
      desc.textContent = p.desc;
    };
    _refreshDesc();
    select.addEventListener('change', _refreshDesc);
    wrap.appendChild(desc);

    // --- Slope handling controls ------------------------------------
    const slopeHeading = document.createElement('div');
    slopeHeading.textContent = 'Slope Handling';
    slopeHeading.style.cssText = 'font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; color: var(--text-secondary); margin-top: 8px;';
    wrap.appendChild(slopeHeading);

    // Max allowed slope (degrees, 0-90, step 5).
    const maxRow = document.createElement('div');
    maxRow.style.cssText = 'display: flex; gap: 8px; align-items: center; font-size: 11px;';
    const maxLabel = document.createElement('span');
    maxLabel.textContent = 'Max Slope';
    maxLabel.classList.add('prop-hint');
    const maxSlider = document.createElement('input');
    maxSlider.type = 'range';
    maxSlider.min = '0';
    maxSlider.max = '90';
    maxSlider.step = '5';
    maxSlider.dataset.field = 'max_allowed_slope';
    maxSlider.style.flex = '1';
    const maxValue = (model.placeable && Number.isFinite(model.placeable.max_allowed_slope))
      ? model.placeable.max_allowed_slope : 90;
    maxSlider.value = String(maxValue);
    const maxReadout = document.createElement('span');
    maxReadout.style.cssText = 'min-width: 3em; text-align: right; font-family: var(--font-mono, monospace); font-size: 11px;';
    maxReadout.textContent = `${maxSlider.value}°`;
    maxSlider.addEventListener('input', () => {
      maxReadout.textContent = `${maxSlider.value}°`;
    });
    maxRow.appendChild(maxLabel);
    maxRow.appendChild(maxSlider);
    maxRow.appendChild(maxReadout);
    wrap.appendChild(maxRow);

    const maxDesc = document.createElement('div');
    maxDesc.style.cssText = 'font-size: 11px; color: var(--text-secondary); padding: 8px 10px; border-left: 2px solid var(--border); background: var(--bg-secondary);';
    maxDesc.textContent = 'Populate skips this prop on hexes whose steepest local slope exceeds this angle. Scale: 0 = flat only; 15 = loose-rock limit; 30-45 = bushes/trees; 60+ = ground cover / moss; 90 = anywhere including cliffs. Slope is derived from elevation diff to walk-through neighbors.';
    wrap.appendChild(maxDesc);

    // Slope blend slider (0..1 in 0.05 steps).
    const blendRow = document.createElement('div');
    blendRow.style.cssText = 'display: flex; gap: 8px; align-items: center; font-size: 11px;';
    const blendLabel = document.createElement('span');
    blendLabel.textContent = 'Slope Tilt';
    blendLabel.classList.add('prop-hint');
    const blendSlider = document.createElement('input');
    blendSlider.type = 'range';
    blendSlider.min = '0';
    blendSlider.max = '1';
    blendSlider.step = '0.05';
    blendSlider.dataset.field = 'slope_blend';
    blendSlider.style.flex = '1';
    const blendValue = (model.placeable && typeof model.placeable.slope_blend === 'number')
      ? model.placeable.slope_blend : 1.0;
    blendSlider.value = String(blendValue);
    const blendReadout = document.createElement('span');
    blendReadout.style.cssText = 'min-width: 3em; text-align: right; font-family: var(--font-mono, monospace); font-size: 11px;';
    blendReadout.textContent = Number(blendSlider.value).toFixed(2);
    blendSlider.addEventListener('input', () => {
      blendReadout.textContent = Number(blendSlider.value).toFixed(2);
    });
    blendRow.appendChild(blendLabel);
    blendRow.appendChild(blendSlider);
    blendRow.appendChild(blendReadout);
    wrap.appendChild(blendRow);

    const blendDesc = document.createElement('div');
    blendDesc.style.cssText = 'font-size: 11px; color: var(--text-secondary); padding: 8px 10px; border-left: 2px solid var(--border); background: var(--bg-secondary);';
    blendDesc.textContent = '0.0 = prop stays strictly vertical on slopes (tall trees). 1.0 = prop lies fully against the terrain normal (moss, flat fungi, ground cover). Intermediate values blend partway.';
    wrap.appendChild(blendDesc);

    return wrap;
  }

  /**
   * Render an editable list of MeshVariant entries — reference.png preview,
   * scene path and scale input. Scene editing still goes through the
   * .tres for now (no file picker yet).
   * @param {Array<{scene: string, scale: number}>} meshes
   * @returns {HTMLElement}
   */
  function _renderMeshVariantList(meshes) {
    const wrap = document.createElement('div');
    wrap.classList.add('prop-full');
    wrap.style.cssText = 'display: flex; flex-direction: column; gap: 8px;';

    const list = document.createElement('div');
    list.dataset.meshVariantsList = '1';
    list.style.cssText = 'display: flex; flex-direction: column; gap: 10px;';

    meshes.forEach((mv, idx) => {
      list.appendChild(_buildMeshVariantRow(mv, idx));
    });
    wrap.appendChild(list);

    // + Add Variant — appends an empty variant row so the author can
    // paste a scene path / set scale. The actual .glb picker is a
    // future improvement; for now the scene input is left blank and
    // the author fills it by hand.
    const addBtn = document.createElement('button');
    addBtn.type = 'button';
    addBtn.textContent = '+ Add Variant';
    addBtn.classList.add('prop-btn');
    addBtn.style.alignSelf = 'flex-start';
    addBtn.addEventListener('click', () => {
      const nextIdx = list.querySelectorAll('[data-mesh-variant-row]').length;
      list.appendChild(_buildMeshVariantRow({ scene: '', scale: 1.0 }, nextIdx));
    });
    wrap.appendChild(addBtn);

    return wrap;
  }

  function _buildMeshVariantRow(mv, idx) {
    const row = document.createElement('div');
    row.dataset.meshVariantRow = '1';
    row.dataset.meshScene = mv.scene || '';
    row.classList.add('prop-card');
    row.style.cssText = 'display: flex; gap: 12px;';

    // Preview image (resolve mesh_vN.glb → reference_vN.png in same dir).
    // Falls back to a visible placeholder when the server can't serve the PNG.
    const previewPath = (mv.scene || '').replace(/^res:\/\//, '').replace(/mesh_(v\d+)\.glb$/, 'reference_$1.png');
    const img = document.createElement('img');
    if (previewPath) img.src = `/api/asset?path=${encodeURIComponent(previewPath)}`;
    img.alt = `variant ${idx + 1}`;
    img.style.cssText = 'width: 96px; height: 96px; object-fit: cover; border-radius: 3px; background: #222; flex-shrink: 0;';
    img.onerror = () => {
      img.replaceWith(_buildPreviewFallback(idx + 1));
    };
    row.appendChild(img);

    const info = document.createElement('div');
    info.style.cssText = 'flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 6px; font-size: 12px;';

    // Header row: variant label + remove button.
    const header = document.createElement('div');
    header.style.cssText = 'display: flex; align-items: center; justify-content: space-between; gap: 8px;';
    const label = document.createElement('div');
    label.textContent = `Variant ${idx + 1}`;
    label.style.cssText = 'font-weight: 600;';
    header.appendChild(label);
    const removeBtn = document.createElement('button');
    removeBtn.type = 'button';
    removeBtn.textContent = '×';
    removeBtn.title = 'Remove variant';
    removeBtn.classList.add('prop-btn-icon');
    removeBtn.addEventListener('click', () => row.remove());
    header.appendChild(removeBtn);
    info.appendChild(header);

    const scenePath = document.createElement('code');
    scenePath.textContent = mv.scene || '(no scene)';
    scenePath.style.cssText = 'font-size: 11px; color: var(--text-secondary); overflow: hidden; text-overflow: ellipsis; white-space: nowrap;';
    info.appendChild(scenePath);

    // Editable scale input. Rotation was removed 2026-04-18 — rotation
    // is now fully procedural (seeded 0-360°) or per-instance override
    // via the Prop context menu, never per-variant.
    // Flex-in-line keeps the label and input adjacent instead of
    // letting a grid column expand and put dead space between them.
    const xform = document.createElement('div');
    xform.style.cssText = 'display: flex; gap: 6px; align-items: center;';
    const scaleLabel = document.createElement('span');
    scaleLabel.textContent = 'scale';
    scaleLabel.classList.add('prop-hint');
    const scaleInput = document.createElement('input');
    scaleInput.type = 'number';
    scaleInput.step = 'any';
    scaleInput.value = String(mv.scale);
    scaleInput.dataset.field = 'scale';
    scaleInput.classList.add('prop-input');
    scaleInput.style.width = '100px';
    xform.appendChild(scaleLabel);
    xform.appendChild(scaleInput);
    info.appendChild(xform);

    row.appendChild(info);
    return row;
  }

  function _buildPreviewFallback(variantNumber) {
    const fallback = document.createElement('div');
    fallback.style.cssText = 'width: 96px; height: 96px; border-radius: 3px; background: #222; display: flex; align-items: center; justify-content: center; color: var(--text-secondary); font-size: 10px; text-align: center; flex-shrink: 0; border: 1px dashed var(--border);';
    fallback.textContent = `no preview\nv${variantNumber}`;
    fallback.style.whiteSpace = 'pre';
    return fallback;
  }

  // --- Wire up events ---
  filterInput.addEventListener('input', () => refreshList());
  originFilter.addEventListener('change', () => { _refreshCatOptions(); refreshList(); });
  catFilter.addEventListener('change', () => refreshList());

  newBtn.addEventListener('click', () => {
    if (!_guardDirty()) return;
    isNewMode = true;
    selectedId = null;
    editingModel = new PropDefModel();

    // Auto-increment ID with P prefix
    editingModel.id = nextId('P', ProjectContext.files.props);

    // If the editor is locked to a category (tab-per-category), pre-set it
    // so the new prop joins the current tab's list immediately.
    if (lockedCategory) {
      editingModel.category = lockedCategory;
      // STUFF defaults to non-natural origin (per Andre, 2026-04-10)
      if (lockedCategory === 'stuff') {
        editingModel.prop_origin = 'crafted';
      }
    }

    initialJson = JSON.stringify(_modelToPlain(editingModel));
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
 * Add a labeled textarea to a prop-grid.
 * @param {HTMLElement} grid
 * @param {string} labelText
 * @param {string} name
 * @param {string} value
 * @returns {void}
 */
function _addTextArea(grid, labelText, name, value) {
  const label = document.createElement('label');
  label.textContent = labelText;
  label.classList.add('prop-label');

  const textarea = document.createElement('textarea');
  textarea.name = name;
  textarea.value = value || '';
  textarea.classList.add('prop-input');
  textarea.rows = 3;

  grid.appendChild(label);
  grid.appendChild(textarea);
}

/**
 * Add a labeled checkbox to a prop-grid.
 * @param {HTMLElement} grid
 * @param {string} labelText
 * @param {string} name
 * @param {boolean} checked
 * @returns {void}
 */
function _addCheckbox(grid, labelText, name, checked) {
  const label = document.createElement('label');
  label.textContent = labelText;
  label.classList.add('prop-label');
  const input = document.createElement('input');
  input.type = 'checkbox';
  input.name = name;
  input.checked = !!checked;
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
 * Add a label + comma-separated-value text input row to a prop-grid.
 * The value is joined with ", " for display and split back on collect.
 * @param {HTMLElement} grid
 * @param {string} labelText
 * @param {string} name
 * @param {string[]} values - Current values
 * @returns {void}
 */
function _addCsvField(grid, labelText, name, values) {
  const label = document.createElement('label');
  label.textContent = labelText;
  label.classList.add('prop-label');

  const input = document.createElement('input');
  input.type = 'text';
  input.name = name;
  input.value = Array.isArray(values) ? values.join(', ') : '';
  input.classList.add('prop-input');
  input.dataset.csvField = '';

  grid.appendChild(label);
  grid.appendChild(input);
}

/**
 * Add a label + select dropdown row with integer values to a prop-grid.
 * Used for GDScript enum fields that serialize as ints.
 * @param {HTMLElement} grid
 * @param {string} labelText
 * @param {string} name
 * @param {number} value - Currently selected integer value
 * @param {Array<{value: number, label: string}>} options - Available options
 * @returns {void}
 */
function _addIntSelectField(grid, labelText, name, value, options) {
  const label = document.createElement('label');
  label.textContent = labelText;
  label.classList.add('prop-label');
  const select = document.createElement('select');
  select.name = name;
  select.classList.add('prop-input');
  select.dataset.intSelect = '';
  for (const opt of options) {
    const option = document.createElement('option');
    option.value = String(opt.value);
    option.textContent = `${opt.value} — ${opt.label}`;
    if (opt.value === value) option.selected = true;
    select.appendChild(option);
  }
  grid.appendChild(label);
  grid.appendChild(select);
}

/**
 * Add a placeholder note row spanning the full prop-grid width.
 * Used for capabilities whose fields aren't yet editable (e.g. GameEvent refs).
 * @param {HTMLElement} grid
 * @param {string} text
 * @returns {void}
 */
function _addPlaceholderNote(grid, text) {
  const note = document.createElement('div');
  note.classList.add('prop-full');
  note.style.cssText = 'font-size:11px;color:var(--text-secondary);font-style:italic;padding:4px 0;';
  note.textContent = text;
  grid.appendChild(note);
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
 * @param {PropDefModel} model
 * @returns {void}
 */
function _addOriginCategoryFields(grid, model) {
  // Category
  const catLabel = document.createElement('label');
  catLabel.textContent = 'Category';
  catLabel.classList.add('prop-label');
  const catSelect = document.createElement('select');
  catSelect.name = 'category';
  catSelect.classList.add('prop-input');
  grid.appendChild(catLabel);
  grid.appendChild(catSelect);

  // Rarity
  const rarityLabel = document.createElement('label');
  rarityLabel.textContent = 'Rarity';
  rarityLabel.classList.add('prop-label');
  const raritySelect = document.createElement('select');
  raritySelect.name = 'rarity';
  raritySelect.classList.add('prop-input');
  for (const r of RARITIES) {
    const opt = document.createElement('option');
    opt.value = r;
    opt.textContent = r;
    if (r === model.rarity) opt.selected = true;
    raritySelect.appendChild(opt);
  }
  grid.appendChild(rarityLabel);
  grid.appendChild(raritySelect);

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

  /** Rebuild category options based on origin. */
  function _refreshCategories(preserveValue) {
    const origin = originSelect.value;
    const allowed = origin === 'natural' ? _NATURAL_CAT_NAMES : _NON_NATURAL_CAT_NAMES;
    const target = preserveValue || catSelect.value;
    catSelect.innerHTML = '';
    for (const c of allowed) {
      const opt = document.createElement('option');
      opt.value = c;
      opt.textContent = c;
      if (c === target) opt.selected = true;
      catSelect.appendChild(opt);
    }
    if (!allowed.includes(target) && allowed.length > 0) {
      catSelect.value = allowed[0];
    }
  }

  _refreshCategories(model.category);
  originSelect.addEventListener('change', () => _refreshCategories());
}

// ============================================================
// Form Data Collection
// ============================================================

/**
 * Collect form data from a prop edit form and return a populated PropDefModel.
 * @param {HTMLFormElement} formElement
 * @returns {PropDefModel}
 */
export function collectPropFormData(formElement) {
  const model = new PropDefModel();

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

  /**
   * Get a checkbox checked state.
   * @param {string} name
   * @returns {boolean}
   */
  function isChecked(name) {
    const el = formElement.querySelector(`[name="${name}"]`);
    return el ? /** @type {HTMLInputElement} */ (el).checked : false;
  }

  // Identity
  model.id = val('id').trim();
  model.display_name = val('display_name').trim();

  // Gear base fields
  model.short_description = val('short_description').trim();
  model.long_description = val('long_description').trim();

  // Tags
  model.tags = _collectTagData(formElement);

  // Placement defaults (editor-only)
  model.category = val('category') || '';
  model.rarity = val('rarity') || 'common';
  model.prop_origin = val('prop_origin') || 'natural';
  // tool_slot and max_stack preserved from model (not in form)

  // --- Capabilities ---
  if (isChecked('cap_portable_enabled')) {
    model.portable = { slot_shape: _collectShapeData(formElement, 'cap_portable_shape') };
  }

  if (isChecked('cap_placeable_enabled')) {
    // Scatter preset lives inside the Placeable cap (feature-011 refactor).
    // Read the dropdown that _renderPlacementSection emits with
    // data-field="placement_preset".
    const placementSelect = formElement.querySelector('select[data-field="placement_preset"]');
    const placement = placementSelect
      ? parseInt(/** @type {HTMLSelectElement} */ (placementSelect).value, 10)
      : 0;
    // Slope handling inputs rendered alongside the preset dropdown.
    const maxSlopeSlider = formElement.querySelector('input[data-field="max_allowed_slope"]');
    const max_allowed_slope = maxSlopeSlider
      ? parseInt(/** @type {HTMLInputElement} */ (maxSlopeSlider).value, 10) : 90;
    const blendSlider = formElement.querySelector('input[data-field="slope_blend"]');
    const slope_blend = blendSlider
      ? parseFloat(/** @type {HTMLInputElement} */ (blendSlider).value) : 1.0;
    model.placeable = {
      meshes: _collectMeshVariantsData(formElement),
      collision_shapes: _collectCollisionShapesData(formElement),
      placement: Number.isInteger(placement) ? placement : 0,
      max_allowed_slope,
      slope_blend,
    };
  }

  if (isChecked('cap_container_enabled')) {
    model.container = {
      grid_width: intVal('cap_container_grid_width'),
      grid_height: intVal('cap_container_grid_height'),
      accepts_filter: _collectStringArrayData(formElement, 'cap_container_accepts_filter'),
    };
  }

  if (isChecked('cap_light_enabled')) {
    model.light = {
      radius: floatVal('cap_light_radius'),
      color: _hexToColor(val('cap_light_color'), floatVal('cap_light_color_alpha')),
      flicker: isChecked('cap_light_flicker'),
    };
  }

  if (isChecked('cap_movable_enabled')) {
    model.movable = { push_cost: floatVal('cap_movable_push_cost') };
  }

  if (isChecked('cap_station_enabled')) {
    model.station = {
      station_tags: _collectStringArrayData(formElement, 'cap_station_station_tags'),
    };
  }

  if (isChecked('cap_catalogable_enabled')) {
    // Properties editing isn't wired to the UI yet, but dropping the
    // dict on every save wipes per-category metadata (plant schema,
    // mineral schema, etc.) that the scanner + catalog read. Preserve
    // the previously-loaded value via a hidden dataset stash on the
    // form so an editor round-trip stays lossless until the rich
    // properties editor lands.
    const stash = formElement.dataset && formElement.dataset.catalogableProps
      ? formElement.dataset.catalogableProps : '';
    let preserved = {};
    if (stash) {
      try {
        const parsed = JSON.parse(stash);
        if (parsed && typeof parsed === 'object') preserved = parsed;
      } catch (_) { /* ignore malformed stash */ }
    }
    model.catalogable = {
      scan_time: floatVal('cap_catalogable_scan_time'),
      show_as_anomaly: isChecked('cap_catalogable_show_as_anomaly'),
      properties: preserved,
    };
  }

  if (isChecked('cap_endurance_enabled')) {
    model.endurance = {
      hp: intVal('cap_endurance_hp') || 1,
      vulnerabilities: _csvToArray(val('cap_endurance_vulnerabilities')),
      resistances: _csvToArray(val('cap_endurance_resistances')),
      immunities: _csvToArray(val('cap_endurance_immunities')),
    };
  }

  if (isChecked('cap_movement_enabled')) {
    model.movement = {
      modes: _collectMovementModesData(formElement),
    };
  }

  if (isChecked('cap_combat_enabled')) {
    model.combat = {
      attacks: [],   // TODO: wire GameEvent refs
      defenses: [],
    };
  }

  if (isChecked('cap_behavior_enabled')) {
    model.behavior = {
      detection_range: intVal('cap_behavior_detection_range'),
      activity_cycle: intVal('cap_behavior_activity_cycle'),
      group_behavior: intVal('cap_behavior_group_behavior'),
      diet: _csvToArray(val('cap_behavior_diet')),
      reactions: [],  // TODO: wire GameEvent refs
    };
  }

  if (isChecked('cap_spawnable_enabled')) {
    model.spawnable = {
      spawn_min: intVal('cap_spawnable_spawn_min') || 1,
      spawn_max: intVal('cap_spawnable_spawn_max') || 1,
      first_spawn_day: intVal('cap_spawnable_first_spawn_day') || 1,
      spawn_min_distance: intVal('cap_spawnable_spawn_min_distance'),
      allowed_biomes: _csvToArray(val('cap_spawnable_allowed_biomes')),
    };
  }

  if (isChecked('cap_harvestable_enabled')) {
    const yields = [];
    const yieldEls = formElement.querySelectorAll('[data-harvest-yield]');
    for (const yEl of yieldEls) {
      const itemInput = yEl.querySelector('[data-yield-item-id]');
      const amountInput = yEl.querySelector('[data-yield-amount]');
      const conditions = [];
      const condRows = yEl.querySelectorAll('[data-yield-conditions] [data-condition-row]');
      for (const r of condRows) {
        const t = r.querySelector('[data-condition-type]');
        const v = r.querySelector('[data-condition-value]');
        const tv = (t && t.value || '').trim();
        const vv = (v && v.value || '').trim();
        if (tv && vv) conditions.push(`${tv}:${vv}`);
      }
      yields.push({
        item_id: (itemInput && itemInput.value || '').trim(),
        amount: parseInt(amountInput && amountInput.value, 10) || 1,
        conditions,
      });
    }
    const respawnConds = [];
    const respawnRows = formElement.querySelectorAll('[data-harvestable-respawn] [data-condition-row]');
    for (const r of respawnRows) {
      const t = r.querySelector('[data-condition-type]');
      const v = r.querySelector('[data-condition-value]');
      const tv = (t && t.value || '').trim();
      const vv = (v && v.value || '').trim();
      if (tv && vv) respawnConds.push(`${tv}:${vv}`);
    }
    model.harvestable = { yields, respawn_conditions: respawnConds };
  }

  // Legacy footprint preserved from model (no longer in form UI)

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

/**
 * Collect movement modes data from a movement-modes editor.
 * @param {HTMLFormElement} formElement
 * @returns {Array<{mode: number, normal: number, max: number}>}
 */
function _collectMovementModesData(formElement) {
  const result = [];
  const container = formElement.querySelector('[data-movement-modes-rows]');
  if (!container) return result;
  const rows = container.children;
  for (const row of rows) {
    const modeSelect = row.querySelector('[data-movement-mode-mode]');
    const normalInput = row.querySelector('[data-movement-mode-normal]');
    const maxInput = row.querySelector('[data-movement-mode-max]');
    if (modeSelect && normalInput && maxInput) {
      const mode = parseInt(/** @type {HTMLSelectElement} */ (modeSelect).value, 10);
      const normal = parseFloat(/** @type {HTMLInputElement} */ (normalInput).value);
      const max = parseFloat(/** @type {HTMLInputElement} */ (maxInput).value);
      result.push({
        mode: isNaN(mode) ? 0 : mode,
        normal: isNaN(normal) ? 0 : normal,
        max: isNaN(max) ? 0 : max,
      });
    }
  }
  return result;
}

/**
 * Collect footprint data from a footprint editor section.
 * @param {HTMLFormElement} formElement
 * @returns {Array<{x: number, y: number}>}
 */
function _collectFootprintData(formElement) {
  const result = [];
  const container = formElement.querySelector('[data-footprint-rows]');
  if (!container) return result;
  const rows = container.children;
  for (const row of rows) {
    const xInput = row.querySelector('[data-fp-x]');
    const yInput = row.querySelector('[data-fp-y]');
    if (xInput && yInput) {
      const x = parseInt(/** @type {HTMLInputElement} */ (xInput).value, 10);
      const y = parseInt(/** @type {HTMLInputElement} */ (yInput).value, 10);
      result.push({ x: isNaN(x) ? 0 : x, y: isNaN(y) ? 0 : y });
    }
  }
  return result;
}

/**
 * Collect tag data from the tag editor.
 * @param {HTMLFormElement} formElement
 * @returns {string[]}
 */
function _collectTagData(formElement) {
  const result = [];
  const container = formElement.querySelector('[data-tag-chips]');
  if (!container) return result;
  for (const chip of container.children) {
    const tag = /** @type {HTMLElement} */ (chip).dataset.tagValue;
    if (tag) result.push(tag);
  }
  return result;
}

/**
 * Collect footprint data from a capability footprint editor.
 * @param {HTMLFormElement} formElement
 * @returns {Array<{x: number, y: number}>}
 */
function _collectCapFootprintData(formElement) {
  const result = [];
  const container = formElement.querySelector('[data-cap-footprint-rows]');
  if (!container) return result;
  for (const row of container.children) {
    const xInput = row.querySelector('[data-cap-fp-x]');
    const yInput = row.querySelector('[data-cap-fp-y]');
    if (xInput && yInput) {
      const x = parseInt(/** @type {HTMLInputElement} */ (xInput).value, 10);
      const y = parseInt(/** @type {HTMLInputElement} */ (yInput).value, 10);
      result.push({ x: isNaN(x) ? 0 : x, y: isNaN(y) ? 0 : y });
    }
  }
  return result;
}

/**
 * Split a comma-separated string into a trimmed, non-empty array.
 * @param {string} str
 * @returns {string[]}
 */
function _csvToArray(str) {
  if (!str || typeof str !== 'string') return [];
  return str.split(',').map(s => s.trim()).filter(s => s.length > 0);
}

/**
 * Collect string array data from a string array editor.
 * @param {HTMLFormElement} formElement
 * @param {string} name - The string array editor name
 * @returns {string[]}
 */
function _collectStringArrayData(formElement, name) {
  const result = [];
  const container = formElement.querySelector(`[data-string-array-rows="${name}"]`);
  if (!container) return result;
  for (const row of container.children) {
    const input = row.querySelector(`[data-string-array-val="${name}"]`);
    if (input) {
      const v = /** @type {HTMLInputElement} */ (input).value.trim();
      if (v) result.push(v);
    }
  }
  return result;
}

// ============================================================
// Form Validation
// ============================================================

/**
 * Validate a prop form model.
 * @param {PropDefModel} model
 * @param {boolean} isNew
 * @returns {{ valid: boolean, errors: string[] }}
 */
export function validatePropForm(model, isNew) {
  /** @type {string[]} */
  const errors = [];

  // ID validation
  if (!model.id) {
    errors.push('ID is required');
  } else if (!/^[a-zA-Z0-9_]+$/.test(model.id)) {
    errors.push('ID must contain only alphanumeric characters and underscores');
  } else if (!model.id.startsWith('P')) {
    errors.push('Prop ID must start with "P" (e.g. P00001)');
  } else if (isNew && ProjectContext.files.props.has(model.id + '.tres')) {
    errors.push(`Prop "${model.id}" already exists`);
  }

  // Display name
  if (!model.display_name) {
    errors.push('Display Name is required');
  }

  // --- Capability validations ---
  if (model.portable) {
    if (!model.portable.slot_shape || model.portable.slot_shape.length === 0) {
      errors.push('PORTABLE slot_shape must have at least one cell');
    } else if (!model.portable.slot_shape.some(c => c.x === 0 && c.y === 0)) {
      errors.push('PORTABLE slot_shape must include the origin cell (0,0)');
    }
  }

  // PlaceableCap is a marker — no fields to validate.

  if (model.light) {
    if (model.light.radius < 1) {
      errors.push('EMITS_LIGHT radius must be >= 1');
    }
  }

  if (model.station) {
    if (!model.station.station_tags || model.station.station_tags.length === 0) {
      errors.push('STATION station_tags must be non-empty');
    }
  }

  return { valid: errors.length === 0, errors };
}

// ============================================================
// Model -> TresFile Serialization
// ============================================================

/**
 * Convert a model to a plain object for dirty comparison (excluding metadata fields).
 * @param {PropDefModel} model
 * @returns {Object}
 */
function _modelToPlain(model) {
  return {
    id: model.id,
    display_name: model.display_name,
    short_description: model.short_description,
    long_description: model.long_description,
    tags: model.tags,
    portable: model.portable,
    placeable: model.placeable,
    container: model.container,
    light: model.light,
    movable: model.movable,
    station: model.station,
    catalogable: model.catalogable,
    endurance: model.endurance,
    movement: model.movement,
    combat: model.combat,
    behavior: model.behavior,
    spawnable: model.spawnable,
    harvestable: model.harvestable,
    max_stack: model.max_stack,
    footprint: model.footprint,
    category: model.category,
    rarity: model.rarity,
    prop_origin: model.prop_origin,
    tool_slot: model.tool_slot,
  };
}

/**
 * Update a TresFile's resourceFields from a PropDefModel.
 * For new props, creates a fresh TresFile with the standard PropDef structure.
 * @param {PropDefModel} model
 * @returns {TresFile}
 */
export function propModelToRaw(model) {
  /** @type {TresFile} */
  let raw;

  if (model._raw) {
    // Update existing raw — preserve structure
    raw = model._raw;
  } else {
    // Create fresh TresFile for new prop
    raw = new TresFile();
    raw.scriptClass = 'PropDef';
    raw.lineEnding = '\n';
  }

  // --- Build ext_resources and sub_resources from capabilities ---
  const extResources = [];
  const subResources = [];
  const fields = new Map();
  let extId = 1;

  // Script is always ext_resource #1
  const scriptExtId = '1_script';
  extResources.push(`[ext_resource type="Script" path="res://scripts/data/prop_def.gd" id="${scriptExtId}"]`);
  extId++;

  /** @type {Array<{capName: string, scriptPath: string, subId: string, subFields: Map<string, import('./tres-parser.js').TresValue>}>} */
  const capEntries = [];
  // Nested sub_resources referenced BY caps (e.g. CollisionShape and HarvestYield).
  // Emitted before the cap sub_resources so they're available when the caps
  // reference them.
  const extraSubResources = [];

  // Build capability entries in the order defined by the GDScript schema
  if (model.portable) {
    const eid = `${extId}_portable`;
    extResources.push(`[ext_resource type="Script" path="res://scripts/data/capabilities/portable_cap.gd" id="${eid}"]`);
    const subFields = new Map();
    subFields.set('script', { type: 'ext_resource', value: `ExtResource("${eid}")` });
    const shapeIsDefault = model.portable.slot_shape.length === 1
      && model.portable.slot_shape[0].x === 0 && model.portable.slot_shape[0].y === 0;
    if (!shapeIsDefault) {
      subFields.set('slot_shape', {
        type: 'array',
        elementType: null,
        value: model.portable.slot_shape.map(c => ({ type: 'vector2i', value: { x: c.x, y: c.y } })),
      });
    }
    capEntries.push({ capName: 'portable', subId: 'portable_1', subFields });
    extId++;
  }

  if (model.placeable) {
    const eid = `${extId}_placeable`;
    extResources.push(`[ext_resource type="Script" path="res://scripts/data/capabilities/placeable_cap.gd" id="${eid}"]`);
    extId++;

    // Mesh variants (Array[Resource] of MeshVariant sub_resources).
    const meshes = Array.isArray(model.placeable.meshes) ? model.placeable.meshes : [];
    let meshVarExtId = null;
    if (meshes.length > 0) {
      meshVarExtId = `${extId}_mesh_variant`;
      extResources.push(`[ext_resource type="Script" path="res://scripts/data/capabilities/mesh_variant.gd" id="${meshVarExtId}"]`);
      extId++;
    }
    const meshSubIds = [];
    for (let i = 0; i < meshes.length; i++) {
      const mv = meshes[i];
      // One ext_resource per unique scene path (PackedScene reference).
      let sceneExtId = null;
      if (mv.scene) {
        sceneExtId = `${extId}_mesh_scene_${i + 1}`;
        extResources.push(`[ext_resource type="PackedScene" path="${mv.scene}" id="${sceneExtId}"]`);
        extId++;
      }
      const mvSubId = `mesh_variant_${i + 1}`;
      meshSubIds.push(mvSubId);
      const mvFields = new Map();
      mvFields.set('script', { type: 'ext_resource', value: `ExtResource("${meshVarExtId}")` });
      if (sceneExtId) {
        mvFields.set('scene', { type: 'ext_resource', value: `ExtResource("${sceneExtId}")` });
      }
      mvFields.set('scale', { type: 'float', value: Number.isFinite(mv.scale) ? mv.scale : 1.0 });
      extraSubResources.push({ type: 'Resource', id: mvSubId, fields: mvFields });
    }

    // Collision shapes (Array[Resource] of CollisionShape sub_resources).
    const collShapes = Array.isArray(model.placeable.collision_shapes) ? model.placeable.collision_shapes : [];
    let collShapeExtId = null;
    if (collShapes.length > 0) {
      collShapeExtId = `${extId}_collision_shape`;
      extResources.push(`[ext_resource type="Script" path="res://scripts/data/capabilities/collision_shape.gd" id="${collShapeExtId}"]`);
      extId++;
    }
    const collSubIds = [];
    for (let i = 0; i < collShapes.length; i++) {
      const cs = collShapes[i];
      const csSubId = `collision_shape_${i + 1}`;
      collSubIds.push(csSubId);
      const csFields = new Map();
      csFields.set('script', { type: 'ext_resource', value: `ExtResource("${collShapeExtId}")` });
      csFields.set('shape_type', { type: 'stringname', value: cs.shape_type || 'box' });
      csFields.set('size', { type: 'vector3', value: { x: cs.size.x, y: cs.size.y, z: cs.size.z } });
      csFields.set('offset', { type: 'vector3', value: { x: cs.offset.x, y: cs.offset.y, z: cs.offset.z } });
      extraSubResources.push({ type: 'Resource', id: csSubId, fields: csFields });
    }

    const subFields = new Map();
    subFields.set('script', { type: 'ext_resource', value: `ExtResource("${eid}")` });
    if (meshSubIds.length > 0) {
      subFields.set('meshes', {
        type: 'array', elementType: 'Resource',
        value: meshSubIds.map(id => ({ type: 'sub_resource', value: id })),
      });
    }
    if (collSubIds.length > 0) {
      subFields.set('collision_shapes', {
        type: 'array', elementType: 'Resource',
        value: collSubIds.map(id => ({ type: 'sub_resource', value: id })),
      });
    }

    // feature-011: scatter preset lives on PlaceableCap now. Emit only
    // when non-default (SINGLE = 0) to keep legacy .tres files minimal.
    const placementPreset = Number.isInteger(model.placeable.placement)
      ? model.placeable.placement : 0;
    if (placementPreset !== 0) {
      subFields.set('placement', { type: 'int', value: placementPreset });
    }

    // Slope handling — emit only when non-default to keep legacy files minimal.
    const maxSlope = Number.isFinite(model.placeable.max_allowed_slope)
      ? model.placeable.max_allowed_slope : 90;
    if (maxSlope !== 90) {
      subFields.set('max_allowed_slope', { type: 'int', value: maxSlope });
    }
    const slopeBlend = typeof model.placeable.slope_blend === 'number'
      ? model.placeable.slope_blend : 1.0;
    if (slopeBlend !== 1.0) {
      subFields.set('slope_blend', { type: 'float', value: slopeBlend });
    }

    capEntries.push({ capName: 'placeable', subId: 'placeable_1', subFields });
  }

  if (model.container) {
    const eid = `${extId}_container`;
    extResources.push(`[ext_resource type="Script" path="res://scripts/data/capabilities/container_cap.gd" id="${eid}"]`);
    const subFields = new Map();
    subFields.set('script', { type: 'ext_resource', value: `ExtResource("${eid}")` });
    if (model.container.grid_width !== 30) subFields.set('grid_width', { type: 'int', value: model.container.grid_width });
    if (model.container.grid_height !== 40) subFields.set('grid_height', { type: 'int', value: model.container.grid_height });
    if (model.container.accepts_filter && model.container.accepts_filter.length > 0) {
      subFields.set('accepts_filter', {
        type: 'array', elementType: null,
        value: model.container.accepts_filter.map(f => ({ type: 'stringname', value: f })),
      });
    }
    capEntries.push({ capName: 'container', subId: 'container_1', subFields });
    extId++;
  }

  if (model.light) {
    const eid = `${extId}_light`;
    extResources.push(`[ext_resource type="Script" path="res://scripts/data/capabilities/light_cap.gd" id="${eid}"]`);
    const subFields = new Map();
    subFields.set('script', { type: 'ext_resource', value: `ExtResource("${eid}")` });
    if (model.light.radius) subFields.set('radius', { type: 'float', value: model.light.radius });
    if (model.light.color) subFields.set('color', _colorToTresValue(model.light.color));
    if (model.light.flicker) subFields.set('flicker', { type: 'bool', value: true });
    capEntries.push({ capName: 'light', subId: 'light_1', subFields });
    extId++;
  }

  if (model.movable) {
    const eid = `${extId}_movable`;
    extResources.push(`[ext_resource type="Script" path="res://scripts/data/capabilities/movable_cap.gd" id="${eid}"]`);
    const subFields = new Map();
    subFields.set('script', { type: 'ext_resource', value: `ExtResource("${eid}")` });
    if (model.movable.push_cost !== 1.0) subFields.set('push_cost', { type: 'float', value: model.movable.push_cost });
    capEntries.push({ capName: 'movable', subId: 'movable_1', subFields });
    extId++;
  }

  if (model.station) {
    const eid = `${extId}_station`;
    extResources.push(`[ext_resource type="Script" path="res://scripts/data/capabilities/station_cap.gd" id="${eid}"]`);
    const subFields = new Map();
    subFields.set('script', { type: 'ext_resource', value: `ExtResource("${eid}")` });
    if (model.station.station_tags && model.station.station_tags.length > 0) {
      subFields.set('station_tags', {
        type: 'array', elementType: null,
        value: model.station.station_tags.map(t => ({ type: 'stringname', value: t })),
      });
    }
    capEntries.push({ capName: 'station', subId: 'station_1', subFields });
    extId++;
  }

  if (model.catalogable) {
    const eid = `${extId}_catalogable`;
    extResources.push(`[ext_resource type="Script" path="res://scripts/data/capabilities/catalogable_cap.gd" id="${eid}"]`);
    const subFields = new Map();
    subFields.set('script', { type: 'ext_resource', value: `ExtResource("${eid}")` });
    if (model.catalogable.scan_time !== 1.0) subFields.set('scan_time', { type: 'float', value: model.catalogable.scan_time });
    if (model.catalogable.show_as_anomaly) subFields.set('show_as_anomaly', { type: 'bool', value: true });
    if (model.catalogable.properties && Object.keys(model.catalogable.properties).length > 0) {
      const propEntries = Object.entries(model.catalogable.properties).map(([k, v]) => {
        if (typeof v === 'string') return [k, { type: 'stringname', value: v }];
        if (typeof v === 'boolean') return [k, { type: 'bool', value: v }];
        if (typeof v === 'number') return [k, { type: Number.isInteger(v) ? 'int' : 'float', value: v }];
        return [k, { type: 'string', value: String(v) }];
      });
      subFields.set('properties', { type: 'dict', value: new Map(propEntries) });
    }
    capEntries.push({ capName: 'catalogable', subId: 'catalogable_1', subFields });
    extId++;
  }

  if (model.endurance) {
    const eid = `${extId}_endurance`;
    extResources.push(`[ext_resource type="Script" path="res://scripts/data/capabilities/endurance_cap.gd" id="${eid}"]`);
    const subFields = new Map();
    subFields.set('script', { type: 'ext_resource', value: `ExtResource("${eid}")` });
    if (model.endurance.hp !== 1) subFields.set('hp', { type: 'int', value: model.endurance.hp });
    if (model.endurance.vulnerabilities && model.endurance.vulnerabilities.length > 0) {
      subFields.set('vulnerabilities', {
        type: 'array', elementType: null,
        value: model.endurance.vulnerabilities.map(v => ({ type: 'stringname', value: v })),
      });
    }
    if (model.endurance.resistances && model.endurance.resistances.length > 0) {
      subFields.set('resistances', {
        type: 'array', elementType: null,
        value: model.endurance.resistances.map(v => ({ type: 'stringname', value: v })),
      });
    }
    if (model.endurance.immunities && model.endurance.immunities.length > 0) {
      subFields.set('immunities', {
        type: 'array', elementType: null,
        value: model.endurance.immunities.map(v => ({ type: 'stringname', value: v })),
      });
    }
    capEntries.push({ capName: 'endurance', subId: 'endurance_1', subFields });
    extId++;
  }

  if (model.movement) {
    const eid = `${extId}_movement`;
    extResources.push(`[ext_resource type="Script" path="res://scripts/data/capabilities/movement_cap.gd" id="${eid}"]`);
    const subFields = new Map();
    subFields.set('script', { type: 'ext_resource', value: `ExtResource("${eid}")` });
    const modes = Array.isArray(model.movement.modes) ? model.movement.modes : [];
    if (modes.length > 0) {
      const modesMap = new Map();
      for (const entry of modes) {
        modesMap.set(
          entry.mode,
          {
            type: 'array',
            elementType: null,
            value: [
              { type: 'float', value: entry.normal },
              { type: 'float', value: entry.max },
            ],
          },
        );
      }
      subFields.set('modes', {
        type: 'dict',
        value: modesMap,
        keyStyle: 'int',
        braceSpaces: true,
      });
    }
    capEntries.push({ capName: 'movement', subId: 'movement_1', subFields });
    extId++;
  }

  if (model.combat) {
    const eid = `${extId}_combat`;
    extResources.push(`[ext_resource type="Script" path="res://scripts/data/capabilities/combat_cap.gd" id="${eid}"]`);
    const subFields = new Map();
    subFields.set('script', { type: 'ext_resource', value: `ExtResource("${eid}")` });
    // attacks/defenses are arrays of GameEvent refs — leave empty until editor supports them.
    capEntries.push({ capName: 'combat', subId: 'combat_1', subFields });
    extId++;
  }

  if (model.behavior) {
    const eid = `${extId}_behavior`;
    extResources.push(`[ext_resource type="Script" path="res://scripts/data/capabilities/behavior_cap.gd" id="${eid}"]`);
    const subFields = new Map();
    subFields.set('script', { type: 'ext_resource', value: `ExtResource("${eid}")` });
    if (model.behavior.detection_range !== 2) subFields.set('detection_range', { type: 'int', value: model.behavior.detection_range });
    if (model.behavior.activity_cycle !== 0) subFields.set('activity_cycle', { type: 'int', value: model.behavior.activity_cycle });
    if (model.behavior.group_behavior !== 0) subFields.set('group_behavior', { type: 'int', value: model.behavior.group_behavior });
    if (model.behavior.diet && model.behavior.diet.length > 0) {
      subFields.set('diet', {
        type: 'array', elementType: null,
        value: model.behavior.diet.map(v => ({ type: 'stringname', value: v })),
      });
    }
    // reactions are GameEvent refs — leave empty until editor supports them.
    capEntries.push({ capName: 'behavior', subId: 'behavior_1', subFields });
    extId++;
  }

  if (model.spawnable) {
    const eid = `${extId}_spawnable`;
    extResources.push(`[ext_resource type="Script" path="res://scripts/data/capabilities/spawnable_cap.gd" id="${eid}"]`);
    const subFields = new Map();
    subFields.set('script', { type: 'ext_resource', value: `ExtResource("${eid}")` });
    if (model.spawnable.spawn_min !== 1) subFields.set('spawn_min', { type: 'int', value: model.spawnable.spawn_min });
    if (model.spawnable.spawn_max !== 1) subFields.set('spawn_max', { type: 'int', value: model.spawnable.spawn_max });
    if (model.spawnable.first_spawn_day !== 1) subFields.set('first_spawn_day', { type: 'int', value: model.spawnable.first_spawn_day });
    if (model.spawnable.spawn_min_distance !== 3) subFields.set('spawn_min_distance', { type: 'int', value: model.spawnable.spawn_min_distance });
    if (model.spawnable.allowed_biomes && model.spawnable.allowed_biomes.length > 0) {
      subFields.set('allowed_biomes', {
        type: 'array', elementType: null,
        value: model.spawnable.allowed_biomes.map(v => ({ type: 'stringname', value: v })),
      });
    }
    capEntries.push({ capName: 'spawnable', subId: 'spawnable_1', subFields });
    extId++;
  }

  // Harvestable cap — emits the cap itself PLUS one sub_resource per yield.
  // Yield sub_resources are pushed to subResources directly (before the main
  // loop below) so they appear before the harvestable cap that references them.
  /** @type {Array<{id: string, fields: Map<string, any>}>} */
  if (model.harvestable) {
    const harvExtId = `${extId}_harvestable`;
    extResources.push(`[ext_resource type="Script" path="res://scripts/data/capabilities/harvestable_cap.gd" id="${harvExtId}"]`);
    extId++;

    const yields = Array.isArray(model.harvestable.yields) ? model.harvestable.yields : [];
    let yieldExtId = null;
    if (yields.length > 0) {
      yieldExtId = `${extId}_harvest_yield`;
      extResources.push(`[ext_resource type="Script" path="res://scripts/data/capabilities/harvest_yield.gd" id="${yieldExtId}"]`);
      extId++;
    }

    const yieldSubIds = [];
    for (let i = 0; i < yields.length; i++) {
      const y = yields[i];
      const yieldSubId = `harvest_yield_${i + 1}`;
      yieldSubIds.push(yieldSubId);

      const yieldFields = new Map();
      yieldFields.set('script', { type: 'ext_resource', value: `ExtResource("${yieldExtId}")` });
      yieldFields.set('item_id', { type: 'stringname', value: y.item_id || '' });
      yieldFields.set('amount', { type: 'int', value: Number.isFinite(y.amount) ? y.amount : 1 });
      yieldFields.set('conditions', {
        type: 'array', elementType: null,
        value: (Array.isArray(y.conditions) ? y.conditions : []).map(c => ({ type: 'stringname', value: c })),
      });

      extraSubResources.push({ type: 'Resource', id: yieldSubId, fields: yieldFields });
    }

    const harvSubFields = new Map();
    harvSubFields.set('script', { type: 'ext_resource', value: `ExtResource("${harvExtId}")` });
    harvSubFields.set('yields', {
      type: 'array', elementType: 'HarvestYield',
      value: yieldSubIds.map(id => ({ type: 'sub_resource', value: id })),
    });
    const respawnConds = Array.isArray(model.harvestable.respawn_conditions) ? model.harvestable.respawn_conditions : [];
    harvSubFields.set('respawn_conditions', {
      type: 'array', elementType: null,
      value: respawnConds.map(c => ({ type: 'stringname', value: c })),
    });
    capEntries.push({ capName: 'harvestable', subId: 'harvestable_1', subFields: harvSubFields });
  }

  // Build sub_resources: yields come first (so harvestable can reference them),
  // then capability sub_resources in definition order.
  for (const sub of extraSubResources) {
    subResources.push(sub);
  }
  for (const cap of capEntries) {
    subResources.push({ type: 'Resource', id: cap.subId, fields: cap.subFields });
  }

  // Update header load_steps: 1 (format) + ext_resources count + sub_resources count
  const loadSteps = extResources.length + subResources.length;
  raw.headerLine = `[gd_resource type="Resource" script_class="PropDef" load_steps=${loadSteps} format=3]`;
  raw.extResources = extResources;
  raw.subResources = subResources;

  // --- Build [resource] fields ---

  // Script line is always first
  fields.set('script', { type: 'ext_resource', value: `ExtResource("${scriptExtId}")` });

  // StringName fields
  fields.set('id', { type: 'stringname', value: model.id });
  fields.set('display_name', { type: 'string', value: model.display_name });

  // Gear base fields (only when non-empty)
  if (model.short_description) fields.set('short_description', { type: 'string', value: model.short_description });
  if (model.long_description) fields.set('long_description', { type: 'string', value: model.long_description });

  // Classification (fixed fields, not tags)
  if (model.category) fields.set('category', { type: 'stringname', value: model.category });
  if (model.rarity) fields.set('rarity', { type: 'stringname', value: model.rarity });

  // Tags (attribute labels only — not category/rarity)
  if (model.tags && model.tags.length > 0) {
    fields.set('tags', {
      type: 'array', elementType: null,
      value: model.tags.map(t => ({ type: 'stringname', value: t })),
    });
  }

  // Capability references (SubResource("xxx"))
  for (const cap of capEntries) {
    fields.set(cap.capName, { type: 'sub_resource', value: cap.subId });
  }

  // Int field
  fields.set('max_stack', { type: 'int', value: model.max_stack });

  // Prop placement defaults (int in .tres)
  fields.set('origin', { type: 'int', value: ORIGIN_TO_INT[model.prop_origin] ?? 0 });

  // Tool slot (only if non-empty)
  if (model.tool_slot) fields.set('tool_slot', { type: 'stringname', value: model.tool_slot });

  // Legacy footprint (top-level, only if non-empty)
  if (model.footprint && model.footprint.length > 0) {
    const fpValues = model.footprint.map(p => ({
      type: 'vector2i',
      value: { x: p.x, y: p.y },
    }));
    fields.set('footprint', { type: 'array', value: fpValues, elementType: null });
  }

  // --- Legacy fields (written when non-default for backward compat during transition) ---
  if (model.gather_time) fields.set('gather_time', { type: 'float', value: model.gather_time });
  if (model.gather_amount) fields.set('gather_amount', { type: 'int', value: model.gather_amount });
  if (model.tool_required) fields.set('tool_required', { type: 'stringname', value: model.tool_required });
  if (model.respawn_time) fields.set('respawn_time', { type: 'float', value: model.respawn_time });
  if (model.yield_type) fields.set('yield_type', { type: 'stringname', value: model.yield_type });
  if (model.tool_speed && Object.keys(model.tool_speed).length > 0) {
    fields.set('tool_speed', _objToTresDict(model.tool_speed, 'stringname', 'float'));
  }
  if (model.is_consumable) fields.set('is_consumable', { type: 'bool', value: true });
  if (model.hunger_restore) fields.set('hunger_restore', { type: 'float', value: model.hunger_restore });
  if (model.thirst_restore) fields.set('thirst_restore', { type: 'float', value: model.thirst_restore });
  if (model.health_restore) fields.set('health_restore', { type: 'float', value: model.health_restore });
  if (model.emits_light) fields.set('emits_light', { type: 'bool', value: true });
  if (model.light_radius > 0) fields.set('light_radius', { type: 'int', value: model.light_radius });
  if (model.is_respawn_point) fields.set('is_respawn_point', { type: 'bool', value: true });
  if (model.is_crafting_station) fields.set('is_crafting_station', { type: 'bool', value: true });

  // Preserve any fields from the original .tres the editor doesn't yet
  // understand (e.g. `mesh`, `depleted_mesh`, `material` asset references).
  // Without this pass, @export PropDef properties the editor has no UI for
  // would be silently dropped on save, causing permanent data loss when
  // real meshes/materials are added via the Godot editor.
  // Capability fields are excluded — their presence is fully controlled by
  // the capability checkboxes above. If unchecked, the reference must NOT
  // survive from the old raw.
  const MANAGED_FIELDS = new Set([
    'portable', 'placeable', 'container', 'light', 'movable', 'station', 'catalogable',
    'endurance', 'movement', 'combat', 'behavior', 'spawnable', 'harvestable',
    'category', 'rarity', 'footprint', 'prop_category',
  ]);
  if (model._raw && model._raw.resourceFields instanceof Map) {
    for (const [key, value] of model._raw.resourceFields) {
      if (!fields.has(key) && !MANAGED_FIELDS.has(key)) {
        fields.set(key, value);
      }
    }
  }

  raw.resourceFields = fields;
  return raw;
}

/**
 * Resolve an ExtResource reference (e.g. "ExtResource(\"7_mesh_v1\")") or
 * a raw `{ type: 'ext_resource', value: id }` TresValue to the `path`
 * attribute from the corresponding [ext_resource ...] header line in the
 * raw .tres. Returns the empty string if the reference can't be resolved.
 * @param {string|{type:string,value:string}|null|undefined} ref
 * @param {import('./tres-parser.js').TresFile|null|undefined} rawFile
 * @returns {string}
 */
function _resolveExtResourcePath(ref, rawFile) {
  let id = '';
  if (!ref) return '';
  if (typeof ref === 'string') {
    // Match ExtResource("id") or plain id.
    const m = ref.match(/ExtResource\(\s*"([^"]+)"\s*\)/);
    id = m ? m[1] : ref;
  } else if (typeof ref === 'object' && ref.type === 'ext_resource') {
    const v = typeof ref.value === 'string' ? ref.value : '';
    const m = v.match(/ExtResource\(\s*"([^"]+)"\s*\)/);
    id = m ? m[1] : v;
  }
  if (!id || !rawFile || !Array.isArray(rawFile.extResources)) return '';
  for (const line of rawFile.extResources) {
    if (typeof line !== 'string') continue;
    const lineMatch = line.match(/id\s*=\s*"([^"]+)"/);
    if (lineMatch && lineMatch[1] === id) {
      const pathMatch = line.match(/path\s*=\s*"([^"]+)"/);
      if (pathMatch) return pathMatch[1];
    }
  }
  return '';
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
 * Command to create a new prop definition.
 */
export class CreatePropDefCommand {
  /**
   * @param {PropDefModel} model
   * @param {import('./commands.js').CommandHistory} [commandHistory]
   */
  constructor(model, commandHistory) {
    this._model = model;
    this._filename = model.id + '.tres';
    this.tab = 'props';
    this.type = 'CreatePropDef';
  }

  execute() {
    const raw = propModelToRaw(this._model);
    const content = TresParser.serialize(raw);

    // Build data object from resourceFields (mirrors _parseTresFile logic)
    const data = {};
    for (const [key, tv] of raw.resourceFields) {
      data[key] = tv.value;
    }

    // Add to ProjectContext
    ProjectContext.files.props.set(this._filename, {
      handle: null,
      dir: 'data/props',
      data,
      raw,
    });

    // Write file
    FileDiscovery.saveFile('data/props', content, this._filename).catch((err) => {
      console.warn(`CreatePropDefCommand: Failed to save "${this._filename}": ${err.message}`);
    });
  }

  undo() {
    ProjectContext.files.props.delete(this._filename);
  }
}

/**
 * Command to edit an existing prop definition.
 */
export class EditPropDefCommand {
  /**
   * @param {string} filename
   * @param {PropDefModel} oldModel
   * @param {PropDefModel} newModel
   * @param {import('./commands.js').CommandHistory} [commandHistory]
   */
  constructor(filename, oldModel, newModel, commandHistory) {
    this._filename = filename;
    this._oldModel = oldModel;
    this._newModel = newModel;
    this._oldRaw = oldModel._raw;
    this.tab = 'props';
    this.type = 'EditPropDef';
  }

  execute() {
    const raw = propModelToRaw(this._newModel);
    const content = TresParser.serialize(raw);

    // Resolve sub_resource references (same logic as _parseTresFile in file-discovery)
    const subResourceMap = new Map();
    if (raw.subResources) {
      for (const sub of raw.subResources) {
        const subData = {};
        for (const [k, v] of sub.fields) {
          subData[k] = v.value;
        }
        subResourceMap.set(sub.id, subData);
      }
    }
    const data = {};
    for (const [key, tv] of raw.resourceFields) {
      if (tv.type === 'sub_resource') {
        data[key] = subResourceMap.get(tv.value) || null;
      } else {
        data[key] = tv.value;
      }
    }

    const entry = ProjectContext.files.props.get(this._filename);
    if (entry) {
      entry.data = data;
      entry.raw = raw;
    }

    FileDiscovery.saveFile('data/props', content, this._filename).catch((err) => {
      console.warn(`EditPropDefCommand: Failed to save "${this._filename}": ${err.message}`);
    });
  }

  undo() {
    const raw = propModelToRaw(this._oldModel);
    // Restore the original raw if available
    if (this._oldRaw) {
      const entry = ProjectContext.files.props.get(this._filename);
      if (entry) {
        entry.raw = this._oldRaw;
        const data = {};
        for (const [key, tv] of this._oldRaw.resourceFields) {
          data[key] = tv.value;
        }
        entry.data = data;
      }

      const content = TresParser.serialize(this._oldRaw);
      FileDiscovery.saveFile('data/props', content, this._filename).catch((err) => {
        console.warn(`EditPropDefCommand.undo: Failed to save "${this._filename}": ${err.message}`);
      });
    } else {
      // Fall back to re-serializing old model
      const oldRaw = propModelToRaw(this._oldModel);
      const content = TresParser.serialize(oldRaw);

      const data = {};
      for (const [key, tv] of oldRaw.resourceFields) {
        data[key] = tv.value;
      }

      const entry = ProjectContext.files.props.get(this._filename);
      if (entry) {
        entry.data = data;
        entry.raw = oldRaw;
      }

      FileDiscovery.saveFile('data/props', content, this._filename).catch((err) => {
        console.warn(`EditPropDefCommand.undo: Failed to save "${this._filename}": ${err.message}`);
      });
    }
  }
}

/**
 * Command to delete a prop definition.
 */
export class DeletePropDefCommand {
  /**
   * @param {string} filename
   * @param {PropDefModel} model
   * @param {import('./commands.js').CommandHistory} [commandHistory]
   */
  constructor(filename, model, commandHistory) {
    this._filename = filename;
    this._model = model;
    this._savedEntry = null;
    this.tab = 'props';
    this.type = 'DeletePropDef';
  }

  execute() {
    // Save entry for undo
    this._savedEntry = ProjectContext.files.props.get(this._filename) || null;
    ProjectContext.files.props.delete(this._filename);
  }

  undo() {
    if (this._savedEntry) {
      ProjectContext.files.props.set(this._filename, this._savedEntry);

      // Re-write the file
      const content = TresParser.serialize(this._savedEntry.raw);
      FileDiscovery.saveFile('data/props', content, this._filename).catch((err) => {
        console.warn(`DeletePropDefCommand.undo: Failed to save "${this._filename}": ${err.message}`);
      });
    }
  }
}

// ============================================================
// Delete Validation — Usage Scan
// ============================================================

/**
 * Scan all loaded maps for props referencing this prop type.
 * @param {string} propId
 * @returns {Array<{map: string, count: number}>}
 */
export function findPropUsage(propId) {
  /** @type {Array<{map: string, count: number}>} */
  const usages = [];
  for (const [mapName, mapEntry] of ProjectContext.files.maps) {
    let count = 0;
    for (const [key, tile] of Object.entries(mapEntry.data.tiles || {})) {
      if (tile.props) {
        count += tile.props.filter(p => p.type === propId).length;
      }
    }
    if (count > 0) usages.push({ map: mapName, count });
  }
  return usages;
}
