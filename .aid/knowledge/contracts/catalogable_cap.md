# CatalogableCap

**Source:** `scripts/data/capabilities/catalogable_cap.gd`
**Category:** core
**Layer:** data
**Depends on:** [`prop_def.md`](prop_def.md), [`scanner_system.md`](scanner_system.md)

## What this system is

CatalogableCap marks a PropDef as "something the player can scan and add to the catalog."
The scanner and catalog subsystems use the presence of this cap as the canonical gate: if a
PropDef has no `catalogable` cap, it is invisible to the scan lifecycle entirely. When the
cap is present, its fields tell the scanner how long a scan takes, whether the entry should
be forced into the "Anomalies" bucket regardless of its origin, what icon the catalog panel
should use, and what structured properties (edibility, toxicity, resource type) the catalog
should surface in the detail view.

## Promises to content

- **Presence is the scan gate.** `def.catalogable != null` is the single check that decides
  whether a prop is scannable. No capability, no scan entry, no catalog tracking. This is
  enforced in both [`scanner_system.md`](scanner_system.md) and the catalog side.
- **`scan_time` is the per-entry scan duration.** It is declared in seconds and defaults to
  `1.0`. The scanner reads it to drive the progress bar and the "scan complete" transition.
  *(Status note: the delivery-006d scanner currently runs a fixed duration path and does
  not yet consume `scan_time` — see Known limitations.)*
- **`show_as_anomaly` forces the entry into the Anomalies bucket.** Regardless of the parent
  PropDef's `origin` value (Natural / Crafted / Structure / etc.), a catalog entry with
  `show_as_anomaly = true` is filed under `Catalog.ANOMALY_BUCKET`. This is how Farhaven
  handles "weird" props whose origin field alone would classify them into the wrong group.
  The field is read by both Catalog (for bucketing) and ScannerSystem (for special-cased
  scan behavior).
- **`icon` is the catalog panel thumbnail.** If set, the catalog panel uses it as the entry's
  preview image. If null, the panel falls back to its default (generic) icon. Content can
  ship an entry with no icon and it will still display.
- **`properties` is an open dictionary.** It is intended to hold structured metadata the
  catalog panel can display — examples in the source include `{"edible": false,
  "toxic": false, "resource_type": "wood"}`. The keys and value types are free-form; the
  panel decides which ones to render. This is a deliberate escape hatch for ad-hoc
  per-entry data without having to add a new `@export` for every new attribute.
- **CatalogableCap is shared across instances.** All rocks of type `P00010` share one
  CatalogableCap. There is no per-instance override — a rock on fire is still the same
  catalog entry as a rock not on fire.

## Requirements from content

- **Sub-resource shape, not dictionary.** CatalogableCap must be authored as an inline
  `[sub_resource type="Resource"]` block with `script = ExtResource("catalogable_cap")`.
- **The parent PropDef must have a non-empty `display_name`.** The scanner explicitly skips
  entries where `String(def.display_name) == ""`. A CatalogableCap on a nameless PropDef
  will load but will never produce a catalog entry.
- **`scan_time` is a `float` in seconds.** Values below ~0.1 will produce a progress bar
  that feels instantaneous; values above ~30 become user-hostile unless the UX explicitly
  handles long scans.
- **`show_as_anomaly` is a `bool`.** Use only when the entry genuinely belongs in the
  Anomalies bucket regardless of its origin. This is a deliberate override; setting it on
  every prop defeats the bucket system.
- **`icon` must be a `Texture2D` resource reference, not a path string.** Godot's `.tres`
  serialisation handles the reference; a string path will fail the typed field.
- **`properties` keys should be simple strings.** The dictionary is typed `Dictionary`
  (untyped), so any values will serialise, but the catalog panel only renders keys it
  recognises. Content that wants a new `properties` key must coordinate with the panel.

## Extension points

