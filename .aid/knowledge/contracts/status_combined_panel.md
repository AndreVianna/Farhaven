# StatusCombinedPanel

**Source:** `ui/status_combined_panel.gd`
**Category:** engine-ui
**Layer:** ui
**Depends on:** [`survival_system.md`](survival_system.md), [`day_night_cycle.md`](day_night_cycle.md), [`catalog.md`](catalog.md), [`inventory.md`](inventory.md). Embeds [`inventory_panel.md`](inventory_panel.md) as its right-hand side. Its left side contains status_stats_section, status_discoveries_section, status_nav_section (not separately contracted — they are internal sub-widgets).

## What this system is

StatusCombinedPanel is the **STATUS button's panel** — a two-column "combined panel" that
shows the player's survival state on the left and their inventory on the right. It exists
because Farhaven's design philosophy is to minimise panel switching: when a player wants
to check "how am I doing?" they also usually want to check "what do I have?" So the two
views live together in one panel.

Left column:
- Header "STATUS"
- Stats section (HP, hunger, thirst bars, chapter label)
- Discoveries section (catalog counter)
- Nav section (current tile, day counter, phase)

Right column:
- Embedded InventoryPanel (the full inventory UI)

It extends `CombinedPanel`, a base class that provides the two-column layout, the toggle/
open/close lifecycle, the mutual-exclusion signal, and the embed helpers. The body of this
contract focuses on what StatusCombinedPanel reads from the engine — the CombinedPanel base
class is generic infrastructure and not engine-specific.

## What it reads from the engine

- **SurvivalSystem** (via `set_survival_system(survival)`). The stats section subscribes to
  `survival.stat_changed(stat_name, current, max)` and updates HP / hunger / thirst bars on
  each tick. Stats read: `hp`, `hunger`, `thirst`, `hp_max`, `hunger_max`, `thirst_max`.
- **DayNightCycle** (via `set_day_night_cycle(day_night)`). The stats section reads the
  current day count and phase name for display. Subscribes to DayNightCycle's `day_changed`
  and `phase_changed` signals (via status_stats_section internally).
- **Catalog** (via `set_catalog(cat)`). The discoveries section subscribes to
  `catalog.entry_cataloged` / `entry_encountered` to update the discovery counter.
  Additionally, the embedded inventory panel receives the same catalog reference (for
  toxic flora confirmation dialogs).
- **Inventory** (via `set_inventory(inv)`). Handed off to the embedded InventoryPanel; the
  status left column does not read inventory directly.
- **Chapter text** (via `set_chapter(text: String)`). A simple string that the stats section
  displays — sourced from Main or a future chapter manager, not from an engine system.

## What it calls back to the engine

**Nothing meaningful.** StatusCombinedPanel is read-only from the engine's perspective. The
only mutation path is through its embedded InventoryPanel (tap-to-use), which itself only
mutates the Inventory (not any other engine system). See `inventory_panel.md` for details.

The panel does emit the generic `CombinedPanel.panel_opened` signal on open, used by HUD
for mutual exclusion.

## Contract with HUD

- **`toggle()` / `open()` / `close()` inherited from CombinedPanel.** HUD calls
  `_status_panel.toggle` from the STATUS button `pressed` signal.
- **`panel_opened` signal** — connected by HUD to `_on_panel_opened.bind(_status_panel)` for
  mutual exclusion. Opening this panel closes Gear and Log.
- **`_on_opened()` override** — when the panel is opened, it also opens the embedded
  InventoryPanel so the inventory side is visible immediately without a second tap.
- **`get_inventory_panel() / get_stats_section() / get_discoveries_section() /
  get_nav_section()`** — accessors for tests and for external wiring that needs to reach
  into a sub-widget.

## Contract with main wiring

Main code calls (in this order):

1. `status_panel.set_survival_system(survival)` — wire stats feed
2. `status_panel.set_day_night_cycle(dnc)` — wire day/phase display
3. `status_panel.set_catalog(catalog)` — wire discoveries counter and toxic-flora check
4. `status_panel.set_inventory(inv)` — wire inventory panel data
5. `status_panel.set_chapter("Chapter 1")` — set display text

Each setter is idempotent and the sections are duck-typed — calling a setter on a section
that doesn't have the method will fail silently (the sub-section methods exist in v1 but
the duck-typed declaration leaves room for test doubles).

## Genre-specific notes

- **HP / hunger / thirst stat bars are survival-genre specific.** The stats section's
  visual layout is tied directly to the three-stat survival model from `survival_system.md`.
  A non-survival game would replace the stats section entirely.
- **Discoveries counter is exploration/science-horror specific.** The "N of M cataloged"
  display is meaningful only in games with a knowledge-gating mechanic. A pure combat
  game would drop this section.
- **Nav section is Farhaven-specific.** The "current tile + day + phase" layout assumes
  hex coordinates and a day/night cycle. A different game would show different nav info
  (location name, objective, minimap reference).
- **The two-column "status + inventory" combined layout is Farhaven-specific.** The
  decision to co-locate these two views is a deliberate UX choice for a touch-first game
  with minimal panel-switching. A keyboard-and-mouse game might split them.
- **CombinedPanel base class is engine-generic.** The two-column + mutual-exclusion pattern
  transfers to any game with multiple top-level panels.

## Known limitations and TODOs

- **Setters are order-sensitive.** If `set_survival_system` is called before the stats
  section is built, the subscription fails silently. Main code must call setters after
  `_ready` has run.
- **Duck-typed section references.** Using `Node` rather than the concrete types is a
  workaround for class_name race conditions. Works but less type-safe than it should be.
- **No responsive layout.** The two-column split is 50/50 on every screen. A very narrow
  screen (small phone) would benefit from stacking.
- **Chapter text is a plain string.** No localisation, no chapter metadata. A future
  chapter manager would replace `set_chapter(text)` with `set_chapter(chapter_def)`.
- **Discoveries section filter duplication.** The same catalog reference is handed to both
  the discoveries section and the inventory panel — the inventory panel uses it only for
  toxic flora checks, which is an unusual coupling. Flagged for a cleaner data path (the
  inventory panel could read toxicity directly from PropDef without needing catalog).
- **No way to expand the inventory side on wide screens.** Desktop / tablet players might
  prefer a different split ratio when they have room.
- **Nav section is duck-typed to Node.** The comment in the source explicitly calls this
  out as a parse-order workaround. Flagged.
