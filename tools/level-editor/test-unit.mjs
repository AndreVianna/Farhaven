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
import { ProjectContext, nextId } from './js/file-discovery.js';
import { PropDefModel, propModelToRaw, validatePropForm } from './js/prop-editor.js';
import { RecipeModel, recipeModelToRaw, validateRecipeForm, PREDICATE_KINDS } from './js/recipe-editor.js';
import { EventModel, eventModelToRaw, validateEventForm } from './js/event-editor.js';
import { BiomeDataModel, biomeModelToRaw } from './js/biome-editor.js';
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

test('TresParser — parseValue int-keyed dict (single mode)', () => {
  // MovementCap.modes uses int Mode enum keys
  const v = TresParser.parseValue('{ 0: [1.0, 1.5] }');
  assert(v.type === 'dict', 'type should be dict');
  assert(v.keyStyle === 'int', 'keyStyle should be int');
  assert(v.value.size === 1, 'should have 1 entry');
  const entry = v.value.get(0);
  assert(entry !== undefined, 'should have key 0');
  assert(entry.type === 'array', 'value should be an array');
  assert(entry.value.length === 2, 'array should have 2 elements');
  assert(entry.value[0].value === 1.0, 'normal speed should be 1.0');
  assert(entry.value[1].value === 1.5, 'max speed should be 1.5');
});

test('TresParser — parseValue int-keyed dict (multiple modes, multiline)', () => {
  // Frog: walks + jumps
  const v = TresParser.parseValue('{\n  0: [1.0, 1.5],\n  5: [2.0, 3.0]\n}');
  assert(v.type === 'dict', 'type should be dict');
  assert(v.keyStyle === 'int', 'keyStyle should be int');
  assert(v.value.size === 2, 'should have 2 entries');
  assert(v.value.get(0).value[0].value === 1.0, 'WALK normal = 1.0');
  assert(v.value.get(5).value[1].value === 3.0, 'JUMP max = 3.0');
});

test('TresParser — parseValue int-keyed dict supports negative keys', () => {
  // Catalog.ANOMALY_BUCKET uses -1 as a sentinel
  const v = TresParser.parseValue('{ -1: 42 }');
  assert(v.type === 'dict', 'type should be dict');
  assert(v.keyStyle === 'int', 'keyStyle should be int');
  assert(v.value.size === 1, 'should have 1 entry');
  assert(v.value.get(-1).value === 42, 'should have -1 = 42');
});

test('TresParser — serializeValue int-keyed dict round-trips', () => {
  const original = '{ 0: [1.0, 1.5], 5: [2.0, 3.0] }';
  const parsed = TresParser.parseValue(original);
  const serialized = TresParser.serializeValue(parsed);
  // Parse the serialized form again to verify equivalence
  const reparsed = TresParser.parseValue(serialized);
  assert(reparsed.type === 'dict', 'should reparse as dict');
  assert(reparsed.keyStyle === 'int', 'should preserve int keyStyle');
  assert(reparsed.value.size === 2, 'should still have 2 entries');
  assert(reparsed.value.get(0).value[0].value === 1.0, 'WALK normal preserved');
  assert(reparsed.value.get(5).value[1].value === 3.0, 'JUMP max preserved');
});

