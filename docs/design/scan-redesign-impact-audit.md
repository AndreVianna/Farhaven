# Scan Redesign — Impact Audit

Date: 2026-04-02

## Summary

The scan system redesign from press-and-hold to proximity-based auto-scan with a 3-state knowledge system (UNKNOWN → ENCOUNTERED → CATALOGED) impacts **every layer of the project**: requirements, 7 of 12 feature specs, 4 of 6 delivery details, and 6 existing code files. The most critical changes are in feature-003 (Scanner & Catalog — near-total SPEC rewrite), feature-002 (Player Movement — removal of scan hold input classification), REQUIREMENTS.md (F13 and AC11 contradict the redesign), and delivery-002 DETAIL.md (tasks 012-015 describe the old press-hold flow). The existing code already has a working `ScannerSystem` with `ScanState` machine, `scan_hold_*` signal handlers, and an `ElementIconRenderer` (already slated for PropRenderer replacement) — all of which need modification or removal. Fauna-related specs (feature-004, feature-010) need moderate updates to handle the new ENCOUNTERED state correctly. The redesign simplifies the MVP scope significantly (flora/mineral auto-scan on proximity, no complex scan puzzle mechanics) while deferring Trap and Sneak Scan to post-MVP deliveries.

## Impact by File

### CRITICAL (must change before coding)

---

- **`.aid/work-001-core/features/feature-003-scanner-catalog/SPEC.md`**
  - **Description** (line ~22): Still says "Players press and hold toward unknown elements" — must be rewritten to describe proximity auto-scan
  - **Acceptance Criteria**: "Press and hold toward unknown flora → scan progress bar" — must change to proximity-based
  - **Data Model — ScanState Enum** (line ~85-94): `IDLE, SCANNING, COMPLETE, REJECTED` — the entire state machine is obsolete. Proximity scan needs at most `IDLE` and `SCANNING` (player in range). `REJECTED` is meaningless without press-hold targeting. Replace with proximity-based states or remove entirely.
  - **Data Model — Knowledge States**: Currently binary (`_discovered: Dictionary[StringName, bool]`). Needs 3 states: UNKNOWN, ENCOUNTERED, CATALOGED. The `Catalog` class needs a new `_knowledge_state: Dictionary[StringName, KnowledgeState]` field.
  - **ScannerSystem Properties** (line ~129-138): `_scan_state`, `_scan_target_coords`, `_scan_target_entry_id`, `_scan_progress`, `_scan_duration`, `_scan_range` — most of these change meaning. No more "target coords" (proximity detects automatically). `_scan_range` becomes the proximity detection radius. `_scan_progress` still exists but advances while player stays in range, resets when they leave.
  - **Signals** (line ~155-168): `scan_rejected`, `scan_cancelled` — remove. `scan_hold_*` consumption removed. New signal needed for ENCOUNTERED state transitions. `element_unknown` needs to carry knowledge state (UNKNOWN vs ENCOUNTERED) or split into two signals.
  - **Feature Flow — Active Scan Flow** (line ~204-260): Entire section describes press-and-hold flow starting from `scan_hold_started` — must be completely rewritten as proximity auto-scan flow (_process checks nearby uncataloged props, starts/continues/interrupts scan based on range).
  - **Feature Flow — Movement Lock During Scan** (line ~296-311): Irrelevant — no scan hold means no movement lock. The player moves freely; scan happens automatically while in range. Remove this section.
  - **Feature Flow — Passive Identification Flow** (line ~316-343): Still relevant but needs update for 3-state system. ENCOUNTERED elements should show ⚠️ with name, not ❓.
  - **Signal Wiring** (line ~444-489): `scan_hold_started/update/ended` consumption from feature-002 — remove. `scan_rejected` emission to feature-002 — remove. Add proximity-based scan trigger wiring.
  - **Component Responsibilities** (line ~435): `scanner_system.gd` description references "Receives scan_hold_started/update/ended from feature-002" — must change to "Runs proximity check in _process".
  - **Mobile Specs — Scan Hold Latency** (line ~615-619): Entire section about 300ms hold threshold is irrelevant. Replace with proximity scan detection latency analysis.
  - **Why**: This is the PRIMARY feature affected. The entire scan mechanic is redesigned. Nearly every section needs rewriting.

