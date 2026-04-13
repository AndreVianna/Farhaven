# delivery-006k: Script Engine Refactor + Test-Map Cleanup

**Status:** Planning
**Created:** 2026-04-12
**Depends on:** delivery-006j (merged — WearableCap + body schema)
**Goal:** Consolidate the Script (Recipe + GameEvent) system around a single, complete formula. Replace the legacy hardcoded recipe dict. Wipe placeholder content (props/recipes/events/journal/cutscenes) so that real Chapter 1 content can be authored against the cleaned-up engine.
**Successor:** Real Chapter 1 content + professional UI pass.

---

## Why this delivery exists

Two debts compound and have to be paid together:

1. **Two parallel recipe systems coexist.** `scripts/crafting/crafting_system.gd` carries a hardcoded `RECIPE_CONFIG` dict (3 entries: stone_axe, stone_pickaxe, campfire) that the in-game Crafting screen uses. Meanwhile, `data/recipes/*.tres` has 26 data-driven Recipe resources consumed by the editor and `RecipeRuntime`. The two never reconcile — the player sees scripts the editor doesn't list, and vice versa.

2. **Script semantics are partially defined.** Recipe and GameEvent both extend ScriptBase, which has `actions: Array[StringName]`, `conditions`, `effects`, `duration`. Recipe adds `inputs` / `outputs`. But the meaning of "action", how scripts are routed to UI surfaces, what triggers them, and how player intent maps to script execution are inconsistent across systems. The Crafting panel filters one way; the AutoInteractionSystem another; the discovery/event chain a third.

This delivery codifies a **single Script formula** governing all gameplay logic, deletes the hardcoded dict, and wipes placeholder content so the real Chapter 1 can be authored against the cleaned-up engine.

---

## The Script formula (DECIDED)

```
Script = Trigger + [Inputs] + [Conditions] => [Outputs] + [Effects]
       + required_time
```

Every gameplay logic unit (Recipe, GameEvent) follows this shape.

* **Trigger** — what makes the script *eligible to fire*.
* **Inputs** — props consumed (or held) by the script.
* **Conditions** — predicates that must be true at start AND at commit.
* **Outputs** — props produced by the script.
* **Effects** — non-prop side effects fired at commit.
* **required_time** — seconds between trigger and commit. `0` means instant.

### Atomic execution semantics

1. Trigger fires.
2. Validate all conditions at start. Failure → silent abort, nothing touched.
3. If any output prop has `PlaceableCap`: open placement UI. Player picks position (with footprint preview) or cancels. Cancel → abort.
4. Start `required_time` timer (no-op if 0).
5. At commit (`t = required_time`):
   1. Revalidate all conditions. Failure → abort, inputs intact.
   2. Spawn outputs:
      * Placeable → at the location chosen in step 3.
      * Non-placeable → try inventory; if no fit → drop in player vicinity (1 sub-hex); if no fit there → abort.
   3. Consume inputs (those with `consume = true`).
   4. Fire effects (all-or-nothing — see Effects).

The order *spawn → consume* is important: if step 5.2 aborts, no inputs were consumed and the player is back to a clean state.

---

## Class hierarchy (DECIDED)

```
Resource                                  (Godot)
└── Gear                                  (id, display_name, short/long_description)
    ├── ScriptBase                        (conditions, effects, required_time)
    │   ├── Recipe                        (inputs, outputs)
    │   └── GameEvent                     (occurrence tracking)
    ├── PropDef                           (tags, capabilities[…])
    ├── CutsceneDef                       (cutscene metadata)
    └── JournalEntry                      (journal entry content)
```

* `actions: Array[StringName]` on ScriptBase **goes away.** Replaced by the typed `Trigger` field below.
* `duration` on ScriptBase is **renamed `required_time`** for clarity. Old meaning (prop lifetime after creation) moves onto a PropDef cap (DecayCap or similar — to be defined when needed).

---

## Triggers (DECIDED — 5 kinds)

A Script declares a single Trigger. Polymorphic — each kind is a Resource subclass with its own params.

