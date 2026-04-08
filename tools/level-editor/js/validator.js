// ============================================================
// MapValidator — Pre-save validation (G1)
// ============================================================

import { HexMath } from './hex-math.js';
import { HexGrid, CATEGORIES, ORIGINS, CATEGORY_TO_INT } from './hex-grid.js';

/**
 * @typedef {Object} ValidationError
 * @property {number[]} hex - [q, r] coordinates of the tile (empty for global errors)
 * @property {string} field - Field name that failed validation
 * @property {string} message - Human-readable error message
 */

/**
 * Validate a HexGrid map before export/save.
 * @param {import('./hex-grid.js').HexGrid} hexGrid
 * @param {Set<string>} knownBiomes - Set of known biome names (without .tres extension)
 * @param {Set<string>} knownResources - Set of known resource names (without .tres extension)
 * @returns {{ valid: boolean, errors: ValidationError[] }}
 */
export function validateMap(hexGrid, knownBiomes, knownResources) {
  /** @type {ValidationError[]} */
  const errors = [];

  // Check spawn point exists and references an existing tile
  const spawn = hexGrid.meta.spawn;
  if (!Array.isArray(spawn) || spawn.length < 2) {
    errors.push({ hex: [], field: 'spawn', message: 'Spawn point is not defined.' });
  } else if (!hexGrid.hasTile(spawn[0], spawn[1])) {
    errors.push({ hex: [spawn[0], spawn[1]], field: 'spawn', message: `spawn point does not reference an existing tile.` });
  }

  for (const [key, tile] of hexGrid.getAllTiles()) {
    const { q, r } = HexGrid.parseKey(key);

    // Validate biome is known (allow empty biome for ghost/unset tiles)
    if (tile.biome && knownBiomes.size > 0 && !knownBiomes.has(tile.biome)) {
      errors.push({ hex: [q, r], field: 'biome', message: `unknown biome "${tile.biome}".` });
    }

    // Validate elevation range
    if (typeof tile.elevation !== 'number' || !Number.isInteger(tile.elevation) || tile.elevation < -32000 || tile.elevation > 32000) {
      errors.push({ hex: [q, r], field: 'elevation', message: `elevation ${tile.elevation} out of range -32000..32000.` });
    }

    if (!tile.props) continue;

    // Track occupied sub-hex positions for overlap detection
    /** @type {Set<string>} */
    const occupiedSubHexes = new Set();

    for (let i = 0; i < tile.props.length; i++) {
      const prop = tile.props[i];

      // Validate category is known
      if (!CATEGORIES.includes(prop.category)) {
        errors.push({ hex: [q, r], field: `props[${i}].category`, message: `unknown category "${prop.category}".` });
      }

      // Validate origin is known (if present)
      if (prop.origin != null && typeof prop.origin === 'string' && !ORIGINS.includes(prop.origin)) {
        errors.push({ hex: [q, r], field: `props[${i}].origin`, message: `unknown origin "${prop.origin}".` });
      }

      // Validate rotation range (all categories)
      if (typeof prop.rotation === 'number') {
        if (prop.rotation < 0 || prop.rotation >= 360) {
          errors.push({ hex: [q, r], field: `props[${i}].rotation`, message: `rotation ${prop.rotation} outside range [0, 360).` });
        }
      }

      // Validate sub-hex position
      if (!HexMath.isValidSubHex(prop.sq, prop.sr)) {
        errors.push({ hex: [q, r], field: `props[${i}].subhex`, message: `sub-hex (${prop.sq},${prop.sr}) is invalid (distance > 2).` });
      }

      // Check for overlapping props on same sub-hex
      if (prop.footprint && Array.isArray(prop.footprint)) {
        for (const cell of prop.footprint) {
          // Validate each footprint cell is a valid sub-hex
          if (!HexMath.isValidSubHex(cell.q, cell.r)) {
            errors.push({ hex: [q, r], field: `props[${i}].footprint`, message: `footprint cell (${cell.q},${cell.r}) is invalid (distance > 2).` });
          }
          const cellKey = `${cell.q},${cell.r}`;
          if (occupiedSubHexes.has(cellKey)) {
            errors.push({ hex: [q, r], field: `props[${i}].footprint`, message: `overlapping prop at sub-hex (${cell.q},${cell.r}).` });
          }
          occupiedSubHexes.add(cellKey);
        }
      } else {
        // Single-cell prop: use anchor position
        const cellKey = `${prop.sq},${prop.sr}`;
        if (occupiedSubHexes.has(cellKey)) {
          errors.push({ hex: [q, r], field: `props[${i}].subhex`, message: `overlapping prop at sub-hex (${prop.sq},${prop.sr}).` });
        }
        occupiedSubHexes.add(cellKey);
      }
    }
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}
