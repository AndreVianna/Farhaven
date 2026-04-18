// ============================================================
// HexGrid Model (task-007)
// ============================================================

import { HEX_SIZE, HexMath } from './hex-math.js';

/**
 * Prop category names indexed by engine integer value.
 * Natural (0-5) and Non-Natural (6-9).
 * @type {string[]}
 */
export const CATEGORIES = [
  'plant', 'mineral', 'animal', 'fungi', 'liquid', 'ooze',
  'structure', 'vehicle', 'equipment', 'storage',
  'stuff',
];

/** Maps internal string categories to engine JSON integer values. */
export const CATEGORY_TO_INT = Object.fromEntries(CATEGORIES.map((name, i) => [name, i]));
/** Maps engine JSON integer category values to internal string categories. */
export const INT_TO_CATEGORY = Object.fromEntries(CATEGORIES.map((name, i) => [i, name]));

/** Prop rarity tiers (affect spawn frequency and catalog grouping). */
export const RARITIES = ['common', 'uncommon', 'rare'];

/** Natural category indices (0-5). */
export const NATURAL_CATEGORIES = new Set([0, 1, 2, 3, 4, 5]);

/**
 * Display labels (plural where applicable) for category tab bar.
 * Internal name → user-facing label.
 */
export const CATEGORY_LABELS = {
  mineral: 'Minerals',
  plant: 'Flora',
  animal: 'Fauna',
  fungi: 'Fungi',
  ooze: 'Oozes',
  liquid: 'Liquids',
  stuff: 'Stuff',
  structure: 'Structures',
  equipment: 'Equipment',
  vehicle: 'Vehicles',
  storage: 'Containers',
};

/** Display order for category tabs (Andre's preferred order, 2026-04-10). */
export const CATEGORY_TAB_ORDER = [
  'mineral', 'plant', 'animal', 'fungi', 'ooze', 'liquid',
  'stuff', 'structure', 'equipment', 'vehicle', 'storage',
];

/**
 * Origin names indexed by engine integer value.
 * @type {string[]}
 */
export const ORIGINS = ['natural', 'crafted', 'human', 'native_alien', 'unknown'];

/** Maps origin string to integer. */
export const ORIGIN_TO_INT = Object.fromEntries(ORIGINS.map((name, i) => [name, i]));
/** Maps origin integer to string. */
export const INT_TO_ORIGIN = Object.fromEntries(ORIGINS.map((name, i) => [i, name]));

/**
 * Default origin for a given category index.
 * Natural categories (0-5) → 0 (natural), Non-Natural (6-9) → 1 (crafted).
 * @param {number} categoryInt
 * @returns {number}
 */
export function defaultOrigin(categoryInt) {
  return NATURAL_CATEGORIES.has(categoryInt) ? 0 : 1;
}

/**
 * Shared category color definitions used by canvas rendering and UI panels.
 * @type {Object<string, { fill: string, badge: string, label: string }>}
 */
export const CATEGORY_COLORS = {
  plant:     { fill: 'rgba(68,200,68,0.3)',  badge: '#44c844', label: 'green' },
  mineral:   { fill: 'rgba(160,160,180,0.3)', badge: '#a0a0b4', label: 'grey' },
  animal:    { fill: 'rgba(220,120,60,0.3)',  badge: '#dc783c', label: 'brown' },
  fungi:     { fill: 'rgba(180,120,220,0.3)', badge: '#b478dc', label: 'lavender' },
  liquid:    { fill: 'rgba(68,160,255,0.3)',  badge: '#44a0ff', label: 'blue' },
  ooze:      { fill: 'rgba(160,220,60,0.3)',  badge: '#a0dc3c', label: 'lime' },
  structure: { fill: 'rgba(255,170,68,0.3)',  badge: '#ffaa44', label: 'orange' },
  vehicle:   { fill: 'rgba(255,220,68,0.3)',  badge: '#ffdc44', label: 'yellow' },
  equipment: { fill: 'rgba(68,220,220,0.3)',  badge: '#44dcdc', label: 'cyan' },
  storage:   { fill: 'rgba(200,140,100,0.3)', badge: '#c88c64', label: 'tan' },
};

