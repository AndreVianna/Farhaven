# task-003: TresParser -- Parse and Serialize .tres Files

**Type:** IMPLEMENT

**Source:** feature-007-file-discovery -> delivery-001

**Depends on:** task-002

**Scope:**
- Implement `TresFile` class with `headerLine`, `extResources`, `resourceFields` (ordered Map), `uid`, `scriptClass`
- Implement `TresValue` tagged union type with all variants: string, stringname, int, float, bool, color, vector2i, ext_resource, dict (with keyStyle tracking), array (typed and untyped with elementType), packed_string_array
- Implement `TresParser.parse(text)` with line-by-line parsing of `[resource]` section:
  - Header line extraction and preservation
  - `[ext_resource ...]` line collection
  - `uid` extraction from header
  - `script_class` extraction from header (or from `script_class` attribute)
  - Key-value pair parsing for each line in `[resource]` section
- Implement `TresParser.parseValue(valueStr)` with detection rules per SPEC: `&"..."` -> stringname, `"..."` -> string, `Color(...)` -> color, `Vector2i(...)` -> vector2i, `ExtResource(...)` -> ext_resource, `{...}` -> dict, `[...]` -> array, `Array[Type](...)` -> typed array, `PackedStringArray(...)` -> packed_string_array, `PackedColorArray(...)` -> typed array with Color, `true`/`false` -> bool, float vs int detection
- Implement `TresParser.serialize(tresFile)` preserving header, ext_resources, blank lines between sections, field order
- Implement `TresParser.serializeValue(tresValue)` with correct formatting per SPEC: stringname -> `&"value"`, float always has decimal, dict keyStyle preservation (stringname vs string keys), typed array -> `Array[Type](...)`, etc.
- Implement `generateTresUid()` for new file creation
- Round-trip validation: during discovery, compare `TresParser.serialize(TresParser.parse(text))` against original text, log warnings on mismatch

**Acceptance Criteria:**
- [ ] `TresParser.parse()` correctly parses all existing .tres files in `data/resources/` and `data/biomes/`
- [ ] `TresParser.serialize(TresParser.parse(text)) === text` for all well-formed .tres files in the project (round-trip invariant)
- [ ] All TresValue types are correctly detected and round-tripped: stringname, string, int, float, bool, color, vector2i, ext_resource, dict (both key styles), array (typed/untyped), packed_string_array
- [ ] Dict keyStyle is preserved: top-level resource fields use `&"key"`, dicts inside arrays use `"key"`
- [ ] Float serialization always includes decimal (e.g., `1.0` not `1`)
- [ ] Header line, ext_resource lines, and uid are preserved verbatim
- [ ] `generateTresUid()` produces valid format: `uid://c` + 13 lowercase alphanumeric chars
- [ ] Malformed input throws descriptive errors (not silent corruption)
- [ ] Build passes; no regressions in game code
