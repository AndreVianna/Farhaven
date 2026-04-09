> **SUPERSEDED:** This document is historical. The authoritative versions are `.aid/knowledge/game-mechanics.md` and `.aid/work-001-core/delivery-005a/DESIGN.md`.

# Game Mechanics Redesign — 2026-04-06

Decisions from design session with Andre. These supersede conflicting info in
`prop-taxonomy.md` and `scan-redesign-2026-04-02.md`.

---

## 1. Prop Category System

### Natural Categories (6)

| Category | Description | Examples |
|----------|-------------|----------|
| Plant | Flora, vegetation | Berry Bush, Thornwood Tree, Fiber Grass |
| Mineral | Rocks, ores, crystals | Stone Deposit, Iron Deposit, Crystal Formation |
| Animal | Fauna (hostile or passive) | Thornback, Shy Deer |
| Fungi | Mushrooms, molds | Glowcap, Spore Cluster |
| Liquid | Water, pools, streams | Fresh Water Pool, Acid Spring |
| Ooze | Living organic matter | Bioluminescent Jelly, Reactive Slime |

### Non-Natural Categories (4+)

| Category | Description | Interaction Model | Examples |
|----------|-------------|-------------------|----------|
| Structure | Buildings player can enter | Collision, interior, spawn point | Shelter, Building, Wall |
| Vehicle | Mobile transport | Movement, mobile inventory | Cart |
| Equipment | Interactive objects with UI | Interaction prompt + UI panel | Workbench, Campfire |
| Storage | Containers for items | Interaction + static inventory | Chest, Crate, Pile |

**Note:** More categories will be added as needed.

---

## 2. Origin System

### Origin Values (5)

| Origin | Meaning | Scan Time Multiplier |
|--------|---------|---------------------|
| Natural | Native planet resource | 1x (fast, current timing) |
| Crafted | Player-built | 0x (no scan needed) |
| Human | Debris from crashed ship | 5x |
| Native Alien | Native to this planet | 20x |
| Unknown | Alien from elsewhere | 50x |

### Origin Propagation

Origin propagates through the extraction/crafting chain until the material is
refined to a **base material** (wood, metal ingot, etc.), at which point origin
resets to Natural.

Examples:
- Alien Device → Alien Component (Origin: Alien) → Metal Ingot (Origin: Natural)
- Human Crate → Human Plank (Origin: Human) → Wood (Origin: Natural)

**Design intent:** Players choose between keeping alien/human materials for
special crafting recipes vs. breaking them down to generic materials.

---

## 3. Two-Tier Scanning System

### Tier 1: Long-Range Scan (Scanned)

- **Range:** What the player can see on a clear day
- **Reveals:** Origin only (Natural, Crafted, or Anomaly)
- **Does NOT reveal:** Category or details
- **Display:** Mini-map blips (implementation in future delivery)
- **Mechanism:** Automatic based on visibility

### Tier 2: Short-Range Scan (Identified)

- **Range:** Proximity (1 hex, as defined in scan-redesign)
- **Reveals:** Category + full details
- **Mechanism:** Auto-scan with progress bar (existing implementation)
- **Scan time depends on Origin** (see multipliers above)
- **Crafted props:** Skip scan entirely (player already knows)

### Anomaly (Derived State)

**Anomaly is NOT a category or origin — it is a derived state.**

```
is_anomaly = scanned AND NOT identified AND origin NOT IN [Natural, Crafted]
```

A prop is an Anomaly when:
1. It has been long-range scanned (player knows it exists)
2. It has NOT been short-range identified (category unknown)
3. Its true origin is non-Natural and non-Crafted

Once identified, the Anomaly state disappears and the true Origin is revealed
(Human, Native Alien, or Unknown).

### Prop Discovery States

| scanned | identified | Player Sees |
|---------|------------|-------------|
| false | false | Nothing (undiscovered) |
| true | false | Origin: Natural → "Natural resource" / Non-Natural → "Anomaly" |
| true | true | Full info: Category + Origin + details |

**In the save file / level JSON:** The prop always stores its real Origin.
The mystery is player-side only.

---

## 4. Resource Source vs Resource Item

### Resource Source (World Entity)

A prop in the game world that can be harvested/processed.

```
Resource Source:
  type: StringName           # e.g., "thornwood_tree"
  category: Category         # Plant, Mineral, etc.
  origin: Origin             # Natural, Human, Alien, Unknown
  scanned: bool
  identified: bool
  movable: bool              # Can be loaded onto Cart
  yield_table: YieldEntry[]  # What it produces (tool-dependent)
  remaining: int             # Depletion counter
  max_amount: int
  respawn_time: float        # 0 = no respawn
  tool_required: StringName  # Minimum tool to interact (optional)
```

### Resource Item (Inventory Entity)

What the player receives in their inventory after collection.

```
Resource Item:
  type: StringName           # e.g., "wood", "firewood"
  origin: Origin             # Inherited from source, resets at base material
  stack_size: float          # Implicit weight (slots consumed)
```

### Yield Table

Each Resource Source has a yield table mapping tool → result:

```
YieldEntry:
  tool: StringName           # "bare_hands", "survival_knife", "axe", "pickaxe"
  result_id: StringName      # What is produced
  is_source: bool            # true = new Source in world, false = Item in inventory
  amount: Vector2i           # min-max range
```

