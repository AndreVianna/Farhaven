# Day/Night Cycle

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-30 | Feature identified from REQUIREMENTS.md §5 F7/F12, §9 AC7 | /aid-interview |

## Source

- REQUIREMENTS.md §5 F7 (Day/Night Cycle)
- REQUIREMENTS.md §5 F12 (HUD Layout — day counter, time-of-day icon)
- REQUIREMENTS.md §9 AC7 (Day/Night acceptance criteria)
- REQUIREMENTS.md §10 P0 — Persistence

## Description

The game runs on a continuous day/night cycle: Day (~3 min real time) → Dusk (30s warning with screen tint) → Night (~1.5 min) → Dawn. Full cycle is ~5 minutes. During the day, all revealed tiles are visible. At night, visibility is reduced to 1 hex around the player; Torches extend visibility to 2 hexes around the torch. The HUD shows a day counter ("Day 7") and time-of-day icon in the top-right.

The day/night cycle drives the game's pacing: day is for exploration and gathering, night is for survival. Auto-save triggers at each dawn.

## User Stories

- As a player, I want to feel the rhythm of day and night so sessions have natural structure
- As a player, I want the dusk warning so I have time to get to safety
- As a player, I want reduced visibility at night so darkness feels dangerous

## Priority

Must (P0 — Persistence)

## Acceptance Criteria

- [ ] Full cycle completes in 5 min ±15s (measurable)
- [ ] Dusk warning visible 30s before night
- [ ] Night: only tiles within 1 hex of player visible
- [ ] Torch placed: extends visibility to 2 hexes around torch

## Save Integration

Adds current day count, time-of-day phase, and phase elapsed time to save data. Auto-save triggers at dawn.

---

## Technical Specification

{Added by /aid-specify — do not fill during interview.}
