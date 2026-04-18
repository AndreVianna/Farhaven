# Prop Placement — Scatter Presets, Seeded Randomization, Per-Instance Overrides

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-17 | Problem identified: Grassland props look isolated and sparse in-game despite being placed correctly. Each prop occupies a sub-hex but visually leaves empty space around. | Andre visual review |
| 2026-04-18 | Design converged through Discord discussion — scatter presets, count jitter ±2, seeded per-instance randomization (variant + 15% scale + rotation), per-instance overrides when placement is Single | Andre + Lola |
| 2026-04-18 | Initial spec drafted | Lola |

## Source

- **Problem trigger:** 2026-04-17 in-game screenshots (grassland with sparse plants — player-scale plants surrounded by empty dirt)
- **Proposed REQUIREMENTS.md addition:** F17 Prop Placement — Scatter & Per-Instance Overrides (pending approval)
- **Full design discussion:** `~/lola/notes-to-self/2026-04-17-prop-placement-thinking.md` + Discord thread (converged 2026-04-18)
- **Depends on:** feature-005 (Resource Editor), feature-006 (Biome Editor), feature-001 (Hex Canvas), engine scripts in `scripts/hex/`, `scripts/rendering/prop_renderer.gd`

## Description

Grassland biomes feel sparse because each placed `Prop` instance renders as a single mesh at a specific sub-hex. A "field of grass" visually becomes "7 isolated grass specimens in a hex." Scaling meshes up would make the player character look tiny; adding more per-sub-hex requires a data model change.

This feature introduces **scatter presets** at the PropDef level. The author places *one* Prop instance at a sub-hex; the engine expands it at render time into 1-19 instances distributed across the sub-sub-hex (SSH) grid within that sub-hex. All rendered copies — original and scattered — randomize variant, scale (±15%), and horizontal rotation (0–360°), seeded deterministically from the placement's coordinates. This gives dense, natural-feeling vegetation without per-instance authoring overhead.

For precise control, each Prop instance can override placement preset, variant, scale, and rotation. Variant/scale/rotation overrides only apply when the effective placement is `SINGLE` (no siblings to break the procedural illusion).

**What is NOT in scope:**
- Multi-select + bulk edit on the editor canvas (deferred to post-MVP)
- Cross-hex scatter (a scatter that spills into adjacent hexes)
- Runtime dynamic scatter (e.g. grass growing over time)
- Visual feedback markers on the editor map for override instances

## User Stories

- As Andre, I want grassland hexes to look like grasslands (dense, natural plant coverage) so that the world feels alive instead of laboratory-sterile
- As Andre, I want to pick a scatter preset per prop type (Single / Normal / Dense / Sprouting / Spread) so that I can define each prop's default density once and reuse it everywhere
- As Andre, I want a right-click context menu on placed props so that I can change preset for this specific instance or pin exact variant/scale/rotation when the placement is Single
- As Andre, I want the count to jitter ±2 within a range so that Normal-density patches don't look mathematically symmetrical
- As Andre, I want the same placed prop to look the same every time I load the map so that iteration feels stable

## Priority

Must (not deferrable — without this, grassland biomes cannot achieve their core visual goal)

## Acceptance Criteria

