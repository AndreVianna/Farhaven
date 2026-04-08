# Scanner & Catalog System

> **SUPERSEDED NOTE (2026-04-08):** This feature spec predates the fog-of-war removal and the PR#10 unified-props refactor. References to `tile_revealed`, `tile_visibility_changed`, and `fog_state` are no longer accurate — ScannerSystem now listens only to `HexGrid.map_generated` for bootstrap. See `.aid/knowledge/api-contracts.md` for the current ScannerSystem API. The historical plan is preserved as-is; do not rewrite.

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | Feature identified from REQUIREMENTS.md §5 F13, §9 AC11 | /aid-interview |
| 2026-03-31 | Full technical specification — all sections | /aid-specify |
| 2026-04-01 | I6: _scan_range (2 hexes) noted as [TUNING_REQUIRED] for HEX_SIZE=3.0; range transitioning to circular world-unit area. I2: Touch target estimate marked [TUNING_REQUIRED]. | /pivot-cascade |
| 2026-04-02 | Architecture: ElementIconRenderer → PropRenderer + PropLabelRenderer. 3D prop meshes replace billboard icons; floating pill labels show ❓/name. Catalog changes label text, not mesh. | /spec-update |
| 2026-04-02 | Major redesign: press-and-hold → proximity auto-scan. Three-state knowledge (UNKNOWN/ENCOUNTERED/CATALOGED). Trap + Sneak mechanics designed but deferred post-MVP. See docs/design/scan-redesign-2026-04-02.md | /design-session |
| 2026-04-02 | Full spec rewrite: proximity auto-scan, 3-state knowledge system, ENCOUNTERED labels, resolved design decisions applied. Old press-and-hold flow, ScanState machine, scan_hold signals, scan_rejected, drift/range checks all removed. | /scan-redesign-apply |
| 2026-04-04 | Sub-hex + unified props: scanning targets are now `tile.props[]` filtered by category. `get_scannable_at()` queries props instead of `prop_nodes[]`/`anomaly`. Passive identification operates on `tile.props`. Element signals reference props. | /spec-update |

> **📐 Design Note (2026-04-02):** The scan system has been fundamentally redesigned from press-and-hold to proximity-based auto-scan. Props now have three knowledge states (UNKNOWN → ENCOUNTERED → CATALOGED) instead of two. Fauna scanning introduces Trap (passive) and Sneak Scan (hostile) mechanics, both deferred post-MVP. Full design rationale and state transition details: [`docs/design/scan-redesign-2026-04-02.md`](../../../../docs/design/scan-redesign-2026-04-02.md)

## Source

- REQUIREMENTS.md §5 F13 (Scanner & Catalog System)
- REQUIREMENTS.md §9 AC11 (Scanner & Catalog acceptance criteria)

## Description

The scanner is the central tool and universal gate for all auto-interactions. When the player walks near an unknown element (❓), scanning starts automatically — no button press, no hold, just proximity. The scan progress bar fills over 2-3 seconds while the player stays in range (1 hex adjacent). Moving out of range interrupts the scan and resets progress immediately (no grace period). One scan at a time, nearest prop first (consistent with chain gathering).

Props have three knowledge states: **UNKNOWN** (❓ — never seen), **ENCOUNTERED** (⚠️ — hostile fauna that attacked or passive fauna that fled, identity unknown), and **CATALOGED** (✅ — fully identified, all details known). Flora and minerals skip ENCOUNTERED and go directly UNKNOWN → CATALOGED via proximity scan. Fauna hostile goes UNKNOWN → ENCOUNTERED on first attack, and ENCOUNTERED → CATALOGED via Sneak Scan (deferred post-MVP). Passive fauna registers ENCOUNTERED when it flees on player approach; full cataloging requires Trap mechanic (deferred post-MVP).

Once cataloged, elements are auto-identified and auto-interaction is unlocked forever for that species/type. Flora scanning reveals edible vs toxic. Fauna scanning reveals hostile vs passive. Mineral scanning reveals resource type and tool requirements. Anomaly scanning triggers narrative cutscenes.

The Catalog UI shows entries by category with a counter. The counter shows total entries (ENCOUNTERED + CATALOGED both count). ENCOUNTERED entries display as "Unidentified Fauna (Hostile)" or "Unidentified Fauna (Shy)" with no species details. CATALOGED entries show full info (name, drops, edible, etc.).

## User Stories

- As a player, I want scanning to happen automatically when I walk near things so movement IS interaction
- As a player, I want my catalog to track everything I've discovered so I feel progress
- As a player, I want scanning to feel like a real discovery moment — tension, then knowledge

## Priority

Must (P0 — Core Loop)

## Acceptance Criteria

