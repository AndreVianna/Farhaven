# Night Threats

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | Feature identified from REQUIREMENTS.md §5 F9, §9 AC9 | /aid-interview |
| 2026-03-31 | Full technical specification — all sections | /aid-specify |
| 2026-04-01 | [PIVOT] Added max_jump attribute to fauna config. Mechanic deferred, attribute defined now. | /design-pivot |
| 2026-04-01 | I4: move_cooldown and detection_range marked [TUNING_REQUIRED] for HEX_SIZE=3.0 visual feel. Range note: detection_range transitioning to circular world-unit area (~2 inscribed hex radii). | /pivot-cascade |
| 2026-04-02 | Scene tree + fauna icon references: ElementIconRenderer → PropRenderer + PropLabelRenderer. Fauna body mesh via PropRenderer, ❓/name label via PropLabelRenderer. | /spec-update |
| 2026-04-02 | Scan redesign: "surprise auto-catalog" → "auto-register as ENCOUNTERED". First hit registers hostile fauna as ENCOUNTERED (not CATALOGED). Auto-defend activates at ENCOUNTERED. Shelter farming produces ENCOUNTERED fauna (drops unknown until CATALOGED). | /scan-redesign-apply |
| 2026-04-04 | Sub-hex + unified props: spawn validation checks `tile.props` for blocking structures. Torch radius uses sub-hex positions. Shelter/wall checks query `tile.props` by category. Meat drops stay on main hex (ground items are main-hex level). | /spec-update |

## Source

- REQUIREMENTS.md §5 F9 (Night Threats)
- REQUIREMENTS.md §9 AC9 (Night Threats acceptance criteria)

## Description

Starting Day 4, fauna spawn at night outside lit/walled areas. Before any encounter, all creatures show ❓ — player doesn't know if hostile. UNKNOWN hostile fauna delivers a surprise attack (first hit taken, species auto-registered as ENCOUNTERED with "Unidentified Fauna (Hostile)" label). ENCOUNTERED and CATALOGED hostile fauna are auto-identified (⚠️ or name). Auto-defend activates at ENCOUNTERED level (not CATALOGED). Fauna move toward player within 2 hexes, deal contact damage, despawn at dawn. Killed fauna drop meat. Emits signals consumed by feature-004 for auto-defend triggers.

## User Stories

- As a player, I want night to feel dangerous but fair
- As a player, I want the first encounter with a new creature to be tense
- As a player, I want killing creatures to be rewarding (meat = best food)

## Priority

Must (P1 -- Tension)

## Acceptance Criteria

- [ ] Day 3 night -> zero fauna spawn
- [ ] Day 4 night -> 1-3 fauna spawn outside lit/walled area
- [ ] UNKNOWN fauna show ❓ icon, no auto-defend
- [ ] UNKNOWN hostile fauna attacks → player takes surprise damage → species auto-registered as ENCOUNTERED
- [ ] After ENCOUNTERED (surprise attack) or CATALOGED (future scan): auto-defend active for all future encounters
- [ ] Dawn -> all fauna despawn

## Save Integration

Fauna are NOT saved (transient per-night). Catalog entries for discovered species saved by feature-003.

---

## Technical Specification

### Data Model

#### Fauna Entity — Transient Dictionary

Fauna are lightweight Dictionaries in an array — not Nodes, not Resources. 1-3 per
night, processed in `_process` by FaunaManager.

```gdscript
# Each fauna instance in _fauna array:
{
  "id": int,                      # unique per spawn cycle (incrementing counter)
  "species_type": StringName,     # [NEW] catalog entry ID — e.g., &"thornback"
  "coords": Vector2i,             # current tile (axial)
  "hp": int,                      # takes damage from auto-defend (feature-004)
  "move_cooldown": float,         # seconds between tile moves
  "cooldown_remaining": float,    # timer (decremented each frame during NIGHT)
}
```