/**
 * Compute waterLevel for a water tile: min elevation of adjacent dry tiles.
 * Returns tile.elevation if no dry neighbor exists (open water).
 * @param {HexGrid} grid
 * @param {number} q
 * @param {number} r
 * @returns {number}
 */
export function computeWaterLevel(grid, q, r) {
  let minDryElev = Infinity;
  for (const dir of HexMath.DIRECTIONS) {
    const neighbor = grid.getTile(q + dir.q, r + dir.r);
    if (!neighbor) continue;
    if (neighbor.biome === 'B00005') continue; // skip water neighbors
    if (neighbor.elevation < minDryElev) minDryElev = neighbor.elevation;
  }
  const tile = grid.getTile(q, r);
  if (!tile) return 0;
  // No dry neighbors (open water) → waterLevel = elevation (surface at bottom)
  if (minDryElev === Infinity) return tile.elevation;
  // waterLevel = min(dry neighbors), clamped so elevation <= waterLevel
  return Math.max(tile.elevation, minDryElev);
}

/** Default walls array — all false (no walls). */
export const DEFAULT_WALLS = [false, false, false, false, false, false];

/**
 * Creates a default TileData object.
 * @param {string} [biome='']
 * @returns {{ biome: string, elevation: number, props: Array<Object>, walls: boolean[], waterLevel: number|null, waterType: string|null }}
 */
export function createTileData(biome = '') {
  return { biome, elevation: 0, props: [], walls: [...DEFAULT_WALLS], waterLevel: null, waterType: null };
}

/**
 * Compute default wall values for a tile based on elevation diffs
 * with its 6 neighbors. Wall = true when abs(diff) >= 2.
 * @param {HexGrid} grid
 * @param {number} q
 * @param {number} r
 * @returns {boolean[]} 6-element array matching HexMath.DIRECTIONS
 */
export function computeDefaultWalls(grid, q, r) {
  const tile = grid.getTile(q, r);
  if (!tile) return [...DEFAULT_WALLS];
  const walls = [];
  for (const dir of HexMath.DIRECTIONS) {
    const neighbor = grid.getTile(q + dir.q, r + dir.r);
    if (!neighbor) {
      walls.push(false);
    } else {
      walls.push(Math.abs(tile.elevation - neighbor.elevation) >= 2);
    }
  }
  return walls;
}

/**
 * Recompute walls for a tile AND all its neighbors (since changing
 * one tile's elevation affects walls on both sides of each edge).
 * @param {HexGrid} grid
 * @param {number} q
 * @param {number} r
 */
export function recomputeWallsAround(grid, q, r) {
  const tile = grid.getTile(q, r);
  if (tile) tile.walls = computeDefaultWalls(grid, q, r);
  for (const dir of HexMath.DIRECTIONS) {
    const nq = q + dir.q, nr = r + dir.r;
    const neighbor = grid.getTile(nq, nr);
    if (neighbor) neighbor.walls = computeDefaultWalls(grid, nq, nr);
  }
}

/**
 * Creates a PropInstance.
 * @param {string} type - Prop identifier (e.g. 'thornwood_tree')
 * @param {number} [sq=0] - Sub-hex q coordinate
 * @param {number} [sr=0] - Sub-hex r coordinate
 * @param {string} [category='plant'] - Category name from CATEGORIES
 * @param {Object} [options={}] - Optional fields:
 *   @param {number} [options.rotation] - Rotation 0-359°
 *   @param {number|string} [options.origin] - Origin index or name. Default derived from category.
 *   @param {number} [options.remaining] - Current prop amount
 *   @param {number} [options.max_amount] - Maximum prop amount
 *   @param {string} [options.tool_required] - Tool needed to harvest
 *   @param {number} [options.respawn_time] - Respawn time in seconds
 *   @param {Array<{q: number, r: number}>} [options.footprint] - Occupied sub-hex offsets (structures)
 *   @param {boolean} [options.blocks_movement] - Whether prop blocks movement
 * @returns {Object}
 */
