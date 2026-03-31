# Scanner & Catalog System

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | Feature identified from REQUIREMENTS.md §5 F13, §9 AC11 | /aid-interview |
| 2026-03-31 | Full technical specification — all sections | /aid-specify |

## Source

- REQUIREMENTS.md §5 F13 (Scanner & Catalog System)
- REQUIREMENTS.md §9 AC11 (Scanner & Catalog acceptance criteria)

## Description

The scanner is the central tool and universal gate for all auto-interactions. Players press and hold toward unknown elements (?) to scan them over 2-3 seconds, adding entries to the Catalog. Once cataloged, elements are auto-identified and auto-interaction is unlocked forever for that species/type. Flora scanning reveals edible vs toxic. Fauna scanning reveals hostile vs passive. Mineral scanning reveals resource type and tool requirements. Anomaly scanning triggers narrative cutscenes. The Catalog UI shows discovered entries by category with a completion counter.

## User Stories

- As a player, I want to scan unknown things to learn about them before interacting
- As a player, I want my catalog to track everything I've discovered so I feel progress
- As a player, I want scanning to feel like a real discovery moment -- tension, then knowledge

## Priority

Must (P0 -- Core Loop)

## Acceptance Criteria

- [ ] Unknown flora shows ? icon -- no auto-gather
- [ ] Press and hold toward unknown flora -> scan progress bar -> catalog entry created
- [ ] After cataloging: flora auto-identified + auto-gather unlocked for that species
- [ ] Unknown fauna shows ? -- no auto-defend
- [ ] Scan fauna from distance -> cataloged -> auto-defend ready
- [ ] Alternatively: uncataloged hostile attacks -> surprise damage -> auto-cataloged -> auto-defend immediate
- [ ] Unknown mineral shows ? -- no auto-gather. Scan -> cataloged -> auto-gather with tool-gating
- [ ] Anomaly scanned -> cutscene triggered -> journal entry added
- [ ] Catalog UI shows all discovered entries with categories and counter ("12/47 cataloged")

## Save Integration

Array of discovered catalog entry IDs. Per-species catalog state.

---

## Technical Specification

### Data Model

#### CatalogEntry (Resource)

Each scannable element type in the game has a static definition. These are loaded at
startup from data files — not created at runtime.

| Property | Type | Description |
|----------|------|-------------|
| `entry_id` | `StringName` | Unique ID: `&"berry_bush"`, `&"iron_deposit"`, `&"thornback"`, `&"anomaly_ch1_001"` |
| `category` | `CatalogCategory` | Flora, Fauna, Mineral, Anomaly |
| `display_name` | `String` | Human-readable: "Berry Bush", "Iron Deposit", "Thornback" |
| `description` | `String` | Short flavor text for catalog UI |
| `icon` | `Texture2D` | Identified icon (shown after cataloging). Placeholder for MVP. |
| `properties` | `Dictionary` | Category-specific data (see below) |

**Category-specific properties:**

| Category | Properties Dictionary |
|----------|---------------------|
| Flora | `{ "edible": bool, "toxic": bool, "resource_type": StringName }` — e.g., `{ "edible": true, "toxic": false, "resource_type": &"berries" }` |
| Mineral | `{ "resource_type": StringName, "tool_required": StringName }` — e.g., `{ "resource_type": &"ore", "tool_required": &"stone_pickaxe" }` |
| Fauna | `{ "hostile": bool, "damage": int, "hp": int }` — e.g., `{ "hostile": true, "damage": 10, "hp": 20 }` |
| Anomaly | `{ "journal_entry_id": StringName, "cutscene_id": StringName }` — e.g., `{ "journal_entry_id": &"anomaly_ch1_001", "cutscene_id": &"cs_first_anomaly" }` |

#### CatalogCategory Enum

```gdscript
enum CatalogCategory { FLORA, FAUNA, MINERAL, ANOMALY }
```

#### ScanState Enum

```gdscript
enum ScanState { IDLE, SCANNING, COMPLETE, REJECTED }
```