**[NEW] `species_type`:** Maps to a CatalogEntry in feature-003. Determines:
- Whether the fauna is hostile or passive (`Catalog.get_entry(species_type).properties.hostile` — only available for CATALOGED)
- The player's knowledge state (`Catalog.get_knowledge_state(species_type)` — UNKNOWN/ENCOUNTERED/CATALOGED)
- What shows in the world: ❓ if UNKNOWN, "⚠️ Unidentified Fauna (Hostile/Shy)" if ENCOUNTERED, real name if CATALOGED

#### Fauna Config

```gdscript
const FAUNA_CONFIG: Dictionary = {
    "hp": 20,
    "contact_damage": 10,         # HP to player per move cycle when adjacent
    "move_cooldown": 1.0,         # seconds between tile moves [TUNING_REQUIRED] — at HEX_SIZE=3.0
                                  # creature mesh visually crosses 3x more world space per move
    "detection_range": 2,         # hexes — move toward player if within range [TUNING_REQUIRED] —
                                  # range system transitioning to circular world-unit area
                                  # (~2 inscribed hex radii ≈ 5.2 units at HEX_SIZE=3.0)
    "max_jump": 1,                # [NEW] max elevation diff fauna can traverse (1=walk only, 2-3=can jump gaps, -1=flying)
    "spawn_count_min": 1,
    "spawn_count_max": 3,
    "first_spawn_day": 4,         # Days 1-3 peaceful (onboarding)
    "meat_drop_amount": 1,        # meat dropped on kill
    "spawn_min_distance": 3,      # hexes — minimum distance from player at spawn
}
```

All values tunable — exported or config resource.

#### Chapter 1 Fauna Species

```gdscript
const CHAPTER1_SPECIES: Array[StringName] = [&"thornback"]
```

Chapter 1 has one hostile species. Architecture supports multiple species per chapter
(future chapters add entries). The species type maps to a CatalogEntry defined in
feature-003's data files (`data/catalog/fauna.tres`).

**Passive fauna:** Not in Chapter 1 scope. Architecture supports passive species
(hostile = false in catalog entry). FaunaManager spawns them but they don't deal
damage and auto-defend ignores them.

**[PIVOT] `max_jump` attribute:** Determines how fauna handles elevation differences.
- `max_jump: 1` — can only WALK (diff 0-1). Treats diff 2+ as impassable. (Default: thornback)
- `max_jump: 3` — can traverse gaps up to diff 3 (same as player JUMP).
- `max_jump: -1` — flying fauna, ignores ALL elevation gaps.
- Mechanic implementation deferred. **Note:** `HexGrid.is_passable()` returns true
  for JUMP/DROP (diff 2-3), so fauna using `is_passable()` alone would incorrectly
  cross gaps. Delivery-005 MUST implement `FaunaManager._is_fauna_passable(from, to, max_jump)`
  that treats `elevation_diff > max_jump` as BLOCKED for that species.
  Thornback (`max_jump: 1`) should only WALK (diff 0-1).

#### FaunaManager Properties (on Node)

| Property | Type | Description |
|----------|------|-------------|
| `_fauna` | `Array[Dictionary]` | Active fauna instances |
| `_next_id` | `int` | Incrementing counter for unique IDs |

No `is_attacking` flag — combat is owned by feature-004 (AutoInteractionSystem
auto-defend). FaunaManager owns creature lifecycle, not player combat.

#### Signals

```gdscript
signal fauna_spawned(id: int, coords: Vector2i, species_type: StringName)
signal fauna_moved(id: int, from_coords: Vector2i, to_coords: Vector2i)
signal fauna_attacked_player(id: int, damage: int, species_type: StringName)
signal fauna_killed(id: int, coords: Vector2i, species_type: StringName)
signal fauna_despawned(id: int)
```

**[CHANGED from pre-redesign]:** `fauna_spawned`, `fauna_attacked_player`, and
`fauna_killed` all include `species_type: StringName`. This is needed by:
- feature-003 (scanner): auto-catalog on surprise attack (`fauna_attacked_player`)
- feature-004 (auto-interaction): auto-defend damage routing (`fauna_moved`)
- feature-007 (survival): meat ground item creation (`fauna_killed`)
- feature-003 (scanner): element icon rendering (`fauna_spawned` for ❓/identified icon)

