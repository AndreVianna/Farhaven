# delivery-006d: Engine Stabilization — Verification, Tests, Contracts

**Status:** Planning (WIP — populate as delivery-006c progresses)
**Created:** 2026-04-11
**Depends on:** delivery-006c (all engine features landed)
**Cumulative state:** Engine phase verified "redonda." Contracts documented. Test coverage audited. Deferred bugs swept. Ready for content work (delivery-007).

> **Why this delivery exists:**
> delivery-006c closes the Engine phase. Before starting content (delivery-007 — Chapter 1 narrative),
> the engine needs to be verified as "round" — every system promises what it claims to promise, tests
> cover the paths content will actually exercise, and known gaps/bugs are closed. This is the "breathe
> out and look at the whole thing" delivery.

## Tasks (preliminary — populated during and after 006c)

| # | Name | Type | Est. hours | Status |
|---|------|------|-----------|--------|
| 083 | Engine Contracts Documentation | DOCS | 6 | PLANNED |
| 084 | Unit test coverage audit + gap fill | TEST | 8 | PLANNED |
| 085 | BDD scenarios for full engine flows | TEST | 6 | PLANNED |
| 086 | Test maps for edge cases and integration | CONTENT (test fixtures) | 4 | PLANNED |
| 087 | Manual play-test sweep (Andre-time) | VERIFY | 6 | PLANNED |
| 088 | Deferred bug backlog — sweep and fix | FIX | ??? | PLANNED (scope TBD) |

**Estimated total: ~30h + 088 (open)**

## Task Details

### task-083: Engine Contracts Documentation

**What:** For every major engine system, produce a short contract doc stating what that system *promises* to content code. Not an API reference — a promise list.

**Systems to cover (preliminary):**
- PropDef + capabilities (Endurance / Movement / Combat / Behavior / Spawnable / Catalogable / Portable / Container / Placeable)
- Recipe system (RecipeRegistry, RecipeRuntime, PredicateEvaluator, WorldContext)
- Event system (GameEvent, DiscoveryWatcher, event-driven unlocks)
- Scanner / Catalog (proximity detection, catalog grouping, ANOMALY_BUCKET)
- Inventory (slot-unit capacity, size-based fit, tool slots)
- Fauna (FaunaManager reads PropDef caps, spawn rules)
- Day/Night cycle (phases, lighting)
- CutsceneManager (created in 006c)
- JournalEntry / Journal system (created in 006c)

**Output:** `.aid/knowledge/engine-contracts.md` or per-system files under `.aid/knowledge/contracts/`. Format TBD — could be Markdown tables or prose, whichever is more honest.

**Why it matters:** Content delivery (007) will write recipes/events/journal entries against these contracts. If the contracts are implicit, content work will discover engine gaps mid-writing. If explicit, gaps surface early.

---

### task-084: Unit test coverage audit + gap fill

**What:**
- Run GdUnit with coverage reporting (or manual inspection of which files have tests)
- Identify untested / under-tested engine files
- Prioritize by risk (autoloads > capability classes > helpers)
- Write unit tests for the gaps

**Deliverable:** GdUnit suite passing at higher coverage than delivery-006c merge.

**Open:** does Godot/GdUnit have a coverage tool we can run? If not, this is manual inspection based on `tests/unit/` vs `scripts/` tree.

---

### task-085: BDD scenarios for full engine flows

**What:** Add Gherkin `.feature` files covering end-to-end flows content will depend on:
- Player approaches fauna → fauna reacts (proximity + behavior)
- Player crafts recipe using container-scope ingredients (fireplace stash)
- Recipe unlock via event → journal entry appears → catalog updates
- Scanner detects unknown prop → encountered → cataloged → anomaly bucket filter works
- Inventory slot-unit overflow → rejection + inventory_full signal
- Day transition → lighting + fauna cycle changes + survival effects

**Deliverable:** New feature files in `tests/features/` + step implementations. Full BDD suite passing.

---

### task-086: Test maps for edge cases and integration

**What:** Create or extend hand-designed test maps that exercise engine integration:
- Map with all capability types on a single tile
- Map with nested containers (fireplace with fuel, chest with tools)
- Map with diverse fauna for behavior testing
- Map with full Chapter 1 milestone progression path (for smoke-testing narrative flow when delivery-007 starts)

**Deliverable:** `.json` maps in `data/maps/test/` or equivalent.

---

### task-087: Manual play-test sweep (Andre-time)

**What:** Andre plays through the engine with intention. Not task-checking — just playing, noting what feels wrong, what breaks, what's missing. Lola watches for reproducible bugs and captures them to task-088.

**Session format:** Probably 2-3 sessions of ~1-2h each over multiple days. Not single marathon.

**Deliverable:** A list of findings (UI bugs, physics edge cases, unexpected interactions, missing feedback, etc.).

---

### task-088: Deferred bug backlog — sweep and fix

**What:** Bugs and gaps Andre noted during delivery-006c review but deferred until engine close. Plus anything surfaced by task-087.

**Known entries (to populate):**
- [Andre to add — the "bugs I saw yesterday" from 2026-04-10]
- [Populated during 006c if new issues surface]
- [Populated by task-087]

**Deliverable:** All known engine bugs fixed or explicitly deferred with written reason.

---

## Exit criteria (how we know 006d is done)

- [ ] Engine contracts doc exists and is reviewed
- [ ] Unit tests cover critical paths (subjective — Andre accepts coverage level)
- [ ] BDD suite covers the flows listed in task-085
- [ ] Test maps exist for integration scenarios
- [ ] At least one full play-test sweep completed
- [ ] Bug backlog reduced to zero or explicitly deferred items
- [ ] Andre says "engine tá redonda"

Last item is the real gate. The checklist is the form; his judgment is the call.

---

## Notes

- This delivery is deliberately loose. Tasks will mutate as 006c progresses and reveals what "engine redonda" actually means in practice.
- task-088 scope is unknown until the backlog is populated. If Andre's deferred list is large, we may need to split 006d into 006d-stabilize and 006d-test.
- delivery-007 (content) cannot begin until this delivery exits.