- `IDLE` — no scan in progress
- `SCANNING` — scan progress bar active, player holding
- `COMPLETE` — scan finished, entry added to catalog
- `REJECTED` — nothing scannable at target coords

#### Catalog (RefCounted)

Runtime catalog state — tracks which entries the player has discovered. Owned by
ScannerSystem node.

| Property | Type | Description |
|----------|------|-------------|
| `_discovered` | `Dictionary[StringName, bool]` | entry_id → true. Missing = not cataloged. |
| `_all_entries` | `Dictionary[StringName, CatalogEntry]` | All possible entries, loaded from data files. |
| `_total_count` | `int` | Total scannable entries in current chapter (for "12/47" counter). |

**Public API:**

```gdscript
# Query
func is_cataloged(entry_id: StringName) -> bool
func get_entry(entry_id: StringName) -> CatalogEntry
func get_discovered_entries() -> Array[CatalogEntry]
func get_discovered_by_category(category: CatalogCategory) -> Array[CatalogEntry]
func get_discovery_count() -> int          # number discovered
func get_total_count() -> int              # total possible
func get_discovery_text() -> String        # "12/47 cataloged"

# Mutation
func catalog_entry(entry_id: StringName) -> void  # marks as discovered, emits signal

# Eligibility (used by scan flow)
func get_scannable_at(coords: Vector2i) -> StringName
    # Returns entry_id of first uncataloged scannable element at coords, or &"" if none.
    # Checks: tile.resource_nodes[].type, tile.anomaly, FaunaManager positions.
    # Maps resource/anomaly/fauna type → entry_id via _all_entries lookup.
```

#### ScannerSystem Properties (on ScannerSystem Node)

| Property | Type | Description |
|----------|------|-------------|
| `_catalog` | `Catalog` | RefCounted catalog instance |
| `_scan_state` | `ScanState` | Current scan lifecycle state |
| `_scan_target_coords` | `Vector2i` | Tile being scanned |
| `_scan_target_entry_id` | `StringName` | Entry being scanned |
| `_scan_progress` | `float` | 0.0 → 1.0, increments during hold |
| `_scan_duration` | `float` | Seconds to complete scan (2.0-3.0, configurable per category) |
| `_scan_range` | `int` | Max hex distance from player to scan target (default: 2) |

#### Scan Duration Config

```gdscript
const SCAN_DURATIONS: Dictionary = {
    CatalogCategory.FLORA:   2.0,  # seconds
    CatalogCategory.MINERAL: 2.0,
    CatalogCategory.FAUNA:   3.0,  # longer — risky to hold near unknown creature
    CatalogCategory.ANOMALY: 3.0,  # narrative weight — moment of discovery
}
```

#### Signals

```gdscript
# Scan lifecycle
signal scan_started(entry_id: StringName, coords: Vector2i)
signal scan_progress_updated(progress: float)       # 0.0-1.0, emitted each frame
signal scan_completed(entry_id: StringName)          # entry added to catalog
signal scan_cancelled()                              # player released early or moved out of range
signal scan_rejected(coords: Vector2i)               # nothing scannable at coords (consumed by feature-002)

# Catalog changes
signal entry_cataloged(entry_id: StringName, category: CatalogCategory)
signal surprise_cataloged(entry_id: StringName)      # auto-catalog from surprise attack (feature-010)

# Passive identification
signal element_identified(coords: Vector2i, entry_id: StringName)  # cataloged element enters visibility range
signal element_unknown(coords: Vector2i)                            # uncataloged element enters visibility range (show ❓)
```

#### Save Data

```json
{
  "catalog": {
    "discovered": ["berry_bush", "fiber_grass", "wood_tree", "thornback", "anomaly_ch1_001"]
  }
}
```

Only discovered entry IDs are saved. Static entry definitions loaded from data files.
Chapter ID determines which entries are in the world — future chapters add entries
without modifying save format.

#### Cross-Feature Data Contracts

