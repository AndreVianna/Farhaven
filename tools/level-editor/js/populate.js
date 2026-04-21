// ============================================================
// Populate — generative prop distribution from biome.natural_props
// ============================================================
//
// Drives the Map Editor "Populate" button. Walks every tile on the
// active map, looks up its biome's `natural_props` table, and for
// each entry checks the placement conditions, rolls frequency, and
// spawns N copies at seeded-random sub-hex positions.
//
// Category-ordered sweep (minerals → liquids → oozes → fungi →
// flora → fauna) means later categories' `near_props` conditions can
// reference props placed earlier in the same Populate run.
//
// All edits go through a BatchCommand so the user can undo the entire
// populate pass as a single step.

import { ProjectContext } from './file-discovery.js';
import { AddPropCommand, DeletePropCommand, BatchCommand } from './commands.js';
import { createProp } from './hex-grid.js';
import { HexMath } from './hex-math.js';

/**
 * Order in which categories populate. Read from Andre's spec.
 */
const CATEGORY_ORDER = ['mineral', 'liquid', 'ooze', 'fungi', 'plant', 'animal'];

/**
 * xorshift32 RNG — deterministic, seedable, small. Used so a given
 * (seed, map, biome table) always yields the same populate output.
 * Good enough for gameplay-flavored randomness (not crypto).
 */
export class SeededRng {
  /**
   * @param {number} seed - 32-bit unsigned integer
   */
  constructor(seed) {
    // Avoid the zero fixed point — xorshift32 stays at 0 forever if
    // state ever becomes 0. Fall back to 0x9E3779B9 (the 32-bit
    // golden-ratio constant) instead of 1 to land deeper in the
    // state space and avoid degenerate early outputs.
    this._state = (seed | 0) || 0x9E3779B9;
  }
  /** @returns {number} next unsigned 32-bit int */
  nextUint32() {
    let x = this._state | 0;
    x ^= x << 13;
    x ^= x >>> 17;
    x ^= x << 5;
    this._state = x | 0;
    return x >>> 0;
  }
  /** @returns {number} float in [0, 1) */
  nextFloat() {
    return this.nextUint32() / 0x100000000;
  }
  /**
   * Uniform integer in [min, max] inclusive.
   * @param {number} min
   * @param {number} max
   * @returns {number}
   */
  nextIntInclusive(min, max) {
    if (max < min) return min;
    return min + (this.nextUint32() % (max - min + 1));
  }
  /**
   * Fisher-Yates partial shuffle — mutates `arr` in place and returns it.
   * @param {Array} arr
   */
  shuffleInPlace(arr) {
    for (let i = arr.length - 1; i > 0; i--) {
      const j = this.nextUint32() % (i + 1);
      const tmp = arr[i];
      arr[i] = arr[j];
      arr[j] = tmp;
    }
    return arr;
  }
}

/**
 * Look up the biome entry for a given biome id. Returns the parsed
 * .tres data bag (with natural_props resolved to flat JS objects) or
 * null if the biome doesn't exist or has no natural_props.
 * @param {string} biomeId
 * @param {Map<string, Object> | null} cache - optional biomeId → entry
 *   map built once per populate run; caller passes the result of
 *   _buildBiomeCache() so the per-tile sweep avoids repeatedly
 *   scanning ProjectContext.files.biomes (O(tiles × biomes) → O(tiles)).
 * @returns {Object|null}
 */
function _getBiomeWithNaturalProps(biomeId, cache) {
  if (!biomeId) return null;
  if (cache) return cache.get(biomeId) || null;
  // Uncached path — kept so ad-hoc callers (tests, future utilities)
  // don't have to build a cache.
  for (const [filename, entry] of ProjectContext.files.biomes) {
    const entryId = (entry.data && typeof entry.data.id === 'string' && entry.data.id) || filename.replace('.tres', '');
    if (entryId !== biomeId) continue;
    return entry;
  }
  return null;
}

/**
 * Build a biomeId → entry map from ProjectContext so the per-tile
 * sweep inside computePopulatePlan doesn't linear-scan the biome
 * table for every tile. On maps with thousands of tiles the previous
 * O(tiles × biomes) walk plus the nested _resolveNaturalProps
 * sub_resource dereference was the hottest path in Populate.
 * @returns {Map<string, Object>}
 */