export function createProp(type, sq = 0, sr = 0, category = 'plant', options = {}) {
  const catInt = CATEGORY_TO_INT[category] != null ? CATEGORY_TO_INT[category] : 0;
  const prop = { type, sq, sr, category };
  // Origin: explicit > default from category
  if (typeof options.origin === 'number') {
    prop.origin = options.origin;
  } else if (typeof options.origin === 'string' && ORIGIN_TO_INT[options.origin] != null) {
    prop.origin = INT_TO_ORIGIN[ORIGIN_TO_INT[options.origin]];
  } else {
    prop.origin = INT_TO_ORIGIN[defaultOrigin(catInt)];
  }
  // Rotation (all categories)
  prop.rotation = typeof options.rotation === 'number' ? options.rotation : 0;
  // Optional fields (applicable to any category depending on type)
  if (typeof options.remaining === 'number') prop.remaining = options.remaining;
  if (typeof options.max_amount === 'number') prop.max_amount = options.max_amount;
  if (options.tool_required) prop.tool_required = options.tool_required;
  if (typeof options.respawn_time === 'number') prop.respawn_time = options.respawn_time;
  if (options.footprint) prop.footprint = options.footprint;
  if (typeof options.blocks_movement === 'boolean') prop.blocks_movement = options.blocks_movement;
  // Feature-011 per-instance overrides. Sentinel < 0 / missing = "use
  // seeded default from PlaceableCap". Only effective when the resolved
  // placement preset is SINGLE.
  if (typeof options.placement_override === 'number') prop.placement_override = options.placement_override;
  if (typeof options.variant_override === 'number') prop.variant_override = options.variant_override;
  if (typeof options.scale_override === 'number') prop.scale_override = options.scale_override;
  if (typeof options.rotation_override === 'number') prop.rotation_override = options.rotation_override;
  return prop;
}

/**
 * In-memory map model. Key = "q,r", Value = TileData.
 */
export class HexGrid {
  constructor() {
    /** @type {{ chapter_id: string, name: string, spawn: number[], generator?: Object|null }} */
    this.meta = { chapter_id: '', name: '', spawn: [0, 0], generator: null };
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

  // Legacy props
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
  hexGrid.meta.generator = mapData.generator || null;
  if (Array.isArray(mapData.spawn)) {
    const s = mapData.spawn;
    if (s.length >= 5) {
      hexGrid.meta.spawn = [s[0] || 0, s[1] || 0, s[2] || 0, s[3] || 0, s[4] || 0];
    } else if (s.length >= 4 && (s[2] || s[3])) {
      hexGrid.meta.spawn = [s[0] || 0, s[1] || 0, s[2] || 0, s[3] || 0, 0];
    } else {
      hexGrid.meta.spawn = [s[0] || 0, s[1] || 0, 0, 0, 0];
    }
  } else {
    hexGrid.meta.spawn = [0, 0, 0, 0, 0];
  }

  if (mapData.tiles && typeof mapData.tiles === 'object') {
    for (const [key, tileJson] of Object.entries(mapData.tiles)) {
      const { q, r } = HexGrid.parseKey(key);
      const tile = createTileData(tileJson.biome || '');
      tile.elevation = typeof tileJson.elevation === 'number' ? tileJson.elevation : 0;
      if (Array.isArray(tileJson.walls) && tileJson.walls.length === 6) {
        tile.walls = tileJson.walls.map(v => !!v);
      }
      if (typeof tileJson.waterLevel === 'number') {
        tile.waterLevel = tileJson.waterLevel;
      }
      if (tileJson.waterType) {
        tile.waterType = tileJson.waterType;
      }

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
          // Origin (integer or string)
          if (typeof p.origin === 'number') options.origin = p.origin;
          else if (typeof p.origin === 'string') options.origin = p.origin;
          // Optional fields (applicable to any category)
          if (typeof p.remaining === 'number') options.remaining = p.remaining;
          if (typeof p.max_amount === 'number') options.max_amount = p.max_amount;
          if (p.tool_required) options.tool_required = p.tool_required;
          if (typeof p.respawn_time === 'number') options.respawn_time = p.respawn_time;
          if (typeof p.blocks_movement === 'boolean') options.blocks_movement = p.blocks_movement;
          if (p.footprint) options.footprint = p.footprint;
          // Feature-011 per-instance overrides
          if (typeof p.placement_override === 'number') options.placement_override = p.placement_override;
          if (typeof p.variant_override === 'number') options.variant_override = p.variant_override;
          if (typeof p.scale_override === 'number') options.scale_override = p.scale_override;
          if (typeof p.rotation_override === 'number') options.rotation_override = p.rotation_override;

          return createProp(p.type || '', sq, sr, categoryStr, options);
        });
      } else {
        tile.props = _parseLegacyTile(tileJson);
      }

