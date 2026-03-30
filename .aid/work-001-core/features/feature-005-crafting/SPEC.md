# Crafting

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-30 | Feature identified from REQUIREMENTS.md §5 F4, §9 AC4 | /aid-interview |

## Source

- REQUIREMENTS.md §5 F4 (Crafting)
- REQUIREMENTS.md §5 F12 (HUD Layout — crafting button near Workbench)
- REQUIREMENTS.md §9 AC4 (Crafting acceptance criteria)
- REQUIREMENTS.md §10 P0 — Core Loop

## Description

Crafting requires a Workbench structure. Recipes are discovered progressively — when the player picks up a new material type, recipes using that material appear in the crafting UI. Recipes with sufficient materials are selectable; insufficient recipes are greyed out. Crafting consumes materials and produces the item in the player's inventory. MVP recipes include tools (Stone Axe, Stone Pickaxe) and structures (Shelter, Storage Chest, Wall, Torch). A crafting button appears in the HUD when the player is near a Workbench.

## User Stories

- As a player, I want recipes to appear as I discover materials so I'm not overwhelmed at the start
- As a player, I want to see which recipes I can afford so I know what to gather next
- As a player, I want crafting to feel like meaningful progression — new tools unlock new possibilities

## Priority

Must (P0 — Core Loop)

## Acceptance Criteria

- [ ] Player has 5 Wood + 3 Stone → Workbench recipe visible
- [ ] Player has 2 Wood + 0 Stone → Workbench recipe greyed out
- [ ] Player gathers Stone for first time → Stone Axe recipe appears
- [ ] Craft Stone Axe → materials consumed, tool in inventory

## Save Integration

Adds discovered recipes list and equipped tool to save data.

---

## Technical Specification

{Added by /aid-specify — do not fill during interview.}