---

- **`.aid/work-001-core/features/feature-002-player-movement/SPEC.md`**
  - **Description** (line ~25): "Press-and-hold toward unknown elements initiates scanning (owned by feature-003, not this feature)" — remove this sentence
  - **Acceptance Criteria** (line ~45): "Press-and-hold toward unknown element initiates scan (feature-003 integration)" — remove this criterion
  - **Two-Outcome Input Classification** (line ~175-201): "OUTCOME 1: POTENTIAL SCAN HOLD" — the entire scan hold path must be removed. Classification simplifies to: TAP (no-op on world) and JOYSTICK (movement). No more "three-outcome" or "two-outcome with scan hold".
  - **Edge cases** (line ~214): "Joystick walk near ❓ element: Movement continues past. No auto-scan. Scanning requires deliberate press-and-hold" — this directly contradicts the redesign. Now walking near ❓ elements DOES trigger auto-scan.
  - **Input Pipeline — Scan Hold (Outcome 2)** (line ~300-326): Entire section — remove
  - **Touch Discrimination thresholds** (line ~497-525): `hold_threshold: 300ms` becomes irrelevant for scan. Can simplify the classification to just tap vs drag.
  - **Signal Wiring** (line ~423-437): `scan_hold_started`, `scan_hold_update`, `scan_hold_ended` signals from player_input → feature-003 — remove. `scan_rejected` from feature-003 → player_input — remove.
  - **Component Responsibilities — player_input.gd** (line ~413): References "potential scan hold" and `scan_rejected` — must be simplified
  - **Why**: Player input no longer handles scan classification. The entire scan-hold input path is obsolete.

---

- **`.aid/work-001-core/REQUIREMENTS.md`**
  - **§4 In Scope** (line ~85): "Scanner system (press-and-hold to scan unknown elements, catalog entries)" — change to "proximity-based auto-scan"
  - **§5 F2** (line ~140): "Press-and-hold toward unknown element = scan (new input mode — see F13)" — remove
  - **§5 F13** (line ~241): "Active scan (press and hold): Player sees unknown element (❓ icon) → press and hold toward it → scan progress bar (2-3 seconds) → entry added to Catalog" — rewrite for proximity auto-scan
  - **§5 F13 — Knowledge states**: Only mentions "Before scanning" (❓) and "After cataloging" — needs 3 states (UNKNOWN/ENCOUNTERED/CATALOGED)
  - **§5 F13 — Fauna scanning**: "Scan fauna from safe distance → cataloged" — needs update: hostile fauna goes UNKNOWN→ENCOUNTERED on first hit, full cataloging deferred post-MVP
  - **§9 AC2** (line ~346): "Press-and-hold toward unknown element initiates scan" — remove
  - **§9 AC11** (line ~367): "Press and hold toward unknown flora → scan progress bar → catalog entry created" — rewrite as proximity auto-scan. Add criteria for ENCOUNTERED state.
  - **§9 AC11**: "Scan fauna from distance → cataloged → auto-defend ready" — needs update for ENCOUNTERED state (auto-defend on ENCOUNTERED, not full catalog)
  - **§11 Bootstrap Sequence**: delivery-002 note mentions "ScannerSystem + Inventory initialize" — still valid but ScannerSystem behavior changes
  - **Why**: Requirements are the upstream source of truth. All specs derive from them. Contradictions here propagate everywhere.

---

