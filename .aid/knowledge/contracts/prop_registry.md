# PropRegistry
**Source:** `scripts/data/prop_registry.gd`
**Category:** core
**Layer:** autoload
**Depends on:** [`prop_def.md`](prop_def.md)

## What this system is

PropRegistry is the in-memory index of every PropDef resource in the project. On game start it
scans `res://data/props/`, loads every `.tres` file, validates the id prefix, and stores the
resource in a dictionary keyed by PropDef id. From that point on, any system that needs to
know "what does prop `P00108` do" asks PropRegistry and gets back the single canonical
resource. It is the first autoload in `project.godot` — deliberately, so that every later
autoload (HexGrid, LightingManager, RecipeRegistry, etc.) can call `get_def(id)` during its
own `_ready` without ordering surprises.

## Promises to content

- **Every PropDef under `res://data/props/` is loaded.** If a `.tres` file lives in that
  directory and its top-level script resolves to `prop_def.gd`, it will be indexed. There is
  no allow-list, no manual registration, and no build-time code generation step.
- **Lookups are constant-time.** `get_def(id)`, `has_def(id)`, and the `get_all()` snapshot
  do not scan disk or re-validate anything — they read a pre-populated dictionary.
- **`get_def` returns null for unknown ids without crashing.** Callers that want a loud
  failure should assert on their own; the registry itself is tolerant.
- **`get_all()` returns every loaded PropDef.** Useful for catalog panels, debug tools, and
  spawn loops that need to enumerate everything.
- **Loaded by the time any other autoload runs its `_ready`.** Because PropRegistry is the
  first autoload in `project.godot`, any code that runs later — HexGrid, LightingManager,
  RecipeRegistry, DiscoveryWatcher, RecipeRuntime — can safely call `get_def` during its own
  startup. There is no initialisation ordering hazard for the other autoloads.
- **Legacy helpers exist for gather/yield.** `get_yield_type(type)` returns `yield_type` if
  set on the PropDef, otherwise the prop's own id. `get_tool_speed(type, tool_name)` returns
  the PropDef's `tool_speed` entry or `1.0`. These are deprecated helpers that exist only to
  keep pre-recipe gather code working; see *Known limitations*.

## Requirements from content

- **`.tres` files must live directly under `res://data/props/`.** The scan is flat — no
  sub-folder traversal. A PropDef inside `res://data/props/creatures/wolf.tres` will not be
  loaded until flat-layout or a recursive scan lands.
- **The top-level `script` of every `.tres` must resolve to `res://scripts/data/prop_def.gd`.**
  Files whose script is a different class are silently skipped (the `is _PropDef` check filters
  them out without error).
- **Every PropDef id must be a StringName starting with `P`.** This is asserted at load time;
  a non-P id will abort the scan with a failed assertion. See [`prop_def.md`](prop_def.md) for
  the broader id convention.
- **Ids must be unique.** The loader stores into `_defs[res.id]`, so duplicate ids will
  silently overwrite each other in whatever order `DirAccess` returns the files. Content must
  guarantee uniqueness at authoring time.
- **Content must not rely on `_ready` completing before PropRegistry's own `_ready`.** Other
  autoloads are safe because of the `project.godot` ordering, but tool scripts, EditorPlugins,
  and `@tool`-annotated scenes may run before the registry has scanned. Those callers should
  check `has_def` or handle a null result.

## Extension points

- **Add a new PropDef.** Drop a `.tres` file in `res://data/props/`, bind its script to
  `prop_def.gd`, give it a `P`-prefixed id. No code change required. The registry picks it up
  on next game start.
- **Read every prop.** Panels and dev tools iterate `PropRegistry.get_all()` instead of
  rescanning the filesystem. See catalog / debug panels for examples.
- **Inject a mock registry.** Several downstream autoloads
  ([`lighting_manager.md`](lighting_manager.md), [`discovery_watcher.md`](discovery_watcher.md),
  [`recipe_runtime.md`](recipe_runtime.md)) accept a `_registry` field that defaults to the
  autoload but can be overridden in tests with a stub that only knows about a handful of props.
- **Post-load hook.** There is currently no `props_loaded` signal. Code that needs to react
  when scanning completes should run its work from its own `_ready` (which will execute after
  PropRegistry's, given the project.godot ordering).

## Genre-specific notes

PropRegistry itself is **fully engine-general**. A flat dictionary of typed resources keyed
by prefixed ids is useful for any data-driven game — items in an RPG, units in a strategy
game, tiles in a puzzle game. The P-prefix convention is Farhaven-chosen but the registry
is parameterised by a class constant; a second game could fork it to scan a different
directory with a different prefix without touching the dictionary API.

The **legacy helpers** `get_yield_type` and `get_tool_speed` are genre-specific: they read
Farhaven's deprecated gather fields (`yield_type`, `tool_speed`) on PropDef. A second game
built on this engine would either delete them or re-route them to recipe lookups via
[`recipe_registry.md`](recipe_registry.md).

## Known limitations and TODOs

- **No hot-reload.** The scan happens once in `_ready`. Editing a `.tres` file while the game
  is running has no effect; the change is picked up only on restart. A `rescan()` hook is a
  plausible future addition for editor tooling.
- **Flat scan only.** No recursion into sub-folders. As the prop library grows past a few
  hundred entries, sub-folder organisation will matter. See delivery-006d task-088 for the
  deferred engine cleanup backlog.
- **No ordering guarantees across `.tres` files.** The registry loads in whatever order
  `DirAccess.get_next()` returns. Duplicate ids silently overwrite. Content authoring must
  enforce uniqueness; the registry does not detect collisions.
- **No `props_loaded` signal.** Systems that want to react "when all props are known" currently
  rely on the autoload ordering. A signal would make the dependency explicit and allow lazy
  consumers to subscribe without depending on `_ready` ordering. Deferred to engine v2.
- **Legacy gather API is deprecated.** `get_yield_type` and `get_tool_speed` are scheduled for
  removal once all gather logic moves into the recipe system (see task-088 for the deprecation
  backlog and [`recipe_registry.md`](recipe_registry.md) for the replacement path).