| Kind | Fires when | Example |
|------|------------|---------|
| **Proximity** | Player enters or stays in range of a target matching a filter (prop_id / cap / tag) | Cook Meat near a HeatSourceCap prop |
| **Action** | Player presses the contextual Action button OR selects the script in the Interact panel | Craft Stone Axe selected from Craft tab |
| **Time** | Time-relative event: tick, duration elapsed, day phase change | Food spoils after N minutes |
| **Signal** | A named engine signal fires (damage, death, prop_cataloged, weather change, fire_script chain, etc.) | Discovery event reacts to `prop_cataloged` |
| **State** | Predicate flips from false to true (passive evaluation) | "HP < 20%" warning fires |

**Notes:**

* Milestones (narrative events) and mechanical event chains both flow through **Signal** — distinguishing them is data, not type.
* `fire_script` (effect) emits a named signal that other Signal-trigger scripts react to, enabling chains. Cycles are detected at registry **load time** (static graph analysis) and refused with a clear error.
* The Action trigger covers both the floating Action button (context-sensitive verb) and the deliberate selection from Interact panel tabs (Craft / Build / Actions). The system distinguishes the two via the cap on the Script (see "Caps on Scripts" below).

### Trigger schemas (DECIDED — minimum field set)

```
ProximityTrigger:
    target: { prop_id?, cap?, tag? }   # one or more, OR semantics
    range: enum { same_sub_hex, adjacent_sub_hex, same_hex }   # default: adjacent

ActionTrigger:
    # No params — eligibility is determined by Conditions + Caps.

TimeTrigger:
    when: enum { tick, duration_elapsed, day_started, phase_changed }
    delay_sec?: float                # for duration_elapsed / tick

SignalTrigger:
    signal: StringName               # name of the named signal to listen for
    payload_filter?: Dictionary      # optional value matchers on the payload

StateTrigger:
    predicate: Predicate             # reuses existing Predicate resource subclass
```

---

## Inputs (DECIDED)

Inputs are the props the Script needs to operate. Sourced from the player's **possession** = inventory grid OR a container in **immediate vicinity** (same sub-hex or one adjacent sub-hex).

```
Input:
    ref: { prop_id | cap | tag }     # what to look for
    count: int                        # how many
    consume: bool                     # true → removed at commit; false → must be present, untouched
```

Examples:

* Stone Axe: `Input{wood, 2, consume=true}, Input{rock, 1, consume=true}`
* Chop Tree: `Input{axe, 1, consume=false}` (axe is "needed but not consumed")
* Cook Meat: `Input{raw_meat, 1, consume=true}`

Tools are inputs with `consume = false`. No special "tool" type — this falls out of the formula.

The **target** of a Proximity trigger (the tree, the campfire) is **not** an input. It's the implicit subject of the trigger. Inputs only describe stuff the player carries.

---

## Outputs (DECIDED)

Outputs are the props the Script produces.

```
Output:
    ref: { prop_id | cap | tag }     # usually prop_id; cap/tag for procedural picks
    count: int
    probability: float                # 0..1 — rolls independently per output
```

**Destination is decided by the runtime, not the author:**

* If the output prop has `PlaceableCap`: opens placement UI **before** the timer; output spawns at the chosen location at commit.
* Otherwise: tries inventory; on overflow tries ground in vicinity; on overflow there too, the script **aborts** (no partial state).

Authors who want to abort early when they know there's no space declare a `must_have_space` condition.

---

## Conditions (PARTIAL — must_stay_close + must_have_space DECIDED; full taxonomy TO DEFINE)

Conditions are predicates evaluated at start AND at commit. Any failure → abort, inputs intact, nothing produced.

DECIDED:

* **must_stay_close** — player remains within the trigger's range throughout `required_time`.
* **must_have_space** — at least one output destination has space (early abort).

The existing `Predicate` resource subclass (from `scripts/recipes/predicate.gd`) is the natural carrier for declarative conditions. The full list of condition kinds will be defined as content authoring surfaces specific needs.

> **TO DEFINE:** Complete condition taxonomy (has_tool, at_station, time_of_day, weather, faction_status, threshold predicates, etc.). Reuse / refactor existing Predicate kinds. Add new ones as needs emerge.

