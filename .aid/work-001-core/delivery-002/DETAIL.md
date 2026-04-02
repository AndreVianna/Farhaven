# delivery-002: See and Know — Scanner + Inventory

**Status:** Approved
**Created:** 2026-03-31
**Features:** feature-005-inventory, feature-003-scanner-catalog
**Depends on:** delivery-001 (tasks 001-008)
**Cumulative state:** Scan ❓ elements, build catalog, carry items

## Execution Graph

```
        CHAIN A (Inventory)              CHAIN B (Scanner/Catalog)
                                         (parallel)

task-009 (Inventory data layer)        task-011 (Catalog data layer)
  │                                      │
  ▼                                      ▼
task-010 (Inventory panel UI +         task-012 (Scanner system core)
          HUD integration)               │
  │                                      ▼
  │                                    task-013 (Prop + label + scan
  │                                              progress renderers)
  │                                      │
  │                                      ▼
  │                                    task-014 (Catalog panel UI)
  │                                      │
  └──────────────┬───────────────────────┘
                 ▼
           task-015 (Integration test)
```

**Parallel chains:** Chain A (Inventory: tasks 009-010) and Chain B (Scanner/Catalog:
tasks 011-014) have zero cross-dependency. Both merge at task-015 (integration test).

## Tasks

| # | Name | Type | Depends On | Parallel With |
|---|------|------|-----------|---------------|
| 009 | Inventory data layer | IMPLEMENT | delivery-001 | 011 |
| 010 | Inventory panel UI + HUD integration | IMPLEMENT | 009 | 011, 012 |
| 011 | Catalog data layer | IMPLEMENT | delivery-001 | 009 |
| 012 | Scanner system core | IMPLEMENT | 011 | 009, 010 |
| 013 | Prop renderer + prop label renderer + scan progress renderer | IMPLEMENT | 012 | -- |
| 014 | Catalog panel UI | IMPLEMENT | 011 | 010 |
| 015 | Delivery-002 integration test | TEST | all above | -- |

## Task Details

### task-009: Inventory Data Layer [IMPLEMENT]

**Source:** feature-005 → Data Model

**Scope:**
- `scripts/inventory/inventory.gd` (RefCounted, owned by Player):
  - `_slots: Array[Dictionary]` — 12 base resource/consumable slots
  - `_tool_slots: Dictionary` — 4 fixed: axe=empty, pickaxe=empty, weapon=survival_knife, scanner=scanner
  - `_base_slots: int = 12`, `_bonus_slots: int = 0`
  - Item config table with all resource + tool entries (including `toxic_berries`, `meat`)
  - Resource/consumable API: `add_item`, `remove_item`, `has_item`, `get_count`,
    `get_slots`, `is_full`, `get_max_slots`, `get_used_slot_count`, `use_item`, `expand`
  - Tool API: `get_tool`, `set_tool`, `has_tool_for`
  - `add_item` logic: tool routing rejection → partial stack → new stack → inventory_full
  - `add_item` timing: called at resource arrival (not gather start)
  - `remove_item`: reverse-order consumption (minimize fragmentation)
  - Signals: `inventory_changed`, `item_added`, `item_removed`, `inventory_full`,
    `item_used`, `tool_changed`
  - `get_save_data()` / `load_save_data()`
- `data/item_config.tres` (or static Dictionary)

**Criteria:**
- [ ] Unit tests: add_item partial stack fill, new stack, overflow/rejection, tool routing rejection
- [ ] Unit tests: remove_item reverse-order, partial removal, empty slot cleanup
- [ ] Unit tests: stacking rules (per-type max_stack from item_config)
- [ ] Unit tests: tool slots (set_tool returns old, has_tool_for, get_tool)
- [ ] Unit tests: use_item removes 1, emits item_used, false if not present
- [ ] Unit tests: expand (bonus_slots +12, new empty slots, max_slots correct)
- [ ] Unit tests: save/load round-trip (slots + tools + bonus_slots preserved)
- [ ] Starting state: 12 empty, weapon=survival_knife, scanner=scanner, axe/pickaxe empty
- [ ] item_config includes: wood, stone, berries, toxic_berries, fiber, ore, crystal, meat + 4 tools
- [ ] Build passes with zero warnings

