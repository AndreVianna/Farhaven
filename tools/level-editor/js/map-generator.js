// ============================================================
// map-generator.js — Procedural hex map generation
// ============================================================
//
// Generates a hex map using layered Simplex noise + biome rules.
// Produces a map JSON object compatible with loadMapIntoGrid().

'use strict';

import { createNoise2D } from './simplex-noise.js';
import { HexMath } from './hex-math.js';
import { ProjectContext } from './file-discovery.js';
import { showInlineFormModal } from './panels.js';

// ============================================================
// Hex coordinate iteration
// ============================================================

/**
 * Yield all axial (q, r) coordinates within a hex-shaped region
 * of the given radius centered at (0, 0).
 * @param {number} radius
 * @returns {Array<{q: number, r: number}>}
 */
function hexesInRadius(radius) {
  const coords = [];
  for (let q = -radius; q <= radius; q++) {
    const r1 = Math.max(-radius, -q - radius);
    const r2 = Math.min(radius, -q + radius);
    for (let r = r1; r <= r2; r++) {
      coords.push({ q, r });
    }
  }
  return coords;
}

// ============================================================
// Biome assignment
// ============================================================

/**
 * @typedef {Object} GenOptions
 * @property {number} radius - Map radius in hexes
 * @property {number} seed - Random seed
 * @property {number} waterPct - Percentage of tiles that become water (0-100)
 * @property {number} forestPct - Percentage of land tiles that become forest (0-100)
 * @property {number} rockyPct - Percentage of land tiles that become rocky (0-100)
 * @property {number} frequency - Noise frequency (lower = larger features)
 * @property {number} crashRadius - Radius of crash site around spawn
 * @property {string} chapterId - Chapter ID for the map
 * @property {string} mapName - Human-readable map name
 */

/** @type {GenOptions} */
const DEFAULTS = {
  radius: 20,
  seed: 0,
  waterPct: 25,
  forestPct: 35,
  rockyPct: 15,
  frequency: 0.06,
  crashRadius: 3,
  chapterId: 'procedural',
  mapName: 'Procedural Map',
};

/**
 * Generate a procedural map.
 * @param {Partial<GenOptions>} opts
 * @returns {{ spawn: number[], chapter_id: string, name: string, tiles: Object }}
 */
export function generateMap(opts = {}) {
  const o = { ...DEFAULTS, ...opts };
  if (o.seed === 0) o.seed = Math.floor(Math.random() * 2147483647);

  const elevNoise = createNoise2D(o.seed);
  const moistNoise = createNoise2D(o.seed + 31337);

  const coords = hexesInRadius(o.radius);

  // --- Phase 1: sample noise for every hex ---
  const samples = coords.map(({ q, r }) => {
    // Convert axial to world-space for noise sampling
    const px = HexMath.axialToPixel(q, r);
    const nx = px.x * o.frequency / 40; // normalize by HEX_SIZE
    const ny = px.y * o.frequency / 40;

    const elevation = elevNoise.fractal2D(nx, ny, 5, 2.0, 0.5);
    const moisture = moistNoise.fractal2D(nx * 0.8, ny * 0.8, 4, 2.0, 0.5);

    // Distance from center for island falloff
    const dist = HexMath.distance(0, 0, q, r);
    const falloff = Math.max(0, 1 - (dist / o.radius) ** 1.5);

    return { q, r, elevation: elevation * falloff, moisture, dist };
  });

  // --- Phase 2: compute percentile thresholds ---
  const elevations = samples.map(s => s.elevation).sort((a, b) => a - b);
  const waterThreshold = elevations[Math.floor(elevations.length * o.waterPct / 100)] ?? -Infinity;

  // For forest/rocky: compute thresholds among land tiles only
  const landSamples = samples.filter(s => s.elevation > waterThreshold);
  const landElevations = landSamples.map(s => s.elevation).sort((a, b) => a - b);
  const rockyThreshold = landElevations.length > 0
    ? landElevations[Math.floor(landElevations.length * (100 - o.rockyPct) / 100)] ?? Infinity
    : Infinity;

  const landMoistures = landSamples.map(s => s.moisture).sort((a, b) => a - b);
  const forestMoistureThreshold = landMoistures.length > 0
    ? landMoistures[Math.floor(landMoistures.length * (100 - o.forestPct) / 100)] ?? Infinity
    : Infinity;

  // --- Phase 3: detect available biomes ---
  const biomeFiles = [...ProjectContext.files.biomes.keys()];
  const biomeSet = new Set(biomeFiles.map(f => f.replace('.tres', '')));

  // Map role -> biome ID. Use project biomes if available, fallback to B000XX.
  const biomeFor = (role) => {
    const map = {
      crash: 'B00001',
      grassland: 'B00002',
      forest: 'B00003',
      rocky: 'B00004',
      water: 'B00005',
    };
    const id = map[role];
    return biomeSet.has(id) ? id : (biomeFiles[0] || '').replace('.tres', '');
  };

  // --- Phase 4: assign biomes ---
  const tiles = {};
  for (const s of samples) {
    const key = `${s.q},${s.r}`;
    let biome;
    let elevation = 0;

    if (s.dist <= o.crashRadius) {
      biome = biomeFor('crash');
      elevation = 0;
    } else if (s.elevation <= waterThreshold) {
      biome = biomeFor('water');
      // Deeper water = more negative elevation
      const depthRatio = waterThreshold === 0 ? 0
        : (waterThreshold - s.elevation) / Math.max(0.001, waterThreshold - elevations[0]);
      elevation = -Math.max(1, Math.round(depthRatio * 5));
    } else if (s.elevation >= rockyThreshold) {
      biome = biomeFor('rocky');
      const heightRatio = landElevations.length > 0
        ? (s.elevation - rockyThreshold) / Math.max(0.001, landElevations[landElevations.length - 1] - rockyThreshold)
        : 0;
      elevation = Math.max(1, Math.round(heightRatio * 8 + 2));
    } else if (s.moisture >= forestMoistureThreshold) {
      biome = biomeFor('forest');
      elevation = Math.max(0, Math.round((s.elevation - waterThreshold) / Math.max(0.001, rockyThreshold - waterThreshold) * 3));
    } else {
      biome = biomeFor('grassland');
      elevation = Math.max(0, Math.round((s.elevation - waterThreshold) / Math.max(0.001, rockyThreshold - waterThreshold) * 3));
    }

    tiles[key] = { biome, elevation };
  }

  return {
    spawn: [0, 0],
    chapter_id: o.chapterId,
    name: o.mapName,
    generator: {
      seed: o.seed,
      radius: o.radius,
      waterPct: o.waterPct,
      forestPct: o.forestPct,
      rockyPct: o.rockyPct,
      frequency: o.frequency,
      crashRadius: o.crashRadius,
    },
    tiles,
  };
}

