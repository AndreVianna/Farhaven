# delivery-006c: Engine Close — Cutscene, Journal, Status

**Status:** Planning
**Created:** 2026-04-09
**Restructured:** 2026-04-11 (split content into delivery-007, added Status screen, narrowed scope to engine close)
**Depends on:** delivery-006a (Event system) + delivery-006b (editor for content creation)
**Cumulative state:** Engine phase of the game closed. CutsceneManager, Journal system, Status screen all implemented. Editor pages for Journal + Cutscene exist. BDD test coverage for narrative flows.

> **Design specs:**
> - `.aid/knowledge/game-lore.md` — 4-act narrative, civilization, Chapter 1
> - `.aid/knowledge/game-mechanics.md` — cutscene system (Level A + B), progression map
>
> **Phase note:** This delivery closes the Engine. After 006c, delivery-006d (stabilization + verification)
> runs before delivery-007 (Chapter 1 content) can begin. Content depends on a verified-round engine.

## Tasks

| # | Name | Type | Est. hours |
|---|------|------|-----------|
| 074 | CutsceneManager autoload (play MP4, skip button, fullscreen) | IMPLEMENT | 6 |
| 075 | Journal system (JournalEntry Gear, journal panel UI, unlock via EVENT) | IMPLEMENT | 6 |
| 076 | Editor: Journal Entry page | IMPLEMENT | 4 |
| 077 | Editor: Cutscene page (metadata, video path, trigger EVENT link) | IMPLEMENT | 4 |
| 081 | BDD scenarios for engine narrative plumbing (no content) | TEST | 4 |
| 082 | Status screen: populate existing placeholder | IMPLEMENT | 4 |

**Estimated total: ~28h**

**Moved to delivery-007 (content phase):** tasks 078 (Chapter 1 milestone events), 079 (cutscene content + video generation), 080 (journal entries content). Those are authorial work and depend on 006c + 006d being complete.

## Task Details

### task-074: CutsceneManager autoload
**What to build:**
- Autoload singleton for playing cutscenes
- Support MP4 playback via Godot's VideoStreamPlayer
- Fullscreen mode during playback
- Skip button (decision: immediate skip vs hold-to-skip — TBD in open questions)
- Signal emitted when cutscene completes or skipped
- API: `CutsceneManager.play(cutscene_id)` returns nothing, emits `cutscene_finished(cutscene_id, skipped)`
- Lookup by ID from `data/cutscenes/*.tres` (CutsceneDef resource — created in 077)

### task-075: Journal system
**What to build:**
- `JournalEntry` extends `Gear` — new data class with fields: id (J prefix), title, body (long text), date_added (int, day count), category (chapter/lore/tutorial)
- `Journal` autoload or service — tracks unlocked entries, emits `journal_entry_added` signal
- Journal panel UI — list of entries, click to read full body, category filter
- Unlock via GameEvent effect: new effect kind `unlock_journal_entry` with param `entry_id`
- DiscoveryWatcher wires up (same pattern as recipe unlocks)
- Integration with existing HUD drawer system (new tab or integrated into existing panel)

**Note flag:** This is the biggest task in 006c. May warrant splitting into 075a (engine/data) + 075b (UI panel) if scope proves too tangled during implementation. Decision deferred to first coding session.

### task-076: Editor — Journal Entry page
**What to build:**
- New tab in level-editor for JournalEntry .tres files
- Master-detail layout (same pattern as Prop / Recipe / Event editors)
- Fields: id (J prefix), title, body (multi-line textarea), category (dropdown), day_added (int)
- ID namespace auto-increment using shared `nextId('J')`
- File discovery for `data/journal/*.tres`
- Round-trip serialization

### task-077: Editor — Cutscene page
**What to build:**
- New tab in level-editor for CutsceneDef .tres files
- Master-detail layout
- Fields: id (C prefix), display_name, video_path (text/file picker), trigger_event (reference to GameEvent ID), duration_seconds (int, for UI preview)
- ID namespace auto-increment using shared `nextId('C')`
- File discovery for `data/cutscenes/*.tres`
- Round-trip serialization
- Trigger event field should be a dropdown of existing GameEvents (reusing event discovery)

### task-081: BDD scenarios — engine narrative plumbing
**What to test (no content, just plumbing):**
- GameEvent with `unlock_journal_entry` effect adds entry to Journal
- Journal panel reflects `journal_entry_added` signal
- CutsceneManager.play resolves on completion and on skip
- Cutscene trigger via event effect (mock video, not real content)
- JournalEntry and CutsceneDef round-trip through editor without data loss

**Not testing (deferred to delivery-007):** actual Chapter 1 content, story flow, specific milestone events.

### task-082: Status screen
**What to build:** Populate the existing placeholder in `ui/status_combined_panel.gd::_build_left_content()`.

**Current state:** `StatusCombinedPanel` class exists and combines a STATUS placeholder (left) with the INVENTORY panel (right). Left side is a generic `CombinedPanel.create_placeholder("STATUS", "Status")` stub.

**What to replace the placeholder with:**
- **Player stats section:** HP, hunger, thirst, stamina (read from SurvivalSystem). Include day counter and current chapter label.
- **Discoveries section:** catalog count (cataloged / total encountered / total known entries from PropDef registry).
- **Navigation links section:** buttons/links for Settings, About, Contact. For 006c scope, these open a "Coming soon" modal. Real implementations deferred to post-006c (future delivery — not 006d, not 007, separate scope).

**Open / TBD during implementation:**
- Exact layout (vertical sections vs tabs within Status)
- Typography matching the existing CombinedPanel aesthetic
- Whether "current chapter" needs a Chapter system (probably placeholder "Chapter 1" string literal for 006c)

**Scope guard:** Don't create real Settings/About/Contact systems in this task. They're placeholders. If a real Settings system is needed before shipping, that's a new delivery.

## Open questions

- **Cutscene format:** MP4, WebM, or Godot animation? (Lean: MP4 for Level A)
- **Journal UI:** separate drawer tab or tab inside existing panel? (Pairs with task-075 scope decision)
- **Cutscene skip:** immediate or "hold to skip" (prevent accidental skip)?
- **Status screen layout:** vertical sections or sub-tabs? (task-082 design call)
- **Chapter label source:** literal "Chapter 1" for now, or a ChapterManager stub?

## What this delivery does NOT include

- Chapter 1 milestone events (.tres) — delivery-007
- Chapter 1 cutscene content (prompts, video generation) — delivery-007
- Chapter 1 journal entries content (writing) — delivery-007
- Real Settings / About / Contact systems — future delivery
- Engine stabilization sweep — delivery-006d
