# delivery-006d: Engine Stabilization — Verification, Tests, Contracts

**Status:** Planning (tasks 083-085 detailed 2026-04-11, 086-088 still preliminary)
**Created:** 2026-04-11
**Depends on:** delivery-006c (merged to main — engine features landed)
**Cumulative state:** Engine v1.0 verified "redonda." Contracts documented with reuse in mind.
Test coverage audited and gap-filled. BDD suite covers every end-to-end flow content will
depend on. Deferred bugs swept. Ready for content work (delivery-007).

> **Why this delivery exists:**
> delivery-006c closed the Engine phase. Before starting content (delivery-007 — Chapter 1
> narrative), the engine needs to be verified as "round" — every system promises what it claims
> to promise, tests cover the paths content will actually exercise, and known gaps/bugs are
> closed. This is the "breathe out and look at the whole thing" delivery.
>
> **Engine v1.0 reuse ambition:** The contracts produced here are intended to support not just
> Farhaven, but a second game built on the same engine. Write them thinking about generality,
> not just the current game. Andre has sketched a second game (top-down strategy, Civ/Catan-like)
> as a future stress test — the contracts should give us a clean diff between "core engine" and
> "genre-specific extensions" when that day comes.

## Engine inventory (for reference)

**Autoloads (12):** PropRegistry, HexGrid, DayNightCycle, LightingManager, RecipeRegistry,
EventRegistry, DiscoveryWatcher, RecipeRuntime, Journal, JournalEntryRegistry, CutsceneManager,
SaveManager.

**Capability classes (12):** behavior_cap, catalogable_cap, combat_cap, container_cap,
endurance_cap, light_cap, movable_cap, movement_cap, placeable_cap, portable_cap, spawnable_cap,
station_cap.

**Data classes:** prop_def, gear (base), cutscene_def, journal_entry, recipe_input,
recipe_output, recipe_effect, recipe_condition, game_event, biome_data, hex_tile, predicate.

**Key systems:** auto_interaction, building, crafting, fauna, hex_grid (map_loader + hex_math),
inventory, lighting, player, rendering, save, scanner, survival.

**Test baseline (pre-006d):** 79 unit test files, 24 BDD feature files, ~1349 GdUnit cases with
13 pre-existing failures, ~2112 JS assertions, 38 round-trip tests, 117 BDD scenarios (98 passing,
19 pending due to data_validation_steps.gd parse error).

---

## Tasks

| # | Name | Type | Est. hours | Status |
|---|------|------|-----------|--------|
| 083 | Engine Contracts Documentation | DOCS | 12 | PLANNED |
| 084 | Unit test coverage audit + gap fill + fix pre-existing failures | TEST | 16 | PLANNED |
| 085 | BDD scenarios for full engine flows + fix data_validation parse error | TEST | 14 | PLANNED |
| 086 | Test maps for edge cases and integration | CONTENT (fixtures) | 4 | PLANNED (preliminary) |
| 087 | Manual play-test sweep (Andre-time) | VERIFY | 6 | PLANNED (preliminary) |
| 088 | Deferred bug backlog — sweep and fix | FIX | TBD | PLANNED (Andre to populate) |

**Estimated total: ~52h + 086/087/088**

---

## task-083: Engine Contracts Documentation

**Purpose:** Produce explicit, reviewable contracts for every engine system. Content authors
(and the hypothetical second-game authors) should be able to read these contracts and know
exactly what the engine promises and what it requires, without reading source code.

**Not an API reference.** Not a tutorial. A promise list: "if you give me X, I guarantee Y."
And a requirement list: "to use me, you must provide Z in the shape W."

### Output format

- **Index file:** `.aid/knowledge/engine-contracts.md` — one-page overview listing every system,
  one-line summary, and link to its contract file. Sorted by layer (data → autoloads → systems → UI).
- **Per-system files:** `.aid/knowledge/contracts/<system>.md` — one file per system.

### Contract file template (every file must have these sections)