- [ ] Unknown flora shows ❓ icon — no auto-gather
- [ ] Walk adjacent to unknown flora → scan progress bar starts automatically → catalog entry created
- [ ] Leave range during scan → progress resets immediately (no grace period)
- [ ] After cataloging: flora auto-identified + auto-gather unlocked for that species
- [ ] Unknown fauna shows ❓ — no auto-defend
- [ ] Hostile fauna attacks uncataloged → ENCOUNTERED state → "Unidentified Fauna (Hostile)" label → auto-defend activates
- [ ] Passive fauna flees on approach → ENCOUNTERED state → "Unidentified Fauna (Shy)" label
- [ ] Unknown mineral shows ❓ — no auto-gather. Proximity scan → cataloged → auto-gather with tool-gating
- [ ] Anomaly scanned → cutscene triggered → journal entry added
- [ ] Catalog UI shows all entries with counter ("X entries" — ENCOUNTERED + CATALOGED both count)
- [ ] ENCOUNTERED entries show "Unidentified Fauna (Hostile/Shy)" with no details
- [ ] CATALOGED entries show full info (name, drops, edible, etc.)
- [ ] Only one scan at a time, nearest prop first

## Save Integration

Array of discovered catalog entry IDs. Per-species knowledge state (UNKNOWN/ENCOUNTERED/CATALOGED).

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

#### KnowledgeState Enum

```gdscript
enum KnowledgeState { UNKNOWN, ENCOUNTERED, CATALOGED }
```

- `UNKNOWN` — never seen, shows ❓
- `ENCOUNTERED` — fauna only: hostile attacked player or passive fled. Shows ⚠️ "Unidentified Fauna (Hostile)" or "Unidentified Fauna (Shy)". Auto-defend activates for hostile. No species name, no details.
- `CATALOGED` — fully identified. Shows real name + all details. Auto-interaction fully unlocked.

**State transitions by element type:**
- **Flora & Mineral:** UNKNOWN → CATALOGED only (proximity scan). Never ENCOUNTERED.
- **Fauna Hostile:** UNKNOWN → ENCOUNTERED (first attack auto-registers). ENCOUNTERED → CATALOGED (Sneak Scan, deferred post-MVP).
- **Fauna Passive:** UNKNOWN → ENCOUNTERED (fauna flees on approach). ENCOUNTERED → CATALOGED (Trap mechanic, deferred post-MVP).
- **Anomaly:** UNKNOWN → CATALOGED only (proximity scan). Never ENCOUNTERED.

#### Catalog (RefCounted)

Runtime catalog state — tracks knowledge state per entry. Owned by ScannerSystem node.

| Property | Type | Description |
|----------|------|-------------|
| `_knowledge` | `Dictionary[StringName, KnowledgeState]` | entry_id → KnowledgeState. Missing = UNKNOWN. |
| `_encounter_labels` | `Dictionary[StringName, String]` | entry_id → "Hostile" or "Shy" (for ENCOUNTERED fauna only) |
| `_all_entries` | `Dictionary[StringName, CatalogEntry]` | All possible entries, loaded from data files. |
| `_total_count` | `int` | Total scannable entries in current chapter (for counter). |

**Public API:**

```gdscript
# Query
func get_knowledge_state(entry_id: StringName) -> KnowledgeState
func is_cataloged(entry_id: StringName) -> bool  # shortcut: state == CATALOGED
func is_encountered(entry_id: StringName) -> bool  # shortcut: state == ENCOUNTERED
func is_known(entry_id: StringName) -> bool  # shortcut: state >= ENCOUNTERED
func get_entry(entry_id: StringName) -> CatalogEntry
func get_discovered_entries() -> Array[CatalogEntry]  # ENCOUNTERED + CATALOGED
func get_discovered_by_category(category: CatalogCategory) -> Array[CatalogEntry]
func get_discovery_count() -> int          # ENCOUNTERED + CATALOGED count
func get_total_count() -> int              # total possible
func get_discovery_text() -> String        # "X entries"
func get_encounter_label(entry_id: StringName) -> String  # "Hostile" or "Shy"

# Mutation
func catalog_entry(entry_id: StringName) -> void  # marks as CATALOGED, emits signal
func encounter_entry(entry_id: StringName, label: String) -> void  # marks as ENCOUNTERED with "Hostile"/"Shy" label

# Eligibility (used by scan flow)
func get_scannable_at(coords: Vector2i) -> StringName
    # Returns entry_id of first uncataloged scannable element at coords, or &"" if none.
    # Checks: tile.props[] filtered by category (resource/anomaly), FaunaManager positions.
    # Maps prop type → entry_id via _all_entries lookup.
    # Skips ENCOUNTERED fauna (can't be proximity-scanned — needs Trap/Sneak).
    # Only returns elements that can be cataloged by proximity scan.
```

