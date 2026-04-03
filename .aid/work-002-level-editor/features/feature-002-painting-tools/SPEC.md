# Painting Tools

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | Feature identified from REQUIREMENTS.md §5 F2, F5 | /aid-interview |

## Source

- REQUIREMENTS.md §5 F2 (Painting Tools), F5 (Resource Placement Detail)

## Description

The set of painting and placement tools for the Map Editor. Includes biome brush, elevation brush (+/- increment mode), resource placer (with auto-randomized position/rotation and manual adjustment via detail panel), structure placer, anomaly marker, spawn marker (exactly one per map), eraser, delete hex, and flood fill for contiguous same-biome regions.

## User Stories

- As Andre, I want to paint biomes by clicking and dragging so that I can quickly define terrain areas
- As Andre, I want to flood-fill a biome region so that I can paint large areas efficiently
- As Andre, I want to place resources on hexes with auto-randomized positions so that placements look natural
- As Andre, I want to fine-tune resource position/rotation via a detail panel so that I can adjust specific placements
- As Andre, I want to set exactly one spawn point so that the map has a valid player start

## Priority

Must

## Acceptance Criteria

- [ ] Given biome brush selected, when clicking and dragging across hexes, then all touched hexes update to the selected biome
- [ ] Given flood fill tool, when clicking a hex, then all contiguous hexes of the same biome change to the selected biome
- [ ] Given resource placer, when clicking a hex, then a resource is added with auto-randomized x, y (-1.0 to 1.0) and rotation (0-359)
- [ ] Given a placed resource, when clicking it, then a detail panel shows x, y, rotation fields for manual editing
- [ ] Given spawn marker tool, when placing a second spawn, then the first spawn is removed (exactly one enforced)
- [ ] Given eraser tool, when clicking a hex with resources/structures, then they are removed but the hex remains

---

## Technical Specification

{Added by /aid-specify — do not fill during interview.}
