# SSH Grid + Mesh Collision — Spatial System Redesign

**Status:** Approved design, implementation deferred to delivery-006
**Created:** 2026-04-09
**Authors:** Andre Vianna (concept) + Lola (math validation + documentation)

## The Change

Replace abstract footprint arrays with mesh-based collision and a 3-level hex grid.

### Three-level grid

```
Hex (H):          diameter = 6.000m    — world tile, biome unit
Sub-hex (SH):     diameter = 1.386m    — prop anchor, current placement unit
Sub-sub-hex (SSH): diameter = 0.320m   — fine placement snap (32cm resolution)

Formula: child_diameter = (parent_diameter / 5) / (√3/2)
```

### What changes

| Before | After |
|---|---|
| `footprint: [Vector2i]` manual cell list | **DELETE** — mesh is the truth |
| `PlaceableCap.footprint` | **DELETE** |
| `blocks_movement: bool` flag | **DELETE** — CollisionShape3D on mesh handles blocking |
| Collision = "cell occupied?" | **Collision = 3D mesh overlap** (Godot physics) |
| Placement snap = sub-hex center | **Placement snap = SSH center** (32cm grid) |
| 2D footprint in editor | **2D top-down silhouette** derived from mesh |

### Decisions (Andre, 2026-04-09)

1. **No footprint field.** Collision is 3D mesh-to-mesh. Godot native (CollisionShape3D, Area3D).
2. **Two representations per prop:** 3D mesh (game world) + 2D top-down (web editor).
3. **SSH is placement snap only.** "Where to position the prop center." Collision is mesh physics.
4. **Prop center of rotation = center of nearest SSH.**
5. **Prop base = ground plane.** Mesh bottom aligns with terrain Y.
6. **No pathfinder yet.** Movement blocking comes from mesh colliders, not grid data.
7. **Performance deferred.** Evaluate when implemented (~18,000 SSHs per 50-hex map is manageable).
8. **Detailed building (shelves, wall mounts) = future.** Current props sit on the ground.

### What this enables

- Props with any shape (box, cylinder, irregular) placed at 32cm precision
- Natural coexistence: torch + chest in same sub-hex if meshes don't overlap
- No manual footprint maintenance — add a mesh, it just works
- Editor shows real prop shapes (2D projected) on the SSH grid
- Level design in both web editor and Godot editor with same snapping

### Implementation scope (delivery-006)

- Add SSH coordinate math to HexMath (trivial — same axial math, smaller scale)
- Remove `footprint` from PlaceableCap and all .tres files
- Remove `blocks_movement` from PlaceableCap
- Add CollisionShape3D to prop meshes (or generate from placeholder mesh params)
- Update BuildingSystem placement to snap to SSH + physics overlap check
- Update web editor to show SSH grid + 2D prop silhouettes
- Update StructureRenderer to position at SSH precision
- ~Estimated 3-4 tasks, ~20h total
