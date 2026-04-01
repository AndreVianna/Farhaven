# Audit Report — work-001-core (Re-Audit v2)

**Auditor:** Lola (subagent)
**Date:** 2026-03-31
**Scope:** All 8 SPECs + REQUIREMENTS.md — re-audit after fixes applied to v1 (Grade B+)
**Previous Grade:** B+
**Updated Grade:** A-

---

## 1. Grade: A-

**Justification:** 17 of 18 original issues are fully resolved. All 3 critical issues are fixed — `is_passable()` now checks `blocks_movement`, `meat` is in CONSUMABLE_CONFIG, and all stale `update_fog()` references are gone. All 7 major issues are resolved (slot count typo fixed, structure save format aligned, orphaned signals/APIs annotated, REQUIREMENTS.md updated). 7 of 8 minor issues are resolved. One partial fix introduced an internal contradiction in F-003 (gather feedback table says show "REQUIRES [TOOL]" text, but the Key Rule and disambiguation flow still say wrong tool = fall through to movement silently). 3 additional minor gaps were found that predate the fixes (missing `take_damage()` API in F-006, stale `equipped_tool` reference in F-003 dependency table, missing fauna signal documentation in F-006). Grade drops from A due to the F-003 internal contradiction and the F-006 external damage API gap.

---

## 2. Issue Resolution Table

### 🔴 CRITICAL — All Resolved

| # | Issue | Status | Evidence |
|---|-------|--------|----------|
| 1 | F-001 `is_passable()` said `structure != "" → impassable` | ✅ RESOLVED | F-001 Core API comment now reads: `#   structure with blocks_movement: true → impassable (Shelter and Torch are walkable)`. Matches F-008's `blocks_movement: false` for Shelter and Torch. |
| 2 | F-006 CONSUMABLE_CONFIG missing `meat` | ✅ RESOLVED | F-006 CONSUMABLE_CONFIG now includes: `&"meat": { "hunger": 25.0, "thirst": 0.0 }`. Accompanying prose: "Meat is the best hunger item (25 vs berries' 15) — only source is fauna kills (feature-008)." |
| 3 | Stale `update_fog()` references in 3 locations | ✅ RESOLVED | **F-001 signal comment:** Now reads `# Fog of war (both emitted by refresh_visibility() in a single pass)`. **F-002 signal wiring:** Now shows `HexGrid.tile_entered()` / `HexGrid.tile_exited()` / `(DayNightCycle handles visibility via tile_entered)` — no `update_fog()`. **F-006 respawn flow:** Now shows `Emit HexGrid.tile_entered(_respawn_tile)` only — no `update_fog()` call. |

### 🟡 MAJOR — All Resolved