#### Spawn Rules

Fauna spawn at NIGHT start (`DayNightCycle.night` signal). Only if
`DayNightCycle.day_count >= FAUNA_CONFIG.first_spawn_day` (Day 4+).

Spawn tile requirements:
- `fog_state != VISIBLE` (outside player sight + torch range)
- No blocking structures on tile (no props with `category == "structure"` that block spawn)
- Passable (not water, not cliff)
- Distance from player >= `spawn_min_distance` (3 hexes)
- Not within torch radius (torch deters spawn within radius 2; torch position includes sub-hex offset)

Spawn count: `randi_range(spawn_count_min, spawn_count_max)`.
Species: randomly selected from `CHAPTER1_SPECIES` (Chapter 1: always `&"thornback"`).

#### Save Data

Fauna are **NOT saved** — transient per-night entities. On load during NIGHT phase,
re-run spawn logic. Catalog entries for discovered fauna species are saved by
feature-003.

#### Cross-Feature Dependencies

| What | Source |
|------|--------|
| `night` signal — spawn trigger | feature-008 (DayNightCycle) |
| `dawn` signal — despawn trigger | feature-008 (DayNightCycle) |
| `DayNightCycle.day_count` — first_spawn_day check | feature-008 |
| `HexGrid.is_passable` — spawn + movement validation | feature-001 |
| `HexGrid.get_tile().fog_state` — spawn validation | feature-001 |
| `tile.props` filtered by category — shelter/structure checks | feature-001 |

| What | Consumer |
|------|----------|
| `fauna_spawned` — icon rendering (❓ or identified) | feature-003 (scanner element icons) |
| `fauna_moved` — auto-defend trigger check | feature-004 (AutoInteractionSystem) |
| `fauna_attacked_player` — HP damage + surprise auto-catalog | feature-003 (scanner), feature-007 (survival `take_damage`) |
| `fauna_killed` — meat ground item creation | feature-007 (survival) |
| `fauna_despawned` — cleanup renderer | renderer (this feature) |
| Fauna position query — auto-defend adjacency check | feature-004 (AutoInteractionSystem) |

#### Public API — Fauna Queries

```gdscript
# Query fauna positions for auto-defend (feature-004) and scanner (feature-003)
func get_fauna_at(coords: Vector2i) -> Array[Dictionary]  # fauna on this tile
func get_fauna_adjacent_to(coords: Vector2i) -> Array[Dictionary]  # fauna within 1 hex
func get_all_fauna() -> Array[Dictionary]  # all active fauna
func apply_damage(fauna_id: int, damage: int) -> void  # called by auto-defend
```

`apply_damage` reduces fauna HP, emits `fauna_killed` on death. FaunaManager owns
fauna HP — auto-defend (feature-004) calls this, doesn't modify fauna directly.

---

### Feature Flow

#### Spawn Flow (night signal)

```
DayNightCycle emits night()
  │
  ├─ if DayNightCycle.day_count < FAUNA_CONFIG.first_spawn_day: return
  │     (Days 1-3 peaceful — onboarding)
  │
  ├─ count = randi_range(spawn_count_min, spawn_count_max)  → 1-3
  │
  ├─ For each spawn:
  │     species = CHAPTER1_SPECIES.pick_random()  → &"thornback"
  │
  │     Find valid spawn tile:
  │       candidates = all tiles where:
  │         fog_state != VISIBLE
  │         no props with category == "structure" that block spawn
  │         HexGrid.is_passable to at least one neighbor
  │         HexGrid.distance(player.current_tile, tile) >= spawn_min_distance
  │         Not within 2 hexes of any torch (_torch_positions from DayNightCycle)
  │       Pick randomly from candidates
  │       ✗ No valid candidates → skip this spawn (rare with 200-300 tiles)
  │
  │     Create fauna entry:
  │       _fauna.append({
  │         "id": _next_id,
  │         "species_type": species,
  │         "coords": spawn_tile,
  │         "hp": FAUNA_CONFIG.hp,
  │         "move_cooldown": FAUNA_CONFIG.move_cooldown,
  │         "cooldown_remaining": FAUNA_CONFIG.move_cooldown,
  │       })
  │       _next_id += 1
  │
  │     Emit fauna_spawned(id, spawn_tile, species)
  │       → feature-003 (scanner): check species knowledge state
  │         → UNKNOWN: PropRenderer shows fauna mesh at spawn_tile,
  │           PropLabelRenderer shows "❓ Unknown Creature" label
  │         → ENCOUNTERED: PropLabelRenderer shows "⚠️ Unidentified Fauna (Hostile/Shy)"
  │         → CATALOGED: PropLabelRenderer shows real name
  │
  └─ Done
```

