// ============================================================
// map-generator.js — Procedural hex map generation (5-pass pipeline)
// ============================================================
//
// Pass 1: Elevation (domain-warped Simplex fBm + power redistribution)
// Pass 2: Hydraulic erosion (particle-based, carves valleys/rivers)
// Pass 3: Hydrology (Priority-Flood → flow direction → accumulation → rivers/lakes)
// Pass 4: Moisture (BFS from water bodies with exponential falloff)
// Pass 5: Biome assignment (Whittaker-style elevation × moisture lookup)

'use strict';

import { createNoise2D } from './simplex-noise.js';
import { HexMath } from './hex-math.js';
import { ProjectContext } from './file-discovery.js';
import { showInlineFormModal } from './panels.js';

// ============================================================
// Hex coordinate helpers
// ============================================================

function hexesInRadius(radius) {
  const coords = [];
  for (let q = -radius; q <= radius; q++) {
    const r1 = Math.max(-radius, -q - radius);
    const r2 = Math.min(radius, -q + radius);
    for (let r = r1; r <= r2; r++) coords.push({ q, r });
  }
  return coords;
}

function hexKey(q, r) { return `${q},${r}`; }

// ============================================================
// Default parameters
// ============================================================

const DEFAULTS = {
  radius: 20,
  seed: 0,
  frequency: 0.05,
  warpStrength: 0.5,
  peakHeight: 200,
  redistPower: 2.0,
  erosionDrops: 5000,
  erosionSteps: 30,
  riverThreshold: 15,
  moistureFalloff: 0.85,
  crashRadius: 3,
  chapterId: 'procedural',
  mapName: 'Procedural Map',
};

// ============================================================
// Pass 1: Elevation
// ============================================================

function passElevation(hexMap, coords, o) {
  const noise = createNoise2D(o.seed);

  for (const { q, r } of coords) {
    const px = HexMath.axialToPixel(q, r);
    const nx = px.x * o.frequency / 40;
    const ny = px.y * o.frequency / 40;

    // Domain-warped fBm for organic mountain ranges
    let e = noise.warpedFbm(nx, ny, 5, o.warpStrength);

    // Remap from [-1,1] to [0,1]
    e = (e + 1) / 2;

    // Power redistribution: compresses midrange toward valleys,
    // preserves peaks → more dramatic terrain
    e = Math.pow(e, o.redistPower);

    // Scale to game units (each ≈ 0.5m)
    e = e * o.peakHeight;

    // Landing zone dampening near crash site
    const dist = HexMath.distance(0, 0, q, r);
    if (dist <= o.crashRadius * 2) {
      const fade = Math.max(0, 1 - dist / (o.crashRadius * 2));
      e = e * (1 - fade * 0.9); // flatten near spawn
    }

    const key = hexKey(q, r);
    hexMap.set(key, { q, r, elevation: e, dist });
  }
}

// ============================================================
// Pass 2: Hydraulic erosion (particle-based)
// ============================================================

function passErosion(hexMap, coords, o) {
  if (o.erosionDrops <= 0) return;

  // Build index for neighbor lookup
  const keySet = new Set([...hexMap.keys()]);

  // Seeded PRNG for reproducible erosion
  let rngState = o.seed + 99991;
  function rng() {
    rngState ^= rngState << 13;
    rngState ^= rngState >>> 17;
    rngState ^= rngState << 5;
    return (rngState >>> 0) / 4294967296;
  }

  // Pick a random hex from coordinates
  function randomHex() {
    const idx = Math.floor(rng() * coords.length);
    return coords[idx];
  }

  // Get the gradient (steepest descent) at a hex
  function getGradient(q, r) {
    const center = hexMap.get(hexKey(q, r));
    if (!center) return null;

    let bestDrop = 0;
    let bestQ = q, bestR = r;
    for (const dir of HexMath.DIRECTIONS) {
      const nq = q + dir.q, nr = r + dir.r;
      const nk = hexKey(nq, nr);
      const neighbor = hexMap.get(nk);
      if (!neighbor) continue;
      const drop = center.elevation - neighbor.elevation;
      if (drop > bestDrop) {
        bestDrop = drop;
        bestQ = nq;
        bestR = nr;
      }
    }
    return { dq: bestQ - q, dr: bestR - r, drop: bestDrop };
  }

  const erosionRate = 0.3;
  const depositionRate = 0.3;
  const sedimentCapacity = 4.0;

  for (let d = 0; d < o.erosionDrops; d++) {
    let { q, r } = randomHex();
    let sediment = 0;
    let velocity = 1;

    for (let step = 0; step < o.erosionSteps; step++) {
      const grad = getGradient(q, r);
      if (!grad || grad.drop <= 0) {
        // Deposit remaining sediment in depression
        const cell = hexMap.get(hexKey(q, r));
        if (cell) cell.elevation += sediment * depositionRate;
        break;
      }

      const cell = hexMap.get(hexKey(q, r));
      if (!cell) break;

      // Capacity depends on velocity and slope
      const capacity = Math.max(grad.drop * velocity * sedimentCapacity, 0.01);

      if (sediment > capacity) {
        // Deposit excess
        const deposit = (sediment - capacity) * depositionRate;
        cell.elevation += deposit;
        sediment -= deposit;
      } else {
        // Erode
        const erode = Math.min((capacity - sediment) * erosionRate, grad.drop * 0.5);
        cell.elevation -= erode;
        sediment += erode;
      }

      velocity = Math.sqrt(velocity * velocity + grad.drop * 0.1);
      velocity *= 0.95; // friction

      // Move downhill
      q += grad.dq;
      r += grad.dr;
    }
  }
}

