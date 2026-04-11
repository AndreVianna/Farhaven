# LightCap

**Source:** `scripts/data/capabilities/light_cap.gd`
**Category:** core
**Layer:** data
**Depends on:** [`prop_def.md`](prop_def.md), [`lighting_manager.md`](lighting_manager.md), [`day_night_cycle.md`](day_night_cycle.md)

## What this system is

LightCap marks a PropDef as "something that emits light in the world." Campfires, torches,
glow crystals, lanterns, and any other prop whose presence changes the lighting of nearby
tiles carry this cap. LightCap is pure data: it does not create the OmniLight node, does
not toggle it on or off, and does not drive the flicker animation. Those are all jobs for
LightingManager, which reads LightCap at placement time to spawn the appropriate Godot
light node, listens to DayNightCycle to decide when to turn lights on, and animates the
flicker if requested. LightCap is the declarative "this prop glows with X properties" slot.

## Promises to content

- **LightCap is opt-in via PropDef.** A PropDef without a `light` cap does not emit light.
  Attaching a LightCap via PropDef's `light` slot is how a campfire or torch declares
  itself as a light source.
- **`radius` is the illumination reach in world units (scaled internally).** LightingManager
  multiplies the value by an internal `RING_TO_WORLD` constant to produce a Godot OmniLight
  range. A radius of 0.0 falls back to a default value inside LightingManager — the field
  does not produce darkness, it only over-rides the default reach. Content that wants a
  dim light sets a small positive value; content that wants the default sets 0.0.
- **`color` is the emission tint.** Defaults to a warm orange (`Color(1.0, 0.7, 0.3, 1.0)`)
  appropriate for firelight. LightingManager falls back to a default colour if the field
  is left at Godot's zero-color default (all components 0), so authors can opt out of the
  colour without touching the field.
- **`flicker` requests animated intensity variation.** When true, LightingManager drives a
  small random brightness wobble on the spawned light node to simulate fire or torch
  flicker. When false, the light is steady. The exact flicker algorithm (period, amplitude)
  is LightingManager's business.
- **Light presence is phase-gated by DayNightCycle.** LightingManager subscribes to the
  day/night cycle and turns lights on during dusk/night and off during day. LightCap
  itself has no schedule field — every light is treated the same way. A light that
  should burn day and night would need either a different schedule hook or a field added
  here.
- **LightCap is shared across instances.** Every torch prop shares one LightCap. The
  spawned OmniLight node exists per-instance in the scene.

## Requirements from content

- **Sub-resource shape, not dictionary.** LightCap must be authored as an inline
  `[sub_resource type="Resource"]` block with `script = ExtResource("light_cap")`.
- **`radius` is a `float`.** Use 0.0 for "default reach" or any positive value for a
  specific range. Negative values are meaningless and likely to produce rendering
  artifacts.
- **`color` is a `Color`.** Leave at the default warm orange for firelight; set explicitly
  for anything that isn't fire-coloured (blue glow crystal, green alchemy lamp).
- **`flicker` is a `bool`.** Steady lights set false; fire-like lights set true.
- **Composition with PlaceableCap is expected.** Almost every light is also placeable —
  the player puts a torch or a campfire somewhere and the lighting follows. LightCap
  alone on a non-placeable prop still works for things that are part of the map at load
  time (e.g. an always-there wall sconce), but the typical pattern is `placeable + light`.
- **Composition with StationCap for multi-purpose props.** A fireplace is typically
  `station + container + light`: a station the player interacts with, a container that
  holds fuel, and a light that glows while fuel is present. The three caps are
  independent; LightCap does not know about the station or the fuel.

## Extension points

- **Schedule-sensitive lights.** Adding a field like `burn_phase: StringName = &"night"`
  would let LightingManager restrict the light to a specific day/night phase. Not on the
  current cap; add if a second content pack needs it.
- **Attenuation curves.** The current field set assumes a default Godot OmniLight
  attenuation. A `falloff_curve: Curve = null` or `attenuation_mode: int` field would let
  authors shape how brightness drops off with distance. Out of scope for delivery-006d.
- **Fuel-driven lighting.** A fireplace that burns fuel and goes dark when the fuel runs
  out is already supported at the system level: the station's `ContainerCap` holds the
  fuel, a recipe consumes it, and LightingManager watches the container state to toggle
  the OmniLight. LightCap itself stays stupid — the burning behavior lives on top of it.
- **Coloured flicker.** Currently the cap has a single colour and a single flicker
  boolean. A flicker-colour variation (e.g. campfires shifting between warm orange and
  yellow) would need either two colour fields or a curve.
- **Adding new fields.** Any new `@export` field on LightCap will round-trip through
  Godot's serialisation and existing `.tres` files will remain valid (new exports
  default to sensible values). LightingManager is the only consumer to update.

## Genre-specific notes

LightCap is **fully genre-agnostic.** "This prop glows with radius X, colour Y, flickers
or not" describes a feature any 2D or 3D game with world lighting might want. A Civ-like
second game could reuse LightCap unchanged for city lights, wonder auras, or tile
highlights. A Catan-like game could use it for highlighting player-owned settlements.

The **genre-adjacent assumption** is that LightingManager runs on a day/night cycle and
toggles lights accordingly. A game with no day/night cycle (a pure indoor game, a
tactical grid game) would either leave the phase gate unused and have LightingManager
treat every light as "always on," or replace LightingManager with a system that ignores
the phase state. LightCap itself does not know about DayNightCycle — the coupling lives
entirely on the manager side.

The **colour default (warm orange firelight)** is a Farhaven survival aesthetic choice
that is trivial to override per-cap. The default does not constrain reuse.

The **radius-in-world-units convention** assumes a 3D world where a linear radius makes
sense. A tile-only 2D game would reinterpret `radius` as "tile rings" at the
LightingManager level; the field itself is a plain float.

## Known limitations and TODOs

- **`radius = 0.0` means "default," not "no light."** This is a usability trap. An author
  who explicitly wants zero-reach (why?) cannot express it directly. The default should
  probably be a sentinel like `-1.0` or a named "use default" flag, but the current
  convention is entrenched in LightingManager. Not urgent.
- **`color = Color()` also means "default."** Same pattern, same usability trap.
  LightingManager checks `def.light.color != Color()` and falls back to `DEFAULT_LIGHT_COLOR`
  if the field is at the zero value. Authors who intentionally want fully transparent
  black cannot express it, but in practice no one wants that.
- **No schedule field.** Every LightCap is phase-gated by DayNightCycle in the same way.
  A torch held indoors at noon will not emit light because LightingManager is not told
  otherwise.
- **Flicker is binary.** There is no "flicker intensity" or "flicker rate" slider. A
  roaring bonfire flickers the same as a dying candle.
- **No shadow / shadow-cast configuration.** Whether the light casts shadows is
  LightingManager's call, uniform across all LightCap instances. Content cannot
  per-prop opt in or out.
- **No spot / directional variants.** LightCap describes a point/omni light. A
  directional torch or a floodlight would need either a `type` enum or a different
  cap entirely.
- **`radius = 0.0` fallback is 3.0.** The constant `3.0 * RING_TO_WORLD` is hardcoded in
  LightingManager and represents the "default reach" for every LightCap that does not
  specify a radius. Authoring tools should probably surface this as a UI hint.
