# delivery-006: The Story — Journal + Narrative

**Status:** Approved
**Created:** 2026-03-31
**Features:** feature-011-journal
**Depends on:** delivery-002 (009-015, entry_cataloged signal), delivery-004 (024-031, day_started signal)
**Cumulative state:** Chapter 1 narrative arc complete. The game has a purpose.

## Execution Graph

```
task-039 (Journal data layer + trigger system)
  │
  ├──────────────────┐
  ▼                  ▼
task-040           task-041
(Cutscene viewer)  (Journal panel UI
                    + HUD integration)
  │                  │
  └──────┬───────────┘
         ▼
task-042 (Integration test — narrative arc end-to-end)
```

**Parallel group:** task-040 + task-041 — both depend on task-039 but not on each other.
Can run in parallel if two agents are available.

## Tasks

| # | Name | Type | Depends On | Parallel With |
|---|------|------|-----------|---------------|
| 039 | Journal data layer + trigger system | IMPLEMENT | delivery-004 | -- |
| 040 | Cutscene viewer — fullscreen comic panel player | IMPLEMENT | 039 | -- |
| 041 | Journal panel UI + HUD integration | IMPLEMENT | 039 | -- |
| 042 | Integration test — narrative arc end-to-end | TEST | 040, 041 | -- |

**Note:** task-040 and task-041 both depend on task-039 but not on each other.
They CAN run in parallel if two agents are available.

## Task Details

### task-039: Journal Data Layer + Trigger System [IMPLEMENT]

**Source:** feature-011 → Data Model + Feature Flow (triggers)

**Scope:**
- `scripts/journal/journal_system.gd` — Node (child of Player):
  - `JournalEntry` Resource: entry_id, title, description, day_hint, cutscene_id,
    trigger_type, trigger_data, chapter_id
  - `JournalTrigger` enum: GAME_START, ANOMALY_SCAN, DAY_REACHED, CATALOG_COUNT
  - `CutsceneDefinition` Resource: cutscene_id, panels array, chapter_id
  - `CutscenePanel` Resource: image (nullable for MVP placeholder), caption, duration
  - Properties: `_all_entries`, `_unlocked`, `_seen_cutscenes`, `_active_cutscene_id`
  - **Trigger evaluation on signals:**
    - `_ready()` → GAME_START entries unlock
    - `ScannerSystem.entry_cataloged(entry_id, ANOMALY)` → ANOMALY_SCAN check
    - `DayNightCycle.day_started(day_number)` → DAY_REACHED check
    - `ScannerSystem.entry_cataloged(any)` → CATALOG_COUNT check
  - **Trigger cascade:** ALL triggers evaluated per signal (one signal can unlock multiple entries)
  - **Cutscene queue:** if multiple entries unlock with cutscenes, play sequentially
  - Signals: `journal_entry_unlocked`, `cutscene_started`, `cutscene_ended`,
    `cutscene_panel_advanced`
  - `get_save_data()` / `load_save_data()` (unlocked IDs, seen cutscene IDs, chapter_id)
- Chapter 1 data files:
  - `data/journal/ch1_entries.tres` — 3 entries: crash_landing (GAME_START),
    strange_signal (DAY_REACHED day 3), first_anomaly (ANOMALY_SCAN anomaly_ch1_001)
  - `data/journal/cutscenes/cs_crash_landing.tres` — placeholder panels (caption only)
  - `data/journal/cutscenes/cs_first_anomaly.tres` — placeholder panels (caption only)

**Criteria:**
- [ ] GAME_START: crash_landing entry unlocks on `_ready()`
- [ ] DAY_REACHED: strange_signal unlocks when day_count ≥ 3
- [ ] ANOMALY_SCAN: first_anomaly unlocks when anomaly_ch1_001 cataloged
- [ ] CATALOG_COUNT: (no Ch1 entries use this — but trigger evaluation code path tested)
- [ ] Trigger cascade: single signal can unlock multiple entries
- [ ] Cutscene queue: multiple cutscene entries play sequentially
- [ ] `journal_entry_unlocked` emitted per unlock
- [ ] Save/load round-trip: unlocked + seen_cutscenes preserved
- [ ] 3 Chapter 1 entries + 2 cutscene definitions loaded from data files
- [ ] MVP placeholder: cutscene panels have caption only, image nullable
- [ ] Unit tests for all 4 trigger types + cascade + queue
- [ ] Build passes with zero warnings

---

### task-040: Cutscene Viewer — Fullscreen Comic Panel Player [IMPLEMENT]

**Source:** feature-011 → Layers & Components (CutsceneViewer) + UI Specs

**Scope:**
- `ui/cutscene_viewer.gd` — CanvasLayer (layer 40, above all):
  - `process_mode = PROCESS_MODE_ALWAYS` (stays responsive during pause)
  - Fullscreen overlay: dark background ColorRect, panel image TextureRect
    (centered, ~80% width), caption Label below, "Tap to continue" prompt
  - On `cutscene_started`: show overlay, load panels, **pause game tree**
    (`get_tree().paused = true`). All other systems freeze (DayNightCycle,
    fauna, survival, auto-interaction — they use default PROCESS_MODE_PAUSABLE).
  - Panel sequence: display panel caption (MVP: colored rect + text, no image file).
    If duration > 0: auto-advance. If duration == 0: wait for tap.
  - Tap anywhere → advance to next panel
  - On last panel: `_seen_cutscenes[id] = true`, emit `cutscene_ended`,
    `get_tree().paused = false`, hide overlay
- `scenes/ui/cutscene_viewer.tscn`

