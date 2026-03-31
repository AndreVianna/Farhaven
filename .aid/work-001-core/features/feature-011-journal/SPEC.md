# Journal & Narrative System

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | Feature identified from REQUIREMENTS.md §5 F14, §9 AC12 | /aid-interview |
| 2026-03-31 | Full technical specification — all sections | /aid-specify |
| 2026-03-31 | Fixes: placeholder art MVP, trigger cascade, pause freezes all systems | /aid-specify |

## Source

- REQUIREMENTS.md §5 F14 (Journal System)
- REQUIREMENTS.md §9 AC12 (Journal acceptance criteria)

## Description

The Journal is the astronaut's logbook and the emotional heart of the game. It has two sections: Story Timeline (unlocked cutscenes in chronological order) and Catalog (scanner discoveries). Scanning anomalies triggers cutscenes and adds entries to both sections. Cutscenes in Chapter 1 use static comic panels. The Journal IS the purpose -- the real loop is explore -> scan -> catalog -> discover story.

## User Stories

- As a player, I want a journal that tells me the story I'm uncovering
- As a player, I want to revisit cutscenes I've already seen
- As a player, I want scanning an anomaly to feel like a narrative reward

## Priority

Must (P0 -- Story Hook)

## Acceptance Criteria

- [ ] Journal accessible via UI button
- [ ] Story Timeline shows unlocked cutscenes in chronological order
- [ ] Catalog section shows scanner discoveries
- [ ] Scanning anomaly adds entry to both Catalog and Story Timeline
- [ ] Cutscene plays on first anomaly scan (placeholder comic panel)

## Save Integration

Unlocked cutscene IDs, seen/unseen status, story progress markers. Chapter ID for future extensibility.

---

## Technical Specification

### Data Model

#### JournalEntry (Resource)

Static definition for each story event. Loaded from data files at startup.

| Property | Type | Description |
|----------|------|-------------|
| `entry_id` | `StringName` | Unique ID: `&"crash_landing"`, `&"first_anomaly"`, `&"strange_signal"` |
| `title` | `String` | Display title: "Day 1: Crash Landing" |
| `description` | `String` | Short narrative text shown in timeline |
| `day_hint` | `int` | Approximate day when this typically unlocks (for ordering, not gating) |
| `cutscene_id` | `StringName` | ID of associated cutscene (`&""` if no cutscene) |
| `trigger_type` | `JournalTrigger` | What unlocks this entry |
| `trigger_data` | `Dictionary` | Trigger-specific parameters (see trigger types below) |
| `chapter_id` | `StringName` | Which chapter this entry belongs to (`&"ch1"`) |

#### JournalTrigger Enum

```gdscript
enum JournalTrigger {
    GAME_START,       # unlocked automatically at game start
    ANOMALY_SCAN,     # unlocked when a specific anomaly is scanned
    DAY_REACHED,      # unlocked when day_count reaches a threshold
    CATALOG_COUNT,    # unlocked when catalog discovery count reaches threshold
}
```

#### Trigger Data by Type

| Trigger Type | trigger_data | Example |
|-------------|-------------|---------|
| `GAME_START` | `{}` | Crash landing — always unlocked |
| `ANOMALY_SCAN` | `{ "anomaly_id": StringName }` | `{ "anomaly_id": &"anomaly_ch1_001" }` |
| `DAY_REACHED` | `{ "day": int }` | `{ "day": 3 }` — "Day 3: Strange Signal" |
| `CATALOG_COUNT` | `{ "count": int }` | `{ "count": 10 }` — "Cataloging the World" |

#### Chapter 1 Journal Entries

