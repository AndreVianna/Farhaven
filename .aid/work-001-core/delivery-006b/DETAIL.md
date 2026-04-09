# delivery-006b: Editor Sync — All Pages for New Schema

**Status:** Planning
**Created:** 2026-04-09
**Depends on:** delivery-006a
**Cumulative state:** Editor fully supports Gear hierarchy, SSH placement, Events, Fauna.

## Tasks (preliminary — to be detailed during planning)

| # | Name | Type | Est. hours |
|---|------|------|-----------|
| 066 | Editor: Prop page — Gear base fields + PlaceableCap without footprint + SSH snap | UPDATE | 6 |
| 067 | Editor: Recipe page — sync with Event system, remove unlock_when UI | UPDATE | 3 |
| 068 | Editor: Event page (NEW) — create/edit milestones, chapter gates, world flags | IMPLEMENT | 8 |
| 069 | Editor: Fauna page (NEW) — Fauna as special Prop with movement config | IMPLEMENT | 6 |
| 070 | Editor: SSH grid support — 2D top-down placement at 32cm resolution | IMPLEMENT | 8 |
| 071 | Editor: ID namespace enforcement — prefix validation, auto-increment per type | UPDATE | 3 |
| 072 | Editor: Biome page review — ensure sync with current schema | REVIEW | 2 |
| 073 | Editor: round-trip tests for all pages with new schema | TEST | 4 |

**Estimated total: ~40h**

## Open questions
- Fauna page: is fauna config (hp, speed, detection_range) per-species on the PropDef, or in a separate FaunaConfig resource?
- SSH grid in editor: show sub-sub-hex grid always, or only when zoomed in?
- Mesh preview in editor: can we render a 3D preview of the prop in the web editor, or stay 2D silhouette?
