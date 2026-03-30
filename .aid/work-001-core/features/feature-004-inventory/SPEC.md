# Inventory

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-30 | Feature identified from REQUIREMENTS.md §5 F5/F12, §9 AC5 | /aid-interview |

## Source

- REQUIREMENTS.md §5 F5 (Inventory)
- REQUIREMENTS.md §5 F12 (HUD Layout — inventory button)
- REQUIREMENTS.md §9 AC5 (Inventory acceptance criteria)
- REQUIREMENTS.md §10 P0 — Core Loop

## Description

The player has a grid-based inventory starting with ~12 slots. Items stack with quantity display. When the inventory is full, picking up a new item is rejected with visual feedback. Inventory can be expanded by building a Storage Chest (+12 slots per chest). The inventory is accessed via a button in the bottom-right HUD. The HUD is minimal and translucent — screen is the game, not the UI.

## User Stories

- As a player, I want to see what I've gathered in a clear grid so I know what I have
- As a player, I want items to stack so my limited inventory isn't wasted on duplicates
- As a player, I want to expand my inventory by building storage so I can carry more as I progress

## Priority

Must (P0 — Core Loop)

## Acceptance Criteria

- [ ] Start with 12 empty slots
- [ ] Pick up 13th unique item without Storage Chest → rejected with feedback
- [ ] Build Storage Chest → inventory expands to 24 slots
- [ ] Items stack with quantity display

## Save Integration

Adds inventory contents (item types, quantities, slot positions) to save data.

---

## Technical Specification

{Added by /aid-specify — do not fill during interview.}
