/**
 * Unit tests for delivery-001 classes: CommandHistory, DirtyTracker, TresParser, KeyboardManager.
 * Run: node tools/level-editor/test-unit.mjs
 */

// DOM mocks — imported first so globalThis.document/window exist before any other module evaluates
import './test-dom-mocks.mjs';

// ES module imports
import { HEX_SIZE, HexMath } from './js/hex-math.js';
import { HexGrid, createTileData, createProp, loadMapIntoGrid, serializeGridToMapJson, CATEGORIES, ORIGINS, CATEGORY_COLORS, CATEGORY_TO_INT, INT_TO_CATEGORY } from './js/hex-grid.js';
import { validateMap } from './js/validator.js';
import { TresParser, TresFile, generateTresUid } from './js/tres-parser.js';
import { ProjectContext } from './js/file-discovery.js';
import { CommandHistory, BatchCommand, SetBiomeCommand, SetElevationCommand, EraseContentCommand, DeleteHexCommand, AddPropCommand, EditPropCommand, DeletePropCommand, SetSpawnCommand } from './js/commands.js';
import { KeyboardManager } from './js/keyboard.js';
import { DirtyTracker } from './js/dirty-tracker.js';
import { ToolType, ElevationMode, ToolManager, BiomeBrush, ElevationBrush, FloodFillTool, EraserTool, PropPlacer, SpawnMarker, DeleteHexTool } from './js/tools.js';
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
  dt.markDirty('props');
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

test('loadMapIntoGrid — loads legacy map JSON correctly (x,y props, string structure)', () => {
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
  const resources00 = grid.getTile(0, 0).props.filter(p => p.category === 'resource');
  assert(resources00.length === 1, 'should have 1 resource prop');
  assert(resources00[0].type === 'wood', 'resource type should be wood');
  assert(typeof resources00[0].sq === 'number', 'resource should have sq');
  assert(typeof resources00[0].sr === 'number', 'resource should have sr');
  // Legacy string structure should be converted to structure prop
  const struct1 = grid.getTile(1, -1).props.find(p => p.category === 'structure');
  assert(struct1 !== undefined, 'structure prop should exist');
  assert(struct1.type === 'campfire', 'structure type should be campfire');
  assert(Array.isArray(struct1.footprint), 'structure should have footprint');
});