- **`.aid/work-001-core/delivery-002/DETAIL.md`**
  - **task-012 (Scanner system core)**: Entire task scope describes old flow:
    - "`ScanState` enum: IDLE, SCANNING, COMPLETE, REJECTED" — redesign
    - "Active scan flow: receive `scan_hold_started(coords)` from PlayerInput" — remove
    - "Movement lock: while SCANNING, never emit `scan_rejected`" — irrelevant
    - Signals list includes `scan_rejected`, `scan_cancelled` — remove/replace
    - "Connect to PlayerInput scan_hold signals from delivery-001" — remove
    - Criteria: "scan lifecycle (IDLE→SCANNING→COMPLETE)" — redesign for proximity
    - Criteria: "scan_rejected never emitted while _scan_state == SCANNING" — irrelevant
  - **task-013 (Prop renderer + scan progress renderer)**: ScanProgressRenderer scope still valid but trigger changes (proximity-based, not scan_hold-based). Criteria reference `scan_started/progress_updated/completed/cancelled` — some signals change.
  - **task-015 (Integration test)**: "Scanner: scan_hold_started → eligibility check → progress → complete" — rewrite for proximity scan. "AC2 completion (scan input — scan_hold fires with coords)" — remove.
  - **Integration Contract — Bootstrap Changes**: "ScannerSystem._ready() → connects to PlayerInput scan_hold_started/update/ended" — rewrite as proximity-based init.
  - **Visual Smoke Test**: "Press-and-hold toward prop → scan progress ring appears" — rewrite as "Walk near prop → scan progress ring appears automatically"
  - **Why**: delivery-002 is the CURRENT delivery. These tasks must be updated before coding begins.

---

- **`.aid/work-001-core/delivery-001/DETAIL.md`**
  - **task-007 (Player Input — Two-Outcome Classifier)**: Scope still describes 3 paths:
    - "SCAN HOLD: hold ≥300ms, drag <20px → emit `scan_hold_started(coords)`, `scan_hold_update(screen_pos)`, `scan_hold_ended()`" — remove entire path
    - "JOYSTICK: drag ≥20px (any time) OR scan_rejected fallback" — remove scan_rejected fallback
    - "`scan_rejected(coords)` → fall back to joystick" — remove
    - Criteria: "Hold ≥300ms → `scan_hold_started` emits" — remove
    - Criteria: "`scan_rejected` → falls back to joystick behavior" — remove
  - **task-008 (Integration test)**: "Hold → scan_hold signals emit (no consumer yet — verify signals fire)" — remove. "Scan hold signals fire with correct coords (no consumer)" — remove.
  - **Why**: task-007 has NOT been re-implemented yet (delivery-001 is complete but the spec drives future maintenance). The scan hold input path is dead code waiting to happen.

---

### MODERATE (should change for consistency)

---

- **`.aid/work-001-core/features/feature-004-auto-interaction/SPEC.md`**
  - **Core Principle** (line ~39): "❓ (uncataloged) = inert to the auto-system" — needs nuance: ENCOUNTERED elements are partially interactive (auto-defend activates on ENCOUNTERED hostile, but drops/details unknown until CATALOGED)
  - **Auto-Defend Flow** (line ~227-262): Currently checks `Catalog.is_cataloged(entry_id)` as binary gate. With 3 states, auto-defend should activate at ENCOUNTERED level (hostile flag is known), not require full CATALOGED. Update to check `knowledge_state >= ENCOUNTERED` for hostile fauna.
  - **Auto-Gather Flow** (line ~144-206): Catalog gate needs to check specifically for CATALOGED state (not just "is_cataloged"). Auto-gather should NOT work on ENCOUNTERED elements — you know they're hostile but don't know their drops/details yet. Flora/mineral go UNKNOWN→CATALOGED directly, so this mainly affects fauna.
  - **Cross-Feature Data Contracts**: `Catalog.is_cataloged(entry_id)` queries need to be updated to `Catalog.get_knowledge_state(entry_id)` or equivalent.
  - **Why**: Auto-interaction is the primary consumer of catalog state. The 3-state system creates a meaningful gameplay difference between ENCOUNTERED and CATALOGED.

---

