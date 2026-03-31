# delivery-002: Inventory + Gathering

**Status:** Approved
**Created:** 2026-03-31
**Features:** feature-004-inventory, feature-003-resource-gathering
**Depends on:** delivery-001 (tasks 001-008)
**Cumulative state:** Collect resources

## Execution Graph

```
task-009 (Inventory data layer)
  │
  ├──────────────────┐
  ▼                  ▼
task-010           task-011
(Inventory tests)  (HUD + Inventory Panel UI)
  │                  │
  └──────┬───────────┘
         │
  ├──────────────────┐
  ▼                  ▼
task-012           task-013
(Gather system)    (Resource renderer)
  │                  │
  └──────┬───────────┘
         ▼
task-014 (Respawn queue + gather feedback)
  │
  ▼
task-015 (Gathering system tests)
  │
  ▼
task-016 (Delivery-002 integration verification)
```

**Parallel groups:**
- task-010 + task-011: both depend only on task-009. Tests and UI are independent.
- task-012 + task-013: gather system writes to Inventory (009), renderer subscribes to HexGrid signals (delivery-001). Neither needs the other.

## Tasks

| # | Name | Type | Depends On | Parallel With |
|---|------|------|-----------|---------------|
| 009 | Inventory data layer | IMPLEMENT | delivery-001 | -- |
| 010 | Inventory data layer tests | TEST | 009 | 011 |
| 011 | HUD CanvasLayer + Inventory Panel UI | IMPLEMENT | 009 | 010 |
| 012 | Resource config + gather system core | IMPLEMENT | 009 | 013 |
| 013 | Resource renderer (MultiMesh per type) | IMPLEMENT | delivery-001 | 012 |
| 014 | Respawn queue + gather feedback | IMPLEMENT | 012, 013 | -- |
| 015 | Gathering system tests | TEST | 014 | -- |
| 016 | Delivery-002 integration verification | TEST | all above | -- |

## Task Details

### task-009: Inventory data layer (RefCounted + item config) [IMPLEMENT]

**Scope:** Create `scripts/inventory/inventory.gd` (RefCounted), `data/item_config.tres`
(or static Dictionary constants file).

**Implements:**
- Resource slot API: `add_item`, `remove_item`, `has_item`, `get_count`, `get_slots`,
  `is_full`, `get_max_slots`, `get_used_slot_count`, `use_item`, `expand`
- Tool slot API: `get_tool`, `set_tool`, `has_tool_for`
- 4 fixed tool slots: `{ &"axe": &"", &"pickaxe": &"", &"weapon": &"survival_knife", &"scanner": &"scanner" }`
- 12 base resource slots, expandable via `expand()`
- Stacking rules per item_config (max_stack per type)
- `add_item` rejects tools (must use `set_tool`)
- All signals: `inventory_changed`, `item_added`, `item_removed`, `inventory_full`,
  `item_used`, `tool_changed`
- `get_save_data() -> Dictionary` and `load_save_data(data: Dictionary)`
- Wire Inventory instance as property on Player node

**Criteria:**
- [ ] All public methods implemented per feature-004 SPEC
- [ ] `add_item` routes tools to rejection (tools use `set_tool`)
- [ ] Stack limits enforced per item_config
- [ ] `expand` adds bonus slots (12 per call)
- [ ] `use_item` removes 1 and emits `item_used`
- [ ] Tool slots: `get_tool`, `set_tool` returns previous, `has_tool_for`
- [ ] Save data round-trip (`get_save_data` → `load_save_data`) preserves all state
- [ ] Signals emit correctly on all mutations
- [ ] Build passes with zero warnings

---

### task-010: Inventory data layer tests [TEST]

**Scope:** GdUnit4 unit tests for `inventory.gd`.

**Covers:**
- AC5: 12 slots, 13th unique item rejected, expansion to 24, stacking with quantity
- Edge cases: add to partial stack, add when full, remove more than available, tool
  routing rejection, `use_item` on non-existent item, `use_item` on non-consumable,
  expand multiple times, save/load round-trip, `set_tool` returns previous tool

**Criteria:**
- [ ] All AC5 criteria covered
- [ ] At least 2 edge cases per public method
- [ ] Tests are deterministic with clean setup/teardown
- [ ] All tests pass
- [ ] Build passes with zero warnings

