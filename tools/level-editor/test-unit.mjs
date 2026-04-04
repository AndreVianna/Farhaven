/**
 * Unit tests for delivery-001 classes: CommandHistory, DirtyTracker, TresParser, KeyboardManager.
 * Run: node tools/level-editor/test-unit.mjs
 */

// DOM mocks — imported first so globalThis.document/window exist before any other module evaluates
import './test-dom-mocks.mjs';

// ES module imports
import { HEX_SIZE, HexMath } from './js/hex-math.js';
import { HexGrid, createTileData, createResourceInstance, loadMapIntoGrid, serializeGridToMapJson } from './js/hex-grid.js';
import { TresParser, TresFile, generateTresUid } from './js/tres-parser.js';
import { ProjectContext } from './js/file-discovery.js';
import { CommandHistory, BatchCommand, SetBiomeCommand, SetElevationCommand, EraseContentCommand, DeleteHexCommand, AddResourceCommand, EditResourceCommand, DeleteResourceCommand, SetStructureCommand, SetAnomalyCommand, SetSpawnCommand } from './js/commands.js';
import { KeyboardManager } from './js/keyboard.js';
import { DirtyTracker } from './js/dirty-tracker.js';
import { ToolType, ElevationMode, ToolManager, BiomeBrush, ElevationBrush, FloodFillTool, EraserTool, ResourcePlacer, StructurePlacer, SpawnMarker, DeleteHexTool } from './js/tools.js';
import { HexCanvas, BIOME_FALLBACK_COLOR } from './js/canvas.js';

// Alias HexGrid as HexGridClass to match existing test usage
const HexGridClass = HexGrid;

let passed = 0;
let failed = 0;

function assert(condition, msg) {
  if (condition) {
    passed++;
  } else {
    failed++;
    console.error(`  FAIL: ${msg}`);
  }
}

function test(name, fn) {
  try {
    fn();
    console.log(`PASS: ${name}`);
  } catch (err) {
    failed++;
    console.error(`FAIL: ${name} — ${err.message}`);
  }
}

// ============================================================
// CommandHistory tests
// ============================================================

test('CommandHistory — execute calls cmd.execute and pushes to undo', () => {
  const ch = new CommandHistory();
  let executed = false;
  const cmd = { type: 'test', tab: 'map', execute() { executed = true; }, undo() {} };
  ch.execute(cmd);
  assert(executed, 'command.execute() should be called');
  assert(ch.undoStack.length === 1, 'undo stack should have 1 entry');
  assert(ch.redoStack.length === 0, 'redo stack should be empty');
});

test('CommandHistory — execute clears redo stack', () => {
  const ch = new CommandHistory();
  const cmd1 = { type: 'a', tab: 'map', execute() {}, undo() {} };
  const cmd2 = { type: 'b', tab: 'map', execute() {}, undo() {} };
  ch.execute(cmd1);
  ch.undo();
  assert(ch.redoStack.length === 1, 'redo should have 1 entry after undo');
  ch.execute(cmd2);
  assert(ch.redoStack.length === 0, 'redo should be empty after new execute');
});

test('CommandHistory — undo/redo cycle', () => {
  const ch = new CommandHistory();
  let val = 0;
  const cmd = {
    type: 'set', tab: 'map',
    execute() { val = 1; },
    undo() { val = 0; },
  };
  ch.execute(cmd);
  assert(val === 1, 'val should be 1 after execute');
  ch.undo();
  assert(val === 0, 'val should be 0 after undo');
  assert(ch.redoStack.length === 1, 'redo should have 1 entry');
  ch.redo();
  assert(val === 1, 'val should be 1 after redo');
});

test('CommandHistory — undo is no-op when empty', () => {
  const ch = new CommandHistory();
  ch.undo(); // Should not throw
  assert(ch.undoStack.length === 0, 'undo stack stays empty');
});

test('CommandHistory — redo is no-op when empty', () => {
  const ch = new CommandHistory();
  ch.redo(); // Should not throw
  assert(ch.redoStack.length === 0, 'redo stack stays empty');
});

test('CommandHistory — maxSize enforces 50 limit (51st drops oldest)', () => {
  const ch = new CommandHistory();
  for (let i = 0; i < 51; i++) {
    ch.execute({ type: `cmd_${i}`, tab: 'map', execute() {}, undo() {} });
  }
  assert(ch.undoStack.length === 50, 'undo stack should be capped at 50');
  assert(ch.undoStack[0].type === 'cmd_1', 'oldest (cmd_0) should be dropped');
});

test('CommandHistory — onChange fires with correct action', () => {
  const ch = new CommandHistory();
  const calls = [];
  ch.onChange = (action, cmd) => calls.push({ action, type: cmd ? cmd.type : null });
  const cmd = { type: 'test', tab: 'map', execute() {}, undo() {} };
  ch.execute(cmd);
  ch.undo();
  ch.redo();
  assert(calls.length === 3, 'onChange should fire 3 times');
  assert(calls[0].action === 'execute', 'first call should be execute');
  assert(calls[1].action === 'undo', 'second call should be undo');
  assert(calls[2].action === 'redo', 'third call should be redo');
});

