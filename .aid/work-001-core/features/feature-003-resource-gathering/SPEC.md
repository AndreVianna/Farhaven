# Resource Gathering

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-30 | Feature identified from REQUIREMENTS.md §5 F3, §9 AC3 | /aid-interview |

## Source

- REQUIREMENTS.md §5 F3 (Resource Gathering)
- REQUIREMENTS.md §9 AC3 (Gathering acceptance criteria)
- REQUIREMENTS.md §10 P0 — Core Loop

## Description

Players gather resources by tapping resource nodes on adjacent hex tiles. Resources are tool-gated: bare hands yield basic materials (Wood, Berries, Fiber), while crafted tools (Stone Axe, Stone Pickaxe) unlock higher-tier resources (thick trees, Ore, Crystals) and speed up gathering. Resource nodes deplete after a number of gathers and visually change. Depleted resources regenerate on tiles outside the player's visible range after a type-specific timer; resources never respawn while the tile is visible.

## User Stories

- As a player, I want to gather resources by tapping so the interaction is simple and satisfying
- As a player, I want better tools to unlock new resources so I feel progression
- As a player, I want resources to respawn off-screen so I'm never permanently stuck

## Priority

Must (P0 — Core Loop)

## Acceptance Criteria

- [ ] Tap tree with bare hands → +1 Wood in inventory
- [ ] Tap ore with bare hands → nothing happens (tool-gated)
- [ ] Tap ore with Stone Pickaxe equipped → +1 Ore
- [ ] Resource node depletes after N gathers and visually changes
- [ ] Depleted resource on non-visible tile regenerates after type-specific timer

## Save Integration

Adds per-tile resource state (type, remaining gathers, respawn timers) to save data.

---

## Technical Specification

{Added by /aid-specify — do not fill during interview.}