---

### task-010: Inventory Panel UI + HUD Integration [IMPLEMENT]

**Source:** feature-005 → Layers & Components + UI Specs

**Scope:**
- `scenes/ui/inventory_panel.tscn` — PanelContainer bottom drawer (~45% height)
- `ui/inventory_panel.gd` — open/close toggle, slot rendering, consumable tap + toxic warning
- `ui/inventory_slot_ui.gd` — single resource slot (icon placeholder, quantity, tap handler)
- `ui/tool_slot_ui.gd` — single tool slot (icon, label: Axe/Pickaxe/Weapon/Scanner, no tap)
- Layout: header + close (X), tool slots row (HBoxContainer, 4 slots), resource grid
  (ScrollContainer wrapping GridContainer 3 columns)
- Consumable tap: calls `inventory.use_item(type)`. Toxic warning dialog for toxic flora
  (queries Catalog.get_entry — no-op if Catalog unavailable)
- `panel_opened` signal for mutual exclusion
- Re-renders on `inventory_changed` / `tool_changed` signals
- **HUD integration (merged from original task-003):**
  - Wire InventoryButton (64×64px) into HUD bottom-right
  - Connect `inventory_full` signal → HUD floating text "INVENTORY FULL"
  - Verify panel opens within HUD CanvasLayer hierarchy
  - Game continues running while open (~55% world visible above)

**Criteria:**
- [ ] InventoryPanel opens/closes on InventoryButton tap
- [ ] Tool slots display correctly (4 fixed, labeled)
- [ ] Resource grid: correct items + quantities, empty slots distinct (border style)
- [ ] ScrollContainer works when slots exceed visible area
- [ ] Consumable tap triggers use_item with highlight animation
- [ ] Toxic warning dialog shows for toxic flora (stub Catalog query)
- [ ] `panel_opened` signal emitted on open
- [ ] Touch targets: slots ≥90×90px, close 48×48px, InventoryButton 64×64px
- [ ] `inventory_full` → floating "INVENTORY FULL" via HUD FloatingTextManager
- [ ] InventoryButton visible in HUD bottom-right
- [ ] Game continues running, ~55% world visible
- [ ] Re-renders on `inventory_changed`
- [ ] Build passes with zero warnings

---

### task-011: Catalog Data Layer [IMPLEMENT]

**Source:** feature-003 → Data Model (CatalogEntry, Catalog, enums, mapping)

**Scope:**
- `scripts/scanner/catalog_entry.gd` — Resource with all properties:
  entry_id, category, display_name, description, icon (placeholder Texture2D),
  properties Dictionary (category-specific: flora edible/toxic/resource_type,
  fauna hostile/damage/hp, mineral resource_type/tool_required, anomaly journal/cutscene IDs)
- `scripts/scanner/catalog.gd` — RefCounted:
  - `CatalogCategory` enum: FLORA, FAUNA, MINERAL, ANOMALY
  - `KnowledgeState` enum: UNKNOWN, ENCOUNTERED, CATALOGED
  - `_knowledge: Dictionary[StringName, KnowledgeState]` (replaces old `_discovered: Dictionary[StringName, bool]`)
  - `_encounter_labels: Dictionary[StringName, String]` — "Hostile" or "Shy" for ENCOUNTERED fauna
  - `_all_entries: Dictionary[StringName, CatalogEntry]`
  - `_total_count: int`
  - Full API: `get_knowledge_state`, `is_cataloged`, `is_encountered`, `is_known`,
    `get_entry`, `get_discovered_entries` (ENCOUNTERED + CATALOGED),
    `get_discovered_by_category`, `get_discovery_count` (ENCOUNTERED + CATALOGED),
    `get_total_count`, `get_discovery_text` ("X entries"),
    `catalog_entry`, `encounter_entry`, `get_encounter_label`, `get_scannable_at`
  - `get_scannable_at` skips ENCOUNTERED fauna (needs Trap/Sneak, not proximity scan)
  - `RESOURCE_TO_ENTRY` mapping: wood→wood_tree, berries→berry_bush,
    toxic_berries→toxic_berry_bush, fiber→fiber_grass, stone→stone_deposit,
    ore→iron_deposit, crystal→crystal_cluster
  - Signals: `entry_cataloged`, `entry_encountered`, `knowledge_state_changed`
  - `get_save_data()` / `load_save_data()` — saves knowledge state + encounter labels