// ============================================================
// Pass 3: Hydrology (Priority-Flood + flow accumulation)
// ============================================================

function passHydrology(hexMap, coords, o) {
  // --- 3a: Priority-Flood depression filling + flow direction ---
  // Barnes (2014) algorithm adapted for 6-connected hex grid.
  // Fills depressions so every cell can drain to the map edge.
  // Simultaneously records flow direction.

  const flowDir = new Map();    // key -> { q, r } of downstream neighbor
  const filled = new Map();     // key -> filled elevation
  const visited = new Set();

  // Priority queue (min-heap by elevation) — simple array-based
  // For 187K hexes this is fast enough; a proper binary heap
  // would be needed only for millions of cells.
  const pq = [];
  function pqPush(item) {
    pq.push(item);
    let i = pq.length - 1;
    while (i > 0) {
      const parent = (i - 1) >> 1;
      if (pq[parent].elev <= pq[i].elev) break;
      [pq[parent], pq[i]] = [pq[i], pq[parent]];
      i = parent;
    }
  }
  function pqPop() {
    const top = pq[0];
    const last = pq.pop();
    if (pq.length > 0) {
      pq[0] = last;
      let i = 0;
      while (true) {
        let smallest = i;
        const l = 2 * i + 1, r = 2 * i + 2;
        if (l < pq.length && pq[l].elev < pq[smallest].elev) smallest = l;
        if (r < pq.length && pq[r].elev < pq[smallest].elev) smallest = r;
        if (smallest === i) break;
        [pq[smallest], pq[i]] = [pq[i], pq[smallest]];
        i = smallest;
      }
    }
    return top;
  }

  // Seed PQ with boundary hexes (distance == radius)
  for (const { q, r } of coords) {
    const dist = HexMath.distance(0, 0, q, r);
    if (dist >= o.radius) {
      const key = hexKey(q, r);
      const cell = hexMap.get(key);
      if (!cell) continue;
      pqPush({ q, r, elev: cell.elevation });
      visited.add(key);
      filled.set(key, cell.elevation);
      flowDir.set(key, null); // boundary drains off-map
    }
  }

  // Flood inward
  while (pq.length > 0) {
    const { q, r, elev } = pqPop();
    const key = hexKey(q, r);

    for (const dir of HexMath.DIRECTIONS) {
      const nq = q + dir.q, nr = r + dir.r;
      const nk = hexKey(nq, nr);
      if (visited.has(nk)) continue;
      const neighbor = hexMap.get(nk);
      if (!neighbor) continue;

      visited.add(nk);
      const filledElev = Math.max(neighbor.elevation, elev);
      filled.set(nk, filledElev);
      flowDir.set(nk, { q, r }); // drains toward current cell
      pqPush({ q: nq, r: nr, elev: filledElev });
    }
  }

  // --- 3b: Flow accumulation ---
  // Sort all hexes by filled elevation, highest first.
  // Each hex passes its accumulated water to its downstream neighbor.
  const accumulation = new Map();
  for (const { q, r } of coords) accumulation.set(hexKey(q, r), 1);

  const sorted = coords
    .map(({ q, r }) => ({ q, r, elev: filled.get(hexKey(q, r)) ?? 0 }))
    .sort((a, b) => b.elev - a.elev);

  for (const { q, r } of sorted) {
    const key = hexKey(q, r);
    const downstream = flowDir.get(key);
    if (!downstream) continue;
    const dk = hexKey(downstream.q, downstream.r);
    accumulation.set(dk, (accumulation.get(dk) || 0) + (accumulation.get(key) || 0));
  }

  // --- 3c: Identify rivers and lakes ---
  for (const { q, r } of coords) {
    const key = hexKey(q, r);
    const cell = hexMap.get(key);
    if (!cell) continue;

    const acc = accumulation.get(key) || 0;
    const filledE = filled.get(key) ?? cell.elevation;

    // Lake: where Priority-Flood raised the elevation (depression was filled)
    cell.isLake = filledE > cell.elevation + 0.5;

    // River: high flow accumulation AND not a lake
    cell.isRiver = !cell.isLake && acc >= o.riverThreshold;

    cell.isWater = cell.isLake || cell.isRiver;
    cell.flowAccumulation = acc;

    // Use filled elevation for final terrain (depressions become lake bottoms)
    if (cell.isLake) {
      cell.elevation = filledE; // lake surface
    }
  }
}

