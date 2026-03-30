# Hex Grid & World Generation

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-30 | Feature identified from REQUIREMENTS.md §5 F1, §9 AC1 | /aid-interview |

## Source

- REQUIREMENTS.md §5 F1 (Hex Grid & World Generation)
- REQUIREMENTS.md §9 AC1 (Hex Grid acceptance criteria)
- REQUIREMENTS.md §10 P0 — Foundation

## Description

The game world is a procedurally generated hex-tile map using axial/cube coordinates. Each playthrough creates a unique map of 200–300 tiles with three biome types (Grassland, Forest, Rocky) distributed via weighted rules and adjacency constraints, plus a scripted Crash Site near center as the player's starting zone. Tiles are hidden under fog of war until the player moves adjacent to them.

This is the foundational feature — everything else builds on top of the hex grid.

## User Stories

- As a player, I want each playthrough to generate a unique map so that exploration feels fresh every time
- As a player, I want to see different biome types with distinct visual identities so I can plan where to explore
- As a player, I want fog of war so that exploration feels like discovery, not just walking

## Priority

Must (P0 — Foundation)

## Acceptance Criteria

- [ ] Generate 3 different maps → all have 200–300 tiles
- [ ] All 3 biomes + Crash Site present in every map
- [ ] Crash Site within 3 hexes of center
- [ ] No two adjacent tiles with same biome exceed cluster of 5
- [ ] Fog tiles not visible until player moves adjacent

## Save Integration

This feature introduces the first save data: hex grid layout (tile positions, biome types, fog state). Auto-save at dawn serializes grid state to JSON via Godot FileAccess. Corrupt/missing save = fresh start without crash.

---

## Technical Specification

{Added by /aid-specify — do not fill during interview.}
