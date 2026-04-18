# tools/migrations

One-shot data migration scripts. Each file is dated `YYYY-MM-DD-<slug>.py`
and documents a specific transformation applied once to the repo.

These scripts **aren't intended to be rerun** after their initial use —
they're kept as a record of what was done to the data, so future readers
can understand data shape changes that a commit alone doesn't explain.

When adding a new migration:

1. Name it `YYYY-MM-DD-<slug>.py` (or `.sh`, etc.)
2. Document the intent and inputs/outputs in a module docstring
3. Make it idempotent where cheap (re-running shouldn't destroy data)
4. Commit the script alongside the migrated data

## Current entries

| Date | Script | Transformation |
|------|--------|----------------|
| 2026-04-17 | `2026-04-17-grassland-scale-collision.py` | Add scale + collision_shapes to 12 grassland prop .tres files (P00001-P00007 plants, P01001-P01005 minerals). First-pass values per Discord discussion 2026-04-17/18. |
| 2026-04-18 | `2026-04-18-grassland-placement-cap.py` | Add PlacementCap to same 12 props. Plants get NORMAL scatter, Boulder stays SINGLE, other minerals get SPROUTING. Enables feature-011 scatter rendering for the grassland biome. |
