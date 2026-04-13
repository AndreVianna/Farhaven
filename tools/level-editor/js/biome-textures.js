// ============================================================
// biome-textures.js — runtime-matching terrain texture preview
// ============================================================
//
// Mirrors `HexGridRenderer._pick_variation_idx` and
// `_pick_rotation_radians` from `scenes/world/hex_grid_renderer.gd` so
// the editor's "Texture" preview shows each hex with the same texture
// + rotation it will get in-game. Uses BigInt for hashing because the
// runtime hash multiplies 64-bit ints; Math.imul truncates to int32
// and would diverge for coords past ~30.

import { ProjectContext } from './file-discovery.js';

const VAR_PRIME_X = 73856093n;
const VAR_PRIME_Y = 19349663n;
const ROT_PRIME_X = 374761393n;
const ROT_PRIME_Y = 668265263n;

function _absBigInt(n) { return n < 0n ? -n : n; }

/**
 * Variation index in [0, n). Matches GDScript:
 *   absi((x * 73856093) ^ (y * 19349663)) % n
 * @param {number} q
 * @param {number} r
 * @param {number} n
 * @returns {number}
 */
export function pickVariationIdx(q, r, n) {
  if (n <= 0) return 0;
  const h = (BigInt(q) * VAR_PRIME_X) ^ (BigInt(r) * VAR_PRIME_Y);
  return Number(_absBigInt(h) % BigInt(n));
}

/**
 * Rotation in radians (one of 0, π/2, π, 3π/2). Matches GDScript:
 *   (absi((x * 374761393) ^ (y * 668265263)) % 4) * (PI / 2)
 * @param {number} q
 * @param {number} r
 * @returns {number}
 */
export function pickRotationRadians(q, r) {
  const h = (BigInt(q) * ROT_PRIME_X) ^ (BigInt(r) * ROT_PRIME_Y);
  return Number(_absBigInt(h) % 4n) * (Math.PI / 2);
}

// ============================================================
// Texture loader / cache
// ============================================================

/** @type {Map<string, Promise<HTMLImageElement[]>>} biome stem -> textures */
const _textureCache = new Map();

/**
 * Convert a `res://...` path the .tres file declares into the
 * `/api/asset?path=...` URL the dev server can serve.
 */
function _resPathToAssetUrl(resPath) {
  const stripped = resPath.replace(/^res:\/\//, '');
  return `/api/asset?path=${encodeURIComponent(stripped)}`;
}

/**
 * Pull the `path="res://..."` field out of an `[ext_resource ...]`
 * line. Returns null if the line doesn't look like one.
 */
function _extractExtResourcePath(line) {
  const m = /\bpath="([^"]+)"/.exec(line);
  return m ? m[1] : null;
}

/**
 * Pull the `id="..."` field out of an `[ext_resource ...]` line.
 */
function _extractExtResourceId(line) {
  const m = /\bid="([^"]+)"/.exec(line);
  return m ? m[1] : null;
}

/**
 * Pull the inner ID from an ExtResource("foo") string the parser
 * stores inside terrain_textures entries.
 */
function _extractRefId(refStr) {
  const m = /ExtResource\("([^"]+)"\)/.exec(refStr);
  return m ? m[1] : null;
}

/**
 * Returns a Promise resolving to the array of HTMLImageElement
 * variations for a biome (filename stem like 'B00002'), or [] if the
 * biome has no terrain_textures or any image fails to load.
 *
 * Uses a per-biome cache so toggling Color/Texture in the editor only
 * pays the network cost on the first switch.
 *
 * @param {string} biomeStem
 * @returns {Promise<HTMLImageElement[]>}
 */
export function loadBiomeTextures(biomeStem) {
  if (_textureCache.has(biomeStem)) {
    return _textureCache.get(biomeStem);
  }

  const promise = (async () => {
    const filename = `${biomeStem}.tres`;
    const entry = ProjectContext.files.biomes.get(filename);
    if (!entry || !entry.raw) return [];

    // Build id -> path map from the raw [ext_resource ...] lines.
    const idToPath = new Map();
    for (const line of entry.raw.extResources || []) {
      const id = _extractExtResourceId(line);
      const path = _extractExtResourcePath(line);
      if (id && path) idToPath.set(id, path);
    }

    // entry.data.terrain_textures is the parser's representation of the
    // .tres array. Each item is a TresValue with type 'ext_resource' and
    // value 'ExtResource("ID")', OR a plain string fallback.
    const arr = (entry.data && entry.data.terrain_textures) || [];
    if (!Array.isArray(arr) || arr.length === 0) return [];

    const refStrings = arr.map((tv) => {
      if (tv && typeof tv === 'object' && tv.type === 'ext_resource') return tv.value;
      if (typeof tv === 'string') return tv;
      return null;
    }).filter(Boolean);

    const paths = refStrings.map((s) => {
      const id = _extractRefId(s);
      return id ? idToPath.get(id) : null;
    }).filter(Boolean);

    if (paths.length === 0) return [];

    const images = await Promise.all(paths.map((p) => new Promise((resolve) => {
      const img = new Image();
      img.onload = () => resolve(img);
      img.onerror = () => {
        console.warn(`biome-textures: failed to load ${p}`);
        resolve(null);
      };
      img.src = _resPathToAssetUrl(p);
    })));

    return images.filter(Boolean);
  })();

  _textureCache.set(biomeStem, promise);
  return promise;
}

/**
 * Drop every cached texture promise. Call after biomes are reloaded
 * so the next render rebuilds the cache from fresh data.
 */
export function clearBiomeTextureCache() {
  _textureCache.clear();
}
