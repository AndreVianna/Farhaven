# Editor Sync Requirements — Post delivery-004b

*The game engine (Godot/GDScript) received major changes in delivery-004b that the
web-based level editor (`tools/level-editor/`) does not yet reflect. This document
lists every change that requires editor updates.*

---

## P0 — Breaking Changes (editor produces incorrect data)

### 1. Sub-hex Size Mismatch

**What changed:** `SUB_HEX_SIZE` in the game engine changed from `HEX_SIZE / 5.0 = 0.6`
to `(HEX_SIZE / cos(30°)) / 5.0 ≈ 0.6928` to account for the 30° rotation between
flat-top main hexes and pointy-top sub-hexes.

**Editor impact:** `tools/level-editor/js/hex-math.js` line 135:
```javascript
SUB_HEX_SCALE: 0.2,  // Currently: HEX_SIZE * 0.2 = 0.6
```

**Required fix:** Change to:
```javascript
SUB_HEX_SCALE: 1.0 / (Math.cos(Math.PI / 6) * 5),  // ≈ 0.2309 → HEX_SIZE * 0.2309 ≈ 0.6928
```

**Files affected:** `js/hex-math.js`, `test-unit.mjs` (if sub-hex scale is tested)

**Verification:** Place a resource prop at sub-hex (1,0) in the editor, export map,
load in game — prop should appear at the same relative position within the hex.

---

### 2. Elevation Range Expanded

**What changed:** Elevation range expanded from `0–9` to `-32000..+32000` (short int limits).

**Editor impact:**
- `js/biome-editor.js` line 21: `elevation_range = { min: 0, max: 9 }` — default should allow full range
- `js/biome-editor.js` lines 1135-1139: validation hardcoded to 0–9
- Elevation paint tool slider: currently limited to 0–9
- Elevation display in hex inspector: may need to handle negative values

**Required fix:**
1. Change validation from `0..9` to `-32000..32000`
2. Update default `elevation_range` to `{ min: -32000, max: 32000 }`
3. Elevation tool UI: input field instead of small slider (range is too large for a slider)
4. Support negative elevation display in hex grid and inspector

**Files affected:** `js/biome-editor.js`, `js/tools.js` (elevation tool), `js/panels.js` (inspector), `js/canvas.js` (elevation number display)

---

## P1 — Data Model Changes (editor produces outdated data structure)

### 3. Prop Categories Expanded (10 categories)

**What changed:** Prop categories expanded from 3 (`RESOURCE=0, STRUCTURE=1, ANOMALY=2`)
to 10 categories spanning Natural and Non-Natural:

| Index | Category | Type | Description |
|-------|----------|------|-------------|
| 0 | Plant | Natural | Flora, vegetation |
| 1 | Mineral | Natural | Rocks, ores, crystals |
| 2 | Animal | Natural | Fauna (hostile or passive) |
| 3 | Fungi | Natural | Mushrooms, molds |
| 4 | Liquid | Natural | Water, pools, streams |
| 5 | Ooze | Natural | Living organic matter |
| 6 | Structure | Non-Natural | Buildings player can enter |
| 7 | Vehicle | Non-Natural | Mobile transport |
| 8 | Equipment | Non-Natural | Interactive objects with UI |
| 9 | Storage | Non-Natural | Containers for items |

**Editor impact:**
- `js/tools.js`: Resource, Structure, and Anomaly tools currently create props with hardcoded categories. Need to either:
  - (a) Replace the 3 tools with a single "Prop" tool with category selector, OR
  - (b) Update existing tools to use new category indices and add tools for new categories
- `js/panels.js`: Prop inspector shows category — needs to display the new names
- Tool palette in `js/app.js`: tool definitions and shortcuts need updating

**Note:** The old `ANOMALY` category no longer exists as a category — Anomaly is now a
derived state (`scanned AND NOT identified AND origin NOT IN [Natural, Crafted]`).
SPAWN is also removed from props — it's level metadata stored as `spawn: [q, r]` in the
map JSON root, not as a prop.

