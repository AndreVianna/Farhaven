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
  const ruggedNoise = createNoise2D(o.seed + 71993);

  const coords = hexesInRadius(o.radius);
  const landingZone = o.crashRadius * 2;

  // --- Phase 1: continuous elevation + biome noise layers ---
  // Elevation is ONE smooth field shared by ALL biomes. No per-biome
  // elevation formulas — that caused cliff transitions.
  const samples = coords.map(({ q, r }) => {
    const px = HexMath.axialToPixel(q, r);
    const nx = px.x * o.frequency / 40;
    const ny = px.y * o.frequency / 40;

    const nElev = elevNoise.fractal2D(nx, ny, 5, 2.0, 0.5);
    const nMoist = moistNoise.fractal2D(nx * 0.8, ny * 0.8, 4, 2.0, 0.5);
    const nRugged = ruggedNoise.fractal2D(nx * 1.5, ny * 1.5, 3, 2.0, 0.5);

    const dist = HexMath.distance(0, 0, q, r);

    // Dampen near spawn for walkable landing zone
    let landingFade = 0;
    if (dist <= landingZone && landingZone > 0) {
      landingFade = Math.max(0, 1 - dist / landingZone);
    }

    // Raw continuous elevation: noise × peakHeight
    // This gives a smooth height field across the entire map.
    const rawElev = nElev * (1 - landingFade * 0.8) * o.peakHeight;

    return { q, r, rawElev, nMoist, nRugged, dist };
  });

  // --- Phase 2: sea level — bottom waterPct% becomes water ---
  const sortedElevs = samples.map(s => s.rawElev).sort((a, b) => a - b);
  const seaLevel = sortedElevs[Math.floor(sortedElevs.length * o.waterPct / 100)] ?? 0;

  // Shift so sea level = 0. Land is positive, water is negative.
  for (const s of samples) {
    s.elevation = s.rawElev - seaLevel;
    s.isWater = s.elevation < 0;
  }

  // --- Phase 3: rocky — top rockyPct% of land by ruggedness noise ---
  const landSamples = samples.filter(s => !s.isWater);
  const ruggedScores = landSamples.map(s => s.nRugged).sort((a, b) => a - b);
  const rockyThreshold = ruggedScores.length > 0
    ? ruggedScores[Math.floor(ruggedScores.length * (100 - o.rockyPct) / 100)] ?? Infinity
    : Infinity;

  for (const s of samples) {
    s.isRocky = !s.isWater && s.nRugged >= rockyThreshold;
  }

  // --- Phase 4: forest — top forestPct% of remaining by moisture ---
  const remainingSamples = samples.filter(s => !s.isWater && !s.isRocky);
  const moistScores = remainingSamples.map(s => s.nMoist).sort((a, b) => a - b);
  const forestThreshold = moistScores.length > 0
    ? moistScores[Math.floor(moistScores.length * (100 - o.forestPct) / 100)] ?? Infinity
    : Infinity;

  // --- Phase 5: detect available biomes ---
  const biomeFiles = [...ProjectContext.files.biomes.keys()];
  const biomeSet = new Set(biomeFiles.map(f => f.replace('.tres', '')));

  const biomeFor = (role) => {
    const ids = { crash: 'B00001', grassland: 'B00002', forest: 'B00003', rocky: 'B00004', water: 'B00005' };
    const id = ids[role];
    return biomeSet.has(id) ? id : (biomeFiles[0] || '').replace('.tres', '');
  };

  // --- Phase 6: assign biomes — elevation is the SAME continuous field ---
  // Rocky at elevation 15 next to grassland at elevation 12 = gentle slope.
  // No more per-biome elevation formulas creating artificial cliffs.
  const tiles = {};
  for (const s of samples) {
    const key = `${s.q},${s.r}`;
    let biome;
    let elev;

    if (s.dist <= o.crashRadius) {
      biome = biomeFor('crash');
      elev = 0;
    } else if (s.isWater) {
      biome = biomeFor('water');
      elev = 0;
    } else if (s.isRocky) {
      biome = biomeFor('rocky');
      elev = Math.round(s.elevation);
    } else if (s.nMoist >= forestThreshold) {
      biome = biomeFor('forest');
      elev = Math.round(s.elevation);
    } else {
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