function _buildBiomeCache() {
  const out = new Map();
  for (const [filename, entry] of ProjectContext.files.biomes) {
    const entryId = (entry.data && typeof entry.data.id === 'string' && entry.data.id) || filename.replace('.tres', '');
    out.set(entryId, entry);
  }
  return out;
}

/**
 * Extract the natural_props JS objects from a biome entry. The
 * biome-editor's fromEntry already flattens sub_resources, but the
 * ProjectContext holds the raw parsed data — so we need the same
 * dereferencing as BiomeDataModel.fromEntry to turn SubResource refs
 * into plain objects.
 * @param {Object} entry - ProjectContext biome entry
 * @returns {Array<Object>}
 */
function _resolveNaturalProps(entry) {
  if (!entry || !entry.data) return [];
  const refs = entry.data.natural_props;
  if (!Array.isArray(refs) || refs.length === 0) return [];
  // Handle Array[Resource]([...]) outer wrapping.
  let list = refs;
  if (list.length === 1 && list[0] && list[0].type === 'array' && Array.isArray(list[0].value)) {
    list = list[0].value;
  }
  const subMap = new Map();
  if (entry.raw && entry.raw.subResources) {
    for (const sub of entry.raw.subResources) {
      const subData = {};
      for (const [k, v] of sub.fields) subData[k] = v.value;
      subMap.set(sub.id, subData);
    }
  }
  const out = [];
  for (const ref of list) {
    let d = null;
    if (ref && typeof ref === 'object' && ref.type === 'sub_resource') {
      d = subMap.get(ref.value) || null;
    } else if (ref && typeof ref === 'object') {
      d = ref;
    }
    if (!d) continue;
    out.push({
      prop_id: typeof d.prop_id === 'string' ? d.prop_id : '',
      frequency: typeof d.frequency === 'number' ? d.frequency : 1.0,
      grouping_range: _v2iOrDefault(d.grouping_range, 1, 1),
      elevation_range: _v2iOrDefault(d.elevation_range, -100, 100),
      near_biomes: _stringArrayOrEmpty(d.near_biomes),
      not_near_biomes: _stringArrayOrEmpty(d.not_near_biomes),
      near_props: _stringArrayOrEmpty(d.near_props),
      not_near_props: _stringArrayOrEmpty(d.not_near_props),
    });
  }
  return out;
}

function _v2iOrDefault(v, dx, dy) {
  if (v && typeof v === 'object') {
    if (typeof v.x === 'number' && typeof v.y === 'number') return { x: v.x, y: v.y };
    if (v.value && typeof v.value.x === 'number') return { x: v.value.x, y: v.value.y };
  }
  return { x: dx, y: dy };
}

function _stringArrayOrEmpty(a) {
  if (!Array.isArray(a)) return [];
  let list = a;
  if (list.length === 1 && list[0] && list[0].type === 'array' && Array.isArray(list[0].value)) {
    list = list[0].value;
  }
  const out = [];
  for (const item of list) {
    if (typeof item === 'string') out.push(item);
    else if (item && typeof item === 'object' && typeof item.value === 'string') out.push(item.value);
  }
  return out;
}

/**
 * Read a PropDef's category string. Defaults to 'plant' when the
 * registry is silent so unknown props still get placed somewhere in
 * the sweep rather than being skipped.
 * @param {string} propId
 * @returns {string}
 */
function _propCategory(propId) {
  const entry = ProjectContext.files.props.get(propId + '.tres');
  if (!entry || !entry.data) return 'plant';
  const cat = entry.data.category;
  return (typeof cat === 'string' && cat.length > 0) ? cat : 'plant';
}

/**
 * Collect the neighbors of (q, r) that actually have tiles in the
 * grid. Neighbors off the map count as "no biome, no props".
 * @param {import('./hex-grid.js').HexGrid} grid
 * @param {number} q
 * @param {number} r
 * @returns {Array<{q: number, r: number, tile: Object}>}
 */
function _neighborsWithTiles(grid, q, r) {
  const out = [];
  for (const n of HexMath.getNeighbors(q, r)) {
    const tile = grid.getTile(n.q, n.r);
    if (tile) out.push({ q: n.q, r: n.r, tile });
  }
  return out;
}