// ============================================================
// Pass 4: Moisture (BFS from water bodies)
// ============================================================

function passMoisture(hexMap, coords, o) {
  const moistNoise = createNoise2D(o.seed + 31337);

  // BFS outward from all water cells
  const moisture = new Map();
  const queue = [];

  for (const { q, r } of coords) {
    const key = hexKey(q, r);
    const cell = hexMap.get(key);
    if (cell && cell.isWater) {
      moisture.set(key, 1.0);
      queue.push({ q, r, m: 1.0 });
    }
  }

  let head = 0;
  while (head < queue.length) {
    const { q, r, m } = queue[head++];
    const nextM = m * o.moistureFalloff;
    if (nextM < 0.01) continue;

    for (const dir of HexMath.DIRECTIONS) {
      const nq = q + dir.q, nr = r + dir.r;
      const nk = hexKey(nq, nr);
      if (!hexMap.has(nk)) continue;
      const existing = moisture.get(nk) ?? 0;
      if (nextM > existing) {
        moisture.set(nk, nextM);
        queue.push({ q: nq, r: nr, m: nextM });
      }
    }
  }

  // Blend with base noise for variety
  for (const { q, r } of coords) {
    const key = hexKey(q, r);
    const cell = hexMap.get(key);
    if (!cell) continue;

    const px = HexMath.axialToPixel(q, r);
    const nx = px.x * o.frequency * 0.7 / 40;
    const ny = px.y * o.frequency * 0.7 / 40;
    const baseNoise = (moistNoise.fractal2D(nx, ny, 3) + 1) / 2; // [0,1]

    const waterMoist = moisture.get(key) ?? 0;
    // Blend: 60% water proximity, 40% base noise
    cell.moisture = Math.min(1, waterMoist * 0.6 + baseNoise * 0.4);
  }
}

// ============================================================
// Pass 5: Biome assignment (Whittaker-style)
// ============================================================

function passBiomes(hexMap, coords, o) {
  const biomeFiles = [...ProjectContext.files.biomes.keys()];
  const biomeSet = new Set(biomeFiles.map(f => f.replace('.tres', '')));

  const biomeFor = (role) => {
    const ids = { crash: 'B00001', grassland: 'B00002', forest: 'B00003', rocky: 'B00004', water: 'B00005' };
    const id = ids[role];
    return biomeSet.has(id) ? id : (biomeFiles[0] || '').replace('.tres', '');
  };

  // Normalize elevation for biome lookup
  let maxElev = 0;
  for (const { q, r } of coords) {
    const cell = hexMap.get(hexKey(q, r));
    if (cell && !cell.isWater && cell.elevation > maxElev) maxElev = cell.elevation;
  }
  if (maxElev === 0) maxElev = 1;

  for (const { q, r } of coords) {
    const key = hexKey(q, r);
    const cell = hexMap.get(key);
    if (!cell) continue;

    if (cell.dist <= o.crashRadius) {
      cell.biome = biomeFor('crash');
      cell.elevation = 0;
    } else if (cell.isWater) {
      cell.biome = biomeFor('water');
      cell.elevation = 0; // water surface
    } else {
      // Whittaker lookup: elevation (normalized) × moisture
      const eNorm = cell.elevation / maxElev; // 0-1
      const m = cell.moisture ?? 0;

      if (eNorm > 0.65) {
        cell.biome = biomeFor('rocky');
      } else if (eNorm > 0.35) {
        cell.biome = m > 0.45 ? biomeFor('forest') : biomeFor('grassland');
      } else {
        cell.biome = m > 0.6 ? biomeFor('forest') : biomeFor('grassland');
      }

      cell.elevation = Math.round(cell.elevation);
    }
  }
}

