# task-017: MapSerializer and MapValidator

**Type:** IMPLEMENT

**Source:** feature-004-import-export -> delivery-004

**Depends on:** task-007, task-002

**Scope:**
- Implement `MapSerializer` class (pure functions, no DOM):
  - `toJSON(hexGrid, mapMeta)` -- serialize HexGrid + MapMeta to JSON string. Keys sorted alphabetically. Tiles sorted by "q,r" key. Optional fields (structure, anomaly, resources) omitted when empty/null. Tab indent for readability.
  - `fromJSON(jsonString, knownBiomes, knownResources, knownStructures)` -- parse and validate JSON. Returns `{ mapMeta, hexGrid, validation }`. Only populates data when `validation.valid === true`.
  - Import: normalize plain string resource entries to dict form `{ type, x: random, y: random, rotation: random }` per SPEC
  - Import: handle null/missing optional fields (structure, anomaly, resources default to null/[])
- Implement `MapValidator` class (pure functions, no DOM):
  - `validate(hexGrid, mapMeta, knownBiomes, knownResources, knownStructures)` -- full validation pass returning `ValidationResult { valid, errors[] }`
  - Checks: spawn exists as tile, all biomes known, all elevations 0-9 integers, all structures known, all resource types known, resource positions within [-1.0, 1.0], rotation is a number
  - Hardcoded biome warning: tiles referencing biomes not in [crash_site, grassland, forest, rocky, water] get a warning (not a blocking error)
  - `validateTile(tile, ...)` -- single tile validation for import iteration
  - All errors collected (not fail-fast) so user sees everything at once
- Implement all import validation rules per SPEC table: JSON parse failure, missing required fields, invalid spawn format, invalid tile keys, unknown biome/structure/resource, elevation range, resource field validation

**Acceptance Criteria:**
- [ ] `MapSerializer.toJSON()` produces JSON in exact MapLoader format with sorted keys and tiles
- [ ] `MapSerializer.fromJSON()` correctly parses ch1.json and populates HexGrid + MapMeta
- [ ] Round-trip: `toJSON(fromJSON(original))` produces semantically equivalent output to input (AC1)
- [ ] Optional fields omitted from export when empty/null
- [ ] Plain string resource entries normalized to dict form on import
- [ ] `MapValidator.validate()` catches: missing spawn, unknown biome/resource/structure, elevation out of range, resource position out of range
- [ ] Validation collects all errors (not fail-fast)
- [ ] Hardcoded biome warning generated for custom biomes (non-blocking)
- [ ] Malformed JSON input returns descriptive error, never crashes
- [ ] Missing required fields each produce specific error messages
