# Gear Hierarchy — Universal Entity Model

**Status:** Approved design, implementation deferred to delivery-006
**Created:** 2026-04-09
**Authors:** Andre Vianna (architecture) + Lola (documentation)

## The Hierarchy

```
Gear (engine root entity)
  id: StringName
  display_name: String
  short_description: String
  long_description: String

  ├── Script (executable game logic)
  │   conditions: [Predicate]
  │   effects: [Effect]
  │   actions: [StringName]     # player trigger (empty = passive)
  │   duration: float           # seconds (was "time")
  │   │
  │   ├── Recipe
  │   │   inputs: [Input]
  │   │   outputs: [Output]
  │   │   # NO unlock_when — discovery handled by Event with grant_script effect
  │   │   # NO kind enum — was purely cosmetic, no runtime behavior
  │   │
  │   └── Event
  │       count: int            # runtime state (persisted in save)
  │       max_count: int        # 0=unlimited, 1=one-shot, N=limited
  │
  ├── Element (world data)
  │   ├── Biome
  │   └── Prop (+ capabilities + tags)
  │
  ├── Cutscene
  │   # display_name = title
  │   # short_description = summary
  │   # long_description = transcript
  │
  └── Journal Entry
      # display_name = title
      # short_description = summary
      # long_description = full entry
```

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Script (not GameAction) | "Script" = screenplay/instruction. Clear, evocative, not overloaded. |
| duration (not time) | "time" is vague. "duration" says what it is. |
| unlock_when removed from Script | Discovery = Event with max_count=1 and effect grant_script(). Recipe doesn't need to know HOW it's discovered. |
| Recipe.kind removed | No runtime behavior. Purely cosmetic classification. Can be optional editor metadata. |
| max_count (not count_max) | Adjective+noun reads better. |
| World flags = Event counts | A "flag" is an Event that has fired (count >= 1). No separate WorldFlags dict. |
| Milestones = Event (max_count=1) | One-shot events that trigger cutscenes, journal entries, recipe unlocks. |
| Cycles = Event (max_count=0) | Unlimited events (campfire burn cycle, decay, growth). |
| Cutscene + JournalEntry = Gear | First-class entities, not properties buried in dictionaries. |

## What Changes in Existing Code

| Change | Effort | Risk |
|--------|--------|------|
| Create gear.gd + script_base.gd | ~1h | Low (additive) |
| recipe.gd extends script_base | ~1h | Medium (26 .tres + tests) |
| Create event.gd | ~30min | Low (new) |
| Move unlock_when → Event .tres files | ~2h | Medium (10 events + DiscoveryWatcher) |
| Rename time → duration in 26 .tres + code | ~1h | Low (find/replace) |
| PropDef extends gear | ~1h | Medium (28 .tres) |
| Kind → optional/cosmetic | ~30min | Low |
| **Total** | **~7h** | **Medium** |

## Implementation Plan

**When:** First task of delivery-006 (after delivery-005b closes)
**Why not now:** delivery-005b is mid-flight with elfos running. Refactoring the base class mid-delivery risks merge conflicts and regressions.
**Dependencies:** None — purely structural refactor, all behavior preserved.

## Examples After Refactor

### Recipe (no unlock_when)
```yaml
eat_berry:
  # Gear fields
  id: "00001"
  display_name: "Eat Berry"
  short_description: "Consume a berry for nourishment"
  # Script fields
  conditions: []
  effects: [{ stat_delta: { hunger: 5 } }, { sound: crunch }]
  actions: [eat]
  duration: 0
  # Recipe fields
  inputs: [{ berry, 1 }]
  outputs: []
```

### Event (discovery)
```yaml
discover_eat_berry:
  # Gear fields
  id: "E0001"
  display_name: "Discover Eat Berry"
  short_description: "Learn that berries are edible"
  # Script fields
  conditions: [{ cataloged: berry }]
  effects: [{ grant_script: "00001" }]
  actions: []
  duration: 0
  # Event fields
  count: 0
  max_count: 1
```

### Event (milestone)
```yaml
milestone_first_shelter:
  id: "E0100"
  display_name: "First Shelter Built"
  short_description: "The crash survivor builds their first shelter"
  conditions: [{ event_count: { event: "shelter_placed", min: 1 } }]
  effects: [{ play_cutscene: "cs_first_shelter" }, { journal_entry: "J0001" }]
  actions: []
  duration: 0
  count: 0
  max_count: 1
```

### Cutscene
```yaml
cs_first_shelter:
  id: "CS001"
  display_name: "A Roof Over Your Head"
  short_description: "The survivor reflects on building their first shelter"
  long_description: "Camera pans from the hex grid to a cinematic view..."
  # + video_path, duration, skip_allowed, etc. (delivery-006 details)
```

### Journal Entry
```yaml
journal_first_shelter:
  id: "J0001"
  display_name: "Day 4 — Shelter"
  short_description: "I built something today."
  long_description: "The walls aren't much. Branches and fiber, mostly..."
```