#### ScannerSystem Properties (on ScannerSystem Node)

| Property | Type | Description |
|----------|------|-------------|
| `_catalog` | `Catalog` | RefCounted catalog instance |
| `_is_scanning` | `bool` | Whether a proximity scan is in progress |
| `_scan_target_coords` | `Vector2i` | Tile being scanned |
| `_scan_target_entry_id` | `StringName` | Entry being scanned |
| `_scan_progress` | `float` | 0.0 → 1.0, increments while in range |
| `_scan_duration` | `float` | Seconds to complete scan (2.0-3.0, configurable per category) |
| `_scan_range` | `int` | Proximity detection range in hexes (default: 1 — adjacent only). Tunable constant. |

#### Scan Duration Config

```gdscript
const SCAN_DURATIONS: Dictionary = {
    CatalogCategory.FLORA:   2.0,  # seconds
    CatalogCategory.MINERAL: 2.0,
    CatalogCategory.FAUNA:   3.0,  # longer — but deferred (needs Trap/Sneak)
    CatalogCategory.ANOMALY: 3.0,  # narrative weight — moment of discovery
}
```

#### Proximity Scan Constants

```gdscript
const SCAN_RANGE: int = 1  # hexes — adjacent only. Tunable.
```

#### Signals

```gdscript
# Scan lifecycle
signal scan_started(entry_id: StringName, coords: Vector2i)
signal scan_progress_updated(progress: float)       # 0.0-1.0, emitted each frame
signal scan_completed(entry_id: StringName)          # entry added to catalog
signal scan_interrupted()                            # player left range, progress reset

# Knowledge state changes
signal entry_cataloged(entry_id: StringName, category: CatalogCategory)
signal entry_encountered(entry_id: StringName, label: String)  # "Hostile" or "Shy"
signal knowledge_state_changed(entry_id: StringName, old_state: int, new_state: int)
signal surprise_cataloged(entry_id: StringName)      # auto-register from surprise attack (feature-010) — now registers ENCOUNTERED, not CATALOGED

# Passive identification
signal element_identified(coords: Vector2i, entry_id: StringName)  # cataloged element enters visibility range
signal element_unknown(coords: Vector2i, entry_id: StringName, category: int)  # uncataloged element enters visibility range (show ❓)
signal element_encountered(coords: Vector2i, entry_id: StringName, label: String)  # ENCOUNTERED element enters visibility range (show ⚠️)
```

#### Save Data

```json
{
  "catalog": {
    "knowledge": {
      "berry_bush": "CATALOGED",
      "thornback": "ENCOUNTERED",
      "fiber_grass": "CATALOGED"
    },
    "encounter_labels": {
      "thornback": "Hostile"
    }
  }
}
```

Knowledge state and encounter labels saved per entry. Static entry definitions loaded
from data files. Chapter ID determines which entries are in the world — future chapters
add entries without modifying save format.

#### Cross-Feature Data Contracts

| This feature queries | Source | What it reads |
|---------------------|--------|---------------|
| `tile.props.filter(category)` | feature-001 | Props on tile filtered by category (resource/anomaly) |
| FaunaManager query (fauna at coords) | feature-010 | Fauna species at position |

| This feature is queried by | Consumer | What it provides |
|---------------------------|----------|-----------------|
| feature-004 (auto-interaction) | `get_knowledge_state(type)` — gates auto-gather (CATALOGED) and auto-defend (ENCOUNTERED or CATALOGED) |
| feature-012 (HUD) | Catalog UI data (`get_discovered_entries`, counters) |
| feature-011 (journal) | `entry_cataloged` + anomaly properties for cutscene triggers |

---

### Feature Flow

#### Proximity Auto-Scan Flow