| This feature queries | Source | What it reads |
|---------------------|--------|---------------|
| `HexGrid.get_tile(coords).resource_nodes[].type` | feature-001 | Resource types on tile (flora/mineral) |
| `HexGrid.get_tile(coords).anomaly` | feature-001 | Anomaly ID on tile |
| FaunaManager query (fauna at coords) | feature-010 | Fauna species at position |

| This feature is queried by | Consumer | What it provides |
|---------------------------|----------|-----------------|
| feature-004 (auto-interaction) | `is_cataloged(type)` — gates auto-gather/auto-defend |
| feature-002 (player_input.gd) | `scan_rejected` signal — fallback to joystick |
| feature-012 (HUD) | Catalog UI data (`get_discovered_entries`, counters) |
| feature-011 (journal) | `entry_cataloged` + anomaly properties for cutscene triggers |

---

### Feature Flow

#### Active Scan Flow (press-and-hold)

```
feature-002 emits scan_hold_started(coords: Vector2i)
  │
  ├─ ScannerSystem receives signal
  │
  ├─ Check eligibility: Catalog.get_scannable_at(coords)
  │     Checks tile.resource_nodes, tile.anomaly, FaunaManager positions
  │     Maps element → entry_id via catalog lookup
  │     ├─ entry_id found (uncataloged element exists):
  │     │     _scan_target_coords = coords
  │     │     _scan_target_entry_id = entry_id
  │     │     _scan_state = SCANNING
  │     │     _scan_progress = 0.0
  │     │     Look up duration from SCAN_DURATIONS[entry.category]
  │     │     Emit scan_started(entry_id, coords)
  │     │     → UI: show scan progress bar over target
  │     │
  │     └─ No uncataloged element:
  │           _scan_state = REJECTED
  │           Emit scan_rejected(coords)
  │           → feature-002 falls back to joystick
  │           Done.
  │
  ├─ Each frame while SCANNING (_process):
  │     ├─ Receive scan_hold_update(screen_pos) from feature-002
  │     │
  │     ├─ Range check: HexGrid.distance(player.current_tile, _scan_target_coords)
  │     │     > _scan_range → cancel scan (player walked away or target too far)
  │     │
  │     ├─ Drift check: convert screen_pos to world coords, check if still pointing
  │     │     at _scan_target_coords tile (within hex boundary)
  │     │     Drifted to different tile → cancel scan
  │     │
  │     ├─ _scan_progress += delta / _scan_duration
  │     │     Emit scan_progress_updated(_scan_progress)
  │     │     → UI: update progress bar fill
  │     │
  │     └─ if _scan_progress >= 1.0:
  │           → Scan complete (see below)
  │
  ├─ On scan_hold_ended() from feature-002 (touch UP):
  │     if _scan_state == SCANNING AND _scan_progress < 1.0:
  │       _scan_state = IDLE
  │       _scan_progress = 0.0
  │       Emit scan_cancelled()
  │       → UI: hide progress bar
  │
  └─ On scan complete (_scan_progress >= 1.0):
        _scan_state = COMPLETE
        Catalog.catalog_entry(_scan_target_entry_id)
        Emit scan_completed(_scan_target_entry_id)
        Emit entry_cataloged(_scan_target_entry_id, entry.category)
        → UI: ❓ icon replaced with identified icon (bulk swap for all visible)
        → UI: brief "Cataloged!" feedback
        → Auto-interaction (feature-004) now unlocked for this type:
          - Cataloged edible flora → auto-gather enabled
          - Cataloged toxic flora → auto-gather ALSO enabled (player collects
            knowingly — the gate is catalog status, not edibility. Danger is in
            consuming, not gathering. Feature-007 handles toxic damage on use.)
          - Cataloged mineral → auto-gather with tool-gating
          - Cataloged hostile fauna → auto-defend active
          - Cataloged passive fauna → ignored by auto-interaction
        if entry.category == ANOMALY:
          → feature-011 (journal) handles cutscene trigger via entry_cataloged signal
        _scan_state = IDLE
        _scan_progress = 0.0
```

#### Surprise Catalog Flow (fauna first-hit, feature-010 owned)