- **`.aid/work-001-core/features/feature-010-night-threats/SPEC.md`**
  - **Surprise Catalog Flow** — Section "Surprise auto-catalog" (line ~298-303): Currently says "feature-003 (ScannerSystem) automatically catalogs the species" on first hit. With the redesign, first hit creates ENCOUNTERED state (not full CATALOGED). The language needs to change from "auto-catalogs" to "auto-registers as ENCOUNTERED."
  - **Data Model — species_type field** (line ~76-80): The "whether the player has cataloged it" description needs to mention 3 states.
  - **Feature Flow — Contact Damage** (line ~278-312): "Surprise auto-catalog" should become "auto-register as ENCOUNTERED." The note at line ~298 says "ScannerSystem automatically catalogs" — change to "transitions to ENCOUNTERED."
  - **Known emergent behavior — shelter farming** (line ~306): Still valid but note that shelter farming produces ENCOUNTERED fauna (not CATALOGED) — auto-defend works but drops remain unknown until full scan (deferred post-MVP).
  - **Why**: Fauna is the primary use case for the ENCOUNTERED state. The distinction between ENCOUNTERED (auto-defend activates, drops unknown) and CATALOGED (everything known) is the core design change.

---

- **`.aid/work-001-core/features/feature-012-hud/SPEC.md`**
  - **Cross-Feature Signal Consumption** (line ~133-148): `scan_completed(entry_id)` → Floating "Cataloged!" — still works for proximity scan completion, but may need new entry for ENCOUNTERED state feedback.
  - **Floating Text System table** (line ~110-119): `feature-003 (scan_completed)` entry for "Cataloged!" text — may need additional entry for "Encountered!" text.
  - **Why**: HUD needs to display feedback for both state transitions (ENCOUNTERED and CATALOGED).

---

- **`.aid/work-001-core/delivery-003/DETAIL.md`**
  - **task-017 (Auto-gather flow)**: "Catalog gate: `Catalog.is_cataloged(RESOURCE_TO_ENTRY[node.type])`" — needs to check for CATALOGED state specifically. Flora/mineral go directly to CATALOGED via proximity, so this practically works the same for MVP, but the API call needs updating.
  - **task-018 (Auto-defend stub)**: "Auto-defend fires on adjacent cataloged hostile" — should fire on ENCOUNTERED or CATALOGED hostile. Update criteria.
  - **Why**: Auto-interaction tasks need to use the correct state checks.

---

- **`.aid/work-001-core/delivery-005/DETAIL.md`**
  - **task-037 (FaunaManager)**: Contact damage and "surprise auto-catalog" language needs to change to "auto-register as ENCOUNTERED." Criteria: "surprise attack: uncataloged fauna → fauna_attacked_player → F-003 auto-catalogs" → "→ F-003 registers as ENCOUNTERED."
  - **task-038 (Fauna renderer + signal wiring)**: "Surprise attack: uncataloged fauna → fauna_attacked_player → F-003 auto-catalogs" — same language fix. "Auto-defend activates: F-004 now gets real fauna data" — auto-defend activates on ENCOUNTERED, not CATALOGED.
  - **Why**: Delivery-005 implements fauna which is the primary consumer of the ENCOUNTERED state.

---

- **`.aid/work-001-core/PLAN.md`**
  - **delivery-002 description**: "The ❓ → scan → identified loop is the game's identity" — still true but mechanism changed (proximity, not press-hold). Minor language update.
  - **Delivery Progression**: "delivery-002: See → What are these ❓ things? Let me scan and discover." — still valid conceptually, but "scan" now means "walk near" not "press and hold."
  - **Why**: Plan describes intent (still correct) but the mechanism language is slightly misleading.

---

- **`docs/vision-pivot-briefing.md`**
  - Line 86: "Active (press and hold) — FIRST ENCOUNTER with any new element" — contradicts redesign
  - Line 104: "Scanning requires proximity + press and hold" — contradicts redesign
  - Line 184: F-002 impact mentions "Add press-and-hold input for scanning" — outdated
  - **Why**: Historical document but still referenced. Should be annotated as superseded by scan-redesign-2026-04-02.md.

