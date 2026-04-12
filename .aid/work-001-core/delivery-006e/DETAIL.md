# delivery-006e: Combat Runtime + Engine Cleanup

**Status:** Planning
**Created:** 2026-04-12
**Depends on:** delivery-006d (merged — engine stabilization docs + tests + BDD)
**Relation to delivery-006f (Grid Inventory):** Independent. Both can run in parallel. Combat weapons are just PropDefs with `supports_actions = [&"attack_*"]`; their inventory shapes are authored in 006f regardless of combat status.
**Cumulative state:** Combat pipeline exists. Fauna can attack and be killed. Structures can be destroyed. Player death loads save. Damage types and EnduranceCap multipliers work. Save-at-campfire is the death recovery model.

## Key design decisions (pinned from 2026-04-12 design conversation)

| # | Decision | Value |
|---|----------|-------|
| 1 | Damage type vocabulary | **Full enum** (PHYSICAL, FIRE, COLD, POISON, ELECTRIC, MAGIC) but only PHYSICAL active in Chapter 1 |
| 2a | Fauna death | Despawn + loot drop (PropDef yield) + `fauna_killed(id, pos, killer)` signal |
| 2b | Structure death | Same mechanism as fauna |
| 2c | Player death | **Save-based.** Auto-save at start of day. Manual save at campfires only (10 slots). Death = load most recent save. **Catalog + Journal persist across death** (knowledge survives). Inventory + position reset to save point. |
| 3 | Attack timing | **(q) Telegraph** with animation for all attacks (including unavoidable). Player auto-attacks are instant once in range. |
| 4a | Enemy UI | Floating damage numbers + **permanent HP bar** (no fade) + (sound + particles later) |
| 4b | Player UI | Floating damage numbers + existing HUD stat_bars + screen flash on hit + (sound + particles later) |
| 5 | Hostility logic | **(x) Auto-defend** via AutoInteractionSystem. **Free first attack** until fauna species reaches **ENCOUNTERED** in catalog (scanner proximity triggers ENCOUNTERED, after which auto_defend activates for that species). |
| 6 | Campfire = save point | Campfires gain "rest and save" interaction. Save is diegetic — character rests, memory consolidates. |

## Tasks — Combat Core

| # | Name | Type | Est. hours |
|---|------|------|-----------|
| 102 | DamageType enum + DamageEvent resource | IMPLEMENT | 1 |
| 103 | EnduranceCap damage pipeline (apply multipliers, subtract HP, death signal) | IMPLEMENT | 3 |
| 104 | CombatCap runtime — iterate attacks/defenses, fire damage events | IMPLEMENT | 3 |
| 105 | FaunaManager: fauna death → loot drop + despawn + signal | IMPLEMENT | 3 |
| 106 | Auto-defend integration + free-first-attack-until-ENCOUNTERED caveat | IMPLEMENT | 3 |
| 107 | Attack telegraph animation stub (delay before damage applies) | IMPLEMENT | 2 |
| 108 | Floating damage numbers (FloatingCombatText scene) | IMPLEMENT | 2 |
| 109 | Enemy HP bar (permanent, world-space or HUD overlay) | IMPLEMENT | 3 |
| 110 | Screen flash on player hit | IMPLEMENT | 1 |
| 111 | Player death → load save | IMPLEMENT | 2 |
| 112 | Campfire save interaction (manual save at campfire) | IMPLEMENT | 3 |
| 113 | SaveManager: auto-save at start of day + schema_version field | IMPLEMENT | 2 |
| 114 | Unit tests: damage pipeline, EnduranceCap multipliers, death signals | TEST | 3 |
| 115 | BDD: combat integration scenarios (attack → damage → death → loot chain) | TEST | 4 |
| 116 | Contract doc updates (combat_cap.md, endurance_cap.md, fauna_manager.md, save_manager.md) | DOCS | 1 |

## Tasks — Engine Cleanup (from 006d task-088 backlog)

| # | Name | Type | Est. hours |
|---|------|------|-----------|
| 117 | Autoload coupling refactor: lazy `_get_autoload()` in 5 files | REFACTOR | 3 |
| 118 | CatalogableCap.scan_time: ScannerSystem reads the field | IMPLEMENT | 1 |
| 119 | PlaceableCap.footprint migration: add field, wire BuildingSystem | IMPLEMENT | 2 |
| 120 | LightingManager._registry typing: Node → broader, remove dead firestarter branch | FIX | 1 |
| 121 | Delete MovableCap + ContainerCap.accepts_filter (vapor caps) | DELETE | 1 |

**Estimated total: ~44 hours (combat ~36h + cleanup ~8h)**

---

## Task Details — Combat Core

### task-102: DamageType enum + DamageEvent

**DamageType enum** in a new file `scripts/combat/damage_type.gd`:
```
enum DamageType {
    PHYSICAL,
    FIRE,
    COLD,
    POISON,
    ELECTRIC,
    MAGIC,
}
```
Chapter 1 uses PHYSICAL only. Others exist for forward compatibility.