```
feature-010 emits fauna_attacked_player(fauna_id, damage, species_type: StringName)
  │
  ├─ ScannerSystem receives signal
  │
  ├─ Check: is species_type already cataloged?
  │     if Catalog.is_cataloged(species_type): return (already known)
  │
  ├─ Auto-catalog:
  │     Catalog.catalog_entry(species_type)
  │     Emit surprise_cataloged(species_type)
  │     Emit entry_cataloged(species_type, CatalogCategory.FAUNA)
  │     → UI: ❓ icon on attacker changes to hostile (red) icon
  │     → Auto-defend (feature-004) activates immediately for this species
  │
  └─ Done — no scan progress bar, instant catalog on first hit
```

**Note on signal from feature-010:** The `fauna_attacked_player` signal needs the
`species_type: StringName` added to its signature (beyond the pre-redesign
`id, damage` args). Feature-010 SPEC must include this.

#### Movement Lock During Scan (this feature's half)

Feature-002 states: "movement doesn't start during scan hold." This feature's
complementary guarantee: **while `_scan_state == SCANNING`, ScannerSystem does NOT
emit `scan_rejected`.** It holds the input claim until scan completes or the player
releases (touch UP → `scan_hold_ended` → `scan_cancelled`).

The two features document the same constraint from their own perspective:
- Feature-002: player_input.gd won't emit movement signals while scan is active
- Feature-003: ScannerSystem won't release the input claim while scanning

Only two ways out of SCANNING: completion (`scan_completed`) or cancellation
(`scan_cancelled` on touch UP, range exceeded, or drift). Never `scan_rejected`.

#### Passive Identification Flow (on tile reveal/enter)

```
HexGrid emits tile_revealed(coords) or tile_visibility_changed(coords, VISIBLE)
  │
  ├─ ScannerSystem receives signal
  │
  ├─ Check tile for elements:
  │     For each resource_node in tile.resource_nodes:
  │       entry_id = _map_resource_to_entry(resource_node.type)
  │       if Catalog.is_cataloged(entry_id):
  │         Emit element_identified(coords, entry_id)
  │         → Renderer: show correct icon (green plant, pickaxe rock, etc.)
  │       else:
  │         Emit element_unknown(coords)
  │         → Renderer: show ❓ icon
  │
  │     If tile.anomaly != &"":
  │       if Catalog.is_cataloged(tile.anomaly):
  │         Emit element_identified(coords, tile.anomaly)
  │       else:
  │         Emit element_unknown(coords)
  │
  │     (Fauna handled separately — FaunaManager emits fauna_spawned with position,
  │      ScannerSystem checks catalog state for that species and emits appropriate icon signal)
  │
  └─ Done
```

This runs once per tile when it becomes VISIBLE. The renderer subscribes and updates
world-space icons accordingly.

#### Resource-to-Entry Mapping

`_map_resource_to_entry(resource_type: StringName) -> StringName` maps ResourceNode
types to catalog entry IDs. This is a static lookup table:

```gdscript
const RESOURCE_TO_ENTRY: Dictionary = {
    &"wood":           &"wood_tree",
    &"berries":        &"berry_bush",
    &"toxic_berries":  &"toxic_berry_bush",
    &"fiber":          &"fiber_grass",
    &"stone":          &"stone_deposit",
    &"ore":            &"iron_deposit",
    &"crystal":        &"crystal_cluster",
}
```

One resource type maps to exactly one catalog entry. Future chapters can add entries.

---

### Layers & Components

#### Scene Tree Additions

