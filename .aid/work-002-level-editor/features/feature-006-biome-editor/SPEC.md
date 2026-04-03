# Biome Editor

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | Feature identified from REQUIREMENTS.md §5 F11, F12; §9 AC2, AC5 | /aid-interview |
| 2026-04-03 | Updated resource_table field names to match biome_data.gd; added F15/AC9 references | /aid-interview (cross-reference) |

## Source

- REQUIREMENTS.md §5 F11 (Biome Editor), F12 (.tres Parser), F15 (Import Validation), §9 AC2, AC5, AC9

## Description

The Biome Editor tab for managing `data/biomes/*.tres` BiomeData files. Provides a list view with color swatches and resource summaries, create/edit/delete operations, color picker for base color and variations, resource table editor, and deletion validation (warns if any map tile uses the biome). Editing biome color updates the Map Editor canvas in real-time.

**Editable fields** (from `biome_data.gd`): `biome_name` (String), `elevation_range` (Vector2i), `color` (Color — with color picker), `color_variations` (Array[Color]).

**Resource table editor:** Each entry has `type` (String — dropdown from Resource Editor), `chance` (float), `min_amount` (int), `max_amount` (int), `tool_required` (String). Add/remove rows.

## User Stories

- As Andre, I want to see all biomes in a list with color swatches so that I can browse definitions visually
- As Andre, I want to edit biome colors with a color picker and see the map update live so that I can tune the look in real-time
- As Andre, I want to edit biome resource tables so that I can define what resources spawn in each biome
- As Andre, I want deletion to warn me if map tiles use the biome so that I don't break existing maps

## Priority

Must

## Acceptance Criteria

- [ ] Given a biome .tres loaded and saved with no changes, then the file preserves uid, ext_resource, and script lines exactly (AC2)
- [ ] Given a biome color changed in the editor, when switching to Map Editor, then all hexes of that biome show the new color immediately (AC5)
- [ ] Given a biome in use by map tiles, when attempting to delete, then a warning dialog shows the tile count
- [ ] Given a resource table edit, when saved, then the .tres file contains the correct resource_table array
- [ ] Given a malformed .tres file in data/biomes/, when loaded, then the editor shows a clear error message and skips the file without crashing (AC9)

---

## Technical Specification

{Added by /aid-specify — do not fill during interview.}
