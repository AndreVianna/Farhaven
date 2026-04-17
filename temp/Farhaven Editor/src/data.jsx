/* Farhaven Editor — mock data (based on actual .tres and map structure) */

// Biomes: id, name, color, elevation range, short desc, resource table
window.BIOMES = [
  { id: 'B00001', name: 'Crash Site',  color: '#8b7355', elev: [0, 2], desc: 'Scorched earth where the shuttle came down.', resources: [
    { prop: 'P01002', chance: 0.6, min: 1, max: 2 },
    { prop: 'P00005', chance: 0.3, min: 1, max: 1 },
  ]},
  { id: 'B00002', name: 'Grassland',   color: '#66bf4d', elev: [0, 3], desc: 'Open plains of tall grass and low brush.', resources: [
    { prop: 'P00001', chance: 0.8, min: 2, max: 4 },
    { prop: 'P00002', chance: 0.4, min: 1, max: 2 },
    { prop: 'P01003', chance: 0.1, min: 1, max: 1 },
  ]},
  { id: 'B00003', name: 'Forest',      color: '#2d8b46', elev: [1, 5], desc: 'Dense canopy of towering alien hardwoods.', resources: [
    { prop: 'P00003', chance: 0.9, min: 1, max: 3 },
    { prop: 'P00004', chance: 0.5, min: 1, max: 2 },
    { prop: 'P01001', chance: 0.15, min: 1, max: 1 },
  ]},
  { id: 'B00004', name: 'Rocky',       color: '#9e8b78', elev: [2, 7], desc: 'Wind-carved outcrops hiding rich mineral veins.', resources: [
    { prop: 'P00006', chance: 0.7, min: 1, max: 3 },
    { prop: 'P00007', chance: 0.3, min: 1, max: 1 },
  ]},
  { id: 'B00005', name: 'Water',       color: '#4a9bd9', elev: [0, 0], desc: 'Still alien pools — drinkable once filtered.', resources: []},
];

window.BIOME_BY_ID = Object.fromEntries(window.BIOMES.map(b => [b.id, b]));

// Props — condensed from data/props/*.tres
window.PROPS = [
  { id: 'P00001', name: 'Blade Grass',    category: 'plant',     rarity: 'common',   color: '#7ec886', glyph: 'BG', desc: 'Dense tufts of fibrous alien grass.' },
  { id: 'P00002', name: 'Sun Moss',       category: 'plant',     rarity: 'common',   color: '#f0d060', glyph: 'SM', desc: 'Light-fed moss that blooms at dawn.' },
  { id: 'P00003', name: 'Ironbark Tree',  category: 'plant',     rarity: 'common',   color: '#6a4b32', glyph: 'IB', desc: 'Tall hardwood with a metallic sheen.' },
  { id: 'P00004', name: 'Glowfern',       category: 'plant',     rarity: 'uncommon', color: '#a88bd9', glyph: 'GF', desc: 'Low fern that emits soft bioluminescence.' },
  { id: 'P00005', name: 'Ration Pack',    category: 'stuff',     rarity: 'uncommon', color: '#f4a261', glyph: 'RP', desc: 'Salvaged from the shuttle. Eat in a pinch.' },
  { id: 'P00006', name: 'Copper Vein',    category: 'mineral',   rarity: 'common',   color: '#c17f4b', glyph: 'Cu', desc: 'Exposed outcrop of conductive ore.' },
  { id: 'P00007', name: 'Crystalline',    category: 'mineral',   rarity: 'rare',     color: '#5bb5e0', glyph: 'Xt', desc: 'Luminous crystals used in scanner repair.' },
  { id: 'P01001', name: 'Sporehopper',    category: 'animal',    rarity: 'uncommon', color: '#a88bd9', glyph: 'Sp', desc: 'Small mammal that bounds between canopies.' },
  { id: 'P01002', name: 'Ship Debris',    category: 'structure', rarity: 'unique',   color: '#c0c6d0', glyph: 'Dw', desc: 'Twisted hull fragment. Scavengable.' },
  { id: 'P01003', name: 'Waterglider',    category: 'animal',    rarity: 'uncommon', color: '#5bb5e0', glyph: 'Wg', desc: 'Glides above grass on pressurized sacs.' },
  { id: 'P01004', name: 'Workbench',      category: 'structure', rarity: 'common',   color: '#f4a261', glyph: 'Wb', desc: 'Crafting station. Requires power.' },
  { id: 'P01005', name: 'Storage Chest',  category: 'structure', rarity: 'common',   color: '#a07050', glyph: 'Sc', desc: 'Holds items between expeditions.' },
  { id: 'P02001', name: 'Ash Spire',      category: 'mineral',   rarity: 'rare',     color: '#4b4852', glyph: 'As', desc: 'Stark black pillar rising from the ash.' },
  { id: 'P02002', name: 'Frost Lichen',   category: 'plant',     rarity: 'uncommon', color: '#c8d2dc', glyph: 'Fl', desc: 'Cold-loving crust on the tundra stones.' },
];