---

## Effects (DECIDED — 7 gameplay kinds; aesthetic hooks deferred)

Effects are non-prop side effects fired at commit. **Tudo-ou-nada:** all effects fire if the script commits; none fire if it aborts. No per-effect conditions. Aesthetic effects (sound, animation, particles, screen flash, haptic) are **out of scope for this delivery** — they will be wired through a separate Hooks system later.

| Kind | Purpose |
|------|---------|
| `modify_world_state` | Mutate world parameters: time of day, biome of a hex, add prop to world, set/clear a global flag |
| `stat_delta` | Modify a player stat (HP / hunger / thirst / stamina / etc.) |
| `grant_script` | Unlock a Script for the player to use (discovery progression) |
| `catalog_unlock` | Mark a species / prop as cataloged in the player's catalog |
| `add_journal_entry` | Add an entry to the journal |
| `fire_script` | Emit a named signal that other Signal-trigger scripts react to (chained execution) |
| `cutscene_trigger` | Play a cutscene |

`fire_script` graphs are validated for cycles at registry load time. A cycle (A.fire_script → B → A) is a hard error during load, not a runtime exception.

> **TO DEFINE:** Exact `params` schema for each effect kind. Will be defined per-kind during implementation as authoring surfaces concrete needs.

---

## Caps on Scripts (CONCEPT DECIDED — full list TO DEFINE)

The same capability pattern used on PropDefs applies to Scripts. A Script can carry one or more capability resources that govern where it appears in the UI and how the system treats it.

Examples of likely Script caps:

| Cap | Meaning |
|-----|---------|
| `CraftableCap` | Script appears in Interact > Craft tab |
| `BuildableCap` | Script appears in Interact > Build tab |
| `ActionableCap` | Script appears in Interact > Actions tab (context-sensitive) |
| `CombatScriptCap` | Script is part of the combat pipeline (attack, defend, ability) |

Each cap may carry config — sort order, category, preview mesh override, eligibility hint, etc.

> **TO DEFINE:**
> * Final list of Script caps for Chapter 1 launch.
> * Field schema per cap.
> * Whether caps live in `scripts/data/capabilities/` alongside PropDef caps, or in a separate `scripts/scripts/capabilities/` namespace.

---

## Tags vs Caps (DECIDED — design heuristic)

| Question | Use |
|----------|-----|
| Need to **read values** from this attribute (radius, intensity, count)? | **Cap** |
| Just need to **filter** on yes/no? | **Tag** |
| Doubt? | Start with Tag (cheap), promote to Cap when params emerge |

Both apply to PropDefs and to Scripts. Both can be referenced in `Input.ref`, `Output.ref`, and `ProximityTrigger.target`. The runtime resolves the lookup uniformly.

---

## Vicinity (DECIDED)

* **Definition:** same sub-hex OR one adjacent sub-hex.
* Used uniformly for:
  * Input source (inventory + containers in vicinity)
  * Output ground drop fallback
  * Container space check (`must_have_space` includes containers in vicinity)
  * Possibly Proximity trigger default range (alternate values: same_hex, longer ranges per script)

---

## UI model (DECIDED — names locked)

```
[Joystick]                                    [Status]  [Interact]  [Action]  [Log]
                                                              │
                                                  ┌───────────┼───────────┐
                                                  │           │           │
                                              [Actions]   [Craft]    [Build]   (more tabs may emerge)
```

* **Joystick** — movement only.
* **Status** — stats, discoveries, body schema (equipped wearables), inventory grid.
* **Interact** (renamed from Gear) — context-sensitive panel with tabs:
  * **Actions** — scripts contextual to the current location (Light Campfire when near one; etc.). Filter: `ActionableCap` + conditions met.
  * **Craft** — scripts that produce items into inventory. Filter: `CraftableCap` + conditions met.
  * **Build** — scripts that place props into the world (uses placement UI at commit). Filter: `BuildableCap` + conditions met.
* **Action** — single context-sensitive button (see Combat below).
* **Log** (renamed from existing log panel) — journal + catalog.

