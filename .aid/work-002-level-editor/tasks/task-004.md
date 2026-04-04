# task-004: Command Infrastructure -- CommandHistory and KeyboardManager

**Type:** IMPLEMENT

**Source:** feature-008-command-infrastructure -> delivery-001

**Depends on:** task-001

**Scope:**
- Implement `CommandHistory` class: `undoStack`, `redoStack`, `maxSize` (50), `onChange` callback
  - `execute(command)`: call `command.execute()`, push to undo stack, clear redo stack, enforce maxSize via `shift()`, fire `onChange('execute', command)`
  - `undo()`: pop from undo, call `command.undo()`, push to redo, fire `onChange('undo', command)`. No-op if empty.
  - `redo()`: pop from redo, call `command.execute()`, push to undo, fire `onChange('redo', command)`. No-op if empty.
  - `canUndo()`, `canRedo()`, `clear()`
- Implement `KeyboardManager` class: `shortcuts` Map, `enabled` flag
  - `register(combo, handler)`, `unregister(combo)`
  - `_normalizeEvent(event)`: modifier order ctrl+shift+alt+key, lowercase
  - `_handleKeydown(event)`: skip dispatch when `<input>`, `<textarea>`, or `[contenteditable]` is focused (for single-key shortcuts only; modifier shortcuts like Ctrl+Z remain active)
- Register global shortcuts: Ctrl+Z -> undo, Ctrl+Shift+Z -> redo, Ctrl+S -> saveAll
- Register map-only tool shortcuts with `mapOnly()` guard: B, E, R, S, A, P, X, D, F, Escape
  - Tool shortcuts call a stub `selectTool()` function (actual ToolManager comes in delivery-002)
- Instantiate singletons: `const commandHistory = new CommandHistory()`, `const keyboardManager = new KeyboardManager()`
- Wire `document.addEventListener('keydown', ...)` in KeyboardManager

**Acceptance Criteria:**
- [ ] `commandHistory.execute(cmd)` calls `cmd.execute()`, pushes to undo stack, clears redo stack
- [ ] `commandHistory.undo()` reverses the most recent command; `redo()` re-applies it
- [ ] Stack overflow: 51st command drops the oldest from undo stack
- [ ] `onChange` callback fires with correct `(action, command)` for execute/undo/redo
- [ ] Keyboard shortcuts Ctrl+Z, Ctrl+Shift+Z, Ctrl+S are registered and functional
- [ ] Single-key shortcuts (B, E, R, etc.) are suppressed when a text input is focused
- [ ] Map-only shortcuts return early when `activeTab !== 'map'`
- [ ] `commandHistory.clear()` empties both stacks
- [ ] All code in `tools/level-editor/index.html` (single file constraint)
