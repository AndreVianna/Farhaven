// ============================================================
// map-generator.js — Procedural hex map generation
// ============================================================
//
// Generates a hex map using layered Simplex noise + biome rules.
// Terrain model: central valley surrounded by rising mountains.
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
 * All axial (q, r) coordinates within a hex-shaped region of the
 * given radius centered at (0, 0).
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
// Generation
// ============================================================

/**
 * @typedef {Object} GenOptions
 * @property {number} radius - Map radius in hexes
 * @property {number} seed - Random seed (0 = pick one)
 * @property {number} waterPct - Percentage of tiles that become water (0-100)
 * @property {number} forestPct - Percentage of land tiles that become forest (0-100)
 * @property {number} rockyPct - Percentage of land tiles that become rocky (0-100)
 * @property {number} frequency - Noise frequency (lower = larger features)
 * @property {number} peakHeight - Max mountain elevation at map edge (in half-metres)
 * @property {number} crashRadius - Radius of crash site around spawn
 * @property {string} chapterId - Chapter ID for the map file
 * @property {string} mapName - Human-readable map name
 */

/** @type {GenOptions} */
const DEFAULTS = {
  radius: 20,
  seed: 0,
  waterPct: 15,
  forestPct: 35,
  rockyPct: 15,
  frequency: 0.06,
  peakHeight: 200,
  crashRadius: 3,
  chapterId: 'procedural',
  mapName: 'Procedural Map',
};

/**
 * Generate a procedural map.
 *
 * Terrain model:
 *   rawElev = noise * amplitude + distanceRise
 *
 * - Center (dist=0): elevation ≈ noise only → gentle, can dip below 0
 * - Edges (dist=radius): elevation ≈ peakHeight → mountains
 * - Sea level is set so that exactly waterPct% of tiles fall below it
 * - Tiles below sea level → Water (elevation = 0, water surface)
 * - Tiles above sea level → elevation in game units (each ≈ 0.5 m)
 *
 * @param {Partial<GenOptions>} opts
 * @returns {Object} Map JSON data
 */