Interact panel tabs filter the visible Script list by cap + condition eligibility, recomputed when the player enters/exits proximity, picks up/drops items, etc.

---

## Combat (DECIDED — Action button + auto-defend setting)

A single permanent **Action** button sits next to the panel buttons. It is **context-sensitive** by visual state:

| State | Color | Meaning |
|-------|-------|---------|
| Disabled | Grey | No applicable context |
| Gather ready | Green / earth | Tree/rock/etc. in proximity + matching tool |
| Attack ready | Amber | Hostile or selected target in range + weapon |
| Defend now | Pulsing red | Enemy is telegraphing an attack |

**Tap-to-target** is the universal selection mechanism: tap on a prop in the world to select it. Hostile fauna auto-selects when it telegraphs an attack on the player.

**Settings:**

* `auto_gather` (default ON): when ON, chop / mine / pluck auto-fire on proximity if the matching tool is held. When OFF, the Action button shows green and the player must tap to fire.
* `auto_defend` (default ON): when ON, the player auto-blocks during enemy telegraph. When OFF, the player must tap the (red, pulsing) Action button during the telegraph window.

Player can always tap an animal (hostile or not) to select and attack — the Action button shows amber when a valid attack target is selected.

---

## Cleanup scope (DECIDED)

Delete all placeholder Chapter 1 content so the real Chapter 1 can be authored against the new engine. Exact paths:

```
data/props/*.tres          # all 30+ PropDefs
data/recipes/*.tres        # 26 Recipes
data/events/*.tres         # 12 GameEvents
data/journal/*.tres        # journal entries (if present)
data/cutscenes/*.tres      # cutscenes (if present)
```

Also remove the legacy hardcoded crafting dict:

```
scripts/crafting/crafting_system.gd : RECIPE_CONFIG constant + all branches reading it
```

Engine code, autoloads, biome / hex grid data, and tests **stay**. Player and HUD stay (the world will simply be empty until Chapter 1 is reauthored next delivery).

> Effect on running game: opening the project after this delivery yields a player on a hex grid with a default 30×40 inventory and zero items, recipes, events, or journal content. That is intentional — it's the empty stage we will populate with real Chapter 1 next.

---

## Test strategy (DECIDED)

| Test layer | Expectation after this delivery |
|------------|---------------------------------|
| **Unit tests** | **Must be idempotent.** Each test creates its own mock PropDef / Script fixtures in memory (no dependency on `data/`). Tests that currently rely on real PropRegistry IDs (P00010, P00201, etc.) get refactored to use mocks. |
| **Behavior BDDs** | **Must be self-contained.** Each scenario authors its own fixture data in setup steps and cleans up in teardown. These survive the cleanup. |
| **Chapter-1-specific BDDs** | **Allowed to break.** They test Chapter 1 content that's about to be deleted. These will be re-authored alongside the real Chapter 1 content next delivery. |

> **TO DEFINE during implementation:** Exactly which tests fall into each bucket. Audit pass at the start of execution will categorize each file.

---

## Phased implementation plan

Each phase is a logical commit (or small group of commits) on the `delivery-006k` branch. Order matters — earlier phases unblock later.

| Phase | Description |
|-------|-------------|
| **A** | Add new resource classes: Trigger subclasses (Proximity / Action / Time / Signal / State), refined Input / Output / Condition / Effect schemas, Script caps stub (CraftableCap, BuildableCap, ActionableCap, CombatScriptCap). Compile-clean, no behavior change. |
| **B** | ScriptBase refactor: replace `actions` array with typed `trigger`. Rename `duration` → `required_time`. Migrate Recipe / GameEvent to use the new fields. Engine refuses to load any Script that still uses old fields. |
| **C** | Script execution runtime: ScriptRuntime class implementing the atomic flow (validate-start → placement-UI → timer → revalidate → spawn → consume → effects). Replaces parts of the existing RecipeRuntime; removes overlap with the legacy CraftingSystem branches. |
| **D** | Registry static analysis: cycle detection for `fire_script` graphs. Hard error with clear path during load. |
| **E** | UI rewire: rename Gear → Interact panel; expose Actions / Craft / Build tabs filtered by Script caps + conditions. Drop the legacy CraftingSystem dict path. |
| **F** | Action button (context-sensitive, color-coded states). Tap-to-target wired into existing AutoInteractionSystem. Settings entries for `auto_gather` and `auto_defend`. |
| **G** | Content cleanup: delete `data/props/`, `data/recipes/`, `data/events/`, `data/journal/`, `data/cutscenes/` `.tres` files. |
| **H** | Test cleanup: refactor unit tests to use mock fixtures; refactor behavior BDDs to self-author fixtures; mark / delete Chapter-1-specific BDDs. |
| **I** | Documentation: update `.aid/knowledge/` (game-mechanics.md, contracts/recipe.md, contracts/script.md, etc.) to reflect the new model. |