```
ScannerSystem._process(delta) runs every frame
  │
  ├─ If _is_scanning:
  │     # Check if player is still in range of current target
  │     distance = HexGrid.distance(player.current_tile, _scan_target_coords)
  │     if distance > _scan_range:
  │       # Player left range — interrupt immediately, reset progress
  │       _is_scanning = false
  │       _scan_progress = 0.0
  │       Emit scan_interrupted()
  │       → UI: hide scan progress bar
  │       # Fall through to check for new nearby targets
  │     else:
  │       # Still in range — advance progress
  │       _scan_progress += delta / _scan_duration
  │       Emit scan_progress_updated(_scan_progress)
  │       → UI: update progress bar fill
  │
  │       if _scan_progress >= 1.0:
  │         → Scan complete (see below)
  │       return  # Don't start a new scan while one is active
  │
  ├─ If NOT _is_scanning:
  │     # Check nearby tiles for scannable props
  │     nearby_tiles = [player.current_tile] + HexGrid.get_neighbors(player.current_tile)
  │     # Filter to tiles within _scan_range
  │     in_range_tiles = nearby_tiles.filter(|t| HexGrid.distance(player.current_tile, t) <= _scan_range)
  │
  │     # Find nearest scannable prop
  │     best_entry_id = &""
  │     best_coords = Vector2i.ZERO
  │     best_distance = INF
  │     for coords in in_range_tiles:
  │       entry_id = Catalog.get_scannable_at(coords)
  │       if entry_id != &"":
  │         dist = HexGrid.distance(player.current_tile, coords)
  │         if dist < best_distance:
  │           best_distance = dist
  │           best_entry_id = entry_id
  │           best_coords = coords
  │
  │     if best_entry_id != &"":
  │       # Start proximity scan on nearest target
  │       _is_scanning = true
  │       _scan_target_coords = best_coords
  │       _scan_target_entry_id = best_entry_id
  │       _scan_progress = 0.0
  │       var entry = Catalog.get_entry(best_entry_id)
  │       _scan_duration = SCAN_DURATIONS[entry.category]
  │       Emit scan_started(best_entry_id, best_coords)
  │       → UI: show scan progress bar over target
  │
  └─ End
```

**Key design principles:**

- **One scan at a time, nearest first.** Consistent with chain gathering pattern.
- **No grace period.** Binary in/out of range. Progress resets immediately on exit.
- **Proximity range = 1 hex (adjacent).** Tunable constant.
- **Flora/mineral only for MVP.** ENCOUNTERED fauna cannot be proximity-scanned (needs Trap/Sneak). `get_scannable_at` skips them.

#### Scan Complete

```
On scan complete (_scan_progress >= 1.0):
  _is_scanning = false
  _scan_progress = 0.0
  Catalog.catalog_entry(_scan_target_entry_id)
  Emit scan_completed(_scan_target_entry_id)
  Emit entry_cataloged(_scan_target_entry_id, entry.category)
  Emit knowledge_state_changed(_scan_target_entry_id, UNKNOWN, CATALOGED)
  → UI: PropLabelRenderer updates label text from "❓ Unknown [category]" to real name
       (bulk label update for all visible props of this type)
  → UI: brief "Cataloged!" feedback
  → Auto-interaction (feature-004) now unlocked for this type:
    - Cataloged edible flora → auto-gather enabled
    - Cataloged toxic flora → auto-gather ALSO enabled (player collects
      knowingly — the gate is catalog status, not edibility. Danger is in
      consuming, not gathering. Feature-007 handles toxic damage on use.)
    - Cataloged mineral → auto-gather with tool-gating
    - Cataloged hostile fauna → full auto-interaction (but fauna cataloging is deferred post-MVP)
    - Cataloged passive fauna → ignored by auto-interaction
  if entry.category == ANOMALY:
    → feature-011 (journal) handles cutscene trigger via entry_cataloged signal
```

#### Surprise Encounter Flow (fauna first-hit, feature-010 owned)

```
feature-010 emits fauna_attacked_player(fauna_id, damage, species_type: StringName)
  │
  ├─ ScannerSystem receives signal
  │
  ├─ Check: is species_type already known?
  │     state = Catalog.get_knowledge_state(species_type)
  │     if state >= ENCOUNTERED: return (already registered)
  │
  ├─ Auto-register as ENCOUNTERED:
  │     Catalog.encounter_entry(species_type, "Hostile")
  │     Emit entry_encountered(species_type, "Hostile")
  │     Emit knowledge_state_changed(species_type, UNKNOWN, ENCOUNTERED)
  │     Emit surprise_cataloged(species_type)  # legacy name, now means ENCOUNTERED
  │     → UI: PropLabelRenderer updates label on attacker from "❓ Unknown Creature" to "⚠️ Unidentified Fauna (Hostile)"
  │     → Auto-defend (feature-004) activates immediately for this species
  │
  └─ Done — no scan progress bar, instant ENCOUNTERED on first hit
```

#### Passive Fauna Flee Flow

```
Player approaches passive fauna → fauna flees (feature-010 owned)
  │
  ├─ ScannerSystem receives fauna_fled(fauna_id, species_type) signal
  │
  ├─ Check: is species_type already known?
  │     state = Catalog.get_knowledge_state(species_type)
  │     if state >= ENCOUNTERED: return (already registered)
  │
  ├─ Auto-register as ENCOUNTERED:
  │     Catalog.encounter_entry(species_type, "Shy")
  │     Emit entry_encountered(species_type, "Shy")
  │     Emit knowledge_state_changed(species_type, UNKNOWN, ENCOUNTERED)
  │     → UI: PropLabelRenderer updates label to "⚠️ Unidentified Fauna (Shy)"
  │
  └─ Done — player knows something exists but can't scan until Trap mechanic
```