test('CommandHistory — canUndo/canRedo', () => {
  const ch = new CommandHistory();
  assert(!ch.canUndo(), 'canUndo should be false when empty');
  assert(!ch.canRedo(), 'canRedo should be false when empty');
  ch.execute({ type: 'x', tab: 'map', execute() {}, undo() {} });
  assert(ch.canUndo(), 'canUndo should be true after execute');
  ch.undo();
  assert(ch.canRedo(), 'canRedo should be true after undo');
});

test('CommandHistory — clear empties both stacks', () => {
  const ch = new CommandHistory();
  ch.execute({ type: 'x', tab: 'map', execute() {}, undo() {} });
  ch.undo();
  ch.clear();
  assert(ch.undoStack.length === 0, 'undo should be empty');
  assert(ch.redoStack.length === 0, 'redo should be empty');
});

// ============================================================
// DirtyTracker tests
// ============================================================

test('DirtyTracker — markDirty/isDirty/hasUnsavedChanges', () => {
  const dt = new DirtyTracker();
  assert(!dt.isDirty('map'), 'map should not be dirty initially');
  assert(!dt.hasUnsavedChanges(), 'no unsaved changes initially');
  dt.markDirty('map');
  assert(dt.isDirty('map'), 'map should be dirty after markDirty');
  assert(dt.hasUnsavedChanges(), 'hasUnsavedChanges should be true');
});

test('DirtyTracker — markClean', () => {
  const dt = new DirtyTracker();
  dt.markDirty('map');
  dt.markClean('map');
  assert(!dt.isDirty('map'), 'map should be clean after markClean');
});

test('DirtyTracker — markAllClean', () => {
  const dt = new DirtyTracker();
  dt.markDirty('map');
  dt.markDirty('resources');
  dt.markDirty('biomes');
  dt.markAllClean();
  assert(!dt.hasUnsavedChanges(), 'all should be clean after markAllClean');
});

test('DirtyTracker — onChange fires', () => {
  const dt = new DirtyTracker();
  let called = 0;
  dt.onChange = () => called++;
  dt.markDirty('map');
  assert(called === 1, 'onChange should fire on markDirty');
  dt.markClean('map');
  assert(called === 2, 'onChange should fire on markClean');
});

test('DirtyTracker — markDirty no-op if already dirty', () => {
  const dt = new DirtyTracker();
  let called = 0;
  dt.onChange = () => called++;
  dt.markDirty('map');
  dt.markDirty('map');
  assert(called === 1, 'onChange should only fire once for duplicate markDirty');
});

// ============================================================
// TresParser value parsing tests
// ============================================================

test('TresParser — parseValue stringname', () => {
  const v = TresParser.parseValue('&"wood"');
  assert(v.type === 'stringname', 'type should be stringname');
  assert(v.value === 'wood', 'value should be wood');
});

test('TresParser — parseValue string', () => {
  const v = TresParser.parseValue('"Forest"');
  assert(v.type === 'string', 'type should be string');
  assert(v.value === 'Forest', 'value should be Forest');
});

test('TresParser — parseValue int', () => {
  const v = TresParser.parseValue('42');
  assert(v.type === 'int', 'type should be int');
  assert(v.value === 42, 'value should be 42');
});

test('TresParser — parseValue float', () => {
  const v = TresParser.parseValue('1.0');
  assert(v.type === 'float', 'type should be float');
  assert(v.value === 1.0, 'value should be 1.0');
});

test('TresParser — parseValue bool true', () => {
  const v = TresParser.parseValue('true');
  assert(v.type === 'bool', 'type should be bool');
  assert(v.value === true, 'value should be true');
});

test('TresParser — parseValue bool false', () => {
  const v = TresParser.parseValue('false');
  assert(v.type === 'bool', 'type should be bool');
  assert(v.value === false, 'value should be false');
});

test('TresParser — parseValue Color', () => {
  const v = TresParser.parseValue('Color(0.2, 0.7, 0.2, 1.0)');
  assert(v.type === 'color', 'type should be color');
  assert(v.value.r === 0.2, 'r should be 0.2');
  assert(v.value.a === 1.0, 'a should be 1.0');
});

test('TresParser — parseValue Vector2i', () => {
  const v = TresParser.parseValue('Vector2i(0, 9)');
  assert(v.type === 'vector2i', 'type should be vector2i');
  assert(v.value.x === 0, 'x should be 0');
  assert(v.value.y === 9, 'y should be 9');
});

test('TresParser — parseValue ExtResource', () => {
  const v = TresParser.parseValue('ExtResource("1_script")');
  assert(v.type === 'ext_resource', 'type should be ext_resource');
  assert(v.value === 'ExtResource("1_script")', 'value should be verbatim');
});