- Data files: `data/catalog/flora.tres`, `fauna.tres`, `minerals.tres`, `anomalies.tres`
  with Chapter 1 entries

**Criteria:**
- [ ] Unit tests: get_knowledge_state returns UNKNOWN/ENCOUNTERED/CATALOGED correctly
- [ ] Unit tests: is_cataloged before/after catalog_entry call
- [ ] Unit tests: encounter_entry sets ENCOUNTERED + stores label ("Hostile"/"Shy")
- [ ] Unit tests: get_discovered_entries returns ENCOUNTERED + CATALOGED (not UNKNOWN)
- [ ] Unit tests: get_discovered_by_category filtering
- [ ] Unit tests: get_discovery_count counts ENCOUNTERED + CATALOGED
- [ ] Unit tests: get_discovery_text returns "X entries" format
- [ ] Unit tests: catalog_entry emits entry_cataloged + knowledge_state_changed signals
- [ ] Unit tests: encounter_entry emits entry_encountered + knowledge_state_changed signals
- [ ] Unit tests: get_scannable_at returns entry_id for UNKNOWN element, &"" for CATALOGED, &"" for ENCOUNTERED fauna
- [ ] Unit tests: save/load round-trip (knowledge states + encounter labels preserved)
- [ ] Unit tests: RESOURCE_TO_ENTRY mapping — all 7 resource types map to valid entry IDs
- [ ] Data files: at least 3 flora (including berry_bush + toxic_berry_bush), 1 fauna (thornback),
      3 minerals, 1 anomaly for Chapter 1
- [ ] Build passes with zero warnings

---

### task-012: Scanner System Core [IMPLEMENT]

**Source:** feature-003 → Data Model (ScannerSystem) + Feature Flow (proximity auto-scan)

**Scope:**
- `scripts/scanner/scanner_system.gd` — Node (child of Player):
  - Properties: `_catalog`, `_is_scanning`, `_scan_target_coords`, `_scan_target_entry_id`,
    `_scan_progress`, `_scan_duration`, `_scan_range` (1 hex — adjacent only, tunable constant)
  - `SCAN_DURATIONS` config: Flora 2.0s, Mineral 2.0s, Fauna 3.0s, Anomaly 3.0s
  - **Proximity auto-scan flow:** `_process` checks nearby tiles (player tile + 6 neighbors
    within `_scan_range`) for uncataloged props via `get_scannable_at`. Starts scan on
    nearest match. Progress advances while player stays in range. Interrupts immediately
    when player leaves range (no grace period). One scan at a time, nearest first.
  - **Surprise encounter:** receive `fauna_attacked_player(id, damage, species)` →
    if UNKNOWN → instant `encounter_entry("Hostile")`. Stub connection (activates when F-010 arrives).
  - **Passive identification:** on `tile_revealed`/`tile_visibility_changed(VISIBLE)` →
    check resource_nodes + anomaly against catalog → emit `element_identified`,
    `element_unknown`, or `element_encountered` based on 3-state knowledge
  - Signals: `scan_started`, `scan_progress_updated`, `scan_completed`, `scan_interrupted`,
    `entry_cataloged`, `entry_encountered`, `knowledge_state_changed`, `surprise_cataloged`,
    `element_identified`, `element_unknown`, `element_encountered`
  - No connection to PlayerInput — proximity scan runs independently in `_process`

