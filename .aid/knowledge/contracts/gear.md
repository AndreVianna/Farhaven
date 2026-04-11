# Gear

**Source:** `scripts/core/gear.gd`
**Category:** core
**Layer:** data
**Depends on:** none (root of the data-class hierarchy)

## What this system is

Gear is the root base class for every data resource in Farhaven. It exists to give every
engine-visible "thing" — props, cutscenes, journal entries, recipes, game events — the same
minimal identity surface so that registries, UI panels, and save/load code can treat them
uniformly. Gear has no behavior of its own and holds no game-state; it is purely a shape. If
a resource needs to be addressable by an id and rendered with a human-readable label, it
extends Gear. If it does not (for example, a small inline sub-resource attached to another
class), it extends `Resource` directly.

## Promises to content

- **Every Gear-derived resource is addressable by a single `StringName` id.** The `id` field
  is the canonical handle. Registries use it as a dictionary key; events, journal effects, and
  save files store it verbatim. Ids are `StringName`, not `String`, so comparisons are O(1).
- **Every Gear-derived resource carries a human-readable `display_name`.** UI panels, tooltips,
  and catalog buckets read this field without branching on the subclass. Content can leave it
  empty during authoring, but any surface that shows the resource to the player will show a
  blank where the name should be.
- **Every Gear-derived resource has a two-tier description surface.** `short_description` is
  intended for tooltips, list rows, and scan previews; `long_description` is intended for
  detail panels, journal teasers, and the bodies of in-world readable items. Subclasses may
  reinterpret `long_description` as a teaser and add their own body field (JournalEntry does
  this), but the base contract is: two strings, short first, long second.
- **Gear imposes no load path.** Gear itself is not registered with any autoload; subclasses
  decide where their `.tres` files live and which autoload scans them.

## Requirements from content

- **Subclasses must use `class_name <Subclass> extends Gear`.** Plain `extends Resource` will
  break every system that type-checks against Gear (Journal, PropRegistry, catalog helpers).
- **Id-prefix convention.** Each subclass owns a letter prefix that its registry asserts at
  load time. Current prefixes: `P` for PropDef (`&"P00001"`), `J` for JournalEntry
  (`&"J00001"`), `C` for CutsceneDef (`&"C00001"`), `R` for Recipe (`&"R00001"`), `E` for
  GameEvent (`&"E00001"`). The prefix is enforced by the owning registry, not by Gear. A new
  Gear-derived class should claim an unused letter and document it here.
- **Ids are `StringName` literals.** Plain strings will fail the typed field assignment or
  silently miss registry lookups. Editor tools that emit `.tres` files must serialise the id
  as `&"..."`, not as a quoted string.
- **Ids should be unique within their subclass.** Gear does not enforce uniqueness; the owning
  registry does. Two PropDefs with the same id will collide in `PropRegistry`. Two JournalEntries
  with the same id will collide in `JournalEntryRegistry`. Cross-subclass collisions
  (PropDef `&"P00001"` vs JournalEntry `&"J00001"`) are impossible because of the prefix rule.
- **`display_name`, `short_description`, `long_description` are plain `String`.** They support
  `\n` line breaks and Godot's BBCode subset where the UI layer chooses to render it, but
  Gear itself makes no promises about formatting.

## Extension points

- **Adding a new Gear subclass.** Create `scripts/<area>/<name>.gd` with
  `class_name MySubclass extends Gear`, claim an id prefix, add any subclass-specific
  `@export` fields, and pair it with a registry (autoload) that scans its `.tres` folder at
  startup. The new subclass inherits `id`, `display_name`, `short_description`, and
  `long_description` for free.
- **Reinterpreting `long_description`.** A subclass that wants a dedicated body field (like
  JournalEntry's `body`) may treat `long_description` as a teaser or summary. Doing so is a
  subclass choice; callers that only know about Gear still see the field as "the long one."
- **Hooking into save/load.** Gear itself is a pure `Resource` and serialises through Godot's
  default resource serialisation. Subclasses that need custom save behavior should override
  the standard `_get_property_list` / `_get` / `_set` hooks; Gear imposes no save contract.

## Genre-specific notes

Gear is **fully genre-agnostic.** The four fields — id, display_name, short_description,
long_description — are a minimal identity surface that any data-driven game needs. A Civ-like
or Catan-like second game built on this engine would reuse Gear unchanged as the base class
for units, buildings, tech entries, resource tiles, event cards, and so on. None of the
Farhaven-specific capability pack lives at this level; Gear is the one class in the data
hierarchy that has no survival/hex-grid/real-time assumptions baked in at all.

The only genre-adjacent decision is the **letter-prefix id convention**, which is a Farhaven
stylistic choice rather than a requirement. A second game could drop the prefix rule entirely,
or use namespaced ids (`unit.warrior`), or use integer-backed StringNames — none of that
would require touching Gear itself. The prefix rule is enforced inside each owning registry,
not inside Gear.

## Known limitations and TODOs

- **No runtime type introspection.** Callers that have a `Gear` reference and need to know its
  subclass must use Godot's `is` operator (`if g is PropDef`) or check for a subclass-specific
  field. Gear does not expose a `type` enum or a `kind` tag. For most code paths this is fine
  because the caller already knows which registry it pulled the Gear from.
- **No validation on load.** Gear does not check that `id` is non-empty, that `display_name`
  is set, or that the id matches the expected prefix. Those checks live in the owning registry.
  A Gear subclass instantiated outside a registry (for example, in a unit test) can ship with
  an empty id without any complaint from the base class.
- **No i18n hook.** `display_name` and the descriptions are raw strings, not translation keys.
  Localisation, when it arrives, will need either a wrapper layer (a `TranslationKey` type) or
  a subclass override. This is flagged as future work and is not scoped to delivery-006d.
- **Tight coupling to Godot's `Resource`.** Gear extends `Resource`, which means every
  Gear-derived class serialises as a `.tres` and loads through Godot's `ResourceLoader`. A
  second game that wanted to move data into a database or a binary format would need to swap
  the base class. This is acceptable for the current scope; no alternative base is planned.
