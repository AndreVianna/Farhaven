# Resource Editor

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | Feature identified from REQUIREMENTS.md §5 F10, F12; §9 AC2, AC4 | /aid-interview |
| 2026-04-03 | Updated field list to match actual resource_def.gd; added F15/AC9 references | /aid-interview (cross-reference) |

## Source

- REQUIREMENTS.md §5 F10 (Resource Editor), F12 (.tres Parser), F15 (Import Validation), §9 AC2, AC4, AC9

## Description

The Resource Editor tab for managing `data/resources/*.tres` ResourceDef files. Provides a list view of all resources with key properties, create/edit/delete operations with form UI, and deletion validation (warns if any map references the resource). Reads and writes .tres files with round-trip safety — preserving uid, ext_resource, and script lines.

**Editable fields** (from `resource_def.gd`): `id` (StringName), `display_name` (String), `gather_time` (float), `gather_amount` (int), `tool_required` (StringName), `respawn_time` (float), `yield_type` (StringName), `tool_speed` (Dictionary), `max_stack` (int), `category` (StringName), `catalog_entry` (StringName), `catalog_category` (StringName), `placeholder_mesh_type` (StringName), `placeholder_params` (Dictionary), `placeholder_color` (Color — with color picker + swatch preview), `placeholder_depleted_type` (StringName), `placeholder_depleted_params` (Dictionary), `placeholder_depleted_color` (Color).

**Read-only fields:** `mesh`, `depleted_mesh`, `material` (Godot resource references — displayed as path or "not set", cannot be authored in a web editor).

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
- [ ] Given a malformed .tres file in data/resources/, when loaded, then the editor shows a clear error message and skips the file without crashing (AC9)

---

## Technical Specification

{Added by /aid-specify — do not fill during interview.}
