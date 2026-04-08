# task-012: Resource Editor -- List View and Data Model

**Type:** IMPLEMENT

**Source:** feature-005-resource-editor -> delivery-003

**Depends on:** task-003, task-004

**Scope:**
- Implement `PropDefModel` data class:
  - All editable fields per SPEC: id, display_name, gather_time, gather_amount, tool_required, respawn_time, yield_type, tool_speed, max_stack, category, catalog_entry, catalog_category, placeholder_mesh_type, placeholder_params, placeholder_color (RGBA), placeholder_depleted_type, placeholder_depleted_params, placeholder_depleted_color
  - Read-only fields: mesh, depleted_mesh, material
  - Round-trip metadata: _handle, _headerLines, _dirty
  - `fromTres(tresString, handle)` -- parse via TresParser, map TresValue fields to typed JS fields
  - `toTres()` -- serialize via TresParser, map JS fields back to TresValue
  - `clone()` -- deep copy for command snapshots
  - `equals(other)` -- field-by-field comparison
- Implement default values for new resources per SPEC
- Implement Resource Editor list view in the Resources tab panel:
  - HTML `<table>` with columns: id, display_name, category, color swatch (16x16), gather_time
  - Sorted alphabetically by id
  - Click row to open edit form
  - "New Resource" button at top
- Wire list rendering to `ProjectContext.files.resources` data
- Re-render list when resource store changes

**Acceptance Criteria:**
- [ ] `PropDefModel.fromTres()` correctly parses all fields from existing .tres files
- [ ] `PropDefModel.toTres()` produces valid .tres output that round-trips correctly
- [ ] Color fields correctly convert between {r,g,b,a} (0.0-1.0) and hex string (#rrggbb)
- [ ] Resource list displays all discovered resources sorted by id
- [ ] Color swatches render with correct placeholder_color
- [ ] Clicking a row navigates to edit form (placeholder -- form built in task-013)
- [ ] "New Resource" button triggers new resource flow
- [ ] List re-renders when resources are added or removed