### Example Yield Tables

**Thornwood Tree (Plant, Natural):**

| Tool | Result | Type | Amount |
|------|--------|------|--------|
| bare_hands | twig | Item | 1-2 |
| survival_knife | wood | Item | 2-3 |
| axe | fallen_tree | Source | 1 |

**Fallen Tree (Plant, Natural, movable):**

| Tool | Result | Type | Amount |
|------|--------|------|--------|
| axe | log | Source | 1-2 |

**Log (Plant, Natural, movable):**

| Tool | Result | Type | Amount |
|------|--------|------|--------|
| axe | firewood | Item | 3-5 |

**Stone Deposit (Mineral, Natural, NOT movable):**

| Tool | Result | Type | Amount |
|------|--------|------|--------|
| bare_hands | — | — | nothing |
| pickaxe | pile_of_stones | Source | 1 |

**Pile of Stones (Mineral, Natural, movable):**

| Tool | Result | Type | Amount |
|------|--------|------|--------|
| pickaxe | stone | Item | 3-5 |

**Crystal Formation (Mineral, Natural, NOT movable):**

| Tool | Result | Type | Amount |
|------|--------|------|--------|
| bare_hands | — | — | nothing |
| survival_knife | crystal_shard | Item | 1-2 |
| pickaxe | crystal_lump | Item | 2-4 |

**Iron Deposit (Mineral, Natural, NOT movable):**

| Tool | Result | Type | Amount |
|------|--------|------|--------|
| bare_hands | — | — | nothing |
| survival_knife | — | — | nothing |
| pickaxe | ore_chunk | Item | 2-3 |

---

## 5. World Refinement Chains

Resource Sources can produce OTHER Resource Sources, creating multi-step
refinement in the world before items enter the inventory.

```
Tree + axe → Fallen Tree (Source, same hex/sub-hex)
Fallen Tree + axe → Log (Source, movable)
Log + axe → Firewood (Item → inventory)
```

**Key rule:** The new Resource Source spawns at the same hex + sub-hex position
as the original. The original is consumed/replaced.

### Movable Flag

| movable | Meaning | Examples |
|---------|---------|----------|
| true | Can be loaded onto Cart | Fallen Tree, Log, Pile of Stones |
| false | Fixed to terrain, process in place | Tree, Stone Deposit, Boulder, Iron Deposit |

**Cart integration:** Instead of processing everything in the field, players can
load movable Sources onto a Cart, transport to base, and process there with
better tools/comfort. This makes the Cart essential for efficient gathering.

---

## 6. Inventory System (Slot-Based)

No weight mechanic. Stack size IS the implicit weight.

| Item | Slots | Rationale |
|------|-------|-----------|
| Berries | ~0 (many per slot) | Tiny, light |
| Twig | ~0 | Tiny |
| Crystal Shard | 0.5 | Small |
| Stone | 1 | Medium |
| Wood | 1 | Medium |
| Firewood | 2 | Bulky |
| Ore Chunk | 2 | Heavy |
| Crystal Lump | 3 | Bulky + fragile |

**Storage tiers:**
- Backpack: 12 slots
- Chest: 12 slots (static, craftable)
- Specialized Pile: for heavy items
- Cart: 50 slots (mobile, movement speed penalty)

Items that don't fit in inventory (Log, Fallen Tree, Boulder) remain as
Resource Sources in the world — only movable via Cart.

---

## 7. Interaction with Existing Systems

### Catalog / Scanner

The existing 3-state system (UNKNOWN → ENCOUNTERED → CATALOGED) maps to:

| Old State | New Equivalent |
|-----------|---------------|
| UNKNOWN | NOT scanned |
| ENCOUNTERED | Scanned but NOT identified (fauna only — via first combat) |
| CATALOGED | Identified |

The Catalog UI will need to display:
- Anomaly entries (scanned, not identified, non-Natural)
- Origin information once identified
- Category-based grouping

### Save File / Level JSON

Props in JSON always store the real Origin. Scanned/Identified are runtime
state saved per-prop in the save file (not in the level definition).

### Enum Changes Needed (Code)

Current `Prop.Category` enum: `RESOURCE, STRUCTURE, ANOMALY`

New enum values needed:
```gdscript
enum Category {
    PLANT, MINERAL, ANIMAL, FUNGI, LIQUID, OOZE,
    STRUCTURE, VEHICLE, EQUIPMENT, STORAGE,
}

enum Origin {
    NATURAL, CRAFTED, HUMAN, NATIVE_ALIEN, UNKNOWN,
}
```

SPAWN removed from props — it's level metadata, not a prop type.

---

## 8. Open Questions (For Future Sessions)

1. How do Liquid and Ooze categories work as Resource Sources?
   (Collection mechanics — bucket? container?)
2. Animal as Resource Source — hunting yields? (meat, hide, bone)
3. Fungi collection — bare hands or tool? Spore hazard?
4. What specific Alien/Human props exist on the planet?
5. Equipment category details — what equipment types beyond Workbench/Campfire?
6. How does the Cart movement work? Auto-follow? Direct control?
7. Crafting recipes that use origin-specific materials (Alien Metal recipes?)
8. How do these changes map to the delivery roadmap?

---

*Decided: 2026-04-06 by Andre and Lola*
*Supersedes: prop-taxonomy.md (partially), scan-redesign-2026-04-02.md (partially)*
