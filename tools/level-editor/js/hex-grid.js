// ============================================================
// HexGrid Model (task-007)
// ============================================================

import { HEX_SIZE, HexMath } from './hex-math.js';

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
 * @param {string} type
 * @param {number} [sq=0] - Sub-hex q coordinate
 * @param {number} [sr=0] - Sub-hex r coordinate
 * @param {string} [category='resource'] - 'resource' | 'structure' | 'anomaly'
 * @param {Object} [options={}]
 * @param {number} [options.rotation] - Rotation in degrees (resources only)
 * @param {Array<{q: number, r: number}>} [options.footprint] - Occupied sub-hex offsets (structures only)
 * @returns {Object}
 */
export function createProp(type, sq = 0, sr = 0, category = 'resource', options = {}) {
  const prop = { type, sq, sr, category };
  if (category === 'resource') {
    prop.rotation = typeof options.rotation === 'number' ? options.rotation : 0;
  }
  if (category === 'structure' && options.footprint) {
    prop.footprint = options.footprint;
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
    /** @type {function():void|null} */
    this.onChange = null;
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
 * Load map JSON data into the HexGrid model.
 * @param {HexGrid} hexGrid
 * @param {Object} mapData - parsed ch1.json
 * @returns {void}
 */
export function loadMapIntoGrid(hexGrid, mapData) {
  hexGrid.clear();
  hexGrid.meta.chapter_id = mapData.chapter_id || '';
  hexGrid.meta.name = mapData.name || '';
  hexGrid.meta.spawn = Array.isArray(mapData.spawn) ? [...mapData.spawn] : [0, 0];

  if (mapData.tiles && typeof mapData.tiles === 'object') {
    for (const [key, tileJson] of Object.entries(mapData.tiles)) {
      const parts = key.split(',');
      const q = parseInt(parts[0], 10);
      const r = parseInt(parts[1], 10);
      const tile = createTileData(tileJson.biome || '');
      tile.elevation = typeof tileJson.elevation === 'number' ? tileJson.elevation : 0;

      // New format: props array present
      if (Array.isArray(tileJson.props)) {
        tile.props = tileJson.props.map(p => {
          const prop = { type: p.type, sq: p.sq, sr: p.sr, category: p.category };
          if (p.category === 'resource' && typeof p.rotation === 'number') prop.rotation = p.rotation;
          if (p.category === 'structure' && p.footprint) prop.footprint = p.footprint;
          return prop;
        });
      } else {
        // Legacy format: merge resources, structure, anomaly into props
        tile.props = [];

        // Legacy resources
        if (Array.isArray(tileJson.resources)) {
          for (const res of tileJson.resources) {
            let sq, sr;
            if ('x' in res && !('sq' in res)) {
              // Legacy format: convert continuous (x, y) to nearest sub-hex
              const subHex = HexMath.pixelToSubHex(
                (typeof res.x === 'number' ? res.x : 0) * HEX_SIZE,
                (typeof res.y === 'number' ? res.y : 0) * HEX_SIZE
              );
              sq = subHex.q;
              sr = subHex.r;
            } else {
              sq = typeof res.sq === 'number' ? res.sq : 0;
              sr = typeof res.sr === 'number' ? res.sr : 0;
            }
            tile.props.push(createProp(
              res.type || '', sq, sr, 'resource',
              { rotation: typeof res.rotation === 'number' ? res.rotation : 0 }
            ));
          }
        }

        // Legacy structure
        if (tileJson.structure) {
          if (typeof tileJson.structure === 'string') {
            tile.props.push(createProp(tileJson.structure, 0, 0, 'structure', {
              footprint: [{ q: 0, r: 0 }],
            }));
          } else {
            const st = tileJson.structure;
            const anchorSq = (st.sub_hexes && st.sub_hexes.length > 0) ? (st.sub_hexes[0].sq || 0) : 0;
            const anchorSr = (st.sub_hexes && st.sub_hexes.length > 0) ? (st.sub_hexes[0].sr || 0) : 0;
            tile.props.push(createProp(st.type || '', anchorSq, anchorSr, 'structure', {
              footprint: st.sub_hexes || [{ q: 0, r: 0 }],
            }));
          }
        }

        // Legacy anomaly
        if (tileJson.anomaly) {
          tile.props.push(createProp(tileJson.anomaly, 0, 0, 'anomaly'));
        }
      }

      hexGrid.setTile(q, r, tile);
    }
  }
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
        const obj = { type: p.type, sq: p.sq, sr: p.sr, category: p.category };
        if (p.category === 'resource' && typeof p.rotation === 'number') obj.rotation = p.rotation;
        if (p.category === 'structure' && p.footprint) obj.footprint = p.footprint;
        return obj;
      });
    }
    tiles[key] = entry;
  }
  return {
    chapter_id: hexGrid.meta.chapter_id,
    name: hexGrid.meta.name,
    spawn: [...hexGrid.meta.spawn],
    tiles: tiles,
  };
}