```
Main (Node)
  └─ World (Node3D)
       ├─ HexGridRenderer (Node3D)              [feature-001]
       ├─ ElementIconRenderer (Node3D)          ← NEW (❓ and identified icons on tiles)
       ├─ ScanProgressRenderer (Node3D)         ← NEW (scan progress bar over target)
       ├─ Player (Node3D)                       [feature-002]
       │    ├─ PlayerVisual (Node3D)
       │    ├─ PlayerInput (Node)
       │    └─ ScannerSystem (Node)             ← NEW
       └─ Camera3D                              [feature-002]
  └─ JoystickOverlay (CanvasLayer)              [feature-002]
  └─ HUD (CanvasLayer)                          [feature-012]
       ├─ ... (HUD buttons, stat bars)
       ├─ ScannerButton (TextureButton)         ← NEW (opens Catalog panel)
       └─ CatalogPanel (PanelContainer)         ← NEW (bottom drawer)
            ├─ CategoryTabs (TabContainer)
            │    ├─ FloraList (ScrollContainer > VBoxContainer)
            │    ├─ FaunaList (ScrollContainer > VBoxContainer)
            │    ├─ MineralList (ScrollContainer > VBoxContainer)
            │    └─ AnomalyList (ScrollContainer > VBoxContainer)
            └─ DiscoveryCounter (Label)         ← "12/47 cataloged"
```

#### File Structure

```
scripts/
  scanner/
    scanner_system.gd        # Node (child of Player) — scan lifecycle, eligibility,
                              #   passive identification, surprise catalog handler
    catalog.gd               # RefCounted — catalog data, discovery state, queries
    catalog_entry.gd         # Resource — static entry definition

  rendering/
    element_icon_renderer.gd # Node3D — ❓ and identified icons on world tiles
    scan_progress_renderer.gd # Node3D — progress bar billboard over scan target

scenes/
  ui/
    catalog_panel.tscn       # PanelContainer — bottom drawer with category tabs
    catalog_entry_ui.tscn    # Single entry row (icon, name, description, properties)

ui/
  catalog_panel.gd           # Control — panel open/close, entry rendering, counters
  catalog_entry_ui.gd        # Control — single catalog entry display

data/
  catalog/
    flora.tres               # Array of CatalogEntry resources for flora
    fauna.tres               # Array of CatalogEntry resources for fauna
    minerals.tres            # Array of CatalogEntry resources for minerals
    anomalies.tres           # Array of CatalogEntry resources for anomalies
```

#### Component Responsibilities

| Component | Responsibility | Depends On |
|-----------|---------------|------------|
| `scanner_system.gd` | Child Node of Player. Owns `Catalog` instance. Receives `scan_hold_started`/`update`/`ended` from feature-002. Checks eligibility (`get_scannable_at`). Manages scan lifecycle (progress, complete, cancel). Handles passive identification on `tile_revealed`/`tile_visibility_changed`. Handles surprise catalog on `fauna_attacked_player`. Emits all scanner/catalog signals. | `HexGrid` (tile queries), `FaunaManager` feature-010 (fauna position queries + surprise signal), `player_input.gd` feature-002 (scan hold signals) |
| `catalog.gd` | RefCounted owned by ScannerSystem. Discovery state (`_discovered`). All query APIs (`is_cataloged`, `get_entry`, `get_scannable_at`, counters). `catalog_entry()` mutation. `get_save_data()`/`load_save_data()`. | `catalog_entry.gd` (static definitions), `HexGrid` (for `get_scannable_at` tile queries), `FaunaManager` (for fauna position in `get_scannable_at`) |
| `catalog_entry.gd` | Resource — static definition. Loaded from `.tres` data files. No runtime mutation. | Nothing (data only) |
| `element_icon_renderer.gd` | Node3D under World. MultiMesh per icon type (~5 pools: ❓, flora, fauna, mineral, anomaly). Maintains tile→entry mapping for bulk swap on `entry_cataloged`. Updates on `element_identified`/`element_unknown`/`entry_cataloged`. | `ScannerSystem` (signals) |
| `scan_progress_renderer.gd` | Node3D under World. Shows a progress bar billboard above the scan target tile during active scan. Updates on `scan_started`/`scan_progress_updated`/`scan_completed`/`scan_cancelled`. Single instance (only one scan at a time). | `ScannerSystem` (signals), `HexGrid` (`axial_to_world` for positioning) |
| `catalog_panel.gd` | Control on CatalogPanel. Bottom drawer (same pattern as Inventory/Crafting/Build panels). 4 category tabs, entry list per category, discovery counter. Mutual exclusion with other panels. | `Catalog` (query APIs for entries and counters) |