- [ ] Given a PropDef with `placement: NORMAL`, when a Prop instance is placed at (H, SH), then the engine renders 5–9 meshes distributed across the SSH grid within that sub-hex (1 center + 4–8 from the remaining 18 SSH positions), each with seeded-random variant/scale/rotation
- [ ] Given a PropDef with `placement: SINGLE`, when a Prop instance is placed, then exactly one mesh is rendered at the sub-hex center with seeded-random variant/scale/rotation
- [ ] Given a Prop instance with `placement_override: DENSE`, when rendered, then 11–15 meshes are drawn (count=13 ± 2) regardless of the PropDef's default placement
- [ ] Given a Prop instance with `variant_override: 2` and effective placement == SINGLE, when rendered, then the single mesh uses variant index 2 (not seeded-random)
- [ ] Given a Prop instance with `variant_override: 2` and effective placement != SINGLE, when rendered, then the variant_override is ignored (siblings would break the procedural illusion)
- [ ] Given two playthroughs of the same map without data changes, when the scene renders, then every Prop instance produces the identical layout (positions, variants, scales, rotations)
- [ ] Given the editor map view, when the user right-clicks a placed prop, then a context menu shows Placement / Variant / Scale / Rotation fields with the correct enabled/disabled state per the Single-only rule
- [ ] Given the user changes an instance from SINGLE to any scatter preset in the context menu, when the change is applied, then variant_override / scale_override / rotation_override are cleared to null
- [ ] Given an existing save file with `Prop.rotation_deg` set, when loaded, then the value is migrated to `rotation_override` and `rotation_deg` is removed
- [ ] Given an instance with collision_shapes on its PropDef and placement != SINGLE, when rendered, then only the original center instance contributes collision — scattered siblings are walkthrough visual-only

---

## Technical Specification

### Data Model

#### New enum: PlacementPreset

Location: `scripts/data/capabilities/placement_preset.gd` (new file)

```gdscript
class_name PlacementPreset extends Resource

enum Preset {
    SINGLE,      # [1, 0]    — boulders, structures, isolated specimens
    NORMAL,      # [7, 0.5]  — default for scatterable plants/flora
    DENSE,       # [13, 0.5] — thick vegetation (shrubs, busy growth)
    SPROUTING,   # [7, 0.3]  — small satellites around a parent (new growth)
    SPREAD,      # [13, 1.0] — uniform distribution at full size (pasture)
}

static func get_count(preset: int) -> int:
    match preset:
        Preset.SINGLE:    return 1
        Preset.NORMAL:    return 7
        Preset.DENSE:     return 13
        Preset.SPROUTING: return 7
        Preset.SPREAD:    return 13
    return 1

static func get_sibling_scale(preset: int) -> float:
    match preset:
        Preset.SINGLE:    return 0.0  # unused
        Preset.NORMAL:    return 0.5
        Preset.DENSE:     return 0.5
        Preset.SPROUTING: return 0.3
        Preset.SPREAD:    return 1.0
    return 1.0
```

Note: GDScript enums cannot be stored as typed fields on a Resource directly. We store as `int` with helper methods. Alternative: use a plain dictionary lookup. Implementation detail.

#### PlacementCap (new capability)

Location: `scripts/data/capabilities/placement_cap.gd` (new file)

```gdscript
class_name PlacementCap extends Resource

## Default placement preset for all instances of this prop.
## Override per-instance via Prop.placement_override.
@export var placement: int = PlacementPreset.Preset.SINGLE  # store as int
```

Rationale for new cap (vs adding to PlaceableCap):
- Not every placeable prop needs scatter (Ship Debris is placeable, never scatters)
- Opt-in via capability is consistent with existing pattern (CatalogableCap, HarvestableCap)
- Allows future expansion (scatter-specific config like jitter_range, sibling_variant_bias, etc.) without bloating PlaceableCap

#### PropDef changes

Add to `scripts/data/prop_def.gd` cap detection logic — recognize PlacementCap the same way existing caps are detected (via `caps: Array[Resource]` or similar field; match the existing pattern).

Propose helper on PropDef:
```gdscript
func get_placement_cap() -> PlacementCap:
    for cap in caps:
        if cap is PlacementCap: return cap
    return null

func get_placement() -> int:
    var cap = get_placement_cap()
    if cap: return cap.placement
    return PlacementPreset.Preset.SINGLE  # default for props without cap
```

#### Prop (instance) changes

Location: `scripts/hex/prop.gd`

**Remove:**
```gdscript
@export var rotation_deg: float = 0.0  # DELETE — replaced by rotation_override
```

**Add:**
```gdscript
# Overrides — null/sentinel = use procedural default from seed
# variant_override and scale_override and rotation_override are only
# effective when the effective placement preset resolves to SINGLE.
@export var placement_override: int = -1       # -1 = inherit from PropDef; otherwise PlacementPreset.Preset value
@export var variant_override: int = -1         # -1 = seeded random; otherwise mesh index
@export var scale_override: float = -1.0       # < 0 = seeded random; otherwise absolute scale
@export var rotation_override: float = -1.0    # < 0 = seeded random; otherwise degrees 0-360
```

