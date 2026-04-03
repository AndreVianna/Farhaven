# Command Infrastructure

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | Extracted from feature-001 — undo/redo and keyboard shortcuts are cross-cutting foundation | Lola review |

## Source

- REQUIREMENTS.md §5 F8 (Undo/Redo), F9 (Keyboard Shortcuts)

## Description

The command pattern infrastructure that underpins ALL editing operations across all three tabs. Every user action (paint hex, place resource, change biome color, edit .tres field, etc.) is wrapped in a Command object with execute/undo methods. This enables undo/redo with a 50+ step history stack. Also includes the keyboard shortcut system for tool switching (B for biome, E for elevation, R for resource, S for structure, etc.) and Ctrl+S for save.

**Why this is separate:** Undo/redo defines the data flow architecture. Every other feature's implementation depends on how commands are structured. Getting this wrong contaminates every feature. Getting it right makes everything else clean.

## User Stories

- As Andre, I want to undo/redo any editing operation across all tabs so that I can experiment without fear
- As Andre, I want keyboard shortcuts for fast tool switching so that editing flow is uninterrupted
- As Andre, I want Ctrl+S to save so that saving is muscle memory

## Priority

Must

## Acceptance Criteria

- [ ] Given 10 painting operations, when pressing Ctrl+Z 10 times, then all operations are undone in reverse order; pressing Ctrl+Shift+Z 5 times redoes 5
- [ ] Given a resource created in the Resource Editor, when pressing Ctrl+Z, then the resource is removed (undo works across tabs)
- [ ] Given a biome color changed in the Biome Editor, when pressing Ctrl+Z, then the color reverts and the map canvas updates
- [ ] Given more than 50 operations performed, when the 51st is executed, then the oldest command is dropped from history
- [ ] Given the keyboard shortcut B pressed, then the biome brush tool is activated
- [ ] Given Ctrl+S pressed, then all modified files are saved via File System Access API

---

## Technical Specification

{Added by /aid-specify — do not fill during interview.}
