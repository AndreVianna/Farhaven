# File Discovery

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | Feature identified from REQUIREMENTS.md §5 F13; §7 | /aid-interview |

## Source

- REQUIREMENTS.md §5 F13 (File Discovery), §7 (Constraints)

## Description

Project root selection and automatic file discovery on startup. The user selects the Farhaven project root folder (containing `data/`, `scripts/`, `project.godot`). The editor auto-discovers maps (`data/maps/*.json`), resources (`data/resources/*.tres`), and biomes (`data/biomes/*.tres`). File handles are retained via File System Access API for direct save (Chrome/Edge). Fallback to standard file download for browsers without File System Access (Firefox/Safari).

## User Stories

- As Andre, I want to select the project folder once and have the editor find all data files so that I don't manually load each file
- As Andre, I want direct save (Ctrl+S) without download dialogs so that iteration is fast
- As Andre, I want a fallback download option so that the editor works in any browser if needed

## Priority

Must

## Acceptance Criteria

- [ ] Given project root selected, when discovery runs, then all .json maps, .tres resources, and .tres biomes are found and loaded
- [ ] Given Chrome/Edge with File System Access API, when saving, then files are written directly without download dialog
- [ ] Given Firefox/Safari, when saving, then files are offered as downloads
- [ ] Given a folder without project.godot, when selected, then the editor shows an error asking for the correct folder

---

## Technical Specification

{Added by /aid-specify — do not fill during interview.}