---

### LOW (nice-to-have, cosmetic)

---

- **`.aid/work-001-core/features/feature-005-inventory/SPEC.md`**
  - **Description** (line ~18): "with scan-safety check for unknown flora" — still valid, no change needed
  - **Use Consumable flow** (line ~163): References `Catalog.get_entry(entry_id)` — still valid with 3-state system (toxicity is a property of the CatalogEntry, available once CATALOGED)
  - Minor: the word "scan" in the description could be clarified as "proximity scan" but not strictly necessary.

---

- **`.aid/work-001-core/features/feature-011-journal/SPEC.md`**
  - Anomaly scanning trigger via `entry_cataloged` signal — still works identically. Anomalies go UNKNOWN→CATALOGED via proximity (no ENCOUNTERED state for anomalies).
  - No changes needed.

---

- **`docs/GDD.md`**
  - **§5.3 Controls**: Still mentions "Tap-to-move mode" and "Virtual joystick mode: toggle" — outdated since joystick-only pivot. No scanner mention at all. This document predates the scanner/catalog feature.
  - **§4.2 Biome Types**: Lists 8 biomes vs current 5. Outdated.
  - **Why**: GDD is a historical document, already superseded by REQUIREMENTS.md. Low priority to update.

---

- **`docs/design/design-system.md`**
  - No scan-specific references. Unaffected by redesign.

---

- **`docs/story-bible.md`**
  - No scan-specific references. "Scannable for Journal entries" language still works. Unaffected.

---

- **`.aid/knowledge/known-issues.md`**
  - No scan-specific issues. Unaffected.

---

### NO CHANGE NEEDED

Files reviewed that don't need changes:

- `.aid/work-001-core/features/feature-001-hex-grid/SPEC.md` — No scan references. HexTile data model unaffected. `prop_nodes` and `anomaly` fields unchanged.
- `.aid/work-001-core/features/feature-006-crafting/SPEC.md` — No scan references. Crafting has zero dependency on scan mechanics.
- `.aid/work-001-core/features/feature-007-survival-stats/SPEC.md` — No direct scan references. Consumes `fauna_attacked_player` signal (unchanged) and `item_used` (unchanged). Indirectly affected via auto-interaction but no SPEC changes needed.
- `.aid/work-001-core/features/feature-008-day-night-cycle/SPEC.md` — No scan references. SaveManager collects `ScannerSystem.get_save_data()` — interface unchanged, internal data format changes are feature-003's concern.
- `.aid/work-001-core/features/feature-009-building/SPEC.md` — No scan references. Building has zero dependency on scan mechanics.
- `.aid/work-001-core/delivery-004/DETAIL.md` — No scan-specific tasks. SaveManager (task-026) collects data generically.
- `.aid/work-001-core/delivery-006/DETAIL.md` — Journal tasks consume `entry_cataloged` signal which still works identically.
- `docs/design/design-system.md` — No scan-specific content.
- `docs/story-bible.md` — No scan-specific content.
- `.aid/knowledge/known-issues.md` — No scan-specific issues.

## Code Impact

### Files to modify