**Note:** Passive fauna flee behavior and `fauna_fled` signal are deferred post-MVP
(no passive fauna in Chapter 1). Architecture supports it when fauna AI arrives.

#### Passive Identification Flow (on tile reveal/enter)

```
HexGrid emits tile_revealed(coords) or tile_visibility_changed(coords, VISIBLE)
  │
  ├─ ScannerSystem receives signal
  │
  ├─ Check tile for elements:
  │     For each prop in tile.props:
  │       entry_id = _map_prop_to_entry(prop.type)
  │       state = Catalog.get_knowledge_state(entry_id)
  │       match state:
  │         CATALOGED:
  │           Emit element_identified(coords, entry_id)
  │           → PropRenderer: show prop mesh at prop.sub_hex position
  │           → PropLabelRenderer: show real name label
  │         ENCOUNTERED:
  │           var label = Catalog.get_encounter_label(entry_id)
  │           Emit element_encountered(coords, entry_id, label)
  │           → PropRenderer: show prop mesh at prop.sub_hex position
  │           → PropLabelRenderer: show "⚠️ Unidentified Fauna ([label])" label
  │         UNKNOWN:
  │           var cat = _all_entries[entry_id].category
  │           Emit element_unknown(coords, entry_id, cat)
  │           → PropRenderer: show prop mesh at prop.sub_hex position (uses category for mesh pool)
  │           → PropLabelRenderer: show "❓ Unknown [category]" label
  │
  │     (Anomalies are props with category == "anomaly" — handled by the same loop above.
  │      Fauna handled separately — FaunaManager emits fauna_spawned with position,
  │      ScannerSystem checks knowledge state for that species and emits appropriate signal)
  │
  └─ Done
```

This runs once per tile when it becomes VISIBLE. PropRenderer places the 3D prop mesh
(always the same regardless of knowledge state). PropLabelRenderer subscribes and sets
the appropriate label text (❓, ⚠️, or real name).

#### Prop-to-Entry Mapping

`_map_prop_to_entry(prop_type: StringName) -> StringName` maps prop types to catalog
entry IDs. This is a static lookup table:

```gdscript
const PROP_TO_ENTRY: Dictionary = {
    &"wood":           &"wood_tree",
    &"berries":        &"berry_bush",
    &"toxic_berries":  &"toxic_berry_bush",
    &"fiber":          &"fiber_grass",
    &"stone":          &"stone_deposit",
    &"ore":            &"iron_deposit",
    &"crystal":        &"crystal_cluster",
}
```

One prop type maps to exactly one catalog entry. Future chapters can add entries.

---

### Layers & Components

#### Scene Tree Additions

```
Main (Node)
  └─ World (Node3D)
       ├─ HexGridRenderer (Node3D)              [feature-001]
       ├─ PropRenderer (Node3D)                  ← NEW (3D prop meshes on tiles)
       ├─ PropLabelRenderer (Node3D)              ← NEW (floating pill labels: ❓/⚠️/name)
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
            └─ DiscoveryCounter (Label)         ← "X entries"
```

#### File Structure