test('TresParser — parseValue empty dict', () => {
  const v = TresParser.parseValue('{}');
  assert(v.type === 'dict', 'type should be dict');
  assert(v.value.size === 0, 'should be empty map');
});

test('TresParser — parseValue stringname-keyed dict', () => {
  const v = TresParser.parseValue('{ &"stone_axe": 0.5 }');
  assert(v.type === 'dict', 'type should be dict');
  assert(v.keyStyle === 'stringname', 'keyStyle should be stringname');
  assert(v.value.get('stone_axe').value === 0.5, 'should have stone_axe = 0.5');
});

test('TresParser — parseValue string-keyed dict', () => {
  const v = TresParser.parseValue('{"radius": 0.3}');
  assert(v.type === 'dict', 'type should be dict');
  assert(v.keyStyle === 'string', 'keyStyle should be string');
  assert(v.value.get('radius').value === 0.3, 'should have radius = 0.3');
});

test('TresParser — parseValue empty array', () => {
  const v = TresParser.parseValue('[]');
  assert(v.type === 'array', 'type should be array');
  assert(v.value.length === 0, 'should be empty');
  assert(v.elementType === null, 'elementType should be null');
});

test('TresParser — parseValue PackedStringArray', () => {
  const v = TresParser.parseValue('PackedStringArray("a", "b", "c")');
  assert(v.type === 'packed_string_array', 'type should be packed_string_array');
  assert(v.value.length === 3, 'should have 3 values');
  assert(v.value[0] === 'a', 'first should be a');
});

test('TresParser — parseValue empty PackedStringArray', () => {
  const v = TresParser.parseValue('PackedStringArray()');
  assert(v.type === 'packed_string_array', 'type should be packed_string_array');
  assert(v.value.length === 0, 'should be empty');
});

// ============================================================
// TresParser serialization round-trips
// ============================================================

test('TresParser — serializeValue round-trips all types', () => {
  const cases = [
    '&"wood"',
    '"Forest"',
    '42',
    '1.0',
    'true',
    'false',
    'Color(0.2, 0.7, 0.2, 1.0)',
    'Vector2i(0, 9)',
    'ExtResource("1_script")',
    '{}',
    '{ &"stone_axe": 0.5 }',
    '{"radius": 0.3}',
    '[]',
    'PackedStringArray("a", "b")',
    'PackedStringArray()',
  ];
  for (const input of cases) {
    const parsed = TresParser.parseValue(input);
    const serialized = TresParser.serializeValue(parsed);
    assert(serialized === input, `round-trip failed for "${input}" — got "${serialized}"`);
  }
});

test('TresParser — float serialization always has decimal', () => {
  const v = { type: 'float', value: 1 };
  assert(TresParser.serializeValue(v) === '1.0', 'should be 1.0');
  const v2 = { type: 'float', value: 3.5 };
  assert(TresParser.serializeValue(v2) === '3.5', 'should be 3.5');
});

// ============================================================
// generateTresUid tests
// ============================================================

test('generateTresUid — format: uid://c + 13 chars', () => {
  const uid = generateTresUid();
  assert(uid.startsWith('uid://c'), 'should start with uid://c');
  assert(uid.length === 7 + 13, 'should be 20 chars total');
  const suffix = uid.slice(7);
  assert(/^[a-z0-9]{13}$/.test(suffix), 'suffix should be 13 lowercase alphanumeric');
});

test('generateTresUid — uniqueness (100 uids)', () => {
  const uids = new Set();
  for (let i = 0; i < 100; i++) {
    uids.add(generateTresUid());
  }
  assert(uids.size === 100, 'all 100 uids should be unique');
});

// ============================================================
// HexMath tests (task-007)
// ============================================================

test('HexMath — axialToPixel and pixelToAxial round-trip for integer coords', () => {
  const coords = [
    { q: 0, r: 0 }, { q: 1, r: 0 }, { q: 0, r: 1 },
    { q: -1, r: 0 }, { q: 2, r: -1 }, { q: -3, r: 5 },
    { q: 10, r: -7 }, { q: -5, r: -5 },
  ];
  for (const c of coords) {
    const px = HexMath.axialToPixel(c.q, c.r);
    const back = HexMath.pixelToAxial(px.x, px.y);
    assert(back.q === c.q && back.r === c.r,
      `round-trip failed for (${c.q},${c.r}) — got (${back.q},${back.r})`);
  }
});