```markdown
# <System name>

**Source:** `<path/to/main/file.gd>`
**Category:** core | genre-specific | engine-ui
**Layer:** data | autoload | system | ui
**Depends on:** <other contracts this one requires>

## What this system is

<One paragraph. What it exists to do. Plain language, no code.>

## Promises to content

<Bulleted list. What callers can rely on. Examples:
- "Journal.add_entry(id) is idempotent — calling twice with the same id emits the signal only once"
- "Recipe.resolve() always consumes inputs atomically — partial consumption rolls back">

## Requirements from content

<What callers must provide. .tres shape, ID prefixes, field conventions, setup order.
Example: "JournalEntry .tres files must use J-prefix ids, live in data/journal/, and extend
Gear. The `body` field is the full text; `long_description` is the teaser.">

## Extension points

<Where to hook in without modifying the system. Signals to connect to, sub-resources to provide,
injection seams.>

## Genre-specific notes

<What in this contract is specific to Farhaven's survival/exploration genre, and what would
transfer to a different game (e.g. Civ/Catan-like). If the system is fully genre-agnostic, say so.>

## Known limitations and TODOs

<Links to future tickets, known gaps, deferred features. E.g.:
- "Combat runtime not yet implemented — attacks/defenses are placeholder Arrays (see delivery-006d task-088)"
- "No support for multi-player / multi-faction ownership — Player is singular (future engine v2)"
- "Turn management — the system assumes real-time ticks via _process; turn-based support would
   require a TurnManager layer (future engine v2)">
```

### Systems to cover (one contract each)

**Autoloads (12):**
- PropRegistry
- HexGrid (+ HexMath reference)
- DayNightCycle
- LightingManager
- RecipeRegistry (+ Recipe / RecipeInput / RecipeOutput / RecipeEffect / RecipeCondition / Predicate)
- EventRegistry (+ GameEvent)
- DiscoveryWatcher
- RecipeRuntime (+ WorldContext, PredicateEvaluator)
- Journal
- JournalEntryRegistry
- CutsceneManager (+ CutsceneDef)
- SaveManager

**Data / capability layer:**
- Gear (base class — what every Gear-derived resource inherits)
- PropDef (how caps compose)
- 12 capability contracts: Behavior, Catalogable, Combat, Container, Endurance, Light, Movable,
  Movement, Placeable, Portable, Spawnable, Station

**Systems (not autoload, but world-level):**
- AutoInteractionSystem
- BuildingSystem
- FaunaManager
- SurvivalSystem
- Scanner (ScannerSystem + Catalog)
- Inventory (not an autoload — owned by Player)
- MapLoader

**UI layer (contracts for what UI panels depend on):**
- JournalPanel
- StatusCombinedPanel
- InventoryPanel (reference existing)
- CatalogPanel (reference existing)
- Hud

**Total: ~32 contract files.** That is the meat of this task.

### Sub-tasks for task-083

- **083a** — System inventory + template validation (1h). Confirm the system list is complete,
  write one sample contract (PropDef is good) as the template, iterate with Andre if shape needs
  adjustment. **Blocks 083b–083d.**
- **083b** — Autoload contracts (4h). 12 files, one per autoload. Most systems-y, most important.
- **083c** — Data / capability contracts (3h). 14 files (Gear + PropDef + 12 caps).
- **083d** — System + UI contracts (3h). ~10 files covering non-autoload systems and UI panels.
- **083e** — Index + cross-reference pass + review (1h). Build the index file, verify every
  contract links to its dependencies, cross-check that no system was missed.

### Deliverables
- `.aid/knowledge/engine-contracts.md` (index)
- `.aid/knowledge/contracts/*.md` (~32 files)

### Acceptance criteria
- Every autoload from `project.godot` has a contract
- Every capability class under `scripts/data/capabilities/` has a contract
- Every contract has all 6 template sections (missing sections explicitly mark "none" or "TBD")
- Cross-references resolve (if Contract A mentions Contract B, Contract B exists and mentions A back where relevant)
- Andre reviews and accepts the contracts before 083 closes

### Pitfalls
- **Don't copy-paste the source code into the contract.** Prose, not code dumps.
- **Don't document implementation details.** "PropRegistry scans res://data/props/ on _ready" is OK;
  "PropRegistry uses a DirAccess iterator with a while-loop" is not.
- **Do note generalization vs genre-specificity.** The "Genre-specific notes" section is load-bearing
  for the engine v2 reuse story.

---

## task-084: Unit test coverage audit + gap fill + fix pre-existing failures