```gdscript
# Defined in data/journal/ch1_entries.tres
[
  {
    entry_id = &"crash_landing",
    title = "Day 1: Crash Landing",
    description = "You wake up next to a wrecked ship on an alien planet...",
    day_hint = 1,
    cutscene_id = &"cs_crash_landing",
    trigger_type = GAME_START,
    trigger_data = {},
    chapter_id = &"ch1",
  },
  {
    entry_id = &"strange_signal",
    title = "Day 3: Strange Signal",
    description = "Your scanner picks up an unusual reading from the far side of the map...",
    day_hint = 3,
    cutscene_id = &"",  # no cutscene, just journal text
    trigger_type = DAY_REACHED,
    trigger_data = { "day": 3 },
    chapter_id = &"ch1",
  },
  {
    entry_id = &"first_anomaly",
    title = "The Ruins",
    description = "This planet was supposed to be uninhabited. These structures say otherwise...",
    day_hint = 7,
    cutscene_id = &"cs_first_anomaly",
    trigger_type = ANOMALY_SCAN,
    trigger_data = { "anomaly_id": &"anomaly_ch1_001" },
    chapter_id = &"ch1",
  },
]
```

**3 journal entries for Chapter 1.** Architecture supports N entries per chapter.
The first anomaly entry is the narrative cliffhanger that hooks the player for Chapter 2.

#### CutsceneDefinition (Resource)

Static data for each cutscene. Chapter 1 uses static comic panels.

| Property | Type | Description |
|----------|------|-------------|
| `cutscene_id` | `StringName` | Unique ID matching `JournalEntry.cutscene_id` |
| `panels` | `Array[CutscenePanel]` | Ordered list of comic panels |
| `chapter_id` | `StringName` | Chapter ownership |

#### CutscenePanel (Resource)

| Property | Type | Description |
|----------|------|-------------|
| `image` | `Texture2D` | Panel image. **MVP: placeholder colored rect + caption text overlay (no art dependency). Final art pipeline TBD (AI-generated illustrations or manual).** |
| `caption` | `String` | Optional text below panel ("You see ancient markings...") |
| `duration` | `float` | Auto-advance time in seconds (0 = wait for tap) |

#### Cutscene Panel Asset Spec

**MVP:** Placeholder panels — solid color background + caption text rendered at runtime.
No external image files needed. `CutscenePanel.image` can be null; the viewer renders
`CutscenePanel.caption` on a colored background. This unblocks implementation with zero
art dependency.

**Post-MVP art target:**
- Format: WebP (lossy, ~80% quality) — best size/quality for mobile
- Resolution: 900×1200px (portrait, centered on 1080×1920 screen with padding)
- Source: TBD (AI-generated illustrations or manual — 2D art pipeline not yet defined,
  separate from 3D Sloyd/Tripo pipeline)
- Per cutscene: 3-5 panels. Chapter 1: 2 cutscenes × ~4 panels = ~8 images
- Estimated size: ~8 images × ~150KB each = ~1.2MB total

#### JournalSystem Properties (on Node)

| Property | Type | Description |
|----------|------|-------------|
| `_all_entries` | `Array[JournalEntry]` | All entries for current chapter, loaded from data |
| `_unlocked` | `Dictionary[StringName, bool]` | entry_id → true if unlocked |
| `_seen_cutscenes` | `Dictionary[StringName, bool]` | cutscene_id → true if watched |
| `_active_cutscene_id` | `StringName` | Currently playing cutscene (`&""` if none) |

#### Signals

```gdscript
signal journal_entry_unlocked(entry_id: StringName)
signal cutscene_started(cutscene_id: StringName)
signal cutscene_ended(cutscene_id: StringName)
signal cutscene_panel_advanced(panel_index: int)
```

#### Save Data

```json
{
  "journal": {
    "unlocked_entries": ["crash_landing", "strange_signal"],
    "seen_cutscenes": ["cs_crash_landing"],
    "chapter_id": "ch1"
  }
}
```

Only unlocked entry IDs and seen cutscene IDs saved. Static definitions loaded
from data files. `chapter_id` for future extensibility.

#### Cross-Feature Dependencies

| What | Source |
|------|--------|
| `entry_cataloged(entry_id, ANOMALY)` — anomaly scan trigger | feature-003 (ScannerSystem) |
| `day_started(day_number)` — day-reached trigger | feature-008 (DayNightCycle) |
| Catalog discovery count — catalog_count trigger | feature-003 (Catalog.get_discovery_count()) |

