/**
 * Unit tests for delivery-001 classes: CommandHistory, DirtyTracker, TresParser, KeyboardManager.
 * Run: node tools/level-editor/test-unit.mjs
 */
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Extract JS from index.html and eval with mocks
const html = readFileSync(join(__dirname, 'index.html'), 'utf-8');
const scriptMatch = html.match(/<script>([\s\S]*?)<\/script>/);
const script = scriptMatch[1];

let keydownHandler = null;
const mockDocument = {
  querySelectorAll: () => [],
  getElementById: () => ({
    addEventListener: () => {},
    classList: { add: () => {}, remove: () => {} },
    textContent: '',
    value: '',
    click: () => {},
  }),
  activeElement: null,
  addEventListener: (event, handler) => { if (event === 'keydown') keydownHandler = handler; },
  createElement: () => ({ click: () => {}, href: '', download: '' }),
  body: { appendChild: () => {}, removeChild: () => {} },
};
const mockWindow = {
  addEventListener: () => {},
  showDirectoryPicker: undefined,
};

const fn = new Function('mockDocument', 'mockWindow', `
  const document = mockDocument;
  const window = mockWindow;
  const URL = { createObjectURL: () => '', revokeObjectURL: () => {} };
  ${script}
  return { TresParser, TresFile, CommandHistory, KeyboardManager, DirtyTracker, generateTresUid, ProjectContext };
`);
const { TresParser, TresFile, CommandHistory, KeyboardManager, DirtyTracker, generateTresUid, ProjectContext } = fn(mockDocument, mockWindow);

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
// Summary
// ============================================================

console.log(`\n${passed + failed} assertions: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