**Required fix:** 
1. Prop placement tool(s) must set `category` to correct new index (0-9)
2. Anomaly tool should be removed or replaced with an Origin selector
3. Spawn tool remains separate (sets map-level `spawn` field, not a prop)
4. Inspector panel shows category name from new enum

**Prop JSON format (unchanged structure, new category values):**
```json
{
  "type": "thornwood_tree",
  "category": 0,
  "sub_hex_q": 1,
  "sub_hex_r": 0,
  "rotation": 45,
  "blocks_movement": false,
  "tool_required": "axe",
  "respawn_time": 60.0,
  "remaining": 5,
  "max_amount": 5
}
```

---

### 4. Origin System (New Field)

**What changed:** Props now have an `origin` field with 5 possible values:

| Index | Origin | Meaning |
|-------|--------|---------|
| 0 | Natural | Native planet resource |
| 1 | Crafted | Player-built |
| 2 | Human | Debris from crashed ship |
| 3 | Native Alien | Native to this planet |
| 4 | Unknown | Alien from elsewhere |

**Editor impact:**
- Prop inspector should show/edit Origin
- Prop placement could default to origin based on category:
  - Natural categories (0-5) → Origin: Natural (0)
  - Structure/Vehicle/Equipment/Storage → Origin: Crafted (1)
- Origin affects scan time multiplier (informational in editor)

**Required fix:** Add `origin` field to prop data in inspector panel and JSON export.
Default to 0 (Natural) if not set.

**Prop JSON with origin:**
```json
{
  "type": "alien_device",
  "category": 8,
  "origin": 4,
  "sub_hex_q": 0,
  "sub_hex_r": 0
}
```

---

### 5. Resource Source Yield Tables (New Data)

**What changed:** Resource Sources now have tool-dependent yield tables. The yield
determines what the player gets based on what tool they use.

**Editor impact:** Currently the editor doesn't manage yield data — it comes from
`PropRegistry` `.tres` files in the engine. The editor just places the type ID.

**Required fix:** No editor change needed for MVP. The type ID (`"thornwood_tree"`)
maps to a PropDef in the engine which contains the yield table. The editor only
needs to know valid type IDs for each category. A dropdown or autocomplete from a
type registry would be helpful but is not blocking.

---

## P2 — Nice-to-Have (improve editor UX)

### 6. Traversal Visualization

**What changed:** Walk diff 0-2, Jump diff 3-4, Blocked diff 5+

**Editor impact:** If the editor shows traversal overlays or path reachability:
- Update thresholds
- Walk (green) for diff ≤ 2
- Jump (yellow) for diff 3-4
- Blocked (red) for diff ≥ 5

---

### 7. tool_required and respawn_time Defaults

**What changed:** The game engine now falls back to `PropRegistry` defaults when
these fields are not present in the map JSON. The editor doesn't need to explicitly
save them unless the map designer wants to override the registry default.

**Editor impact:** Prop inspector could show "(default from registry)" for these fields
when not explicitly set, and allow override. Low priority.

---

### 8. Two-Tier Scanning Display

**What changed:** Props have Scanned/Identified tiers with derived Anomaly state.

**Editor impact:** The editor could show scan-tier info in the prop inspector. However,
scan state is runtime-only (stored in save file, not level JSON), so this is
informational only. Low priority.

---

## Reference Files

| File | Description |
|------|-------------|
| `docs/design/game-mechanics-redesign-2026-04-06.md` | Full design doc with all decisions |
| `scripts/hex/hex_math.gd` | `HEX_SIZE`, `SUB_HEX_SIZE` constants |
| `scripts/hex/hex_grid.gd` | `WALK_MAX_DIFF=2`, `JUMP_MAX_DIFF=4`, traversal logic |
| `scripts/hex/prop.gd` | Prop resource class (category, origin, type, etc.) |
| `scripts/hex/map_loader.gd` | Map JSON parser, elevation clamp, prop loading |
| `data/resources/*.tres` | PropDef files with tool_required, respawn, yields |
| `.aid/knowledge/data-model.md` | Data model documentation |

---

*Compiled: 2026-04-07 by Lola*
*Source: delivery-004b changes merged to main*