// ============================================================
// Pass 6: Accessibility smoothing
// ============================================================
//
// Post-processing to eliminate inaccessible "tower" tiles.
// A tile is accessible if at least one non-water neighbor has
// an elevation diff ≤ 4 (the max step-up height in-game).

function passAccessibility(hexMap, coords, o) {
  const MAX_STEP = 4;

  // Helper: check if a tile can be reached from at least one neighbor
  function isAccessible(q, r) {
    const key = hexKey(q, r);
    const cell = hexMap.get(key);
    if (!cell) return true;
    const elev = cell.elevation;
    for (const dir of HexMath.DIRECTIONS) {
      const nk = hexKey(q + dir.q, r + dir.r);
      const neighbor = hexMap.get(nk);
      if (!neighbor || neighbor.isWater) continue;
      if (elev - neighbor.elevation <= MAX_STEP) return true;
    }
    return false;
  }

  // Helper: get highest non-water, non-rocky neighbor elevation
  function highestLandNeighborElev(q, r) {
    let best = 0;
    for (const dir of HexMath.DIRECTIONS) {
      const nk = hexKey(q + dir.q, r + dir.r);
      const neighbor = hexMap.get(nk);
      if (!neighbor || neighbor.isWater || neighbor.biome === 'B00004') continue;
      if (neighbor.elevation > best) best = neighbor.elevation;
    }
    return best;
  }

  // Detect biome IDs for water and rocky
  const biomeFiles = [...ProjectContext.files.biomes.keys()];
  const biomeSet = new Set(biomeFiles.map(f => f.replace('.tres', '')));
  const waterBiome = biomeSet.has('B00005') ? 'B00005' : null;
  const rockyBiome = biomeSet.has('B00004') ? 'B00004' : null;

  function isSkippable(cell) {
    return !cell || cell.isWater || cell.biome === waterBiome;
  }

  // Accessible from below = at least one non-water, non-rocky neighbor
  // with elevation between (tile - MAX_STEP) and tile (inclusive).
  // Neighbors above the tile don't count (not "coming from below").
  // Neighbors more than MAX_STEP below don't count (too steep).
  function isAccessibleFromLand(q, r) {
    const cell = hexMap.get(hexKey(q, r));
    if (!cell) return true;
    const elev = cell.elevation;
    for (const dir of HexMath.DIRECTIONS) {
      const nk = hexKey(q + dir.q, r + dir.r);
      const neighbor = hexMap.get(nk);
      if (!neighbor || neighbor.isWater || neighbor.biome === waterBiome || neighbor.biome === rockyBiome) continue;
      const diff = elev - neighbor.elevation;
      if (diff >= 0 && diff <= MAX_STEP) return true;
    }
    return false;
  }

  // Step 1: Promote inaccessible high tiles (≥10) to Rocky — repeat until stable
  let totalPromoted = 0;
  if (rockyBiome) {
    let changed = true;
    while (changed) {
      changed = false;
      for (const { q, r } of coords) {
        const cell = hexMap.get(hexKey(q, r));
        if (isSkippable(cell) || cell.biome === rockyBiome) continue;
        if (cell.elevation >= 10 && !isAccessibleFromLand(q, r)) {
          cell.biome = rockyBiome;
          totalPromoted++;
          changed = true;
        }
      }
    }
  }

  // Step 2: Clamp inaccessible non-water, non-rocky tiles to highest non-rocky neighbor + MAX_STEP
  let smoothed = 0;
  for (const { q, r } of coords) {
    const cell = hexMap.get(hexKey(q, r));
    if (isSkippable(cell) || cell.biome === rockyBiome) continue;
    if (!isAccessibleFromLand(q, r)) {
      const target = highestLandNeighborElev(q, r) + MAX_STEP;
      cell.elevation = target;
      smoothed++;
    }
  }

  if (totalPromoted > 0 || smoothed > 0) {
    console.log(`passAccessibility: ${totalPromoted} tiles promoted to rocky, ${smoothed} tiles elevation-smoothed`);
  }
}