```
scripts/
  scanner/
    scanner_system.gd        # Node (child of Player) — proximity auto-scan in _process,
                              #   passive identification, surprise encounter handler
    catalog.gd               # RefCounted — catalog data, 3-state knowledge, queries
    catalog_entry.gd         # Resource — static entry definition

  rendering/
    prop_renderer.gd         # Node3D — 3D prop meshes on world tiles (MultiMesh per type)
    prop_label_renderer.gd   # Node3D — floating pill-shaped labels above props (billboard)
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
| `scanner_system.gd` | Child Node of Player. Owns `Catalog` instance. Runs proximity check in `_process` — finds nearest uncataloged prop within `SCAN_RANGE`, starts/continues/interrupts scan based on player distance. Handles passive identification on `tile_revealed`/`tile_visibility_changed`. Handles surprise encounter on `fauna_attacked_player`. Handles passive fauna encounter on `fauna_fled`. Emits all scanner/catalog signals. | `HexGrid` (tile queries), `FaunaManager` feature-010 (fauna position queries + surprise signal), `Player` (current_tile for proximity) |
| `catalog.gd` | RefCounted owned by ScannerSystem. 3-state knowledge tracking (`_knowledge`). Encounter labels for fauna. All query APIs (`get_knowledge_state`, `is_cataloged`, `get_entry`, `get_scannable_at`, counters). `catalog_entry()` and `encounter_entry()` mutations. `get_save_data()`/`load_save_data()`. | `catalog_entry.gd` (static definitions), `HexGrid` (for `get_scannable_at` — queries `tile.props`), `FaunaManager` (for fauna position in `get_scannable_at`) |
| `catalog_entry.gd` | Resource — static definition. Loaded from `.tres` data files. No runtime mutation. | Nothing (data only) |
| `prop_renderer.gd` | Node3D under World. MultiMesh per prop type (~5 pools: flora cube, fauna sphere, mineral octahedron, anomaly tetrahedron, generic). Places 3D placeholder meshes at prop sub-hex positions within hexes. Updates on `element_identified(coords, entry_id)`/`element_unknown(coords, entry_id, category)`/`element_encountered(coords, entry_id, label)`. Uses `category` to select the correct MultiMesh pool. Props are always visible once tile is revealed — knowledge state does NOT change meshes. **Sub-hex positioning:** Each prop has a `sub_hex: Vector2i` (axial coords within the 19 sub-hex grid). PropRenderer converts `(tile coords, sub_hex)` to world position for mesh placement. No manual radial offset needed — sub-hex grid provides natural spatial distribution. | `ScannerSystem` (signals), `HexGrid` (`axial_to_world` for positioning, sub-hex → world offset) |
| `prop_label_renderer.gd` | Node3D under World. Floating pill-shaped labels above props (~1 MultiMesh pool). Billboard-enabled (faces camera). Shows "❓ Unknown [category]" for UNKNOWN, "⚠️ Unidentified Fauna (Hostile/Shy)" for ENCOUNTERED, real name for CATALOGED. Only renders labels for nearby/targeted props. On `entry_cataloged`: bulk label text update for all visible props of that type. On `entry_encountered`: update matching labels from ❓ → ⚠️ label. Labels positioned at prop sub-hex world positions (same sub-hex coords as PropRenderer). | `ScannerSystem` (signals), `Catalog` (name lookups, encounter labels) |
| `scan_progress_renderer.gd` | Node3D under World. Shows a progress bar billboard above the scan target tile during active scan. Updates on `scan_started`/`scan_progress_updated`/`scan_completed`/`scan_interrupted`. Single instance (only one scan at a time). | `ScannerSystem` (signals), `HexGrid` (`axial_to_world` for positioning) |
| `catalog_panel.gd` | Control on CatalogPanel. Bottom drawer (same pattern as Inventory/Crafting/Build panels). 4 category tabs, entry list per category, discovery counter. Mutual exclusion with other panels. ENCOUNTERED entries show "Unidentified Fauna (Hostile/Shy)" with no details. CATALOGED entries show full info. | `Catalog` (query APIs for entries, counters, knowledge states, encounter labels) |

#### Signal Wiring — Complete

```
feature-010 (FaunaManager)                   scanner_system.gd
  fauna_attacked_player(id, dmg, species)──►  surprise encounter if unknown (→ ENCOUNTERED)
  fauna_fled(id, species)                ──►  passive encounter if unknown (→ ENCOUNTERED)

HexGrid signals                              scanner_system.gd
  tile_revealed(coords)                  ──►  passive identification check
  tile_visibility_changed(coords, VISIBLE)──► passive identification check

scanner_system.gd                            prop_renderer.gd
  element_identified(coords, entry_id)   ──►  add prop mesh instance to appropriate MultiMesh pool
  element_unknown(coords, entry_id, cat) ──►  add prop mesh instance to appropriate MultiMesh pool
  element_encountered(coords, id, label) ──►  add prop mesh instance to appropriate MultiMesh pool
                                              (uses category to pick correct mesh pool;
                                              same mesh regardless of knowledge state)

scanner_system.gd                            prop_label_renderer.gd
  element_identified(coords, entry_id)   ──►  show real name label above prop
  element_unknown(coords, entry_id, cat) ──►  show "❓ Unknown [category]" label above prop
                                              (uses category int to resolve label text:
                                              0=Vegetation, 1=Creature, 2=Mineral, 3=Anomaly)
  element_encountered(coords, id, label) ──►  show "⚠️ Unidentified Fauna ([label])" label
  entry_cataloged(entry_id, category)    ──►  BULK LABEL UPDATE: iterate all visible props,
                                              update matching labels from ❓ → real name.
                                              This is the "biome conquered" satisfaction moment.
  entry_encountered(entry_id, label)     ──►  LABEL UPDATE: iterate visible props of this species,
                                              update from ❓ → "⚠️ Unidentified Fauna ([label])"

scanner_system.gd                            scan_progress_renderer.gd
  scan_started(entry_id, coords)         ──►  show progress bar at tile
  scan_progress_updated(progress)        ──►  update bar fill
  scan_completed(entry_id)               ──►  hide bar, flash "Cataloged!"
  scan_interrupted()                     ──►  hide bar

