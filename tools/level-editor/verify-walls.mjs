/**
 * Wall consistency checker.
 * Verifies that for every shared edge between two hexes,
 * tile.walls[d] matches neighbor.walls[opposite_d].
 *
 * Usage: node tools/level-editor/verify-walls.mjs data/maps/<map.json>
 */

import { readFileSync } from 'fs';

const DIRECTIONS = [
  { q: 1, r: 0 },   // 0: E
  { q: 1, r: -1 },  // 1: NE
  { q: 0, r: -1 },  // 2: NW
  { q: -1, r: 0 },  // 3: W
  { q: -1, r: 1 },  // 4: SW
  { q: 0, r: 1 },   // 5: SE
];

const DIR_NAMES = ['E', 'NE', 'NW', 'W', 'SW', 'SE'];

const file = process.argv[2];
if (!file) {
  console.error('Usage: node tools/level-editor/verify-walls.mjs data/maps/<map.json>');
  process.exit(1);
}

const map = JSON.parse(readFileSync(file, 'utf-8'));
const tiles = map.tiles || {};
let errors = 0;
let checked = 0;
let missingWalls = 0;

for (const [key, tile] of Object.entries(tiles)) {
  if (!tile.walls || tile.walls.length !== 6) {
    missingWalls++;
    continue;
  }

  const [q, r] = key.split(',').map(Number);

  for (let d = 0; d < 6; d++) {
    const nq = q + DIRECTIONS[d].q;
    const nr = r + DIRECTIONS[d].r;
    const nk = `${nq},${nr}`;
    const neighbor = tiles[nk];
    if (!neighbor) continue;
    if (!neighbor.walls || neighbor.walls.length !== 6) continue;

    checked++;
    const opposite = (d + 3) % 6;

    if (tile.walls[d] !== neighbor.walls[opposite]) {
      errors++;
      console.log(
        `MISMATCH: (${q},${r}).walls[${d}/${DIR_NAMES[d]}]=${tile.walls[d]}` +
        ` vs (${nq},${nr}).walls[${opposite}/${DIR_NAMES[opposite]}]=${neighbor.walls[opposite]}` +
        ` | elevations: ${tile.elevation} vs ${neighbor.elevation}`
      );
    }
  }
}

console.log(`\nChecked ${checked} shared edges.`);
console.log(`${errors} mismatches found.`);
if (missingWalls > 0) console.log(`${missingWalls} tiles missing walls field.`);
process.exit(errors > 0 ? 1 : 0);