// ============================================================
// Main generator
// ============================================================

export function generateMap(opts = {}) {
  const o = { ...DEFAULTS, ...opts };
  if (o.seed === 0) o.seed = Math.floor(Math.random() * 2147483647);

  const coords = hexesInRadius(o.radius);
  const hexMap = new Map();

  // Scale erosion drops with map size (roughly 1 drop per 2-3 hexes)
  const scaledDrops = o.erosionDrops === DEFAULTS.erosionDrops
    ? Math.max(1000, Math.round(coords.length * 0.4))
    : o.erosionDrops;
  const effectiveOpts = { ...o, erosionDrops: scaledDrops };

  const t0 = performance.now();
  passElevation(hexMap, coords, effectiveOpts);
  const t1 = performance.now();
  passErosion(hexMap, coords, effectiveOpts);
  const t2 = performance.now();
  passHydrology(hexMap, coords, effectiveOpts);
  const t3 = performance.now();
  passMoisture(hexMap, coords, effectiveOpts);
  const t4 = performance.now();
  passBiomes(hexMap, coords, effectiveOpts);
  const t5 = performance.now();
  passAccessibility(hexMap, coords, effectiveOpts);
  const t6 = performance.now();

  console.log(`map-generator passes: elev=${(t1-t0).toFixed(0)}ms erosion=${(t2-t1).toFixed(0)}ms hydro=${(t3-t2).toFixed(0)}ms moisture=${(t4-t3).toFixed(0)}ms biomes=${(t5-t4).toFixed(0)}ms access=${(t6-t5).toFixed(0)}ms total=${(t6-t0).toFixed(0)}ms`);

  // Build output tiles
  const tiles = {};
  for (const [key, cell] of hexMap) {
    tiles[key] = {
      biome: cell.biome || 'B00002',
      elevation: typeof cell.elevation === 'number' ? Math.round(cell.elevation) : 0,
    };
  }

  return {
    spawn: [0, 0],
    chapter_id: o.chapterId,
    name: o.mapName,
    generator: {
      seed: o.seed,
      radius: o.radius,
      frequency: o.frequency,
      warpStrength: o.warpStrength,
      peakHeight: o.peakHeight,
      redistPower: o.redistPower,
      erosionDrops: scaledDrops,
      erosionSteps: o.erosionSteps,
      riverThreshold: o.riverThreshold,
      moistureFalloff: o.moistureFalloff,
      crashRadius: o.crashRadius,
    },
    tiles,
  };
}

// ============================================================
// Generator dialog
// ============================================================

export function showGeneratorDialog(onGenerate) {
  const fields = [
    { label: 'Chapter ID', defaultValue: 'procedural', placeholder: 'e.g. procedural' },
    { label: 'Map Name', defaultValue: 'Procedural Map', placeholder: 'Human-readable name' },
    { label: 'Radius (hexes)', defaultValue: '20', placeholder: '5-500' },
    { label: 'Seed (0 = random)', defaultValue: '0', placeholder: 'Integer seed' },
    { label: 'Frequency', defaultValue: '0.05', placeholder: '0.02-0.15 (lower = bigger features)' },
    { label: 'Domain Warp', defaultValue: '0.5', placeholder: '0-2 (organic deformation)' },
    { label: 'Peak Height', defaultValue: '200', placeholder: '50-500 (each unit ≈ 0.5m)' },
    { label: 'River Sensitivity', defaultValue: '15', placeholder: '5-50 (lower = more rivers)' },
    { label: 'Crash Site Radius', defaultValue: '3', placeholder: '0-10' },
  ];

  showInlineFormModal('Generate Procedural Map', fields, (values) => {
    if (values === null) return;

    const opts = {
      chapterId: (values[0] || '').trim() || 'procedural',
      mapName: (values[1] || '').trim() || 'Procedural Map',
      radius: Math.max(1, Math.min(500, parseInt(values[2], 10) || 20)),
      seed: parseInt(values[3], 10) || 0,
      frequency: Math.max(0.02, Math.min(0.15, parseFloat(values[4]) || 0.05)),
      warpStrength: Math.max(0, Math.min(2, parseFloat(values[5]) || 0.5)),
      peakHeight: Math.max(50, Math.min(500, parseInt(values[6], 10) || 200)),
      riverThreshold: Math.max(3, Math.min(100, parseInt(values[7], 10) || 15)),
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