**Parallel with:** task-011

---

### task-011: HUD CanvasLayer + Inventory Panel UI [IMPLEMENT]

**Scope:** Create HUD infrastructure and inventory panel.

**Files:**
- `scenes/ui/hud.tscn` — CanvasLayer (shared by future features)
- `scenes/ui/inventory_panel.tscn` — PanelContainer bottom drawer
- `ui/inventory_panel.gd` — open/close, slot rendering, consumable tap
- `ui/inventory_slot_ui.gd` — single resource slot (icon + quantity)
- `ui/tool_slot_ui.gd` — single tool slot (icon + label)

**Implements:**
- InventoryButton in HUD (bottom-right, 64×64px)
- Bottom drawer: full width, ~45% height, semi-transparent
- Tool slots row: HBoxContainer, 4 fixed slots (Axe, Pickaxe, Weapon, Scanner)
- Resource grid: ScrollContainer wrapping GridContainer (3 columns)
- Open/close: button toggle, X button, tap above panel
- Slot rendering from `inventory.get_slots()` + `get_tool()`
- Consumable tap: calls `inventory.use_item(type)`
- Re-render on `inventory_changed` / `tool_changed` signals
- `panel_opened` signal for mutual exclusion (used by delivery-003/004 panels)
- Game continues running — no pause

**Criteria:**
- [ ] InventoryButton opens/closes panel
- [ ] Panel shows 4 tool slots + 12 resource slots
- [ ] Slots display icon placeholder + quantity label
- [ ] Tap consumable slot calls `use_item`
- [ ] Empty vs occupied slots visually distinct
- [ ] Touch targets ≥ 48dp (slots ~90×90px, button 64×64px, close 48×48px)
- [ ] Panel closes on X, button re-tap, or tap above
- [ ] `panel_opened` signal emits on open
- [ ] Build passes with zero warnings

**Parallel with:** task-010

---

### task-012: Resource config + gather system core [IMPLEMENT]

**Scope:** Create gathering data and core system.

**Files:**
- `data/resource_config.tres` — gather_time, gather_amount per resource type
- `data/tool_config.tres` — tool speed multipliers
- `scripts/gathering/gather_system.gd` — Node, child of Player

**Implements:**
- `can_gather(node, inventory)` — direct StringName matching on `tool_required`
- Input disambiguation: adjacent tile with gatherable resource → gather; wrong tool → fall through to movement; no resources → fall through
- Gather action: set `is_gathering = true`, compute effective_time (base × tool multiplier), Tween timer, cancel on any input (`is_gathering = false`, no resource consumed)
- Multi-resource priority: highest `TOOL_PRIORITY` first
- On complete: `inventory.add_item()`, decrement `node.remaining`, emit signals
- On depletion: emit `HexGrid.resource_depleted`
- `is_gathering` flag checked by `player_input.gd` (rejects movement while true)
- `_unhandled_input` with lower `process_priority` than PlayerInput — claims tap before movement via `set_input_as_handled()`

**Criteria:**
- [ ] Bare-hands resources gatherable (wood, berries, fiber)
- [ ] Tool-gated resources rejected without correct tool (falls through to movement)
- [ ] `is_gathering` flag locks movement
- [ ] Cancel on any input during gather — no resource consumed
- [ ] Gather completes after effective_time
- [ ] Tool speed multipliers apply correctly
- [ ] Multi-resource priority: highest tool_required first
- [ ] `add_item` called on completion; inventory_full handled
- [ ] Build passes with zero warnings

**Parallel with:** task-013

---

### task-013: Resource renderer (MultiMesh per type) [IMPLEMENT]

**Scope:** Create visual representation of resources on tiles.

**Files:**
- `scenes/world/resource_renderer.tscn` — Node3D with 6 MultiMeshInstance3D children
- `scripts/gathering/resource_renderer.gd` — signal-driven updates

**Implements:**
- One MultiMeshInstance3D per resource type (~6 types = ~6 draw calls)
- On `map_generated()`: allocate instances for initial resources
- On `tile_revealed`: add resource instances for newly visible tile
- On `tile_visibility_changed`: show/hide per fog state (custom data)
- On `resource_depleted`: swap mesh variant (full → depleted: tree→stump, rock→rubble)
- On `resource_respawned`: swap back (depleted → full)
- Resources positioned with slight random offset within hex (not dead-center)