#### Movement Tick (_process, NIGHT only)

```
Every frame (FaunaManager._process):
  │
  ├─ if DayNightCycle.current_phase != TimePhase.NIGHT: return
  │
  ├─ For each fauna in _fauna:
  │     cooldown_remaining -= delta
  │     if cooldown_remaining > 0: continue
  │     Reset cooldown_remaining = move_cooldown
  │
  │     ├─ Player within detection_range (2 hexes)?
  │     │     distance = HexGrid.distance(fauna.coords, player.current_tile)
  │     │     ✗ distance > detection_range → idle (don't move)
  │     │
  │     ├─ Pick move target:
  │     │     From HexGrid.get_neighbors(fauna.coords):
  │     │       Pick neighbor closest to player (min hex distance)
  │     │       Must be passable (props with category="structure" and blocks_movement=true block — fauna routes around)
  │     │       Must not have another fauna (no stacking on same tile)
  │     │     ✗ No valid move → stay put
  │     │
  │     ├─ Move fauna:
  │     │     old_coords = fauna.coords
  │     │     fauna.coords = new_tile
  │     │     Emit fauna_moved(id, old_coords, new_tile)
  │     │       → feature-004 (AutoInteractionSystem): checks adjacency for auto-defend
  │     │
  │     └─ Contact damage check — fauna now adjacent to player?
  │           if HexGrid.distance(fauna.coords, player.current_tile) == 1:
  │
  │             Shelter check:
  │               var tile = HexGrid.get_tile(player.current_tile)
  │               if tile.props.any(|p| p.category == &"structure" and p.type == &"shelter"):
  │                 → 0 damage (shelter protection)
  │                 → Still emit fauna_attacked_player with damage = 0
  │
  │             Else:
  │               damage = FAUNA_CONFIG.contact_damage  → 10 HP
  │               Emit fauna_attacked_player(id, damage, fauna.species_type)
  │                 → feature-007 (survival): take_damage(damage)
  │                 → feature-003 (scanner): if species NOT cataloged →
  │                     surprise auto-catalog (instant, no scan bar)
  │                 → feature-012 (HUD): ScreenFade.flash(red) for damage feedback
  │
  └─ End
```

**Contact damage is fauna-move-only (intentional design).** Damage checked when
fauna moves adjacent to player, NOT when player moves adjacent to fauna. If player
approaches between fauna move ticks, player gets a free first strike via auto-defend
(feature-004) before fauna's next contact tick. Rewards aggressive play.

**[NEW] Surprise auto-register as ENCOUNTERED:** When `fauna_attacked_player` fires with an
UNKNOWN `species_type`, feature-003 (ScannerSystem) auto-registers the species as
ENCOUNTERED with label "Hostile". No scan progress bar — instant transition on first hit.
From that moment, auto-defend (feature-004) activates for all subsequent attacks in
this encounter AND all future encounters with this species. The player does NOT learn
the species name or drops — only that it's hostile. Full details require CATALOGED state
(Sneak Scan mechanic, deferred post-MVP).

**Shelter protection:** player's tile has a prop with `category == "structure"` and `type == "shelter"` → contact damage = 0.
Signal still fires (with damage = 0) so surprise auto-catalog still triggers — the
player learns what attacked them even if they're safe.