**Criteria:**
- [ ] Unit tests: proximity detection (finds nearest uncataloged prop within 1 hex)
- [ ] Unit tests: scan lifecycle (start on proximity → progress → complete)
- [ ] Unit tests: scan interruption (player leaves range → progress resets immediately)
- [ ] Unit tests: one scan at a time (nearest first, no parallel scans)
- [ ] Unit tests: scan duration per category (flora 2s, mineral 2s, anomaly 3s)
- [ ] Unit tests: surprise encounter (UNKNOWN hostile species → instant ENCOUNTERED with "Hostile" label)
- [ ] Unit tests: passive ID with 3 states (CATALOGED → element_identified, ENCOUNTERED → element_encountered, UNKNOWN → element_unknown)
- [ ] Unit tests: flora/mineral never enter ENCOUNTERED state (UNKNOWN → CATALOGED only)
- [ ] entry_cataloged emitted on completion with correct entry_id + category
- [ ] knowledge_state_changed emitted on all transitions
- [ ] No scan_hold signals, no scan_rejected — proximity-based only
- [ ] Build passes with zero warnings

---

### task-013: Prop Renderer + Prop Label Renderer + Scan Progress Renderer [IMPLEMENT]

**Source:** feature-003 → Layers & Components (renderers)

**Scope:**
- `scripts/rendering/prop_renderer.gd` — Node3D:
  - 5 MultiMeshInstance3D pools: flora (cube), fauna (sphere), mineral (octahedron),
    anomaly (tetrahedron), generic (fallback)
  - On `element_identified(coords, entry_id)`: add prop mesh to appropriate pool
  - On `element_unknown(coords, entry_id, category)`: add prop mesh to appropriate pool
    (uses category to pick correct mesh pool; same mesh regardless of knowledge state)
  - On `element_encountered(coords, entry_id, label)`: add prop mesh to appropriate pool
  - On `tile_visibility_changed(coords, REVEALED/HIDDEN)`: remove instances
  - Prop positioning: `HexGrid.axial_to_world(coords)` + Y offset
- `scripts/rendering/prop_label_renderer.gd` — Node3D:
  - ~1 MultiMeshInstance3D pool for pill-shaped label backgrounds (billboard)
  - `_tile_entries: Dictionary[Vector2i, Array[StringName]]` — tile → displayed entry IDs
  - On `element_identified(coords, entry_id)`: show real name label above prop
  - On `element_unknown(coords, entry_id, category)`: show "❓ Unknown [category]" label above prop
    (uses category to resolve label text: Flora→"Vegetation", Fauna→"Creature", etc.)
  - On `element_encountered(coords, entry_id, label)`: show "⚠️ Unidentified Fauna ([label])" label
  - On `entry_cataloged(entry_id, category)`: bulk label update — iterate all visible
    props, update matching labels from ❓ or ⚠️ → real name. "Biome conquered" moment.
  - On `entry_encountered(entry_id, label)`: update matching labels from ❓ → ⚠️ label
  - On `tile_visibility_changed(coords, REVEALED/HIDDEN)`: remove labels
  - Labels only render for nearby/targeted props (not all at once)
- `scripts/rendering/scan_progress_renderer.gd` — Node3D:
  - Single billboard progress bar above scan target
  - On `scan_started`: show at target coords (proximity auto-scan trigger)
  - On `scan_progress_updated`: update fill
  - On `scan_completed`/`scan_interrupted`: hide
- `scenes/world/prop_renderer.tscn`, `prop_label_renderer.tscn`, `scan_progress_renderer.tscn`
- **Remove ElementIconRenderer from main.tscn** (replaced by PropRenderer + PropLabelRenderer)

