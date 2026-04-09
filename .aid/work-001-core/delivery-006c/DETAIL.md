# delivery-006c: The Story — Journal, Cutscenes, Events

**Status:** Planning
**Created:** 2026-04-09
**Depends on:** delivery-006a (Event system) + delivery-006b (editor for content creation)
**Cumulative state:** Chapter 1 narrative arc complete. Milestones, cutscenes, journal entries.

> **Design specs:**
> - `.aid/knowledge/game-lore.md` — 4-act narrative, civilization, Chapter 1
> - `.aid/knowledge/game-mechanics.md` — cutscene system (Level A + B), progression map

## Tasks (preliminary — to be detailed during planning)

| # | Name | Type | Est. hours |
|---|------|------|-----------|
| 074 | CutsceneManager autoload (play MP4, skip button, fullscreen) | IMPLEMENT | 6 |
| 075 | Journal system (JournalEntry Gear, journal panel UI, unlock via EVENT) | IMPLEMENT | 6 |
| 076 | Editor: Journal Entry page | IMPLEMENT | 4 |
| 077 | Editor: Cutscene page (metadata, video path, trigger EVENT link) | IMPLEMENT | 4 |
| 078 | Chapter 1 milestone EVENTs (.tres) | CONTENT | 3 |
| 079 | Chapter 1 cutscene content (AI-generated video prompts + production) | CONTENT | 8 |
| 080 | Chapter 1 journal entries content | CONTENT | 3 |
| 081 | BDD scenarios for narrative flows | TEST | 4 |

**Estimated total: ~38h**

## Chapter 1 milestone events (preliminary list)

From `game-lore.md` Act 1 (Far Side):

| Event ID | Trigger | Effects |
|----------|---------|---------|
| first_tool_crafted | craft_stone_axe resolved | journal: "Day 2 — Tools", hint: "try chopping trees" |
| first_night_survived | day_count >= 2 | journal: "Day 2 — Survived", cutscene: dawn after first night |
| first_structure_built | any build recipe resolved | journal: "Day 3 — Shelter", hint: "structures protect at night" |
| anomaly_discovered | anomaly_ch1_001 cataloged | journal: "Day 4 — Signal", cutscene: cs_first_anomaly |
| chapter_1_complete | all above + day_count >= 5 | cutscene: cs_chapter_1_end, unlock chapter 2 |

## Open questions
- Cutscene format: MP4, WebM, or Godot animation? (Lean: MP4 for Level A)
- Journal UI: separate panel or tab in existing log panel?
- Cutscene skip: immediate or "hold to skip" (prevent accidental skip)?
- AI video generation: which tool? Sora, Kling, Runway? Andre generates, Lola prompts?
- Chapter 1 duration: ~30 min gameplay? ~1 hour? Affects event timing.
