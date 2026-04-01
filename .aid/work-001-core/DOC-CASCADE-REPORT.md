# Documentation Impact Report — Post-Pivot Cascade

**Author:** Lola (subagent)
**Date:** 2026-04-01
**Scope:** All 12 feature SPECs, 6 delivery DETAILs, REQUIREMENTS.md, PLAN.md, AUDIT-REPORT.md, known-issues.md
**Trigger:** Design decisions #7–#11 (HEX_SIZE tripled, player occupancy, cliff faces, ELEVATION_STEP, scatter props)

---

## Summary

**21 of 24 files read. 17 files affected.** 6 critical issues (would cause CC to build the wrong thing), 10 important issues (stale numbers/descriptions that cause confusion), 5 minor issues (cosmetic/terminology). The most pervasive impact is **HEX_SIZE=3.0** — it cascades into camera positioning, player size, move speed, mobile pixel calculations, and animation parameters across 8+ files. The second most impactful is **cliff faces** moving from "deferred" to current scope, which contradicts an explicit deferral statement in the spec CC would read first.

**Decisions #1–#6 (already committed)** are correctly propagated in the specs — no stale WorldGenerator, tap-to-move, or MultiMesh hex grid references found. The [PIVOT] annotations are thorough and consistent.

---

## Critical (blocks implementation)

### C1. HEX_SIZE=3.0 not defined anywhere in specs
No spec, constant table, or data model mentions `HEX_SIZE`. Feature-001's HexGrid Constants table lists only `WALK_MAX_DIFF` and `JUMP_MAX_DIFF`. An implementer would need to guess or default to 1.0 (the Red Blob Games tutorial default). Every `axial_to_world` conversion, every world-space calculation, every camera/rendering value derives from this constant. **Without it, the entire spatial layer is undefined.**

**Fix:** Add `HEX_SIZE = 3.0` to feature-001's HexGrid Constants table. Add a note in `hex_math.gd` scope (task-002) that this constant drives all spatial conversions.

### C2. Cliff faces spec says "deferred" but decision says "current"
Feature-001 Rendering Architecture explicitly states: *"Cliff face geometry (vertical quads between elevation steps) deferred to post-MVP polish."* This is the spec CC reads to build the renderer. CC will skip cliff faces entirely.

**Fix:** Remove the deferral statement. Add cliff face geometry to the Rendering Architecture section: flat vertical quads between adjacent hexes at different elevations, using the higher tile's biome color × 0.6. These are additional triangles in the same ArrayMesh — zero extra draw calls.

### C3. Camera offset calibrated for HEX_SIZE=1.0
Feature-002 specifies `offset: Vector3 = Vector3(0, 15, 10)`. This produces a reasonable view for HEX_SIZE=1.0. With HEX_SIZE=3.0, the world is 3× larger in XZ — the camera at this offset would show ~1/9th of the previous visible area (only 1-2 hexes instead of the intended 5-7). The game would be unplayably zoomed in.

**Fix:** Recalculate camera offset for HEX_SIZE=3.0. Rough scaling: `Vector3(0, 45, 30)` to maintain similar visible hex count. Exact value needs tuning (see Design Questions).

### C4. Player move_speed not adjusted for HEX_SIZE=3.0
Feature-002 declares `move_speed: float` as exported/tunable but provides no default value in the spec. Delivery-001 doesn't specify one either. With HEX_SIZE=3.0, tiles are 3× farther apart in world units. If the default move_speed is kept from a HEX_SIZE=1.0 assumption, the player will cross tiles 3× slower than intended.

**Fix:** Define a concrete `move_speed` default in feature-002 that accounts for HEX_SIZE=3.0. At HEX_SIZE=1.0, ~4-6 units/sec was reasonable. At HEX_SIZE=3.0, ~12-18 units/sec would maintain similar tile-crossing speed.