**DamageEvent** resource (or inner class) carrying:
- `damage_type: DamageType`
- `amount: int` (raw damage before multipliers)
- `source: Resource` (attacker PropDef or null for environmental)
- `attack_event: Resource` (the GameEvent that triggered this, for effect chaining)

---

### task-103: EnduranceCap damage pipeline

The core of combat. When a DamageEvent arrives at a target with EnduranceCap:

1. Look up `damage_type` in target's EnduranceCap:
   - `vulnerabilities.has(damage_type_name)` → **multiply by 2.0**
   - `resistances.has(damage_type_name)` → **multiply by 0.5**
   - `immunities.has(damage_type_name)` → **multiply by 0.0**
   - None of the above → multiply by 1.0
2. Final damage = `int(ceil(amount * multiplier))`
3. Subtract from `endurance.hp`
4. If `hp <= 0` → emit `died(entity_id: StringName)` signal

**Where does this live?** New `scripts/combat/damage_resolver.gd` — a static utility or autoload that takes (DamageEvent, target_propdef/endurance_cap) and returns the resolved damage + applies HP change.

---

### task-104: CombatCap runtime

Currently CombatCap has `attacks: Array[Resource]` and `defenses: Array[Resource]` (GameEvent arrays). Runtime:

- **Attack dispatch:** When fauna decides to attack (via BehaviorCap.reactions or contact damage), iterate `combat_cap.attacks`, fire each as a GameEvent via EventRegistry.try_fire. The GameEvent's effects include a new `deal_damage` effect kind that creates a DamageEvent targeting the player.
- **Defense dispatch:** When fauna takes damage, iterate `combat_cap.defenses`, fire applicable ones (e.g., "thorns" — on-hit retaliation). Same mechanism: GameEvent with `deal_damage` effect back at the attacker.

New effect kind: `deal_damage` with params `{damage_type: "PHYSICAL", amount: 10, target: "player"}` (or `target: "attacker"` for retaliation).

---

### task-105: FaunaManager death

When a fauna instance's EnduranceCap.hp reaches 0:

1. `died` signal fires
2. FaunaManager catches it
3. Loot drop: spawn `PropDef.yield_type` items on the death tile (reuse existing yield system from gather)
4. Despawn the fauna instance (remove from active pool, renderer cleanup)
5. Emit `fauna_killed(species_id, tile_pos, killer_ref)` signal for other systems (journal events, quest tracking)

If the fauna's PropDef has no yield_type, just despawn with no drop.

---

### task-106: Auto-defend + free first attack caveat

Update `scripts/auto_interaction/auto_interaction_system.gd`:

- When a hostile fauna enters proximity AND the species' catalog state is **ENCOUNTERED or CATALOGED**, trigger auto-defend (use best weapon from bag via `find_best_tool_for_action(&"attack_melee")`)
- When catalog state is **UNKNOWN**, do NOT auto-defend. The fauna gets a "free first attack."
- Scanner proximity → UNKNOWN → ENCOUNTERED transition happens via ScannerSystem. After that, auto-defend activates.
- This creates the "surprise encounter" pattern: new species surprises you once, then you're prepared.

**Edge case:** fauna that attacks player while UNKNOWN. The attack lands (free hit). Scanner detects the fauna in the same tick or next tick → ENCOUNTERED. From then on, auto-defend fires.

---

### task-107: Attack telegraph

Fauna attacks have a wind-up before damage applies:

- BehaviorCap triggers "intent to attack"
- Visual cue: brief animation (sprite flash, scale pulse, or orientation change toward player)
- After `attack_telegraph_duration` (0.3-0.5s), the actual DamageEvent fires
- Player who moves out of range during telegraph → attack misses (optional — could be auto-hit for simplicity in Chapter 1)

Player attacks are instant (auto-defend fires immediately when triggered).

**Implementation:** Tween-based delay between intent and damage, similar to gather timer pattern in AutoInteractionSystem.

---

### task-108: Floating damage numbers

New scene `scenes/ui/floating_combat_text.tscn`:

- Spawns at target position (world-space → screen-space)
- Shows "−15" (red for damage to player, white for damage to enemy)
- Rises upward, fades, despawns after ~1s
- FloatingTextManager already exists — extend it or create a combat-specific variant

---

### task-109: Enemy HP bar

When a fauna takes damage, show an HP bar:

- World-space billboard above the fauna (or HUD overlay near the fauna)
- **Permanent** (per Andre's design — doesn't fade after combat ends)
- Green → yellow → red color gradient based on HP ratio
- Shows after first damage, stays until despawn/death
- Uses same color logic as player stat_bars

---

### task-110: Screen flash on player hit

When player takes damage:

- Brief red tint overlay (0.2s)
- Camera shake (small — 2-3px, 0.15s)
- ScreenFade already exists (from day/night cycle) — can be reused for the red flash

---

### task-111: Player death → load save

When player HP <= 0:

1. Brief death screen (fade to black, "You fell..." text, 2s)
2. Load most recent save (auto-save from day start, or manual save from campfire)
3. Catalog + Journal state **persists** (knowledge survives death)
4. Inventory + position + world state reset to the save point
5. SaveManager needs a `load_game_preserving_knowledge()` variant that:
   - Loads the full save
   - Then re-applies current Journal unlocked entries + Catalog discovery states
   - This is the "groundhog day" mechanic — you know what you learned

---

### task-112: Campfire save interaction

Campfire PropDef gains a new interaction: "Rest and Save."

- When player approaches a campfire and interacts (auto-interaction or UI button)
- Opens a simple modal: "Save to slot X?" with slot picker (10 slots)
- Saves the full game state to the selected slot
- Visual feedback: campfire flames brighten briefly, "Saved" notification
- Campfire must have a specific tag (e.g., `&"SAVE_STATION"`) or a new capability that marks it as a save point

---

### task-113: SaveManager improvements

Two changes:

1. **Auto-save at start of day:** Hook into DayNightCycle.`day_started` signal → SaveManager.save_game() to a dedicated "auto" slot. Overwritten each day.

2. **schema_version field:** Add `schema_version: int = 1` to the save data root. On load, check version. If current > saved, apply migration or warn. If saved > current, warn and refuse (future save loaded in old code). This is critical before delivery-007 starts producing real content that players save.

Also address the `_SYSTEM_KEYS` hardcoded paths issue from 088 backlog: make the paths configurable or resolve them dynamically.

---

## Task Details — Engine Cleanup

### task-117: Autoload coupling refactor

Replace bare `PropRegistry` / `HexGrid` global identifier references with `_get_autoload()` lazy lookups in:

- `scripts/recipes/recipe_runtime.gd` lines 289, 367
- `scripts/recipes/predicate_evaluator.gd` lines 82, 238, 441
- `scripts/scanner/scanner_system.gd` lines 68, 209, 211
- `scripts/scanner/catalog.gd` line 50
- `scripts/day_night/day_night_cycle.gd` line 74

Pattern: add `var _prop_registry: Node = null` + populate in `_ready()` via `_get_autoload(&"PropRegistry")`. Replace bare refs with the cached field.

**Bonus validation:** after this lands, check if BDD scenarios can drop their MiniRuntime/MiniCatalog/snapshot shims and drive real production code. If yes, file a follow-up to simplify the step files.

---

### task-118: CatalogableCap.scan_time

ScannerSystem currently uses a hardcoded scan duration. Update to read `def.catalogable.scan_time` from the target PropDef's CatalogableCap. This makes scan duration a content-authorable value per prop — a crystal cluster might take longer to scan than a berry bush.

---

### task-119: PlaceableCap.footprint migration

Add `footprint: Vector2i` to PlaceableCap (default `Vector2i(1,1)` — single hex). Update BuildingSystem to read `prop_def.placeable.footprint` instead of the legacy `prop_def.footprint` field. Migrate any .tres files that set the top-level `footprint`. Remove the deprecated field from PropDef.

---

### task-120: LightingManager fixes

Two small fixes:
1. Change `_registry: Node` to a looser type or duck-typed pattern so BDD shims using RefCounted aren't rejected.
2. Remove the dead `&"firestarter"` tool slot check at line 186 — Inventory._tool_slots has no firestarter entry, and with tools-as-invoked (006f), tool slots are going away entirely.

---

### task-121: Delete vapor caps

Delete `scripts/data/capabilities/movable_cap.gd` + `.uid` (zero runtime consumers). Delete `ContainerCap.accepts_filter` field (never read at runtime — no insertion is rejected by it). Update PropDef to remove the `movable` field if it's just a vestigial reference. Update any .tres files that reference movable. Update the engine-contracts docs to reflect the removal.

---

## Exit criteria

- [ ] DamageType enum exists with 6 types
- [ ] EnduranceCap damage pipeline applies vuln/resist/immune multipliers correctly
- [ ] Fauna can be killed: HP reaches 0 → loot drop → despawn → signal
- [ ] Player death triggers save load with knowledge persistence
- [ ] Campfire save interaction works (10 manual slots + auto-save at day start)
- [ ] SaveManager has schema_version field
- [ ] Auto-defend fires for ENCOUNTERED species, not UNKNOWN
- [ ] Floating damage numbers + permanent enemy HP bar + screen flash work
- [ ] 5 autoload files refactored to lazy _get_autoload()
- [ ] Vapor caps deleted, scan_time/footprint wired
- [ ] Unit tests pass for damage pipeline
- [ ] BDD scenarios cover attack → damage → death → loot chain
- [ ] Andre play-tests and confirms combat feel (delivery-006g verification)