/**
 * Check whether a BiomeProp entry's conditions all pass for a tile.
 * @param {Object} np - natural_props entry
 * @param {Object} tile
 * @param {Array<{q: number, r: number, tile: Object}>} neighbors
 * @param {number} q
 * @param {number} r
 * @returns {boolean}
 */
function _conditionsPass(np, tile, neighbors, q, r) {
  // elevation_range is inclusive.
  const elev = typeof tile.elevation === 'number' ? tile.elevation : 0;
  if (elev < np.elevation_range.x || elev > np.elevation_range.y) return false;

  // Slope filter — props set their max tolerated slope (in degrees) on
  // PlaceableCap.max_allowed_slope. 0 = flat only, 90 = anywhere.
  // Default 90 means no restriction. Loose rocks should use ~15, ground
  // cover / moss can stay at 90.
  const maxSlope = _propMaxSlope(np.prop_id);
  if (maxSlope < 90) {
    const tileSlopeDeg = _tileMaxSlopeDeg(tile, neighbors, q, r);
    if (tileSlopeDeg > maxSlope) return false;
  }

  if (np.near_biomes.length > 0) {
    const ok = neighbors.some(n => np.near_biomes.includes(n.tile.biome));
    if (!ok) return false;
  }
  if (np.not_near_biomes.length > 0) {
    const bad = neighbors.some(n => np.not_near_biomes.includes(n.tile.biome));
    if (bad) return false;
  }
  if (np.near_props.length > 0) {
    const ok = neighbors.some(n => Array.isArray(n.tile.props)
      && n.tile.props.some(p => np.near_props.includes(p.type)));
    if (!ok) return false;
  }
  if (np.not_near_props.length > 0) {
    const bad = neighbors.some(n => Array.isArray(n.tile.props)
      && n.tile.props.some(p => np.not_near_props.includes(p.type)));
    if (bad) return false;
  }
  return true;
}

/**
 * Read PlaceableCap.max_allowed_slope from the prop's .tres data.
 * Defaults to 90 when missing (permissive — old maps keep working).
 * @param {string} propId
 * @returns {number} degrees in [0, 90]
 */
function _propMaxSlope(propId) {
  const entry = ProjectContext.files.props.get(propId + '.tres');
  if (!entry || !entry.raw) return 90;
  const subs = entry.raw.subResources || [];
  for (const sub of subs) {
    for (const [field, data] of sub.fields) {
      if (field === 'max_allowed_slope' && data && typeof data.value === 'number') {
        return data.value;
      }
    }
  }
  return 90;
}

/**
 * Compute the steepest local slope angle (in degrees) for a tile.
 * Slope between the tile and each non-wall neighbor is approximated as
 * atan2(rise, run) where rise = |ΔelevationSteps| * ELEVATION_STEP and
 * run = distance between hex centers (flat-top hex, radius 1). Walls
 * are treated as cliffs (skipped) so cliff-adjacent flat-top tiles
 * still report slope 0.
 *
 * Table (for reference):
 *   diff 0 →  0°    diff 1 → 16°    diff 2 → 30°
 *   diff 3 → 41°    diff 4 → 49°    diff 6 → 60°
 *
 * @param {Object} tile
 * @param {Array<{q: number, r: number, tile: Object}>} neighbors
 * @param {number} selfQ
 * @param {number} selfR
 * @returns {number} degrees in [0, 90]
 */
function _tileMaxSlopeDeg(tile, neighbors, selfQ, selfR) {
  const selfElev = typeof tile.elevation === 'number' ? tile.elevation : 0;
  const walls = Array.isArray(tile.walls) ? tile.walls : [false, false, false, false, false, false];
  let maxDiff = 0;
  for (const n of neighbors) {
    const dirIdx = HexMath.DIRECTIONS.findIndex(d =>
      d.q === (n.q - selfQ) && d.r === (n.r - selfR)
    );
    if (dirIdx >= 0 && walls[dirIdx]) continue;  // cliff
    const nElev = typeof n.tile.elevation === 'number' ? n.tile.elevation : 0;
    const diff = Math.abs(nElev - selfElev);
    if (diff > maxDiff) maxDiff = diff;
  }
  if (maxDiff === 0) return 0;
  const ELEVATION_STEP = 0.5;
  const HEX_CENTER_DIST = Math.sqrt(3);  // flat-top hex, radius 1
  return Math.atan2(maxDiff * ELEVATION_STEP, HEX_CENTER_DIST) * 180 / Math.PI;
}