**Known emergent behavior — shelter farming:** Player in shelter takes 0 damage →
fauna auto-registers as ENCOUNTERED on contact → auto-defend activates → kills fauna
from safety → free meat (1-3 per night). Note: shelter farming produces ENCOUNTERED
fauna (auto-defend works, but drops remain unknown until full CATALOGED state via
Sneak Scan, deferred post-MVP). This is intentional for MVP: mild reward for building
shelter, "base building pays off" feel. Rate is balanced (~5 min cycle for 1-3 meat).
Flag for balancing review in future chapters if meat economy needs tuning.

#### Auto-Defend Integration (feature-004 owned)

FaunaManager does NOT implement player combat. It emits signals:
- `fauna_moved` → feature-004 checks adjacency, triggers auto-attack if cataloged hostile
- Feature-004 calls `FaunaManager.apply_damage(fauna_id, damage)` on auto-attack

```
FaunaManager.apply_damage(fauna_id: int, damage: int):
  │
  ├─ Find fauna by id in _fauna
  ├─ fauna.hp -= damage
  │
  ├─ if fauna.hp <= 0:
  │     coords = fauna.coords
  │     species = fauna.species_type
  │     Remove from _fauna
  │     Emit fauna_killed(id, coords, species)
  │       → feature-007 (survival): add_ground_item(coords, &"meat", meat_drop_amount)
  │       → renderer: remove fauna visual
  │
  └─ Done
```

#### Despawn Flow (dawn signal)

```
DayNightCycle emits dawn()
  │
  ├─ For each fauna in _fauna:
  │     Emit fauna_despawned(fauna.id)
  │       → renderer: remove fauna visual
  │
  ├─ _fauna.clear()
  └─ Done
```

All fauna removed instantly at dawn. No fade, no death animation — they disappear.

---

### Layers & Components

#### Scene Tree

```
Main (Node)
  └─ World (Node3D)
       ├─ WorldEnvironment                      [feature-008]
       ├─ DirectionalLight3D                    [feature-008]
       ├─ HexGridRenderer (Node3D)              [feature-001]
       ├─ PropRenderer (Node3D)                  [feature-003]
       ├─ PropLabelRenderer (Node3D)              [feature-003]
       ├─ ScanProgressRenderer (Node3D)         [feature-003]
       ├─ PropRenderer (Node3D)             [feature-004]
       ├─ StructureRenderer (Node3D)            [feature-009]
       ├─ FaunaRenderer (Node3D)                ← THIS FEATURE
       ├─ GroundItemRenderer (Node3D)           [feature-007]
       ├─ Player (Node3D)                       [feature-002]
       │    ├─ PlayerVisual (Node3D)
       │    ├─ PlayerInput (Node)               [feature-002]
       │    ├─ ScannerSystem (Node)             [feature-003]
       │    ├─ AutoInteractionSystem (Node)     [feature-004]
       │    ├─ CraftingSystem (Node)            [feature-006]
       │    ├─ SurvivalSystem (Node)            [feature-007]
       │    ├─ BuildingSystem (Node)            [feature-009]
       │    └─ FaunaManager (Node)              ← THIS FEATURE
       └─ Camera3D                              [feature-002]
  └─ (CanvasLayers unchanged)
```

#### File Structure

```
scripts/
  fauna/
    fauna_manager.gd         # Node (child of Player) — spawn, AI movement,
                              #   contact damage, apply_damage API, despawn

  rendering/
    fauna_renderer.gd        # Node3D — MultiMesh for fauna bodies

scenes/
  world/
    fauna_renderer.tscn      # Single MultiMeshInstance3D
```

#### Component Responsibilities

