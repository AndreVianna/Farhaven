// ============================================================
// HexGrid Model (task-007)
// ============================================================

/**
 * Creates a default TileData object.
 * @param {string} [biome='']
 * @returns {{ biome: string, elevation: number, structure: string|null, anomaly: string|null, resources: Array<Object> }}
 */
export function createTileData(biome = '') {
  return {
    biome: biome,
    elevation: 0,
    structure: null,
    anomaly: null,
    resources: [],
  };
}

/**
 * Creates a ResourceInstance.
 * @param {string} type
 * @param {number} x
 * @param {number} y
 * @param {number} rotation
 * @returns {{ type: string, x: number, y: number, rotation: number }}
 */
export function createResourceInstance(type, x, y, rotation) {
  return { type, x, y, rotation };
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
      tile.structure = tileJson.structure || null;
      tile.anomaly = tileJson.anomaly || null;
      tile.resources = Array.isArray(tileJson.resources)
        ? tileJson.resources.map(res => createResourceInstance(
            res.type || '',
            typeof res.x === 'number' ? res.x : 0,
            typeof res.y === 'number' ? res.y : 0,
            typeof res.rotation === 'number' ? res.rotation : 0
          ))
        : [];
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
      resources: tile.resources.map(r => ({
        type: r.type,
        x: r.x,
        y: r.y,
        rotation: r.rotation,
      })),
    };
    if (tile.structure) entry.structure = tile.structure;
    if (tile.anomaly) entry.anomaly = tile.anomaly;
    tiles[key] = entry;
  }
  return {
    chapter_id: hexGrid.meta.chapter_id,
    name: hexGrid.meta.name,
    spawn: [...hexGrid.meta.spawn],
    tiles: tiles,
  };
}