/**
 * Pick up to `count` unoccupied sub-hex positions for a tile.
 * Occupancy is drawn from the tile's current props; the returned
 * positions are guaranteed unique and valid.
 *
 * Algorithm: shuffle the 19 candidate positions with the seeded
 * RNG, then walk in order skipping anything taken. Cheaper than
 * retry-on-collision and deterministic for the same seed.
 *
 * @param {Object} tile
 * @param {number} count
 * @param {SeededRng} rng
 * @returns {Array<{sq: number, sr: number}>}
 */
function _pickFreeSubHexes(tile, count, rng) {
  const taken = new Set();
  if (Array.isArray(tile.props)) {
    for (const p of tile.props) taken.add(`${p.sq ?? 0},${p.sr ?? 0}`);
  }
  const candidates = HexMath.VALID_SUB_HEXES.map(s => ({ sq: s.q, sr: s.r }));
  rng.shuffleInPlace(candidates);
  const out = [];
  for (const c of candidates) {
    if (out.length >= count) break;
    const key = `${c.sq},${c.sr}`;
    if (taken.has(key)) continue;
    taken.add(key);
    out.push(c);
  }
  return out;
}

/**
 * Planning output from computePopulatePlan. Consumers (UI preview +
 * applyPopulatePlan) both read from this shape.
 * @typedef {Object} PopulatePlan
 * @property {Array<{
 *   q: number, r: number, sq: number, sr: number,
 *   type: string, category: string,
 * }>} props
 * @property {Array<{q: number, r: number, propIndex: number, prop: Object}>} removed
 * @property {Map<string, number>} countByType   // prop_id → count
 * @property {number} seed
 * @property {number} touchedTiles
 */

/**
 * Build a populate plan WITHOUT mutating the grid. Returns the list
 * of AddProp intents plus summary stats the dialog shows before the
 * user hits Apply.
 *
 * @param {import('./hex-grid.js').HexGrid} grid
 * @param {Object} [opts]
 * @param {boolean} [opts.replace=false] - When true, existing natural
 *   props on each tile are cleared before rolling new ones.
 * @param {number} [opts.seed] - 32-bit seed. Defaults to the map's
 *   generator seed if present, else a timestamp.
 * @returns {PopulatePlan}
 */