**Rationale for `-1` sentinels vs nullable fields:** GDScript's typed exports don't support null for int/float. Sentinel values avoid wrapper Resources. Trade-off: `-1` is not a valid index/scale/rotation value in practice (scale > 0, rotation 0-360, variant 0+, preset 0+).

Helper methods:
```gdscript
func get_effective_placement(prop_def: PropDef) -> int:
    if placement_override >= 0: return placement_override
    return prop_def.get_placement()

func has_variant_override() -> bool: return variant_override >= 0
func has_scale_override() -> bool: return scale_override > 0.0
func has_rotation_override() -> bool: return rotation_override >= 0.0
```

### Scatter Algorithm

#### Hierarchy recap

Farhaven's hex geometry is fractal at each level:
- **H** (hex): the tile. 1 tile in a map contains 19 SH positions.
- **SH** (sub-hex): 19 positions per H. Flat-top hex with 1 center + 6 ring1 + 12 ring2.
- **SSH** (sub-sub-hex): 19 positions per SH. Same geometry, smaller scale.

Sub-hex scale formula (from engine contract): `1/(cos(30°)*5) ≈ 0.2309` units per SH. Same ratio applied one more level: SSH scale ≈ 0.0533 units.

SSH positions within a SH are the same 19 axial coordinates used for SH within H, just scaled down. The existing `hex_math.gd` utilities can be reused.

#### Deterministic seed

```gdscript
func compute_seed(map_id: StringName, h: Vector2i, sh: Vector2i, prop_type: StringName) -> int:
    var s: int = 0
    s = hash(map_id) ^ (h.x * 73856093) ^ (h.y * 19349663) ^ (sh.x * 83492791) ^ (sh.y * 2654435761)
    s ^= hash(prop_type)
    return s & 0x7fffffff  # keep positive
```

Rationale for including `prop_type` in seed: if an author replaces one prop type with another at the same SH, the scatter shouldn't look identical (different prop = different random layout). If seed included only position, swapping prop types would produce the same pattern in a different mesh — uncanny.

The seed drives a simple LCG or `RandomNumberGenerator` instance, locally scoped to this prop's render. Multiple calls consume the sequence deterministically.

#### Count jitter

```gdscript
func compute_actual_count(rng: RandomNumberGenerator, preset_count: int) -> int:
    if preset_count == 1: return 1  # SINGLE never jitters
    var jitter = rng.randi_range(-2, 2)
    return clamp(preset_count + jitter, 1, 19)
```

Examples:
- `NORMAL` (7) → [5, 9]
- `DENSE` (13) → [11, 15]
- `SPROUTING` (7) → [5, 9]
- `SPREAD` (13) → [11, 15]

#### SSH position selection

```gdscript
# 19 SSH positions per SH. Center is index 0; ring1 is 1-6; ring2 is 7-18.
const SSH_POSITIONS: Array[Vector2i] = [
    Vector2i(0, 0),                                               # 0 — center
    Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),             # 1-3 ring1
    Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),             # 4-6 ring1
    # 12 ring2 positions (same formula as HexMath.DIRECTIONS scaled by 2, plus intermediates)
    # ... (derive from hex_math.gd or inline — 12 axial coords at distance 2)
]

func select_ssh_positions(rng: RandomNumberGenerator, count: int) -> Array[Vector2i]:
    if count == 1: return [SSH_POSITIONS[0]]  # center only

    # Center + (count-1) randomly chosen from the remaining 18
    var indices = range(1, 19)  # [1..18]
    indices.shuffle()  # seeded via the rng
    var selected: Array[Vector2i] = [SSH_POSITIONS[0]]
    for i in range(count - 1):
        selected.append(SSH_POSITIONS[indices[i]])
    return selected
```

Note: `Array.shuffle()` in GDScript uses the global RNG, not ours. Implementation must use the seeded RNG manually for Fisher-Yates. The snippet above is illustrative.