test('HexMath — getNeighbors returns exactly 6 with correct flat-top directions', () => {
  const neighbors = HexMath.getNeighbors(0, 0);
  assert(neighbors.length === 6, 'should have 6 neighbors');
  const expected = [
    { q: 1, r: 0 }, { q: 1, r: -1 }, { q: 0, r: -1 },
    { q: -1, r: 0 }, { q: -1, r: 1 }, { q: 0, r: 1 },
  ];
  for (let i = 0; i < 6; i++) {
    assert(neighbors[i].q === expected[i].q && neighbors[i].r === expected[i].r,
      `neighbor ${i}: expected (${expected[i].q},${expected[i].r}), got (${neighbors[i].q},${neighbors[i].r})`);
  }
});

test('HexMath — cubeRound snaps fractional coordinates correctly', () => {
  // Exact center
  const exact = HexMath.cubeRound(1.0, 0.0);
  assert(exact.q === 1 && exact.r === 0, 'exact should be (1,0)');
  // Slightly off center
  const near = HexMath.cubeRound(0.9, 0.1);
  assert(near.q === 1 && near.r === 0, 'near (0.9,0.1) should snap to (1,0)');
  // Origin
  const origin = HexMath.cubeRound(0.1, -0.1);
  assert(origin.q === 0 && origin.r === 0, 'near-origin should snap to (0,0)');
});

test('HexMath — hexCorners returns 6 points forming a valid flat-top hexagon', () => {
  const corners = HexMath.hexCorners(100, 100, 40);
  assert(corners.length === 6, 'should have 6 corners');
  // First corner of flat-top hex should be at (cx + size, cy) = (140, 100)
  assert(Math.abs(corners[0].x - 140) < 0.01, 'first corner x should be cx + size');
  assert(Math.abs(corners[0].y - 100) < 0.01, 'first corner y should be cy');
  // All corners should be at distance = size from center
  for (let i = 0; i < 6; i++) {
    const dx = corners[i].x - 100;
    const dy = corners[i].y - 100;
    const dist = Math.sqrt(dx * dx + dy * dy);
    assert(Math.abs(dist - 40) < 0.01, `corner ${i} should be at distance 40 from center, got ${dist}`);
  }
});

test('HexMath — distance', () => {
  assert(HexMath.distance(0, 0, 0, 0) === 0, 'same hex = 0');
  assert(HexMath.distance(0, 0, 1, 0) === 1, 'adjacent = 1');
  assert(HexMath.distance(0, 0, 2, -1) === 2, 'two steps = 2');
  assert(HexMath.distance(0, 0, 3, 0) === 3, 'three east = 3');
});

test('HexMath — getEdgeIndex', () => {
  // East neighbor
  assert(HexMath.getEdgeIndex(0, 0, 1, 0) === 0, 'east should be edge 0');
  // NE neighbor
  assert(HexMath.getEdgeIndex(0, 0, 1, -1) === 1, 'NE should be edge 1');
  // Non-adjacent
  assert(HexMath.getEdgeIndex(0, 0, 2, 0) === -1, 'non-adjacent should be -1');
});

// ============================================================
// HexGrid tests (task-007)
// ============================================================

test('HexGrid — setTile/getTile/hasTile/deleteTile', () => {
  const grid = new HexGridClass();
  const tile = createTileData('forest');
  grid.setTile(1, 2, tile);
  assert(grid.hasTile(1, 2), 'should have tile (1,2)');
  assert(grid.getTile(1, 2).biome === 'forest', 'biome should be forest');
  assert(!grid.hasTile(3, 4), 'should not have tile (3,4)');
  grid.deleteTile(1, 2);
  assert(!grid.hasTile(1, 2), 'should not have tile after delete');
});

test('HexGrid — onChange fires on setTile and deleteTile', () => {
  const grid = new HexGridClass();
  let calls = 0;
  grid.onChange = () => calls++;
  grid.setTile(0, 0, createTileData('water'));
  assert(calls === 1, 'onChange should fire on setTile');
  grid.deleteTile(0, 0);
  assert(calls === 2, 'onChange should fire on deleteTile');
});

test('HexGrid — getKey format', () => {
  const grid = new HexGridClass();
  assert(grid.getKey(3, -2) === '3,-2', 'key should be "3,-2"');
  assert(grid.getKey(0, 0) === '0,0', 'key should be "0,0"');
});

test('HexGrid — getAllTiles iterator', () => {
  const grid = new HexGridClass();
  grid.setTile(0, 0, createTileData('a'));
  grid.setTile(1, 1, createTileData('b'));
  let count = 0;
  for (const [key, tile] of grid.getAllTiles()) {
    count++;
  }
  assert(count === 2, 'should iterate 2 tiles');
});

test('HexGrid — clear removes all tiles', () => {
  const grid = new HexGridClass();
  grid.setTile(0, 0, createTileData('a'));
  grid.setTile(1, 1, createTileData('b'));
  grid.clear();
  assert(grid.tiles.size === 0, 'tiles should be empty after clear');
});

