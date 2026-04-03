# Hex Canvas

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | Feature identified from REQUIREMENTS.md §5 F1, F8, F9 | /aid-interview |

## Source

- REQUIREMENTS.md §5 F1 (Hex Canvas), F8 (Undo/Redo), F9 (Keyboard Shortcuts)

## Description

The core hex grid canvas for the Map Editor tab. Renders a flat-top hex grid using axial coordinates (q, r) matching Farhaven's coordinate system. Each hex is colored by its biome using actual biome colors from loaded .tres files. Elevation is shown as a number overlay and brightness gradient. Cliff indicators highlight edges between hexes with elevation difference ≥ 2. Supports click-to-select, click-drag-to-paint, hover tooltips, zoom (scroll wheel), pan (middle-click or space+drag), and grid coordinate labels toggle. Includes undo/redo (50+ steps) and keyboard shortcuts for tool switching.

## User Stories

- As Andre, I want to see a visual hex grid colored by biome so that I can understand the map's shape and layout at a glance
- As Andre, I want to zoom and pan the canvas so that I can work on maps of any size
- As Andre, I want to undo/redo my edits so that I can experiment without fear of mistakes
- As Andre, I want hover tooltips showing hex data so that I can inspect tiles without switching tools

## Priority

Must

## Acceptance Criteria

- [ ] Given a loaded map, when hexes are rendered, then each hex displays the correct biome color from the loaded .tres files
- [ ] Given a hex with elevation > 0, when rendered, then the elevation value is shown as an overlay and brightness is adjusted
- [ ] Given two adjacent hexes with elevation difference ≥ 2, when rendered, then the edge between them is highlighted as a cliff indicator
- [ ] Given a canvas with hexes, when scrolling the mouse wheel, then the canvas zooms in/out smoothly
- [ ] Given a canvas, when middle-click-dragging or space+dragging, then the canvas pans
- [ ] Given 10 painting operations, when pressing Ctrl+Z 10 times, then all operations are undone; pressing Ctrl+Shift+Z 5 times redoes 5

---

## Technical Specification

{Added by /aid-specify — do not fill during interview.}