#### Per-instance randomization

For each of the N SSH positions (the center and scattered siblings), compute:

```gdscript
# Consume 3 random values per instance (variant, scale, rotation)
func render_params(rng, prop_def, is_center, has_variant_ovr, has_scale_ovr, has_rotation_ovr, ovr_variant, ovr_scale, ovr_rotation, sibling_scale_mult) -> Dictionary:
    var variant_count: int = prop_def.get_placeable_cap().meshes.size()  # assumes PlaceableCap exists

    # Variant
    var variant: int
    if has_variant_ovr and is_center: variant = ovr_variant
    else:                              variant = rng.randi_range(0, variant_count - 1)

    # Scale: base = meshes[variant].scale * jitter(0.85..1.15)
    var base_scale: float = prop_def.get_placeable_cap().meshes[variant].scale
    var jitter: float = 0.85 + rng.randf() * 0.30
    var scale: float
    if has_scale_ovr and is_center: scale = ovr_scale
    else:                            scale = base_scale * jitter * (1.0 if is_center else sibling_scale_mult)

    # Rotation: 0-360°
    var rotation: float
    if has_rotation_ovr and is_center: rotation = ovr_rotation
    else:                               rotation = rng.randf() * 360.0

    return {"variant": variant, "scale": scale, "rotation": rotation}
```

**Consumption order matters.** The RNG advances deterministically — if we call `rng.randi_range(0, N)` before `rng.randf()`, the values depend on the count of meshes. Document the order: for each position (center first, then siblings in order of selection), consume (variant, scale_jitter, rotation) in that order.

### Engine Render Path

Location: `scripts/rendering/prop_renderer.gd`

Current: `prop_renderer.gd` iterates `tile.props`, and for each Prop with a PlaceableCap, it adds ONE MultiMesh instance at the sub-hex world position.

**Change:** for each Prop, compute the scatter (1-19 instances). Emit each to the MultiMesh pool.

```gdscript
func render_prop_instance(tile: HexTile, prop: Prop, prop_def: PropDef) -> void:
    var placeable = prop_def.get_placeable_cap()
    if placeable == null: return  # not placeable

    var effective_placement = prop.get_effective_placement(prop_def)
    var preset_count = PlacementPreset.get_count(effective_placement)
    var sibling_scale_mult = PlacementPreset.get_sibling_scale(effective_placement)

    var rng := RandomNumberGenerator.new()
    rng.seed = compute_seed(current_map_id, tile.coord, prop.sub_hex, prop.type)

    var actual_count = compute_actual_count(rng, preset_count)
    var ssh_positions = select_ssh_positions(rng, actual_count)

    # Effective placement == SINGLE? Overrides are active.
    var is_single = (effective_placement == PlacementPreset.Preset.SINGLE)

    for i in range(ssh_positions.size()):
        var is_center = (i == 0)
        var params = render_params(
            rng, prop_def, is_center,
            is_single and prop.has_variant_override(), ...
        )
        var ssh_offset: Vector3 = ssh_to_world_offset(ssh_positions[i])
        var world_pos: Vector3 = sub_hex_world_pos(tile, prop.sub_hex) + ssh_offset
        _multimesh_pool_for(prop.type, params.variant).add_instance(
            world_pos, params.scale, params.rotation
        )

    # Collision — only from original/center, and only if placeable has collision_shapes
    if placeable.collision_shapes.size() > 0:
        _add_collision_at(sub_hex_world_pos(tile, prop.sub_hex), placeable.collision_shapes)
```

**Performance:** worst case scatter = 15 instances per Prop × ~20 Props per tile × ~200 tiles = 60,000 MultiMesh instances. MultiMesh is designed for this scale; no issue.

### Editor UX

#### Context menu (right-click a placed prop)

```
┌─ Edit instance ─────────────────┐
│ Placement: [Normal         ▼ ↺] │ ← always enabled; ↺ clears placement_override
│                                  │
│ Variant:   [v2 (seed)      ▼ ↺] │ ← enabled iff effective placement == SINGLE
│ Scale:     [1.00 (seed)    ↺]   │ ← same
│ Rotation:  [90° (seed)     ↺]   │ ← same
│ ───────────────────────────────  │
│ Delete                    (Del)  │
└──────────────────────────────────┘
```

