# Import / Export

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | Feature identified from REQUIREMENTS.md §5 F6, F7; §9 AC1, AC3, AC6 | /aid-interview |

## Source

- REQUIREMENTS.md §5 F6 (Import/Export), F7 (Export Validation), §9 AC1, AC3, AC6

## Description

Map JSON import, export, and new map creation. Import loads existing chapter JSON files and renders the full map on canvas. Export saves to JSON in the exact format MapLoader expects, with validation before save. New Map starts from a blank canvas. Export validation checks: exactly one spawn point, no duplicate coordinates, all biome/resource/structure names valid, elevation 0-9, resource positions within range.

## User Stories

- As Andre, I want to load ch1.json and see it rendered so that I can edit existing maps
- As Andre, I want to export valid JSON that MapLoader accepts so that I can test maps immediately in-game
- As Andre, I want export validation to catch errors before save so that I don't ship broken data
- As Andre, I want to start a new blank map so that I can create chapters from scratch

## Priority

Must

## Acceptance Criteria

- [ ] Given ch1.json loaded then exported with no changes, then the output is semantically equivalent to the input (AC1)
- [ ] Given a new map with 50+ hexes, biomes, elevations, resources, structures, and spawn, when exported, then MapLoader loads it without errors (AC3)
- [ ] Given a map with no spawn point, when exporting, then a clear error message is shown and save is blocked (AC6)
- [ ] Given a map with duplicate coordinates, when exporting, then validation catches and reports the duplicates
- [ ] Given a map with an invalid biome name, when exporting, then validation catches and reports the invalid name

---

## Technical Specification

{Added by /aid-specify — do not fill during interview.}
