/* ============================================================
 * Farhaven Editor — Cross-Reference Index (Phase 4)
 *
 * Scans ProjectContext (maps + biomes) once and precomputes:
 *   - biome → list of maps + tile counts ("Used In")
 *   - prop  → list of biomes + spawn frequency ("Drop Sources")
 *
 * Pure functions + a factory `buildReferenceIndex` that caches
 * results. Editors consume via `refIndex.forBiome(id)` /
 * `refIndex.forProp(id)`.
 *
 * All computation is client-side — current data sizes are ~1ms.
 * ============================================================ */

import { ProjectContext } from './file-discovery.js';

/**
 * @typedef {Object} BiomeUsage
 * @property {string} mapId        - filename stem (e.g. "ch1")
 * @property {string} mapName      - display name if present, else mapId
 * @property {number} tileCount    - number of tiles with this biome
 */

/**
 * @typedef {Object} PropDropSource
 * @property {string} biomeId
 * @property {string} biomeName
 * @property {string} biomeColor   - CSS color (for swatch), may be ''
 * @property {number} frequency    - 0..1 from biome.natural_props[n].frequency
 * @property {number[]} groupRange - [min, max] from grouping_range.x / .y
 */

/**
 * Count biome usage across all loaded maps.
 * @param {string} biomeId
 * @returns {BiomeUsage[]}
 */
export function computeBiomeUsedIn(biomeId) {
  const out = [];
  if (!biomeId) return out;
  for (const [filename, entry] of ProjectContext.files.maps) {
    const data = entry && entry.data;
    if (!data) continue;
    const mapId = filename.replace(/\.json$/i, '');
    const mapName = (data.name || data.chapter_id || mapId);
    let tileCount = 0;
    const tiles = data.tiles || {};
    for (const key in tiles) {
      const t = tiles[key];
      if (t && t.biome === biomeId) tileCount++;
    }
    if (tileCount > 0) out.push({ mapId, mapName, tileCount });
  }
  out.sort((a, b) => b.tileCount - a.tileCount);
  return out;
}

/**
 * Find biomes that spawn a given prop via their natural_props list.
 * @param {string} propId
 * @returns {PropDropSource[]}
 */
export function computePropDropSources(propId) {
  const out = [];
  if (!propId) return out;
  for (const [filename, entry] of ProjectContext.files.biomes) {
    const data = entry && entry.data;
    if (!data) continue;
    const biomeId = filename.replace(/\.tres$/i, '');
    const biomeName = data.display_name || data.id || biomeId;
    const naturals = _resolveNaturalProps(entry);
    for (const np of naturals) {
      if (np.prop_id !== propId) continue;
      const freq = typeof np.frequency === 'number' ? np.frequency : 0;
      const gr = np.grouping_range || { x: 1, y: 1 };
      out.push({
        biomeId,
        biomeName,
        biomeColor: _biomeColorCss(data.color),
        frequency: freq,
        groupRange: [gr.x | 0 || 1, gr.y | 0 || 1],
      });
    }
  }
  out.sort((a, b) => b.frequency - a.frequency);
  return out;
}

/**
 * Build a reference index with cached lookups. Call once after
 * ProjectContext has loaded, and again whenever a save mutates
 * maps or biomes.
 *
 * @returns {{
 *   forBiome: (biomeId: string) => BiomeUsage[],
 *   forProp: (propId: string) => PropDropSource[],
 *   rebuild: () => void
 * }}
 */
export function buildReferenceIndex() {
  /** @type {Map<string, BiomeUsage[]>} */
  const biomeCache = new Map();
  /** @type {Map<string, PropDropSource[]>} */
  const propCache = new Map();

  function forBiome(biomeId) {
    if (!biomeCache.has(biomeId)) {
      biomeCache.set(biomeId, computeBiomeUsedIn(biomeId));
    }
    return biomeCache.get(biomeId);
  }

  function forProp(propId) {
    if (!propCache.has(propId)) {
      propCache.set(propId, computePropDropSources(propId));
    }
    return propCache.get(propId);
  }

  function rebuild() {
    biomeCache.clear();
    propCache.clear();
  }

  return { forBiome, forProp, rebuild };
}

