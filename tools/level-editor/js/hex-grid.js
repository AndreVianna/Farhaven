// ============================================================
// HexGrid Model (task-007)
// ============================================================

import { HEX_SIZE, HexMath } from './hex-math.js';

/** Maps internal string categories to engine JSON integer values. */
export const CATEGORY_TO_INT = { resource: 0, structure: 1, anomaly: 2, spawn: 3 };
/** Maps engine JSON integer category values to internal string categories. */
export const INT_TO_CATEGORY = { 0: 'resource', 1: 'structure', 2: 'anomaly', 3: 'spawn' };

/**
 * Shared category color definitions used by canvas rendering and UI panels.
 * @type {Object<string, { fill: string, badge: string, label: string }>}
 */
export const CATEGORY_COLORS = {
  resource: { fill: 'rgba(68,136,255,0.3)', badge: '#4488ff', label: 'blue' },
  structure: { fill: 'rgba(255,170,68,0.3)', badge: '#ffaa44', label: 'orange' },
  anomaly: { fill: 'rgba(180,68,255,0.3)', badge: '#b444ff', label: 'purple' },
};

/**
 * Creates a default TileData object.
 * @param {string} [biome='']
 * @returns {{ biome: string, elevation: number, props: Array<Object> }}
 */
export function createTileData(biome = '') {
  return { biome, elevation: 0, props: [] };
}

/**
 * Creates a PropInstance.
 * @param {string} type - Resource/structure/anomaly identifier
 * @param {number} [sq=0] - Sub-hex q coordinate
 * @param {number} [sr=0] - Sub-hex r coordinate
 * @param {string} [category='resource'] - 'resource' | 'structure' | 'anomaly'
 * @param {Object} [options={}] - Per-category optional fields:
 *   **All categories:**
 *   @param {number} [options.rotation] - Rotation in degrees (default 0)
 *   **resource only:**
 *   @param {number} [options.remaining] - Current resource amount
 *   @param {number} [options.max_amount] - Maximum resource amount
 *   @param {string} [options.tool_required] - Tool needed to harvest
 *   @param {number} [options.respawn_time] - Respawn time in seconds
 *   **structure only:**
 *   @param {Array<{q: number, r: number}>} [options.footprint] - Occupied sub-hex offsets
 *   @param {boolean} [options.blocks_movement] - Whether structure blocks movement
 * @returns {Object}
 */
export function createProp(type, sq = 0, sr = 0, category = 'resource', options = {}) {
  const prop = { type, sq, sr, category };
  if (category === 'resource') {
    prop.rotation = typeof options.rotation === 'number' ? options.rotation : 0;
    // Resource-specific optional fields (populated from biome data or map JSON)
    if (typeof options.remaining === 'number') prop.remaining = options.remaining;
    if (typeof options.max_amount === 'number') prop.max_amount = options.max_amount;
    if (options.tool_required) prop.tool_required = options.tool_required;
    if (typeof options.respawn_time === 'number') prop.respawn_time = options.respawn_time;
  }
  if (category === 'structure') {
    prop.rotation = typeof options.rotation === 'number' ? options.rotation : 0;
    if (options.footprint) prop.footprint = options.footprint;
    if (typeof options.blocks_movement === 'boolean') prop.blocks_movement = options.blocks_movement;
  }
  if (category === 'anomaly') {
    prop.rotation = typeof options.rotation === 'number' ? options.rotation : 0;
  }
  return prop;
}

/**
 * In-memory map model. Key = "q,r", Value = TileData.
 */
export class HexGrid {
  constructor() {
    /** @type {{ chapter_id: string, name: string, spawn: number[] }} */
    this.meta = { chapter_id: '', name: '', spawn: [0, 0] };
    /** @type {Map<string, Object>} */
    this.tiles = new Map();
    /**
     * Single callback slot for change notifications. Only one listener
     * can be registered at a time. If multiple listeners are needed in
     * the future, consider switching to an array-based observer pattern.
     * @type {function():void|null}
     */
    this.onChange = null;
  }

  /**
   * Parse a "q,r" key string into { q, r } integers.
   * @param {string} key
   * @returns {{ q: number, r: number }}
   */
  static parseKey(key) {
    const parts = key.split(',');
    return { q: parseInt(parts[0], 10), r: parseInt(parts[1], 10) };
  }

  /**
   * @param {number} q
   * @param {number} r
   * @returns {string}
   */
  getKey(q, r) {
    return `${q},${r}`;
  }

