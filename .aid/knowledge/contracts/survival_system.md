# SurvivalSystem

**Source:** `scripts/survival/survival_system.gd`
**Category:** genre-specific
**Layer:** system
**Depends on:** [`prop_def.md`](prop_def.md) (for consumable fields, `tool_slot`, `is_respawn_point`), [`inventory.md`](inventory.md), [`day_night_cycle.md`](day_night_cycle.md), [`hex_grid.md`](hex_grid.md), [`save_manager.md`](save_manager.md) (persists via `get_save_data` / `load_save_data`). Not an autoload — child Node of Player.

## What this system is

SurvivalSystem is the **player stat clock**: hunger, thirst, HP, and the activity modulations
on top. It ticks three base stats every frame, applies penalties when a stat is starved,
regenerates HP during the day when not starving, and handles the full death-to-respawn
sequence including dropping items on the ground at the death tile. It is the only system in
Farhaven that represents "how the player is doing" as numbers.

It also owns ground items — when the player dies, inventory contents are dropped at the
death tile with sub-hex precision. Ground items are stored in a flat array (tile, sub-hex,
item type, count) and exposed for auto-pickup.

## Promises to content

- **Three base stats: HP, hunger, thirst.** Each has a current and max value. All three are
  clamped to `[0, max]` every tick. Signal `stat_changed(stat_name, current, max)` fires each
  tick.
- **Passive drain is constant.** Hunger drains at 0.4/sec, thirst at 0.8/sec. These are
  hardcoded in `STAT_CONFIG` and tuned for a ~250-second exhaustion curve.
- **Starvation drains HP.** If `hunger <= 0`, HP loses 0.1/sec. If `thirst <= 0`, HP loses
  0.2/sec. Both drains stack. This is how the player actually dies in the long run.
- **Daytime regen only fires when not starving.** If the day/night cycle reports daytime and
  both hunger and thirst are > 0, HP regenerates at 0.5/sec. Any starvation, or night phase,
  suspends regen.
- **Activities apply two kinds of cost.** One-shot "costs" via `apply_activity_cost(name)` —
  a single subtraction from the current stats. Continuous "drains" via `start_activity_drain` /
  `stop_activity_drain` — a tick-proportional drain that accumulates on top of passive drain
  while active. The v1 activities are `&"gathering"`, `&"crafting"`, `&"scanning"`,
  `&"building"`, `&"attacking"`, `&"moving"`; the exact cost/drain dicts live in
  `ACTIVITY_CONFIG`.
- **Death is idempotent.** `_check_death` only fires once per run; `is_dead = true` is
  checked before the death sequence fires. `respawn()` clears the flag.
- **Death drops everything except tools.** Every slot entry in the inventory is dropped to the
  ground items list. Items whose PropDef has a non-empty `tool_slot` are explicitly skipped —
  tools never drop. This means players who die mid-expedition keep their axe, pickaxe,
  weapon, and scanner.
- **Respawn tile is updated by structure placement.** Structures with `is_respawn_point`
  (legacy field) replace the respawn tile on `HexGrid.structure_placed`. If the current
  respawn structure is destroyed, the tile is cleared back to `(0, 0)`.
- **Night death waits for dawn.** If the player dies during night phase with no screen fade
  (tests/headless), the system calls `DayNightCycle.skip_to_dawn()` before respawning. With
  a screen fade, the fade-out completion waits while dawn is reached, then respawns.
- **`consume(type)` reads PropDef consumable fields.** Eating an item reads
  `hunger_restore`, `thirst_restore`, `health_restore` from the PropDef. Positive
  `health_restore` heals; negative deals damage (toxic flora). No hardcoded item table.