export function computePopulatePlan(grid, opts) {
  const options = opts || {};
  const replace = !!options.replace;
  const seedSource = Number.isFinite(options.seed)
    ? options.seed
    : (grid.meta && grid.meta.generator && Number.isFinite(grid.meta.generator.seed)
      ? grid.meta.generator.seed
      : Date.now() & 0x7fffffff);
  const rng = new SeededRng(seedSource);

  /** @type {PopulatePlan['props']} */
  const props = [];
  /** @type {PopulatePlan['removed']} */
  const removed = [];
  const countByType = new Map();

  // Snapshot of tile props we'll mutate in planning so near_props
  // checks see both pre-existing props and props added earlier in
  // the sweep. We never touch the real grid here.
  /** @type {Map<string, {biome: string, elevation: number, props: Array<Object>}>} */
  const shadow = new Map();
  for (const [key, tile] of grid.getAllTiles()) {
    const existing = Array.isArray(tile.props) ? tile.props : [];
    let kept = existing;
    if (replace) {
      // Drop natural-origin props so populate gets a clean slate;
      // structures, equipment, etc. stay put. q/r come from the key
      // parse below — keeping them off `dropped` avoids a dead field
      // that earlier encoded `tile ? null : 0` for an impossible
      // "tile is null" case (tile is the iteration value and always
      // truthy inside a Map for-of).
      const dropped = [];
      kept = [];
      for (let i = 0; i < existing.length; i++) {
        const p = existing[i];
        const originIsNatural = (typeof p.origin === 'string' && p.origin === 'natural')
          || (typeof p.origin === 'number' && p.origin === 0);
        if (originIsNatural) {
          dropped.push({ propIndex: i, prop: p });
        } else {
          kept.push(p);
        }
      }
      // removed[] gets real (q,r) from the key; splice indices here
      // are against the pre-existing array. We use a reverse-delete
      // trick when applying so indices stay valid.
      const { q, r } = _parseKey(key);
      for (const d of dropped) removed.push({ q, r, propIndex: d.propIndex, prop: d.prop });
    }
    shadow.set(key, {
      biome: tile.biome || '',
      elevation: typeof tile.elevation === 'number' ? tile.elevation : 0,
      props: [...kept],
    });
  }

  // Shadow helpers that look like grid.getTile / getNeighbors but
  // read from `shadow` so mid-sweep additions are visible.
  const shadowGet = (q, r) => shadow.get(`${q},${r}`) || null;
  const shadowNeighbors = (q, r) => {
    const out = [];
    for (const n of HexMath.getNeighbors(q, r)) {
      const s = shadowGet(n.q, n.r);
      if (s) out.push({ q: n.q, r: n.r, tile: s });
    }
    return out;
  };

  // Tile sweep, one category at a time. For each category pass we
  // iterate tiles in key order (deterministic).
  const tileKeys = [...shadow.keys()].sort();
  const touchedTiles = new Set();

  // Build the biome cache once so the per-tile lookup below is O(1)
  // instead of linear-scanning ProjectContext.files.biomes each time.
  // Also memoize _resolveNaturalProps per biomeId — the sub_resource
  // deref work is non-trivial and the biome set is small + reused
  // across every tile that shares a biome.
  const biomeCache = _buildBiomeCache();
  /** @type {Map<string, Array<Object>>} */
  const naturalPropsCache = new Map();
  const resolveCached = (biomeId, entry) => {
    if (naturalPropsCache.has(biomeId)) return naturalPropsCache.get(biomeId);
    const list = _resolveNaturalProps(entry);
    naturalPropsCache.set(biomeId, list);
    return list;
  };

  for (const category of CATEGORY_ORDER) {
    for (const key of tileKeys) {
      const { q, r } = _parseKey(key);
      const stile = shadow.get(key);
      if (!stile) continue;
      const biomeEntry = _getBiomeWithNaturalProps(stile.biome, biomeCache);
      if (!biomeEntry) continue;
      const naturalProps = resolveCached(stile.biome, biomeEntry);
      if (naturalProps.length === 0) continue;

      const neighbors = shadowNeighbors(q, r);
      // Bucket entries for this category.
      const bucket = naturalProps.filter(np => _propCategory(np.prop_id) === category);
      if (bucket.length === 0) continue;

      for (const np of bucket) {
        if (!_conditionsPass(np, stile, neighbors, q, r)) continue;
        const roll = rng.nextFloat();
        if (roll >= np.frequency) continue;

        const countMin = Math.max(1, np.grouping_range.x | 0);
        const countMax = Math.max(countMin, np.grouping_range.y | 0);
        const n = rng.nextIntInclusive(countMin, countMax);
        const positions = _pickFreeSubHexes(stile, n, rng);
        for (const pos of positions) {
          props.push({ q, r, sq: pos.sq, sr: pos.sr, type: np.prop_id, category });
          // Add to the shadow so later near_props checks see it.
          stile.props.push({ type: np.prop_id, sq: pos.sq, sr: pos.sr, origin: 'natural' });
          touchedTiles.add(key);
          countByType.set(np.prop_id, (countByType.get(np.prop_id) || 0) + 1);
        }
      }
    }
  }

  return {
    props,
    removed,
    countByType,
    seed: seedSource,
    touchedTiles: touchedTiles.size,
  };
}

/**
 * Convert a planned set of adds + removes into a BatchCommand and
 * execute it through the supplied CommandHistory. Callers (UI) are
 * responsible for calling `cmdHistory.execute(cmd)` only when the
 * user has confirmed.
 *
 * Removal commands are emitted in descending propIndex order so
 * splicing indices stay valid during execute AND undo restores them
 * to the same slots.
 *
 * @param {import('./hex-grid.js').HexGrid} grid
 * @param {PopulatePlan} plan
 * @returns {BatchCommand}
 */