  /**
   * @param {number} q
   * @param {number} r
   * @returns {Object|undefined}
   */
  getTile(q, r) {
    return this.tiles.get(this.getKey(q, r));
  }

  /**
   * @param {number} q
   * @param {number} r
   * @param {Object} data
   * @returns {void}
   */
  setTile(q, r, data) {
    this.tiles.set(this.getKey(q, r), data);
    if (this.onChange) this.onChange();
  }

  /**
   * @param {number} q
   * @param {number} r
   * @returns {void}
   */
  deleteTile(q, r) {
    this.tiles.delete(this.getKey(q, r));
    if (this.onChange) this.onChange();
  }

  /**
   * @param {number} q
   * @param {number} r
   * @returns {boolean}
   */
  hasTile(q, r) {
    return this.tiles.has(this.getKey(q, r));
  }

  /**
   * @returns {IterableIterator<[string, Object]>}
   */
  getAllTiles() {
    return this.tiles.entries();
  }

  /**
   * Remove all tiles.
   * @returns {void}
   */
  clear() {
    this.tiles.clear();
    if (this.onChange) this.onChange();
  }
}

/**
 * Parse legacy tile JSON (pre-props-array format) into a props array.
 * Handles resources (string, x/y, sq/sr), structure (string or object), and anomaly.
 * @param {Object} tileJson
 * @returns {Array<Object>}
 */
function _parseLegacyTile(tileJson) {
  const props = [];

  // Legacy resources
  if (Array.isArray(tileJson.resources)) {
    for (const res of tileJson.resources) {
      // B5/Q5: Handle plain-string resource format
      if (typeof res === 'string') {
        props.push(createProp(res, 0, 0, 'resource', {
          rotation: Math.floor(Math.random() * 360),
        }));
      } else if ('x' in res && !('sq' in res)) {
        // Legacy x,y format: convert continuous (x, y) to nearest sub-hex
        const subHex = HexMath.pixelToSubHex(
          (typeof res.x === 'number' ? res.x : 0) * HEX_SIZE,
          (typeof res.y === 'number' ? res.y : 0) * HEX_SIZE
        );
        props.push(createProp(
          res.type || '', subHex.q, subHex.r, 'resource',
          { rotation: typeof res.rotation === 'number' ? res.rotation : 0 }
        ));
      } else {
        // New sq,sr format
        const sq = typeof res.sq === 'number' ? res.sq : 0;
        const sr = typeof res.sr === 'number' ? res.sr : 0;
        props.push(createProp(
          res.type || '', sq, sr, 'resource',
          { rotation: typeof res.rotation === 'number' ? res.rotation : 0 }
        ));
      }
    }
  }

  // Legacy structure
  if (tileJson.structure) {
    if (typeof tileJson.structure === 'string') {
      props.push(createProp(tileJson.structure, 0, 0, 'structure', {
        footprint: [{ q: 0, r: 0 }],
      }));
    } else {
      const st = tileJson.structure;
      const anchorSq = (st.sub_hexes && st.sub_hexes.length > 0) ? (st.sub_hexes[0].sq || 0) : 0;
      const anchorSr = (st.sub_hexes && st.sub_hexes.length > 0) ? (st.sub_hexes[0].sr || 0) : 0;
      props.push(createProp(st.type || '', anchorSq, anchorSr, 'structure', {
        footprint: st.sub_hexes || [{ q: 0, r: 0 }],
      }));
    }
  }

  // B6: Legacy anomaly — handle both string and object form
  if (tileJson.anomaly) {
    const anomalyType = typeof tileJson.anomaly === 'string'
      ? tileJson.anomaly
      : (tileJson.anomaly.type || '');
    props.push(createProp(anomalyType, 0, 0, 'anomaly'));
  }

  return props;
}

/**
 * Load map JSON data into the HexGrid model.
 * @param {HexGrid} hexGrid
 * @param {Object} mapData - parsed ch1.json
 * @returns {{ success: true } | { success: false, error: string }}
 */