test('loadMapIntoGrid — loads legacy map JSON correctly (x,y resources, string structure)', () => {
  const grid = new HexGridClass();
  const mapData = {
    chapter_id: 'ch1',
    name: 'Test Map',
    spawn: [2, 3],
    tiles: {
      '0,0': { biome: 'forest', elevation: 2, resources: [{ type: 'wood', x: 0.1, y: 0.2, rotation: 45 }] },
      '1,-1': { biome: 'water', elevation: 0, structure: 'campfire', resources: [] },
    },
  };
  loadMapIntoGrid(grid, mapData);
  assert(grid.meta.chapter_id === 'ch1', 'chapter_id should match');
  assert(grid.meta.name === 'Test Map', 'name should match');
  assert(grid.meta.spawn[0] === 2 && grid.meta.spawn[1] === 3, 'spawn should match');
  assert(grid.hasTile(0, 0), 'should have tile 0,0');
  assert(grid.getTile(0, 0).biome === 'forest', 'biome should be forest');
  assert(grid.getTile(0, 0).elevation === 2, 'elevation should be 2');
  assert(grid.getTile(0, 0).resources.length === 1, 'should have 1 resource');
  assert(grid.getTile(0, 0).resources[0].type === 'wood', 'resource type should be wood');
  assert(typeof grid.getTile(0, 0).resources[0].sq === 'number', 'resource should have sq');
  assert(typeof grid.getTile(0, 0).resources[0].sr === 'number', 'resource should have sr');
  // Legacy string structure should be converted to object
  assert(grid.getTile(1, -1).structure !== null, 'structure should exist');
  assert(grid.getTile(1, -1).structure.type === 'campfire', 'structure type should be campfire');
  assert(Array.isArray(grid.getTile(1, -1).structure.sub_hexes), 'structure should have sub_hexes');
});

test('loadMapIntoGrid — loads new format (sq,sr resources, object structure)', () => {
  const grid = new HexGridClass();
  const mapData = {
    chapter_id: 'ch2',
    name: 'New Map',
    spawn: [0, 0],
    tiles: {
      '0,0': { biome: 'forest', elevation: 1, resources: [{ type: 'stone', sq: 1, sr: -1, rotation: 90 }],
               structure: { type: 'workbench', sub_hexes: [{ sq: 0, sr: 0 }] } },
    },
  };
  loadMapIntoGrid(grid, mapData);
  const tile = grid.getTile(0, 0);
  assert(tile.resources[0].sq === 1, 'sq should be 1');
  assert(tile.resources[0].sr === -1, 'sr should be -1');
  assert(tile.structure.type === 'workbench', 'structure type should be workbench');
  assert(tile.structure.sub_hexes[0].sq === 0, 'structure sub_hex sq should be 0');
});

// ============================================================
// Command classes tests (task-009/task-010)
// ============================================================

test('SetBiomeCommand — execute and undo', () => {
  const grid = new HexGridClass();
  grid.setTile(0, 0, createTileData('forest'));
  const cmd = new SetBiomeCommand(grid, 0, 0, 'forest', 'water');
  cmd.execute();
  assert(grid.getTile(0, 0).biome === 'water', 'biome should be water after execute');
  cmd.undo();
  assert(grid.getTile(0, 0).biome === 'forest', 'biome should be forest after undo');
});

test('SetBiomeCommand — creates tile if none exists', () => {
  const grid = new HexGridClass();
  const cmd = new SetBiomeCommand(grid, 5, 5, '', 'grassland');
  cmd.execute();
  assert(grid.hasTile(5, 5), 'tile should be created');
  assert(grid.getTile(5, 5).biome === 'grassland', 'biome should be grassland');
});

test('SetElevationCommand — execute and undo', () => {
  const grid = new HexGridClass();
  grid.setTile(0, 0, createTileData('forest'));
  grid.getTile(0, 0).elevation = 3;
  const cmd = new SetElevationCommand(grid, 0, 0, 3, 7);
  cmd.execute();
  assert(grid.getTile(0, 0).elevation === 7, 'elevation should be 7');
  cmd.undo();
  assert(grid.getTile(0, 0).elevation === 3, 'elevation should be 3 after undo');
});

test('BatchCommand — execute and undo in correct order', () => {
  const grid = new HexGridClass();
  grid.setTile(0, 0, createTileData('a'));
  grid.setTile(1, 0, createTileData('b'));
  const cmd1 = new SetBiomeCommand(grid, 0, 0, 'a', 'x');
  const cmd2 = new SetBiomeCommand(grid, 1, 0, 'b', 'y');
  const batch = new BatchCommand([cmd1, cmd2]);
  batch.execute();
  assert(grid.getTile(0, 0).biome === 'x', '0,0 should be x');
  assert(grid.getTile(1, 0).biome === 'y', '1,0 should be y');
  batch.undo();
  assert(grid.getTile(0, 0).biome === 'a', '0,0 should be a after undo');
  assert(grid.getTile(1, 0).biome === 'b', '1,0 should be b after undo');
});