test('TresParser — serializeValue int-keyed dict with negative key round-trips', () => {
  const original = '{ -1: 42 }';
  const parsed = TresParser.parseValue(original);
  const serialized = TresParser.serializeValue(parsed);
  const reparsed = TresParser.parseValue(serialized);
  assert(reparsed.value.get(-1).value === 42, 'should preserve -1 key');
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
// TresParser — sub_resource parsing (task-046b)
// ============================================================

test('TresParser — parseValue SubResource', () => {
  const v = TresParser.parseValue('SubResource("placeable_1")');
  assert(v.type === 'sub_resource', 'type should be sub_resource');
  assert(v.value === 'placeable_1', 'value should be placeable_1');
});

test('TresParser — serializeValue sub_resource', () => {
  const s = TresParser.serializeValue({ type: 'sub_resource', value: 'portable_1' });
  assert(s === 'SubResource("portable_1")', `expected SubResource("portable_1"), got "${s}"`);
});

test('TresParser — parse file with sub_resource blocks', () => {
  const text = [
    '[gd_resource type="Resource" script_class="PropDef" load_steps=4 format=3]',
    '',
    '[ext_resource type="Script" path="res://scripts/data/prop_def.gd" id="1_script"]',
    '[ext_resource type="Script" path="res://scripts/data/capabilities/portable_cap.gd" id="2_portable"]',
    '',
    '[sub_resource type="Resource" id="portable_1"]',
    'script = ExtResource("2_portable")',
    'size = 2.5',
    '',
    '[resource]',
    'script = ExtResource("1_script")',
    'id = &"test"',
    'portable = SubResource("portable_1")',
    '',
  ].join('\n');

  const file = TresParser.parse(text);
  assert(file.subResources.length === 1, 'should have 1 sub_resource');
  assert(file.subResources[0].id === 'portable_1', 'sub_resource id should be portable_1');
  assert(file.subResources[0].type === 'Resource', 'sub_resource type should be Resource');
  assert(file.subResources[0].fields.get('size').type === 'float', 'size should be float');
  assert(file.subResources[0].fields.get('size').value === 2.5, 'size value should be 2.5');

  const portableRef = file.resourceFields.get('portable');
  assert(portableRef.type === 'sub_resource', 'portable field should be sub_resource reference');
  assert(portableRef.value === 'portable_1', 'portable ref should point to portable_1');
});

test('TresParser — serialize file with sub_resource blocks round-trips', () => {
  const text = [
    '[gd_resource type="Resource" script_class="PropDef" load_steps=5 format=3]',
    '',
    '[ext_resource type="Script" path="res://scripts/data/prop_def.gd" id="1_script"]',
    '[ext_resource type="Script" path="res://scripts/data/capabilities/placeable_cap.gd" id="2_placeable"]',
    '[ext_resource type="Script" path="res://scripts/data/capabilities/catalogable_cap.gd" id="3_catalogable"]',
    '',
    '[sub_resource type="Resource" id="placeable_1"]',
    'script = ExtResource("2_placeable")',
    'footprint = [Vector2i(0, 0)]',
    'blocks_movement = true',
    '',
    '[sub_resource type="Resource" id="catalogable_1"]',
    'script = ExtResource("3_catalogable")',
    'scan_time = 1.0',
    'display_tag = &"flora"',
    '',
    '[resource]',
    'script = ExtResource("1_script")',
    'id = &"P00001"',
    'placeable = SubResource("placeable_1")',
    'catalogable = SubResource("catalogable_1")',
    '',
  ].join('\n');

  const parsed = TresParser.parse(text);
  const serialized = TresParser.serialize(parsed);
  assert(serialized === text, 'round-trip should match');
});

test('TresParser — parse multiple sub_resources', () => {
  const text = [
    '[gd_resource type="Resource" script_class="PropDef" load_steps=8 format=3]',
    '',
    '[ext_resource type="Script" path="res://scripts/data/prop_def.gd" id="1_script"]',
    '[ext_resource type="Script" path="res://scripts/data/capabilities/placeable_cap.gd" id="2_placeable"]',
    '[ext_resource type="Script" path="res://scripts/data/capabilities/container_cap.gd" id="3_container"]',
    '[ext_resource type="Script" path="res://scripts/data/capabilities/light_cap.gd" id="4_light"]',
    '[ext_resource type="Script" path="res://scripts/data/capabilities/station_cap.gd" id="5_station"]',
    '[ext_resource type="Script" path="res://scripts/data/capabilities/catalogable_cap.gd" id="6_catalogable"]',
    '',
    '[sub_resource type="Resource" id="placeable_1"]',
    'script = ExtResource("2_placeable")',
    'footprint = [Vector2i(0, 0)]',
    'blocks_movement = true',
    '',
    '[sub_resource type="Resource" id="container_1"]',
    'script = ExtResource("3_container")',
    'capacity_weight = 20.0',
    'accepts_filter = [&"BURNABLE"]',
    '',
    '[sub_resource type="Resource" id="light_1"]',
    'script = ExtResource("4_light")',
    'radius = 4.0',
    'color = Color(1.0, 0.7, 0.3, 1.0)',
    'flicker = true',
    '',
    '[sub_resource type="Resource" id="station_1"]',
    'script = ExtResource("5_station")',
    'station_tags = [&"fire", &"cook", &"light"]',
    '',
    '[sub_resource type="Resource" id="catalogable_1"]',
    'script = ExtResource("6_catalogable")',
    'scan_time = 1.0',
    'display_tag = &"survival"',
    '',
    '[resource]',
    'script = ExtResource("1_script")',
    'id = &"P00101"',
    '',
  ].join('\n');

  const parsed = TresParser.parse(text);
  assert(parsed.subResources.length === 5, `expected 5 sub_resources, got ${parsed.subResources.length}`);
  assert(parsed.subResources[0].id === 'placeable_1', 'first sub should be placeable');
  assert(parsed.subResources[1].id === 'container_1', 'second sub should be container');
  assert(parsed.subResources[2].id === 'light_1', 'third sub should be light');
  assert(parsed.subResources[3].id === 'station_1', 'fourth sub should be station');
  assert(parsed.subResources[4].id === 'catalogable_1', 'fifth sub should be catalogable');

  // Verify round-trip
  const serialized = TresParser.serialize(parsed);
  assert(serialized === text, 'round-trip should match for multi-sub_resource file');
});

test('TresParser — file without sub_resources still works', () => {
  const text = [
    '[gd_resource type="Resource" script_class="BiomeData" load_steps=2 format=3]',
    '',
    '[ext_resource type="Script" path="res://scripts/data/biome_data.gd" id="1_script"]',
    '',
    '[resource]',
    'script = ExtResource("1_script")',
    'name = &"forest"',
    '',
  ].join('\n');

  const parsed = TresParser.parse(text);
  assert(parsed.subResources.length === 0, 'should have 0 sub_resources');
  const serialized = TresParser.serialize(parsed);
  assert(serialized === text, 'round-trip should match for file without sub_resources');
});

// ============================================================
// PropDefModel — capability parsing (task-046b)
// ============================================================

test('PropDefModel — fromEntry reads tags', () => {
  const entry = _makePropEntry({
    tags: ['SOURCE', 'WOOD'],
  });
  const model = PropDefModel.fromEntry('00001.tres', entry);
  assert(model.tags.length === 2, 'should have 2 tags');
  assert(model.tags[0] === 'SOURCE', 'first tag should be SOURCE');
  assert(model.tags[1] === 'WOOD', 'second tag should be WOOD');
});

test('PropDefModel — fromEntry reads portable capability', () => {
  const entry = _makePropEntry({
    portable: { size: 2.5 },
  });
  const model = PropDefModel.fromEntry('test.tres', entry);
  assert(model.portable !== null, 'portable should not be null');
  assert(model.portable.size === 2.5, 'size should be 2.5');
});

test('PropDefModel — fromEntry reads placeable capability', () => {
  const entry = _makePropEntry({
    placeable: {},
  });
  const model = PropDefModel.fromEntry('test.tres', entry);
  assert(model.placeable !== null, 'placeable should not be null');
});

test('PropDefModel — fromEntry reads container capability', () => {
  const entry = _makePropEntry({
    container: { capacity_weight: 50, accepts_filter: ['BURNABLE', 'WOOD'] },
  });
  const model = PropDefModel.fromEntry('test.tres', entry);
  assert(model.container !== null, 'container should not be null');
  assert(model.container.capacity_weight === 50, 'capacity_weight should be 50');
  assert(model.container.accepts_filter.length === 2, 'accepts_filter should have 2 items');
  assert(model.container.accepts_filter[0] === 'BURNABLE', 'first filter should be BURNABLE');
});

test('PropDefModel — fromEntry reads light capability', () => {
  const entry = _makePropEntry({
    light: { radius: 4, color: { r: 1, g: 0.7, b: 0.3, a: 1 }, flicker: true },
  });
  const model = PropDefModel.fromEntry('test.tres', entry);
  assert(model.light !== null, 'light should not be null');
  assert(model.light.radius === 4, 'radius should be 4');
  assert(model.light.flicker === true, 'flicker should be true');
  assert(model.light.color.r === 1, 'color r should be 1');
});

test('PropDefModel — fromEntry reads movable capability', () => {
  const entry = _makePropEntry({
    movable: { push_cost: 3.5 },
  });
  const model = PropDefModel.fromEntry('test.tres', entry);
  assert(model.movable !== null, 'movable should not be null');
  assert(model.movable.push_cost === 3.5, 'push_cost should be 3.5');
});

test('PropDefModel — fromEntry reads station capability', () => {
  const entry = _makePropEntry({
    station: { station_tags: ['fire', 'cook'] },
  });
  const model = PropDefModel.fromEntry('test.tres', entry);
  assert(model.station !== null, 'station should not be null');
  assert(model.station.station_tags.length === 2, 'should have 2 station tags');
  assert(model.station.station_tags[0] === 'fire', 'first tag should be fire');
});

test('PropDefModel — fromEntry reads catalogable capability', () => {
  const entry = _makePropEntry({
    catalogable: { scan_time: 2.5, show_as_anomaly: false, properties: new Map() },
  });
  const model = PropDefModel.fromEntry('test.tres', entry);
  assert(model.catalogable !== null, 'catalogable should not be null');
  assert(model.catalogable.scan_time === 2.5, 'scan_time should be 2.5');
  assert(model.catalogable.show_as_anomaly === false, 'show_as_anomaly should be false');
});

test('PropDefModel — fromEntry reads catalogable show_as_anomaly', () => {
  const entry = _makePropEntry({
    catalogable: { scan_time: 3.0, show_as_anomaly: true, properties: new Map() },
  });
  const model = PropDefModel.fromEntry('test.tres', entry);
  assert(model.catalogable !== null, 'catalogable should not be null');
  assert(model.catalogable.show_as_anomaly === true, 'show_as_anomaly should be true');
});

test('PropDefModel — fromEntry reads endurance capability', () => {
  const entry = _makePropEntry({
    endurance: { hp: 20, vulnerabilities: ['FIRE'], resistances: [], immunities: ['POISON'] },
  });
  const model = PropDefModel.fromEntry('test.tres', entry);
  assert(model.endurance !== null, 'endurance should not be null');
  assert(model.endurance.hp === 20, 'hp should be 20');
  assert(model.endurance.vulnerabilities.length === 1, 'vulnerabilities should have 1 item');
  assert(model.endurance.vulnerabilities[0] === 'FIRE', 'vulnerability should be FIRE');
  assert(model.endurance.resistances.length === 0, 'resistances should be empty');
  assert(model.endurance.immunities[0] === 'POISON', 'immunity should be POISON');
});

test('PropDefModel — fromEntry reads endurance with default hp', () => {
  const entry = _makePropEntry({
    endurance: { vulnerabilities: [], resistances: [], immunities: [] },
  });
  const model = PropDefModel.fromEntry('test.tres', entry);
  assert(model.endurance !== null, 'endurance should not be null');
  assert(model.endurance.hp === 1, 'hp should default to 1 when missing');
});

test('PropDefModel — fromEntry reads movement capability (modes dict)', () => {
  // Simulate what file-discovery builds from the parsed .tres:
  // movement sub_resource's `modes` field is a Map<int, TresValue> where
  // each value is an array TresValue of two float TresValues.
  const modesMap = new Map();
  modesMap.set(2, {
    type: 'array',
    elementType: null,
    value: [
      { type: 'float', value: 3.0 },
      { type: 'float', value: 5.0 },
    ],
  });
  const entry = _makePropEntry({
    movement: { modes: modesMap },
  });
  const model = PropDefModel.fromEntry('test.tres', entry);
  assert(model.movement !== null, 'movement should not be null');
  assert(Array.isArray(model.movement.modes), 'modes should be an array');
  assert(model.movement.modes.length === 1, 'modes should have 1 entry');
  assert(model.movement.modes[0].mode === 2, 'mode should be 2 (FLY)');
  assert(model.movement.modes[0].normal === 3.0, 'normal speed should be 3.0');
  assert(model.movement.modes[0].max === 5.0, 'max speed should be 5.0');
});

test('PropDefModel — fromEntry reads movement with empty modes', () => {
  const entry = _makePropEntry({
    movement: {},
  });
  const model = PropDefModel.fromEntry('test.tres', entry);
  assert(model.movement !== null, 'movement should not be null');
  assert(Array.isArray(model.movement.modes), 'modes should default to an array');
  assert(model.movement.modes.length === 0, 'modes should be empty');
});

test('PropDefModel — fromEntry reads movement with multiple modes (amphibian)', () => {
  const modesMap = new Map();
  modesMap.set(0, {
    type: 'array',
    elementType: null,
    value: [
      { type: 'float', value: 1.0 },
      { type: 'float', value: 1.5 },
    ],
  });
  modesMap.set(1, {
    type: 'array',
    elementType: null,
    value: [
      { type: 'float', value: 0.8 },
      { type: 'float', value: 1.2 },
    ],
  });
  const entry = _makePropEntry({
    movement: { modes: modesMap },
  });
  const model = PropDefModel.fromEntry('test.tres', entry);
  assert(model.movement.modes.length === 2, 'modes should have 2 entries');
  assert(model.movement.modes[0].mode === 0, 'first mode is WALK');
  assert(model.movement.modes[1].mode === 1, 'second mode is SWIM');
});

test('PropDefModel — fromEntry reads combat capability', () => {
  const entry = _makePropEntry({
    combat: { attacks: [], defenses: [] },
  });
  const model = PropDefModel.fromEntry('test.tres', entry);
  assert(model.combat !== null, 'combat should not be null');
  assert(Array.isArray(model.combat.attacks), 'attacks should be an array');
  assert(Array.isArray(model.combat.defenses), 'defenses should be an array');
});

test('PropDefModel — fromEntry reads behavior capability', () => {
  const entry = _makePropEntry({
    behavior: { detection_range: 5, activity_cycle: 2, group_behavior: 1, diet: ['FAUNA'], reactions: [] },
  });
  const model = PropDefModel.fromEntry('test.tres', entry);
  assert(model.behavior !== null, 'behavior should not be null');
  assert(model.behavior.detection_range === 5, 'detection_range should be 5');
  assert(model.behavior.activity_cycle === 2, 'activity_cycle should be 2 (NOCTURNAL)');
  assert(model.behavior.group_behavior === 1, 'group_behavior should be 1 (PAIR)');
  assert(model.behavior.diet.length === 1, 'diet should have 1 item');
  assert(model.behavior.diet[0] === 'FAUNA', 'diet should be FAUNA');
  assert(Array.isArray(model.behavior.reactions), 'reactions should be an array');
});

test('PropDefModel — fromEntry reads behavior with defaults', () => {
  const entry = _makePropEntry({
    behavior: {},
  });
  const model = PropDefModel.fromEntry('test.tres', entry);
  assert(model.behavior !== null, 'behavior should not be null');
  assert(model.behavior.detection_range === 2, 'detection_range should default to 2');
  assert(model.behavior.activity_cycle === 0, 'activity_cycle should default to 0 (ALWAYS)');
  assert(model.behavior.group_behavior === 0, 'group_behavior should default to 0 (SOLO)');
});

test('PropDefModel — fromEntry reads behavior group_behavior HERD', () => {
  const entry = _makePropEntry({
    behavior: { detection_range: 3, activity_cycle: 1, group_behavior: 3, diet: [], reactions: [] },
  });
  const model = PropDefModel.fromEntry('test.tres', entry);
  assert(model.behavior.group_behavior === 3, 'group_behavior should be 3 (HERD)');
});

test('PropDefModel — fromEntry reads behavior group_behavior SWARM', () => {
  const entry = _makePropEntry({
    behavior: { detection_range: 4, activity_cycle: 0, group_behavior: 4, diet: [], reactions: [] },
  });
  const model = PropDefModel.fromEntry('test.tres', entry);
  assert(model.behavior.group_behavior === 4, 'group_behavior should be 4 (SWARM)');
});

test('PropDefModel — fromEntry reads spawnable capability', () => {
  const entry = _makePropEntry({
    spawnable: { spawn_min: 2, spawn_max: 5, first_spawn_day: 4, spawn_min_distance: 6, allowed_biomes: ['FOREST', 'GRASSLAND'] },
  });
  const model = PropDefModel.fromEntry('test.tres', entry);
  assert(model.spawnable !== null, 'spawnable should not be null');
  assert(model.spawnable.spawn_min === 2, 'spawn_min should be 2');
  assert(model.spawnable.spawn_max === 5, 'spawn_max should be 5');
  assert(model.spawnable.first_spawn_day === 4, 'first_spawn_day should be 4');
  assert(model.spawnable.spawn_min_distance === 6, 'spawn_min_distance should be 6');
  assert(model.spawnable.allowed_biomes.length === 2, 'allowed_biomes should have 2 items');
  assert(model.spawnable.allowed_biomes[0] === 'FOREST', 'first biome should be FOREST');
});

test('PropDefModel — fromEntry reads spawnable with defaults', () => {
  const entry = _makePropEntry({
    spawnable: {},
  });
  const model = PropDefModel.fromEntry('test.tres', entry);
  assert(model.spawnable !== null, 'spawnable should not be null');
  assert(model.spawnable.spawn_min === 1, 'spawn_min should default to 1');
  assert(model.spawnable.spawn_max === 1, 'spawn_max should default to 1');
  assert(model.spawnable.first_spawn_day === 1, 'first_spawn_day should default to 1');
  assert(model.spawnable.spawn_min_distance === 3, 'spawn_min_distance should default to 3');
  assert(model.spawnable.allowed_biomes.length === 0, 'allowed_biomes should be empty');
});

test('PropDefModel — fromEntry null capabilities when not present', () => {
  const entry = _makePropEntry({});
  const model = PropDefModel.fromEntry('test.tres', entry);
  assert(model.portable === null, 'portable should be null');
  assert(model.placeable === null, 'placeable should be null');
  assert(model.container === null, 'container should be null');
  assert(model.light === null, 'light should be null');
  assert(model.movable === null, 'movable should be null');
  assert(model.station === null, 'station should be null');
  assert(model.catalogable === null, 'catalogable should be null');
  assert(model.endurance === null, 'endurance should be null');
  assert(model.movement === null, 'movement should be null');
  assert(model.combat === null, 'combat should be null');
  assert(model.behavior === null, 'behavior should be null');
  assert(model.spawnable === null, 'spawnable should be null');
});

// ============================================================
// validatePropForm — capability validation (task-046b)
// ============================================================

test('validatePropForm — PORTABLE.size >= 0', () => {
  const model = _makeModel({ portable: { size: -1 } });
  const result = validatePropForm(model, false);
  assert(!result.valid, 'should be invalid');
  assert(result.errors.some(e => e.includes('PORTABLE size')), 'should mention PORTABLE size');
});

test('validatePropForm — PORTABLE.size = 0 is valid', () => {
  const model = _makeModel({ portable: { size: 0 } });
  const result = validatePropForm(model, false);
  assert(result.valid, 'size 0 should be valid');
});

test('validatePropForm — PLACEABLE marker is always valid', () => {
  const model = _makeModel({ placeable: {} });
  const result = validatePropForm(model, false);
  assert(result.valid, 'placeable marker should be valid');
});

test('validatePropForm — EMITS_LIGHT.radius >= 1', () => {
  const model = _makeModel({ light: { radius: 0, color: { r: 1, g: 1, b: 1, a: 1 }, flicker: false } });
  const result = validatePropForm(model, false);
  assert(!result.valid, 'should be invalid');
  assert(result.errors.some(e => e.includes('EMITS_LIGHT radius')), 'should mention EMITS_LIGHT radius');
});

test('validatePropForm — EMITS_LIGHT.radius = 1 is valid', () => {
  const model = _makeModel({ light: { radius: 1, color: { r: 1, g: 1, b: 1, a: 1 }, flicker: false } });
  const result = validatePropForm(model, false);
  assert(result.valid, 'should be valid');
});

test('validatePropForm — STATION.station_tags must be non-empty', () => {
  const model = _makeModel({ station: { station_tags: [] } });
  const result = validatePropForm(model, false);
  assert(!result.valid, 'should be invalid');
  assert(result.errors.some(e => e.includes('STATION station_tags')), 'should mention STATION station_tags');
});

test('validatePropForm — STATION with tags is valid', () => {
  const model = _makeModel({ station: { station_tags: ['fire'] } });
  const result = validatePropForm(model, false);
  assert(result.valid, 'should be valid');
});

test('validatePropForm — no capabilities = valid', () => {
  const model = _makeModel({});
  const result = validatePropForm(model, false);
  assert(result.valid, 'should be valid with no capabilities');
});

test('validatePropForm — ID missing P prefix', () => {
  const result = validatePropForm(_makeModel({ id: '00001' }), true);
  assert(!result.valid, 'should be invalid without P prefix');
  assert(result.errors.some(e => e.includes('start with "P"')), 'should mention P prefix');
});

test('validatePropForm — ID with P prefix is valid', () => {
  const result = validatePropForm(_makeModel({ id: 'P00001' }), false);
  assert(result.valid, 'should be valid with P prefix');
});

// ============================================================
// nextId — shared auto-increment helper
// ============================================================

test('nextId — returns prefix + 00001 for empty map', () => {
  const empty = new Map();
  assert(nextId('P', empty) === 'P00001', 'should be P00001');
  assert(nextId('R', empty) === 'R00001', 'should be R00001');
  assert(nextId('E', empty) === 'E00001', 'should be E00001');
});

test('nextId — increments past highest existing ID', () => {
  const map = new Map();
  map.set('P00003.tres', {});
  map.set('P00010.tres', {});
  map.set('P00005.tres', {});
  assert(nextId('P', map) === 'P00011', 'should be P00011 (max was 10)');
});

test('nextId — ignores entries with wrong prefix', () => {
  const map = new Map();
  map.set('R00050.tres', {});
  map.set('P00002.tres', {});
  assert(nextId('P', map) === 'P00003', 'should be P00003, ignoring R entry');
  assert(nextId('R', map) === 'R00051', 'should be R00051, ignoring P entry');
});

test('nextId — ignores non-numeric suffixes', () => {
  const map = new Map();
  map.set('Pabc.tres', {});
  map.set('P00007.tres', {});
  assert(nextId('P', map) === 'P00008', 'should be P00008, ignoring Pabc');
});

test('nextId — pads to 5 digits', () => {
  const map = new Map();
  map.set('E00001.tres', {});
  const result = nextId('E', map);
  assert(result === 'E00002', 'should be E00002');
  assert(result.length === 6, 'prefix + 5 digits = 6 chars');
});

// ============================================================
// propModelToRaw — capability serialization (task-046b)
// ============================================================

test('propModelToRaw — serializes tags', () => {
  const model = _makeModel({ tags: ['SOURCE', 'WOOD'] });
  const raw = propModelToRaw(model);
  const tagsField = raw.resourceFields.get('tags');
  assert(tagsField !== undefined, 'tags field should exist');
  assert(tagsField.type === 'array', 'tags should be array type');
  assert(tagsField.value.length === 2, 'tags should have 2 elements');
  assert(tagsField.value[0].value === 'SOURCE', 'first tag should be SOURCE');
});

test('propModelToRaw — serializes portable as sub_resource', () => {
  const model = _makeModel({ portable: { size: 2.0 } });
  const raw = propModelToRaw(model);
  assert(raw.subResources.length === 1, 'should have 1 sub_resource');
  assert(raw.subResources[0].id === 'portable_1', 'sub_resource id should be portable_1');
  const portableRef = raw.resourceFields.get('portable');
  assert(portableRef.type === 'sub_resource', 'portable field should be sub_resource ref');
  assert(portableRef.value === 'portable_1', 'should point to portable_1');
});

test('propModelToRaw — serializes multiple capabilities', () => {
  const model = _makeModel({
    portable: { size: 1.0 },
    placeable: {},
    catalogable: { scan_time: 1.0, show_as_anomaly: false, properties: {} },
  });
  const raw = propModelToRaw(model);
  assert(raw.subResources.length === 3, `should have 3 sub_resources, got ${raw.subResources.length}`);
  assert(raw.extResources.length === 4, `should have 4 ext_resources (script + 3 caps), got ${raw.extResources.length}`);
});

test('propModelToRaw — no capabilities = no sub_resources', () => {
  const model = _makeModel({});
  const raw = propModelToRaw(model);
  assert(raw.subResources.length === 0, 'should have 0 sub_resources');
  assert(raw.extResources.length === 1, 'should have 1 ext_resource (script only)');
});

test('propModelToRaw — serialized output is valid .tres', () => {
  const model = _makeModel({
    tags: ['STRUCTURE', 'STATION.fire'],
    placeable: {},
    light: { radius: 4, color: { r: 1, g: 0.7, b: 0.3, a: 1 }, flicker: true },
    station: { station_tags: ['fire', 'cook'] },
    catalogable: { scan_time: 1.0, show_as_anomaly: false, properties: {} },
  });
  const raw = propModelToRaw(model);
  const text = TresParser.serialize(raw);

  // Re-parse should succeed
  const reparsed = TresParser.parse(text);
  assert(reparsed.scriptClass === 'PropDef', 'should parse as PropDef');
  assert(reparsed.subResources.length === 4, 'should have 4 sub_resources');
  assert(reparsed.resourceFields.get('id').value === 'Ptest', 'id should round-trip');
});

// ============================================================
// PropDefModel round-trip: fromEntry -> propModelToRaw -> parse -> fromEntry (task-046b)
// ============================================================

test('PropDefModel — full round-trip with capabilities', () => {
  const original = _makeModel({
    tags: ['SOURCE', 'WOOD', 'BURNABLE.log'],
    portable: { size: 1.5 },
    placeable: {},
    container: { capacity_weight: 20, accepts_filter: ['BURNABLE'] },
    light: { radius: 4, color: { r: 1, g: 0.7, b: 0.3, a: 1 }, flicker: true },
    station: { station_tags: ['fire', 'cook'] },
    catalogable: { scan_time: 2.0, show_as_anomaly: true, properties: {} },
  });

  // Serialize
  const raw = propModelToRaw(original);
  const text = TresParser.serialize(raw);

  // Re-parse
  const reparsed = TresParser.parse(text);

  // Build data object (simulates what file-discovery does)
  const subResourceMap = new Map();
  for (const sub of reparsed.subResources) {
    const subData = {};
    for (const [k, v] of sub.fields) {
      subData[k] = v.value;
    }
    subResourceMap.set(sub.id, subData);
  }
  const data = {};
  for (const [key, tv] of reparsed.resourceFields) {
    if (tv.type === 'sub_resource') {
      data[key] = subResourceMap.get(tv.value) || null;
    } else {
      data[key] = tv.value;
    }
  }

  // Reconstruct model
  const restored = PropDefModel.fromEntry('test.tres', { data, raw: reparsed });

  // Verify capabilities survived
  assert(restored.tags.length === 3, `tags should have 3 items, got ${restored.tags.length}`);
  assert(restored.portable !== null, 'portable should survive');
  assert(restored.portable.size === 1.5, 'portable size should be 1.5');
  assert(restored.placeable !== null, 'placeable should survive');
  assert(restored.container !== null, 'container should survive');
  assert(restored.container.capacity_weight === 20, 'capacity_weight should be 20');
  assert(restored.container.accepts_filter.length === 1, 'accepts_filter should have 1 item');
  assert(restored.light !== null, 'light should survive');
  assert(restored.light.radius === 4, 'light radius should be 4');
  assert(restored.light.flicker === true, 'flicker should be true');
  assert(restored.station !== null, 'station should survive');
  assert(restored.station.station_tags.length === 2, 'station_tags should have 2 items');
  assert(restored.catalogable !== null, 'catalogable should survive');
  assert(restored.catalogable.scan_time === 2.0, 'scan_time should be 2.0');
  assert(restored.catalogable.show_as_anomaly === true, 'show_as_anomaly should be true');
});

test('PropDefModel — full round-trip with fauna capabilities', () => {
  const original = _makeModel({
    tags: ['FAUNA', 'HOSTILE'],
    catalogable: { scan_time: 3.0, show_as_anomaly: false, properties: {} },
    endurance: { hp: 20, vulnerabilities: ['FIRE'], resistances: [], immunities: [] },
    movement: { modes: [{ mode: 0, normal: 1.0, max: 1.5 }] },
    combat: { attacks: [], defenses: [] },
    behavior: { detection_range: 2, activity_cycle: 2, group_behavior: 0, diet: ['FAUNA'], reactions: [] },
    spawnable: { spawn_min: 1, spawn_max: 3, first_spawn_day: 4, spawn_min_distance: 3, allowed_biomes: [] },
  });

  // Serialize
  const raw = propModelToRaw(original);
  const text = TresParser.serialize(raw);

  // Re-parse
  const reparsed = TresParser.parse(text);

  // Build data object (simulates what file-discovery does)
  const subResourceMap = new Map();
  for (const sub of reparsed.subResources) {
    const subData = {};
    for (const [k, v] of sub.fields) {
      subData[k] = v.value;
    }
    subResourceMap.set(sub.id, subData);
  }
  const data = {};
  for (const [key, tv] of reparsed.resourceFields) {
    if (tv.type === 'sub_resource') {
      data[key] = subResourceMap.get(tv.value) || null;
    } else {
      data[key] = tv.value;
    }
  }

  // Reconstruct model
  const restored = PropDefModel.fromEntry('test.tres', { data, raw: reparsed });

  // Verify all fauna caps survived
  assert(restored.catalogable !== null, 'catalogable should survive');
  assert(restored.catalogable.scan_time === 3.0, 'catalogable.scan_time should be 3.0');
  assert(restored.catalogable.show_as_anomaly === false, 'catalogable.show_as_anomaly should be false');

  assert(restored.endurance !== null, 'endurance should survive');
  assert(restored.endurance.hp === 20, 'endurance.hp should be 20');
  assert(restored.endurance.vulnerabilities.length === 1, 'vulnerabilities should have 1 item');
  assert(restored.endurance.vulnerabilities[0] === 'FIRE', 'vulnerability should be FIRE');
  assert(restored.endurance.resistances.length === 0, 'resistances should be empty');
  assert(restored.endurance.immunities.length === 0, 'immunities should be empty');

  assert(restored.movement !== null, 'movement should survive');
  assert(Array.isArray(restored.movement.modes), 'movement.modes should be an array');
  assert(restored.movement.modes.length === 1, 'modes should have 1 entry');
  assert(restored.movement.modes[0].mode === 0, 'movement.modes[0].mode should be 0 (WALK)');
  assert(restored.movement.modes[0].normal === 1.0, 'normal speed should be 1.0');
  assert(restored.movement.modes[0].max === 1.5, 'max speed should be 1.5');

  assert(restored.combat !== null, 'combat should survive');
  assert(Array.isArray(restored.combat.attacks), 'combat.attacks should be an array');
  assert(Array.isArray(restored.combat.defenses), 'combat.defenses should be an array');

  assert(restored.behavior !== null, 'behavior should survive');
  assert(restored.behavior.detection_range === 2, 'detection_range should be 2');
  assert(restored.behavior.activity_cycle === 2, 'activity_cycle should be 2 (NOCTURNAL)');
  assert(restored.behavior.group_behavior === 0, 'group_behavior should be 0 (SOLO)');
  assert(restored.behavior.diet.length === 1, 'diet should have 1 item');
  assert(restored.behavior.diet[0] === 'FAUNA', 'diet should be FAUNA');

  assert(restored.spawnable !== null, 'spawnable should survive');
  assert(restored.spawnable.spawn_min === 1, 'spawn_min should be 1');
  assert(restored.spawnable.spawn_max === 3, 'spawn_max should be 3');
  assert(restored.spawnable.first_spawn_day === 4, 'first_spawn_day should be 4');
  assert(restored.spawnable.spawn_min_distance === 3, 'spawn_min_distance should be 3');
  assert(restored.spawnable.allowed_biomes.length === 0, 'allowed_biomes should be empty');
});

test('PropDefModel — round-trip fauna caps with non-default values', () => {
  const original = _makeModel({
    endurance: { hp: 50, vulnerabilities: ['FIRE', 'BLUNT'], resistances: ['PIERCING'], immunities: ['POISON'] },
    movement: { modes: [
      { mode: 2, normal: 3.0, max: 5.0 },
      { mode: 5, normal: 4.0, max: 4.0 },
    ] },
    behavior: { detection_range: 8, activity_cycle: 1, group_behavior: 2, diet: ['FLORA', 'FAUNA'], reactions: [] },
    spawnable: { spawn_min: 3, spawn_max: 7, first_spawn_day: 10, spawn_min_distance: 5, allowed_biomes: ['FOREST', 'MOUNTAIN'] },
  });

  const raw = propModelToRaw(original);
  const text = TresParser.serialize(raw);
  const reparsed = TresParser.parse(text);

  const subResourceMap = new Map();
  for (const sub of reparsed.subResources) {
    const subData = {};
    for (const [k, v] of sub.fields) {
      subData[k] = v.value;
    }
    subResourceMap.set(sub.id, subData);
  }
  const data = {};
  for (const [key, tv] of reparsed.resourceFields) {
    if (tv.type === 'sub_resource') {
      data[key] = subResourceMap.get(tv.value) || null;
    } else {
      data[key] = tv.value;
    }
  }

  const restored = PropDefModel.fromEntry('test.tres', { data, raw: reparsed });

  assert(restored.endurance.hp === 50, 'hp should be 50');
  assert(restored.endurance.vulnerabilities.length === 2, 'vulnerabilities should have 2 items');
  assert(restored.endurance.resistances[0] === 'PIERCING', 'resistance should be PIERCING');
  assert(restored.endurance.immunities[0] === 'POISON', 'immunity should be POISON');

  assert(restored.movement.modes.length === 2, 'modes should have 2 entries');
  assert(restored.movement.modes[0].mode === 2, 'first mode should be 2 (FLY)');
  assert(restored.movement.modes[0].normal === 3.0, 'fly normal speed should be 3.0');
  assert(restored.movement.modes[0].max === 5.0, 'fly max speed should be 5.0');
  assert(restored.movement.modes[1].mode === 5, 'second mode should be 5 (JUMP)');
  assert(restored.movement.modes[1].normal === 4.0, 'jump normal should be 4.0 (max elev diff)');

  assert(restored.behavior.detection_range === 8, 'detection_range should be 8');
  assert(restored.behavior.activity_cycle === 1, 'activity_cycle should be 1 (DIURNAL)');
  assert(restored.behavior.group_behavior === 2, 'group_behavior should be 2 (PACK)');
  assert(restored.behavior.diet.length === 2, 'diet should have 2 items');

  assert(restored.spawnable.spawn_min === 3, 'spawn_min should be 3');
  assert(restored.spawnable.spawn_max === 7, 'spawn_max should be 7');
  assert(restored.spawnable.first_spawn_day === 10, 'first_spawn_day should be 10');
  assert(restored.spawnable.spawn_min_distance === 5, 'spawn_min_distance should be 5');
  assert(restored.spawnable.allowed_biomes.length === 2, 'allowed_biomes should have 2 items');
});

test('PropDefModel — round-trip with no capabilities', () => {
  const original = _makeModel({});
  const raw = propModelToRaw(original);
  const text = TresParser.serialize(raw);
  const reparsed = TresParser.parse(text);

  const data = {};
  for (const [key, tv] of reparsed.resourceFields) {
    data[key] = tv.value;
  }

  const restored = PropDefModel.fromEntry('test.tres', { data, raw: reparsed });
  assert(restored.portable === null, 'portable should be null');
  assert(restored.placeable === null, 'placeable should be null');
  assert(restored.container === null, 'container should be null');
  assert(restored.light === null, 'light should be null');
  assert(restored.movable === null, 'movable should be null');
  assert(restored.station === null, 'station should be null');
  assert(restored.catalogable === null, 'catalogable should be null');
  assert(restored.endurance === null, 'endurance should be null');
  assert(restored.movement === null, 'movement should be null');
  assert(restored.combat === null, 'combat should be null');
  assert(restored.behavior === null, 'behavior should be null');
  assert(restored.spawnable === null, 'spawnable should be null');
  assert(restored.id === 'test', 'id should survive');
  assert(restored.display_name === 'Test Prop', 'display_name should survive');
});

// ============================================================
// PropDefModel round-trip from actual .tres files (task-046b)
// ============================================================

import { readFileSync, readdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __test_filename = fileURLToPath(import.meta.url);
const __test_dirname = dirname(__test_filename);
const __projectRoot = join(__test_dirname, '..', '..');
const __propsDir = join(__projectRoot, 'data', 'props');
const __propFiles = readdirSync(__propsDir).filter(f => f.endsWith('.tres'));

for (const propFile of __propFiles) {
  test(`PropDefModel round-trip — ${propFile}`, () => {
    const filePath = join(__propsDir, propFile);
    const text = readFileSync(filePath, 'utf-8');

    // Parse
    const parsed = TresParser.parse(text);

    // Build data object (same as file-discovery)
    const subResourceMap = new Map();
    if (parsed.subResources) {
      for (const sub of parsed.subResources) {
        const subData = {};
        for (const [k, v] of sub.fields) {
          subData[k] = v.value;
        }
        subResourceMap.set(sub.id, subData);
      }
    }
    const data = {};
    for (const [key, tv] of parsed.resourceFields) {
      if (tv.type === 'sub_resource') {
        data[key] = subResourceMap.get(tv.value) || null;
      } else {
        data[key] = tv.value;
      }
    }

    // Create model
    const model = PropDefModel.fromEntry(propFile, { data, raw: parsed });

    // Verify basic fields survived
    assert(model.id === propFile.replace('.tres', ''), `id should match filename for ${propFile}`);
    assert(model.display_name.length > 0, `display_name should be non-empty for ${propFile}`);

    // Verify capabilities match what's in the file
    if (parsed.resourceFields.has('portable')) {
      assert(model.portable !== null, `${propFile}: portable should be parsed`);
    }
    if (parsed.resourceFields.has('placeable')) {
      assert(model.placeable !== null, `${propFile}: placeable should be parsed`);
    }
    if (parsed.resourceFields.has('container')) {
      assert(model.container !== null, `${propFile}: container should be parsed`);
    }
    if (parsed.resourceFields.has('light')) {
      assert(model.light !== null, `${propFile}: light should be parsed`);
    }
    if (parsed.resourceFields.has('station')) {
      assert(model.station !== null, `${propFile}: station should be parsed`);
    }
    if (parsed.resourceFields.has('catalogable')) {
      assert(model.catalogable !== null, `${propFile}: catalogable should be parsed`);
    }
    if (parsed.resourceFields.has('endurance')) {
      assert(model.endurance !== null, `${propFile}: endurance should be parsed`);
    }
    if (parsed.resourceFields.has('movement')) {
      assert(model.movement !== null, `${propFile}: movement should be parsed`);
    }
    if (parsed.resourceFields.has('combat')) {
      assert(model.combat !== null, `${propFile}: combat should be parsed`);
    }
    if (parsed.resourceFields.has('behavior')) {
      assert(model.behavior !== null, `${propFile}: behavior should be parsed`);
    }
    if (parsed.resourceFields.has('spawnable')) {
      assert(model.spawnable !== null, `${propFile}: spawnable should be parsed`);
    }
  });
}

// ============================================================
// P00108.tres model round-trip: load → serialize → load again → identical model
// ============================================================

test('PropDefModel — P00108.tres fauna model round-trips through editor', () => {
  const filePath = join(__propsDir, 'P00108.tres');
  const text = readFileSync(filePath, 'utf-8');

  // First load
  const parsed1 = TresParser.parse(text);
  const subMap1 = new Map();
  for (const sub of parsed1.subResources) {
    const subData = {};
    for (const [k, v] of sub.fields) subData[k] = v.value;
    subMap1.set(sub.id, subData);
  }
  const data1 = {};
  for (const [key, tv] of parsed1.resourceFields) {
    data1[key] = tv.type === 'sub_resource' ? (subMap1.get(tv.value) || null) : tv.value;
  }
  const model1 = PropDefModel.fromEntry('P00108.tres', { data: data1, raw: parsed1 });

  // Verify we actually loaded the expected fauna data
  assert(model1.endurance !== null, 'P00108 should have endurance');
  assert(model1.endurance.hp === 20, 'P00108 hp should be 20');
  assert(model1.endurance.vulnerabilities[0] === 'FIRE', 'P00108 vulnerability should be FIRE');
  assert(model1.movement !== null, 'P00108 should have movement');
  assert(Array.isArray(model1.movement.modes), 'P00108 movement.modes should be an array');
  assert(model1.movement.modes.length >= 1, 'P00108 should have at least one movement mode');
  assert(model1.movement.modes[0].mode === 0, 'P00108 first movement mode should be 0 (WALK)');
  assert(model1.movement.modes[0].normal === 1.0, 'P00108 walk normal speed should be 1.0');
  assert(model1.movement.modes[0].max === 1.5, 'P00108 walk max speed should be 1.5');
  assert(model1.combat !== null, 'P00108 should have combat');
  assert(model1.behavior !== null, 'P00108 should have behavior');
  assert(model1.behavior.activity_cycle === 2, 'P00108 activity_cycle should be 2 (NOCTURNAL)');
  assert(model1.behavior.diet[0] === 'FAUNA', 'P00108 diet should be FAUNA');
  assert(model1.spawnable !== null, 'P00108 should have spawnable');
  assert(model1.spawnable.spawn_max === 3, 'P00108 spawn_max should be 3');
  assert(model1.spawnable.first_spawn_day === 4, 'P00108 first_spawn_day should be 4');
  assert(model1.catalogable !== null, 'P00108 should have catalogable');
  assert(model1.tags.length === 2, 'P00108 should have 2 tags');

  // Serialize back to text through the editor model
  const raw2 = propModelToRaw(model1);
  const text2 = TresParser.serialize(raw2);

  // Second load
  const parsed2 = TresParser.parse(text2);
  const subMap2 = new Map();
  for (const sub of parsed2.subResources) {
    const subData = {};
    for (const [k, v] of sub.fields) subData[k] = v.value;
    subMap2.set(sub.id, subData);
  }
  const data2 = {};
  for (const [key, tv] of parsed2.resourceFields) {
    data2[key] = tv.type === 'sub_resource' ? (subMap2.get(tv.value) || null) : tv.value;
  }
  const model2 = PropDefModel.fromEntry('P00108.tres', { data: data2, raw: parsed2 });

  // Verify the two models are structurally identical for all fauna caps
  assert(model2.id === model1.id, 'id should match');
  assert(model2.display_name === model1.display_name, 'display_name should match');
  assert(JSON.stringify(model2.tags) === JSON.stringify(model1.tags), 'tags should match');

  assert(model2.catalogable !== null, 'catalogable should survive round-trip');
  assert(model2.catalogable.scan_time === model1.catalogable.scan_time, 'scan_time should match');
  assert(model2.catalogable.show_as_anomaly === model1.catalogable.show_as_anomaly, 'show_as_anomaly should match');

  assert(model2.endurance !== null, 'endurance should survive round-trip');
  assert(model2.endurance.hp === model1.endurance.hp, 'endurance.hp should match');
  assert(JSON.stringify(model2.endurance.vulnerabilities) === JSON.stringify(model1.endurance.vulnerabilities), 'vulnerabilities should match');
  assert(JSON.stringify(model2.endurance.resistances) === JSON.stringify(model1.endurance.resistances), 'resistances should match');
  assert(JSON.stringify(model2.endurance.immunities) === JSON.stringify(model1.endurance.immunities), 'immunities should match');

  assert(model2.movement !== null, 'movement should survive round-trip');
  assert(model2.movement.modes.length === model1.movement.modes.length, 'modes length should match');
  for (let i = 0; i < model1.movement.modes.length; i++) {
    assert(model2.movement.modes[i].mode === model1.movement.modes[i].mode, `modes[${i}].mode should match`);
    assert(model2.movement.modes[i].normal === model1.movement.modes[i].normal, `modes[${i}].normal should match`);
    assert(model2.movement.modes[i].max === model1.movement.modes[i].max, `modes[${i}].max should match`);
  }

  assert(model2.combat !== null, 'combat should survive round-trip');

  assert(model2.behavior !== null, 'behavior should survive round-trip');
  assert(model2.behavior.detection_range === model1.behavior.detection_range, 'detection_range should match');
  assert(model2.behavior.activity_cycle === model1.behavior.activity_cycle, 'activity_cycle should match');
  assert(model2.behavior.group_behavior === model1.behavior.group_behavior, 'group_behavior should match');
  assert(JSON.stringify(model2.behavior.diet) === JSON.stringify(model1.behavior.diet), 'diet should match');

  assert(model2.spawnable !== null, 'spawnable should survive round-trip');
  assert(model2.spawnable.spawn_min === model1.spawnable.spawn_min, 'spawn_min should match');
  assert(model2.spawnable.spawn_max === model1.spawnable.spawn_max, 'spawn_max should match');
  assert(model2.spawnable.first_spawn_day === model1.spawnable.first_spawn_day, 'first_spawn_day should match');
  assert(model2.spawnable.spawn_min_distance === model1.spawnable.spawn_min_distance, 'spawn_min_distance should match');
  assert(JSON.stringify(model2.spawnable.allowed_biomes) === JSON.stringify(model1.spawnable.allowed_biomes), 'allowed_biomes should match');
});

// ============================================================
// Test Helpers (task-046b)
// ============================================================

/**
 * Create a mock prop entry for testing PropDefModel.fromEntry.
 * @param {Object} overrides - Fields to set on the data object
 * @returns {{data: Object, raw: TresFile}}
 */
function _makePropEntry(overrides) {
  const data = {
    script: 'ExtResource("1_script")',
    id: 'test',
    display_name: 'Test Prop',
    max_stack: 99,
    origin: 0,
    prop_category: 0,
    placeholder_mesh_type: 'cube',
    placeholder_params: new Map(),
    placeholder_color: { r: 1, g: 1, b: 1, a: 1 },
    placeholder_depleted_type: 'cube',
    placeholder_depleted_params: new Map(),
    placeholder_depleted_color: { r: 0.5, g: 0.5, b: 0.5, a: 1 },
    ...overrides,
  };
  const raw = new TresFile();
  raw.scriptClass = 'PropDef';
  raw.headerLine = '[gd_resource type="Resource" script_class="PropDef" load_steps=2 format=3]';
  raw.extResources = ['[ext_resource type="Script" path="res://scripts/data/prop_def.gd" id="1_script"]'];
  return { data, raw };
}

/**
 * Create a model with overrides for validation testing.
 * @param {Object} overrides - Fields to set on the model
 * @returns {PropDefModel}
 */
function _makeModel(overrides) {
  const model = new PropDefModel();
  model.id = 'Ptest';
  model.display_name = 'Test Prop';
  model.max_stack = 99;
  model.placeholder_mesh_type = 'cube';
  model.placeholder_color = { r: 1, g: 1, b: 1, a: 1 };
  model.placeholder_depleted_type = 'cube';
  model.placeholder_depleted_color = { r: 0.5, g: 0.5, b: 0.5, a: 1 };
  for (const [key, val] of Object.entries(overrides)) {
    model[key] = val;
  }
  return model;
}

// ============================================================
// RecipeModel — parsing (task-039b)
// ============================================================

function _makeRecipeEntry(resourceOverrides, subResources) {
  const raw = new TresFile();
  raw.scriptClass = 'Recipe';
  raw.headerLine = '[gd_resource type="Resource" script_class="Recipe" load_steps=2 format=3]';
  raw.extResources = ['[ext_resource type="Script" path="res://scripts/recipes/recipe.gd" id="1_recipe"]'];
  raw.subResources = subResources || [];
  const data = { script: 'ExtResource("1_recipe")', id: 'Rtest', display_name: 'Test Recipe', ...resourceOverrides };
  raw.resourceFields = new Map();
  raw.resourceFields.set('script', { type: 'ext_resource', value: 'ExtResource("1_recipe")' });
  raw.resourceFields.set('id', { type: 'stringname', value: data.id || 'Rtest' });
  raw.resourceFields.set('display_name', { type: 'string', value: data.display_name || 'Test Recipe' });
  raw.resourceFields.set('kind', { type: 'int', value: data.kind || 0 });
  if (data.inputs) raw.resourceFields.set('inputs', { type: 'array', elementType: null, value: data.inputs });
  if (data.outputs) raw.resourceFields.set('outputs', { type: 'array', elementType: null, value: data.outputs });
  if (data.effects) raw.resourceFields.set('effects', { type: 'array', elementType: null, value: data.effects });
  if (data.conditions) raw.resourceFields.set('conditions', { type: 'array', elementType: null, value: data.conditions });
  if (data.actions) raw.resourceFields.set('actions', { type: 'array', elementType: null, value: data.actions });
  if (data.duration != null && data.duration !== 0) raw.resourceFields.set('duration', { type: 'float', value: data.duration });
  if (data.short_description) raw.resourceFields.set('short_description', { type: 'string', value: data.short_description });
  if (data.long_description) raw.resourceFields.set('long_description', { type: 'string', value: data.long_description });
  return { data, raw };
}

function _makeRecipeModel(overrides) {
  const model = new RecipeModel();
  model.id = 'Rtest';
  model.display_name = 'Test Recipe';
  model.duration = 0;
  for (const [key, val] of Object.entries(overrides)) { model[key] = val; }
  return model;
}

test('RecipeModel — fromEntry reads basic fields', () => {
  const entry = _makeRecipeEntry({ duration: 4.0 }, []);
  const model = RecipeModel.fromEntry('R00001.tres', entry);
  assert(model.id === 'R00001', 'id should be R00001');
  assert(model.display_name === 'Test Recipe', 'display_name');
  assert(model.duration === 4.0, 'duration should be 4.0');
  assert(model._filename === 'R00001.tres', '_filename');
});

test('RecipeModel — fromEntry reads inputs via sub_resource resolution', () => {
  const inputFields = new Map();
  inputFields.set('script', { type: 'ext_resource', value: 'ExtResource("2_input")' });
  inputFields.set('ref', { type: 'string', value: 'P00020' });
  inputFields.set('count', { type: 'int', value: 3 });
  const entry = _makeRecipeEntry(
    { inputs: [{ type: 'sub_resource', value: 'input_1' }] },
    [{ type: 'Resource', id: 'input_1', fields: inputFields }],
  );
  const model = RecipeModel.fromEntry('test.tres', entry);
  assert(model.inputs.length === 1, 'should have 1 input');
  assert(model.inputs[0].ref === 'P00020', 'input ref');
  assert(model.inputs[0].count === 3, 'input count');
  assert(model.inputs[0].must_hold === false, 'input must_hold default false');
});

test('RecipeModel — fromEntry reads input with tag ref', () => {
  const inputFields = new Map();
  inputFields.set('script', { type: 'ext_resource', value: 'ExtResource("2_input")' });
  inputFields.set('ref', { type: 'string', value: '&BURNABLE.log' });
  inputFields.set('count', { type: 'int', value: 1 });
  const entry = _makeRecipeEntry(
    { inputs: [{ type: 'sub_resource', value: 'input_1' }] },
    [{ type: 'Resource', id: 'input_1', fields: inputFields }],
  );
  const model = RecipeModel.fromEntry('test.tres', entry);
  assert(model.inputs[0].ref === '&BURNABLE.log', 'ref preserves & prefix');
  assert(model.inputs[0].ref.startsWith('&'), 'tag refs start with &');
});

test('RecipeModel — fromEntry reads input with must_hold true', () => {
  const inputFields = new Map();
  inputFields.set('script', { type: 'ext_resource', value: 'ExtResource("2_input")' });
  inputFields.set('ref', { type: 'string', value: 'P00010' });
  inputFields.set('count', { type: 'int', value: 2 });
  inputFields.set('must_hold', { type: 'bool', value: true });
  const entry = _makeRecipeEntry(
    { inputs: [{ type: 'sub_resource', value: 'input_1' }] },
    [{ type: 'Resource', id: 'input_1', fields: inputFields }],
  );
  const model = RecipeModel.fromEntry('test.tres', entry);
  assert(model.inputs[0].must_hold === true, 'must_hold true');
});

test('RecipeModel — fromEntry reads outputs with prob', () => {
  const outputFields = new Map();
  outputFields.set('script', { type: 'ext_resource', value: 'ExtResource("3_output")' });
  outputFields.set('prop_ref', { type: 'stringname', value: 'branch' });
  outputFields.set('count', { type: 'int', value: 2 });
  outputFields.set('prob', { type: 'float', value: 0.8 });
  const entry = _makeRecipeEntry(
    { outputs: [{ type: 'sub_resource', value: 'output_1' }] },
    [{ type: 'Resource', id: 'output_1', fields: outputFields }],
  );
  const model = RecipeModel.fromEntry('test.tres', entry);
  assert(model.outputs.length === 1, 'should have 1 output');
  assert(model.outputs[0].prop_ref === 'branch', 'prop_ref');
  assert(model.outputs[0].count === 2, 'count');
  assert(model.outputs[0].prob === 0.8, 'prob');
});

test('RecipeModel — fromEntry reads effects with params', () => {
  const effectFields = new Map();
  effectFields.set('script', { type: 'ext_resource', value: 'ExtResource("4_effect")' });
  effectFields.set('kind', { type: 'stringname', value: 'stat_delta' });
  effectFields.set('params', { type: 'dict', value: new Map([['stat', { type: 'string', value: 'hunger' }], ['value', { type: 'int', value: 5 }]]), braceSpaces: true });
  const entry = _makeRecipeEntry(
    { effects: [{ type: 'sub_resource', value: 'effect_1' }] },
    [{ type: 'Resource', id: 'effect_1', fields: effectFields }],
  );
  const model = RecipeModel.fromEntry('test.tres', entry);
  assert(model.effects.length === 1, 'should have 1 effect');
  assert(model.effects[0].kind === 'stat_delta', 'effect kind');
  assert(model.effects[0].params.stat === 'hunger', 'params.stat');
  assert(model.effects[0].params.value === 5, 'params.value');
});

test('RecipeModel — fromEntry reads conditions with nested predicate', () => {
  const predFields = new Map();
  predFields.set('script', { type: 'ext_resource', value: 'ExtResource("6_predicate")' });
  predFields.set('kind', { type: 'stringname', value: 'at_station' });
  predFields.set('params', { type: 'dict', value: new Map([['tag', { type: 'string', value: 'fire' }]]), braceSpaces: true });
  const condFields = new Map();
  condFields.set('script', { type: 'ext_resource', value: 'ExtResource("5_condition")' });
  condFields.set('predicate', { type: 'sub_resource', value: 'cond_pred_1' });
  condFields.set('must_sustain', { type: 'bool', value: true });
  const entry = _makeRecipeEntry(
    { conditions: [{ type: 'sub_resource', value: 'condition_1' }] },
    [
      { type: 'Resource', id: 'cond_pred_1', fields: predFields },
      { type: 'Resource', id: 'condition_1', fields: condFields },
    ],
  );
  const model = RecipeModel.fromEntry('test.tres', entry);
  assert(model.conditions.length === 1, 'should have 1 condition');
  assert(model.conditions[0].predicate_kind === 'at_station', 'predicate_kind');
  assert(model.conditions[0].predicate_params.tag === 'fire', 'predicate_params.tag');
  assert(model.conditions[0].must_sustain === true, 'must_sustain');
});

test('RecipeModel — fromEntry reads actions', () => {
  const entry = _makeRecipeEntry(
    { actions: [{ type: 'stringname', value: 'eat' }, { type: 'stringname', value: 'chop' }] }, [],
  );
  const model = RecipeModel.fromEntry('test.tres', entry);
  assert(model.actions.length === 2, 'should have 2 actions');
  assert(model.actions[0] === 'eat', 'first action');
  assert(model.actions[1] === 'chop', 'second action');
});

test('RecipeModel — fromEntry handles empty arrays', () => {
  const entry = _makeRecipeEntry({}, []);
  const model = RecipeModel.fromEntry('test.tres', entry);
  assert(model.inputs.length === 0, 'no inputs');
  assert(model.outputs.length === 0, 'no outputs');
  assert(model.effects.length === 0, 'no effects');
  assert(model.conditions.length === 0, 'no conditions');
  assert(model.actions.length === 0, 'no actions');
});

// ============================================================
// validateRecipeForm (task-039b)
// ============================================================

test('validateRecipeForm — valid minimal recipe', () => {
  const result = validateRecipeForm(_makeRecipeModel({}), true);
  assert(result.valid === true, 'should be valid');
  assert(result.errors.length === 0, 'no errors');
});

test('validateRecipeForm — missing ID', () => {
  const result = validateRecipeForm(_makeRecipeModel({ id: '' }), true);
  assert(result.valid === false, 'should be invalid');
  assert(result.errors.some(e => e.includes('ID')), 'mention ID');
});

test('validateRecipeForm — invalid ID chars', () => {
  const result = validateRecipeForm(_makeRecipeModel({ id: 'bad recipe!' }), true);
  assert(result.valid === false, 'should be invalid');
});

test('validateRecipeForm — duplicate ID on create', () => {
  ProjectContext.files.recipes.set('Rtest.tres', { data: {}, raw: new TresFile() });
  const result = validateRecipeForm(_makeRecipeModel({}), true);
  assert(result.valid === false, 'should be invalid');
  assert(result.errors.some(e => e.includes('already exists')), 'mention duplicate');
  ProjectContext.files.recipes.delete('Rtest.tres');
});

test('validateRecipeForm — missing display_name', () => {
  const result = validateRecipeForm(_makeRecipeModel({ display_name: '' }), true);
  assert(result.valid === false, 'should be invalid');
});

test('validateRecipeForm — negative duration', () => {
  const result = validateRecipeForm(_makeRecipeModel({ duration: -1 }), true);
  assert(result.valid === false, 'should be invalid');
});

test('validateRecipeForm — input missing ref', () => {
  const result = validateRecipeForm(_makeRecipeModel({ inputs: [{ ref: '', count: 1, must_hold: true }] }), false);
  assert(result.valid === false, 'should be invalid');
});

test('validateRecipeForm — input count < 1', () => {
  const result = validateRecipeForm(_makeRecipeModel({ inputs: [{ ref: 'P00001', count: 0, must_hold: true }] }), false);
  assert(result.valid === false, 'should be invalid');
});

test('validateRecipeForm — output missing prop_ref', () => {
  const result = validateRecipeForm(_makeRecipeModel({ outputs: [{ prop_ref: '', count: 1, prob: 1.0 }] }), false);
  assert(result.valid === false, 'should be invalid');
});

test('validateRecipeForm — output prob > 1', () => {
  const result = validateRecipeForm(_makeRecipeModel({ outputs: [{ prop_ref: '00010', count: 1, prob: 1.5 }] }), false);
  assert(result.valid === false, 'should be invalid');
});

test('validateRecipeForm — output prob < 0', () => {
  const result = validateRecipeForm(_makeRecipeModel({ outputs: [{ prop_ref: '00010', count: 1, prob: -0.1 }] }), false);
  assert(result.valid === false, 'should be invalid');
});

test('validateRecipeForm — output prob = 0 is valid', () => {
  const result = validateRecipeForm(_makeRecipeModel({ outputs: [{ prop_ref: '00010', count: 1, prob: 0 }] }), false);
  assert(result.valid === true, 'prob=0 should be valid');
});

test('validateRecipeForm — effect missing kind', () => {
  const result = validateRecipeForm(_makeRecipeModel({ effects: [{ kind: '', params: {} }] }), false);
  assert(result.valid === false, 'should be invalid');
});

test('validateRecipeForm — condition missing predicate kind', () => {
  const result = validateRecipeForm(_makeRecipeModel({ conditions: [{ predicate_kind: '', predicate_params: {}, must_sustain: false }] }), false);
  assert(result.valid === false, 'should be invalid');
});

test('validateRecipeForm — ID missing R prefix', () => {
  const result = validateRecipeForm(_makeRecipeModel({ id: '00001' }), true);
  assert(result.valid === false, 'should be invalid');
  assert(result.errors.some(e => e.includes('R')), 'mention R prefix');
});

test('validateRecipeForm — valid full recipe', () => {
  const result = validateRecipeForm(_makeRecipeModel({
    inputs: [{ ref: 'P00020', count: 1, must_hold: true }],
    outputs: [{ prop_ref: '00010', count: 2, prob: 0.8 }],
    effects: [{ kind: 'stat_delta', params: { stat: 'hunger', value: 5 } }],
    conditions: [{ predicate_kind: 'at_station', predicate_params: { tag: 'fire' }, must_sustain: true }],
    actions: ['eat'], duration: 3.0,
  }), true);
  assert(result.valid === true, 'should be valid');
  assert(result.errors.length === 0, 'no errors');
});

// ============================================================
// recipeModelToRaw — serialization (task-039b)
// ============================================================

test('recipeModelToRaw — serializes basic recipe', () => {
  const raw = recipeModelToRaw(_makeRecipeModel({ display_name: 'Eat Berry' }));
  assert(raw.scriptClass === 'Recipe', 'scriptClass');
  assert(raw.resourceFields.has('id'), 'should have id');
  assert(raw.resourceFields.get('display_name').value === 'Eat Berry', 'display_name value');
});

test('recipeModelToRaw — serializes inputs as sub_resources', () => {
  const raw = recipeModelToRaw(_makeRecipeModel({
    inputs: [{ ref: 'P00020', count: 1, must_hold: true }],
  }));
  assert(raw.subResources.length >= 1, 'should have sub_resources');
  const inputSub = raw.subResources.find(s => s.id === 'input_1');
  assert(inputSub != null, 'should have input_1');
  assert(inputSub.fields.get('ref').value === 'P00020', 'ref');
  assert(inputSub.fields.get('must_hold').value === true, 'must_hold written when true');
});

test('recipeModelToRaw — omits must_hold when false', () => {
  const raw = recipeModelToRaw(_makeRecipeModel({
    inputs: [{ ref: 'P00001', count: 1, must_hold: false }],
  }));
  const inputSub = raw.subResources.find(s => s.id === 'input_1');
  assert(inputSub != null, 'should have input_1');
  assert(!inputSub.fields.has('must_hold'), 'must_hold omitted when false');
});

test('recipeModelToRaw — serializes tag input with & prefix', () => {
  const raw = recipeModelToRaw(_makeRecipeModel({
    inputs: [{ ref: '&BURNABLE.log', count: 1, must_hold: false }],
  }));
  const inputSub = raw.subResources.find(s => s.id === 'input_1');
  assert(inputSub != null, 'should have input_1');
  assert(inputSub.fields.get('ref').value === '&BURNABLE.log', 'tag ref keeps & prefix');
});

test('recipeModelToRaw — serializes outputs with prob', () => {
  const raw = recipeModelToRaw(_makeRecipeModel({
    outputs: [{ prop_ref: 'branch', count: 2, prob: 0.8 }],
  }));
  const outputSub = raw.subResources.find(s => s.id === 'output_1');
  assert(outputSub != null, 'should have output_1');
  assert(outputSub.fields.get('prop_ref').value === 'branch', 'prop_ref');
  assert(outputSub.fields.get('prob').value === 0.8, 'prob');
});

test('recipeModelToRaw — omits prob when 1.0', () => {
  const raw = recipeModelToRaw(_makeRecipeModel({
    outputs: [{ prop_ref: '00010', count: 1, prob: 1.0 }],
  }));
  const outputSub = raw.subResources.find(s => s.id === 'output_1');
  assert(outputSub != null, 'should have output_1');
  assert(!outputSub.fields.has('prob'), 'prob omitted when 1.0');
});

test('recipeModelToRaw — serializes conditions with nested predicate', () => {
  const raw = recipeModelToRaw(_makeRecipeModel({
    conditions: [{ predicate_kind: 'has_tool', predicate_params: { tool: 'axe' }, must_sustain: true }],
  }));
  const predSub = raw.subResources.find(s => s.id === 'cond_pred_1');
  assert(predSub != null, 'should have cond_pred_1');
  assert(predSub.fields.get('kind').value === 'has_tool', 'predicate kind');
  const condSub = raw.subResources.find(s => s.id === 'condition_1');
  assert(condSub != null, 'should have condition_1');
  assert(condSub.fields.get('must_sustain').value === true, 'must_sustain');
  assert(condSub.fields.get('predicate').type === 'sub_resource', 'predicate is sub_resource ref');
});

test('recipeModelToRaw — serializes actions', () => {
  const raw = recipeModelToRaw(_makeRecipeModel({ actions: ['eat', 'chop'] }));
  const actionsField = raw.resourceFields.get('actions');
  assert(actionsField != null, 'should have actions');
  assert(actionsField.value.length === 2, '2 actions');
  assert(actionsField.value[0].value === 'eat', 'action value');
});

test('recipeModelToRaw — no sub_resources when empty', () => {
  const raw = recipeModelToRaw(_makeRecipeModel({}));
  assert(raw.subResources.length === 0, 'no sub_resources');
});

test('recipeModelToRaw — serialized output is valid .tres', () => {
  const raw = recipeModelToRaw(_makeRecipeModel({
    inputs: [{ ref: 'P00001', count: 1, must_hold: false }],
    outputs: [{ prop_ref: '00010', count: 3, prob: 1.0 }, { prop_ref: 'branch', count: 2, prob: 0.8 }],
    effects: [{ kind: 'sound', params: { sound_id: 'chop' } }],
    actions: ['chop'], duration: 4.0,
  }));
  const text = TresParser.serialize(raw);
  assert(text.includes('[gd_resource'), 'should have header');
  assert(text.includes('script_class="Recipe"'), 'Recipe class');
  const reparsed = TresParser.parse(text);
  assert(reparsed.scriptClass === 'Recipe', 'should reparse as Recipe');
});

// ============================================================
// RecipeModel round-trip: fromEntry -> recipeModelToRaw -> parse -> fromEntry (task-039b)
// ============================================================

test('RecipeModel — full round-trip with all fields', () => {
  const original = _makeRecipeModel({
    display_name: 'Chop Small Tree',
    inputs: [{ ref: 'P00001', count: 1, must_hold: false }],
    outputs: [{ prop_ref: '00010', count: 3, prob: 1.0 }, { prop_ref: 'branch', count: 2, prob: 0.8 }],
    effects: [{ kind: 'sound', params: { sound_id: 'chop' } }],
    conditions: [{ predicate_kind: 'has_tool', predicate_params: { tool: 'axe' }, must_sustain: true }],
    actions: ['chop'], duration: 4.0,
  });
  const raw = recipeModelToRaw(original);
  const text = TresParser.serialize(raw);
  const reparsed = TresParser.parse(text);
  const subMap = new Map();
  for (const sub of reparsed.subResources) {
    const subData = {};
    for (const [k, v] of sub.fields) { subData[k] = v.value; }
    subMap.set(sub.id, subData);
  }
  const data = {};
  for (const [key, tv] of reparsed.resourceFields) {
    if (tv.type === 'sub_resource') { data[key] = subMap.get(tv.value) || null; }
    else { data[key] = tv.value; }
  }
  const restored = RecipeModel.fromEntry('Rtest.tres', { data, raw: reparsed });
  assert(restored.id === original.id, 'id round-trip');
  assert(restored.display_name === original.display_name, 'display_name round-trip');
  assert(restored.duration === original.duration, 'duration round-trip');
  assert(restored.actions.length === 1, 'actions count');
  assert(restored.actions[0] === 'chop', 'actions[0]');
  assert(restored.inputs.length === 1, 'inputs count');
  assert(restored.inputs[0].ref === 'P00001', 'input ref');
  assert(restored.inputs[0].must_hold === false, 'input must_hold');
  assert(restored.outputs.length === 2, 'outputs count');
  assert(restored.outputs[0].prop_ref === '00010', 'output[0] prop_ref');
  assert(restored.outputs[1].prob === 0.8, 'output[1] prob');
  assert(restored.effects.length === 1, 'effects count');
  assert(restored.effects[0].kind === 'sound', 'effect kind');
  assert(restored.conditions.length === 1, 'conditions count');
  assert(restored.conditions[0].predicate_kind === 'has_tool', 'condition predicate_kind');
  assert(restored.conditions[0].must_sustain === true, 'condition must_sustain');
});

test('RecipeModel — round-trip with no optional fields', () => {
  const original = _makeRecipeModel({});
  const raw = recipeModelToRaw(original);
  const text = TresParser.serialize(raw);
  const reparsed = TresParser.parse(text);
  const subMap = new Map();
  for (const sub of reparsed.subResources) {
    const subData = {};
    for (const [k, v] of sub.fields) { subData[k] = v.value; }
    subMap.set(sub.id, subData);
  }
  const data = {};
  for (const [key, tv] of reparsed.resourceFields) {
    if (tv.type === 'sub_resource') { data[key] = subMap.get(tv.value) || null; }
    else { data[key] = tv.value; }
  }
  const restored = RecipeModel.fromEntry('Rtest.tres', { data, raw: reparsed });
  assert(restored.id === 'Rtest', 'id');
  assert(restored.display_name === 'Test Recipe', 'display_name');
  assert(restored.inputs.length === 0, 'no inputs');
  assert(restored.outputs.length === 0, 'no outputs');
  assert(restored.conditions.length === 0, 'no conditions');
  assert(restored.actions.length === 0, 'no actions');
});

// ============================================================
// RecipeModel round-trip from actual .tres files (task-039b)
// ============================================================

const __recipesDir = join(__projectRoot, 'data', 'recipes');
let __recipeFiles = [];
try { __recipeFiles = readdirSync(__recipesDir).filter(f => f.endsWith('.tres')); }
catch (e) { console.warn('Could not read data/recipes/:', e.message); }

for (const recipeFile of __recipeFiles) {
  test(`RecipeModel round-trip — ${recipeFile}`, () => {
    const filePath = join(__recipesDir, recipeFile);
    const text = readFileSync(filePath, 'utf-8');
    const parsed = TresParser.parse(text);
    assert(parsed.scriptClass === 'Recipe', `${recipeFile}: scriptClass`);

    // Verify TresParser round-trip
    const serialized = TresParser.serialize(parsed);
    assert(serialized === text, `${recipeFile}: TresParser round-trip`);

    // Build resolved data
    const subMap = new Map();
    for (const sub of parsed.subResources) {
      const subData = {};
      for (const [k, v] of sub.fields) { subData[k] = v.value; }
      subMap.set(sub.id, subData);
    }
    const data = {};
    for (const [key, tv] of parsed.resourceFields) {
      if (tv.type === 'sub_resource') { data[key] = subMap.get(tv.value) || null; }
      else { data[key] = tv.value; }
    }

    const model = RecipeModel.fromEntry(recipeFile, { data, raw: parsed });
    assert(model.id === recipeFile.replace('.tres', ''), `${recipeFile}: id`);
    assert(typeof model.display_name === 'string', `${recipeFile}: display_name is string`);
    assert(model.duration >= 0, `${recipeFile}: duration >= 0`);
    assert(Array.isArray(model.inputs), `${recipeFile}: inputs is array`);
    assert(Array.isArray(model.outputs), `${recipeFile}: outputs is array`);

    // Verify inputs have valid fields
    for (const inp of model.inputs) {
      assert(typeof inp.ref === 'string' && inp.ref.length > 0, `${recipeFile}: input ref`);
      assert(inp.count >= 1, `${recipeFile}: input count >= 1`);
      assert(typeof inp.must_hold === 'boolean', `${recipeFile}: input must_hold boolean`);
    }
    // Verify outputs have valid fields
    for (const out of model.outputs) {
      assert(typeof out.prop_ref === 'string' && out.prop_ref.length > 0, `${recipeFile}: output prop_ref`);
      assert(out.prob >= 0 && out.prob <= 1, `${recipeFile}: output prob in [0,1]`);
    }

    // Serialize back and verify round-trip
    const raw2 = recipeModelToRaw(model);
    const text2 = TresParser.serialize(raw2);
    const reparsed = TresParser.parse(text2);
    assert(reparsed.scriptClass === 'Recipe', `${recipeFile}: re-serialized scriptClass`);

    const subMap2 = new Map();
    for (const sub of reparsed.subResources) {
      const subData = {};
      for (const [k, v] of sub.fields) { subData[k] = v.value; }
      subMap2.set(sub.id, subData);
    }
    const data2 = {};
    for (const [key, tv] of reparsed.resourceFields) {
      if (tv.type === 'sub_resource') { data2[key] = subMap2.get(tv.value) || null; }
      else { data2[key] = tv.value; }
    }

    const model2 = RecipeModel.fromEntry(recipeFile, { data: data2, raw: reparsed });
    assert(model2.id === model.id, `${recipeFile}: id survives round-trip`);
    assert(model2.display_name === model.display_name, `${recipeFile}: display_name survives`);
    assert(model2.inputs.length === model.inputs.length, `${recipeFile}: inputs count survives`);
    assert(model2.outputs.length === model.outputs.length, `${recipeFile}: outputs count survives`);
    assert(model2.effects.length === model.effects.length, `${recipeFile}: effects count survives`);
    assert(model2.conditions.length === model.conditions.length, `${recipeFile}: conditions count survives`);
    assert(model2.actions.length === model.actions.length, `${recipeFile}: actions count survives`);
    assert(model2.duration === model.duration, `${recipeFile}: duration survives`);
  });
}

// ============================================================
// Constants exports (task-039b)
// ============================================================

test('Recipe constants — PREDICATE_KINDS has expected entries', () => {
  assert(PREDICATE_KINDS.includes('has_tool'), 'includes has_tool');
  assert(PREDICATE_KINDS.includes('cataloged'), 'includes cataloged');
  assert(PREDICATE_KINDS.includes('at_station'), 'includes at_station');
});

// ============================================================
// EventModel — parsing
// ============================================================

function _makeEventEntry(resourceOverrides, subResources) {
  const raw = new TresFile();
  raw.scriptClass = 'GameEvent';
  raw.headerLine = '[gd_resource type="Resource" script_class="GameEvent" load_steps=2 format=3]';
  raw.extResources = ['[ext_resource type="Script" path="res://scripts/core/event.gd" id="1_event"]'];
  raw.subResources = subResources || [];
  const data = { script: 'ExtResource("1_event")', id: 'E00001', display_name: 'Test Event', max_count: 1, ...resourceOverrides };
  raw.resourceFields = new Map();
  raw.resourceFields.set('script', { type: 'ext_resource', value: 'ExtResource("1_event")' });
  raw.resourceFields.set('id', { type: 'stringname', value: data.id || 'E00001' });
  raw.resourceFields.set('display_name', { type: 'string', value: data.display_name || 'Test Event' });
  if (data.max_count != null) raw.resourceFields.set('max_count', { type: 'int', value: data.max_count });
  if (data.count != null && data.count !== 0) raw.resourceFields.set('count', { type: 'int', value: data.count });
  if (data.conditions) raw.resourceFields.set('conditions', { type: 'array', elementType: null, value: data.conditions });
  if (data.effects) raw.resourceFields.set('effects', { type: 'array', elementType: null, value: data.effects });
  if (data.actions) raw.resourceFields.set('actions', { type: 'array', elementType: null, value: data.actions });
  if (data.duration != null && data.duration !== 0) raw.resourceFields.set('duration', { type: 'float', value: data.duration });
  if (data.short_description) raw.resourceFields.set('short_description', { type: 'string', value: data.short_description });
  if (data.long_description) raw.resourceFields.set('long_description', { type: 'string', value: data.long_description });
  return { data, raw };
}

function _makeEventModel(overrides) {
  const model = new EventModel();
  model.id = 'Etest';
  model.display_name = 'Test Event';
  model.max_count = 1;
  model.count = 0;
  model.duration = 0;
  for (const [key, val] of Object.entries(overrides)) { model[key] = val; }
  return model;
}

test('EventModel — fromEntry reads basic fields', () => {
  const entry = _makeEventEntry({ max_count: 3, id: 'E00005', display_name: 'Discover Something' }, []);
  const model = EventModel.fromEntry('E00005.tres', entry);
  assert(model.id === 'E00005', 'id should be E00005');
  assert(model.display_name === 'Discover Something', 'display_name');
  assert(model.max_count === 3, 'max_count should be 3');
  assert(model.count === 0, 'count should default to 0');
  assert(model._filename === 'E00005.tres', '_filename');
});

test('EventModel — fromEntry reads effects via sub_resource resolution', () => {
  const effectFields = new Map();
  effectFields.set('script', { type: 'ext_resource', value: 'ExtResource("4_effect")' });
  effectFields.set('kind', { type: 'stringname', value: 'grant_recipe' });
  effectFields.set('params', { type: 'dict', value: new Map([['recipe_id', { type: 'string', value: 'R00001' }]]) });
  const entry = _makeEventEntry(
    { effects: [{ type: 'sub_resource', value: 'effect_1' }] },
    [{ type: 'Resource', id: 'effect_1', fields: effectFields }],
  );
  const model = EventModel.fromEntry('test.tres', entry);
  assert(model.effects.length === 1, 'should have 1 effect');
  assert(model.effects[0].kind === 'grant_recipe', 'effect kind');
  assert(model.effects[0].params.recipe_id === 'R00001', 'effect param');
});

test('EventModel — fromEntry reads conditions with nested predicate', () => {
  const predFields = new Map();
  predFields.set('script', { type: 'ext_resource', value: 'ExtResource("3_predicate")' });
  predFields.set('kind', { type: 'stringname', value: 'cataloged' });
  predFields.set('params', { type: 'dict', value: new Map([['prop', { type: 'string', value: 'P00001' }]]) });
  const condFields = new Map();
  condFields.set('script', { type: 'ext_resource', value: 'ExtResource("2_condition")' });
  condFields.set('predicate', { type: 'sub_resource', value: 'cond_pred_1' });
  condFields.set('must_sustain', { type: 'bool', value: false });
  const entry = _makeEventEntry(
    { conditions: [{ type: 'sub_resource', value: 'condition_1' }] },
    [
      { type: 'Resource', id: 'cond_pred_1', fields: predFields },
      { type: 'Resource', id: 'condition_1', fields: condFields },
    ],
  );
  const model = EventModel.fromEntry('test.tres', entry);
  assert(model.conditions.length === 1, 'should have 1 condition');
  assert(model.conditions[0].predicate_kind === 'cataloged', 'predicate kind');
  assert(model.conditions[0].predicate_params.prop === 'P00001', 'predicate param');
});

test('EventModel — fromEntry reads actions', () => {
  const entry = _makeEventEntry({
    actions: [{ type: 'stringname', value: 'discover' }, { type: 'stringname', value: 'trigger' }],
  }, []);
  const model = EventModel.fromEntry('test.tres', entry);
  assert(model.actions.length === 2, 'should have 2 actions');
  assert(model.actions[0] === 'discover', 'first action');
  assert(model.actions[1] === 'trigger', 'second action');
});

test('EventModel — fromEntry handles empty arrays', () => {
  const entry = _makeEventEntry({}, []);
  const model = EventModel.fromEntry('test.tres', entry);
  assert(model.conditions.length === 0, 'conditions empty');
  assert(model.effects.length === 0, 'effects empty');
  assert(model.actions.length === 0, 'actions empty');
});

test('EventModel — fromEntry reads duration', () => {
  const entry = _makeEventEntry({ duration: 5.0 }, []);
  const model = EventModel.fromEntry('test.tres', entry);
  assert(model.duration === 5.0, 'duration should be 5.0');
});

test('EventModel — fromEntry reads short/long description', () => {
  const entry = _makeEventEntry({ short_description: 'short', long_description: 'long' }, []);
  const model = EventModel.fromEntry('test.tres', entry);
  assert(model.short_description === 'short', 'short_description');
  assert(model.long_description === 'long', 'long_description');
});

// ============================================================
// validateEventForm
// ============================================================

test('validateEventForm — valid minimal event', () => {
  const result = validateEventForm(_makeEventModel({}), true);
  assert(result.valid, 'should be valid');
  assert(result.errors.length === 0, 'no errors');
});

test('validateEventForm — missing ID', () => {
  const result = validateEventForm(_makeEventModel({ id: '' }), true);
  assert(!result.valid, 'should be invalid');
  assert(result.errors.some(e => e.includes('ID is required')), 'ID required error');
});

test('validateEventForm — invalid ID chars', () => {
  const result = validateEventForm(_makeEventModel({ id: 'bad event!' }), true);
  assert(!result.valid, 'should be invalid');
});

test('validateEventForm — ID missing E prefix', () => {
  const result = validateEventForm(_makeEventModel({ id: '00001' }), true);
  assert(!result.valid, 'should be invalid');
  assert(result.errors.some(e => e.includes('start with "E"')), 'E prefix error');
});

test('validateEventForm — duplicate ID on create', () => {
  ProjectContext.files.events.set('Etest.tres', { data: {}, raw: new TresFile() });
  const result = validateEventForm(_makeEventModel({}), true);
  assert(!result.valid, 'should be invalid');
  assert(result.errors.some(e => e.includes('already exists')), 'duplicate error');
  ProjectContext.files.events.delete('Etest.tres');
});

test('validateEventForm — missing display_name', () => {
  const result = validateEventForm(_makeEventModel({ display_name: '' }), true);
  assert(!result.valid, 'should be invalid');
  assert(result.errors.some(e => e.includes('Display Name')), 'display_name error');
});

test('validateEventForm — negative max_count', () => {
  const result = validateEventForm(_makeEventModel({ max_count: -1 }), true);
  assert(!result.valid, 'should be invalid');
  assert(result.errors.some(e => e.includes('Max Count')), 'max_count error');
});

test('validateEventForm — max_count 0 is valid (unlimited)', () => {
  const result = validateEventForm(_makeEventModel({ max_count: 0 }), true);
  assert(result.valid, 'should be valid');
});

test('validateEventForm — negative duration', () => {
  const result = validateEventForm(_makeEventModel({ duration: -1 }), true);
  assert(!result.valid, 'should be invalid');
  assert(result.errors.some(e => e.includes('Duration')), 'duration error');
});

test('validateEventForm — effect missing kind', () => {
  const result = validateEventForm(_makeEventModel({ effects: [{ kind: '', params: {} }] }), false);
  assert(!result.valid, 'should be invalid');
  assert(result.errors.some(e => e.includes('Effect #1')), 'effect error');
});

test('validateEventForm — condition missing predicate kind', () => {
  const result = validateEventForm(_makeEventModel({ conditions: [{ predicate_kind: '', predicate_params: {}, must_sustain: false }] }), false);
  assert(!result.valid, 'should be invalid');
  assert(result.errors.some(e => e.includes('Condition #1')), 'condition error');
});

// ============================================================
// eventModelToRaw — serialization
// ============================================================

test('eventModelToRaw — serializes basic event', () => {
  const raw = eventModelToRaw(_makeEventModel({ display_name: 'Discover Berry' }));
  assert(raw.scriptClass === 'GameEvent', 'scriptClass');
  assert(raw.headerLine.includes('GameEvent'), 'header');
  assert(raw.resourceFields.get('display_name').value === 'Discover Berry', 'display_name');
  assert(raw.resourceFields.get('id').value === 'Etest', 'id');
});

test('eventModelToRaw — serializes conditions with nested predicate', () => {
  const raw = eventModelToRaw(_makeEventModel({
    conditions: [{ predicate_kind: 'cataloged', predicate_params: { prop: 'P00001' }, must_sustain: false }],
  }));
  assert(raw.subResources.length === 2, 'should have 2 sub_resources (predicate + condition)');
  assert(raw.resourceFields.get('conditions').value.length === 1, '1 condition ref');
});

test('eventModelToRaw — serializes effects', () => {
  const raw = eventModelToRaw(_makeEventModel({
    effects: [{ kind: 'grant_recipe', params: { recipe_id: 'R00001' } }],
  }));
  assert(raw.subResources.length === 1, 'should have 1 sub_resource (effect)');
  assert(raw.resourceFields.get('effects').value.length === 1, '1 effect ref');
});

test('eventModelToRaw — serializes actions', () => {
  const raw = eventModelToRaw(_makeEventModel({ actions: ['discover', 'trigger'] }));
  const actions = raw.resourceFields.get('actions');
  assert(actions, 'should have actions field');
  assert(actions.value.length === 2, '2 actions');
  assert(actions.value[0].value === 'discover', 'first action');
});

test('eventModelToRaw — no sub_resources when empty', () => {
  const raw = eventModelToRaw(_makeEventModel({}));
  assert(raw.subResources.length === 0, 'no sub_resources');
});

test('eventModelToRaw — serializes max_count', () => {
  const raw = eventModelToRaw(_makeEventModel({ max_count: 5 }));
  assert(raw.resourceFields.get('max_count').value === 5, 'max_count should be 5');
});

test('eventModelToRaw — serialized output is valid .tres', () => {
  const raw = eventModelToRaw(_makeEventModel({
    conditions: [{ predicate_kind: 'cataloged', predicate_params: { prop: 'P00001' }, must_sustain: false }],
    effects: [{ kind: 'grant_recipe', params: { recipe_id: 'R00018' } }],
    max_count: 1,
  }));
  const text = TresParser.serialize(raw);
  assert(text.includes('[gd_resource type="Resource" script_class="GameEvent"'), 'header');
  assert(text.includes('res://scripts/core/event.gd'), 'event script');
  assert(text.includes('res://scripts/recipes/recipe_condition.gd'), 'condition script');
  assert(text.includes('res://scripts/recipes/predicate.gd'), 'predicate script');
  assert(text.includes('res://scripts/recipes/recipe_effect.gd'), 'effect script');
});

// ============================================================
// EventModel round-trip: fromEntry -> eventModelToRaw -> parse -> fromEntry
// ============================================================

test('EventModel — full round-trip with all fields', () => {
  const original = _makeEventModel({
    conditions: [{ predicate_kind: 'cataloged', predicate_params: { prop: 'P00001' }, must_sustain: false }],
    effects: [{ kind: 'grant_recipe', params: { recipe_id: 'R00018' } }],
    actions: ['discover'],
    duration: 2.5,
    max_count: 1,
  });
  const raw = eventModelToRaw(original);
  const serialized = TresParser.serialize(raw);

  // Re-parse
  const reparsed = TresParser.parse(serialized);
  assert(reparsed.scriptClass === 'GameEvent', 'reparsed scriptClass');

  const subResourceMap = new Map();
  if (reparsed.subResources) {
    for (const sub of reparsed.subResources) {
      const subData = {};
      for (const [k, v] of sub.fields) { subData[k] = v.value; }
      subResourceMap.set(sub.id, subData);
    }
  }
  const data = {};
  for (const [key, tv] of reparsed.resourceFields) {
    if (tv.type === 'sub_resource') { data[key] = subResourceMap.get(tv.value) || null; }
    else { data[key] = tv.value; }
  }

  const restored = EventModel.fromEntry('Etest.tres', { data, raw: reparsed });
  assert(restored.id === original.id, 'id survives round-trip');
  assert(restored.display_name === original.display_name, 'display_name survives');
  assert(restored.conditions.length === original.conditions.length, 'conditions count survives');
  assert(restored.effects.length === original.effects.length, 'effects count survives');
  assert(restored.actions.length === original.actions.length, 'actions count survives');
  assert(restored.duration === original.duration, 'duration survives');
  assert(restored.max_count === original.max_count, 'max_count survives');
  assert(restored.conditions[0].predicate_kind === 'cataloged', 'condition predicate survives');
  assert(restored.effects[0].kind === 'grant_recipe', 'effect kind survives');
});

test('EventModel — round-trip with no optional fields', () => {
  const original = _makeEventModel({});
  const raw = eventModelToRaw(original);
  const serialized = TresParser.serialize(raw);

  const reparsed = TresParser.parse(serialized);
  assert(reparsed.scriptClass === 'GameEvent', 'reparsed scriptClass');

  const subResourceMap = new Map();
  if (reparsed.subResources) {
    for (const sub of reparsed.subResources) {
      const subData = {};
      for (const [k, v] of sub.fields) { subData[k] = v.value; }
      subResourceMap.set(sub.id, subData);
    }
  }
  const data = {};
  for (const [key, tv] of reparsed.resourceFields) {
    if (tv.type === 'sub_resource') { data[key] = subResourceMap.get(tv.value) || null; }
    else { data[key] = tv.value; }
  }

  const restored = EventModel.fromEntry('Etest.tres', { data, raw: reparsed });
  assert(restored.id === original.id, 'id');
  assert(restored.display_name === original.display_name, 'display_name');
  assert(restored.conditions.length === 0, 'conditions empty');
  assert(restored.effects.length === 0, 'effects empty');
  assert(restored.actions.length === 0, 'actions empty');
});

// ============================================================
// EventModel round-trip from actual .tres files
// ============================================================

const __eventsDir = join(__projectRoot, 'data', 'events');
let __eventFiles = [];
try { __eventFiles = readdirSync(__eventsDir).filter(f => f.endsWith('.tres')); }
catch (e) { console.warn('Could not read data/events/:', e.message); }

for (const eventFile of __eventFiles) {
  test(`EventModel round-trip — ${eventFile}`, () => {
    const filePath = join(__eventsDir, eventFile);
    const text = readFileSync(filePath, 'utf-8');

    const parsed = TresParser.parse(text);
    assert(parsed.scriptClass === 'GameEvent', `${eventFile}: scriptClass`);

    // TresParser round-trip
    const serialized = TresParser.serialize(parsed);
    assert(serialized === text, `${eventFile}: TresParser round-trip`);

    // Build data for fromEntry
    const subResourceMap = new Map();
    if (parsed.subResources) {
      for (const sub of parsed.subResources) {
        const subData = {};
        for (const [k, v] of sub.fields) { subData[k] = v.value; }
        subResourceMap.set(sub.id, subData);
      }
    }
    const data = {};
    for (const [key, tv] of parsed.resourceFields) {
      if (tv.type === 'sub_resource') { data[key] = subResourceMap.get(tv.value) || null; }
      else { data[key] = tv.value; }
    }

    // Parse into model
    const model = EventModel.fromEntry(eventFile, { data, raw: parsed });
    assert(typeof model.id === 'string' && model.id.length > 0, `${eventFile}: id`);
    assert(typeof model.display_name === 'string', `${eventFile}: display_name is string`);
    assert(model.max_count >= 0, `${eventFile}: max_count >= 0`);
    assert(model.duration >= 0, `${eventFile}: duration >= 0`);
    assert(Array.isArray(model.conditions), `${eventFile}: conditions is array`);
    assert(Array.isArray(model.effects), `${eventFile}: effects is array`);

    // Re-serialize and compare
    const raw2 = eventModelToRaw(model);
    const serialized2 = TresParser.serialize(raw2);
    const reparsed = TresParser.parse(serialized2);
    assert(reparsed.scriptClass === 'GameEvent', `${eventFile}: re-serialized scriptClass`);

    // Build data2 for fromEntry
    const subResourceMap2 = new Map();
    if (reparsed.subResources) {
      for (const sub of reparsed.subResources) {
        const subData = {};
        for (const [k, v] of sub.fields) { subData[k] = v.value; }
        subResourceMap2.set(sub.id, subData);
      }
    }
    const data2 = {};
    for (const [key, tv] of reparsed.resourceFields) {
      if (tv.type === 'sub_resource') { data2[key] = subResourceMap2.get(tv.value) || null; }
      else { data2[key] = tv.value; }
    }

    const model2 = EventModel.fromEntry(eventFile, { data: data2, raw: reparsed });
    assert(model2.id === model.id, `${eventFile}: id survives round-trip`);
    assert(model2.display_name === model.display_name, `${eventFile}: display_name survives`);
    assert(model2.conditions.length === model.conditions.length, `${eventFile}: conditions count survives`);
    assert(model2.effects.length === model.effects.length, `${eventFile}: effects count survives`);
    assert(model2.actions.length === model.actions.length, `${eventFile}: actions count survives`);
    assert(model2.duration === model.duration, `${eventFile}: duration survives`);
    assert(model2.max_count === model.max_count, `${eventFile}: max_count survives`);
  });
}

// ============================================================
// BiomeDataModel round-trip from actual .tres files
// ============================================================

const __biomesDir = join(__projectRoot, 'data', 'biomes');
let __biomeFiles = [];
try { __biomeFiles = readdirSync(__biomesDir).filter(f => f.endsWith('.tres')); }
catch (e) { console.warn('Could not read data/biomes:', e.message); }

for (const biomeFile of __biomeFiles) {
  test(`BiomeDataModel round-trip — ${biomeFile}`, () => {
    const filePath = join(__biomesDir, biomeFile);
    const text = readFileSync(filePath, 'utf-8');

    // Parse
    const parsed = TresParser.parse(text);
    assert(parsed.scriptClass === 'BiomeData', `${biomeFile}: scriptClass should be BiomeData`);

    // Verify TresParser round-trip
    const serialized = TresParser.serialize(parsed);
    assert(serialized === text, `${biomeFile}: TresParser round-trip`);

    // Build data object (same as file-discovery _parseTresFile)
    const data = {};
    for (const [key, tv] of parsed.resourceFields) {
      data[key] = tv.value;
    }

    // Parse into model
    const model = BiomeDataModel.fromEntry(biomeFile, { data, raw: parsed });
    assert(typeof model.id === 'string' && model.id.length > 0, `${biomeFile}: id`);
    assert(typeof model.biome_name === 'string' && model.biome_name.length > 0, `${biomeFile}: biome_name`);
    assert(typeof model.elevation_range.min === 'number', `${biomeFile}: elevation_range.min is number`);
    assert(typeof model.elevation_range.max === 'number', `${biomeFile}: elevation_range.max is number`);
    assert(model.elevation_range.min <= model.elevation_range.max, `${biomeFile}: elevation min <= max`);
    assert(Array.isArray(model.prop_table), `${biomeFile}: prop_table is array`);
    assert(Array.isArray(model.color_variations), `${biomeFile}: color_variations is array`);
    assert(typeof model.color.r === 'number', `${biomeFile}: color.r is number`);

    // Verify prop_table entries have P-prefixed types (if non-empty)
    for (let i = 0; i < model.prop_table.length; i++) {
      const entry = model.prop_table[i];
      assert(typeof entry.type === 'string', `${biomeFile}: prop_table[${i}].type is string`);
      assert(entry.type.startsWith('P'), `${biomeFile}: prop_table[${i}].type "${entry.type}" has P prefix`);
      assert(typeof entry.chance === 'number', `${biomeFile}: prop_table[${i}].chance is number`);
      assert(typeof entry.min_amount === 'number', `${biomeFile}: prop_table[${i}].min_amount is number`);
      assert(typeof entry.max_amount === 'number', `${biomeFile}: prop_table[${i}].max_amount is number`);
    }

    // Re-serialize through model and compare
    const raw2 = biomeModelToRaw(model);
    const text2 = TresParser.serialize(raw2);
    const reparsed = TresParser.parse(text2);
    assert(reparsed.scriptClass === 'BiomeData', `${biomeFile}: re-serialized scriptClass`);

    // Build data2 for fromEntry
    const data2 = {};
    for (const [key, tv] of reparsed.resourceFields) {
      data2[key] = tv.value;
    }

    const model2 = BiomeDataModel.fromEntry(biomeFile, { data: data2, raw: reparsed });
    assert(model2.id === model.id, `${biomeFile}: id survives round-trip`);
    assert(model2.biome_name === model.biome_name, `${biomeFile}: biome_name survives`);
    assert(model2.elevation_range.min === model.elevation_range.min, `${biomeFile}: elevation min survives`);
    assert(model2.elevation_range.max === model.elevation_range.max, `${biomeFile}: elevation max survives`);
    assert(model2.prop_table.length === model.prop_table.length, `${biomeFile}: prop_table count survives`);
    for (let i = 0; i < model.prop_table.length; i++) {
      assert(model2.prop_table[i].type === model.prop_table[i].type, `${biomeFile}: prop_table[${i}].type survives`);
      assert(model2.prop_table[i].chance === model.prop_table[i].chance, `${biomeFile}: prop_table[${i}].chance survives`);
      assert(model2.prop_table[i].min_amount === model.prop_table[i].min_amount, `${biomeFile}: prop_table[${i}].min_amount survives`);
      assert(model2.prop_table[i].max_amount === model.prop_table[i].max_amount, `${biomeFile}: prop_table[${i}].max_amount survives`);
    }
    assert(model2.color_variations.length === model.color_variations.length, `${biomeFile}: color_variations count survives`);
  });
}

// ============================================================
// Summary
// ============================================================

console.log(`\n${passed + failed} assertions: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