export function loadMapIntoGrid(hexGrid, mapData) {
  // G2: Validate input before modifying grid
  if (!mapData || typeof mapData !== 'object') {
    return { success: false, error: 'mapData must be a non-null object.' };
  }
  if (mapData.tiles !== undefined && (typeof mapData.tiles !== 'object' || mapData.tiles === null)) {
    return { success: false, error: 'mapData.tiles must be an object if present.' };
  }

  hexGrid.clear();
  hexGrid.meta.chapter_id = mapData.chapter_id || '';
  hexGrid.meta.name = mapData.name || '';
  if (Array.isArray(mapData.spawn)) {
    const s = mapData.spawn;
    // Preserve original length: only store 4 elements if sub-hex was present
    if (s.length >= 4 && (s[2] || s[3])) {
      hexGrid.meta.spawn = [s[0] || 0, s[1] || 0, s[2] || 0, s[3] || 0];
    } else {
      hexGrid.meta.spawn = [s[0] || 0, s[1] || 0];
    }
  } else {
    hexGrid.meta.spawn = [0, 0];
  }

  if (mapData.tiles && typeof mapData.tiles === 'object') {
    for (const [key, tileJson] of Object.entries(mapData.tiles)) {
      const { q, r } = HexGrid.parseKey(key);
      const tile = createTileData(tileJson.biome || '');
      tile.elevation = typeof tileJson.elevation === 'number' ? tileJson.elevation : 0;

      // New format: props array present
      if (Array.isArray(tileJson.props)) {
        tile.props = tileJson.props.map(p => {
          // Handle both integer (engine) and string (legacy editor) categories
          const categoryStr = typeof p.category === 'number' ? (INT_TO_CATEGORY[p.category] || 'resource') : (p.category || 'resource');
          // Handle both sub_hex_q/sub_hex_r (engine) and sq/sr (legacy editor) field names
          const sq = typeof p.sub_hex_q === 'number' ? p.sub_hex_q : (typeof p.sq === 'number' ? p.sq : 0);
          const sr = typeof p.sub_hex_r === 'number' ? p.sub_hex_r : (typeof p.sr === 'number' ? p.sr : 0);
          const rotation = typeof p.rotation === 'number' ? p.rotation : 0;

          const options = { rotation };
          // Resource-specific fields
          if (categoryStr === 'resource') {
            if (typeof p.remaining === 'number') options.remaining = p.remaining;
            if (typeof p.max_amount === 'number') options.max_amount = p.max_amount;
            if (p.tool_required) options.tool_required = p.tool_required;
            if (typeof p.respawn_time === 'number') options.respawn_time = p.respawn_time;
          }
          // Structure-specific fields
          if (categoryStr === 'structure') {
            if (typeof p.blocks_movement === 'boolean') options.blocks_movement = p.blocks_movement;
            if (p.footprint) options.footprint = p.footprint;
          }

          return createProp(p.type || '', sq, sr, categoryStr, options);
        });
      } else {
        tile.props = _parseLegacyTile(tileJson);
      }

      hexGrid.setTile(q, r, tile);
    }
  }

  return { success: true };
}

/**
 * Serialize the HexGrid model back to map JSON format.
 * @param {HexGrid} hexGrid
 * @returns {Object}
 */
export function serializeGridToMapJson(hexGrid) {
  const tiles = {};
  for (const [key, tile] of hexGrid.getAllTiles()) {
    const entry = {
      biome: tile.biome,
      elevation: tile.elevation,
    };
    if (tile.props && tile.props.length > 0) {
      entry.props = tile.props.map(p => {
        const obj = {
          type: p.type,
          category: CATEGORY_TO_INT[p.category] ?? 0,
        };
        // Only include sub_hex if not (0,0)
        if (p.sq !== 0 || p.sr !== 0) {
          obj.sub_hex_q = p.sq;
          obj.sub_hex_r = p.sr;
        }
        // Only include rotation if non-zero
        if (p.rotation) obj.rotation = p.rotation;
        // Resource-specific
        if (p.category === 'resource') {
          if (typeof p.remaining === 'number') obj.remaining = p.remaining;
          if (typeof p.max_amount === 'number') obj.max_amount = p.max_amount;
          if (p.tool_required) obj.tool_required = p.tool_required;
          if (typeof p.respawn_time === 'number' && p.respawn_time > 0) obj.respawn_time = p.respawn_time;
        }
        // Structure-specific (footprint is internal only — not serialized)
        if (p.category === 'structure') {
          if (p.blocks_movement) obj.blocks_movement = true;
        }
        return obj;
      });
    }
    tiles[key] = entry;
  }
  // Trim trailing zero sub-hex elements from spawn to reduce diff noise
  const spawn = [...hexGrid.meta.spawn];
  if (spawn.length === 4 && spawn[2] === 0 && spawn[3] === 0) {
    spawn.length = 2;
  }
  const result = { spawn, tiles };
  // Include optional metadata if present
  if (hexGrid.meta.chapter_id) result.chapter_id = hexGrid.meta.chapter_id;
  if (hexGrid.meta.name) result.name = hexGrid.meta.name;
  return result;
}
