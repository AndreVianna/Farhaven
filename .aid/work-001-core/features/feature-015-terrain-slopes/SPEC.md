# Terrain Slopes — Elevation Edge Interpolation

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-06 | Feature created for delivery-004b — slopes replace hard steps for diff 1-3 | /aid-specify |

## Source

- delivery-004b (Camera + Landscape pivot)
- Andre's design decision: diff <= 3 = slope, diff 4+ = cliff

## Description

Hex tile edges transition between elevations using slopes instead of hard steps. When two adjacent tiles differ by 1-3 elevation levels (WALK/JUMP/DROP traversal), their shared edge vertices interpolate Y position, creating a visible slope. Only elevation differences of 4+ (BLOCKED traversal) produce vertical cliff faces. This creates three visually distinct terrain transitions that reinforce gameplay mechanics: gentle slopes you can walk, steep slopes you must jump, and walls you cannot pass.

## User Stories

- As a player, I want terrain to look like natural terrain with slopes, not a stepped board game
- As a player, I want to visually distinguish walkable slopes from jumpable slopes from impassable cliffs
- As a player, I want the world to feel like a real alien landscape from the orbital camera angle

## Priority

Must (P0 — delivery-004b)

## Acceptance Criteria

- [ ] Elevation diff 0: flat shared edges (unchanged from current)
- [ ] Elevation diff 1: gentle slope between tiles
- [ ] Elevation diff 2-3: steeper slope, visually distinct from diff 1
- [ ] Elevation diff 4+: vertical cliff face (unchanged from current)
- [ ] No visual gaps or z-fighting at slope transitions
- [ ] Single ArrayMesh draw call maintained
- [ ] Player movement on slopes feels smooth (no hovering/clipping)
- [ ] Slopes look natural from orbital camera (35-45 deg pitch)

## Save Integration

None. Terrain rendering is derived from tile elevation data.

---

## Technical Specification

### Data Model

No new data structures. Feature modifies mesh generation in `hex_grid_renderer.gd`.

#### Transition Types

| Elevation Diff | Traversal | Visual | Mesh Change |
|----------------|-----------|--------|-------------|
| 0 | WALK | Flat | Shared corner vertices at same Y (current) |
| 1 | WALK | Gentle slope | Outer corners on shared edge lerp Y 50% toward neighbor |
| 2-3 | JUMP/DROP | Steep slope | Outer corners on shared edge lerp Y 50% toward neighbor |
| 4+ | BLOCKED | Cliff face | Vertical quad (current). No Y interpolation. |

#### Vertex Layout Change

**Current:** 13 vertices per hex (center + 6 inner + 6 outer). All outer corners at `tile.elevation * ELEVATION_STEP`. Shared corners between same-elevation tiles use averaged color via corner_map key `Vector3i(x*1000, elevation, z*1000)`.

**New:** Up to 13 vertices per hex (same count). Outer corner Y varies per edge:
- For each of 6 edges, check neighbor elevation diff
- If diff 0: corner Y = own elevation (shared via corner_map, as now)
- If diff 1-3: corner Y = `lerp(own_y, neighbor_y, 0.5)`
- If diff 4+: corner Y = own elevation (cliff face generated separately)

Each hex still generates 6 wedge segments. The outer corners on a sloped edge simply have different Y than the inner ring.

#### Corner Y Computation

```gdscript
# For each hex edge (pair of corners i, i+1):
var neighbor = get_neighbor(coords, direction_i)
if neighbor == null:
    corner_y = elevation_y  # edge of map
elif abs(tile.elevation - neighbor.elevation) <= 3:
    # Slope: interpolate toward neighbor
    var neighbor_y = float(neighbor.elevation) * ELEVATION_STEP
    corner_y = lerpf(elevation_y, neighbor_y, 0.5)
else:
    # Cliff: stay at own elevation
    corner_y = elevation_y
```

Note: Each corner is shared by two edges. When a corner sits between two different-elevation neighbors, use the average of both interpolated values.

#### Cliff Face Generation Change

**Current (Step 5):** Generate cliff quad for ANY elevation diff > 0.

**New:** Generate cliff quad ONLY when diff >= 4.

```gdscript
# Step 5 change:
if neighbor_tile.elevation >= tile.elevation:
    continue
var diff = tile.elevation - neighbor_tile.elevation
if diff < 4:
    continue  # Slope handles diff 1-3 via vertex Y interpolation
# Generate cliff face quad for diff 4+
```

### Feature Flow

#### Mesh Build Flow (modified)

```
_build_mesh():
  Step 1: Collect tile colors (unchanged)
  Step 2: Build corner color map (unchanged — color sharing)
  Step 3: Average corner colors (unchanged)
  Step 4: Assemble triangles (MODIFIED)
    │
    For each hex:
      For each of 6 edges (i, i+1):
        │
        ├─ Compute corner_y_i and corner_y_j based on neighbor elevation diff:
        │    neighbor_a = neighbor sharing corner i (direction i-1)
        │    neighbor_b = neighbor sharing corner i (direction i)
        │    For each corner, average the slope interpolations from its 2 adjacent edges
        │
        ├─ Inner triangle: center → inner_i → inner_j
        │    All at elevation_y (inner ring stays flat)
        │
        ├─ Outer quad: inner_i → corner_i → corner_j → inner_j
        │    corner_i at corner_y_i, corner_j at corner_y_j
        │    Inner vertices at elevation_y
        │    Creates the visible slope on the 15% transition band
        │
        └─ Done
    │
  Step 5: Cliff faces (MODIFIED — only diff >= 4)
  Step 6: Commit mesh
```

### Layers & Components

#### Modified Files

| File | Change |
|------|--------|
| `scenes/world/hex_grid_renderer.gd` | Corner Y interpolation + cliff face threshold |

No new files. No new signals. No new dependencies.

#### Player Interaction

Player already handles elevation changes:
- `_update_elevation_y_interpolated()` in `player.gd` lerps Y between tile centers
- Jump/drop arcs handle larger elevation changes
- Slopes are cosmetic geometry — player Y is computed from tile elevation data, not mesh vertices
- Player may appear to float slightly above or clip slightly into slope geometry at the 15% transition band. This is acceptable for MVP (player is small relative to hex size).

### Mobile Specs

#### Performance

| Metric | Current | After Change |
|--------|---------|-------------|
| Vertices per hex | 13 | 13 (same — corners just have different Y) |
| Triangles per hex | 12 | 12 (same) |
| Cliff face quads | ~N (all diffs) | ~N/3 (only diff 4+, fewer quads) |
| Draw calls | 1 | 1 (single ArrayMesh unchanged) |

Net effect: **slightly fewer triangles** (fewer cliff face quads for diff 1-3 edges).

#### Memory

No change. Same vertex count, same mesh structure.