**Purpose:** Ensure critical engine paths have real unit test coverage. Close existing gaps.
Fix the 13 pre-existing failures that have been accumulating across deliveries.

### Methodology

1. **Inventory pass:** For every `scripts/**/*.gd` file, check if a matching `tests/unit/test_*.gd`
   exists. Build a coverage matrix (file → tested? → confidence level).
2. **Priority-rank files** by risk:
   - **High:** Autoloads, capability classes, data classes (prop_def, recipe_input, etc.)
   - **Medium:** Helpers referenced by high-risk code, UI panels with state
   - **Low:** Pure static utilities, debug/dev-only code
3. **Fix pre-existing failures:** Start by understanding WHY each failing test fails. Fix or
   explicitly defer with documented reason.
4. **Gap-fill high-risk first**, then medium, then stop. Don't chase 100% — chase meaningful.

### Sub-tasks for task-084

- **084a** — Coverage inventory (2h). Produce `.aid/knowledge/unit-test-audit.md` with the
  coverage matrix. Each row: `file_path | has_test | test_file | coverage_confidence | notes`.
  **Blocks 084c–084d.** (Not 084b — that can start in parallel.)
- **084b** — Fix pre-existing failures (4h). Investigate and fix:
  - `tests/unit/test_catalog.gd` — mock/spy related failures
  - `tests/unit/test_structure_renderer.gd`
  - `tests/unit/test_building_placement.gd`
  - `tests/unit/test_building_system.gd`
  - Plus any others 084a surfaces.
  For each: root-cause in commit message, fix the test OR the underlying system bug,
  OR mark explicitly deferred with reason.
- **084c** — Gap-fill high-risk (6h). Write tests for all untested autoloads and data classes.
  Each new test file should cover:
  - Construction / defaults
  - Round-trip serialization (for data classes)
  - Public API contract (happy path + error paths)
  - At least one signal emission verification (for autoloads)
- **084d** — Gap-fill medium-risk (4h). UI panels and helpers not covered by 084c.

### Deliverables
- `.aid/knowledge/unit-test-audit.md` — coverage matrix + deferred items
- New test files filling identified gaps
- All 13 pre-existing failures either fixed or documented as explicit deferrals

### Acceptance criteria
- Every autoload has at least smoke-tests
- Every capability class has round-trip + behavior tests
- Zero un-explained failures in the GdUnit suite (deferred failures carry a written reason
  and a `@deferred` marker or similar)
- Total GdUnit pass rate ≥ 99%
- Coverage audit file reviewed

### Pitfalls
- **Don't write tests that test the test.** Test the real code, not your mock.
- **Don't chase coverage percentage.** Chase risk. A trivially-boilerplate helper doesn't need
  a test if its only logic is `return value + 1`.
- **Fix root causes.** If a test is flaky, find why. If a mock is wrong, rewrite the mock.
  Don't just `@flaky` the test away.
- **Don't rewrite working tests** just because their style doesn't match yours.

---

## task-085: BDD scenarios for full engine flows + fix data_validation parse error

**Purpose:** Cover every end-to-end flow that content authoring (delivery-007) will depend on.
Also fix the parse error in `data_validation_steps.gd` that currently blocks 19 scenarios.

### Flows to cover

Each flow below is a mandatory feature file. Feel free to split into multiple scenarios per
feature where it improves clarity.

**Category A — Recipe & event plumbing**

1. **recipe_lifecycle.feature**
   - Recipe start with missing inputs → rejection, no consumption
   - Recipe start with sufficient inputs → inputs consumed atomically, pending queue populated
   - Duration-based recipe → finishes after elapsed time
   - Sustain condition failure mid-recipe → cancelled, inputs returned
   - Multiple simultaneous recipes → each resolves independently
   - Recipe with container-scope input (fireplace fuel pattern) — `ctx.container` priority
     over `ctx.station` and `ctx.tile`
   - Recipe with tag input (&BURNABLE) — resolves via PropRegistry tag scan

2. **event_flow.feature**
   - GameEvent.try_fire with failing precondition → does not emit
   - GameEvent.try_fire with met precondition → emits event_fired, increments count
   - One-shot GameEvent (max_count=1) → second fire rejected
   - Multi-count GameEvent → fires up to max_count
   - Event effect `grant_recipe` → RecipeRegistry unlocks recipe
   - Event effect `unlock_journal_entry` → Journal.add_entry called
   - Event count persists through save/load