| File | Changes |
|------|---------|
| `scripts/scanner/scanner_system.gd` | **MAJOR REWRITE.** Remove `ScanState` enum (or simplify to IDLE/SCANNING). Remove `_on_scan_hold_started`, `_on_scan_hold_ended`, `_on_scan_hold_update` handlers. Remove drift check logic. Add proximity-based auto-scan in `_process`: check nearby props within `_scan_range`, start/continue/interrupt scan based on player distance. Add 3-state knowledge tracking. Change `scan_rejected`/`scan_cancelled` signals — remove `scan_rejected`, repurpose `scan_cancelled` for "left range during proximity scan." Add `knowledge_state_changed` signal for ENCOUNTERED transitions. |
| `scripts/player/player_input.gd` | **MODERATE.** Remove `signal scan_hold_started`, `signal scan_hold_update`, `signal scan_hold_ended` declarations (lines 16-18). Remove `_enter_scan_hold()` method (line 126). Remove `receive_scan_rejected()` method (line 158). Remove scan hold classification from `_unhandled_input` (lines 73-77, 104, 120). Simplify to TAP (no-op) + JOYSTICK only. |
| `scripts/main.gd` | **MINOR.** Remove `scan_rejected` wiring at lines 28-31. Remove `ScannerSystem` reference for scan_rejected signal connection. |
| `scripts/scanner/catalog.gd` | **MODERATE.** Change `_discovered: Dictionary[StringName, bool]` to `_knowledge: Dictionary[StringName, KnowledgeState]` with enum `{ UNKNOWN, ENCOUNTERED, CATALOGED }`. Add `get_knowledge_state(entry_id)` API. Update `is_cataloged()` to check for `CATALOGED` specifically. Add `encounter_entry(entry_id)` for ENCOUNTERED transitions. Update `get_save_data`/`load_save_data` for 3-state persistence. |
| `scripts/rendering/scan_progress_renderer.gd` | **MINOR.** Change trigger from `scan_hold` signals to proximity scan signals. Still shows/hides progress bar, but now activates automatically when player is in range of uncataloged prop. Remove `scan_cancelled` connection at line 88-90. |
| `scripts/rendering/element_icon_renderer.gd` | **DELETE** (see below) — already planned for replacement by PropRenderer + PropLabelRenderer. |
| `scenes/main.tscn` | **MINOR.** Replace `ElementIconRenderer` node reference (line 19) with PropRenderer + PropLabelRenderer once those are created. |
| `scenes/world/element_icon_renderer.tscn` | **DELETE** (see below). |

### Files to delete

| File | Reason |
|------|--------|
| `scripts/rendering/element_icon_renderer.gd` | Already slated for replacement by `prop_renderer.gd` + `prop_label_renderer.gd` (task-013 in delivery-002). The redesign reinforces this — icon rendering needs 3-state visual support (❓/⚠️/✅). |
| `scenes/world/element_icon_renderer.tscn` | Same — replaced by `prop_renderer.tscn` + `prop_label_renderer.tscn`. |

### Files to create

| File | Purpose |
|------|---------|
| `scripts/rendering/prop_renderer.gd` | Already planned in task-013. 3D prop meshes for world elements. |
| `scripts/rendering/prop_label_renderer.gd` | Already planned in task-013. Floating pill labels with 3-state text: "❓ Unknown [category]" / "⚠️ [name]" (ENCOUNTERED) / "[name]" (CATALOGED). |
| `scenes/world/prop_renderer.tscn` | Already planned. |
| `scenes/world/prop_label_renderer.tscn` | Already planned. |

No entirely NEW files are needed beyond what was already planned. The redesign changes the *behavior* of planned files, not the file structure.

### Signals to add/remove/modify

| Signal | Action | File | Details |
|--------|--------|------|---------|
| `scan_hold_started(coords)` | **REMOVE** | `player_input.gd` | No more press-and-hold scan input |
| `scan_hold_update(screen_pos)` | **REMOVE** | `player_input.gd` | Same |
| `scan_hold_ended()` | **REMOVE** | `player_input.gd` | Same |
| `scan_rejected(coords)` | **REMOVE** | `scanner_system.gd` | No eligibility check on hold — proximity is automatic |
| `scan_cancelled()` | **MODIFY** | `scanner_system.gd` | Repurpose: emitted when player leaves proximity range during an active scan (progress resets). Or rename to `scan_interrupted()` for clarity. |
| `element_unknown(coords)` | **MODIFY** | `scanner_system.gd` | Current signature `(coords: Vector2i)` — needs to include `entry_id` and `knowledge_state` (or `category`). The SPEC already defines `(coords, entry_id, category)` but code only emits `(coords)`. Also needs to differentiate UNKNOWN from ENCOUNTERED. |
| `knowledge_state_changed(entry_id, old_state, new_state)` | **ADD** | `scanner_system.gd` | New signal for any knowledge transition (UNKNOWN→ENCOUNTERED, UNKNOWN→CATALOGED, ENCOUNTERED→CATALOGED). Consumed by PropLabelRenderer for label updates. |
| `entry_encountered(entry_id, category)` | **ADD** | `scanner_system.gd` | Specific signal for ENCOUNTERED transitions (hostile fauna first-hit). Consumed by auto-interaction for auto-defend activation. |

