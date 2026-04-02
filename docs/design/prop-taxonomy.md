# Prop Taxonomy

All world objects fall into 4 categories. This is the authoritative reference.

## Categories

| Type | Moves? | Harvestable? | Blocks Movement? | Render Strategy | Examples |
|------|--------|-------------|-------------------|-----------------|----------|
| Decoration | No | No | No | MultiMesh (batched) | Grass tufts, flowers, pebbles, dead branches |
| Resource | No | Yes | No | MultiMesh (per type, 6 pools) | Wood/tree, stone/rock, ore/vein, berries/bush, fiber/grass, crystal/cluster |
| Structure | No | No | Some yes | Node3D (individual) | Workbench, shelter, wall, torch, storage chest, boulder, ruins, bridge |
| Entity | Yes | Yes | No | Node3D (individual, moves) | Hostile fauna (thornback), shy fauna |

## Key Rules

1. **Resources** are gathered via auto-interaction (proximity + catalog gate). They deplete and respawn.
2. **Structures** include both player-built (workbench, wall) and map-placed (boulder, ruins, bridge). All stored in `HexTile.structure`. Movement blocking checked via `get_traversal()`.
3. **Entities** move independently. They have AI (pathfinding, flee/chase). Rendered as individual Node3D because position changes every frame.
4. **Decorations** are purely visual. No game logic. Deferred post-MVP.
5. **Collision is hex-logic only.** No physics bodies, no Area3D, no raycasts. All blocking is tile-level via `HexGrid.get_traversal()` checking elevation + structure.blocks_movement.

## Render Pipeline

| Renderer | Category | Delivery | Draw Calls | Notes |
|----------|----------|----------|------------|-------|
| HexGridRenderer | Terrain | 001 ✅ | ~1 | Single ArrayMesh |
| ResourceRenderer | Resource | 003 | ~6 | MultiMesh per resource type |
| PropLabelRenderer | Resource + Entity | 002 ✅ | ~1 | Label3D markers (❓/⚠️/name) |
| ScanProgressRenderer | Resource + Entity | 002 ✅ | ~1 | Shader-based progress bar |
| StructureRenderer | Structure | 005 | ~5-20 | Individual Node3D per structure |
| FaunaRenderer | Entity | 005 | ~3-10 | Individual Node3D per fauna |
| DecorationRenderer | Decoration | post-MVP | TBD | MultiMesh scatter |

**PropRenderer (delivery-002) is replaced by ResourceRenderer (delivery-003).** PropRenderer used generic cubes per category (flora/fauna/mineral/anomaly). ResourceRenderer uses specific meshes per resource type (tree/rock/bush/etc.) — strictly better. PropRenderer to be deleted when ResourceRenderer is implemented.

## Collision Architecture

No physics engine. All spatial queries use hex math:

- `HexGrid.get_traversal(from, to)` → WALK / JUMP / DROP / BLOCKED
- Checks: elevation difference + `structure_config[tile.structure].blocks_movement`
- Fauna pathfinding: A* with `max_jump` attribute per species
- Auto-gather/defend range: hex distance ≤ 1
- Fog of war: hex distance from player

This is intentional for mobile performance. Intra-hex collision (props within the same hex blocking each other) is not supported and not planned.