- **Save/load round-trips HP, hunger, thirst, respawn tile, and ground items.** `is_dead` is
  never saved — loading always revives. This is a deliberate simplification (no "resume into
  death screen" state).

## Requirements from content

- **Must be child of Player.** Walks `get_parent()` to find the player, reads
  `player.current_tile`, and calls `player._snap_to_tile` on respawn to teleport.
- **Player must expose `get_inventory()`.** Standard.
- **DayNightCycle and HexGrid must be registered as autoloads.** Fetched in `_ready` from
  `/root/DayNightCycle` and `/root/HexGrid`. Tests can inject via `_day_night_cycle` and
  `_hex_grid` before `_ready`.
- **PropRegistry must be available globally.** The system calls `PropRegistry.get_def` and
  `PropRegistry.has_def` at several points (consume, tool-slot skip, respawn-point check).
  If PropRegistry hasn't scanned yet, these lookups return null and the corresponding paths
  silently no-op.
- **Consumable PropDefs carry stat deltas.** For `consume(type)` to have any effect, the
  PropDef must have `is_consumable = true` and the three restore fields populated. These
  are legacy fields flagged for migration to recipes (see `prop_def.md` — the `is_consumable`
  path is a known transitional).
- **Activity name must match `ACTIVITY_CONFIG` key.** Passing an unknown name to
  `apply_activity_cost` is a silent no-op. Use exact StringNames: `&"gathering"`, etc.

## Extension points

- **New activities.** Add a new entry to `ACTIVITY_CONFIG` with a `cost` dict and a `drain`
  dict. Call `apply_activity_cost` and `start_activity_drain` / `stop_activity_drain` from
  the relevant system. No SurvivalSystem code changes needed beyond the dict entry.
- **Signals for HUD/audio.** `stat_changed`, `player_died`, `player_respawned`,
  `ground_item_dropped`, `ground_item_picked_up`. HUD subscribes to `stat_changed` via
  `StatusCombinedPanel` (see `status_combined_panel.md`).
- **Ground items API.** `add_ground_item`, `remove_ground_item`, `get_ground_items_at`,
  `get_all_ground_items`. AutoInteractionSystem uses these for proximity auto-pickup.
- **Respawn point via StationCap.** Future: move the legacy `is_respawn_point` boolean to
  a `StationCap` tag (`&"respawn"`), at which point the shelter check in FaunaManager and
  the respawn tile update here can share the same data path.
- **Screen fade is injectable.** `_screen_fade` is resolved from `/root/Main/ScreenFade` but
  tests can set it to `null` (the system falls through to the headless code path).

## Genre-specific notes

SurvivalSystem is **the most genre-explicit system in the engine** — its entire reason for
existing is Farhaven's survival genre.

- **Hunger / thirst / HP is canonical survival.** Minecraft, The Long Dark, Don't Starve,
  Green Hell all have this triangle (sometimes plus stamina or fatigue). A non-survival
  game would replace it with whatever its stat model is — HP only for an RPG, MP + HP for a
  wizard game, etc.
- **Daytime regen is a design choice.** The rule "you heal during the day if you're fed and
  hydrated" is a gameplay loop: it rewards playing the food/water meta before fighting.
  An action game would heal from medkits instead.
- **Activity costs are survival-specific.** The notion that gathering costs thirst and
  crafting costs hunger is an energy-metabolism model. A strategy game would not track
  these.
- **Death-drops-inventory is common but not universal.** Minecraft and Don't Starve do it.
  Some survival games keep inventory on death (The Long Dark is kinder); some do a partial
  drop. Content can tune the "tools are protected" rule by editing what fields count as a
  tool.
- **Night-death-waits-for-dawn is Farhaven-specific.** The idea that you can't respawn until
  the world is "safe" is tied to the night/fauna spawning mechanic. A game without that
  mechanic would respawn immediately.
- **The base numeric model is reusable.** If a second game wanted "three stats with passive
  drain, starvation damage, and daytime regen," the code would need only the `STAT_CONFIG`
  dict edited. The scaffolding itself is general.

## Known limitations and TODOs

- **STAT_CONFIG and ACTIVITY_CONFIG are hardcoded constants.** Designer iteration requires
  code edits. Moving these to a `SurvivalDef` data resource is deferred.
- **HP regen is binary.** It either fires or not; there's no partial regen based on how well
  fed you are. A future pass might scale regen rate by stat levels.
- **No temperature / weather / fatigue stats.** The v1 model is just HP/hunger/thirst. Adding
  temperature (cold damage, hypothermia) or fatigue (sleep mechanic) is deferred to a future
  chapter.
- **Consumable fields are legacy.** `is_consumable`, `hunger_restore`, `thirst_restore`,
  `health_restore` on PropDef are transitional fields. The long-term plan is to move
  consumption to recipes with `stat_delta` effects. SurvivalSystem will keep reading the
  legacy fields until that migration is complete.
- **`is_respawn_point` is a legacy field.** Same migration story — the respawn-point bool
  should move to a station tag. Flagged in `prop_def.md` as well.
- **Ground items persist forever.** There is no decay, no "spoilage," and no limit on how
  many items can accumulate on a single tile. A future pass could add decay timers per
  item type.
- **`_on_fauna_killed` is an empty stub.** Meat drops from killed fauna will be wired to
  this handler when the combat runtime lands. Flagged for task-088.
- **Death sequence assumes a single `ScreenFade` at a fixed path.** Makes it fragile to
  scene reorganisation. A future pass could make it a signal-driven coordinator.
