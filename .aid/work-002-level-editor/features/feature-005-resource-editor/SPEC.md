# Resource Editor

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | Feature identified from REQUIREMENTS.md §5 F10, F12; §9 AC2, AC4 | /aid-interview |

## Source

- REQUIREMENTS.md §5 F10 (Resource Editor), F12 (.tres Parser), §9 AC2, AC4

## Description

The Resource Editor tab for managing `data/resources/*.tres` ResourceDef files. Provides a list view of all resources with key properties, create/edit/delete operations with form UI, live mesh color swatch preview, and deletion validation (warns if any map references the resource). Reads and writes .tres files with round-trip safety — preserving uid, ext_resource, and script lines.

## User Stories

- As Andre, I want to see all resource definitions in a list so that I can browse and manage them
- As Andre, I want to create new resources with a form so that I don't have to write .tres files by hand
- As Andre, I want to edit resource properties and see a color preview so that I can tune visual appearance
- As Andre, I want deletion to warn me if a map uses the resource so that I don't break existing maps

## Priority

Must

## Acceptance Criteria

- [ ] Given a resource .tres loaded and saved with no changes, then the file preserves uid, ext_resource, and script lines exactly (AC2)
- [ ] Given a new resource created, when saved, then a valid .tres file appears in data/resources/ and the resource shows in the Map Editor palette (AC4)
- [ ] Given a resource in use by a map, when attempting to delete, then a warning dialog shows which map references it
- [ ] Given a resource edit, when saved, then re-parsing the written file matches the in-memory model

---

## Technical Specification

{Added by /aid-specify — do not fill during interview.}