scanner_system.gd                            feature-011 (journal)
  entry_cataloged(entry_id, category)    ──►  if ANOMALY: trigger cutscene

scanner_system.gd                            feature-004 (auto-interaction)
  entry_cataloged(entry_id, category)    ──►  unlock auto-gather for type
  entry_encountered(entry_id, label)     ──►  unlock auto-defend for hostile fauna

scanner_system.gd                            catalog_panel.gd
  entry_cataloged(entry_id, category)    ──►  refresh entry list + counter
  entry_encountered(entry_id, label)     ──►  add ENCOUNTERED entry to list + counter
```

#### Prop Rendering (3D Meshes)

**MultiMesh per prop type** — same proven pattern as hex tiles and resources.

One `MultiMeshInstance3D` per prop category:
- Flora (green cube)
- Fauna (red/green sphere)
- Mineral (blue octahedron)
- Anomaly (purple tetrahedron)
- Generic (fallback)

**~5 MultiMeshInstance3D = ~5 draw calls.** Player visibility radius 2 = ~19 tiles,
1-3 elements each = ~20-50 instances distributed across the pools. Well within budget.

**Prop positioning:** Each prop has a `sub_hex: Vector2i` (axial coords within the
19 sub-hex grid, 1.2m sub-hexes). World position = `HexGrid.axial_to_world(tile_coords)`
+ sub-hex offset + Y for elevation. No manual distribution needed.

**Sub-hex grid:** Each main hex contains 19 sub-hexes with axial coords `(sq, sr)`.
Props are placed at their assigned sub-hex position, providing natural spatial
distribution within the tile. Multiple props on the same tile occupy different sub-hexes.

**Prop lifecycle:**
- Tile becomes VISIBLE → ScannerSystem checks catalog → emit `element_identified`,
  `element_unknown`, or `element_encountered` → PropRenderer adds prop mesh instance
  to appropriate MultiMesh pool. **The same mesh is used regardless of knowledge state**
  — the prop always looks the same.
- Tile becomes REVEALED → remove instances (dimmed tile, no props)
- Tile becomes HIDDEN → remove instances
- Entry cataloged → PropRenderer does NOT change meshes. Props stay as-is.

#### Prop Label Rendering (Colored Markers)

**Colored ❓/⚠️ markers** above props. Billboard-enabled (faces camera).
Small, clean, non-overlapping per-prop markers using Label3D with single emoji characters.

**Marker content (3-state):**
- UNKNOWN: Colored ❓ (color by category)
  - Mineral: blue `Color(0.3, 0.5, 1.0)`
  - Flora: green `Color(0.3, 0.8, 0.3)`
  - Fauna: red `Color(1.0, 0.3, 0.3)`
  - Anomaly: purple `Color(0.7, 0.3, 0.9)`
- ENCOUNTERED (fauna only): ⚠️ in orange/amber `Color(1.0, 0.6, 0.1)`
- CATALOGED: **No marker** — the prop speaks for itself

**Marker lifecycle:**
- Tile becomes VISIBLE → PropLabelRenderer adds colored ❓ for UNKNOWN, ⚠️ for ENCOUNTERED, nothing for CATALOGED
- Entry encountered → `entry_encountered` signal → PropLabelRenderer updates matching ❓ markers to ⚠️ with orange color
- Entry cataloged → `entry_cataloged` signal → PropLabelRenderer hides/clears all matching markers (CATALOGED = no marker)

**Bulk marker update mechanism:** `PropLabelRenderer` maintains a mapping
`Dictionary[Vector2i, Array]` — tile coords → list of marker info dicts.
On `entry_cataloged(entry_id)`, iterate the mapping, find all markers for that
entry_id, hide them and clear text. O(n) where n = visible tiles with that element type.

#### Catalog Panel UI

Bottom drawer — same pattern as Inventory (feature-005), Crafting (feature-006),
Build (feature-009). Full width, ~45% height, semi-transparent.

```
┌──────────────────────────┐
│      (game world)        │  ← ~55% visible
├──────────────────────────┤
│  CATALOG  X entries  [X] │  ← header + counter + close
│ [Flora][Fauna][Min][Anom]│  ← category tabs
│ ─────────────────────────│
│ ┌──────────────────────┐ │
│ │ [icon] Berry Bush    │ │  ← CATALOGED entry (full info)
│ │   Edible. Restores   │ │
│ │   hunger.            │ │
│ └──────────────────────┘ │
│ ┌──────────────────────┐ │
│ │ [⚠️] Unidentified    │ │  ← ENCOUNTERED entry (no details)
│ │   Fauna (Hostile)    │ │
│ └──────────────────────┘ │
│ ┌──────────────────────┐ │
│ │ [icon] Iron Deposit  │ │  ← CATALOGED entry (full info)
│ │   Requires Pickaxe.  │ │
│ └──────────────────────┘ │  ← ~45% height
└──────────────────────────┘
```

- **Mutual exclusion** with all other panels (panel_opened signal pattern)
- **Opens via ScannerButton** in HUD (bottom-right, 64×64px)
- **Category tabs:** Flora, Fauna, Minerals, Anomalies. Each tab has its own
  ScrollContainer with VBoxContainer of entries.
- **Entry display (CATALOGED):** Icon + name + description + properties summary. Read-only.
- **Entry display (ENCOUNTERED):** ⚠️ icon + "Unidentified Fauna (Hostile/Shy)" — no name, no details.
- **Discovery counter:** "X entries" in header (ENCOUNTERED + CATALOGED both count). Updates on `entry_cataloged` and `entry_encountered`.
- **Game continues running** — no pause.
- **Touch targets:** Entry rows ~80px height, tabs ~48px, close 48×48, ScannerButton 64×64.

---

### Mobile Specs

#### Performance — Scanner Processing

| Operation | Cost | When |
|-----------|------|------|
| Proximity check (`_process`) | O(7): player tile + 6 neighbors. Each: `get_scannable_at` (tile lookup + props iteration 1-3 + catalog hash lookup) | Every frame (lightweight — just distance + hash checks) |
| Scan progress tick | One float add per frame | During active scan only (2-3 seconds) |
| Passive identification (tile reveal) | O(n): n = props on tile (1-3) | Once per tile when VISIBLE |
| Surprise encounter | O(1): catalog hash lookup + insert | Once per new hostile species |

The per-frame proximity check is lightweight: 7 tiles × ~3 hash lookups each = ~21
dictionary lookups. Negligible (<0.1ms). When not near any scannable prop, the check
exits early.

#### Draw Call Budget — Scanner Share

| Renderer | Estimated Draw Calls | Notes |
|----------|---------------------|-------|
| PropRenderer | ~5 | MultiMesh per prop type: flora, fauna, mineral, anomaly, generic |
| PropLabelRenderer | ~1 | Floating pill labels (billboard, single pool) |
| ScanProgressRenderer | 1 | Single billboard, only during active scan |
| CatalogPanel (UI) | 0 | CanvasLayer, not 3D draw calls |
| **Scanner total** | **~7** | Within remaining ~90 budget after terrain (~5) |

#### Touch Interaction

- **No scan-specific touch input.** Proximity scan is automatic — no tap, no hold.
  The player just walks near props.
- **Catalog panel:** Same touch targets as other bottom drawers. Entry rows ~80px,
  tabs ~48px, buttons ≥48dp.
- **No platform differences.** Same behavior on iOS and Android.

#### Memory

- `Catalog._knowledge`: Dictionary with ~50 entries max (Chapter 1). Negligible.
- `Catalog._encounter_labels`: Dictionary with ~5 fauna entries max. Negligible.
- `CatalogEntry` resources: ~50 static definitions. <100KB total.
- Prop meshes: 5 MultiMesh pools × ~50 instances each = ~250 instances max.
  ~64 bytes per instance (transform + custom data). Total: <100KB.
- Prop labels: 1 MultiMesh pool for nearby props. ~20 instances max. <20KB.
- Scan progress bar: 1 instance. Negligible.

---

## Known Limitations

### Proximity Scan — One at a Time, Nearest First
The scanner processes one proximity scan at a time, targeting the nearest uncataloged
prop within range (1 hex). This is consistent with the chain gathering pattern.
When multiple uncataloged props are in range:
- Nearest prop is scanned first
- After completion, the next nearest is automatically targeted
- Players cannot choose which element to scan
- This is acceptable for MVP (most tiles have 1-2 elements)

### Fauna Cataloging Deferred
Full fauna cataloging (ENCOUNTERED → CATALOGED) requires Trap (passive) or Sneak Scan
(hostile) mechanics, both deferred post-MVP. In Chapter 1:
- Hostile fauna can only reach ENCOUNTERED state (via first attack)
- Passive fauna can only reach ENCOUNTERED state (via fleeing)
- Auto-defend works at ENCOUNTERED level — knowing drops is the incentive for CATALOGED
- The player knows *something* is there but can't learn details until future mechanics arrive

### Flora/Mineral Never ENCOUNTERED
Code enforces that static elements (flora, mineral, anomaly) go UNKNOWN → CATALOGED
only. They never enter ENCOUNTERED state. This is by design — ENCOUNTERED is a
fauna-only concept representing partial knowledge from behavioral observation.
