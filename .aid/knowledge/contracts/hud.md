# HUD

**Source:** `scripts/hud/hud.gd`
**Category:** engine-ui
**Layer:** ui
**Depends on:** [`survival_system.md`](survival_system.md), [`inventory.md`](inventory.md), [`catalog.md`](catalog.md), [`auto_interaction_system.md`](auto_interaction_system.md), [`building_system.md`](building_system.md), [`recipe_runtime.md`](recipe_runtime.md) (indirectly via crafting_system connection), [`prop_def.md`](prop_def.md). Embeds [`status_combined_panel.md`](status_combined_panel.md), GearCombinedPanel, LogCombinedPanel. Contains [`inventory_panel.md`](inventory_panel.md), [`catalog_panel.md`](catalog_panel.md), [`journal_panel.md`](journal_panel.md) through its child combined panels.

## What this system is

HUD is the **root UI container** — a `Control` node that holds every on-screen panel and
feedback widget, and coordinates mutual exclusion between the three "combined panels"
(Status, Gear, Log). It is the single entry point external systems call into when they
need to show something to the player.

HUD itself renders very little directly. Its responsibility is composition and routing:

- Own the StatBars, DayCounter, FloatingTextContainer, NotificationContainer,
  PlacementLabel, and craft flash.
- Own the three combined panels (created programmatically in `_ready`, not via tscn).
- Connect external systems (Inventory, Catalog, Crafting, Building, AutoInteraction,
  sound) and route their signals to the right child widget.
- Provide convenience pass-through methods so callers can treat the HUD as one facade
  (`hud.show_notification("...")` rather than drilling into sub-widgets).

## Promises to content (engine systems calling HUD)

- **Three mutually exclusive combined panels.** STATUS (left = status + nav + discoveries,
  right = inventory), GEAR (crafting + building), LOG (catalog + journal). Opening one
  closes the other two automatically via `_on_panel_opened` routing.
- **Bottom bar buttons toggle panels.** `StatusButton.pressed → status_panel.toggle`, same
  for Gear and Log. Panels remember their own open/closed state; HUD only coordinates
  exclusion.
- **Placement label API for BuildingSystem.** `show_placement_label(structure_type)` sets
  the `TAP TO PLACE <TYPE>` text and shows the label. `hide_placement_label()` hides it.
  Called from BuildingSystem's placement mode entry/exit.
- **Stat and day updates are pass-throughs.** `update_stat(name, value, max)` →
  `_stat_bars.update_stat(...)`. `update_day(day)` and `update_phase(phase)` →
  `_day_counter`. External systems call these directly; HUD is a thin router.
- **Floating text and notifications.** `show_text(world_pos, text, color, duration)` adds
  a floating number or text anchored to a world position (used for +items, -damage, tool
  warnings). `show_notification(text, duration)` adds a banner-style message.
- **Inventory full is a notification.** HUD subscribes to `inventory.inventory_full` and
  shows `"INVENTORY FULL"` as a notification (not floating text, because the signal has no
  world anchor).
- **`connect_inventory(inv)` wires inventory signals.** Stores the inventory reference in
  the status panel and connects the `inventory_full` routing. Called once at game start by
  Main.
- **`connect_catalog(cat)` wires catalog signals.** Stores the catalog reference on both
  the log panel (for CatalogPanel + JournalPanel) and the status panel (for discoveries
  section + toxic flora check on inventory panel).
- **`connect_crafting(crafting_system, inv)` wires crafting feedback.** Stores references
  on the gear panel and connects three signals: `station_proximity_changed`,
  `recipe_discovered`, `craft_completed`. Recipe discovery shows a notification; craft
  completion shows a notification + craft flash + sound.
- **`connect_building(building_system)` hands the building system to the gear panel.**
  Used by the crafting / build tab routing inside GearCombinedPanel.
- **`connect_auto_interaction(auto_interaction)` wires gather feedback.** Subscribes to
  `auto_gather_completed`, `auto_gather_failed`, `auto_defend_triggered`. Shows `+N <name>`
  floating text on successful gather, `INVENTORY FULL` or `REQUIRES TOOL` on failure, and
  `-N` red number on defend.
- **`connect_sound(sound_node)` stores a GatherSound reference.** HUD calls
  `_gather_sound.play_gather_ding()` and `play_craft_success()` when those events fire.
  Sound is optional — a null sound_node is tolerated.

## Requirements from content

