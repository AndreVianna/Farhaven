# Integration Map

> **Source:** discovery-integrator
> **Status:** Active
> **Last Updated:** 2026-04-03

Farhaven is a 100% offline single-player mobile game with no network calls, no backend, no analytics, no ads, and no IAP. There are no external service integrations. This document covers engine-level integrations and the planned (but not yet configured) platform export targets.

## Message Queues / Event Buses

**None.** Farhaven uses Godot's built-in signal system (observer pattern) for all inter-system communication. There are no message queues, event buses, or pub/sub systems beyond Godot signals. See `api-contracts.md` for the complete signal flow.

## Caches

**None.** There are no caching layers. All game data is held in memory:
- Hex grid tiles: `HexGrid._tiles` Dictionary (Vector2i -> HexTile). Source: `scripts/hex/hex_grid.gd`
- Resource definitions: `ResourceRegistry._defs` Dictionary (StringName -> ResourceDef). Source: `scripts/data/resource_registry.gd`
- Catalog entries: `Catalog._all_entries` Dictionary (StringName -> CatalogEntry). Source: `scripts/scanner/catalog.gd`
- Biome data: loaded at startup and held in arrays by HexGridRenderer and MapLoader. Source: `scenes/world/hex_grid_renderer.gd`, `scripts/hex/map_loader.gd`

## Webhooks

**None.** No incoming or outgoing webhooks. The game is entirely offline.

## Third-Party Services

**None in code.** The game collects no data, makes no network calls, and has no third-party SDK integrations.

## Feature Flags

**None.** No feature flag system. Game behavior is controlled entirely by code constants and data files.

---

## Godot Engine Integration

### Autoload System
Two autoload singletons registered in `project.godot` (lines 25-26):
1. `ResourceRegistry` -> `scripts/data/resource_registry.gd` (loaded first)
2. `HexGrid` -> `scripts/hex/hex_grid.gd` (loaded second, depends on ResourceRegistry)

### Rendering Pipeline
- **Renderer:** Mobile (Vulkan-based). Source: `project.godot` line 49
- **Texture compression:** ETC2/ASTC enabled for Android/iOS. Source: `project.godot` line 50
- **Custom shaders (3):**
  - `shaders/hex_tile.gdshader` -- hex terrain with fog of war via vertex colors
  - `shaders/icon_billboard.gdshader` -- billboard icons for resource props
  - `shaders/scan_progress.gdshader` -- scan progress bar overlay
- **Rendering approach:** Programmatic meshes (ArrayMesh for terrain, MultiMesh for props). No imported 3D models yet.

### Input System
- Touch emulation from mouse enabled for desktop testing. Source: `project.godot` line 45
- Raw touch event handling (InputEventScreenTouch, InputEventScreenDrag) in `scripts/player/player_input.gd`
- No Godot input actions defined -- all input is processed directly

### Audio System
- Audio stubs created (AudioStreamPlayer nodes for gather ding and craft success). Source: `scripts/audio/gather_sound.gd`
- No audio assets loaded yet -- AudioStream resources are null
- Uses Master audio bus (default)

### Data Loading
- JSON map loading via FileAccess + JSON.parse_string(). Source: `scripts/hex/map_loader.gd`
- Godot Resource (.tres) files for biome data, catalog entries, and resource definitions. Loaded via load() / preload()
- Resource definitions auto-scanned from `data/resources/` directory at startup. Source: `scripts/data/resource_registry.gd`

### Save/Load System
- Serialization methods exist on Player, HexGrid, Inventory, Catalog, and CraftingSystem (get_save_data / load_save_data)
- No actual save-to-disk implementation yet -- the serialization API is built but not wired to file I/O

---

## Addon: gdUnit4

- **Version:** 6.0.3
- **Purpose:** Unit and integration testing framework
- **Integration:** Editor plugin registered in `project.godot` line 41
- **Location:** `addons/gdUnit4/` (934 files)
- **Usage:** 20 unit test files + 3 integration test files in `tests/`
- **Source:** `addons/gdUnit4/plugin.cfg`

---

## Platform Export Targets (Planned, Not Configured)

### Android
- **Status:** No export_presets.cfg exists. Export not configured.
- **Target:** API 26+ (Android 8.0) per GDD. Google Play Store requires API 34+.
- **Requirements:** Android SDK, JDK 17, debug/release keystores
- **Notes:** Mobile renderer may limit device compatibility vs Compatibility renderer. See `external-sources.md` Source 4.
- **Credentials:** No keystores in repository. Will need to be created externally.

### iOS
- **Status:** No export_presets.cfg exists. Export not configured.
- **Target:** iOS 14+ per GDD
- **Requirements:** macOS with Xcode, Apple Developer account ($99/year)
- **Notes:** macOS availability unconfirmed ("Andre has a Mac?" noted in `docs/01-godot-engine-setup.md`). Cloud build (MacStadium/GitHub Actions) mentioned as alternative.
- **Credentials:** No provisioning profiles or signing certificates in repository.

---

## Stubbed Future Integrations

The following systems are referenced in code but do not exist yet:

| System | Referenced In | Reference Method | Purpose |
|--------|--------------|------------------|---------|
| FaunaManager | `scripts/auto_interaction/auto_interaction_system.gd:340` | get_node_or_null("/root/FaunaManager") | Fauna AI, movement, hostility queries |
| SurvivalSystem | `scripts/auto_interaction/auto_interaction_system.gd:392` | get_node_or_null("/root/SurvivalSystem") | Ground items, HP/hunger/thirst mechanics |
| BuildingSystem | `scripts/hud/hud.gd:40` | show_placement_label API comment | Structure placement on hex tiles |
| DayNightCycle | `scripts/player/player.gd:316` | Comment: "delivery-004 DayNightCycle takes over" | Day/night cycle, visibility source management |

These are graceful stubs -- they check for existence before use, so their absence causes no errors.

---

## Discrepancies: Documentation vs Code

1. **Renderer mismatch.** `docs/01-godot-engine-setup.md` recommends the Compatibility renderer for broadest device support. `project.godot` uses the Mobile renderer. These are different renderers with different GPU requirements. Source: `external-sources.md` Source 4.

2. **No CI/CD.** No build pipeline exists despite the project targeting mobile release. No GitHub Actions workflows, no Makefile, no build scripts.

3. **No export configuration.** Neither Android nor iOS export presets exist, despite both being primary target platforms per the GDD.
