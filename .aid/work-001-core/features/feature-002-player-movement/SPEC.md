# Player Movement & Controls

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-30 | Feature identified from REQUIREMENTS.md §5 F2, §9 AC2 | /aid-interview |

## Source

- REQUIREMENTS.md §5 F2 (Player Movement & Controls)
- REQUIREMENTS.md §9 AC2 (Movement acceptance criteria)
- REQUIREMENTS.md §10 P0 — Foundation

## Description

The player moves through the hex world via two simultaneous input modes: tap-to-move (tap a revealed tile → character pathfinds via A* along the shortest route) and a floating joystick (touch-and-hold anywhere on screen → joystick appears at touch point for fine continuous movement). Both modes are always available — no toggle needed. Touches on HUD elements are ignored by the movement system. There is no stamina bar; the player can always move freely.

## User Stories

- As a player, I want to tap a tile to move there automatically so navigation feels effortless
- As a player, I want a floating joystick for fine control when I need precise positioning
- As a player, I want movement to feel responsive (<100ms) so the game feels snappy on my phone

## Priority

Must (P0 — Foundation)

## Acceptance Criteria

- [ ] Tap any revealed tile → character arrives via shortest path
- [ ] Path avoids impassable tiles (water, structures)
- [ ] Joystick appears at touch point on hold, character moves continuously
- [ ] Both input modes work without settings toggle
- [ ] Input-to-first-movement-frame < 100ms (measured)

## Save Integration

Adds player position (current tile coordinates) to save data.

---

## Technical Specification

{Added by /aid-specify — do not fill during interview.}