window.PROP_BY_ID = Object.fromEntries(window.PROPS.map(p => [p.id, p]));

window.PROP_CATEGORIES = ['all','plant','animal','mineral','structure','stuff'];
window.CATEGORY_COLORS = {
  plant:     '#7ec886',
  animal:    '#a88bd9',
  mineral:   '#c17f4b',
  structure: '#f4a261',
  stuff:     '#b0b8c8',
};

// Recipes — condensed
window.RECIPES = [
  { id: 'R00001', name: 'Cordage',       station: 'hand',       time: 2,  ingredients: [{ prop:'plant_fiber', qty: 3 }], output: { prop:'cordage', qty: 1 } },
  { id: 'R00002', name: 'Stone Axe',     station: 'workbench',  time: 8,  ingredients: [{ prop:'cordage', qty: 2 },{ prop:'stone_chunk', qty: 3 },{ prop:'branch', qty: 1 }], output: { prop:'stone_axe', qty: 1 } },
  { id: 'R00003', name: 'Campfire',      station: 'hand',       time: 6,  ingredients: [{ prop:'stone_chunk', qty: 4 },{ prop:'branch', qty: 2 }], output: { prop:'campfire', qty: 1 } },
  { id: 'R00004', name: 'Torch',         station: 'hand',       time: 2,  ingredients: [{ prop:'branch', qty: 1 },{ prop:'plant_fiber', qty: 1 }], output: { prop:'torch', qty: 1 } },
  { id: 'R00005', name: 'Copper Plate',  station: 'workbench',  time: 15, ingredients: [{ prop:'copper_ore', qty: 3 },{ prop:'heat_charge', qty: 1 }], output: { prop:'copper_plate', qty: 2 } },
  { id: 'R00006', name: 'Scanner Core',  station: 'workbench',  time: 30, ingredients: [{ prop:'crystalline_shard', qty: 2 },{ prop:'copper_plate', qty: 3 }], output: { prop:'scanner_core', qty: 1 } },
];

// Journal entries
window.JOURNAL = [
  { id: 'J0001', day: 1, title: 'The Landing',         body: 'Shuttle impact at 03:22 local. Primary systems offline. Auxiliary scanner functional.' },
  { id: 'J0002', day: 2, title: 'Fiber & Stone',       body: 'Blade grass cordage holds. Enough for a shelter frame by nightfall.' },
  { id: 'J0003', day: 3, title: 'Tracks in the Moss',  body: 'Small mammal prints lead toward the treeline. Not hostile. Yet.' },
  { id: 'J0004', day: 5, title: 'The Glowfern',        body: 'Ferns in the understory pulse at dusk. Possible power source?' },
];

// Cutscenes
window.CUTSCENES = [
  { id: 'C0001', name: 'Intro — Crash',     trigger: 'chapter_start:ch1', frames: 4 },
  { id: 'C0002', name: 'First Night',       trigger: 'phase_change:night:1', frames: 2 },
  { id: 'C0003', name: 'Workbench Online',  trigger: 'craft:workbench',  frames: 3 },
];

// Events
window.EVENTS = [
  { id: 'E0001', name: 'Meteor Shower',    schedule: 'day>=7 && phase==night',  rarity: 0.2 },
  { id: 'E0002', name: 'Rainstorm',        schedule: 'day>=3',                   rarity: 0.35 },
  { id: 'E0003', name: 'Bioluminescence',  schedule: 'phase==dusk',              rarity: 0.5 },
];

/* ============================================================
   Procedural map generation (visually varied showcase map)
   ============================================================ */

