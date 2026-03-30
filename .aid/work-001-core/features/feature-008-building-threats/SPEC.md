# Building & Night Threats

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-30 | Feature identified from REQUIREMENTS.md §5 F6/F9, §9 AC6/AC9 | /aid-interview |

## Source

- REQUIREMENTS.md §5 F6 (Building)
- REQUIREMENTS.md §5 F9 (Night Threats)
- REQUIREMENTS.md §9 AC6 (Building acceptance criteria)
- REQUIREMENTS.md §9 AC9 (Night Threats acceptance criteria)
- REQUIREMENTS.md §10 P1 — Tension

## Description

Players place structures on hex tiles (one per tile). Structures block movement, which is critical for night defense — walls redirect fauna, Shelter provides a safe zone where the player takes zero damage at night. Structures have HP and can be damaged by fauna.

Starting Day 4, simple fauna spawn at night outside lit and walled areas. They move toward the player when within 2 hexes and deal damage on contact. All fauna despawn at dawn. Days 1–3 are peaceful (onboarding). The player can fight back with tools (slow, costly) or shelter (smart play). Night is a pressure/timer mechanic, not a combat game.

Building and threats are combined because they form a single gameplay unit: you build to defend, threats make building meaningful.

## User Stories

- As a player, I want to build walls and shelter so I feel safe at night
- As a player, I want night threats to create tension so the day/night cycle has stakes
- As a player, I want the first few days to be peaceful so I can learn without dying

## Priority

Must (P1 — Tension)

## Acceptance Criteria

- [ ] Place Workbench on empty hex → occupied, blocks movement
- [ ] Try to place on occupied hex → rejected
- [ ] Shelter built → player inside at night takes 0 damage
- [ ] Wall built → fauna pathfinding routes around it
- [ ] Fauna attacks unprotected structure → HP decreases
- [ ] Day 3 night → zero fauna spawn
- [ ] Day 4 night → 1–3 fauna spawn outside lit/walled area
- [ ] Fauna within 2 hexes → moves toward player
- [ ] Fauna contacts player → defined HP damage
- [ ] Dawn → all fauna despawn

## Save Integration

Adds placed structures (type, position, HP) and fauna state to save data.

---

## Technical Specification

{Added by /aid-specify — do not fill during interview.}
