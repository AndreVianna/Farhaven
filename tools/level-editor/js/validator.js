// ============================================================
// MapValidator — Pre-save validation (G1)
// ============================================================

import { HexMath } from './hex-math.js';

/**
 * Validate a HexGrid map before export/save.
 * @param {import('./hex-grid.js').HexGrid} hexGrid
 * @param {Set<string>} knownBiomes - Set of known biome names (without .tres extension)
 * @param {Set<string>} knownResources - Set of known resource names (without .tres extension)
 * @returns {{ valid: boolean, errors: string[] }}
 */
export function validateMap(hexGrid, knownBiomes, knownResources) {
  const errors = [];

  // Check spawn point exists and references an existing tile
  const spawn = hexGrid.meta.spawn;
  if (!Array.isArray(spawn) || spawn.length < 2) {
    errors.push('Spawn point is not defined.');
  } else if (!hexGrid.hasTile(spawn[0], spawn[1])) {
    errors.push(`Spawn point (${spawn[0]}, ${spawn[1]}) does not reference an existing tile.`);
  }

  for (const [key, tile] of hexGrid.getAllTiles()) {
    const parts = key.split(',');
    const q = parseInt(parts[0], 10);
    const r = parseInt(parts[1], 10);
    const prefix = `Tile (${q},${r})`;

    // Validate biome is known (allow empty biome for ghost/unset tiles)
    if (tile.biome && knownBiomes.size > 0 && !knownBiomes.has(tile.biome)) {
      errors.push(`${prefix}: unknown biome "${tile.biome}".`);
    }

    // Validate elevation range
    if (typeof tile.elevation !== 'number' || tile.elevation < 0 || tile.elevation > 9) {
      errors.push(`${prefix}: elevation ${tile.elevation} out of range 0-9.`);
    }

    if (!tile.props) continue;

    // Track occupied sub-hex positions for overlap detection
    /** @type {Set<string>} */
    const occupiedSubHexes = new Set();

    for (let i = 0; i < tile.props.length; i++) {
      const prop = tile.props[i];
      const propLabel = `${prefix} prop[${i}] "${prop.type}"`;

      // Validate prop type exists in known definitions for its category
      if (prop.category === 'resource' && knownResources.size > 0 && !knownResources.has(prop.type)) {
        errors.push(`${propLabel}: unknown resource type.`);
      }

      // Validate sub-hex position
      if (!HexMath.isValidSubHex(prop.sq, prop.sr)) {
        errors.push(`${propLabel}: sub-hex (${prop.sq},${prop.sr}) is invalid (distance > 2).`);
      }

      // Check for overlapping props on same sub-hex
      if (prop.footprint && Array.isArray(prop.footprint)) {
        for (const cell of prop.footprint) {
          // Validate each footprint cell is a valid sub-hex
          if (!HexMath.isValidSubHex(cell.q, cell.r)) {
            errors.push(`${propLabel}: footprint cell (${cell.q},${cell.r}) is invalid (distance > 2).`);
          }
          const cellKey = `${cell.q},${cell.r}`;
          if (occupiedSubHexes.has(cellKey)) {
            errors.push(`${propLabel}: overlapping prop at sub-hex (${cell.q},${cell.r}).`);
          }
          occupiedSubHexes.add(cellKey);
        }
      } else {
        // Single-cell prop: use anchor position
        const cellKey = `${prop.sq},${prop.sr}`;
        if (occupiedSubHexes.has(cellKey)) {
          errors.push(`${propLabel}: overlapping prop at sub-hex (${prop.sq},${prop.sr}).`);
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