#### Signal Wiring — Complete

```
feature-002 (player_input.gd)               scanner_system.gd
  scan_hold_started(coords)              ──►  check eligibility, start or reject
  scan_hold_update(screen_pos)           ──►  drift/range check during scan
  scan_hold_ended()                      ──►  cancel if incomplete

scanner_system.gd                            feature-002 (player_input.gd)
  scan_rejected(coords)                  ──►  fall back to joystick

feature-010 (FaunaManager)                   scanner_system.gd
  fauna_attacked_player(id, dmg, species)──►  surprise catalog if uncataloged

HexGrid signals                              scanner_system.gd
  tile_revealed(coords)                  ──►  passive identification check
  tile_visibility_changed(coords, VISIBLE)──► passive identification check

scanner_system.gd                            element_icon_renderer.gd
  element_identified(coords, entry_id)   ──►  add instance to identified MultiMesh pool
  element_unknown(coords)                ──►  add instance to ❓ MultiMesh pool
  entry_cataloged(entry_id, category)    ──►  BULK SWAP: iterate all visible tiles,
                                              move matching ❓ instances → identified pool.
                                              This is the "biome conquered" satisfaction moment.

scanner_system.gd                            scan_progress_renderer.gd
  scan_started(entry_id, coords)         ──►  show progress bar at tile
  scan_progress_updated(progress)        ──►  update bar fill
  scan_completed(entry_id)               ──►  hide bar, flash "Cataloged!"
  scan_cancelled()                       ──►  hide bar

scanner_system.gd                            feature-011 (journal)
  entry_cataloged(entry_id, category)    ──►  if ANOMALY: trigger cutscene

scanner_system.gd                            feature-004 (auto-interaction)
  entry_cataloged(entry_id, category)    ──►  unlock auto-gather/auto-defend for type

scanner_system.gd                            catalog_panel.gd
  entry_cataloged(entry_id, category)    ──►  refresh entry list + counter
```

#### Element Icon Rendering

**MultiMesh per icon type** — same proven pattern as hex tiles and resources.

One `MultiMeshInstance3D` per icon category:
- ❓ unknown (shared across all uncataloged elements)
- Flora identified (green plant icon)
- Fauna identified (creature icon — red if hostile, green if passive)
- Mineral identified (rock/gem icon)
- Anomaly identified (special marker icon)

**~5 MultiMeshInstance3D = ~5 draw calls.** Player visibility radius 2 = ~19 tiles,
1-3 elements each = ~20-50 instances distributed across the pools. Well within budget.

**Icon positioning:** Floats above tile center at a fixed Y offset. Uses
`HexGrid.axial_to_world(coords)` + Y offset. Billboard via shader or Godot's
`BaseMaterial3D.billboard_mode = BILLBOARD_ENABLED`.

**Icon lifecycle:**
- Tile becomes VISIBLE → ScannerSystem checks catalog → emit `element_identified` or
  `element_unknown` → renderer adds instance to appropriate MultiMesh pool
- Tile becomes REVEALED → remove instances (dimmed tile, no icons)
- Tile becomes HIDDEN → remove instances
- Entry cataloged → `entry_cataloged` signal → renderer iterates ALL visible tiles,
  swaps matching ❓ instances from the unknown pool to the correct identified pool.
  This is the "biome conquered" moment — all ❓s for that type flip at once.

**Swap on catalog mechanism:** `ElementIconRenderer` maintains a mapping
`Dictionary[Vector2i, Array[StringName]]` — tile coords → list of element entry_ids
currently displayed. On `entry_cataloged(entry_id)`, iterate the mapping, find all
tiles showing that entry_id as ❓, remove from unknown MultiMesh, add to identified
MultiMesh. O(n) where n = visible tiles with that element type — typically 5-15.

#### Catalog Panel UI