- **Must be placed at `Main/HUD/HUD` in the scene tree.** BuildingSystem's `_find_hud()`
  resolves by absolute path. Moving the HUD requires updating that path.
- **Combined panels are created programmatically.** The HUD scene file does NOT contain
  StatusPanel / GearPanel / LogPanel children — they're instantiated and added in `_ready`.
  This means test harnesses that instantiate the HUD via `.new()` get the full panel tree.
- **Child widgets expected at fixed paths.** `$StatBars`, `$DayCounter`,
  `$FloatingTextContainer`, `$NotificationContainer`, `$PlacementLabel`, `$BottomBar/StatusButton`,
  `$BottomBar/GearButton`, `$BottomBar/LogButton`. These come from the HUD scene file; the
  programmatic children are on top.
- **`_get_player()` walks Main/World/Player.** For floating-text anchoring on gather /
  defend feedback. A missing player path degrades to `Vector3.ZERO` anchor.
- **External systems call in via explicit `connect_*` methods.** HUD is not discoverable —
  systems cannot just subscribe; Main code must explicitly call `hud.connect_inventory(...)`
  etc. during game startup.

## Extension points

- **Add a new combined panel.** Instantiate it in `_ready`, add it to `_panels` for mutual
  exclusion, connect its `panel_opened` signal to `_on_panel_opened.bind(panel)`, and add
  a bottom bar button. The rest is routing.
- **Add a new `connect_*` method.** For any new system that wants HUD hooks. Follow the
  crafting / auto-interaction pattern: store the reference, subscribe to signals, route to
  the appropriate widget.
- **Customize feedback.** Replace FloatingTextManager or NotificationManager without
  touching HUD if they maintain the same `show_text` / `show_notification` signatures.
- **Swap a combined panel.** Replace GearCombinedPanel with a different crafting UI as
  long as it exposes `set_crafting_system`, `set_inventory`, `set_building_system`, `toggle`,
  `close`, and `panel_opened`.

## Genre-specific notes

HUD is **mostly engine-UI** — it is primarily a composition layer. Its genre-specific
bits are:

- **Stat bars are survival-flavoured.** The `_stat_bars` child is specifically set up for
  HP, hunger, thirst. A non-survival game would swap it for a single HP bar, mana, or
  whatever its stat model needs. The rest of the HUD would stay unchanged.
- **Day counter is survival-flavoured.** The `update_day` / `update_phase` pass-throughs
  assume a day/night cycle. A non-survival game would replace the widget.
- **"Three combined panels" split is Farhaven-specific.** The Status / Gear / Log
  triangulation is a design choice for a touch-first survival game. A different game
  might use a radial menu, a single paginated panel, or no panels at all.
- **Notification + floating text feedback loop is genre-neutral.** Any game can use these.
  The fact that gather feedback is green `+N` and damage feedback is red `-N` is a visual
  convention that transfers.
- **Placement label is build-mode specific.** Only useful when there's a placement mode.
  Games without building would never call it.

The "thin router plus pass-through convenience" pattern is clean and reusable. A second
game could replace every child widget without touching HUD's shape.

## Known limitations and TODOs

- **`_find_hud` uses an absolute path.** Scene reorganisation breaks every system that
  looks up HUD. Converting to a signal-bus pattern or an explicit HUD reference on the
  player would be cleaner.
- **`connect_*` methods are order-sensitive.** Main code must call them in a specific order
  at game start. A future pass could make HUD an orchestrator that pulls references from
  a registry on `_ready` instead of having them pushed in.
- **Placement label text is uppercased and hardcoded.** `"TAP TO PLACE %s" % structure_type.to_upper()`.
  No localisation and no visual language support. Flagged.
- **Recipe / craft notification uses string manipulation on recipe id.** `recipe_name.replace("_",
  " ").capitalize()`. Fine for English, brittle for localisation. Should read from the
  PropDef `display_name`.
- **`connect_sound` is optional but silently.** No error if sound_node is missing — calls
  to sound methods just no-op via `has_method` guards. Fine for headless tests but easy
  to forget.
- **`_on_station_proximity_changed` is an empty pass.** The hook exists but doesn't do
  anything; the comment says "craft button visible whenever recipes are discovered (not
  just near station)." Legacy — left in place in case the design reverts.
- **Mutual exclusion is implemented by closing other panels on open.** Three panels means
  three signal connections. Scales linearly with the number of panels.
- **No confirmation on destructive actions from HUD itself.** The toxic confirm dialog
  lives in InventoryPanel, not HUD. HUD has no authority to gate actions.
