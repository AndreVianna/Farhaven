# SaveManager
**Source:** `scripts/save/save_manager.gd`
**Category:** core
**Layer:** autoload
**Depends on:** [`hex_grid.md`](hex_grid.md), [`day_night_cycle.md`](day_night_cycle.md), [`inventory.md`](inventory.md), [`survival_system.md`](survival_system.md), [`scanner_system.md`](scanner_system.md)

## What this system is

SaveManager is the game's sole persistence layer. It owns the on-disk save file at
`user://save.json`, runs a dirty-flag timer that writes every five seconds when state has
changed, writes immediately on critical lifecycle events (app going to background, app
closing), and distributes loaded save data back to the same nodes that produced it. It
works via a hardcoded registry of system keys paired with absolute node paths: for each
entry, it fetches the node, calls `get_save_data()` during collection, and calls
`load_save_data(data)` during distribution. Autoloads are located at `/root/<Name>`;
gameplay systems living under `Player` are located via their full scene path. The manager
is the twelfth and last autoload in `project.godot`, so every other autoload is guaranteed
ready before it runs.

## Promises to content

- **Mark-dirty is the debounce primitive.** Gameplay code calls `mark_dirty()` whenever
  something worth saving changes (inventory shift, stat change, prop placement, tile
  modification). The manager then writes on the next timer tick (or immediately on
  critical events). Never saving directly is the normal path.
- **`save_now()` is the synchronous "write right now" entry point.** It calls `save_game()`
  and clears the dirty flag on success. Use it sparingly — the normal flow is
  `mark_dirty()` + let the timer handle it.
- **`save_game()` is the low-level write.** Collects data from every registered system,
  JSON-stringifies it with tab indentation (so saves are human-readable), writes to
  `user://save.json`, and returns false on I/O error. Does not touch the dirty flag on
  its own.
- **`load_game()` reloads the file and distributes.** Parses JSON, checks it's a
  Dictionary, deletes the file if corrupt, otherwise iterates `_SYSTEM_KEYS` and hands
  each registered node its slice of the loaded dictionary.
- **`has_save()` is a cheap existence check** and `delete_save()` removes the file
  unconditionally. Used by "New Game" menus.
- **Mobile lifecycle is handled automatically.** On `NOTIFICATION_APPLICATION_FOCUS_OUT`
  (app backgrounded), the manager saves immediately and pauses the scene tree. On
  `FOCUS_IN`, it unpauses. On `WM_CLOSE_REQUEST`, it saves again before the app exits.
  The app surviving a Task-Kill between FOCUS_OUT and next launch is the load path.
- **Corrupt saves delete themselves.** A JSON parse failure or a non-Dictionary root
  triggers `_delete_save` and returns false from `load_game`. The next session starts
  fresh instead of limping with garbage state.
- **Missing systems are skipped gracefully.** If a registered node path returns null
  (system disabled, scene not yet built, test environment), collection and distribution
  skip it silently. The save dict simply lacks that key; loading fills in what it can.
- **Missing `get_save_data`/`load_save_data` methods are also skipped.** The manager
  checks `has_method` before calling, so adding a node to the registry that doesn't
  support save is benign during development.

## Requirements from content

- **Save-capable nodes must implement `get_save_data() -> Dictionary` and
  `load_save_data(data: Dictionary) -> void`.** These are the two methods the manager
  calls. Implementation quality is the system's responsibility: validation, version
  handling, default fill-in.
- **Nodes must live at stable paths.** The manager uses hardcoded paths like
  `/root/HexGrid`, `/root/Main/World/Player`, `/root/Main/World/Camera3D`,
  `/root/Main/World/Player/CraftingSystem`. Renaming these scenes or reparenting their
  nodes breaks collection and distribution. Changes must include a `_SYSTEM_KEYS` update.
- **Each system's key must be unique.** Duplicate keys in the registry would silently
  overwrite during collection. Enforced by review, not runtime assertions.
- **Player-owned systems (Inventory, Catalog) are saved through their parent.** Inventory
  is a RefCounted owned by the Player scene, so the Player's `get_save_data` is
  responsible for serialising it inline. Catalog is the same story through
  ScannerSystem. The manager does not walk into non-Node children.