3. **discovery_chain.feature**
   - Catalog entry discovered → scanner_system emits → DiscoveryWatcher processes → event fires
     → effect unlocks content → cross-system end-to-end

**Category B — PropDef + capabilities integration**

4. **multi_capability_prop.feature**
   - A PropDef with Endurance + Movement + Combat + Behavior + Spawnable (live fauna like P00108)
     loads correctly, all caps readable, no interference between caps
   - A PropDef with Container + Portable + Placeable (storage chest) loads and serializes

5. **capability_extension_points.feature**
   - BehaviorCap.reactions GameEvents fire on triggers
   - CombatCap.attacks/defenses Array of GameEvents is iterable (placeholder runtime OK)
   - MovementCap.modes Dictionary keyed by Mode enum with [normal, max] values round-trips

**Category C — Scanner / Catalog**

6. **scanner_lifecycle.feature** (extend existing scanner.feature if appropriate)
   - Unknown prop → ENCOUNTERED → CATALOGED state transitions
   - Anomaly override: show_as_anomaly PropDef → categorized under ANOMALY_BUCKET
   - Catalog count signals fire on each transition
   - Scanner interrupts on move out of range

**Category D — Inventory + tool slots**

7. **inventory_integration.feature** (extend existing inventory.feature)
   - Slot-unit capacity enforced (adding > capacity → partial add + inventory_full signal)
   - Tool slots separate from regular slots (cannot put tool in regular slot, vice versa)
   - Save/load preserves both regular slots and tool slots
   - Container expansion increases capacity

**Category E — Day/Night + Lighting + Survival**

8. **day_night_chain.feature** (extend existing day_night.feature)
   - Day transition triggers LightingManager phase change
   - Dusk triggers local lights on (campfire, torch, etc.)
   - Dawn triggers local lights off + fauna activity cycle change
   - Survival pressure increases at night (hunger/thirst rates if applicable)

**Category F — Narrative plumbing** (delivery-006c already added narrative.feature with 11
scenarios — verify they're still passing, don't duplicate)

9. **(Verify narrative.feature from delivery-006c still passes as-is)**

**Category G — Save/load full round trip**

10. **save_load_integration.feature** (extend existing save_load.feature)
    - Full game state save → new session → load → every autoload restored
    - Journal unlocked entries preserved
    - Catalog discovery state preserved
    - Recipe pending queue preserved (or explicitly cleared with documented reason)
    - Event counts preserved
    - Inventory + tool slots preserved

### Sub-tasks for task-085

- **085a** — **Fix `data_validation_steps.gd` parse error** (2h). This unblocks 19 pending
  scenarios. Must be first, because knowing what's actually failing post-fix changes the rest
  of the audit. **Blocks everything else in 085.**
- **085b** — Category A (recipes & events) (3h)
- **085c** — Category B (multi-cap props) (2h)
- **085d** — Category C (scanner) + Category D (inventory) (2h)
- **085e** — Category E (day/night) + Category F (verify narrative) (2h)
- **085f** — Category G (save/load full) + final suite audit (3h)

### Deliverables
- `tests/features/*.feature` files (new + extended)
- `tests/steps/*_steps.gd` files (new + extended)
- `data_validation_steps.gd` parse error resolved
- BDD suite at **≥ 99% pass rate** (target: 0 pending, 0 failures; deferred scenarios
  carry explicit `@deferred` tag with reason)

### Acceptance criteria
- Every flow listed above has at least one scenario
- No scenario uses shallow mocks where real code is reachable (the 006c narrative BDD set a
  precedent — follow it)
- Every scenario exercises a boundary between at least 2 systems (that's what makes it BDD
  and not a unit test)
- Full BDD suite: passing scenarios go from 98 → ≥ 115 (current 117 total minus up to 2
  that might be legitimately `@deferred`)
- Suite runs in < 2 minutes total (if slower, profile first)

### Pitfalls
- **Don't write unit tests dressed in Gherkin.** If a scenario only touches one system, it
  doesn't belong in BDD.
- **Don't copy-paste steps.** Reuse common_steps.gd and extend it. If two feature files need
  the same setup, extract to a shared step file.
- **Don't await without timeout.** Every `await` on a signal must have a fallback so hangs
  become failures, not infinite runs.
