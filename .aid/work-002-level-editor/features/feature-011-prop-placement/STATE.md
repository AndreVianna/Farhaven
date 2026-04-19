# Feature State — Prop Placement (Scatter Presets, Seeded Randomization, Per-Instance Overrides)

**Status:** In Progress (implementation shipped; review/approvals pending)
**Started:** 2026-04-18
**Approved:** 2026-04-18 (Andre, via Discord discussion)

## Sections

| # | Section | Status | Source | Last Updated |
|---|---------|--------|--------|--------------|
| 1 | Description & User Stories | Complete | Lola | 2026-04-18 |
| 2 | Acceptance Criteria | Complete | Lola | 2026-04-18 |
| 3 | Data Model (PlacementPreset, PlacementCap, Prop changes) | Complete | Lola | 2026-04-18 |
| 4 | Scatter Algorithm (seed, count jitter, SSH selection, randomization) | Complete | Lola | 2026-04-18 |
| 5 | Engine Render Path (prop_renderer.gd changes) | Complete | Lola | 2026-04-18 |
| 6 | Editor UX (context menu, PlacementCap authoring) | Complete | Lola | 2026-04-18 |
| 7 | Migration (rotation_deg → rotation_override, opt-in PlacementCap) | Complete | Lola | 2026-04-18 |
| 8 | Edge Cases | Complete | Lola | 2026-04-18 |

## Pending

- Grade A review by Andre
- Approval of proposed F17 addition to work-002 REQUIREMENTS.md
- Approval of branch strategy (implementing on feature/props-grassland per Andre 2026-04-18)

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-18 | Initial draft — 8 sections complete. Design discussion Discord 2026-04-17/18. | Lola |
| 2026-04-18 | Grade A approved by Andre. Status Draft → In Progress. | Andre approval |
| 2026-04-18 | Scaffolding committed on `feature/grassland-polish`: PlacementPreset enum + PlacementCap resource class. Consumer (scatter algorithm + per-instance overrides + editor UI) pending. | implementation |
| 2026-04-18 | Engine consumer implemented in PropRenderer: scatter algorithm with seeded RNG, ±2 count jitter, Fisher-Yates sub-hex shuffle, per-copy variant / scale / rotation. Override fields added on Prop. Backward-compat for legacy rotation_deg as implicit rotation_override on SINGLE center. | implementation |
| 2026-04-18 | 12 grassland .tres patched with PlacementCap (plants NORMAL, Boulder SINGLE, other minerals SPROUTING). Migration script at tools/migrations/. Roundtrip tests green. | implementation |
| 2026-04-18 | Unit tests added: test_placement_preset.gd (13 tests), test_placement_cap.gd (3 tests). | implementation |
| 2026-04-19 | Refactor: PlacementCap merged into PlaceableCap as `placement: PlacementPreset`. PropDef now carries placement on the same cap instead of a sibling resource. Tests renamed: test_placement_cap.gd → test_placeable_cap.gd. Migration `2026-04-18-placement-into-placeable.py` relocated the existing saves. | implementation |
| 2026-04-19 | Editor UI for per-instance overrides shipped (context menu: variant / scale / rotation / reset). Drag-to-move placed props and generative populate button also shipped as part of the same branch. | implementation |

## Still Pending

- Review / approvals by Andre (Grade A gate, PR #27 merge)
- Removal of legacy Prop.rotation_deg after full migration of saves