      hexGrid.setTile(q, r, tile);
    }
  }

  // Walls default to all-false. Placement is manual via wall tool.

  // Compute waterLevel for water tiles that don't have it from JSON.
  for (const [key, tile] of hexGrid.tiles) {
    if (tile.biome !== 'B00005') continue;
    if (tile.waterLevel != null) continue;
    const { q, r } = HexGrid.parseKey(key);
    tile.waterLevel = computeWaterLevel(hexGrid, q, r);
  }
  // Water↔land shoreline always gets a wall (different biome types
  // never smooth into each other).
  for (const [key, tile] of hexGrid.tiles) {
    const { q, r } = HexGrid.parseKey(key);
    const tileIsWater = tile.biome === 'B00005';
    for (let d = 0; d < HexMath.DIRECTIONS.length; d++) {
      const dir = HexMath.DIRECTIONS[d];
      const neighbor = hexGrid.getTile(q + dir.q, r + dir.r);
      if (!neighbor) continue;
      const neighborIsWater = neighbor.biome === 'B00005';
      if (tileIsWater !== neighborIsWater) {
        tile.walls[d] = true;
      }
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
      walls: tile.walls || [...DEFAULT_WALLS],
    };
    if (tile.waterLevel != null) {
      entry.waterLevel = tile.waterLevel;
    }
    if (tile.waterType) {
      entry.waterType = tile.waterType;
    }
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
        // Origin
        if (typeof p.origin === 'string' && ORIGIN_TO_INT[p.origin] != null) {
          obj.origin = ORIGIN_TO_INT[p.origin];
        } else if (typeof p.origin === 'number') {
          obj.origin = p.origin;
        }
        // Only include rotation if non-zero
        if (p.rotation) obj.rotation = p.rotation;
        // Optional fields (any category)
        if (typeof p.remaining === 'number') obj.remaining = p.remaining;
        if (typeof p.max_amount === 'number') obj.max_amount = p.max_amount;
        if (p.tool_required) obj.tool_required = p.tool_required;
        if (typeof p.respawn_time === 'number' && p.respawn_time > 0) obj.respawn_time = p.respawn_time;
        if (p.blocks_movement) obj.blocks_movement = true;
        // Feature-011 overrides — emit only when the user has authored
        // a non-sentinel value. Sentinel (< 0) means "let the engine
        // compute from the seed" and matches the default in prop.gd.
        if (typeof p.placement_override === 'number' && p.placement_override >= 0) {
          obj.placement_override = p.placement_override;
        }
        if (typeof p.variant_override === 'number' && p.variant_override >= 0) {
          obj.variant_override = p.variant_override;
        }
        if (typeof p.scale_override === 'number' && p.scale_override > 0) {
          obj.scale_override = p.scale_override;
        }
        if (typeof p.rotation_override === 'number' && p.rotation_override >= 0) {
          obj.rotation_override = p.rotation_override;
        }
        // footprint is internal only — not serialized
        return obj;
      });
    }
    tiles[key] = entry;
  }
  // Trim trailing zero elements from spawn to reduce diff noise
  const spawn = [...hexGrid.meta.spawn];
  if (spawn.length === 5 && spawn[4] === 0) {
    spawn.length = 4;
  }
  if (spawn.length === 4 && spawn[2] === 0 && spawn[3] === 0) {
    spawn.length = 2;
  }
  const result = { spawn, tiles };
  // Include optional metadata if present
  if (hexGrid.meta.chapter_id) result.chapter_id = hexGrid.meta.chapter_id;
  if (hexGrid.meta.name) result.name = hexGrid.meta.name;
  if (hexGrid.meta.generator) result.generator = hexGrid.meta.generator;
  return result;
}
