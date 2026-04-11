# PropDef

**Source:** `scripts/data/prop_def.gd`
**Category:** core
**Layer:** data
**Depends on:** [`gear.md`](gear.md), [`prop_registry.md`](prop_registry.md), and every capability contract it composes ([`portable_cap.md`](portable_cap.md), [`placeable_cap.md`](placeable_cap.md), [`container_cap.md`](container_cap.md), [`light_cap.md`](light_cap.md), [`movable_cap.md`](movable_cap.md), [`station_cap.md`](station_cap.md), [`catalogable_cap.md`](catalogable_cap.md), [`endurance_cap.md`](endurance_cap.md), [`movement_cap.md`](movement_cap.md), [`combat_cap.md`](combat_cap.md), [`behavior_cap.md`](behavior_cap.md), [`spawnable_cap.md`](spawnable_cap.md))

## What this system is

PropDef is the central data class of Farhaven's engine. Every item the player can hold, every
tree and rock in the world, every enemy creature, every crafting station, and every placeable
building piece is described by a single PropDef `.tres` resource. PropDef is a thin composition
root: it inherits identity fields from `Gear` (id, display_name, descriptions) and then attaches
zero or more **capabilities** — small optional sub-resources that each grant the prop a specific
behavior. A rock has no capabilities beyond its visual shell. A live animal has six (catalogable,
endurance, movement, combat, behavior, spawnable). The engine's "everything is a prop" story runs
through this class.

## Promises to content

- **Identity is inherited from Gear.** Every PropDef carries an `id`, `display_name`,
  `short_description`, and `long_description` by virtue of extending Gear. Content authors get
  these fields for free and do not need to declare them.
- **Capabilities are opt-in and independently readable.** Each capability slot (`portable`,
  `placeable`, `container`, `light`, `movable`, `station`, `catalogable`, `endurance`, `movement`,
  `combat`, `behavior`, `spawnable`) defaults to `null`. Systems that care about a capability
  check for `null` before reading it; they never assume presence. Content can add a capability
  to a prop without touching any other capability or breaking any system that ignores it.
- **`has_capability(name)` is the canonical presence check.** Callers can ask
  `prop_def.has_capability(&"container")` instead of reaching into the field directly. New
  capabilities added to the `match` block become discoverable to any caller using this API.
- **`has_tag(tag)` provides free-form classification.** Tags (e.g. `&"BURNABLE"`, `&"WOOD"`,
  `&"FAUNA"`, `&"HOSTILE"`, `&"CONSUMABLE.edible"`) are independent of the type system and let
  recipes, effects, and AI filter props without needing a capability. Tags are matched exactly —
  no wildcarding, no hierarchy.
- **A PropDef with no capabilities is still valid.** It represents a pure decorative or
  placeholder prop. Loading will not fail; the registry will still index it.
- **Visual fields have graceful fallback.** If `mesh` is unset, the rendering layer falls back
  to a `placeholder_mesh_type` (cube, cylinder, sphere, octahedron, prism, box) parameterised by
  `placeholder_params` and tinted by `placeholder_color`. A PropDef can ship with only the
  placeholder block and still render correctly.

## Requirements from content

- **File location.** Every PropDef must live as a `.tres` file under `res://data/props/`.
  Nothing else in that directory: the registry scans flat (no sub-folders) and loads every
  `.tres` it finds.
- **ID convention.** The `id` field must be a `StringName` starting with the letter `P` (for
  example `&"P00108"`). This is asserted at load time by PropRegistry; a non-P id will crash the
  scan. By convention the digits after the prefix are zero-padded and monotonically assigned.
- **Script reference.** The `.tres` file must bind its top-level `script` to
  `res://scripts/data/prop_def.gd`. Tooling that generates PropDefs must emit this ExtResource
  entry; capabilities are sub-resources whose scripts point at the relevant capability files
  under `scripts/data/capabilities/`.
- **Capabilities are sub-resources, not inline dictionaries.** A container, for instance, is
  declared as `[sub_resource type="Resource" id="container_1"]` with
  `script = ExtResource("container_cap")` and typed fields. Dictionary-shaped capability data
  will not load.
- **Tags are `StringName`, not `String`.** The `tags` array is typed `Array[StringName]`. Using
  plain strings will either fail the typed assignment or silently miss tag lookups.
- **Tool props use the `tool_slot` field, not a capability.** A prop that can be equipped as a
  tool (axe, pickaxe, scanner) must set `tool_slot` to the slot name; tool handling is keyed off
  this field, not off the presence of a capability. This is explicitly a design call from the
  Open Question §11.6 discussion and is subject to redesign (see known limitations below).
- **Setup order during game start.** PropRegistry is the first autoload in `project.godot`,
  ahead of HexGrid and every other system. Content that runs later can call `PropRegistry.get_def(id)`
  unconditionally; any code that needs PropRegistry before its `_ready` runs (another autoload
  running earlier, or a tool script running in the editor) will get an empty registry.
- **Deprecated fields should not be used for new content.** The following fields exist only for
  backward compatibility with pre-task-053 props and will be removed: `footprint` (use
  `placeable.footprint`), `gather_time`/`gather_amount`/`tool_required`/`respawn_time`/
  `yield_type`/`tool_speed` (use the Recipe system), `is_consumable`/`hunger_restore`/
  `thirst_restore`/`health_restore` (use Recipes with `stat_delta` effects), `category`,
  `prop_category`, `emits_light`/`light_radius` (use `light` cap), `is_respawn_point`
  (use `station` cap with a `respawn` tag), `is_crafting_station` (use `station` cap with a
  `craft` tag), and `max_stack` (will be replaced by `portable.weight` in task-049). New PropDefs
  should leave these at defaults.

## Extension points

