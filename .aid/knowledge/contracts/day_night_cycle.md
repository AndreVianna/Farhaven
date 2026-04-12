# DayNightCycle
**Source:** `scripts/day_night/day_night_cycle.gd`
**Category:** genre-specific
**Layer:** autoload
**Depends on:** [`hex_grid.md`](hex_grid.md)

## What this system is

DayNightCycle is the in-game clock. It runs a four-phase loop (DAY → DUSK → NIGHT → DAWN →
DAY…) using real-time seconds, emits a signal every time the phase changes, and drives
three visual layers: the scene's WorldEnvironment ambient light, the DirectionalLight3D sun,
and the hex terrain shader's darkness parameter. It is the third autoload in `project.godot`,
after PropRegistry and HexGrid, so it can connect to `HexGrid.tile_entered` during its own
`_ready` to keep the shader's `player_world_pos` parameter up to date for per-tile lighting.

## Promises to content

- **Four phases, fixed durations.** `DAY = 105s`, `DUSK = 15s`, `NIGHT = 105s`, `DAWN = 15s`
  — a full day is 240 seconds at `TIME_SCALE = 1.0`. The phase enum
  `TimePhase { DAY, DUSK, NIGHT, DAWN }` is stable and safe to reference from other systems.
- **Phase transitions emit multiple signals.** Every transition emits `phase_changed(old,
  new)`. The specific phase signals (`day_started`, `dusk`, `night`, `dawn`) fire on top
  of that, in that order within the same transition call. Systems that care about a specific
  phase can listen to the specific signal; systems that care about all transitions listen to
  `phase_changed`.
- **`day_count` only increments on DAWN.** The day counter advances when the cycle moves from
  NIGHT to DAWN, not at midnight or at DAY. This is the canonical "what day is it" value
  used by SpawnableCap's first-day gate, SurvivalSystem's day-boundary logic, and save
  metadata.
- **`is_daytime` is a live flag.** True during DAY and DAWN, false during DUSK and NIGHT.
  Systems that want a simple day/night boolean (lighting active, fauna activity) read this
  field directly.
- **Lighting transitions are tweened.** On phase change the system starts a parallel tween
  over `min(phase_duration, 5s)` that interpolates ambient color, ambient energy, sun color,
  sun energy, and shader darkness from current to phase-target values. The tween runs on the
  real WorldEnvironment and DirectionalLight3D nodes registered via `register_lighting`.
- **Headless-safe.** If no lighting nodes are registered (tests, headless CI, early boot),
  lighting calls become no-ops. The phase timer and signals still fire.
- **`skip_to_dawn()` is the night-death respawn hook.** Jumps directly to DAWN, resets
  elapsed time to zero, increments `day_count`, emits `phase_changed` + `dawn`, and applies
  lighting immediately (no tween) so the player wakes up to a bright world.
- **Save/load restores the clock.** `get_save_data()` emits `day_count`, `phase`,
  `phase_elapsed`, and a `chapter_id` placeholder. `load_save_data(data)` clamps phase to
  a valid enum value, rounds `phase_elapsed` non-negative, and re-applies lighting
  immediately so the loaded phase is visible without waiting for a tween.

## Requirements from content

- **Scene must call `register_lighting(env, sun)` before any lighting tween should run.**
  Typically done in `main.gd` during scene setup. Before registration, phase transitions
  still fire and the clock still advances, but no visuals change.
- **Scene must call `register_hex_material(mat)` if the hex terrain uses a shader.** The
  registered material is updated both by phase tweens (darkness) and by player movement
  (`player_world_pos` via `tile_entered`). Without it, the hex shader stays at whatever
  darkness value it was initialised with.
- **Lighting targets come from `LIGHTING_PARAMS`.** Warm DAY (cream/peach), orange DUSK,
  deep indigo NIGHT, warm DAWN. Content wanting different palettes must either edit this
  constant directly or fork the autoload; there is no per-map override today.
- **HexGrid must exist when DayNightCycle's `_ready` runs.** It is — HexGrid is the autoload
  immediately before it in `project.godot`. Do not add a new autoload between them without
  auditing the `HexGrid.tile_entered` connection.
- **`TIME_SCALE` is a source-edited constant.** There is no runtime setter. Timelapse testing
  means editing the file (`const TIME_SCALE: float = 20.0`) and rebuilding.

## Extension points

- **Phase listeners.** Any system can connect to `phase_changed` or the per-phase signals.
  LightingManager uses `current_phase` to decide whether to return local lights.
  SurvivalSystem uses the DAWN signal for day-boundary bookkeeping. Fauna can hook `night`
  / `day_started` to switch activity.
- **Custom lighting.** External code can read `LIGHTING_PARAMS[phase]` at any time to
  construct its own tween on a different node (e.g. a second environment for a cave
  interior).
- **Skip-to-dawn hook.** Death handlers, cheat menus, and cutscenes that need to jump time
  call `skip_to_dawn()`; there is no corresponding `skip_to_night()` but adding one is
  trivial if needed.
- **Hex shader override.** Games that use a different terrain material can skip
  `register_hex_material` and compute darkness themselves by reading `current_phase` and
  `DARKNESS_VALUES`.

## Genre-specific notes

DayNightCycle is **partially genre-agnostic**. The shape — a phase enum, fixed durations, a
`phase_changed` signal, a day counter — transfers to any real-time game with a time-of-day
system. The clock logic itself could be reused unchanged.

The **genre-specific parts** are all downstream of that shape:

- **The four-phase enum with two long phases and two short transitions** is a survival-genre
  choice. A combat game might want just DAY/NIGHT; a slice-of-life game might want HOUR-based
  phases. Anyone reusing this system in another genre would edit `TimePhase` and
  `PHASE_DURATIONS` together.
- **The warm-to-cool lighting palette** is explicitly Farhaven's atmosphere. A horror game
  would invert the NIGHT color; a desert game would use cyan/white for DAY.
- **Hex shader darkness coupling** assumes a hex-grid terrain using the project's shader.
  A game with a different terrain system would not register a hex material and the
  `_set_hex_darkness` branch would simply never run.
- **Real-time tick via `_process`** assumes a real-time game loop. A turn-based game would
  need a TurnManager layer that advances phases on turn completion instead of elapsed
  seconds. This is flagged as future engine-v2 scope in delivery-006d task-088.

## Known limitations and TODOs

- **No pause mechanism.** The clock runs whenever the scene tree runs. Menus and inventory
  panels that freeze the world must either `get_tree().paused = true` (which stops
  `_process` on unpausable nodes) or set a manual pause flag. There is no `DayNightCycle.pause()`
  method.
- **Tween duration is capped at 5 seconds.** Useful so DAY → DUSK doesn't take 105 seconds
  to finish its tween, but it means fast-forwarded time (`TIME_SCALE > 1.0`) can outrun the
  tween. Visible only in timelapse testing.
- **No subphase hooks.** Listeners cannot ask "we are 30% through NIGHT" without reading
  `phase_elapsed` directly. Exposing a normalised `phase_progress` field is future scope.
- **`chapter_id` in save data is a placeholder.** Currently always `1`. A real chapter system
  would need a separate autoload or an extension here. See task-088.
- **`skip_to_dawn` always increments `day_count`.** Even if the player dies mid-day, the
  counter jumps. Intended for night-death respawns; other callers should be aware.
- **Multi-phase tweens cannot be cancelled cleanly.** If a phase advances while a tween from
  the previous phase is still running, the old tween is killed and a new one starts —
  intermediate frames may snap. Not visible at normal `TIME_SCALE` but obvious in tests.
