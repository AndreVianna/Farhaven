class_name MeshVariant
extends Resource

## MeshVariant — a single visual variant for a Placeable prop.
## Props can have multiple variants; the renderer picks one per instance
## (hash-based) for visual variety across tiles.
##
## The mesh is a reference to an imported .glb/.gltf/.obj/.fbx — Godot
## creates a PackedScene from the import, from which the actual Mesh
## resource is extracted by the prop renderer.

## Imported 3D asset (Godot PackedScene or Mesh resource).
## Points to res://assets/props/PXXXXX/*.glb or similar.
@export var scene: PackedScene = null

## Optional uniform scale applied to the variant (default 1.0).
## Expected range: positive, finite. Consumed by PropRenderer and
## StructureRenderer — siblings in a scatter group receive additional
## variance from the seeded RNG on top of this base value.
@export var scale: float = 1.0

# Note: rotation_offset_deg was removed 2026-04-18. Rotation is now
# either purely procedural (seeded 0-360°) on scatter / default SINGLE,
# or pinned per-instance via Prop.rotation_override (UI context menu).
# Correcting a mesh that was exported at the wrong base rotation should
# happen in the DCC tool or the .glb import step, not as a per-variant
# runtime offset.