## Delivery Plan Impact

### delivery-001 — task changes needed

| Task | Change |
|------|--------|
| **task-007** (Player Input) | Remove SCAN HOLD classification path. Remove `scan_hold_started/update/ended` signals. Remove `receive_scan_rejected` method. Simplify to TAP + JOYSTICK only. Update criteria: remove hold ≥300ms and scan_rejected tests. |
| **task-008** (Integration test) | Remove "Hold → scan_hold signals emit" test. Remove "Scan hold signals fire with correct coords" criterion. |

### delivery-002 — task changes needed

| Task | Change |
|------|--------|
| **task-011** (Catalog data layer) | Add `KnowledgeState` enum (UNKNOWN, ENCOUNTERED, CATALOGED). Change `_discovered` to `_knowledge` dictionary. Add `get_knowledge_state()`, `encounter_entry()` APIs. Add `entry_encountered` signal. Update save/load for 3-state. Update unit test criteria. |
| **task-012** (Scanner system core) | **MAJOR REWRITE.** Replace entire active scan flow: remove `ScanState` machine, remove scan_hold_* handlers, implement proximity auto-scan in `_process`. Add proximity detection: check nearby tiles for uncataloged props, start scan when in range, interrupt when out of range. Add ENCOUNTERED logic for hostile fauna first-hit. Remove scan_rejected/scan_cancelled (or repurpose). Remove "Movement lock" guarantee. Update all criteria. |
| **task-013** (Renderers) | ScanProgressRenderer trigger changes: show on proximity scan start (automatic), not on scan_hold_started. PropLabelRenderer needs 3-state labels: ❓ (UNKNOWN), ⚠️+name (ENCOUNTERED), name (CATALOGED). Add criteria for ENCOUNTERED label rendering. |
| **task-014** (Catalog panel UI) | Minor: catalog entries may show knowledge state icon (❓/⚠️/✅). Counter could show "12/47 cataloged" but also "3 encountered" — design decision needed. |
| **task-015** (Integration test) | Replace "scan_hold_started → eligibility → progress → complete" with "walk near prop → proximity scan starts → progress → complete." Remove "AC2 scan input verified (scan_hold signals)." Add ENCOUNTERED state tests. |

### delivery-003 — task changes needed

| Task | Change |
|------|--------|
| **task-017** (Auto-gather flow) | Update catalog gate: `Catalog.get_knowledge_state(entry_id) == CATALOGED` instead of `is_cataloged()`. For MVP flora/mineral this is equivalent (they skip ENCOUNTERED), but the API call matters for correctness. |
| **task-018** (Auto-defend stub) | Auto-defend should activate on `knowledge_state >= ENCOUNTERED` (not just CATALOGED). Update criteria: "Auto-defend fires on adjacent ENCOUNTERED or CATALOGED hostile." |

### delivery-005 — task changes needed

| Task | Change |
|------|--------|
| **task-037** (FaunaManager) | Language: "surprise auto-catalog" → "auto-register as ENCOUNTERED." Contact damage still fires `fauna_attacked_player` signal — no signature change needed. The ENCOUNTERED transition is handled by ScannerSystem, not FaunaManager. Minor criteria language updates. |
| **task-038** (Fauna renderer + signal wiring) | "F-003 auto-catalogs" → "F-003 registers as ENCOUNTERED." Auto-defend activates on ENCOUNTERED (line in criteria needs update). |