test('loadMapIntoGrid — loads new props format', () => {
  const grid = new HexGridClass();
  const mapData = {
    chapter_id: 'ch2',
    name: 'New Map',
    spawn: [0, 0],
    tiles: {
      '0,0': { biome: 'forest', elevation: 1, props: [
        { type: 'stone', sq: 1, sr: -1, category: 'mineral', rotation: 90 },
        { type: 'workbench', sq: 0, sr: 0, category: 'structure', footprint: [{ q: 0, r: 0 }] },
      ] },
    },
  };
  loadMapIntoGrid(grid, mapData);
  const tile = grid.getTile(0, 0);
  const minerals = tile.props.filter(p => p.category === 'mineral');
  assert(minerals[0].sq === 1, 'sq should be 1');
  assert(minerals[0].sr === -1, 'sr should be -1');
  const struct = tile.props.find(p => p.category === 'structure');
  assert(struct.type === 'workbench', 'structure type should be workbench');
  assert(struct.footprint[0].q === 0, 'structure footprint q should be 0');
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

test('EraseContentCommand — erases all props but preserves hex biome/elevation', () => {
  const grid = new HexGridClass();
  const tile = createTileData('forest');
  tile.elevation = 5;
  tile.props = [
    createProp('wood', 0, 0, 'plant', { rotation: 45 }),
    createProp('workbench', 0, 0, 'structure', { footprint: [{ q: 0, r: 0 }] }),
    createProp('scanner', 0, 0, 'equipment', { origin: 'unknown' }),
  ];
  grid.setTile(0, 0, tile);

  const cmd = new EraseContentCommand(grid, 0, 0, tile);
  cmd.execute();
  const after = grid.getTile(0, 0);
  assert(after.props.length === 0, 'props should be empty');
  assert(after.biome === 'forest', 'biome should be preserved');
  assert(after.elevation === 5, 'elevation should be preserved');

  cmd.undo();
  const restored = grid.getTile(0, 0);
  assert(restored.props.length === 3, 'props should be restored');
  assert(restored.props.find(p => p.category === 'plant').type === 'wood', 'plant should be restored');
  assert(restored.props.find(p => p.category === 'structure').type === 'workbench', 'structure should be restored');
  assert(restored.props.find(p => p.category === 'equipment').type === 'scanner', 'equipment should be restored');
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

test('AddPropCommand — add structure prop and undo', () => {
  const grid = new HexGridClass();
  grid.setTile(0, 0, createTileData('forest'));
  const structProp = createProp('campfire', 0, 0, 'structure', { footprint: [{ q: 0, r: 0 }] });
  const cmd = new AddPropCommand(grid, 0, 0, structProp);
  cmd.execute();
  const struct = grid.getTile(0, 0).props.find(p => p.category === 'structure');
  assert(struct !== undefined, 'structure prop should exist');
  assert(struct.type === 'campfire', 'structure type should be campfire');
  cmd.undo();
  assert(grid.getTile(0, 0).props.find(p => p.category === 'structure') === undefined, 'structure prop should be removed after undo');
});

test('AddPropCommand — add equipment prop and undo', () => {
  const grid = new HexGridClass();
  grid.setTile(0, 0, createTileData('forest'));
  const equipProp = createProp('scanner', 0, 0, 'equipment', { origin: 'unknown' });
  const cmd = new AddPropCommand(grid, 0, 0, equipProp);
  cmd.execute();
  const equip = grid.getTile(0, 0).props.find(p => p.category === 'equipment');
  assert(equip !== undefined, 'equipment prop should exist');
  assert(equip.type === 'scanner', 'equipment type should be scanner');
  cmd.undo();
  assert(grid.getTile(0, 0).props.find(p => p.category === 'equipment') === undefined, 'equipment prop should be removed after undo');
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

test('AddPropCommand — add plant prop and undo', () => {
  const grid = new HexGridClass();
  grid.setTile(0, 0, createTileData('forest'));
  const res = createProp('wood', 1, -1, 'plant', { rotation: 90 });
  const cmd = new AddPropCommand(grid, 0, 0, res);
  cmd.execute();
  const plants = grid.getTile(0, 0).props.filter(p => p.category === 'plant');
  assert(plants.length === 1, 'should have 1 plant');
  assert(plants[0].type === 'wood', 'plant type should be wood');
  assert(plants[0].sq === 1, 'sq should be 1');
  assert(plants[0].sr === -1, 'sr should be -1');
  cmd.undo();
  assert(grid.getTile(0, 0).props.filter(p => p.category === 'plant').length === 0, 'should have 0 plants after undo');
});

test('EditPropCommand — execute and undo', () => {
  const grid = new HexGridClass();
  const tile = createTileData('forest');
  tile.props = [createProp('wood', 1, 0, 'plant', { rotation: 90 })];
  grid.setTile(0, 0, tile);
  const cmd = new EditPropCommand(grid, 0, 0, 0, { sq: 1 }, { sq: -1 });
  cmd.execute();
  assert(grid.getTile(0, 0).props[0].sq === -1, 'sq should be -1');
  cmd.undo();
  assert(grid.getTile(0, 0).props[0].sq === 1, 'sq should be 1 after undo');
});

test('DeletePropCommand — execute and undo', () => {
  const grid = new HexGridClass();
  const tile = createTileData('forest');
  tile.props = [
    createProp('wood', 0, 0, 'plant', { rotation: 90 }),
    createProp('stone', 1, 0, 'mineral', { rotation: 180 }),
  ];
  grid.setTile(0, 0, tile);
  const removed = { ...tile.props[0] };
  const cmd = new DeletePropCommand(grid, 0, 0, 0, removed);
  cmd.execute();
  assert(grid.getTile(0, 0).props.length === 1, 'should have 1 prop');
  assert(grid.getTile(0, 0).props[0].type === 'stone', 'remaining should be stone');
  cmd.undo();
  assert(grid.getTile(0, 0).props.length === 2, 'should have 2 props after undo');
  assert(grid.getTile(0, 0).props[0].type === 'wood', 'first should be wood again');
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

  tm.setTool('prop', 'wood');
  assert(tm.activeTool instanceof PropPlacer, 'should be PropPlacer');

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

  // Clamping — elevation can go up to 32000 now
  tm.elevationValue = 40000;
  tm.setTool('elevation'); // reset tool for fresh paintedHexes
  tm.elevationMode = ElevationMode.SET;
  tm.elevationValue = 40000;
  tm.onMouseDown({ q: 0, r: 0 });
  tm.onMouseUp({ q: 0, r: 0 });
  assert(grid.getTile(0, 0).elevation === 32000, 'elevation should clamp to 32000');
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
  tile.props = [createProp('torch', 0, 0, 'structure', { footprint: [{ q: 0, r: 0 }] })];
  grid.setTile(1, 1, tile);
  const ch = new CommandHistory();
  const tm = new ToolManager(grid, ch);
  tm.setTool('delete_hex');
  tm.onMouseDown({ q: 1, r: 1 });
  assert(!grid.hasTile(1, 1), 'tile should be deleted');
  ch.undo();
  assert(grid.hasTile(1, 1), 'tile should be restored');
  assert(grid.getTile(1, 1).biome === 'water', 'biome should be restored');
  const struct = grid.getTile(1, 1).props.find(p => p.category === 'structure');
  assert(struct !== undefined && struct.type === 'torch', 'structure should be restored');
});

// ============================================================
// Validator tests (CO3)
// ============================================================

test('validateMap — valid map passes', () => {
  const grid = new HexGridClass();
  grid.meta = { chapter_id: 'ch1', name: 'Test', spawn: [0, 0] };
  const tile = createTileData('forest');
  tile.props = [createProp('wood', 0, 0, 'plant', { rotation: 45 })];
  grid.setTile(0, 0, tile);

  const result = validateMap(grid, new Set(['forest']), new Set(['wood']));
  assert(result.valid === true, 'valid map should pass');
  assert(result.errors.length === 0, 'no errors expected');
});

test('validateMap — missing spawn fails', () => {
  const grid = new HexGridClass();
  grid.meta = { chapter_id: 'ch1', name: 'Test', spawn: [5, 5] };
  grid.setTile(0, 0, createTileData('forest'));

  const result = validateMap(grid, new Set(['forest']), new Set());
  assert(result.valid === false, 'should fail with missing spawn tile');
  assert(result.errors.length > 0, 'should have errors');
  assert(result.errors[0].field === 'spawn', 'error field should be spawn');
});

test('validateMap — invalid biome fails', () => {
  const grid = new HexGridClass();
  grid.meta = { chapter_id: 'ch1', name: 'Test', spawn: [0, 0] };
  grid.setTile(0, 0, createTileData('unknown_biome'));

  const result = validateMap(grid, new Set(['forest', 'water']), new Set());
  assert(result.valid === false, 'should fail with unknown biome');
  assert(result.errors.some(e => e.field === 'biome'), 'should have biome error');
});

test('validateMap — overlapping props fails', () => {
  const grid = new HexGridClass();
  grid.meta = { chapter_id: 'ch1', name: 'Test', spawn: [0, 0] };
  const tile = createTileData('forest');
  tile.props = [
    createProp('wood', 0, 0, 'plant', { rotation: 0 }),
    createProp('stone', 0, 0, 'mineral', { rotation: 90 }),
  ];
  grid.setTile(0, 0, tile);

  const result = validateMap(grid, new Set(['forest']), new Set(['wood', 'stone']));
  assert(result.valid === false, 'should fail with overlapping props');
  assert(result.errors.some(e => e.message.includes('overlapping')), 'should mention overlapping');
});

test('validateMap — invalid sub-hex fails', () => {
  const grid = new HexGridClass();
  grid.meta = { chapter_id: 'ch1', name: 'Test', spawn: [0, 0] };
  const tile = createTileData('forest');
  // (2, 2) is distance 4 from origin in axial, which is > 2
  tile.props = [{ type: 'wood', sq: 2, sr: 2, category: 'plant', rotation: 0, origin: 'natural' }];
  grid.setTile(0, 0, tile);

  const result = validateMap(grid, new Set(['forest']), new Set(['wood']));
  assert(result.valid === false, 'should fail with invalid sub-hex');
  assert(result.errors.some(e => e.message.includes('invalid')), 'should mention invalid sub-hex');
});

test('validateMap — invalid rotation range fails', () => {
  const grid = new HexGridClass();
  grid.meta = { chapter_id: 'ch1', name: 'Test', spawn: [0, 0] };
  const tile = createTileData('forest');
  tile.props = [{ type: 'wood', sq: 0, sr: 0, category: 'plant', rotation: 400, origin: 'natural' }];
  grid.setTile(0, 0, tile);

  const result = validateMap(grid, new Set(['forest']), new Set(['wood']));
  assert(result.valid === false, 'should fail with invalid rotation');
  assert(result.errors.some(e => e.message.includes('rotation')), 'should mention rotation');
});

test('validateMap — unknown category fails', () => {
  const grid = new HexGridClass();
  grid.meta = { chapter_id: 'ch1', name: 'Test', spawn: [0, 0] };
  const tile = createTileData('forest');
  tile.props = [{ type: 'mystery', sq: 0, sr: 0, category: 'bogus_category', origin: 'natural', rotation: 0 }];
  grid.setTile(0, 0, tile);

  const result = validateMap(grid, new Set(['forest']), new Set());
  assert(result.valid === false, 'should fail with unknown category');
  assert(result.errors.some(e => e.message.includes('unknown category')), 'should mention unknown category');
});

test('validateMap — structured error format', () => {
  const grid = new HexGridClass();
  grid.meta = { chapter_id: 'ch1', name: 'Test', spawn: [0, 0] };
  grid.setTile(0, 0, createTileData('bad_biome'));

  const result = validateMap(grid, new Set(['forest']), new Set());
  assert(result.valid === false, 'should fail');
  const err = result.errors[0];
  assert(Array.isArray(err.hex), 'error.hex should be an array');
  assert(typeof err.field === 'string', 'error.field should be a string');
  assert(typeof err.message === 'string', 'error.message should be a string');
});

test('HexGrid.parseKey — parses key correctly', () => {
  const result = HexGrid.parseKey('3,-2');
  assert(result.q === 3, 'q should be 3');
  assert(result.r === -2, 'r should be -2');
});

test('CATEGORY_COLORS — has expected categories', () => {
  assert(CATEGORY_COLORS.plant !== undefined, 'should have plant');
  assert(CATEGORY_COLORS.mineral !== undefined, 'should have mineral');
  assert(CATEGORY_COLORS.structure !== undefined, 'should have structure');
  assert(CATEGORY_COLORS.equipment !== undefined, 'should have equipment');
  assert(typeof CATEGORY_COLORS.plant.badge === 'string', 'plant should have badge color');
  assert(typeof CATEGORY_COLORS.plant.fill === 'string', 'plant should have fill color');
});

// ============================================================
// Category enum mapping tests
// ============================================================

test('CATEGORY_TO_INT — maps string categories to integers', () => {
  assert(CATEGORY_TO_INT.plant === 0, 'plant should be 0');
  assert(CATEGORY_TO_INT.mineral === 1, 'mineral should be 1');
  assert(CATEGORY_TO_INT.animal === 2, 'animal should be 2');
  assert(CATEGORY_TO_INT.fungi === 3, 'fungi should be 3');
  assert(CATEGORY_TO_INT.liquid === 4, 'liquid should be 4');
  assert(CATEGORY_TO_INT.ooze === 5, 'ooze should be 5');
  assert(CATEGORY_TO_INT.structure === 6, 'structure should be 6');
  assert(CATEGORY_TO_INT.vehicle === 7, 'vehicle should be 7');
  assert(CATEGORY_TO_INT.equipment === 8, 'equipment should be 8');
  assert(CATEGORY_TO_INT.storage === 9, 'storage should be 9');
});

test('INT_TO_CATEGORY — maps integers to string categories', () => {
  assert(INT_TO_CATEGORY[0] === 'plant', '0 should be plant');
  assert(INT_TO_CATEGORY[1] === 'mineral', '1 should be mineral');
  assert(INT_TO_CATEGORY[2] === 'animal', '2 should be animal');
  assert(INT_TO_CATEGORY[3] === 'fungi', '3 should be fungi');
  assert(INT_TO_CATEGORY[4] === 'liquid', '4 should be liquid');
  assert(INT_TO_CATEGORY[5] === 'ooze', '5 should be ooze');
  assert(INT_TO_CATEGORY[6] === 'structure', '6 should be structure');
  assert(INT_TO_CATEGORY[7] === 'vehicle', '7 should be vehicle');
  assert(INT_TO_CATEGORY[8] === 'equipment', '8 should be equipment');
  assert(INT_TO_CATEGORY[9] === 'storage', '9 should be storage');
});

// ============================================================
// createProp — new optional fields
// ============================================================

test('createProp — mineral with optional fields', () => {
  const p = createProp('iron', 1, -1, 'mineral', {
    rotation: 45, remaining: 5, max_amount: 10, tool_required: 'pickaxe', respawn_time: 300,
  });
  assert(p.category === 'mineral', 'category should be mineral');
  assert(p.origin === 'natural', 'origin should default to natural for mineral');
  assert(p.remaining === 5, 'remaining should be 5');
  assert(p.max_amount === 10, 'max_amount should be 10');
  assert(p.tool_required === 'pickaxe', 'tool_required should be pickaxe');
  assert(p.respawn_time === 300, 'respawn_time should be 300');
});

test('createProp — plant without optional fields omits them', () => {
  const p = createProp('wood', 0, 0, 'plant', { rotation: 0 });
  assert(p.category === 'plant', 'category should be plant');
  assert(p.origin === 'natural', 'origin should default to natural for plant');
  assert(!('remaining' in p), 'remaining should not be present');
  assert(!('max_amount' in p), 'max_amount should not be present');
  assert(!('tool_required' in p), 'tool_required should not be present');
  assert(!('respawn_time' in p), 'respawn_time should not be present');
});

test('createProp — structure with blocks_movement', () => {
  const p = createProp('wall', 0, 0, 'structure', { blocks_movement: true });
  assert(p.blocks_movement === true, 'blocks_movement should be true');
  assert(p.rotation === 0, 'structure should have rotation');
  assert(p.origin === 'crafted', 'origin should default to crafted for structure');
});

test('createProp — equipment gets rotation and origin', () => {
  const p = createProp('scanner', 0, 0, 'equipment', { rotation: 180, origin: 'unknown' });
  assert(p.rotation === 180, 'equipment rotation should be 180');
  assert(p.origin === 'unknown', 'origin should be unknown when explicitly set');
});

// ============================================================
// Serialization — engine JSON format
// ============================================================

test('serializeGridToMapJson — outputs integer categories, origin, and sub_hex_q/sub_hex_r', () => {
  const grid = new HexGridClass();
  const tile = createTileData('forest');
  tile.props = [
    createProp('wood', 1, -1, 'plant', { rotation: 90 }),
    createProp('wall', 0, 0, 'structure', { footprint: [{ q: 0, r: 0 }], blocks_movement: true }),
    createProp('scanner', 0, 0, 'equipment', { rotation: 45, origin: 'unknown' }),
  ];
  grid.setTile(0, 0, tile);
  grid.meta.spawn = [0, 0];
  grid.meta.chapter_id = 'ch1';
  grid.meta.name = 'Test';

  const json = serializeGridToMapJson(grid);
  const props = json.tiles['0,0'].props;

  // Plant prop
  assert(props[0].category === 0, 'plant category should be integer 0');
  assert(props[0].origin === 0, 'plant origin should be integer 0 (natural)');
  assert(props[0].sub_hex_q === 1, 'sub_hex_q should be 1');
  assert(props[0].sub_hex_r === -1, 'sub_hex_r should be -1');
  assert(!('sq' in props[0]), 'should not have sq field');
  assert(!('sr' in props[0]), 'should not have sr field');
  assert(props[0].rotation === 90, 'rotation should be 90');

  // Structure prop — sub_hex omitted when (0,0)
  assert(props[1].category === 6, 'structure category should be integer 6');
  assert(props[1].origin === 1, 'structure origin should be integer 1 (crafted)');
  assert(!('sub_hex_q' in props[1]), 'sub_hex_q omitted for (0,0)');
  assert(!('sub_hex_r' in props[1]), 'sub_hex_r omitted for (0,0)');
  assert(!('footprint' in props[1]), 'footprint should not be serialized');
  assert(props[1].blocks_movement === true, 'blocks_movement should be true');

  // Equipment prop
  assert(props[2].category === 8, 'equipment category should be integer 8');
  assert(props[2].origin === 4, 'equipment origin should be integer 4 (unknown)');
  assert(props[2].rotation === 45, 'equipment rotation should be 45');
});

test('serializeGridToMapJson — omits rotation when zero', () => {
  const grid = new HexGridClass();
  const tile = createTileData('plains');
  tile.props = [createProp('stone', 0, 0, 'mineral', { rotation: 0 })];
  grid.setTile(0, 0, tile);
  grid.meta.spawn = [0, 0];
  const json = serializeGridToMapJson(grid);
  const prop = json.tiles['0,0'].props[0];
  assert(!('rotation' in prop), 'rotation should be omitted when zero');
});

test('serializeGridToMapJson — prop optional fields round-trip', () => {
  const grid = new HexGridClass();
  const tile = createTileData('forest');
  tile.props = [createProp('iron', 0, 0, 'mineral', {
    rotation: 0, remaining: 5, max_amount: 10, tool_required: 'pickaxe', respawn_time: 300,
  })];
  grid.setTile(0, 0, tile);
  grid.meta.spawn = [0, 0];
  const json = serializeGridToMapJson(grid);
  const prop = json.tiles['0,0'].props[0];
  assert(prop.remaining === 5, 'remaining should serialize');
  assert(prop.max_amount === 10, 'max_amount should serialize');
  assert(prop.tool_required === 'pickaxe', 'tool_required should serialize');
  assert(prop.respawn_time === 300, 'respawn_time should serialize');
});

test('serializeGridToMapJson — root level has spawn and tiles, optional metadata', () => {
  const grid = new HexGridClass();
  grid.meta.spawn = [2, 3];
  grid.meta.chapter_id = 'ch1';
  grid.meta.name = 'Map';
  const json = serializeGridToMapJson(grid);
  assert(Array.isArray(json.spawn), 'should have spawn');
  assert(json.spawn[0] === 2 && json.spawn[1] === 3, 'spawn values match');
  assert(json.chapter_id === 'ch1', 'chapter_id present when set');
  assert(json.name === 'Map', 'name present when set');
});

test('serializeGridToMapJson — omits chapter_id and name when empty', () => {
  const grid = new HexGridClass();
  grid.meta.spawn = [0, 0];
  grid.meta.chapter_id = '';
  grid.meta.name = '';
  const json = serializeGridToMapJson(grid);
  assert(!('chapter_id' in json), 'chapter_id omitted when empty');
  assert(!('name' in json), 'name omitted when empty');
});

// ============================================================
// loadMapIntoGrid — engine JSON format (integer categories)
// ============================================================

test('loadMapIntoGrid — loads engine format with integer categories and sub_hex fields', () => {
  const grid = new HexGridClass();
  const mapData = {
    spawn: [0, 0],
    tiles: {
      '0,0': { biome: 'forest', elevation: 1, props: [
        { type: 'iron', category: 1, sub_hex_q: 2, sub_hex_r: -1, rotation: 45, remaining: 5, max_amount: 10, tool_required: 'pickaxe', respawn_time: 300 },
        { type: 'wall', category: 6, blocks_movement: true },
        { type: 'scanner', category: 8, rotation: 90, origin: 4 },
      ] },
    },
  };
  loadMapIntoGrid(grid, mapData);
  const tile = grid.getTile(0, 0);

  // Mineral
  const res = tile.props.find(p => p.category === 'mineral');
  assert(res.type === 'iron', 'mineral type should be iron');
  assert(res.sq === 2, 'sq should be 2 (from sub_hex_q)');
  assert(res.sr === -1, 'sr should be -1 (from sub_hex_r)');
  assert(res.remaining === 5, 'remaining should load');
  assert(res.max_amount === 10, 'max_amount should load');
  assert(res.tool_required === 'pickaxe', 'tool_required should load');
  assert(res.respawn_time === 300, 'respawn_time should load');

  // Structure
  const st = tile.props.find(p => p.category === 'structure');
  assert(st.type === 'wall', 'structure type should be wall');
  assert(st.blocks_movement === true, 'blocks_movement should load');
  assert(st.sq === 0, 'default sq for structure should be 0');
  assert(st.sr === 0, 'default sr for structure should be 0');

  // Equipment
  const eq = tile.props.find(p => p.category === 'equipment');
  assert(eq.type === 'scanner', 'equipment type should be scanner');
  assert(eq.rotation === 90, 'equipment rotation should load');
  assert(eq.origin === 4, 'equipment origin should be 4 (unknown) when loaded from integer');
});

test('loadMapIntoGrid — full round-trip: load engine format, serialize back', () => {
  const grid = new HexGridClass();
  const input = {
    spawn: [1, 2],
    tiles: {
      '0,0': { biome: 'forest', elevation: 3, props: [
        { type: 'wood', category: 0, sub_hex_q: 1, sub_hex_r: -1, rotation: 45, remaining: 8 },
        { type: 'campfire', category: 6, blocks_movement: false },
      ] },
    },
  };
  loadMapIntoGrid(grid, input);
  const output = serializeGridToMapJson(grid);

  assert(output.spawn[0] === 1 && output.spawn[1] === 2, 'spawn round-trips');
  const props = output.tiles['0,0'].props;
  assert(props[0].category === 0, 'plant category round-trips as int');
  assert(props[0].sub_hex_q === 1, 'sub_hex_q round-trips');
  assert(props[0].sub_hex_r === -1, 'sub_hex_r round-trips');
  assert(props[0].remaining === 8, 'remaining round-trips');
  assert(props[1].category === 6, 'structure category round-trips as int');
  // blocks_movement=false should not be serialized (only truthy)
  assert(!('blocks_movement' in props[1]), 'blocks_movement=false not serialized');
});

// ============================================================
// Sub-hex round-trip and geometry tests (task: hex-math.js:201)
// ============================================================

test('subHexToPixel -> pixelToSubHex round-trip for all 19 VALID_SUB_HEXES', () => {
  for (const sh of HexMath.VALID_SUB_HEXES) {
    const px = HexMath.subHexToPixel(sh.q, sh.r);
    const back = HexMath.pixelToSubHex(px.x, px.y);
    assert(back.q === sh.q && back.r === sh.r,
      `round-trip failed for (${sh.q},${sh.r}): got (${back.q},${back.r})`);
  }
});

test('pixelToSubHex clamping — distance > 2 returns nearest valid sub-hex', () => {
  // Push a pixel far out along the +x axis; should clamp to a ring-2 sub-hex
  const farPx = HexMath.subHexToPixel(4, 0); // well beyond ring 2
  const clamped = HexMath.pixelToSubHex(farPx.x, farPx.y);
  assert(HexMath.distance(0, 0, clamped.q, clamped.r) <= 2,
    `clamped result (${clamped.q},${clamped.r}) should be within distance 2`);
  // The nearest valid sub-hex along +x axis should be (2, 0)
  assert(clamped.q === 2 && clamped.r === 0,
    `expected (2,0) but got (${clamped.q},${clamped.r})`);
});

test('subHexCorners returns 6 points with pointy-top orientation (first corner at 30 degrees)', () => {
  const corners = HexMath.subHexCorners(0, 0, 10);
  assert(corners.length === 6, `expected 6 corners, got ${corners.length}`);
  // First corner should be at 30 degrees: x = 10*cos(30°), y = 10*sin(30°)
  const expectedX = 10 * Math.cos(30 * Math.PI / 180);
  const expectedY = 10 * Math.sin(30 * Math.PI / 180);
  assert(Math.abs(corners[0].x - expectedX) < 1e-9,
    `first corner x: expected ${expectedX}, got ${corners[0].x}`);
  assert(Math.abs(corners[0].y - expectedY) < 1e-9,
    `first corner y: expected ${expectedY}, got ${corners[0].y}`);
  // All corners should be at distance 10 from center
  for (let i = 0; i < 6; i++) {
    const dist = Math.hypot(corners[i].x, corners[i].y);
    assert(Math.abs(dist - 10) < 1e-9, `corner ${i} distance should be 10, got ${dist}`);
  }
});

// ============================================================
// Summary
// ============================================================

console.log(`\n${passed + failed} assertions: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
