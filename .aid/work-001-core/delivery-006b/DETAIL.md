# delivery-006b: Editor Sync — All Pages for New Schema

**Status:** In Progress
**Created:** 2026-04-09
**Started:** 2026-04-10
**Depends on:** delivery-006a (merged to main)
**Cumulative state:** Editor fully supports Gear hierarchy, SSH placement, Events, slot-unit inventory.

## Tasks

| # | Name | Type | Est. hours | Status |
|---|------|------|-----------|--------|
| 066 | Prop page: Gear fields + slot-unit inventory + cleanup | UPDATE | 6 | DONE |
| 067 | Recipe page: time→duration, remove unlock_when, Gear fields | UPDATE | 4 | DONE |
| 068 | Event page (NEW): create/edit GameEvent .tres files | IMPLEMENT | 8 | DONE |
| 069 | Prop page: map tool filter by placeable (already done in PR fix) | DONE | 0 | DONE |
| 070 | ID namespace enforcement: prefix validation + auto-increment | UPDATE | 3 | DONE |
| 071 | Biome page review: ensure sync with current schema | REVIEW | 2 | DONE (no issues) |
| 072 | Round-trip tests for all pages with new schema | TEST | 4 | DONE (87 round-trips) |
| 073 | BDD scenarios covering delivery-006b changes | TEST | 4 | IN PROGRESS |

**Estimated total: ~31h**

## Task Details

### task-066: Prop page — Gear fields + slot-unit inventory + cleanup
**What changes:**
- Add Gear base fields to form: `short_description`, `long_description` (editable text areas)
- PortableCap: rename `weight` → `size` (float, unit: slots). Examples: berry=0.00001, rock=0.2, wood=2.0, stone=4.0, log=100.0
- Remove `max_stack` from form and serialization (replaced by slot math)
- Remove `tool_slot` from form (mechanic under review — defer to future delivery)
- Remove deprecated fields from form if still shown: `category` (StringName), `footprint` (top-level)
- Ensure `origin` dropdown reads/writes int correctly (already fixed for map tool)
- PlaceableCap: already pure marker (done in PR #12 fixes)
- Update PropDefModel: `weight` → `size` in portable, remove max_stack
- Update serialization: write `size` instead of `weight` in portable sub_resource
- Update .tres round-trip tests

### task-067: Recipe page — time→duration, remove unlock_when, Gear fields
**What changes:**
- Rename `time` field → `duration` in model, form, serialization, tests
- Remove `unlock_when` UI section entirely (discovery is event-driven via GameEvent)
- Remove unlock_when from model, validation, serialization
- Add ScriptBase fields if missing: `conditions`, `effects`, `actions` (may already exist)
- Add Gear base fields: `short_description`, `long_description`
- Ensure Recipe IDs enforce R prefix
- Update round-trip tests

### task-068: Event page (NEW)
**What to build:**
- New editor tab/page for GameEvent .tres files in `data/events/`
- Master-detail layout (same pattern as Prop/Recipe editors)
- Fields: id (E prefix), display_name, short_description, long_description
- ScriptBase fields: conditions, effects, actions, duration
- Event-specific: count (read-only, runtime), max_count (editable)
- Effect editor for `grant_recipe` effect type
- Create/edit/delete GameEvent resources
- File discovery for `data/events/*.tres`
- Round-trip serialization

### task-069: DONE (map tool filter)
Already fixed in delivery-006a PR #12 — map prop tool now filters by placeable + origin + category.

### task-070: ID namespace enforcement
**What changes:**
- Prop editor: enforce P prefix on new IDs, auto-suggest next available P-number
- Recipe editor: enforce R prefix on new IDs, auto-suggest next available R-number
- Event editor: enforce E prefix on new IDs, auto-suggest next available E-number
- Validation: reject IDs without correct prefix

### task-071: Biome page review
**What to check:**
- Biome .tres files reference P-prefixed prop IDs in spawn tables
- Editor reads/writes biome data correctly with current schema
- No stale field references

### task-072: Round-trip tests
**What to test:**
- All prop .tres files round-trip through editor without data loss
- All recipe .tres files round-trip (duration, no unlock_when)
- All event .tres files round-trip
- All biome .tres files round-trip
- Portable.size (not weight), no max_stack, no footprint in placeable

### task-073: BDD scenarios
**Feature files to add/update:**
- Editor prop validation scenarios (slot-unit sizes, ID prefixes)
- Editor recipe validation scenarios (duration, no unlock_when)
- Editor event CRUD scenarios
- Data validation: every portable prop has size > 0
- Data validation: no recipe has unlock_when
- Data validation: every event has E-prefixed ID

## Wave Plan

**Wave 1:** task-066 (Prop page) — largest, most impactful
**Wave 2:** task-067 (Recipe page) — depends on patterns from 066
**Wave 3:** task-068 (Event page) — new page, independent
**Wave 4:** task-070 + task-071 (ID namespace + Biome review) — smaller tasks, parallel
**Wave 5:** task-072 + task-073 (Tests + BDD) — verification layer

## Design Decisions

- **Slot units (approved 2026-04-06):** PortableCap.size (float) replaces weight. All items measured in universal Slot unit. max_stack removed.
- **PlaceableCap:** Pure marker, no fields (rotation_snap removed — rotation is per-placement).
- **Tool slot:** Deferred to future delivery (mechanic under review).
- **Fauna page:** Deferred — fauna config design not finalized yet (open question from planning).
- **SSH grid in editor:** Deferred — needs design decision on zoom behavior.