- **The Gherkin CLI runs inside `SceneTree._init`** — `is_inside_tree()` may return false for
  nodes parented to `tree.root`. Worked around in narrative_steps.gd by walking parent chain
  manually. Same workaround may be needed for new flows — flag if encountered.

---

## task-086: Test maps for edge cases and integration

**What:** Create or extend hand-designed test maps that exercise engine integration:
- Map with all capability types on a single tile (stress test for cap composition)
- Map with nested containers (fireplace with fuel, chest with tools)
- Map with diverse fauna for behavior testing
- Map with full Chapter 1 milestone progression path (for smoke-testing narrative flow
  when delivery-007 starts)

**Deliverable:** JSON maps in `data/maps/test/` or equivalent.

*Note: preliminary. Detail after 083–085 land, because the test maps should exercise the
actual contracts documented in 083 and the flows tested in 085.*

---

## task-087: Manual play-test sweep (Andre-time)

**What:** Andre plays through the engine with intention. Not task-checking — just playing,
noting what feels wrong, what breaks, what's missing. Lola watches for reproducible bugs
and captures them to task-088.

**Session format:** Probably 2-3 sessions of ~1-2h each over multiple days. Not single marathon.

**Deliverable:** A list of findings (UI bugs, physics edge cases, unexpected interactions,
missing feedback, etc.).

---

## task-088: Deferred bug backlog — sweep and fix

**What:** Bugs and gaps deferred until engine close. Plus anything surfaced by 084/085/087.

**Known entries (populated 2026-04-11, more to come from Andre + manual testing):**

From 2026-04-10 review (Andre saw bugs he deferred):
- [Andre to add — the "bugs I saw yesterday" from 2026-04-10]

From 006c Wave 1 agent reports:
- `RecipeRuntime._apply_effect` uses `PropRegistry` as a global identifier — this prevents
  BDD scenarios from driving real production code. Should be refactored to use
  `_get_autoload(&"PropRegistry")` lazy lookup. Discovered by task-081 BDD agent.
- Gherkin CLI runs inside `SceneTree._init`, so `is_inside_tree()` returns false for nodes
  parented to `tree.root`. Either fix the runner to await a frame, or document the quirk
  so future BDD authors know to walk the parent chain manually. Discovered by task-081 BDD agent.

From 2026-04-11 Copilot PR #14 review:
- None remaining — all round 1-4 comments resolved. (One false-positive from Copilot was
  correctly rejected — see PR #14 reply thread for `status_discoveries_section.gd:68`.)

Future engine v2 scope (**NOT for 006d** — track separately):
- Turn manager (for Civ/Catan-style turn-based games)
- Multi-player / multi-faction ownership (Player is currently singular)
- Strategic AI (BehaviorCap is fauna-AI only, not strategic planning)
- Combat runtime (attacks/defenses are empty Array[GameEvent] placeholders — damage_type
  must respect EnduranceCap vuln/resist/immune when implemented)
- Tool slot mechanic redesign (current slot-by-type constraint may not be the right shape)

**Deliverable:** All known engine bugs from 006d scope fixed or explicitly deferred with
written reason. Engine v2 items moved to a separate `ENGINE-BACKLOG.md` (to be created when
we start thinking about v2).

---

## Exit criteria (how we know 006d is done)

- [ ] Engine contracts doc exists and is reviewed by Andre
- [ ] Unit tests cover critical paths; 0 unexplained failures
- [ ] BDD suite covers the flows listed in task-085; pass rate ≥ 99%
- [ ] Test maps exist for integration scenarios
- [ ] At least one full play-test sweep completed
- [ ] Bug backlog reduced to zero or explicitly deferred items
- [ ] **Andre says "engine tá redonda"**

Last item is the real gate. The checklist is the form; his judgment is the call.

---

## Notes

- Tasks 086–088 are intentionally less detailed — their shape depends on what 083–085 surface.
  After those three land, we come back and detail these.
- task-088 scope is unknown until Andre populates the backlog. If his deferred list is large,
  we may need to split 006d into 006d-stabilize and 006d-test.
- delivery-007 (content) cannot begin until this delivery exits.
- Engine v2 / second-game scope is explicitly NOT in 006d. It's in a separate future backlog.