- **Adding a new capability.** Create a new `*_cap.gd` under `scripts/data/capabilities/`
  extending `Resource`, add a matching `@export` field to `prop_def.gd`, add a branch to the
  `has_capability` match, and add a cross-referencing contract file alongside this one. No other
  system needs to be touched until a consumer of the new capability is written. Existing PropDef
  `.tres` files remain valid because the new field defaults to `null`.
- **Adding a new tag.** Tags are string literals with no central enum. Any system that cares
  about a tag reads it through `has_tag` or `tags.has(...)`. Content can invent new tags freely;
  all the engine requires is that producers and consumers agree on the spelling.
- **Hooking into load.** PropDefs are loaded once at startup by PropRegistry. Code that needs to
  react to "all props are now known" should read from the registry after its own `_ready` has
  run, or connect to a post-load signal on the registry (see `prop_registry.md` for the contract
  on when scanning is complete).
- **Overriding visuals.** Setting `mesh`/`depleted_mesh`/`material` on a PropDef tells the
  rendering system to use real assets instead of placeholders. There is no need to disable the
  placeholder fields; the renderer checks the real-asset fields first.

## Genre-specific notes

PropDef is **partially genre-agnostic**. The composition-of-capabilities pattern transfers
cleanly to any game that wants data-driven entities: the class itself and the opt-in capability
list are a general engine feature, not a Farhaven detail. A Civ-like or Catan-like second game
could reuse the PropDef type unchanged to describe units, buildings, or resource tiles.

The **capabilities themselves vary in genre-specificity**, and this is where the reuse story
gets more nuanced:

- **Generic across genres.** `PortableCap`, `ContainerCap`, `PlaceableCap`, `CatalogableCap`,
  `StationCap`, `LightCap`, and `SpawnableCap` describe properties that most 2D/3D games with
  items and world placement will want. They make no assumption about the map topology or the
  time model.
- **Farhaven-specific — hex grid.** `MovementCap.modes` encodes speeds in **sub-hex per second**
  (see `movement_cap.gd`). "Sub-hex" is a Farhaven-specific spatial unit tied to the HexGrid
  autoload's sub-hex subdivision; the `JUMP` mode's elevation delta of 1 also refers to hex
  elevation levels. A game on a square grid or a continuous plane would need to reinterpret
  or replace this cap.
- **Farhaven-specific — real-time.** `MovementCap.move_cooldown` is derived as seconds-per-sub-hex,
  which assumes a real-time update loop. A turn-based game would need a different timing model
  or a TurnManager layer on top (flagged as future engine-v2 scope in delivery-006d task-088).
- **Farhaven-specific — survival genre.** `EnduranceCap` names its damage-type lists
  `vulnerabilities`, `resistances`, `immunities`, with `FIRE`-style StringName tags as values.
  This shape is fine for survival/RPG; strategy games that track damage by attacker type rather
  than element would want a different schema. `CombatCap.attacks`/`defenses` currently hold
  `Array[GameEvent]` placeholders and have no runtime yet (delivery-006d task-088) — the combat
  story is the most likely piece to need rework for a second game.
- **Genre-adjacent — fauna AI.** `BehaviorCap` is an AI policy block for **creatures**, not a
  general strategic-AI container. It describes detection range, activity cycle, group behavior,
  diet, and event-based reactions — reasonable for Farhaven's ecosystem simulation, but a
  strategic opponent in a Civ-like game would need its own AI scaffold.

The pragmatic answer for engine v2 reuse is: keep PropDef, keep the capability composition
pattern, treat the current capability set as "the Farhaven survival-genre capability pack," and
expect to ship additional or replacement packs for other genres.

## Known limitations and TODOs

- **Tag system is flat.** No hierarchy, no namespaces, no wildcard matching. Naming conventions
  like `CONSUMABLE.edible` hint at hierarchy but are just strings — `has_tag(&"CONSUMABLE")`
  will not match `CONSUMABLE.edible`. Future work may introduce a tag tree; for now, callers
  that want hierarchy must check every leaf explicitly.
- **`tool_slot` redesign pending.** The current slot-by-type constraint (one axe slot, one
  pickaxe slot, etc.) is explicitly flagged for redesign in delivery-006d task-088. The field
  stays on PropDef for now; a future refactor may move it into a dedicated `ToolCap` or replace
  slot-name strings with a different mechanism.
- **`max_stack` is transitional.** `PortableCap.size` (slot-unit capacity) was introduced in
  delivery-006b and is already the primary inventory constraint, but `max_stack` still lives on
  PropDef and is still read by `Inventory.gd` for slot-fill limits alongside `size`. The
  long-term direction is slot-unit only; the transition is not yet complete. Content should
  lean on `portable.size` as the load-bearing field and treat `max_stack` as legacy.
- **Large legacy field surface.** Roughly half the fields on PropDef are deprecated remnants
  from pre-capabilities Farhaven. They remain on the class because old `.tres` files still set
  them and because AutoInteractionSystem's legacy gather fallback still reads some of them.
  These will be pruned during a future cleanup pass; new content must not set them.
- **`combat` cap has no runtime.** `CombatCap.attacks`/`defenses` are `Array[GameEvent]`
  placeholders until the combat runtime lands (delivery-006d task-088). Damage resolution must
  respect `EnduranceCap.vulnerabilities`/`resistances`/`immunities` when that work is done.
- **PropRegistry scans flat.** No sub-folder organisation under `data/props/`. Once the prop
  library grows past a few hundred, this will likely need to change (future engine-v2 scope).
- **No hot-reload.** PropRegistry scans once on `_ready`. Editing a `.tres` file at runtime has
  no effect until the game is restarted. Editor tooling that wants live updates must call a
  rescan hook (not currently exposed).