### New tasks needed

None strictly *new*. The redesign simplifies the MVP (fewer states to handle for flora/mineral, no scan puzzle mechanics), but changes the *content* of existing tasks significantly. All changes fit within the existing task structure.

### Tasks that can be removed/simplified

| Item | Simplification |
|------|---------------|
| **task-007 scan hold path** | Removes ~40% of player_input.gd complexity. No more 3-outcome classification, no hold threshold, no scan_rejected fallback. |
| **task-012 ScanState machine** | Removes the 4-state machine (IDLE→SCANNING→COMPLETE→REJECTED) with drift checks and range validation. Replaces with simple proximity check in `_process`. |
| **Scan duration configs** | Still exist but simpler — flora/mineral scan duration is the time player must stay in range (e.g., 2s), not the time they must hold a button. |
| **Input latency analysis** | The scan hold classification timeline (300ms threshold, 2-frame timeout) is completely removed from Mobile Specs in feature-002. |

## Open Questions

1. **ENCOUNTERED state visual:** The redesign doc specifies ⚠️ for ENCOUNTERED. Should PropLabelRenderer show "⚠️ [name]" or "⚠️ Hostile" (since only the hostile flag is known, not the species name)? The redesign doc says name is shown at ENCOUNTERED but drops/details are unknown. **Design decision needed.**

2. **Auto-defend gate level:** Should auto-defend activate at ENCOUNTERED (as the redesign implies — "auto-defend activates" at ENCOUNTERED) or require CATALOGED? The redesign doc is clear (ENCOUNTERED activates auto-defend), but this means the player never needs to fully catalog hostile fauna for combat purposes — the only incentive for CATALOGED is knowing drops. **Confirm this is intentional.**

3. **Scan progress bar for proximity scan:** Does the progress bar still appear above the prop during proximity scan? If so, it needs to appear/disappear dynamically as the player moves in/out of range. What happens if the player is in range of multiple uncataloged props — does it scan one at a time (nearest first) or all simultaneously? **Design decision needed.**

4. **Catalog counter with 3 states:** Does the "12/47 cataloged" counter count ENCOUNTERED entries? Or only fully CATALOGED? The player might encounter 5 hostile fauna but not catalog any (since full fauna cataloging is deferred post-MVP). **Design decision needed.**

5. **Flora/Mineral ENCOUNTERED state:** The redesign says flora/mineral skip ENCOUNTERED and go UNKNOWN→CATALOGED directly. Should the code enforce this as a rule (flora/mineral never enter ENCOUNTERED) or allow it as a potential future state? **Implementation decision.**

6. **Passive fauna scanning (deferred):** The redesign defers passive fauna scanning (needs Trap). For MVP, passive fauna cannot be fully cataloged. Do they stay UNKNOWN forever, or do they become ENCOUNTERED somehow? If a passive fauna flees on approach, the player sees it but can't scan it — should this register as ENCOUNTERED? **Design decision needed.**

7. **ScannerSystem proximity range:** The redesign says "player walks near" — what exactly is the range? Same as the old `_scan_range` (2 hexes), or closer (adjacent only)? The redesign doc doesn't specify an exact range for auto-scan proximity. **Tuning decision needed.**

8. **Scan progress on movement:** If the player walks near a prop and keeps moving past it, does the scan interrupt immediately or is there a grace period? If scan requires staying in range for 2-3 seconds, does the player need to stop or slow down? The redesign says "Player stays in range → scan progress bar fills → scan completes / Player leaves range → scan interrupted, progress resets." **Confirm no grace period — binary in/out of range.**

9. **ElementIconRenderer in main.tscn:** The existing `scenes/main.tscn` references `ElementIconRenderer` (line 19). The PropRenderer/PropLabelRenderer replacement was already planned in task-013, but the scan redesign makes this more urgent. Should task-013 also handle removing the old scene reference? **Yes — confirm.**
