# Scan System Redesign — 2026-04-02

## Core Change: Prop-Centric Auto-Scan

The scan system is fundamentally simplified. Instead of press-and-hold targeting tiles, scanning is **proximity-based auto-interaction**, consistent with the "movement IS interaction" pillar.

### How It Works

- Player walks near an unscanned prop → scan starts automatically
- Player stays in range → scan progress bar fills → scan completes
- Player leaves range → scan interrupted, progress resets
- No press-and-hold. No manual targeting. Movement IS the interaction.

### What This Eliminates

- Press-and-hold mechanic (scan_hold_started/update/ended signals from PlayerInput)
- Drift check, range check during scan (range is just proximity)
- Complex ScanState machine (was IDLE→SCANNING→COMPLETE→REJECTED)
- ScannerSystem as a massive 15-responsibility Node

## Three-State Knowledge System

Props have three knowledge states instead of two:

```
UNKNOWN → ENCOUNTERED → CATALOGED
```

| State | Symbol | Auto-Interact | Info Known |
|-------|--------|---------------|------------|
| UNKNOWN | ❓ | None | Nothing |
| ENCOUNTERED | ⚠️ | Auto-defend only | Hostile flag only |
| CATALOGED | ✅ (name) | Full (harvest/hunt/gather) | Everything (drops, edible, resource type) |

### State Transitions by Element Type

**Flora & Mineral** (static):
- UNKNOWN → CATALOGED (proximity scan, straightforward)
- No ENCOUNTERED state (they don't move or attack)

**Fauna Passive** (flees):
- UNKNOWN → player approaches → fauna flees → scan interrupted
- Need **Trap** to immobilize → then proximity scan → CATALOGED
- Trap is a **consumable** crafted item — resource investment with risk/reward

**Fauna Hostile** (attacks):
- UNKNOWN → player approaches → fauna attacks → ENCOUNTERED (first hit auto-registers hostility)
- ENCOUNTERED: auto-defend activates, but drops/edible/details unknown
- Need **Sneak Scan** to catalog → approach from behind (outside detection cone) → scan before detected → CATALOGED
- Failed sneak → fauna turns and attacks → scan interrupted

## Fauna Scan Puzzles

### Passive Fauna → Trap Mechanic (DEFERRED — post-MVP)

1. See unknown passive fauna → ❓
2. Approach → fauna flees → "I need a trap"
3. Craft trap (consumes resources) → place on ground near spawn/path
4. Fauna steps on trap → immobilized for X seconds
5. Player runs to immobilized fauna → scan completes → CATALOGED
6. Now knows drops → decides if worth spending more traps to hunt

Key design points:
- Traps are **consumable** (resource cost per use, creates decision weight)
- Each trap is a gamble: "is this fauna worth the resources I spent?"
- Creates gameplay loop: discover → craft → capture → scan → decide

### Hostile Fauna → Sneak Scan (DEFERRED — post-MVP)

1. See unknown hostile fauna → ❓
2. Approach → fauna attacks → ENCOUNTERED (knows it's hostile, auto-defend activates)
3. Return prepared → approach from behind (outside detection cone) → scan before detected → CATALOGED
4. Now knows drops → decides if worth hunting

Key design points:
- Hostile fauna needs **facing direction** + **detection cone** (not 360° circle)
- Creates tension: "can I get close enough without being seen?"
- Failed sneak = combat, scan interrupted
- Qualitatively different challenge from traps: **execution** (timing/movement) vs **preparation** (crafting/positioning)

## MVP Scope (Delivery-002)

For the current delivery, implement basic scan only:

- **Flora/Mineral**: proximity auto-scan works fully (UNKNOWN → CATALOGED)
- **Fauna hostile**: first-hit registers as ENCOUNTERED (auto-defend activates). Full scan NOT possible yet (sneak mechanic deferred)
- **Fauna passive**: flee behavior exists but scan may be difficult/impossible without traps (acceptable — traps come in future delivery)
- **Catalog**: supports all three states (UNKNOWN, ENCOUNTERED, CATALOGED)
- **Props**: 3D meshes visible in world, labels show state (❓ / ⚠️ name / ✅ name)

## Future Deliveries Needed

- **Trap System**: consumable crafting, placement, trigger, immobilize timer
- **Sneak/Stealth**: fauna facing direction, detection cones, stealth approach, cone visualization?
- **Fauna AI**: flee behavior improvements, patrol paths, detection ranges

## Design Decisions (Resolved 2026-04-02)

The following open questions from the impact audit were resolved:

1. **ENCOUNTERED visual label:** "Unidentified Fauna (Hostile)" if it attacked, "Unidentified Fauna (Shy)" if it fled. No species name until CATALOGED. This preserves the mystery incentive — the player knows *something* hostile exists but doesn't know what it is.

2. **Auto-defend gate:** Activates at ENCOUNTERED (confirmed intentional). The player doesn't need to fully catalog hostile fauna for combat purposes. The incentive for CATALOGED = knowing drops/details, not survival. This is a deliberate design choice: ENCOUNTERED gives safety, CATALOGED gives knowledge.

3. **Multi-prop proximity scan:** One scan at a time, nearest prop first. This is consistent with the chain gathering pattern and avoids complexity. After completing one scan, the system automatically targets the next nearest uncataloged prop.

4. **Catalog counter:** Shows total "X entries" (ENCOUNTERED + CATALOGED both count). ENCOUNTERED entries display as "Unidentified Fauna (Hostile)" or "Unidentified Fauna (Shy)" with no details. CATALOGED entries show full info (name, drops, edible, etc.). This rewards exploration — every encounter counts toward discovery.

5. **Flora/mineral ENCOUNTERED:** Never. Code enforces UNKNOWN → CATALOGED only for static elements. ENCOUNTERED is a fauna-only concept representing partial knowledge from behavioral observation (attacked/fled). Static elements have no behavior to observe.

6. **Passive fauna MVP:** Seeing fauna flee registers ENCOUNTERED. Player knows something exists but can't scan until Trap mechanic (deferred post-MVP). This creates a natural "I need to come back with a trap" moment.

7. **Proximity scan range:** 1 hex (adjacent). Tunable constant (`SCAN_RANGE`). Adjacent-only keeps the discovery moment intimate — you have to get close to learn.

8. **Grace period:** None. Binary in/out of range. Progress resets immediately on exit. This creates clear, predictable behavior and encourages the player to pause near interesting props.

9. **task-013:** Also removes ElementIconRenderer from main.tscn. PropRenderer + PropLabelRenderer replace it entirely.