| What | Consumer |
|------|----------|
| `get_save_data()` / `load_save_data()` | feature-008 (SaveManager) |
| Journal UI data (unlocked entries, cutscene replay) | feature-012 (HUD — Journal panel) |

---

### Feature Flow

#### Trigger Evaluation

JournalSystem listens to multiple signals and evaluates triggers:

**1. Game start (`_ready` or explicit init):**

```
JournalSystem._ready():
  │
  ├─ Load all entries from data/journal/ch1_entries.tres
  │
  ├─ For each entry with trigger_type == GAME_START:
  │     if NOT _unlocked[entry.entry_id]:
  │       unlock(entry)
  │
  └─ Done (crash_landing entry unlocked on first play)
```

**2. Anomaly scanned (`entry_cataloged` from feature-003):**

```
ScannerSystem emits entry_cataloged(entry_id, CatalogCategory.ANOMALY)
  │
  ├─ JournalSystem receives signal
  │
  ├─ For each entry with trigger_type == ANOMALY_SCAN:
  │     if entry.trigger_data.anomaly_id == entry_id
  │        AND NOT _unlocked[entry.entry_id]:
  │
  │       unlock(entry)
  │       if entry.cutscene_id != &"":
  │         play_cutscene(entry.cutscene_id)
  │
  └─ Done
```

**3. Day reached (`day_started` from feature-008):**

```
DayNightCycle emits day_started(day_number)
  │
  ├─ JournalSystem receives signal
  │
  ├─ For each entry with trigger_type == DAY_REACHED:
  │     if day_number >= entry.trigger_data.day
  │        AND NOT _unlocked[entry.entry_id]:
  │
  │       unlock(entry)
  │       if entry.cutscene_id != &"":
  │         play_cutscene(entry.cutscene_id)
  │
  └─ Done
```

**4. Catalog count (`entry_cataloged` — any category):**

```
ScannerSystem emits entry_cataloged(entry_id, category)
  │
  ├─ JournalSystem receives signal
  │
  ├─ current_count = Catalog.get_discovery_count()
  │
  ├─ For each entry with trigger_type == CATALOG_COUNT:
  │     if current_count >= entry.trigger_data.count
  │        AND NOT _unlocked[entry.entry_id]:
  │
  │       unlock(entry)
  │
  └─ Done
```

**Trigger cascade rule:** ALL trigger types are evaluated on each signal, not just
the matching type. A single `entry_cataloged` signal could unlock both an
`ANOMALY_SCAN` entry (matched by anomaly_id) AND a `CATALOG_COUNT` entry (threshold
crossed). The evaluation loop runs over all entries, checking all trigger types in
one pass. If multiple entries unlock in one pass, all `journal_entry_unlocked` signals
fire, and cutscenes queue (play sequentially, not simultaneously).

#### Unlock Flow

```
func unlock(entry: JournalEntry) -> void:
  │
  ├─ _unlocked[entry.entry_id] = true
  ├─ Emit journal_entry_unlocked(entry.entry_id)
  │     → HUD (feature-012): brief notification "New journal entry!"
  │     → Journal panel: refresh entry list if open
  │
  └─ Done
```

#### Cutscene Playback Flow

```
func play_cutscene(cutscene_id: StringName) -> void:
  │
  ├─ Load CutsceneDefinition from data/journal/cutscenes/
  │
  ├─ _active_cutscene_id = cutscene_id
  ├─ Emit cutscene_started(cutscene_id)
  │     → CutsceneViewer (UI): show fullscreen overlay, load first panel
  │     → Game pauses (process_mode on CutsceneViewer = ALWAYS,
  │       game tree set to pause — cutscenes are the ONE thing that pauses)
  │
  ├─ Panel sequence:
  │     For each panel in cutscene.panels:
  │       Display panel.image + panel.caption
  │       if panel.duration > 0:
  │         Auto-advance after duration
  │       else:
  │         Wait for player tap to advance
  │       Emit cutscene_panel_advanced(panel_index)
  │
  ├─ On last panel tap/advance:
  │     _seen_cutscenes[cutscene_id] = true
  │     _active_cutscene_id = &""
  │     Emit cutscene_ended(cutscene_id)
  │       → CutsceneViewer: hide overlay
  │       → Game unpauses
  │
  └─ Done
```