export function buildPopulateCommand(grid, plan) {
  const commands = [];

  // Removes first, descending by (tile, propIndex), so earlier splices
  // don't shift the indices of the ones that still need to run.
  const removedSorted = [...plan.removed].sort((a, b) => {
    const ka = `${a.q},${a.r}`;
    const kb = `${b.q},${b.r}`;
    if (ka !== kb) return ka < kb ? -1 : 1;
    return b.propIndex - a.propIndex;
  });
  for (const rem of removedSorted) {
    commands.push(new DeletePropCommand(grid, rem.q, rem.r, rem.propIndex, rem.prop));
  }

  // Then adds — category-grouped for readability, though order
  // within the batch is irrelevant for the grid state.
  for (const p of plan.props) {
    const prop = createProp(p.type, p.sq, p.sr, p.category, { origin: 'natural' });
    commands.push(new AddPropCommand(grid, p.q, p.r, prop));
  }

  const batch = new BatchCommand(commands);
  batch.type = 'Populate';
  return batch;
}

/**
 * Parse an "x,y" hex key back to integers. Mirrors HexGrid.parseKey
 * but inlined here so callers don't have to import the class.
 * @param {string} key
 * @returns {{q: number, r: number}}
 */
function _parseKey(key) {
  const [qs, rs] = key.split(',');
  return { q: parseInt(qs, 10), r: parseInt(rs, 10) };
}

/**
 * @typedef {Object} ClearNaturalsPlan
 * @property {Array<{q:number,r:number,propIndex:number,prop:Object}>} removed
 * @property {Map<string, number>} countByType  — prop_id → count removed
 * @property {number} touchedTiles              — unique tiles with removals
 */

/**
 * Walk every tile and build a plan that removes ALL natural-origin
 * props (origin === 'natural' OR origin === 0). Player-crafted
 * structures, anomalies, and equipment stay put — the origin check
 * is the sole filter. Does not mutate the grid; consumer passes
 * the plan to buildClearNaturalsCommand().
 *
 * Mirrors the "replace" branch inside computePopulatePlan, minus the
 * add sweep. Kept as a standalone function so the Clear button can
 * ship without coupling its UI to the populate dialog.
 * @param {import('./hex-grid.js').HexGrid} grid
 * @returns {ClearNaturalsPlan}
 */
export function computeClearNaturalsPlan(grid) {
  /** @type {ClearNaturalsPlan['removed']} */
  const removed = [];
  /** @type {Map<string, number>} */
  const countByType = new Map();
  const touchedTiles = new Set();

  for (const [key, tile] of grid.getAllTiles()) {
    const existing = Array.isArray(tile.props) ? tile.props : [];
    if (existing.length === 0) continue;
    const { q, r } = _parseKey(key);
    for (let i = 0; i < existing.length; i++) {
      const p = existing[i];
      // Andre's rule: anomalies are NEVER natural. The legacy JSON
      // loader now tags them origin='crafted', but defend here too in
      // case a map saved with the old loader is still in memory.
      if (p.category === 'anomaly') continue;
      const originIsNatural = (typeof p.origin === 'string' && p.origin === 'natural')
        || (typeof p.origin === 'number' && p.origin === 0);
      if (!originIsNatural) continue;
      removed.push({ q, r, propIndex: i, prop: p });
      touchedTiles.add(key);
      const t = p.type || '(unknown)';
      countByType.set(t, (countByType.get(t) || 0) + 1);
    }
  }

  return { removed, countByType, touchedTiles: touchedTiles.size };
}

/**
 * Convert a ClearNaturalsPlan into a BatchCommand that removes every
 * planned prop. Removes are emitted in descending (tile, propIndex)
 * order so splicing indices stay valid during execute, and undo
 * restores each prop to its original slot.
 * @param {import('./hex-grid.js').HexGrid} grid
 * @param {ClearNaturalsPlan} plan
 * @returns {BatchCommand}
 */
export function buildClearNaturalsCommand(grid, plan) {
  const commands = [];
  const sorted = [...plan.removed].sort((a, b) => {
    const ka = `${a.q},${a.r}`;
    const kb = `${b.q},${b.r}`;
    if (ka !== kb) return ka < kb ? -1 : 1;
    return b.propIndex - a.propIndex;
  });
  for (const rem of sorted) {
    commands.push(new DeletePropCommand(grid, rem.q, rem.r, rem.propIndex, rem.prop));
  }
  const batch = new BatchCommand(commands);
  batch.type = 'ClearNaturals';
  return batch;
}
