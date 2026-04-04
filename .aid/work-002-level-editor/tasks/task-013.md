# task-013: Resource Editor -- Edit Form, Commands, and Delete Validation

**Type:** IMPLEMENT

**Source:** feature-005-resource-editor -> delivery-003

**Depends on:** task-012

**Scope:**
- Implement Resource Editor edit form with collapsible sections (`<details>` elements):
  - Section 1 -- Identity: id (text, validated: non-empty, alphanumeric+underscores, unique; disabled for existing), display_name (text, non-empty)
  - Section 2 -- Gathering: gather_time, gather_amount, tool_required, respawn_time, yield_type, tool_speed (key-value pair editor with Add Row / Remove)
  - Section 3 -- Inventory: max_stack, category
  - Section 4 -- Catalog: catalog_entry, catalog_category
  - Section 5 -- Visuals: placeholder_mesh_type, placeholder_params (key-value editor), placeholder_color (color picker + swatch), placeholder_depleted_type, placeholder_depleted_params, placeholder_depleted_color (color picker + swatch)
  - Section 6 -- Read-Only: mesh, depleted_mesh, material (displayed as text labels)
- Implement `collectFormData()` -- read form inputs into ResourceDefModel
- Implement `validateForm(model)` -- required fields, id uniqueness, numeric ranges
- Implement Command classes for feature-008 integration:
  - `CreateResourceDefCommand` -- add to store + write file; undo removes
  - `EditResourceDefCommand` -- apply new values + write file; undo restores old values + write
  - `DeleteResourceDefCommand` -- remove from store + delete file; undo re-adds + write
- Implement delete validation: scan all loaded maps for resource references (both `"wood"` string form and `{ type: "wood" }` dict form)
- Implement delete warning dialog: "This resource is used by {count} tile(s) in {mapNames}. Continue?"
- Wire Save button: validate -> create command -> execute -> return to list
- Wire Cancel button: discard changes, confirm if dirty, return to list
- Wire "Back to List" link
- Color picker updates swatch live on `input` event
- Alpha preserved from existing files; new resources default alpha 1.0

**Acceptance Criteria:**
- [ ] All 18 editable fields render in the form with correct input types
- [ ] Form validation catches: empty id, duplicate id, empty display_name, invalid numeric values
- [ ] id field is disabled when editing existing resource (immutable)
- [ ] tool_speed key-value editor supports add/remove rows
- [ ] placeholder_params key-value editor supports add/remove rows
- [ ] Color picker updates swatch preview live
- [ ] Save creates a Command and writes valid .tres file
- [ ] Edit command captures before-state for correct undo
- [ ] Delete scans all maps for references and shows warning if found
- [ ] Cancel discards changes; confirm dialog if form is dirty
- [ ] Created/edited/deleted resources correctly update in-memory store and trigger list re-render
- [ ] All commands integrate with CommandHistory (undo/redo functional)