export function generateMap(opts = {}) {
  const o = { ...DEFAULTS, ...opts };
  if (o.seed === 0) o.seed = Math.floor(Math.random() * 2147483647);

  const elevNoise = createNoise2D(o.seed);
  const moistNoise = createNoise2D(o.seed + 31337);

  const coords = hexesInRadius(o.radius);

  // Noise amplitude — controls how much the terrain undulates.
  // Scaled relative to peakHeight so the center valley has meaningful
  // variation without overpowering the distance-based mountain rise.
  const noiseAmp = o.peakHeight * 0.25;

  // --- Phase 1: raw elevation + moisture for every hex ---
  const samples = coords.map(({ q, r }) => {
    const px = HexMath.axialToPixel(q, r);
    const nx = px.x * o.frequency / 40;
    const ny = px.y * o.frequency / 40;

    // Fractal noise in roughly [-1, 1]
    const nElev = elevNoise.fractal2D(nx, ny, 5, 2.0, 0.5);
    const nMoist = moistNoise.fractal2D(nx * 0.8, ny * 0.8, 4, 2.0, 0.5);

    // Distance-based mountain rise: center = 0, edge = peakHeight
    const dist = HexMath.distance(0, 0, q, r);
    const distRatio = dist / Math.max(1, o.radius);
    const heightRise = Math.pow(distRatio, 2.5) * o.peakHeight;

    // Combined raw elevation
    const rawElev = nElev * noiseAmp + heightRise;

    return { q, r, rawElev, moisture: nMoist, dist };
  });

  // --- Phase 2: set sea level via percentile so waterPct% of tiles are submerged ---
  const sortedElevs = samples.map(s => s.rawElev).sort((a, b) => a - b);
  const seaLevel = sortedElevs[Math.floor(sortedElevs.length * o.waterPct / 100)] ?? 0;

  // Shift all elevations so sea level = 0
  for (const s of samples) {
    s.elevation = s.rawElev - seaLevel;
  }

  // --- Phase 3: biome thresholds among land tiles ---
  const landSamples = samples.filter(s => s.elevation >= 0);

  // Rocky threshold: top rockyPct% of land by elevation
  const landElevsSorted = landSamples.map(s => s.elevation).sort((a, b) => a - b);
  const rockyThreshold = landElevsSorted.length > 0
    ? landElevsSorted[Math.floor(landElevsSorted.length * (100 - o.rockyPct) / 100)] ?? Infinity
    : Infinity;

  // Forest threshold: top forestPct% of land by moisture
  const landMoistSorted = landSamples.map(s => s.moisture).sort((a, b) => a - b);
  const forestMoistThreshold = landMoistSorted.length > 0
    ? landMoistSorted[Math.floor(landMoistSorted.length * (100 - o.forestPct) / 100)] ?? Infinity
    : Infinity;

  // --- Phase 4: detect available biomes ---
  const biomeFiles = [...ProjectContext.files.biomes.keys()];
  const biomeSet = new Set(biomeFiles.map(f => f.replace('.tres', '')));

  const biomeFor = (role) => {
    const ids = { crash: 'B00001', grassland: 'B00002', forest: 'B00003', rocky: 'B00004', water: 'B00005' };
    const id = ids[role];
    return biomeSet.has(id) ? id : (biomeFiles[0] || '').replace('.tres', '');
  };

  // --- Phase 5: assign biomes + final elevation ---
  const tiles = {};
  for (const s of samples) {
    const key = `${s.q},${s.r}`;
    let biome;
    let elev;

    if (s.dist <= o.crashRadius) {
      // Crash site: flat area at center
      biome = biomeFor('crash');
      elev = 0;
    } else if (s.elevation < 0) {
      // Below sea level → water, surface at 0
      biome = biomeFor('water');
      elev = 0;
    } else if (s.elevation >= rockyThreshold) {
      // High elevation → rocky
      biome = biomeFor('rocky');
      elev = Math.round(s.elevation);
    } else if (s.moisture >= forestMoistThreshold) {
      // High moisture land → forest
      biome = biomeFor('forest');
      elev = Math.round(s.elevation);
    } else {
      // Default → grassland
      biome = biomeFor('grassland');
      elev = Math.round(s.elevation);
    }

    tiles[key] = { biome, elevation: elev };
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
      peakHeight: o.peakHeight,
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
 * @param {function(Object, Object): void} onGenerate
 */
export function showGeneratorDialog(onGenerate) {
  const fields = [
    { label: 'Chapter ID', defaultValue: 'procedural', placeholder: 'e.g. procedural' },
    { label: 'Map Name', defaultValue: 'Procedural Map', placeholder: 'Human-readable name' },
    { label: 'Radius (hexes)', defaultValue: '20', placeholder: '5-500' },
    { label: 'Seed (0 = random)', defaultValue: '0', placeholder: 'Integer seed' },
    { label: 'Water %', defaultValue: '15', placeholder: '0-60' },
    { label: 'Forest %', defaultValue: '35', placeholder: '0-80' },
    { label: 'Rocky %', defaultValue: '15', placeholder: '0-60' },
    { label: 'Frequency', defaultValue: '0.06', placeholder: '0.01-0.2 (lower = bigger features)' },
    { label: 'Peak Height', defaultValue: '200', placeholder: '50-500 (each unit ≈ 0.5 m)' },
    { label: 'Crash Site Radius', defaultValue: '3', placeholder: '0-10' },
  ];

  showInlineFormModal('Generate Procedural Map', fields, (values) => {
    if (values === null) return;

    const opts = {
      chapterId: (values[0] || '').trim() || 'procedural',
      mapName: (values[1] || '').trim() || 'Procedural Map',
      radius: Math.max(1, Math.min(500, parseInt(values[2], 10) || 20)),
      seed: parseInt(values[3], 10) || 0,
      waterPct: Math.max(0, Math.min(60, parseInt(values[4], 10) || 15)),
      forestPct: Math.max(0, Math.min(80, parseInt(values[5], 10) || 35)),
      rockyPct: Math.max(0, Math.min(60, parseInt(values[6], 10) || 15)),
      frequency: Math.max(0.01, Math.min(0.2, parseFloat(values[7]) || 0.06)),
      peakHeight: Math.max(50, Math.min(500, parseInt(values[8], 10) || 200)),
      crashRadius: Math.max(0, Math.min(10, parseInt(values[9], 10) || 3)),
    };

    const t0 = performance.now();
    const mapData = generateMap(opts);
    const elapsed = (performance.now() - t0).toFixed(0);
    const tileCount = Object.keys(mapData.tiles).length;

    console.log(`map-generator: ${tileCount} tiles in ${elapsed}ms (seed=${opts.seed === 0 ? 'random' : opts.seed})`);
    onGenerate(mapData, opts);
  });
}