- **Adding a new `properties` key.** Author it in the `.tres`. If the catalog panel already
  reads that key, it will display; if not, it will quietly ignore it. This is the low-friction
  extension path — no code change required for experimental fields.
- **Adding a new anomaly subclass.** `show_as_anomaly` is a binary flag; the catalog has a
  single `ANOMALY_BUCKET`. If a future design wants multiple anomaly subcategories (e.g.
  "temporal," "biological," "unknown origin"), the flag should be promoted to an enum and
  the catalog's bucketing logic updated. Not scoped to delivery-006d.
- **Overriding scan behavior.** CatalogableCap itself cannot override scan behavior beyond
  `scan_time`. More complex scans (multi-stage, interrupted, tool-gated) would require a
  new field or a paired sub-resource (e.g. a `ScanPolicy`). This is noted in the Open
  Questions for a future iteration.
- **Hooking into composition.** CatalogableCap composes cleanly with any other capability.
  A scannable container, a scannable light, a scannable creature — all are authored by
  adding `catalogable` to the PropDef alongside the other caps. The scanner subsystem
  reads only `catalogable`; it is agnostic to everything else on the PropDef.

## Genre-specific notes

CatalogableCap is **largely genre-agnostic.** The pattern — "this resource is indexable by
a scanning/learning mechanic, has an icon, has a display duration, and carries open
metadata" — transfers to any game with a codex, encyclopedia, bestiary, or research tree.
A Civ-like second game could reuse CatalogableCap unchanged for units the player has
encountered, techs the player has researched, or wonders the player has seen.

The **`scan_time` field carries a real-time assumption.** A duration in seconds makes sense
for a real-time scanner that tracks progress against wall-clock; a turn-based game would
either ignore the field or reinterpret it (turns, action points). The value itself is a
plain float, so no code change is needed for reinterpretation — only a convention change.

The **`show_as_anomaly` flag and the ANOMALY_BUCKET concept** are Farhaven-flavored but not
strictly genre-bound. They describe a UX pattern ("this doesn't fit neatly in any origin
bucket, so show it separately") that any game with grouped catalog entries would find
useful. A second game that did not want the concept could simply leave `show_as_anomaly`
false on every entry and ignore the bucket.

The **`properties` dictionary** is the most genre-adjacent piece. Farhaven's survival
vocabulary — `edible`, `toxic`, `resource_type` — would not match a Civ-like game's needs
(`era`, `tech_level`, `faction`). Because the dictionary is open, this is a swap rather
than a rewrite: a second game ships its own property vocabulary and its own catalog panel
rendering.

## Known limitations and TODOs

- **`scan_time` is not yet consumed by the scanner runtime.** The current ScannerSystem
  runs with a fixed duration and does not read `scan_time` per entry. The field exists
  and round-trips through serialisation, but authoring a shorter or longer value today has
  no effect in-game. Fix is on the delivery-006d task-088 sweep (or equivalent).
- **`icon` is null for every shipped PropDef.** The source comment explicitly notes
  "(currently null for all)." The catalog panel falls back to a generic thumbnail. Real
  icon assets are deferred to delivery-007 content work.
- **`properties` has no schema.** Any key, any value. This is good for experimentation and
  bad for long-term maintenance. A future validator could warn about unknown keys or
  enforce a canonical vocabulary.
- **No per-instance state.** "Has the player scanned *this specific* rock?" lives in the
  Catalog / ScannerSystem layer, not on CatalogableCap. Content authors occasionally
  expect a `discovered` flag on the cap and are disappointed.
- **Anomaly override is binary.** A PropDef cannot partially belong to both its origin
  bucket and the anomaly bucket. The only tool available is `show_as_anomaly = true`,
  which moves the entry wholesale into the anomaly group.
- **No localisation slot.** `properties` values are raw, and CatalogableCap does not carry
  translation keys. This is fine for now; a future localisation pass will need to decide
  whether to extend CatalogableCap or layer a translation step on top.