- **Save data must be JSON-serialisable.** Strings, numbers, booleans, nulls, arrays,
  dictionaries only. Vector2/StringName/enum values must be converted to strings or
  ints before return; re-hydrated on load. Custom Godot types cannot round-trip through
  `JSON.stringify`.
- **Load order is the same as save order.** Systems whose `load_save_data` depends on
  another system's already-being-loaded state must either appear later in `_SYSTEM_KEYS`
  or handle the out-of-order case internally. Currently the manager does not enforce
  dependency ordering beyond the registry's static order.

## Extension points

- **Register a new system.** Add an entry `{"key": "name", "path": "/root/path/to/node"}`
  to `_SYSTEM_KEYS`. Ensure the node implements the save API. No other code change
  required.
- **Critical save trigger.** Any code path that wants to save immediately (e.g. a
  "trophy earned" moment that must persist even if the app is killed a frame later) calls
  `SaveManager.save_now()` directly.
- **Save-interval tuning.** `SAVE_INTERVAL = 5.0` is a source constant. Games that want
  to save less often (or more often, or not at all) edit it here.
- **Custom save path.** `SAVE_PATH = "user://save.json"` is a source constant. Multiple
  save slots would need either a parameterised method or a different manager altogether;
  task-088 scope.
- **Bypassing the manager.** Nothing prevents a system from writing its own file for
  debug purposes, but the canonical save lives entirely in this autoload. Parallel save
  files are a foot-gun.

## Genre-specific notes

SaveManager is **fully engine-general**. "Collect JSON data from a registered list of
nodes, debounce writes, handle lifecycle events, parse on load and distribute"
transfers to any game. The hardcoded registry is the only thing that would need editing
for a second game — and that list is expected to change per-project anyway.

The **mobile-first lifecycle handling** is a Farhaven choice driven by the target
platform (Android). A desktop-only game would keep the `WM_CLOSE_REQUEST` handler but
could drop the `FOCUS_OUT/FOCUS_IN` pair. A multiplayer game would likely replace this
entire system with server-side persistence.

The **5-second debounce interval** is a mobile-friendly "don't thrash the SD card"
choice. Desktop games could set it lower; server-authoritative games could set it
much higher.

The **distinction between hot-resume (pause/unpause via FOCUS notifications) and
cold-resume (save/load on launch)** is a real piece of engine design that any
mobile-shipped game will hit. The manager handles both in the minimal way: hot-resume
just pauses the tree, cold-resume is "load_game() on startup if `has_save()`."

## Known limitations and TODOs

- **Single save slot.** No multi-slot support, no named saves, no autosave-vs-manual
  split. Task-088 scope.
- **No save versioning.** The JSON has no schema version field; migrations would be
  brittle without one. New fields can be added because systems tolerate missing keys,
  but renames and removals are hard. Task-088 scope.
- **Hardcoded node paths.** Moving a scene (e.g. renaming `Main/World` to `Main/Scene`)
  silently breaks save. A fix would register by group or by export, not by path.
- **No load-order graph.** If loading HexGrid after Player broke some invariant, the
  manager wouldn't know — it just iterates in registry order.
- **No compression.** JSON is human-readable but verbose. Large hex grids produce large
  saves (kilobytes to megabytes). Compression is a future optimization.
- **No atomic write.** If the app is killed mid-write, the save file ends up truncated.
  A write-temp-then-rename dance would fix this; deferred.
- **No per-system save size caps or progress reporting.** Large saves block the main
  thread during JSON.stringify. A background-thread save is task-088 scope.
- **FaunaManager creatures are not saved.** FaunaManager has no entry in `_SYSTEM_KEYS`
  today, so spawned creatures are re-generated on load rather than restored. Static
  tile props round-trip through HexGrid; dynamic fauna doesn't. Intentional scoping for
  delivery-006d; see [`fauna_manager.md`](fauna_manager.md).
- **No save-in-progress flag.** Calling `save_now` while the timer is already mid-write
  could collide. In practice nothing calls `save_now` at 200+ Hz, so it hasn't been
  observed, but the guarantee is missing.