// ---- Internals ---------------------------------------------------------

function _biomeColorCss(color) {
  if (!color) return '';
  if (typeof color === 'string') return color;
  if (typeof color === 'object' && 'r' in color) {
    const r = Math.round((color.r || 0) * 255);
    const g = Math.round((color.g || 0) * 255);
    const b = Math.round((color.b || 0) * 255);
    return `rgb(${r},${g},${b})`;
  }
  return '';
}

/**
 * Extract natural_props entries from a biome .tres entry, resolving
 * sub_resource references. Mirrors the dereffing logic in populate.js
 * but inlined here so cross-refs doesn't depend on populate.
 * @param {Object} entry
 * @returns {Array<{prop_id: string, frequency: number, grouping_range: {x:number,y:number}}>}
 */
function _resolveNaturalProps(entry) {
  if (!entry || !entry.data) return [];
  const refs = entry.data.natural_props;
  if (!Array.isArray(refs) || refs.length === 0) return [];
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
    let obj = null;
    if (ref && ref.type === 'sub_resource' && typeof ref.value === 'string') {
      obj = subMap.get(ref.value);
    } else if (ref && typeof ref === 'object' && ref.prop_id) {
      obj = ref;
    }
    if (!obj) continue;
    const propId = String(obj.prop_id || '');
    if (!propId) continue;
    out.push({
      prop_id: propId,
      frequency: typeof obj.frequency === 'number' ? obj.frequency : 0,
      grouping_range: obj.grouping_range || { x: 1, y: 1 },
    });
  }
  return out;
}

/**
 * Render a reference panel into an existing container. The panel
 * shows the section title + either a list of rows or an empty state.
 *
 * Shared renderer used by biome-editor.js ("Used In") and
 * prop-editor.js ("Drop Sources").
 *
 * @param {HTMLElement} container
 * @param {string} title - e.g. "USED IN" or "DROP SOURCES"
 * @param {Array<{swatch?: string, label: string, sub?: string, meta?: string}>} rows
 * @param {string} emptyText
 */
export function renderRefPanel(container, title, rows, emptyText) {
  container.innerHTML = '';
  const t = document.createElement('div');
  t.className = 'section-title';
  t.textContent = title;
  container.appendChild(t);
  if (!rows || rows.length === 0) {
    const empty = document.createElement('div');
    empty.style.cssText = 'color:var(--text-2);font-size:11px;padding:8px 2px;';
    empty.textContent = emptyText;
    container.appendChild(empty);
    return;
  }
  for (const row of rows) {
    const el = document.createElement('div');
    el.style.cssText = 'display:flex;align-items:center;gap:8px;padding:5px 2px;font-size:11.5px;color:var(--text-1);';
    if (row.swatch) {
      const sw = document.createElement('span');
      sw.style.cssText = `width:12px;height:12px;border-radius:3px;background:${row.swatch};border:1px solid rgba(0,0,0,0.3);flex-shrink:0;`;
      el.appendChild(sw);
    }
    const name = document.createElement('span');
    name.style.cssText = 'flex:1;color:var(--text-0);';
    name.textContent = row.label;
    el.appendChild(name);
    if (row.meta) {
      const m = document.createElement('span');
      m.style.cssText = 'font-family:var(--font-mono);font-size:10.5px;color:var(--text-2);';
      m.textContent = row.meta;
      el.appendChild(m);
    }
    container.appendChild(el);
    if (row.sub) {
      const s = document.createElement('div');
      s.style.cssText = 'font-family:var(--font-mono);font-size:10px;color:var(--text-2);padding:0 0 4px 20px;';
      s.textContent = row.sub;
      container.appendChild(s);
    }
  }
}