Bottom drawer — same pattern as Inventory (feature-005), Crafting (feature-006),
Build (feature-009). Full width, ~45% height, semi-transparent.

```
┌──────────────────────────┐
│      (game world)        │  ← ~55% visible
├──────────────────────────┤
│  CATALOG  12/47      [X] │  ← header + counter + close
│ [Flora][Fauna][Min][Anom]│  ← category tabs
│ ─────────────────────────│
│ ┌──────────────────────┐ │
│ │ [icon] Berry Bush    │ │  ← entry row
│ │   Edible. Restores   │ │
│ │   hunger.            │ │
│ └──────────────────────┘ │
│ ┌──────────────────────┐ │
│ │ [icon] Iron Deposit  │ │  ← scrollable
│ │   Requires Pickaxe.  │ │
│ └──────────────────────┘ │  ← ~45% height
└──────────────────────────┘
```

- **Mutual exclusion** with all other panels (panel_opened signal pattern)
- **Opens via ScannerButton** in HUD (bottom-right, 64×64px)
- **Category tabs:** Flora, Fauna, Minerals, Anomalies. Each tab has its own
  ScrollContainer with VBoxContainer of entries.
- **Entry display:** Icon + name + description + properties summary. Read-only.
- **Discovery counter:** "12/47 cataloged" in header. Updates on `entry_cataloged`.
- **Game continues running** — no pause.
- **Touch targets:** Entry rows ~80px height, tabs ~48px, close 48×48, ScannerButton 64×64.

---

### Mobile Specs

#### Performance — Scanner Processing

| Operation | Cost | When |
|-----------|------|------|
| Eligibility check (`get_scannable_at`) | O(1): tile lookup + resource_nodes iteration (1-3) + fauna query + catalog hash lookup | Once at 300ms hold threshold |
| Scan progress tick | One float add per frame | During active scan only (2-3 seconds) |
| Passive identification (tile reveal) | O(n): n = resource_nodes on tile (1-3) + anomaly check | Once per tile when VISIBLE |
| Surprise catalog | O(1): catalog hash lookup + insert | Once per new hostile species |

No per-frame cost when not scanning. Passive identification is event-driven
(signal on tile reveal), not polled.

#### Draw Call Budget — Scanner Share

| Renderer | Estimated Draw Calls | Notes |
|----------|---------------------|-------|
| ElementIconRenderer | ~5 | MultiMesh per icon type: ❓, flora, fauna, mineral, anomaly |
| ScanProgressRenderer | 1 | Single billboard, only during active scan |
| CatalogPanel (UI) | 0 | CanvasLayer, not 3D draw calls |
| **Scanner total** | **~6** | Within remaining ~90 budget after terrain (~5) |

#### Scan Hold Latency

The 300ms hold threshold is a design constant, not latency. Once the threshold fires:

| Step | Time |
|------|------|
| feature-002 emits `scan_hold_started(coords)` | ~0ms (signal) |
| ScannerSystem `get_scannable_at` eligibility check | <1ms |
| Response: `scan_started` or `scan_rejected` | <1ms |
| **Total from threshold to response** | **<2ms (within same frame)** |

feature-002 has a 2-frame (32ms) defensive timeout for the response. The scanner
responds within the same frame — timeout never fires in practice.

#### Touch Interaction

- **Scan hold:** Player holds on ❓ element for 2-3 seconds. No additional touch
  targets — the ❓ icon IS the target, positioned on the hex tile (54-72px).
- **Catalog panel:** Same touch targets as other bottom drawers. Entry rows ~80px,
  tabs ~48px, buttons ≥48dp.
- **No platform differences.** Same touch events on iOS and Android.

#### Memory

- `Catalog._discovered`: Dictionary with ~50 entries max (Chapter 1). Negligible.
- `CatalogEntry` resources: ~50 static definitions. <100KB total.
- Element icons: 5 MultiMesh pools × ~50 instances each = ~250 instances max.
  ~64 bytes per instance (transform + custom data). Total: <100KB.
- Scan progress bar: 1 instance. Negligible.