**Cutscenes ARE the one thing that pauses the game.** All other panels (inventory,
crafting, build, catalog) run with the game continuing. Cutscenes are narrative
moments — they deserve the player's full attention.

**Pause mechanism:** `get_tree().paused = true` on cutscene start, `false` on end.
CutsceneViewer uses `process_mode = PROCESS_MODE_ALWAYS` to stay responsive while
paused. All other nodes (including DayNightCycle autoload) use the default
`PROCESS_MODE_PAUSABLE` — they freeze automatically. This means:
- Day/night phase timer stops during cutscenes (time doesn't pass)
- Fauna movement stops (no surprise attacks during story)
- Survival stat depletion stops (no dying during cutscene)
- Auto-interaction stops (no gathering while watching)
No special handling needed per system — Godot's pause tree handles it.

**Cutscene replay from Journal:** Player taps a seen cutscene entry in the Story
Timeline → `play_cutscene(cutscene_id)` again. Same flow, same pause.

#### Chapter 1 Narrative Arc

| Entry | Trigger | Day Hint | Cutscene | Narrative |
|-------|---------|----------|----------|-----------|
| Crash Landing | GAME_START | Day 1 | cs_crash_landing | Wake up, broken ship, alien world |
| Strange Signal | DAY_REACHED(3) | Day 3 | — (text only) | Scanner detects anomaly in distance, directs exploration |
| The Ruins | ANOMALY_SCAN(anomaly_ch1_001) | Day 7+ | cs_first_anomaly | Ancient structures, signs of civilization, cliffhanger |

The "Strange Signal" entry at Day 3 serves as a narrative breadcrumb — it tells
the player "there's something out there" and guides them toward the anomaly.
The anomaly scan is the payoff — the Chapter 1 cliffhanger.

---

### Layers & Components

#### Scene Tree

```
Main (Node)
  └─ World (Node3D)
       ├─ (all world renderers from features 001-010)
       ├─ Player (Node3D)
       │    ├─ (all player child nodes from features 002-009)
       │    └─ JournalSystem (Node)             ← THIS FEATURE
       └─ Camera3D
  └─ (CanvasLayers: Joystick, HUD, ScreenFade)
  └─ CutsceneViewer (CanvasLayer)               ← THIS FEATURE (above all, process_mode ALWAYS)
       ├─ Background (ColorRect)                 ← fullscreen black/dark
       ├─ PanelImage (TextureRect)               ← comic panel image
       ├─ CaptionLabel (Label)                   ← text below panel
       └─ TapPrompt (Label)                      ← "Tap to continue" (when duration=0)
  └─ HUD (CanvasLayer)                          [feature-012]
       ├─ JournalButton (TextureButton)         ← THIS FEATURE (bottom-right, 64×64px)
       └─ JournalPanel (PanelContainer)         ← THIS FEATURE (bottom drawer)
            ├─ SectionTabs (TabContainer)
            │    ├─ TimelineTab (ScrollContainer > VBoxContainer)
            │    └─ CatalogTab (label: "See Catalog panel")
            └─ (header + close)
```

**CatalogTab in JournalPanel:** The Journal's Catalog section is a redirect — it
tells the player to use the Catalog panel (feature-003). The Journal's main value
is the Story Timeline. Catalog is accessible via its own dedicated panel and button.
No duplication of UI.

#### File Structure

```
scripts/
  journal/
    journal_system.gd       # Node (child of Player) — trigger eval, unlock,
                              #   cutscene orchestration, save/load

scenes/
  ui/
    cutscene_viewer.tscn    # CanvasLayer — fullscreen comic panel viewer
    journal_panel.tscn      # PanelContainer — bottom drawer

ui/
  cutscene_viewer.gd        # Control — panel display, tap advance, auto-advance
  journal_panel.gd          # Control — story timeline list, cutscene replay tap
  journal_entry_ui.gd       # Control — single timeline entry (title, desc, replay button)

data/
  journal/
    ch1_entries.tres        # Array of JournalEntry resources for Chapter 1
    cutscenes/
      cs_crash_landing.tres # CutsceneDefinition — panels for crash landing
      cs_first_anomaly.tres # CutsceneDefinition — panels for first anomaly
```

#### Component Responsibilities

| Component | Responsibility | Depends On |
|-----------|---------------|------------|
| `journal_system.gd` | Child Node of Player. Trigger evaluation (listens to entry_cataloged, day_started). Unlock logic. Cutscene orchestration (play, track seen, replay). `get_save_data()` / `load_save_data()`. | `ScannerSystem` feature-003 (`entry_cataloged` signal, `Catalog.get_discovery_count()`), `DayNightCycle` feature-008 (`day_started` signal) |
| `cutscene_viewer.gd` | CanvasLayer above all. Fullscreen overlay. Displays panels sequentially. Handles tap-to-advance and auto-advance. Pauses game tree on show, unpauses on hide. `process_mode = PROCESS_MODE_ALWAYS`. | `JournalSystem` (`cutscene_started`, `cutscene_ended` signals) |
| `journal_panel.gd` | Control on JournalPanel. Bottom drawer. Shows unlocked Story Timeline entries sorted by `day_hint`. Tap on entry with cutscene → replay. `panel_opened` for mutual exclusion. | `JournalSystem` (unlocked entries, `journal_entry_unlocked` signal) |
| `journal_entry_ui.gd` | Single timeline entry. Title + description + optional "Replay" button (if has cutscene + seen). | `JournalSystem` (entry data) |

#### Signal Wiring — Complete

```
ScannerSystem (feature-003)                  journal_system.gd
  entry_cataloged(entry_id, category)    ──►  evaluate ANOMALY_SCAN + CATALOG_COUNT triggers

DayNightCycle (feature-008)                  journal_system.gd
  day_started(day_number)                ──►  evaluate DAY_REACHED triggers

journal_system.gd                            cutscene_viewer.gd
  cutscene_started(cutscene_id)          ──►  show overlay, load panels, pause game
  cutscene_ended(cutscene_id)            ──►  hide overlay, unpause game

journal_system.gd                            journal_panel.gd
  journal_entry_unlocked(entry_id)       ──►  refresh timeline + show notification

journal_system.gd                            feature-012 (HUD)
  journal_entry_unlocked(entry_id)       ──►  brief "New journal entry!" notification
```

#### Panel Mutual Exclusion

5-panel list:
1. Inventory (feature-005)
2. Crafting (feature-006)
3. Build (feature-009)
4. Catalog (feature-003)
5. **Journal (this feature)**

Symmetric `panel_opened` signal pattern.

**Cutscene viewer is NOT a panel** — it's a fullscreen overlay above everything,
not a bottom drawer. It doesn't participate in panel mutual exclusion. It pauses
the game and occupies the full screen.

#### Journal Panel — Open/Close

- **Open:** Tap JournalButton (HUD, 64×64px) → drawer slides up.
  Game continues running — no pause (same as all panels).
  ~55% screen visible above.
- **Close:** JournalButton again, X button, or tap game area above.
- Mutual exclusion with 4 other panels.
- Shows unlocked entries sorted by `day_hint` (chronological order).

### UI Specs

#### Journal Panel Layout — Portrait 1080×1920

```
┌──────────────────────────┐
│      (game world visible)│  ← ~55%
│                          │
├──────────────────────────┤
│  JOURNAL             [X] │
│ [Timeline] [Catalog→]    │  ← tabs (Catalog redirects to Catalog panel)
│ ─────────────────────────│
│ ┌──────────────────────┐ │
│ │ Day 1: Crash Landing │ │  ← entry with cutscene
│ │ You wake up next to..│ │
│ │             [REPLAY]  │ │  ← replay button (if seen)
│ └──────────────────────┘ │
│ ┌──────────────────────┐ │
│ │ Day 3: Strange Signal│ │  ← text-only entry (no cutscene)
│ │ Your scanner picks...│ │
│ └──────────────────────┘ │
│ ┌──────────────────────┐ │
│ │ ??? (locked)         │ │  ← not yet unlocked, greyed placeholder
│ └──────────────────────┘ │  ← ~45% height, scrollable
└──────────────────────────┘
```

#### Timeline Entry States

| State | Visual | Interaction |
|-------|--------|-------------|
| Unlocked, has cutscene, seen | Full brightness, title + desc + REPLAY button | Tap REPLAY → play cutscene |
| Unlocked, has cutscene, NOT seen | Full brightness + "NEW" badge, title + desc | Entry auto-plays cutscene on unlock (first time) |
| Unlocked, no cutscene | Full brightness, title + desc | No interaction (read-only) |
| Locked | Greyed "???" placeholder | No interaction |

**Locked entries:** Show "???" with a greyed style. Player knows more entries exist
but can't see them. Creates curiosity — "what happens next?" Number of locked entries
visible = total entries for chapter minus unlocked. Doesn't reveal titles.

#### Cutscene Viewer Layout — Fullscreen

```
┌──────────────────────────┐
│                          │
│  ┌────────────────────┐  │  ← black background
│  │                    │  │
│  │   [Comic Panel]    │  │  ← panel image, centered, max 80% width
│  │                    │  │
│  └────────────────────┘  │
│                          │
│  "You see ancient        │  ← caption text below panel
│   markings on the wall"  │
│                          │
│       Tap to continue    │  ← prompt (when duration=0)
│                          │
└──────────────────────────┘
```

- **Fullscreen** — covers everything (above HUD, above ScreenFade)
- **Black/dark background** — cinematic feel
- **Panel image:** centered, max ~80% screen width, aspect ratio preserved
- **Caption:** below image, centered, readable font, warm color on dark bg
- **Tap prompt:** "Tap to continue" appears for manual-advance panels. Hidden during
  auto-advance (timer panels).
- **Tap anywhere** to advance to next panel (when duration=0).
- **Auto-advance** panels progress automatically after `panel.duration` seconds.
- **Last panel tap/advance** → cutscene ends, viewer hides, game unpauses.

#### Touch Targets

- JournalButton (HUD): 64×64px
- Timeline entries: ~100px height
- REPLAY button: ~80×48px
- Cutscene tap-to-advance: fullscreen (entire screen is the target)
- Close (X): 48×48px

#### Panel Consistency

Same bottom-drawer pattern for JournalPanel. Cutscene viewer is a separate fullscreen
overlay — different from panel pattern, used only for narrative moments.

---

### Mobile Specs

#### Performance

| Operation | Cost | When |
|-----------|------|------|
| Trigger evaluation | O(e): e = journal entries for chapter (~3 for Ch1) | On entry_cataloged, day_started |
| Cutscene load | O(p): p = panels in cutscene (~3-5 per cutscene) | On cutscene play (rare — max 2 in Ch1) |
| Panel display | 1 Texture2D swap | Per panel advance |

Trigger evaluation runs on signal receipt — not per frame. Cost is trivial
at 3 entries with simple comparisons.

#### Draw Calls

| Component | Draw Calls | Notes |
|-----------|-----------|-------|
| CutsceneViewer | 0 | CanvasLayer UI (fullscreen overlay) |
| JournalPanel | 0 | CanvasLayer UI (bottom drawer) |
| **Total** | **0** | Running total unchanged: ~24 |

#### Touch Interaction

- JournalButton: 64×64px, always visible in HUD
- Timeline entries: ~100px rows in bottom drawer
- Cutscene: tap anywhere on fullscreen to advance
- All standard Godot UI Control handling

#### Platform Differences

None. Godot UI Controls + Texture2D loading identical on iOS/Android.
`user://` save path platform-appropriate. Comic panel images bundled in APK/IPA.

#### Memory

- JournalEntry definitions: ~3 entries × ~200 bytes = negligible
- CutsceneDefinition: ~2 cutscenes × ~5 panels × ~100 bytes = negligible
- Panel images: MVP = 0 bytes (placeholder rendered at runtime from caption text).
  Post-MVP: ~8 WebP images × ~150KB = ~1.2MB total.
- `_unlocked` + `_seen_cutscenes` Dictionaries: ~10 entries = negligible
