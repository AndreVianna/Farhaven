## DEPRECATED: Kept only for fauna fallback (data/catalog/fauna.tres).
## TODO: Remove when fauna PropDefs exist.
class_name CatalogData
extends Resource

## Container resource for an array of CatalogEntry definitions.
## Used by data/catalog/fauna.tres only (fauna has no PropDefs yet).

@export var entries: Array = []  # Array of CatalogEntry
