# task-015: Biome Editor -- Edit Form, Commands, Live Preview, and Delete Validation

**Type:** IMPLEMENT

**Source:** feature-006-biome-editor -> delivery-003

**Depends on:** task-014

**Scope:**
- Implement Biome Editor edit form:
  - biome_name: text input, validated non-empty and unique (case-insensitive); disabled for existing biomes
  - elevation_range: two number inputs (Min/Max), integers 0-9, validated min <= max
  - color: HTML color picker + 32x32 swatch preview; fires `biome-color-changed` custom event on `input` for live preview
  - color_variations: vertical list of color entries with color picker + 16x16 swatch + X remove button; "Add Variation" button (max 10); new entries default to current base color
  - resource_table: editable table with columns: Type (`<select>` dropdown from ProjectContext.files.resources keys), Chance (0.0-1.0), Min Amount (int >= 0), Max Amount (int >= min), Tool Required (text); Add/Remove rows; unknown resource types shown as red text with "(unknown)"
- Implement `collectFormData()` and `validateForm(model)`
- Implement Command classes:
  - `CreateBiomeCommand` -- add to store + write file + generate uid; undo removes
  - `EditBiomeCommand` -- apply new values + write file + fire `biome-color-changed`; undo restores + fire event
  - `DeleteBiomeCommand` -- remove from store + delete file; undo re-adds + write
- Implement live color preview: dispatch `biome-color-changed` event with `{ biomeName, newColor }` on color picker `input` event; HexCanvas listens and repaints affected tiles
- Implement cancel color revert: on Cancel, fire `biome-color-changed` with original color to revert canvas
- Implement delete validation: scan all loaded maps for tiles with matching biome name (case-insensitive)
- Implement delete warning dialog: "This biome is used by {count} tile(s) across {mapCount} map(s). Continue?"
- Wire Save, Cancel, "Back to List" buttons

**Acceptance Criteria:**
- [ ] All editable fields render in the form with correct input types and validation
- [ ] biome_name field is disabled when editing existing biome
- [ ] Color picker updates swatch and fires `biome-color-changed` event live
- [ ] HexCanvas updates biome colors in real-time when color picker changes (cross-tab integration)
- [ ] Cancel reverts color on canvas to original value
- [ ] color_variations supports add (up to 10) and remove
- [ ] resource_table dropdown populates from loaded resources; unknown types shown in red
- [ ] resource_table validates max_amount >= min_amount, chance in [0.0, 1.0]
- [ ] Delete scans all maps for biome references and shows warning if found
- [ ] All commands integrate with CommandHistory (undo/redo functional)
- [ ] New biome .tres files get generated uid in header
- [ ] Biome color changes via commands fire `biome-color-changed` for canvas updates on undo/redo
