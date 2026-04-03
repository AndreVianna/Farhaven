# Palette & Sidebar

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | Feature identified from REQUIREMENTS.md §5 F3, F4 | /aid-interview |

## Source

- REQUIREMENTS.md §5 F3 (Palette / Sidebar), F4 (Map Properties)

## Description

The sidebar panel showing biome palette (color swatches from .tres files), resource palette (all ResourceDef types), structure palette, active tool indicator, and biome statistics (tile count per biome, total tiles, resource count). Also includes map properties editing (chapter ID, chapter name, spawn point highlight). Palettes are live — changes in Resource/Biome Editor tabs update the Map Editor palette immediately.

## User Stories

- As Andre, I want to see biome swatches with actual game colors so that I can pick biomes visually
- As Andre, I want to see resource and structure lists populated from game data so that I only place valid types
- As Andre, I want biome statistics so that I can balance the map composition
- As Andre, I want to set the chapter ID and name so that export metadata is correct

## Priority

Must

## Acceptance Criteria

- [ ] Given loaded biome .tres files, when the palette renders, then each biome shows its actual color swatch and name
- [ ] Given a new resource created in the Resource Editor tab, when switching to Map Editor, then the resource appears in the resource palette
- [ ] Given a map with hexes, when viewing statistics, then tile count per biome and total tile/resource counts are accurate
- [ ] Given map properties, when editing chapter ID/name, then the values are included in exported JSON

---

## Technical Specification

{Added by /aid-specify — do not fill during interview.}