test('EraseContentCommand — erases resources/structure/anomaly but preserves hex', () => {
  const grid = new HexGridClass();
  const tile = createTileData('forest');
  tile.elevation = 5;
  tile.structure = { type: 'workbench', sub_hexes: [{ sq: 0, sr: 0 }] };
  tile.anomaly = 'test_anomaly';
  tile.resources = [createResourceInstance('wood', 0, 0, 45)];
  grid.setTile(0, 0, tile);

  const cmd = new EraseContentCommand(grid, 0, 0, tile);
  cmd.execute();
  const after = grid.getTile(0, 0);
  assert(after.resources.length === 0, 'resources should be empty');
  assert(after.structure === null, 'structure should be null');
  assert(after.anomaly === null, 'anomaly should be null');
  assert(after.biome === 'forest', 'biome should be preserved');
  assert(after.elevation === 5, 'elevation should be preserved');

  cmd.undo();
  const restored = grid.getTile(0, 0);
  assert(restored.resources.length === 1, 'resources should be restored');
  assert(restored.structure !== null && restored.structure.type === 'workbench', 'structure should be restored');
  assert(restored.anomaly === 'test_anomaly', 'anomaly should be restored');
});

test('DeleteHexCommand — deletes and restores hex', () => {
  const grid = new HexGridClass();
  const tile = createTileData('water');
  tile.elevation = 3;
  grid.setTile(2, 2, tile);

  const cmd = new DeleteHexCommand(grid, 2, 2, tile);
  cmd.execute();
  assert(!grid.hasTile(2, 2), 'tile should be deleted');
  cmd.undo();
  assert(grid.hasTile(2, 2), 'tile should be restored');
  assert(grid.getTile(2, 2).biome === 'water', 'biome should be water');
  assert(grid.getTile(2, 2).elevation === 3, 'elevation should be 3');
});

test('SetStructureCommand — execute and undo', () => {
  const grid = new HexGridClass();
  grid.setTile(0, 0, createTileData('forest'));
  const newStruct = { type: 'campfire', sub_hexes: [{ sq: 0, sr: 0 }] };
  const cmd = new SetStructureCommand(grid, 0, 0, null, newStruct);
  cmd.execute();
  assert(grid.getTile(0, 0).structure !== null, 'structure should exist');
  assert(grid.getTile(0, 0).structure.type === 'campfire', 'structure type should be campfire');
  cmd.undo();
  assert(grid.getTile(0, 0).structure === null, 'structure should be null after undo');
});

test('SetAnomalyCommand — execute and undo', () => {
  const grid = new HexGridClass();
  grid.setTile(0, 0, createTileData('forest'));
  const cmd = new SetAnomalyCommand(grid, 0, 0, null, 'anomaly_01');
  cmd.execute();
  assert(grid.getTile(0, 0).anomaly === 'anomaly_01', 'anomaly should be set');
  cmd.undo();
  assert(grid.getTile(0, 0).anomaly === null, 'anomaly should be null after undo');
});

test('SetSpawnCommand — execute and undo', () => {
  const grid = new HexGridClass();
  grid.meta.spawn = [0, 0];
  const cmd = new SetSpawnCommand(grid, [0, 0], [5, 3]);
  cmd.execute();
  assert(grid.meta.spawn[0] === 5 && grid.meta.spawn[1] === 3, 'spawn should be [5,3]');
  cmd.undo();
  assert(grid.meta.spawn[0] === 0 && grid.meta.spawn[1] === 0, 'spawn should be [0,0] after undo');
});

test('AddResourceCommand — execute and undo', () => {
  const grid = new HexGridClass();
  grid.setTile(0, 0, createTileData('forest'));
  const res = createResourceInstance('wood', 1, -1, 90);
  const cmd = new AddResourceCommand(grid, 0, 0, res);
  cmd.execute();
  assert(grid.getTile(0, 0).resources.length === 1, 'should have 1 resource');
  assert(grid.getTile(0, 0).resources[0].type === 'wood', 'resource type should be wood');
  assert(grid.getTile(0, 0).resources[0].sq === 1, 'sq should be 1');
  assert(grid.getTile(0, 0).resources[0].sr === -1, 'sr should be -1');
  cmd.undo();
  assert(grid.getTile(0, 0).resources.length === 0, 'should have 0 resources after undo');
});

test('EditResourceCommand — execute and undo', () => {
  const grid = new HexGridClass();
  const tile = createTileData('forest');
  tile.resources = [createResourceInstance('wood', 1, 0, 90)];
  grid.setTile(0, 0, tile);
  const cmd = new EditResourceCommand(grid, 0, 0, 0, { sq: 1 }, { sq: -1 });
  cmd.execute();
  assert(grid.getTile(0, 0).resources[0].sq === -1, 'sq should be -1');
  cmd.undo();
  assert(grid.getTile(0, 0).resources[0].sq === 1, 'sq should be 1 after undo');
});

