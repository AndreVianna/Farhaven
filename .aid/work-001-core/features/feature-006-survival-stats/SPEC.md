# Survival Stats, Death & Respawn

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-30 | Feature identified from REQUIREMENTS.md §5 F8/F11/F12, §9 AC8 | /aid-interview |

## Source

- REQUIREMENTS.md §5 F8 (Survival Stats)
- REQUIREMENTS.md §5 F11 (Death & Respawn)
- REQUIREMENTS.md §5 F12 (HUD Layout — stat bars)
- REQUIREMENTS.md §9 AC8 (Survival acceptance criteria)
- REQUIREMENTS.md §10 P0 — Core Loop

## Description

The player has three survival stats displayed as compact horizontal bars at the top of the HUD: HP, Hunger, and Thirst. Hunger and Thirst deplete over time; when either reaches zero, HP drains (Thirst drains HP faster). The player eats or drinks to restore stats. HP regenerates slowly during daytime. There is no stamina bar.

When HP reaches zero, the player dies and respawns at their Shelter (if built) or the Crash Site. 50% of inventory is dropped as random items scattered on nearby tiles (recoverable). The day counter continues — no reset. If death occurs at night, respawn happens at dawn. No permadeath.

## User Stories

- As a player, I want to see my survival stats at a glance so I know when I'm in danger
- As a player, I want hunger and thirst to create gentle urgency without being punishing
- As a player, I want death to have consequences (lose items) but not end my run (no permadeath)

## Priority

Must (P0 — Core Loop)

## Acceptance Criteria

- [ ] HUD shows 3 bars at all times
- [ ] Hunger reaches 0 → HP decreases at defined rate
- [ ] Eat Berries → Hunger increases by defined amount
- [ ] All three stats at 0 → player dies → respawn with 50% inventory drop

## Save Integration

Adds HP, Hunger, Thirst values and respawn location to save data.

---

## Technical Specification

{Added by /aid-specify — do not fill during interview.}