Phases can run in series; some (G + H) can be done together. Phase A blocks B, B blocks C, C blocks D, A blocks E, E blocks F. G can run any time after B. H runs throughout.

---

## Open questions (TO DEFINE)

This list is the punch-list of decisions to close as we implement. Each item gets a small focused conversation, then a commit that resolves it.

1. **Caps on Scripts** — final list, field schemas, namespace location.
2. **Effect params schemas** — concrete params per effect kind.
3. **Condition taxonomy** — full list beyond `must_stay_close` / `must_have_space`. Likely reuses existing `Predicate` kinds with renames; new kinds added as needed.
4. **`grant_script` semantics** — does it just add to a "known scripts" set? Does it persist in save? Does it fire a notification?
5. **`catalog_unlock` semantics** — already partly implemented in the Catalog autoload. How exactly do effects route through it?
6. **`add_journal_entry` semantics** — JournalEntry resources exist but the unlock flow isn't formalized.
7. **`modify_world_state` params shape** — generic `{target_path, field, op, value}`? Or fixed sub-types?
8. **DecayCap or equivalent** — where does the "prop lifetime after creation" metadata live? On PropDef as a dedicated cap?
9. **Save format version bump** — do we need to invalidate existing saves (likely yes, given content wipe)?
10. **Backward compat policy** — confirm: zero migration, zero compat shims. Saves from main pre-006k are dead.
11. **Editor updates** — recipe_editor / event_editor panels need to gain UI for new Trigger / Caps fields.

---

## Glossary (for new contributors and future me)

| Term | Meaning |
|------|---------|
| **Script** | Any executable game logic unit. Recipe and GameEvent are both Scripts (subclasses of ScriptBase). |
| **Trigger** | What makes a Script eligible to fire. One of 5 kinds: Proximity, Action, Time, Signal, State. |
| **Input** | A prop the Script needs (held in inventory or vicinity container). Optionally consumed at commit. |
| **Output** | A prop the Script produces. Destination decided by prop's PlaceableCap presence. |
| **Condition** | Predicate that must be true at start AND at commit. Failure → abort. |
| **Effect** | Non-prop side effect (stat delta, world mutation, signal emission, cutscene, etc.) fired at commit. All-or-nothing. |
| **required_time** | Seconds from trigger to commit. 0 = instant. |
| **Vicinity** | Same sub-hex or one adjacent sub-hex. |
| **Cap** | Capability resource attached to a PropDef OR a Script. Carries structured config. |
| **Tag** | Free-form StringName label. No data. Used for filtering only. |
| **PropDef** | Definition resource for any thing in the world (item, structure, creature, resource). Composed of caps + tags. |
| **Action button** | The single permanent context-sensitive button next to Status/Interact/Log. |
| **Interact panel** | Renamed from "Gear". Three tabs: Actions / Craft / Build (more may come). Filtered by Script caps + conditions. |

---

## Out of scope for 006k (deferred to later deliveries)

* Authoring the real Chapter 1 content (props, scripts, events, journal, cutscenes).
* Aesthetic hooks system (sound, animation, particles, screen flash, haptic).
* Professional UI pass (assets, design system, animations, transitions).
* Multi-language support.
* Save schema beyond what the engine refactor requires.
* Editor visual upgrades beyond the minimum needed to author the new fields.

---

*End of DETAIL.md — open questions stay open until we close them together, one at a time, during implementation.*