test('DeleteResourceCommand — execute and undo', () => {
  const grid = new HexGridClass();
  const tile = createTileData('forest');
  tile.resources = [
    createResourceInstance('wood', 0, 0, 90),
    createResourceInstance('stone', 1, 0, 180),
  ];
  grid.setTile(0, 0, tile);
  const removed = { ...tile.resources[0] };
  const cmd = new DeleteResourceCommand(grid, 0, 0, 0, removed);
  cmd.execute();
  assert(grid.getTile(0, 0).resources.length === 1, 'should have 1 resource');
  assert(grid.getTile(0, 0).resources[0].type === 'stone', 'remaining should be stone');
  cmd.undo();
  assert(grid.getTile(0, 0).resources.length === 2, 'should have 2 resources after undo');
  assert(grid.getTile(0, 0).resources[0].type === 'wood', 'first should be wood again');
});

// ============================================================
// ToolManager tests (task-009)
// ============================================================

test('ToolManager — setTool creates correct tool instances', () => {
  const grid = new HexGridClass();
  const ch = new CommandHistory();
  const tm = new ToolManager(grid, ch);

  tm.setTool('biome', 'forest');
  assert(tm.activeToolType === 'biome', 'activeToolType should be biome');
  assert(tm.activeValue === 'forest', 'activeValue should be forest');
  assert(tm.activeTool instanceof BiomeBrush, 'should be BiomeBrush');

  tm.setTool('elevation');
  assert(tm.activeTool instanceof ElevationBrush, 'should be ElevationBrush');

  tm.setTool('flood_fill', 'water');
  assert(tm.activeTool instanceof FloodFillTool, 'should be FloodFillTool');

  tm.setTool('eraser');
  assert(tm.activeTool instanceof EraserTool, 'should be EraserTool');

  tm.setTool('resource', 'wood');
  assert(tm.activeTool instanceof ResourcePlacer, 'should be ResourcePlacer');

  tm.setTool('structure', 'campfire');
  assert(tm.activeTool instanceof StructurePlacer, 'should be StructurePlacer');

  tm.setTool('spawn');
  assert(tm.activeTool instanceof SpawnMarker, 'should be SpawnMarker');

  tm.setTool('delete_hex');
  assert(tm.activeTool instanceof DeleteHexTool, 'should be DeleteHexTool');

  tm.setTool(null);
  assert(tm.activeTool === null, 'should be null when no tool');
});

test('ToolManager — delegates mouse events to active tool', () => {
  const grid = new HexGridClass();
  grid.setTile(0, 0, createTileData('forest'));
  const ch = new CommandHistory();
  const tm = new ToolManager(grid, ch);
  tm.setTool('biome', 'water');
  tm.onMouseDown({ q: 0, r: 0 });
  tm.onMouseUp({ q: 0, r: 0 });
  assert(grid.getTile(0, 0).biome === 'water', 'biome should change to water via mouse event');
});

// ============================================================
// BiomeBrush drag -> BatchCommand test (task-009)
// ============================================================

test('BiomeBrush — drag creates BatchCommand for single undo', () => {
  const grid = new HexGridClass();
  grid.setTile(0, 0, createTileData('forest'));
  grid.setTile(1, 0, createTileData('forest'));
  grid.setTile(2, 0, createTileData('forest'));
  const ch = new CommandHistory();
  const tm = new ToolManager(grid, ch);
  tm.setTool('biome', 'water');

  tm.onMouseDown({ q: 0, r: 0 });
  tm.onMouseMove({ q: 1, r: 0 });
  tm.onMouseMove({ q: 2, r: 0 });
  tm.onMouseUp({ q: 2, r: 0 });

  // All three hexes should be water
  assert(grid.getTile(0, 0).biome === 'water', '0,0 should be water');
  assert(grid.getTile(1, 0).biome === 'water', '1,0 should be water');
  assert(grid.getTile(2, 0).biome === 'water', '2,0 should be water');

  // Single undo should revert all
  ch.undo();
  assert(grid.getTile(0, 0).biome === 'forest', '0,0 should be forest after undo');
  assert(grid.getTile(1, 0).biome === 'forest', '1,0 should be forest after undo');
  assert(grid.getTile(2, 0).biome === 'forest', '2,0 should be forest after undo');
});

// ============================================================
// ElevationBrush tests (task-009)
// ============================================================

test('ElevationBrush — SET mode sets exact value, clamped to [0,9]', () => {
  const grid = new HexGridClass();
  grid.setTile(0, 0, createTileData('forest'));
  const ch = new CommandHistory();
  const tm = new ToolManager(grid, ch);
  tm.setTool('elevation');
  tm.elevationMode = ElevationMode.SET;
  tm.elevationValue = 5;

  tm.onMouseDown({ q: 0, r: 0 });
  tm.onMouseUp({ q: 0, r: 0 });
  assert(grid.getTile(0, 0).elevation === 5, 'elevation should be 5');

  // Clamping
  tm.elevationValue = 15;
  tm.setTool('elevation'); // reset tool for fresh paintedHexes
  tm.elevationMode = ElevationMode.SET;
  tm.elevationValue = 15;
  tm.onMouseDown({ q: 0, r: 0 });
  tm.onMouseUp({ q: 0, r: 0 });
  assert(grid.getTile(0, 0).elevation === 9, 'elevation should clamp to 9');
});