// Flat-top axial neighbor directions
window.HEX_DIRS = [
  [+1,  0], [+1, -1], [0, -1],
  [-1,  0], [-1, +1], [0, +1],
];

function hexDist(a, b) {
  const ax = a[0], az = a[1], ay = -ax - az;
  const bx = b[0], bz = b[1], by = -bx - bz;
  return Math.max(Math.abs(ax-bx), Math.abs(ay-by), Math.abs(az-bz));
}
window.hexDist = hexDist;

function ringOfHexes(radius) {
  const tiles = [];
  for (let q = -radius; q <= radius; q++) {
    const r1 = Math.max(-radius, -q - radius);
    const r2 = Math.min(radius,  -q + radius);
    for (let r = r1; r <= r2; r++) tiles.push([q, r]);
  }
  return tiles;
}

function buildShowcaseMap() {
  // Seeded pseudo-random
  let seed = 4242;
  const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };
  const pick = arr => arr[Math.floor(rnd() * arr.length)];

  const tiles = {};
  const allHexes = ringOfHexes(7);

  // Biome anchors — center-ish, chosen to create organic blobs
  const anchors = [
    { id: 'B00001', at: [0, 0] },      // Crash site — center
    { id: 'B00002', at: [3, -1] },     // Grassland east
    { id: 'B00002', at: [-3, 2] },     // Grassland west
    { id: 'B00003', at: [-1, 4] },     // Forest south
    { id: 'B00003', at: [2, -5] },     // Forest north-east
    { id: 'B00004', at: [-5, -1] },    // Rocky west
    { id: 'B00004', at: [5, -4] },     // Rocky ne
    { id: 'B00005', at: [-3, 5] },     // Water
    { id: 'B00005', at: [4, 3] },      // Water lake
  ];

  for (const [q, r] of allHexes) {
    // Find nearest anchor with small jitter
    let best = null, bestDist = Infinity;
    for (const a of anchors) {
      const d = hexDist([q, r], a.at) + rnd() * 0.9;
      if (d < bestDist) { bestDist = d; best = a; }
    }
    const biome = best.id;

    // Elevation: follow biome range, smoothed by distance from center
    const b = window.BIOME_BY_ID[biome];
    const [eMin, eMax] = b.elev;
    let elev = eMin + Math.round(rnd() * (eMax - eMin));

    // Push up rocky ridges, keep water flat
    if (biome === 'B00005') elev = 0;
    if (biome === 'B00004' && rnd() < 0.35) elev = Math.min(9, elev + 1);

    // Placed props — 0..2 per tile, biased by biome table
    const props = [];
    if (biome !== 'B00005') {
      const tbl = b.resources;
      for (const row of tbl) {
        if (rnd() < row.chance * 0.5) {
          const qty = row.min + Math.floor(rnd() * (row.max - row.min + 1));
          for (let i = 0; i < qty && props.length < 3; i++) {
            props.push({
              type: row.prop,
              x: (rnd() - 0.5) * 1.6,
              y: (rnd() - 0.5) * 1.6,
              rot: Math.floor(rnd() * 360),
            });
          }
        }
      }
    }

    // Walls for cliff edges (purely visual cue)
    const walls = [false, false, false, false, false, false];

    // Anomaly pocket: 2 hexes far east
    let anomaly = null;
    if (q === 6 && r === -3) anomaly = 'strange_signal';
    if (q === -6 && r === 5) anomaly = 'crater';

    // Structure: workbench near spawn
    let structure = null;
    if (q === 1 && r === 0) structure = 'P01004';
    if (q === -1 && r === 1) structure = 'P01005';
    if (q === 0 && r === -1) structure = 'P01002'; // ship debris

    tiles[`${q},${r}`] = { q, r, biome, elevation: elev, walls, props, anomaly, structure };
  }

  return {
    id: 'ch1',
    name: 'Crash Landing',
    spawn: [0, 0],
    tiles,
  };
}

window.MAPS = [
  { id: 'ch1',    name: 'Crash Landing', tiles: 168 },
  { id: 'ch2',    name: 'The Ridgeline', tiles: 240, dirty: true },
  { id: 'ch3',    name: 'Cavern Below',  tiles: 92 },
  { id: 'test01', name: 'test01',        tiles: 19 },
];

window.SHOWCASE_MAP = buildShowcaseMap();