### C5. Player placeholder size stale for new scale
Delivery-001 Integration Contract specifies: *"PlayerVisual (MeshInstance3D — placeholder blue cube 0.4×0.8×0.4)"*. This was ~40% of HEX_SIZE=1.0. With HEX_SIZE=3.0 and 30% target occupancy, the player should be ~0.9×1.8×0.9.

**Fix:** Update delivery-001 Integration Contract and task-006 to specify placeholder cube dimensions appropriate for HEX_SIZE=3.0 and 30% hex occupancy.

### C6. ELEVATION_STEP not defined — jump arc height and Y offsets are unanchored
No spec defines the Y offset per elevation level. Feature-002 references "~0.5 world units" for jump arc height, but this is the arc peak, not the step. The elevation system is fully specified in integer levels (0-9) but the conversion to world-space Y is undefined. With the decision to increase ELEVATION_STEP from 0.3 to 0.5-0.8, an implementer has no value to use.

**Fix:** Add `ELEVATION_STEP` constant to feature-001 HexGrid Constants table (pending Andre's decision on exact value). Update feature-002 jump arc parameters to be proportional to this constant. Total world height range = 9 × ELEVATION_STEP (at 0.5 → 4.5 units; at 0.8 → 7.2 units).

---

## Important (causes confusion)

### I1. Delivery-001 execution graph says "3-outcome classifier"
The execution graph label reads: `task-007 (Player input — 3-outcome classifier + joystick)`. The actual task title is: "Player Input — **Two-Outcome** Classifier + Joystick". The pivot to two-outcome input (SCAN_HOLD + JOYSTICK; tap = no-op) was applied to the task description but not the graph label.

**Fix:** Update graph label to `task-007 (Player input — two-outcome classifier + joystick)`.

### I2. Mobile pixel calculations stale across multiple files
The following files state "~54-72px per hex at 1080×1920 portrait":
- Feature-001 Mobile Specs → Touch Input Geometry
- Feature-002 Mobile Specs → Touch Target Sizes
- Feature-003 Mobile Specs → Touch Interaction

These values derive from HEX_SIZE + camera distance + viewport. With HEX_SIZE=3.0 and adjusted camera, the calculation needs redoing. The conclusion (above 48dp minimum) is probably still true but the stated numbers are wrong.

**Fix:** Recalculate hex screen size with HEX_SIZE=3.0 and new camera offset. Update all three specs.

### I3. Jump/drop arc parameters may need adjustment
Feature-002 specifies:
- Jump arc: "Y rises by ~0.5 world units above the higher tile" over ~0.3s
- Drop arc: ~0.2s

With ELEVATION_STEP increasing from 0.3 to 0.5-0.8, a diff-2 elevation gap goes from 0.6 to 1.0-1.6 world units. The arc peak of 0.5 units above the higher tile might be too low relative to the gap. The timing (0.3s/0.2s) might also need adjustment — larger gaps could feel too fast.

**Fix:** Define arc peak as a function of the gap height (e.g., `gap_height * 0.5 + 0.3`). Review timing. Mark these as tunable/exported.

### I4. Fauna movement feel changes at HEX_SIZE=3.0
Feature-010 fauna move 1 tile per `move_cooldown` (1.0s). At HEX_SIZE=1.0, this was 1.0 world units/sec. At HEX_SIZE=3.0, it's 3.0 world units/sec — but tiles are also 3× apart, so the tile-crossing rate is identical. However, the visual speed of the creature mesh moving through 3D space appears 3× faster. Conversely, the `detection_range: 2` hexes is now 6+ world units of visual distance — creatures start approaching from much further away visually.

**Fix:** Note in feature-010 that `move_cooldown` and `detection_range` may need retuning after HEX_SIZE change. Flag for playtesting.

### I5. Auto-gather fly-to-player distance scales with HEX_SIZE
Feature-004 specifies: *"resource visually 'flies to' player's CURRENT position... over ~0.3s."* With HEX_SIZE=3.0, an adjacent resource is 3× farther in world space. At 0.3s, the fly animation would appear 3× faster. May look janky.

**Fix:** Note that fly animation duration should scale with distance, or increase to ~0.5s. Mark as tunable.

### I6. Scanner range verification needed
Feature-003 sets `_scan_range: int = 2` (hexes). At HEX_SIZE=1.0, this was ~2 world units. At HEX_SIZE=3.0, it's ~6 world units. Visually, the player can scan things quite far away. This might be fine (scanner is a long-range tool) or might feel disconnected.

**Fix:** Note for playtesting. The value is already exported/tunable, so no spec change needed — just flag it.

### I7. Feature-001 BiomeData elevation lightening may need recalibration
Feature-001 specifies: *"Elevation subtly lightens the color (+5% per elevation level)."* With 10 levels (0-9), the highest tiles are 45% lighter. This was designed for a flat-ish world at ELEVATION_STEP=0.3 (max height 2.7). With ELEVATION_STEP=0.8 (max height 7.2), the visual height range is much more dramatic — the color lightening might need to be less aggressive (e.g., +3% per level).

**Fix:** Note as tunable. May need adjustment after visual testing.

### I8. Snap-to-center tween distance increases
Feature-002: *"On joystick release, player snaps to current tile center (~0.1s tween)."* With HEX_SIZE=3.0, the maximum snap distance (from a hex edge to its center) is ~1.5 units (was ~0.5). At 0.1s, this could appear too fast/jarring.

**Fix:** Make snap duration proportional to distance, or increase to ~0.15-0.2s. Mark as tunable.

### I9. Delivery-001 Visual Smoke Test references stale player size
Delivery-001 says: *"Blue cube (player) standing on center tile."* The cube dimensions (0.4×0.8×0.4) are defined elsewhere in the same file but are stale (see C5). The smoke test itself is fine conceptually but the visual expectation is wrong.

**Fix:** Update alongside C5.

### I10. Feature-002 "Two-Outcome" naming vs 3 classified paths
Feature-002 section header says "Two-Outcome Input Classification" but then describes 3 outcomes: TAP, SCAN HOLD, JOYSTICK. The reasoning is that TAP is a no-op and therefore not a "meaningful outcome" — but the flow diagram shows 3 branches labeled OUTCOME 1, 2, 3. An implementer might be confused by the inconsistency.

**Fix:** Either rename to "Three-Path Input Classification" or rename the flow diagram labels to match (TAP = "no-op path", SCAN HOLD = "Outcome 1", JOYSTICK = "Outcome 2").

---

## Minor (cosmetic/consistency)

### M1. known-issues.md INSTANCE_CUSTOM note slightly misleading
The note says *"This applies to ALL MultiMesh shaders."* The hex grid renderer no longer uses MultiMesh (it's ArrayMesh per the pivot). The note is still technically accurate (it does apply to ALL MultiMesh shaders, and other renderers still use MultiMesh) but could confuse someone who reads it after the hex grid pivot.

**Fix:** Add a note: *"The hex grid renderer (feature-001) now uses a single ArrayMesh, so this only applies to icon/resource/structure/fauna renderers."*

### M2. Resource renderer random offset should scale with HEX_SIZE
Feature-004 mentions *"per-node random offset within hex for visual variety"* but doesn't specify the offset range. With HEX_SIZE=3.0, the offset range should be larger to maintain the same proportional spread. Currently underspecified regardless of HEX_SIZE.

**Fix:** Specify offset range as a fraction of HEX_SIZE (e.g., ±15% of hex radius).

### M3. Draw call budget may shift slightly with cliff faces
Feature-012 tallies ~21 total 3D draw calls. If cliff faces are part of the existing ArrayMesh (same draw call), the budget is unchanged. If they're separate geometry, it adds 1. The budget is fine either way (~79 remaining) but the tally should note the cliff face geometry.

**Fix:** Add a note in the draw call budget that cliff faces are part of the HexGridRenderer ArrayMesh (0 additional draw calls).

### M4. Scatter props deferral is consistent (verified)
Feature-001 correctly states scatter props are deferred to post-delivery-006. No other file references scatter props as current work. **No fix needed.**

### M5. AUDIT-REPORT remains valid but scope-limited
The audit was performed before decisions #7-#11. Its findings (N1-N5: F-003 contradiction, F-006 missing take_damage, stale equipped_tool, missing fauna signal cross-refs, undefined equipped variable) are all still valid and unaffected by the spatial changes. The audit grade (A-) should be considered valid for the API/signal consistency it covers, but incomplete for the spatial/rendering layer now added by decisions #7-#10.

**Fix:** Note in AUDIT-REPORT that a re-audit will be needed after spatial constants are propagated.

---

## Per-File Findings

### REQUIREMENTS.md
| Issue | Severity | Details |
|-------|----------|---------|
| No HEX_SIZE constant | Critical | Add to §5 F1 or §11 or create a new spatial constants section |
| No ELEVATION_STEP constant | Critical | Same — add alongside HEX_SIZE |
| No player occupancy target | Important | Add "player visual occupies ~30% of hex width" to §5 F2 or §6 |
| No cliff face mention | Critical | Add to §5 F1 description or AC1 |
| "~200-300 tiles" → world scale context | Minor | With HEX_SIZE=3.0, map is ~60-90 world units across. May want to note this. |

### PLAN.md
| Issue | Severity | Details |
|-------|----------|---------|
| Clean | — | No spatial constants. No stale references. No fixes needed. |

### AUDIT-REPORT.md
| Issue | Severity | Details |
|-------|----------|---------|
| Scope-limited | Minor | Pre-dates decisions #7-#11. Note re-audit needed. |
| Findings N1-N5 still valid | — | Unaffected by spatial changes. |

### known-issues.md
| Issue | Severity | Details |
|-------|----------|---------|
| INSTANCE_CUSTOM note | Minor | Add clarification that hex grid is now ArrayMesh |

### feature-001-hex-grid SPEC.md
| Issue | Severity | Details |
|-------|----------|---------|
| HEX_SIZE missing from Constants | Critical (C1) | Add `HEX_SIZE = 3.0` |
| ELEVATION_STEP missing | Critical (C6) | Add constant (pending value decision) |
| Cliff faces "deferred" | Critical (C2) | Remove deferral, add cliff face geometry spec |
| Mobile Specs: "~54-72px per hex" | Important (I2) | Recalculate for HEX_SIZE=3.0 + new camera |
| Elevation lightening +5%/level | Important (I7) | Flag as tunable, may need adjustment |
| Draw call budget | Minor (M3) | Note cliff faces are part of ArrayMesh (0 extra) |
| Resource offset unspecified | Minor (M2) | Specify as fraction of HEX_SIZE |

### feature-002-player-movement SPEC.md
| Issue | Severity | Details |
|-------|----------|---------|
| Camera offset Vector3(0, 15, 10) | Critical (C3) | Recalculate for HEX_SIZE=3.0 |
| move_speed undefined for HEX_SIZE=3.0 | Critical (C4) | Define concrete default |
| Jump arc "~0.5 world units" | Important (I3) | Adjust for ELEVATION_STEP |
| Touch targets "~54-72px" | Important (I2) | Recalculate |
| Snap tween ~0.1s | Important (I8) | May need to increase |
| "Two-Outcome" vs 3 paths | Important (I10) | Naming inconsistency |

### feature-003-scanner-catalog SPEC.md
| Issue | Severity | Details |
|-------|----------|---------|
| scan_range 2 hexes at new scale | Important (I6) | Flag for playtesting |
| Touch "~54-72px" | Important (I2) | Recalculate |

### feature-004-auto-interaction SPEC.md
| Issue | Severity | Details |
|-------|----------|---------|
| Fly-to-player ~0.3s at 3× distance | Important (I5) | Scale duration or increase |
| Resource offset unspecified | Minor (M2) | Specify as fraction of HEX_SIZE |

### feature-005-inventory SPEC.md
| Issue | Severity | Details |
|-------|----------|---------|
| Clean | — | No spatial constants. No fixes needed. |

### feature-006-crafting SPEC.md
| Issue | Severity | Details |
|-------|----------|---------|
| Clean | — | Workbench proximity is hex-distance-based. No fixes needed. |

### feature-007-survival-stats SPEC.md
| Issue | Severity | Details |
|-------|----------|---------|
| Clean | — | No spatial constants. No fixes needed. |

### feature-008-day-night-cycle SPEC.md
| Issue | Severity | Details |
|-------|----------|---------|
| Clean | — | Visibility radius in hex units. Lighting is time-based. No fixes needed. |

### feature-009-building SPEC.md
| Issue | Severity | Details |
|-------|----------|---------|
| Clean at spec level | — | Adjacency and placement are hex-distance-based. Touch targets for hex tiles depend on camera (I2) but building spec itself is fine. |

### feature-010-night-threats SPEC.md
| Issue | Severity | Details |
|-------|----------|---------|
| Fauna movement feel | Important (I4) | Flag move_cooldown and detection_range for retuning |

### feature-011-journal SPEC.md
| Issue | Severity | Details |
|-------|----------|---------|
| Clean | — | Data/UI only. No spatial constants. |

### feature-012-hud SPEC.md
| Issue | Severity | Details |
|-------|----------|---------|
| Clean | — | Screen-space UI. No spatial constants. |

### delivery-001 DETAIL.md
| Issue | Severity | Details |
|-------|----------|---------|
| Graph: "3-outcome classifier" | Important (I1) | Update to "two-outcome" |
| Player cube 0.4×0.8×0.4 | Critical (C5) | Update for HEX_SIZE=3.0 + 30% occupancy |
| Camera offset not recalculated | Critical (C3) | Add note/value for HEX_SIZE=3.0 |
| Visual smoke test player size | Important (I9) | Update alongside C5 |
| task-002 missing HEX_SIZE in scope | Important | HexMath should define HEX_SIZE=3.0 |
| task-004 missing cliff face scope | Critical | Add cliff face geometry to renderer task |

### delivery-002 DETAIL.md
| Issue | Severity | Details |
|-------|----------|---------|
| Clean | — | Scanner and inventory are data/hex-distance-based. |

### delivery-003 DETAIL.md
| Issue | Severity | Details |
|-------|----------|---------|
| Fly-to-player timing | Minor | Note duration may need scaling for HEX_SIZE=3.0 |

### delivery-004 DETAIL.md
| Issue | Severity | Details |
|-------|----------|---------|
| Clean | — | Day/night and survival are time-based. |

### delivery-005 DETAIL.md
| Issue | Severity | Details |
|-------|----------|---------|
| Clean at task level | — | Building and fauna use hex distances. Fauna feel (I4) is a spec-level issue. |

### delivery-006 DETAIL.md
| Issue | Severity | Details |
|-------|----------|---------|
| Clean | — | Journal is data/UI only. |

---

## Design Questions (need Andre's input)

### Q1. What is the exact ELEVATION_STEP value?
You said "likely 0.5-0.8." This affects:
- Total world height range: 9 × step (4.5 at 0.5, 7.2 at 0.8)
- Jump/drop animation arc height and timing
- Camera offset Y component (needs to see highest tiles)
- Cliff face visual height
- How dramatic elevation differences look

**Recommendation:** Start with 0.6 (total range 5.4 — roughly 2× HEX_SIZE, visually balanced). Tune from there.

### Q2. Should hex-distance-based ranges stay the same?
All these are currently in hex units and would remain logically correct:
- Auto-gather: 1 hex (adjacent)
- Auto-defend: 1 hex
- Scanner scan range: 2 hexes
- Fauna detection: 2 hexes
- Fauna spawn min distance: 3 hexes
- Fog visibility: 2 hexes (day), 1 hex (night)

But with HEX_SIZE=3.0, these distances are 3× larger in world space. Does the feel change meaningfully? Scanning from 6 world units away — does that feel too far? Auto-gather at 3 world units — does it feel like "I'm grabbing from across the room"?

**Recommendation:** Keep hex-distance values as-is initially. They define game rules, not visual distance. Camera and scale should make them feel right. Flag for playtesting.

### Q3. Camera offset — triple or recalculate?
Two approaches:
- **Triple:** `Vector3(0, 45, 30)` — maintains exact same visual hex count on screen
- **Recalculate from design intent:** How many hexes should be visible on screen? Then derive camera distance.

**Recommendation:** Triple as starting point, then tune. The isometric angle (rotation.x ≈ -34°) is independent of hex size.

### Q4. Player move_speed — triple or keep slower?
HEX_SIZE=3.0 means tiles are 3× farther apart. Options:
- **Triple (~15 units/sec):** Same tiles-per-second crossing rate. Same gameplay pacing.
- **Keep slower (~5 units/sec):** Each tile feels bigger, more deliberate. Suits "curiosity" gameplay.
- **Compromise (~10 units/sec):** Slightly slower crossing but not tedious.

**Recommendation:** Triple (maintain gameplay pacing), tune down if world feels too "zoomed in" and rushed.

### Q5. Cliff faces — which delivery and how?
Current delivery-001 task-004 (HexGridRenderer) would be the natural place. Options:
- **Add to task-004:** Cliff face quads are part of the ArrayMesh build. Same draw call. Simple extension.
- **Separate task:** Clean separation but adds coordination overhead.

**Recommendation:** Add to task-004 scope. It's the renderer task and cliff faces are just additional triangles in the same mesh. Update task-004 criteria.

### Q6. Cliff face coloring — single biome or blend?
You said "biome color × 0.6." Question: WHICH biome? The higher tile's biome? The lower? Average?

**Recommendation:** Higher tile's biome color × 0.6. The cliff "belongs" to the higher terrain visually. Simpler than blending.

### Q7. Player occupancy — how does 30% affect interaction ranges?
At 30% occupancy with HEX_SIZE=3.0, the player is ~0.9 units wide in a 3.0-unit hex. The "player is on a tile" zone is just the tile they're standing on. Adjacent tiles (for auto-gather) are a full hex away (~3 units). Does the player feel too small relative to the interaction range? Or does the extra "whitespace" in the hex create a nice sense of space?

**Recommendation:** Flag for playtesting. The 30% + 3.0 combination creates a very different feel from 40% + 1.0. Visual prototyping early (even before full mechanics) would catch feel issues.

---

## Appendix: Verified Correct (no changes needed)

These were checked and found to be already correctly propagated:
- ✅ MapLoader replaces WorldGenerator — no stale references anywhere
- ✅ Elevation 0-9 for all biomes — consistently applied
- ✅ TraversalType enum — correctly defined in feature-001 and consumed everywhere
- ✅ Joystick-only movement — all specs correctly describe joystick movement
- ✅ Single ArrayMesh hex renderer — feature-001 is correct, other MultiMesh renderers are correctly separate
- ✅ Two-outcome input — correctly described in feature-002 (minor naming issue I10)
- ✅ Scatter props — consistently deferred across all files
- ✅ Signal cross-references — all verified correct in AUDIT-REPORT (N1-N5 pre-existing, unrelated)
- ✅ Save data formats — all consistent with tile_col/tile_row convention
- ✅ Panel mutual exclusion — 5-panel list consistent across all feature specs