test('ElevationBrush — INCREMENT mode adds/subtracts 1', () => {
  const grid = new HexGridClass();
  const tile = createTileData('forest');
  tile.elevation = 3;
  grid.setTile(0, 0, tile);
  const ch = new CommandHistory();
  const tm = new ToolManager(grid, ch);
  tm.setTool('elevation');
  tm.elevationMode = ElevationMode.INCREMENT;
  tm.elevationDelta = 1;

  tm.onMouseDown({ q: 0, r: 0 });
  tm.onMouseUp({ q: 0, r: 0 });
  assert(grid.getTile(0, 0).elevation === 4, 'elevation should be 4 after +1');

  tm.setTool('elevation');
  tm.elevationMode = ElevationMode.INCREMENT;
  tm.elevationDelta = -1;
  tm.onMouseDown({ q: 0, r: 0 });
  tm.onMouseUp({ q: 0, r: 0 });
  assert(grid.getTile(0, 0).elevation === 3, 'elevation should be 3 after -1');
});

// ============================================================
// FloodFill tests (task-009)
// ============================================================

test('FloodFill — fills contiguous same-biome region', () => {
  const grid = new HexGridClass();
  // Create a small cluster of forest hexes
  grid.setTile(0, 0, createTileData('forest'));
  grid.setTile(1, 0, createTileData('forest'));
  grid.setTile(0, 1, createTileData('forest'));
  grid.setTile(1, -1, createTileData('water')); // blocker
  const ch = new CommandHistory();
  const tm = new ToolManager(grid, ch);
  tm.setTool('flood_fill', 'grassland');

  tm.onMouseDown({ q: 0, r: 0 });
  assert(grid.getTile(0, 0).biome === 'grassland', '0,0 should be grassland');
  assert(grid.getTile(1, 0).biome === 'grassland', '1,0 should be grassland');
  assert(grid.getTile(0, 1).biome === 'grassland', '0,1 should be grassland');
  assert(grid.getTile(1, -1).biome === 'water', '1,-1 should still be water');

  // Single undo should revert all
  ch.undo();
  assert(grid.getTile(0, 0).biome === 'forest', '0,0 should be forest after undo');
  assert(grid.getTile(1, 0).biome === 'forest', '1,0 should be forest after undo');
});

test('FloodFill — no-op when target biome equals start biome', () => {
  const grid = new HexGridClass();
  grid.setTile(0, 0, createTileData('forest'));
  const ch = new CommandHistory();
  const tm = new ToolManager(grid, ch);
  tm.setTool('flood_fill', 'forest');
  tm.onMouseDown({ q: 0, r: 0 });
  assert(ch.undoStack.length === 0, 'no command should be created');
});

// ============================================================
// Placement tools tests (task-010)
// ============================================================

test('SpawnMarker — moves spawn, single spawn enforced', () => {
  const grid = new HexGridClass();
  grid.setTile(0, 0, createTileData('forest'));
  grid.setTile(3, 3, createTileData('water'));
  grid.meta.spawn = [0, 0];
  const ch = new CommandHistory();
  const tm = new ToolManager(grid, ch);
  tm.setTool('spawn');
  tm.onMouseDown({ q: 3, r: 3 });
  assert(grid.meta.spawn[0] === 3 && grid.meta.spawn[1] === 3, 'spawn should be [3,3]');
  ch.undo();
  assert(grid.meta.spawn[0] === 0 && grid.meta.spawn[1] === 0, 'spawn should be [0,0] after undo');
});

test('DeleteHexTool — removes tile, undo restores', () => {
  const grid = new HexGridClass();
  const tile = createTileData('water');
  tile.elevation = 4;
  tile.structure = { type: 'torch', sub_hexes: [{ sq: 0, sr: 0 }] };
  grid.setTile(1, 1, tile);
  const ch = new CommandHistory();
  const tm = new ToolManager(grid, ch);
  tm.setTool('delete_hex');
  tm.onMouseDown({ q: 1, r: 1 });
  assert(!grid.hasTile(1, 1), 'tile should be deleted');
  ch.undo();
  assert(grid.hasTile(1, 1), 'tile should be restored');
  assert(grid.getTile(1, 1).biome === 'water', 'biome should be restored');
  assert(grid.getTile(1, 1).structure !== null && grid.getTile(1, 1).structure.type === 'torch', 'structure should be restored');
});

// ============================================================
// Summary
// ============================================================

console.log(`\n${passed + failed} assertions: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