**Criteria:**
- [ ] Fullscreen overlay covers everything (layer 40, above HUD + ScreenFade)
- [ ] Game tree pauses on cutscene start (DayNightCycle, fauna, survival all freeze)
- [ ] CutsceneViewer stays responsive during pause (PROCESS_MODE_ALWAYS)
- [ ] Panels display caption text on colored background (MVP placeholder)
- [ ] Tap anywhere advances to next panel
- [ ] Auto-advance panels progress after duration seconds
- [ ] Last panel advance → cutscene ends, game unpauses
- [ ] `cutscene_started` / `cutscene_ended` / `cutscene_panel_advanced` signals emit
- [ ] Build passes with zero warnings

---

### task-041: Journal Panel UI + HUD Integration [IMPLEMENT]

**Source:** feature-011 → Layers & Components (JournalPanel) + UI Specs

**Scope:**
- `scenes/ui/journal_panel.tscn` — PanelContainer bottom drawer
- `ui/journal_panel.gd`:
  - Story Timeline tab: ScrollContainer with VBoxContainer of entries sorted by day_hint
  - Catalog tab: redirect label ("See Catalog panel") — no UI duplication
  - Unlocked entries: title + description + REPLAY button (if has cutscene + seen)
  - Locked entries: "???" greyed placeholder (creates curiosity)
  - Refreshes on `journal_entry_unlocked`
  - `panel_opened` for mutual exclusion (5-panel list)
- `ui/journal_entry_ui.gd` — entry row: 4 states (unlocked+cutscene+seen = REPLAY,
  unlocked+cutscene+new = "NEW" badge, unlocked+no cutscene = read-only,
  locked = "???")
- JournalButton (64×64px) in HUD — always visible
- Wire `journal_entry_unlocked` → HUD notification "New journal entry!"

**Criteria:**
- [ ] JournalPanel opens/closes on JournalButton tap
- [ ] Timeline shows unlocked entries sorted by day_hint
- [ ] Locked entries show "???" (greyed, no title revealed)
- [ ] REPLAY button on seen cutscene entries → replays cutscene
- [ ] "NEW" badge on unseen cutscene entries
- [ ] Catalog tab shows redirect (not duplicate UI)
- [ ] `panel_opened` signal; mutual exclusion with 4 other panels
- [ ] "New journal entry!" notification on unlock
- [ ] JournalButton visible in HUD
- [ ] Touch targets: entry ~100px, REPLAY ~80×48, close 48×48, JournalButton 64×64
- [ ] Game continues while panel open (but cutscene pauses)
- [ ] Build passes with zero warnings

---

### task-042: Integration Test — Narrative Arc End-to-End [TEST]

**Source:** AC12

**Scope:**
- Full Chapter 1 narrative arc:
  - Game start → crash_landing entry unlocked → cutscene plays → seen
  - Day 3 → strange_signal entry unlocked (text only, no cutscene)
  - Scan anomaly_ch1_001 → first_anomaly entry unlocked → cutscene plays → cliffhanger
- Journal panel: all 3 entries appear in timeline after unlocking
- Locked entries: before unlock, show "???"
- Cutscene viewer: pauses game, panels advance, game unpauses
- Cutscene replay: tap REPLAY → plays again
- Save/load: unlocked entries + seen cutscenes persist
- AC12 full coverage

**Criteria:**
- [ ] AC12 fully covered: journal accessible, timeline chronological, catalog section,
      anomaly scan → both catalog + timeline, cutscene plays
- [ ] Crash landing cutscene auto-plays on first game start
- [ ] Strange signal unlocks at Day 3 (text entry, no cutscene)
- [ ] First anomaly cutscene plays on anomaly scan
- [ ] "???" entries visible before unlock, correct count
- [ ] Cutscene pauses game, unpauses on end
- [ ] Cutscene replay works from journal panel
- [ ] Save/load round-trip: unlocked + seen preserved
- [ ] Trigger cascade: verify single signal can unlock multiple (if applicable)
- [ ] Tests deterministic, clean setup/teardown
- [ ] All tests pass
- [ ] Build passes with zero warnings

## Integration Contract

### Scene Tree Additions
Cumulative (adds to delivery-005):
- Player
  - JournalSystem (Node) — NEW
- CutsceneViewer (CanvasLayer, layer=40) — NEW, above everything

### Bootstrap Changes
- JournalSystem._ready() → connects to ScannerSystem.entry_cataloged + DayNightCycle.day_started
- JournalSystem loads chapter data from data/journal/ch1_entries.tres
- GAME_START trigger fires immediately → crash_landing cutscene queues
- CutsceneViewer.process_mode = PROCESS_MODE_ALWAYS (runs during pause)

### Visual Smoke Test
Run the game on desktop (F5). You MUST see:
- [ ] Everything from delivery-005 still works
- [ ] Game start → crash landing cutscene plays (placeholder: colored panel + caption text)
- [ ] Tap to advance cutscene panels → cutscene ends → game resumes
- [ ] Tap Journal button → panel shows Story Timeline with crash_landing entry
- [ ] Tap entry → REPLAY button → cutscene replays
- [ ] Day 3 → "strange signal" journal entry unlocks (text only, no cutscene)
- [ ] Scan anomaly → cutscene plays → both Catalog entry and Journal entry created
- [ ] During cutscene: game is paused (no stat drain, no fauna movement, no day/night progression)

### Dev Environment
No additional requirements beyond delivery-001.

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | 4 tasks created (039-042). Linear chain, single feature. | /aid-detail |