**Behavior:**

- **Placement dropdown** — lists 6 options: `Inherit (PropDef default) / Single / Normal / Dense / Sprouting / Spread`. Selecting "Inherit" sets `placement_override = -1`.
- **Variant / Scale / Rotation fields** — enabled iff effective placement resolves to SINGLE (either via override or PropDef default). When disabled, display the current seeded value in parentheses (read-only preview), e.g. `v2 (seed)`.
- **Per-field reset ↺ button** — enabled iff that field is editable (Single). Clicking clears that specific override (sets to -1 / -1.0) and recomputes from seed on next render.
- **Transition: Single → Scatter** — when user changes placement from Single to any scatter preset (Normal/Dense/etc), the editor auto-clears `variant_override`, `scale_override`, `rotation_override` to -1. Variant/Scale/Rotation fields immediately disable.
- **Transition: Scatter → Single** — variant/scale/rotation fields become editable. Overrides stay null (procedural) unless user sets them.

#### PlacementCap authoring (PropDef editor)

In the existing prop editor form (`tools/level-editor/js/prop-editor.js`), add a new capability section:

```
☑ PLACEMENT
  Preset: [Normal ▼]
```

Shows the 5 presets. Default for new props: Single (matches `PlacementCap.placement = SINGLE`).

### Migration

#### Existing `Prop.rotation_deg` field

- Serialized Prop data currently has `rotation_deg: float`
- New model has `rotation_override: float = -1.0`
- Migration rule: on first load of an old save, copy `rotation_deg` to `rotation_override` if `rotation_deg != 0.0`, else set `rotation_override = -1.0` (0.0 is ambiguous — could be "no rotation set" or "set to zero"; default to the former since procedurally random rotation better matches gameplay feel)
- Remove `rotation_deg` from the export after migration

#### Existing Prop instances without PlacementCap on their PropDef

- Without a PlacementCap, `PropDef.get_placement()` returns `SINGLE`
- Effective behavior: identical to current rendering (1 mesh per Prop)
- No visual change for existing maps until author adds PlacementCap to a PropDef
- Safe opt-in rollout

#### Existing assets (.tres props saved today)

- Our 12 grassland props (P00001-P00007 plants, P01001-P01005 minerals) all have PlaceableCap but no PlacementCap
- Post-feature-011 task: add PlacementCap to each — plants get NORMAL/DENSE/SPROUTING, minerals stay SINGLE (boulders shouldn't scatter)

### Edge Cases

| Scenario | Behavior |
|---|---|
| PropDef has no PlaceableCap and has PlacementCap | PlacementCap is ignored — scatter needs a mesh to render. Editor should warn but not block. |
| PropDef has 0 meshes in PlaceableCap | Render path skips. Editor already handles this case. |
| `placement_override` points to invalid preset value (data corruption) | Fall back to PropDef default. Log warning. |
| User places prop with `scatter_count == 15` on a tiny hex at game-zoom-2x | All 15 render within the SH; visual density is OK because SSH geometry keeps them within bounds |
| Two different Prop instances of the same type at adjacent SHs produce same scatter | Seed includes SH coordinates, so scatters differ — no issue |
| User deletes a Prop mid-render | Standard editor-engine sync: Prop removed from `tile.props`, next render frame skips it |
| Prop instance has `variant_override: 5` but PropDef only has 3 meshes | Fallback to variant 0 (or clamp). Log warning. |
| Sibling position maps to a world location outside the visible hex (unlikely geometric edge) | Visual rendering doesn't care about hex boundaries — SSH positions are all inside the SH which is inside the H. Geometry ensures containment. |
| Save game mid-scatter, load, compare | Identical result (seed deterministic, no floating-point divergence across platforms expected from seeded RNG) |
| Author wants "empty" tile that still has biome color | Place no props → tile renders with biome ground only. No change from today. |