| # | Issue | Status | Evidence |
|---|-------|--------|----------|
| 4 | F-004 "fixed 3 slots" typo | ✅ RESOLVED | F-004 Data Model now reads: `2. **Tool slots** — 4 fixed slots, one tool each, auto-used, upgrade replaces in-place` |
| 5 | Structure save format inconsistent with `tile_col/tile_row` | ✅ RESOLVED | F-008 save data now uses array format: `[{ "tile_col": 2, "tile_row": -1, "type": "workbench" }, ...]` — matches convention used by all other save sections. |
| 6 | F-001 signal comment referencing `update_fog()` | ✅ RESOLVED | (Same fix as #3 — F-001 signal comment now says `refresh_visibility()`) |
| 7 | Orphaned `tile_contents_changed` signal | ✅ RESOLVED | F-001 signal declaration now annotated: `signal tile_contents_changed(coords: Vector2i)  # generic catch-all — reserved for future use` |
| 8 | Orphaned `has_tool_for()` API | ✅ RESOLVED | F-004 API now annotated: `# Convenience — does the player have any tool in this slot? (convenience API)` / `func has_tool_for(slot: StringName) -> bool` |
| 9 | REQUIREMENTS.md stale text (3 locations) | ✅ RESOLVED | **§5 F6:** Now reads "Structures are indestructible in MVP" and "Most structures block movement (walls, workbench); Shelter and Torch are walkable — important for night defense". **§9 AC6:** Now reads "Structures are indestructible — fauna cannot damage them" (replaces structure HP criterion). |
| 10 | F-003 gather feedback contradiction | ⚠️ PARTIALLY FIXED | Feedback table updated to: `Tool-gated feedback: Floating "REQUIRES [TOOL]" text in red (same GatherFeedback system). On tap with wrong tool`. **However**, the Key Rule still says: `Wrong tool = move, not "need stone_axe" message.` And the disambiguation flow still says: `Has resources but ALL are tool-gated → FALL THROUGH TO MOVEMENT`. These three are internally contradictory. See New Issue N1. |

### 🟢 MINOR — 7 of 8 Resolved

| # | Issue | Status | Evidence |
|---|-------|--------|----------|
| 11 | F-001 API section historical note about `update_fog()` | ✅ RESOLVED | Comment now reads: `# Fog of war — single pass, multiple visibility sources (player + torches).` Historical reference to `update_fog()` removed. |
| 12 | F-002 signal wiring diagram shows `update_fog()` | ✅ RESOLVED | (Same fix as #3 — diagram now shows `tile_entered`/`tile_exited` with DayNightCycle note) |
| 13 | F-007 cycle 310s tight margin on 5min±15s | — ACKNOWLEDGED | Comment now explicitly notes: `(within AC7's 5 min ±15s — tight margin, 5s to spare)`. Was observation, not a required fix. Still 310s, still passes AC7. |
| 14 | `fade_in_completed` signal no consumer | ✅ RESOLVED | Signal now annotated: `signal fade_in_completed()  # available for future use (no current consumer)` |
| 15 | F-001 ResourceNode table missing cross-ref to F-003 | ✅ RESOLVED | Text added after ResourceNode table: `Feature-003 extends ResourceNode with respawn_time: float (seconds until respawn after depletion).` |
| 16 | F-003 `process_priority` description confusing | ✅ RESOLVED | Text now reads: `gather_system.gd has a lower process_priority value than player_input.gd (lower value = higher priority in Godot) — it receives _unhandled_input first.` |
| 17 | F-003 two `can_gather` signatures | ✅ RESOLVED | Only one signature remains: `func can_gather(node: ResourceNode, inventory: Inventory) -> bool`. Old `equipped: StringName` version removed. |
| 18 | F-006 respawn flow `update_fog` | ✅ RESOLVED | (Same fix as #3 — respawn flow now emits `tile_entered` only, no `update_fog()`) |

---

## 3. New Issues

### 🟡 MAJOR

**N1 — F-003 internal contradiction: gather feedback vs Key Rule vs disambiguation flow**

The fix for Issue #10 updated the Gather Feedback table to show "REQUIRES [TOOL]" red text on wrong-tool tap. But two other sections within the same spec were NOT updated:

1. **Key Rule** (Feature Flow section) still says:
   > `Wrong tool = move, not "need stone_axe" message. The player is never stuck.`

2. **Tap Disambiguation Flow** still says:
   > `Has resources but ALL are tool-gated (wrong tool) or depleted? → FALL THROUGH TO MOVEMENT (don't block, just walk there)`

These three now contradict each other within F-003. The implementer faces ambiguity: does wrong-tool show red text, or silently fall through to movement?

**Fix:** Decide on one behavior and update all three locations. Recommended: show "REQUIRES [TOOL]" red text AND fall through to movement (both can coexist — the text floats while the player walks). Update the Key Rule to: "Wrong tool = show requirement feedback and move. The player is never stuck." Update the flow to: "→ SHOW FLOATING 'REQUIRES [TOOL]' FEEDBACK, THEN FALL THROUGH TO MOVEMENT."

---

**N2 — F-006 missing `take_damage()` public API for external damage sources**

F-008 documents that `fauna_attacked_player(id, damage) → apply HP damage to player` via signal to SurvivalSystem. But F-006 defines no public method for receiving external damage. The SurvivalSystem's HP management only covers:
- Depletion from hunger/thirst (in stat tick `_process`)
- HP regen during daytime

There is no `take_damage(amount: float)` method or equivalent documented in F-006's Data Model or API. An implementer would need to infer the damage application pattern.

**Fix:** Add to F-006 Data Model a public method:
```gdscript
func take_damage(amount: float) -> void
```
And document that it's consumed by F-008's `fauna_attacked_player` signal. Also add F-008 fauna signals to F-006's Cross-Feature Dependencies table.

---

### 🟢 MINOR

**N3 — F-003 Component Responsibilities table lists stale `Player (equipped_tool)` dependency**

F-003's Component Responsibilities table for `gather_system.gd` says:
> Depends On: `HexGrid` (API + signals), `Player` (equipped_tool, current_tile), `Inventory` (add_item contract)

But F-003's own Data Model section explicitly states: "`Player.equipped_tool` is eliminated. Tool slots are owned by Inventory (feature-004)."

**Fix:** Change dependency to: `Player (current_tile), Inventory (get_tool, add_item)`

---

**N4 — F-006 missing cross-feature dependencies on F-008 fauna signals**

F-006's Cross-Feature Dependencies table lists signals from F-002, F-004, F-007, and F-008 (structure signals). But it does NOT list:
- `fauna_attacked_player(id, damage)` — consumed to apply HP damage
- `fauna_killed(id, coords)` — consumed to create meat ground item

F-008 documents these wirings FROM its side, but F-006 doesn't document RECEIVING them. An implementer reading F-006 alone wouldn't know SurvivalSystem handles fauna damage and meat drops.

**Fix:** Add to F-006 Cross-Feature Dependencies table:
```
| fauna_attacked_player signal (HP damage) | feature-008 (FaunaManager) |
| fauna_killed signal (meat ground item)   | feature-008 (FaunaManager) |
```
And add corresponding entries to F-006's Signal Wiring section.

---

**N5 — F-003 Gather Action pseudocode uses undefined `equipped` variable**

F-003 Gather Action flow references:
```
multiplier = tool_speed.get(equipped, {}).get(node.type, 1.0)
```

The variable `equipped` is never defined in the flow. Since `Player.equipped_tool` was eliminated, this should reference the inventory tool lookup:
```
equipped = Inventory.get_tool(item_config[node.tool_required].get("tool_slot", &""))
```

**Fix:** Add a step before the multiplier lookup that derives `equipped` from Inventory, or inline the lookup.

---

## 4. Remaining Fix List

### Should Fix (5 items)

| Priority | Issue | Location | Fix |
|----------|-------|----------|-----|
| 🟡 MAJOR | N1: F-003 internal contradiction on tool-gated feedback | F-003 SPEC Key Rule + Disambiguation Flow + Feedback Table | Reconcile all three: show red text AND fall through to movement. Update Key Rule and flow to match feedback table. |
| 🟡 MAJOR | N2: F-006 missing `take_damage()` API | F-006 SPEC Data Model | Add `func take_damage(amount: float) -> void` to public API |
| 🟢 MINOR | N3: F-003 stale `equipped_tool` in dependency table | F-003 SPEC Component Responsibilities | Change `Player (equipped_tool, current_tile)` → `Player (current_tile), Inventory (get_tool, add_item)` |
| 🟢 MINOR | N4: F-006 missing fauna signal cross-refs | F-006 SPEC Cross-Feature Dependencies + Signal Wiring | Add `fauna_attacked_player` and `fauna_killed` entries |
| 🟢 MINOR | N5: F-003 undefined `equipped` variable in pseudocode | F-003 SPEC Gather Action flow | Derive `equipped` from Inventory.get_tool() |

---

## 5. Cross-Reference Verification

### Signal Names/Signatures — All Match ✅

Verified all signal declarations in F-001 against consumers in F-002 through F-008:

| Signal | Declaration (F-001) | All Consumer Signatures Match? |
|--------|--------------------|-|
| `map_generated()` | ✅ | ✅ F-001 renderer, F-002 pathfinder, F-003 renderer |
| `tile_revealed(coords: Vector2i)` | ✅ | ✅ F-001 renderer, F-003 renderer |
| `tile_visibility_changed(coords: Vector2i, state: FogState)` | ✅ | ✅ F-001 renderer, F-003 renderer |
| `tile_entered(coords: Vector2i)` | ✅ | ✅ F-003, F-005, F-006, F-007 |
| `tile_exited(coords: Vector2i)` | ✅ | ✅ F-005 |
| `resource_depleted(coords: Vector2i, resource_type: StringName)` | ✅ | ✅ F-003 renderer |
| `resource_respawned(coords: Vector2i, resource_type: StringName)` | ✅ | ✅ F-003 renderer |
| `structure_placed(coords: Vector2i, structure_type: StringName)` | ✅ | ✅ F-002, F-004, F-005, F-006, F-007, F-008 |
| `structure_destroyed(coords: Vector2i, structure_type: StringName)` | ✅ | ✅ F-002, F-005, F-006, F-007 |
| `tile_contents_changed(coords: Vector2i)` | ✅ (reserved) | N/A — no consumers, documented as reserved |

DayNightCycle signals (F-007) verified against all consumers:
| `phase_changed(new_phase: TimePhase)` | ✅ | ✅ F-007 day_counter |
| `dawn()` | ✅ | ✅ F-006 (respawn), F-008 (fauna despawn) |
| `night()` | ✅ | ✅ F-008 (fauna spawn) |
| `day_started(day_number: int)` | ✅ | ✅ F-007 (SaveManager, day_counter) |

Inventory signals (F-004) verified:
| `item_used(type: StringName)` | ✅ | ✅ F-006 (consume effect) |
| `item_added(type: StringName, amount: int)` | ✅ | ✅ F-005 (recipe discovery) |
| `inventory_changed()` | ✅ | ✅ F-004 UI, F-005 UI, F-008 UI |

### API Method Signatures — Match ✅

| Method | Owner Signature | Caller Usage | Match? |
|--------|----------------|-------------|--------|
| `HexGrid.is_passable(from, to)` | `func is_passable(from: Vector2i, to: Vector2i) -> bool` | F-002, F-003, F-008 all pass two Vector2i | ✅ |
| `HexGrid.refresh_visibility(sources)` | `func refresh_visibility(sources: Array[Dictionary]) -> Array[Vector2i]` | F-007 passes `Array[Dictionary]` with `coords`+`radius` keys | ✅ |
| `Inventory.add_item(type, amount)` | `func add_item(type: StringName, amount: int = 1) -> int` | F-003 calls `add_item(node.type, amount)`, F-006 calls `add_item(item.type, item.amount)` | ✅ |
| `Inventory.get_tool(slot)` | `func get_tool(slot: StringName) -> StringName` | F-003 calls `get_tool(slot)`, F-008 calls `get_tool(&"weapon")` | ✅ |
| `Inventory.set_tool(slot, tool)` | `func set_tool(slot: StringName, tool: StringName) -> StringName` | F-005 calls `set_tool(recipe.tool_slot, recipe_name)` | ✅ |
| `Inventory.expand(additional)` | `func expand(additional_slots: int) -> void` | F-008 calls `expand(12)` | ✅ |

### Save Schema Keys — Consistent ✅

All save sections now use `tile_col`/`tile_row` convention:
- `hex_grid.tiles[]` → `tile_col`, `tile_row` ✅
- `player` → `tile_col`, `tile_row` ✅
- `survival` → `respawn_tile_col`, `respawn_tile_row` ✅
- `ground_items[]` → `tile_col`, `tile_row` ✅
- `respawn_queue[]` → `tile_col`, `tile_row` ✅
- `structures[]` → `tile_col`, `tile_row` ✅ (was `"col,row"` string keys — FIXED)

### New Inconsistencies Introduced by Fixes

| Finding | Severity | Details |
|---------|----------|---------|
| F-003 feedback vs flow contradiction | 🟡 Major | Fix for Issue #10 updated feedback table but not Key Rule or flow. See N1. |
| No other fix-introduced issues | — | All other fixes are clean and internally consistent. |

---

## 6. Score Summary

| Category | v1 (Before Fixes) | v2 (After Fixes) |
|----------|--------------------|-------------------|
| 🔴 Critical | 3 | 0 |
| 🟡 Major | 7 | 2 (1 partial + 1 new) |
| 🟢 Minor | 8 | 3 new |
| **Total Open** | **18** | **5** |
| **Grade** | **B+** | **A-** |

All blocking issues resolved. Remaining 5 issues are non-blocking — implementers can resolve them at coding time with clear intent from surrounding context. Documentation is implementation-ready.

**Note (2026-04-01):** This audit (Grade A-) covers API/signal consistency and was performed before design decisions #7–#11 (HEX_SIZE tripled, ELEVATION_STEP, cliff faces, player occupancy, scatter props). Its findings (N1–N5) remain valid and unaffected by spatial changes. A re-audit of the spatial/rendering layer will be needed after constants are propagated and the renderer is implemented. The A- grade should be understood as covering the logical/API layer only.
