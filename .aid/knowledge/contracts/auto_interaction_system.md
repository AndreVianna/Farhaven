# AutoInteractionSystem

**Source:** `scripts/auto_interaction/auto_interaction_system.gd`
**Category:** genre-specific
**Layer:** system
**Depends on:** [`prop_def.md`](prop_def.md), [`recipe.md`](recipe.md) (including its Siblings section on Predicate, used indirectly through PredicateEvaluator), [`recipe_registry.md`](recipe_registry.md), [`discovery_watcher.md`](discovery_watcher.md), [`catalog.md`](catalog.md), [`inventory.md`](inventory.md), [`hex_grid.md`](hex_grid.md), [`fauna_manager.md`](fauna_manager.md) (for auto-defend), [`survival_system.md`](survival_system.md) (for activity costs). Reads from `catalogable_cap.md` and `portable_cap.md` indirectly. Not an autoload — it is a child Node of Player.

## What this system is

AutoInteractionSystem is the **player's proximity dispatcher**: the node that asks, every
tenth of a second, "is there anything within arm's reach of the player that a gather recipe
or a pickup should trigger right now?" If yes, it starts a gather timer, waits for it to
complete, applies the prop's **resolved gather yield** to the player's inventory
(`PropRegistry.get_yield_type(prop.type)` × `PropDef.gather_amount` — the recipe match gates
*whether* the gather runs and *how long* it takes, but the item produced is still driven by the
prop's own yield fields, not by `recipe.outputs`), and chains into the next candidate. It also
owns a small auto-defend hook that fires an attack when a hostile catalogued creature walks
adjacent, and an auto-pickup hook that vacuums ground items the player walks over.

It is the gameplay "bridge" between the passive exploration loop (walk around) and the
economic loop (items appear in your inventory). It never asks the player to tap anything —
proximity is the verb.

## Promises to content

- **Proximity gather radius is 0.75 world units (≈ arm's reach).** Any natural prop whose
  world-space XZ distance to the player is less than or equal to `GATHER_RADIUS` is a
  candidate. Hex distance is not used; the check is continuous-space on the XZ plane.
- **Proximity is throttled, not per-frame.** The check runs every `PROXIMITY_CHECK_INTERVAL`
  (0.1s). Content should not expect a candidate to be picked up in the same frame it comes
  into range — up to one tick of latency is normal.
- **Candidates are sorted: priority desc, distance asc.** A tool-gated recipe wins over an
  ungated one. Among equal-priority candidates, the nearer one wins. Ties are deterministic
  within a single tick but content should not depend on exact ordering of simultaneous
  candidates.
- **Recipe match drives behaviour, legacy catalog is a fallback.** The first query is
  "find a gather recipe that accepts this prop type as input." If found, its conditions are
  evaluated via PredicateEvaluator against a freshly-built WorldContext; if conditions fail
  with a `has_tool` predicate the candidate goes into the *tool_gated* list (which emits
  `auto_gather_failed(&"tool_required")` as a hint). If no recipe matches, the legacy catalog
  path kicks in (checks `CatalogableCap` presence and the player's `tool_required` field).
- **Gather timer is a Tween, gathering always completes.** There is no cancel path. Once
  `_begin_gather` fires, the tween runs to completion; if the player walks away the gather
  still finishes and the item is added on arrival back at the tile (or silently fails if the
  prop was consumed by another system).
- **Duration is recipe-first, legacy-fallback.** If a recipe is matched, the gather duration
  is `recipe.duration`. If the legacy catalog path is used, it's `PropDef.gather_time *
  PropRegistry.get_tool_speed(prop_type, equipped_tool)`.
- **On completion: yield type resolution + inventory add + respawn queue enroll.** The yield
  is `PropRegistry.get_yield_type(prop_type)` (e.g. `loose_rock` yields `stone`). `prop.remaining`
  is decremented; if it hits zero, `HexGrid.prop_depleted` fires, and if `respawn_time > 0`
  the prop is enqueued in an internal respawn queue that restores `remaining = max_amount`
  when the timer expires.
- **Activity costs are forwarded to SurvivalSystem.** On each successful gather, the
  `&"gathering"` activity cost is applied via `survival.apply_activity_cost`. On auto-defend,
  the `&"attacking"` cost is applied.
- **Signals are the integration contract for HUD/audio.** `auto_gather_started`,
  `auto_gather_completed`, `auto_gather_failed(reason)`, `auto_defend_triggered`,
  `ground_item_picked_up` are what the HUD and GatherSound listen to. They are the only
  stable surface this system exposes.
- **Auto-pickup consumes SurvivalSystem's ground items.** When the player is within
  `GATHER_RADIUS` of a ground item (tracked per sub-hex by SurvivalSystem), the item is added
  to inventory and removed from the ground list.

## Requirements from content

- **Must be child of Player.** The system walks `get_parent()` to find the player node, reads
  `player.current_tile` and `player.global_position`, and looks up sibling nodes
  (`ScannerSystem`, `FaunaManager`, `SurvivalSystem`) by name. Detaching it from Player will
  break dependency resolution.
- **Player must expose `current_tile` (Vector2i) and `get_inventory()`.** The first is the
  player's hex coordinate; the second returns the `Inventory` instance the system will
  mutate on gather completion.
- **Sibling `ScannerSystem` must expose `catalog`.** The scanner's catalog is how the system
  learns which props count as "cataloged" for the legacy gate. If no scanner sibling is
  present, only the recipe path works.
- **Gather recipes must opt in via `actions.has(&"gather")`.** A recipe without the `&"gather"`
  action string is invisible to this system even if its inputs match.
- **Gather recipes must be known to be eligible.** If a `DiscoveryWatcher` autoload is
  present, only recipes whose id is known per `discovery.is_known(recipe.id)` are considered.
  Newly-discovered recipes become eligible on the next proximity tick.
- **Natural props only.** Only props with `origin == NATURAL` are gather candidates. Crafted
  structures and anomalies are never auto-gathered.
- **`prop.remaining > 0` required.** Depleted props waiting to respawn are invisible to
  proximity scanning.

## Extension points

- **Connect `auto_gather_started` / `auto_gather_completed` for HUD feedback.** HUD, sounds,
  particles, floating text — anything that wants to react to gather events subscribes to
  these signals. There is no polling API.
- **Inject dependencies for tests.** Tests can set `_grid`, `_player`, `_catalog`,
  `_inventory`, `_registry`, `_discovery` before `_ready()` runs. Normally `_ready()`
  auto-resolves them from the autoload tree and the sibling layout.
- **Add a new activity cost.** If a new verb (e.g. `&"fishing"`) is added, extend
  `survival_system.md`'s ACTIVITY_CONFIG and call `apply_activity_cost(&"fishing")` from a
  new code path. The dispatcher itself does not need to change.
- **WEAPON_DAMAGE override.** The hardcoded `WEAPON_DAMAGE` dictionary maps weapon PropDef
  ids to damage integers. Adding a new weapon id adds an entry; the fallback for an
  unrecognised weapon is 5. Long-term this belongs in a weapon `CombatCap`, but for now it
  lives here.

## Genre-specific notes

AutoInteractionSystem is **highly genre-specific** — it is the most "Farhaven survival game"
system in the engine.

- **Proximity-as-verb.** The whole design assumes "walk near a thing, the thing happens."
  This is a survival genre convention (Minecraft's right-click, The Long Dark's approach +
  harvest, Don't Starve's hover gather). A Civ-like or turn-based game would replace this
  entirely with click-to-command.
- **Real-time gather timers.** Tween-based gather duration assumes a real-time loop. A
  turn-based successor would need to reformulate `duration` as "turns to complete" and drive
  timer advance off a TurnManager.
- **Continuous-space candidate selection.** The 0.75-unit XZ distance is explicitly not hex
  distance — it's meant to feel like physical arm-reach on a 2.5D map. A pure top-down or
  pure grid-snapped game would use hex distance instead.
- **Auto-defend is a stub.** The v1 implementation fires `auto_defend_triggered` with a
  damage number drawn from WEAPON_DAMAGE; there's no animation, no to-hit roll, no AI
  retaliation. When the combat runtime lands (delivery-006d task-088) this path will be
  reworked into proper attack event firing.
- **Auto-pickup assumes a ground-item model.** Games without "dropped items on the ground"
  (point-and-click adventures, RTS) would remove this path entirely.

The closest thing to a genre-agnostic core is the **signal surface** (`auto_gather_started`
et al.). A different gather system for a different game could emit the same signals and the
HUD would not need to change.

## Known limitations and TODOs

- **Gather cannot be cancelled.** Walking away mid-gather does not interrupt the tween. This
  was a deliberate simplification for v1 — the interrupt path would require cleaning up the
  tween, re-emitting `auto_gather_failed(&"interrupted")`, and deciding whether partial
  progress is refunded. Flagged for a future UX pass.
- **Auto-defend lacks feedback.** `auto_defend_triggered` fires but there's no visible attack
  animation, no sound hook, and no damage numbers on the target. HUD currently shows a red
  `-N` at the player's position as a placeholder.
- **WEAPON_DAMAGE is hardcoded.** Weapon damage should live on the weapon's PropDef via a
  future `CombatCap` or `ToolCap`. The current hardcoded table is the smallest possible
  v1 solution.
- **Legacy catalog path is staying alive for now.** The fallback exists so that old PropDefs
  without recipes still gather. Removing it is waiting on full migration of every gatherable
  prop to the recipe system.
- **Respawn queue ticks only while the system is alive.** If the player is in a scene where
  AutoInteractionSystem is not running (main menu, cutscene), respawns pause. This is
  usually fine but is not an explicit guarantee.
- **Proximity tick interval is a constant.** No way to slow it down on mobile for battery,
  or speed it up for precision. A future pass might expose it as a tunable.