// ============================================================
// Generator dialog
// ============================================================

/**
 * Show the procedural map generation dialog.
 * @param {function(Object): void} onGenerate - Called with the generated map data
 */
export function showGeneratorDialog(onGenerate) {
  const fields = [
    { label: 'Chapter ID', defaultValue: 'procedural', placeholder: 'e.g. procedural' },
    { label: 'Map Name', defaultValue: 'Procedural Map', placeholder: 'Human-readable name' },
    { label: 'Radius (hexes)', defaultValue: '20', placeholder: '5-500' },
    { label: 'Seed (0 = random)', defaultValue: '0', placeholder: 'Integer seed' },
    { label: 'Water %', defaultValue: '25', placeholder: '0-80' },
    { label: 'Forest %', defaultValue: '35', placeholder: '0-80' },
    { label: 'Rocky %', defaultValue: '15', placeholder: '0-60' },
    { label: 'Frequency', defaultValue: '0.06', placeholder: '0.01-0.2' },
    { label: 'Crash Site Radius', defaultValue: '3', placeholder: '0-10' },
  ];

  showInlineFormModal('Generate Procedural Map', fields, (values) => {
    if (values === null) return;

    const opts = {
      chapterId: (values[0] || '').trim() || 'procedural',
      mapName: (values[1] || '').trim() || 'Procedural Map',
      radius: Math.max(1, Math.min(500, parseInt(values[2], 10) || 20)),
      seed: parseInt(values[3], 10) || 0,
      waterPct: Math.max(0, Math.min(80, parseInt(values[4], 10) || 25)),
      forestPct: Math.max(0, Math.min(80, parseInt(values[5], 10) || 35)),
      rockyPct: Math.max(0, Math.min(60, parseInt(values[6], 10) || 15)),
      frequency: Math.max(0.01, Math.min(0.2, parseFloat(values[7]) || 0.06)),
      crashRadius: Math.max(0, Math.min(10, parseInt(values[8], 10) || 3)),
    };

    const t0 = performance.now();
    const mapData = generateMap(opts);
    const elapsed = (performance.now() - t0).toFixed(0);
    const tileCount = Object.keys(mapData.tiles).length;

    console.log(`map-generator: ${tileCount} tiles in ${elapsed}ms (seed=${opts.seed === 0 ? 'random' : opts.seed})`);
    onGenerate(mapData, opts);
  });
}