**Criteria:**
- [ ] PropRenderer: 5 MultiMesh pools created (flora, fauna, mineral, anomaly, generic)
- [ ] PropRenderer: prop meshes appear at correct tile positions (same mesh regardless of knowledge state)
- [ ] PropRenderer: multi-prop tiles use radial offset (N≥2 → 360°/N spacing at 0.3*HEX_SIZE radius; single prop centered)
- [ ] PropRenderer: meshes removed when tile goes REVEALED or HIDDEN
- [ ] PropLabelRenderer: UNKNOWN props show "❓ Unknown [category]" label
- [ ] PropLabelRenderer: ENCOUNTERED props show "⚠️ Unidentified Fauna (Hostile/Shy)" label
- [ ] PropLabelRenderer: CATALOGED props show real name label
- [ ] PropLabelRenderer: bulk label update on entry_cataloged — all visible ❓/⚠️ labels for that type → real name
- [ ] PropLabelRenderer: label update on entry_encountered — matching ❓ labels → ⚠️ label
- [ ] PropLabelRenderer: labels billboard toward camera (pill-shaped)
- [ ] PropLabelRenderer: labels only render for nearby/targeted props
- [ ] ScanProgressRenderer shows/hides on proximity scan lifecycle signals
- [ ] Progress bar fill updates on scan_progress_updated
- [ ] ElementIconRenderer removed from main.tscn
- [ ] Draw calls: ~5 for props + ~1 for labels + 1 for progress bar = ~7
- [ ] Build passes with zero warnings

---

### task-014: Catalog Panel UI [IMPLEMENT]

**Source:** feature-003 → Layers & Components (CatalogPanel) + UI Specs

**Scope:**
- `scenes/ui/catalog_panel.tscn` — PanelContainer bottom drawer
- `scenes/ui/catalog_entry_ui.tscn` — single entry row
- `ui/catalog_panel.gd` — panel logic:
  - 4 category tabs (Flora, Fauna, Minerals, Anomalies) via TabContainer
  - ScrollContainer per tab with VBoxContainer of entries
  - Discovery counter in header: "12/47 cataloged" from `Catalog.get_discovery_text()`
  - Refreshes on `entry_cataloged` signal
  - `panel_opened` signal for mutual exclusion
- `ui/catalog_entry_ui.gd` — icon + name + description + properties
- ScannerButton (64×64px) in HUD bottom-right
- Same bottom-drawer pattern as InventoryPanel

**Criteria:**
- [ ] CatalogPanel opens/closes on ScannerButton tap
- [ ] 4 category tabs render correct entries per category
- [ ] Entry rows display icon, name, description, properties
- [ ] Discovery counter shows correct "N/M cataloged", updates on entry_cataloged
- [ ] `panel_opened` signal emitted; mutual exclusion with InventoryPanel works
- [ ] ScannerButton visible in HUD bottom-right
- [ ] Touch targets: entry rows ~80px, tabs ~48px, close 48×48, ScannerButton 64×64
- [ ] Game continues running while open
- [ ] Build passes with zero warnings

---

### task-015: Delivery-002 Integration Test [TEST]

**Source:** AC5 + AC11

**Scope:**
Integration tests verifying delivery-002 features together:
- Inventory: add_item with real item_config → panel displays correctly
- Inventory full → floating "INVENTORY FULL" text via HUD
- Scanner: walk adjacent to uncataloged prop → proximity scan starts → progress → complete → catalog entry
- Scanner: leave range during scan → progress resets immediately
- Scanner: one scan at a time, nearest prop first
- Prop labels: ❓ label appears on reveal → proximity scan → label updates to real name
- 3-state labels: UNKNOWN shows ❓, ENCOUNTERED shows ⚠️ "Unidentified Fauna (Hostile/Shy)", CATALOGED shows real name
- Bulk label update: catalog one berry_bush → all visible berry_bush ❓ labels flip to real name
- Catalog panel: newly cataloged entry appears in correct tab, counter updates
- Catalog panel: ENCOUNTERED entry shows "Unidentified Fauna (Hostile)" with no details
- Mutual exclusion: Inventory ↔ Catalog panels
- Toxic berries in inventory: tap → warning dialog
- Full AC5 coverage (12 slots, 13th rejected, stacking, expansion)
- Full AC11 coverage (❓ icons, proximity scan flow, ENCOUNTERED state, auto-identify after, mineral scan, anomaly → journal signal)

