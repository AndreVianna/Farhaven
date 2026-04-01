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
  │                                    task-013 (Element icon + scan
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
| 013 | Element icon + scan progress renderers | IMPLEMENT | 012 | -- |
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
  - `_discovered: Dictionary[StringName, bool]`
  - `_all_entries: Dictionary[StringName, CatalogEntry]`
  - `_total_count: int`
  - Full API: `is_cataloged`, `get_entry`, `get_discovered_entries`,
    `get_discovered_by_category`, `get_discovery_count`, `get_total_count`,
    `get_discovery_text`, `catalog_entry`, `get_scannable_at`
  - `RESOURCE_TO_ENTRY` mapping: wood→wood_tree, berries→berry_bush,
    toxic_berries→toxic_berry_bush, fiber→fiber_grass, stone→stone_deposit,
    ore→iron_deposit, crystal→crystal_cluster
  - `get_save_data()` / `load_save_data()`
- Data files: `data/catalog/flora.tres`, `fauna.tres`, `minerals.tres`, `anomalies.tres`
  with Chapter 1 entries

**Criteria:**
- [ ] Unit tests: is_cataloged before/after catalog_entry call
- [ ] Unit tests: get_discovered_entries, get_discovered_by_category filtering
- [ ] Unit tests: get_discovery_count / get_total_count / get_discovery_text format
- [ ] Unit tests: catalog_entry emits entry_cataloged signal, marks discovered
- [ ] Unit tests: get_scannable_at returns entry_id for uncataloged element, &"" for cataloged
- [ ] Unit tests: save/load round-trip (discovered IDs preserved)
- [ ] Unit tests: RESOURCE_TO_ENTRY mapping — all 7 resource types map to valid entry IDs
- [ ] Data files: at least 3 flora (including berry_bush + toxic_berry_bush), 1 fauna (thornback),
      3 minerals, 1 anomaly for Chapter 1
- [ ] Build passes with zero warnings

---

### task-012: Scanner System Core [IMPLEMENT]

**Source:** feature-003 → Data Model (ScannerSystem) + Feature Flow

**Scope:**
- `scripts/scanner/scanner_system.gd` — Node (child of Player):
  - `ScanState` enum: IDLE, SCANNING, COMPLETE, REJECTED
  - Properties: `_catalog`, `_scan_state`, `_scan_target_coords`, `_scan_target_entry_id`,
    `_scan_progress`, `_scan_duration`, `_scan_range` (2 hexes)
  - `SCAN_DURATIONS` config: Flora 2.0s, Mineral 2.0s, Fauna 3.0s, Anomaly 3.0s
  - **Active scan flow:** receive `scan_hold_started(coords)` from PlayerInput →
    `get_scannable_at(coords)` → claim or reject → progress tick in `_process` →
    range + drift checks → complete or cancel
  - **Surprise catalog:** receive `fauna_attacked_player(id, damage, species)` →
    if uncataloged → instant `catalog_entry`. Stub connection (activates when F-010 arrives).
  - **Passive identification:** on `tile_revealed`/`tile_visibility_changed(VISIBLE)` →
    check resource_nodes + anomaly against catalog → emit `element_identified` or
    `element_unknown`
  - **Movement lock:** while SCANNING, never emit `scan_rejected`
  - Signals: `scan_started`, `scan_progress_updated`, `scan_completed`, `scan_cancelled`,
    `scan_rejected`, `entry_cataloged`, `surprise_cataloged`, `element_identified`,
    `element_unknown`
  - Connect to PlayerInput scan_hold signals (from delivery-001)

**Criteria:**
- [ ] Unit tests: eligibility (uncataloged returns entry_id, cataloged returns &"")
- [ ] Unit tests: scan lifecycle (IDLE→SCANNING→COMPLETE, IDLE→SCANNING→cancelled on touch UP)
- [ ] Unit tests: scan duration per category (flora 2s, fauna 3s, anomaly 3s)
- [ ] Unit tests: range check (cancel if player > _scan_range from target)
- [ ] Unit tests: surprise catalog (uncataloged species → instant catalog_entry)
- [ ] Unit tests: passive ID (cataloged resource → element_identified, uncataloged → element_unknown)
- [ ] scan_rejected never emitted while _scan_state == SCANNING
- [ ] entry_cataloged emitted on completion with correct entry_id + category
- [ ] Connects to PlayerInput scan_hold signals from delivery-001
- [ ] Build passes with zero warnings

---

### task-013: Element Icon + Scan Progress Renderers [IMPLEMENT]

**Source:** feature-003 → Layers & Components (renderers)

**Scope:**
- `scripts/rendering/element_icon_renderer.gd` — Node3D:
  - 5 MultiMeshInstance3D pools: unknown (❓), flora, fauna, mineral, anomaly
  - `_tile_entries: Dictionary[Vector2i, Array[StringName]]` — tile → displayed entry IDs
  - On `element_identified(coords, entry_id)`: add to identified pool
  - On `element_unknown(coords)`: add to unknown (❓) pool
  - On `entry_cataloged(entry_id, category)`: bulk swap — iterate all visible tiles,
    move matching ❓ instances → identified pool. "Biome conquered" moment.
  - On `tile_visibility_changed(coords, REVEALED/HIDDEN)`: remove instances
  - Icon positioning: `HexGrid.axial_to_world(coords)` + Y offset, billboard
- `scripts/rendering/scan_progress_renderer.gd` — Node3D:
  - Single billboard progress bar above scan target
  - On `scan_started`: show at target coords
  - On `scan_progress_updated`: update fill
  - On `scan_completed`/`scan_cancelled`: hide
- `scenes/world/element_icon_renderer.tscn`, `scan_progress_renderer.tscn`

**Criteria:**
- [ ] 5 MultiMesh pools created (unknown, flora, fauna, mineral, anomaly)
- [ ] Unknown elements show ❓ icon at correct tile positions
- [ ] Identified elements show category-appropriate icon
- [ ] Bulk swap on entry_cataloged: all visible ❓ for that type → identified pool
- [ ] Icons removed when tile goes REVEALED or HIDDEN
- [ ] ScanProgressRenderer shows/hides on scan lifecycle signals
- [ ] Progress bar fill updates on scan_progress_updated
- [ ] Icons billboard toward camera
- [ ] Draw calls: ~5 for icons + 1 for progress bar = ~6
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

**Source:** AC5 + AC11 + AC2 (scan input complete)

**Scope:**
Integration tests verifying delivery-002 features together:
- Inventory: add_item with real item_config → panel displays correctly
- Inventory full → floating "INVENTORY FULL" text via HUD
- Scanner: scan_hold_started → eligibility check → progress → complete → catalog entry
- Element icons: ❓ appears on reveal → scan → icon swaps to identified
- Bulk swap: catalog one berry_bush → all visible berry_bush ❓ flip to identified
- Catalog panel: newly cataloged entry appears in correct tab, counter updates
- Mutual exclusion: Inventory ↔ Catalog panels
- Toxic berries in inventory: tap → warning dialog
- Full AC5 coverage (12 slots, 13th rejected, stacking, expansion)
- Full AC11 coverage (❓ icons, scan flow, auto-identify after, mineral scan, anomaly → journal signal)
- AC2 completion (scan input — scan_hold fires with coords)

**Criteria:**
- [ ] Scan unknown flora → catalog entry → icon swap → catalog panel shows entry
- [ ] Bulk swap: all visible ❓ of cataloged type flip at once
- [ ] Inventory add → panel displays → inventory full → floating text
- [ ] Mutual exclusion: open Catalog → Inventory closes, and vice versa
- [ ] AC5 fully covered (12 slots, rejection, stacking, tool slots)
- [ ] AC11 fully covered (❓, scan, auto-identify, mineral, anomaly trigger)
- [ ] AC2 scan input verified (scan_hold signals fire with correct coords)
- [ ] Toxic berries: consume shows warning dialog
- [ ] Tests deterministic, clean setup/teardown
- [ ] All tests pass
- [ ] Build passes with zero warnings

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | 7 tasks created (009-015) — approved. Merged original task-003 into task-010. | /aid-detail |