**Criteria:**
- [ ] One MultiMeshInstance3D per resource type (~6 draw calls)
- [ ] Resources appear on REVEALED/VISIBLE tiles
- [ ] Resources hidden on HIDDEN tiles
- [ ] Depleted resources show changed appearance
- [ ] Respawned resources restore full appearance
- [ ] Per-node offset within hex (visual variety)
- [ ] Build passes with zero warnings

**Parallel with:** task-012

---

### task-014: Respawn queue + gather feedback [IMPLEMENT]

**Scope:** Implement respawn timer system and visual feedback for gathering.

**Implements in gather_system.gd:**
- `_respawn_queue: Array[Dictionary]` — entries with coords, resource_index, time_remaining
- `_process` tick: decrement timers only when tile `fog_state != VISIBLE`
- Timer pauses when tile becomes VISIBLE, resumes on REVEALED/HIDDEN
- On timer complete: restore `node.remaining = max_amount`, emit `resource_respawned`
- Non-respawning resources (`respawn_time == 0`) never enter queue
- `get_save_data()` / `load_save_data()` for respawn queue serialization

**Creates `ui/gather_feedback.gd` (CanvasLayer):**
- `show_floating_text(world_pos, text, color)` — shared API for floating labels
- Successful gather: "+1 WOOD" in green, rises and fades (~1s)
- Tool-gated rejection: "REQUIRES STONE AXE" in red, same animation
- Inventory full: "INVENTORY FULL" in red
- Labels spawned at screen position via `Camera3D.unproject_position()`

**Criteria:**
- [ ] Depleted resource enters respawn queue with correct time
- [ ] Timer ticks only when tile fog_state is NOT VISIBLE
- [ ] Timer pauses on VISIBLE, resumes on REVEALED/HIDDEN
- [ ] Resource restores to max_amount on respawn, signal emitted
- [ ] `respawn_time == 0` → never enters queue
- [ ] Respawn queue survives save/load round-trip
- [ ] Floating "+N Type" text appears on successful gather (green)
- [ ] Floating "REQUIRES [TOOL]" text on tool-gated rejection (red)
- [ ] Floating "INVENTORY FULL" on full inventory rejection (red)
- [ ] Floating text fades after ~1s
- [ ] Build passes with zero warnings

---

### task-015: Gathering system tests [TEST]

**Scope:** GdUnit4 tests for gather_system.gd, respawn queue, can_gather, config lookups.

**Covers:**
- AC3: bare hands → wood, bare hands → ore rejected, pickaxe → ore, depletion, respawn
- Edge cases: gather while inventory full, cancel mid-gather, respawn timer pause/resume,
  multi-resource priority, `respawn_time == 0` (permanent depletion), tool speed multipliers

**Criteria:**
- [ ] All AC3 criteria covered
- [ ] Respawn pause/resume tested (VISIBLE pauses, REVEALED resumes)
- [ ] Cancel mid-gather tested (no resource consumed, no depletion)
- [ ] Inventory-full path tested (add_item returns 0)
- [ ] `respawn_time == 0` tested (never enters queue)
- [ ] Tests are deterministic with clean setup/teardown
- [ ] All tests pass
- [ ] Build passes with zero warnings

---

### task-016: Delivery-002 integration verification [TEST]

**Scope:** End-to-end integration tests for the full delivery-002 flow.

**Covers:**
- Gather wood → appears in inventory → shows in panel
- Gather until node depleted → visual change → respawn queue active
- Fill inventory → gather rejected → "INVENTORY FULL" feedback
- Tool slot display matches Inventory state (Survival Knife in weapon slot)
- Tool-gated resource → "REQUIRES STONE AXE" feedback → tap falls through to movement
- Cross-feature signal wiring: gather_system → inventory → UI, gather_system → resource_renderer

**Criteria:**
- [ ] End-to-end: gather resource → inventory updated → panel shows it
- [ ] Depletion → visual change → respawn queue entry created
- [ ] Full inventory → rejection feedback visible
- [ ] Tool-gated rejection → feedback visible, movement still works
- [ ] All AC3 and AC5 criteria verified in integration context
- [ ] Tests are deterministic
- [ ] All tests pass
- [ ] Build passes with zero warnings

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | 8 tasks created (009-016) — approved | /aid-detail |