| Component | Responsibility | Depends On |
|-----------|---------------|------------|
| `fauna_manager.gd` | Child Node of Player. Spawn on `night` signal. AI movement in `_process` (NIGHT only). Contact damage check + emit. `apply_damage()` API for auto-defend. Despawn on `dawn`. Fauna position query API. Does NOT implement player combat — emits signals consumed by feature-004. | `DayNightCycle` feature-008 (night/dawn signals, day_count, current_phase), `HexGrid` feature-001 (tile queries, distance, passability), `Player` (current_tile for proximity) |
| `fauna_renderer.gd` | Node3D under World. Single MultiMeshInstance3D (~3 max instances, 1 draw call). Updates on `fauna_spawned` (add), `fauna_moved` (transform), `fauna_killed` (remove), `fauna_despawned` (remove). Placeholder mesh: colored sphere or simple creature shape. | `FaunaManager` (fauna signals), `HexGrid` (axial_to_world for positioning) |

**Note:** Fauna 3D prop meshes are rendered by PropRenderer (feature-003), which
places the fauna body mesh at spawn position. Fauna ❓/name labels are owned by
PropLabelRenderer (feature-003), which listens to `fauna_spawned` and checks catalog
state to decide "❓ Unknown Fauna" vs real name label. FaunaRenderer renders the
creature body mesh; PropLabelRenderer renders the floating label above it.

#### Signal Wiring — Complete

```
DayNightCycle (feature-008)                  fauna_manager.gd
  night()                                ──►  spawn fauna (if day >= 4)
  dawn()                                 ──►  despawn all fauna

fauna_manager.gd                             feature-004 (AutoInteractionSystem)
  fauna_moved(id, from, to)              ──►  check adjacency for auto-defend

fauna_manager.gd                             feature-003 (ScannerSystem)
  fauna_spawned(id, coords, species)     ──►  icon rendering (❓ or identified)
  fauna_attacked_player(id, dmg, species)──►  surprise auto-catalog if uncataloged

fauna_manager.gd                             feature-007 (SurvivalSystem)
  fauna_attacked_player(id, dmg, species)──►  take_damage(damage)
  fauna_killed(id, coords, species)      ──►  add_ground_item(coords, &"meat", 1)

fauna_manager.gd                             fauna_renderer.gd
  fauna_spawned(id, coords, species)     ──►  add creature mesh instance
  fauna_moved(id, from, to)              ──►  update instance transform
  fauna_killed(id, coords, species)      ──►  remove instance
  fauna_despawned(id)                    ──►  remove instance

fauna_manager.gd                             feature-012 (HUD)
  fauna_attacked_player(id, dmg, species)──►  ScreenFade.flash(red) + floating damage text

feature-004 (AutoInteractionSystem)          fauna_manager.gd
  auto_defend_triggered(fauna_id, dmg)   ──►  apply_damage(fauna_id, dmg)
```

---

### Mobile Specs

#### Performance

| Operation | Cost | When |
|-----------|------|------|
| Spawn | O(t): t = total tiles (~300) for candidate filtering | Once at night start |
| Movement tick | O(f): f = active fauna (1-3). Per fauna: 1 distance check + 6 neighbor checks + 1 passability | Every frame during NIGHT (with cooldown gating) |
| Contact damage check | O(1): distance check + shelter check | After each fauna move |
| apply_damage | O(f): linear scan for fauna by ID | On each auto-defend hit |
| Despawn | O(f): clear array | Once at dawn |

Movement tick runs every frame but actual movement only occurs when cooldown expires
(1.0s intervals). Between moves, just one float decrement per fauna. At 1-3 fauna,
negligible.

#### Draw Calls

| Renderer | Draw Calls | Notes |
|----------|-----------|-------|
| FaunaRenderer | 1 | Single MultiMesh, ~3 max instances |
| **Total** | **1** | Running total: terrain ~5, icons ~6, resources ~6, ground ~1, structures ~5, fauna ~1 = ~24 |

#### Touch Interaction

None from this feature. Auto-defend is feature-004's concern (also no touch — it's
proximity-based). FaunaManager has zero touch input.

#### Platform Differences

None. Pure GDScript + Godot signals. iOS/Android identical.

#### Memory

- `_fauna`: 3 entries × ~64 bytes = ~192 bytes
- FaunaRenderer: 1 MultiMesh, 3 instances = negligible
- FAUNA_CONFIG: static Dictionary = negligible
