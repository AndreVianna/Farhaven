# Cutscene Vision — Hybrid Animation + Game

**Status:** Design seed
**Created:** 2026-04-09
**Author:** Andre Vianna (concept) + Lola (documentation)

## The Idea

Farhaven becomes a **hybrid of animation and game**. Cutscenes are generated using AI video generation tools (Sora, Kling, Runway, etc.) and stitched into the gameplay at narrative moments. The game world and the cinematic world are the SAME world — what the player builds, discovers, and survives appears in the cutscenes.

This is the game's **key differentiator.** Few indie mobile games use AI-generated cinematics. None stitch them to world state.

## Two Levels of Ambition

### Level A — MVP (delivery-006 scope)

Pre-generated AI video cutscenes, shipped with the game as MP4 files.

- Cutscenes created offline using AI video generation tools
- Triggered by gameplay events: anomaly discovered, first night survived, chapter milestones
- Played fullscreen via a `CutsceneManager` autoload
- Videos are FIXED — they don't change based on world state
- Trigger mechanism already exists: `CatalogableCap.properties.cutscene_id`

**What's needed:**
- `CutsceneManager` autoload: receives `cutscene_id`, loads + plays video, emits `cutscene_finished`
- `data/cutscenes/` directory with MP4 files
- Trigger wiring: Catalog.entry_cataloged → check for cutscene_id → play
- Journal entries that unlock alongside cutscenes (already have `journal_entry_id` in CatalogableCap.properties)
- UI: fullscreen video player with skip button

**Art pipeline:** Andre generates cutscenes using AI video tools with prompts that describe the Farhaven world consistently. Style guide needed for visual consistency across videos.

### Level B — Vision (future R&D)

Dynamic cutscenes generated at runtime based on world state.

- Video generation API call with prompt built from current game state:
  - Biome the player is in
  - Structures they've built (campfire, shelter, etc.)
  - Time of day / weather
  - What they've discovered
  - Inventory state (armed? starving? thriving?)
- Each playthrough generates UNIQUE cutscenes
- Requires: API access, acceptable latency, prompt engineering, caching strategy
- Could be cloud-generated + cached, or on-device (future hardware)

**Problems to solve (discussed but deferred):**
- Latency: video generation takes seconds to minutes — need loading screen or pre-generation
- Cost: API calls per cutscene per player — pricing model
- Consistency: AI video tools can produce inconsistent styles — need style anchoring
- Storage: generated videos need caching (don't regenerate the same state twice)
- Offline: mobile games need to work offline — Level B may require wifi

## Existing Model Support

The data model already has cutscene hooks:

```gdscript
# In CatalogableCap.properties (on anomaly PropDefs):
properties = {
    "cutscene_id": &"cs_first_anomaly",
    "journal_entry_id": &"anomaly_ch1_001"
}
```

Trigger chain: player scans anomaly → Catalog.entry_cataloged → check properties.cutscene_id → CutsceneManager.play(id) → video plays → cutscene_finished → journal unlocks

## Why This Is Differentiating

1. **AI-generated cinematics in a mobile indie game** — most indie games use static art or pixel animation. Cinematic-quality cutscenes are AAA territory. AI video generation collapses this gap.
2. **Narrative stitching** — the cutscene world IS the game world. Player agency in gameplay bleeds into the cinematic. Even in Level A (pre-generated), the prompts can reference the canonical chapter progression.
3. **Low marginal cost** — generating a 15-second cutscene with AI tools is cheaper than hiring an animator. Enables more narrative moments without art team scaling.
4. **Emotional impact** — survival games rarely have cinematic moments. The contrast between hex-grid gameplay and cinematic beauty creates an emotional gut-punch at the right narrative beats.

## Decision: Andre, 2026-04-09

- Level A goes into delivery-006 (The Story — Journal + Narrative)
- Level B is R&D, not scheduled
- CutsceneManager design will happen during delivery-006 planning
- AI video generation experiments can start anytime (Andre generates, Lola prompts)