**Criteria:**
- [ ] Walk near unknown flora → proximity scan starts → catalog entry → label update → catalog panel shows entry
- [ ] Leave range during scan → progress resets immediately, scan interrupted
- [ ] One scan at a time, nearest prop first
- [ ] Bulk label update: all visible ❓ labels of cataloged type flip to real name at once
- [ ] ENCOUNTERED fauna label: "⚠️ Unidentified Fauna (Hostile)" (no species name)
- [ ] Catalog counter counts both ENCOUNTERED and CATALOGED entries
- [ ] Inventory add → panel displays → inventory full → floating text
- [ ] Mutual exclusion: open Catalog → Inventory closes, and vice versa
- [ ] AC5 fully covered (12 slots, rejection, stacking, tool slots)
- [ ] AC11 fully covered (❓, proximity scan, ENCOUNTERED, auto-identify, mineral, anomaly trigger)
- [ ] Toxic berries: consume shows warning dialog
- [ ] Tests deterministic, clean setup/teardown
- [ ] All tests pass
- [ ] Build passes with zero warnings

## Integration Contract

### Scene Tree Additions
Cumulative (adds to delivery-001):
- Player
  - ScannerSystem (Node) — NEW
  - Inventory (RefCounted, not in tree — owned by Player script)
- World
  - PropRenderer (Node3D) — NEW, 5 MultiMesh pools for 3D prop meshes
  - PropLabelRenderer (Node3D) — NEW, floating pill labels (❓/name) above props
  - ScanProgressRenderer (Node3D) — NEW, scan progress ring
- HUD
  - InventoryPanel (bottom drawer ~45%) — NEW
  - CatalogPanel (bottom drawer ~45%) — NEW

### Bootstrap Changes
- ScannerSystem._ready() → proximity scan runs in `_process` (no PlayerInput connection needed)
- PropRenderer receives map_generated → creates prop meshes for all elements on revealed tiles
- PropLabelRenderer receives map_generated → creates ❓/⚠️/name labels based on 3-state knowledge
- PropLabelRenderer receives entry_cataloged → updates ❓ labels to real names
- Inventory created in Player._ready() with 12 base slots + 4 tool slots (survival_knife + scanner)

### Visual Smoke Test
Run the game on desktop (F5). You MUST see:
- [ ] Everything from delivery-001 still works
- [ ] 3D prop meshes visible on revealed tiles with "❓ Unknown [category]" floating labels
- [ ] Walk near prop → scan progress ring appears automatically → completes → label updates to real name
- [ ] Tap Inventory button → panel slides up showing 12 empty slots + 4 tool slots
- [ ] Tap Scanner button → catalog panel shows discovered entries (after scanning something)
- [ ] Panels are mutually exclusive — opening one closes others

### Dev Environment
No additional requirements beyond delivery-001.

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | 7 tasks created (009-015) — approved. Merged original task-003 into task-010. | /aid-detail |
| 2026-04-02 | task-013 rewritten: ElementIconRenderer → PropRenderer + PropLabelRenderer. Scene tree, criteria, and integration contract updated. | /spec-update |
| 2026-04-02 | Scan redesign applied: task-011 adds KnowledgeState + encounter_entry. task-012 rewritten for proximity auto-scan. task-013 adds 3-state labels + ElementIconRenderer removal. task-015 rewritten for proximity flow. Bootstrap/smoke test updated. | /scan-redesign-apply |
