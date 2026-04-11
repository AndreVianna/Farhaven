# delivery-007: Chapter 1 Content — Milestones, Cutscenes, Journal

**Status:** Planning
**Created:** 2026-04-11 (split from delivery-006c during restructuring)
**Depends on:** delivery-006c (engine features landed) + delivery-006d (engine verified "redonda")
**Cumulative state:** Chapter 1 of Farhaven playable. Milestone events written, cutscenes produced, journal entries authored. Narrative arc complete for Act 1 (Far Side).

> **Design specs:**
> - `.aid/knowledge/game-lore.md` — 4-act narrative, civilization, Chapter 1
> - `.aid/knowledge/game-mechanics.md` — cutscene system, progression map
>
> **Phase note:** This is the Content delivery. It is authorial work — tone, voice, story choices are
> Andre's call with Lola as collaborator, not a task to delegate to an elf. Tasks look short on the
> surface but the shape of "done" depends on creative judgment, not task completion.

## Tasks

| # | Name | Type | Est. hours |
|---|------|------|-----------|
| 078 | Chapter 1 milestone EVENTs (.tres) | CONTENT | 3 |
| 079 | Chapter 1 cutscene content (AI video prompts + production) | CONTENT | 8 |
| 080 | Chapter 1 journal entries content | CONTENT | 3 |

**Estimated total: ~14h** (but creative work — real time depends on iteration)

## Chapter 1 milestone events (from original delivery-006c draft)

From `game-lore.md` Act 1 (Far Side):

| Event ID | Trigger | Effects |
|----------|---------|---------|
| first_tool_crafted | craft_stone_axe resolved | journal: "Day 2 — Tools", hint: "try chopping trees" |
| first_night_survived | day_count >= 2 | journal: "Day 2 — Survived", cutscene: dawn after first night |
| first_structure_built | any build recipe resolved | journal: "Day 3 — Shelter", hint: "structures protect at night" |
| anomaly_discovered | anomaly_ch1_001 cataloged | journal: "Day 4 — Signal", cutscene: cs_first_anomaly |
| chapter_1_complete | all above + day_count >= 5 | cutscene: cs_chapter_1_end, unlock chapter 2 |

*Note: This table is the preliminary list from 2026-04-09 planning. Revisit during task-078 — may need adjustment once we see the engine running Chapter 1 during 006d play-testing.*

## Task Details

### task-078: Chapter 1 milestone EVENTs (.tres)
**What to create:**
- GameEvent .tres files for the five milestones listed above
- Each with: id, trigger condition (Predicate), effects (unlock journal + trigger cutscene + hint)
- Stored in `data/events/chapter1/*.tres`
- IDs follow E prefix convention established in delivery-006b

**Collaborative:** Lola drafts the mechanical event definitions (trigger conditions, effect structure). Andre reviews and adjusts narrative timing (e.g., should "first tool crafted" fire on ANY tool or specifically stone_axe?).

### task-079: Chapter 1 cutscene content
**What to produce:**
- Cutscene prompts for each narrative beat that needs a video:
  - `cs_intro`: Opening — arrival at Far Side (first seconds of game)
  - `cs_first_dawn`: Dawn after first night survived
  - `cs_first_anomaly`: Discovery of first chapter 1 anomaly (the "signal")
  - `cs_chapter_1_end`: Chapter 1 closing moment, transition to chapter 2
- Video generation tool selection (Sora / Kling / Runway / other — open question)
- Lola writes prompts in her voice / Andre's aesthetic direction
- Andre runs generation, reviews, iterates
- Final videos saved to `data/cutscenes/media/*.mp4`
- CutsceneDef .tres files (created via editor from task-077) reference the media paths

**Collaborative:** Prompt writing is Lola + Andre joint work. Video generation is Andre's hands. Evaluation is both.

**Open question:** Which video generation tool? The answer affects prompt style (Sora loves specific shot descriptions; Kling prefers action verbs; Runway wants style references). Decision deferred until we start the task.

### task-080: Chapter 1 journal entries content
**What to write:**
- Journal entry bodies for each unlock trigger in task-078 events
- Preliminary list (from the milestone table):
  - "Day 2 — Tools" (after first_tool_crafted)
  - "Day 2 — Survived" (after first_night_survived)
  - "Day 3 — Shelter" (after first_structure_built)
  - "Day 4 — Signal" (after anomaly_discovered)
- Possibly a chapter-opening entry "Day 1 — Arrival"
- Each entry is in-world voice — the player character's reflection, not tutorial text. Tone is contemplative, slightly overwhelmed, human.
- Saved as JournalEntry .tres via editor from task-076

**Collaborative:** Lola drafts. Andre edits for voice/tone. Entries are short (100-300 words each) but every word matters because this is where narrative tone is established.

## Exit criteria

- [ ] Player can play Chapter 1 start to end
- [ ] All five milestone events fire at the right time
- [ ] All journal entries unlock and read correctly
- [ ] All cutscenes play at the right triggers
- [ ] Andre says "this feels like the opening of the game we want to make"

Last item is the gate. This is authorial work, not checklist work.

## Dependencies (do not start before these)

1. **delivery-006c** merged — need CutsceneManager, Journal system, editor pages working
2. **delivery-006d** complete — need engine verified "redonda" before pouring content into it. If engine contracts reveal gaps, content would be built on sand.

Starting 007 before 006d finishes would be like writing a novel in a word processor whose save function sometimes drops paragraphs.
