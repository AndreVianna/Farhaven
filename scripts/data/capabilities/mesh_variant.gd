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
@export var scale: float = 1.0

## Optional rotation offset in degrees around Y axis.
## The prop's per-instance rotation is applied on top of this.
@export var rotation_offset_deg: float = 0.0
