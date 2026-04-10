# Project Structure

> **Source:** discovery-scout
> **Status:** Active
> **Last Updated:** 2026-04-09 (updated for delivery-006a: Gear hierarchy, Events, IDs, SSH, mesh collision)

## Repository Overview

- **Repository:** https://github.com/AndreVianna/Farhaven.git (private)
- **VCS:** Git, hosted on GitHub
- **Current branch:** delivery-006a (off main)
- **Engine:** Godot 4.6-stable (standard edition, not .NET)
- **Language:** GDScript
- **Test framework:** gdUnit4 v6.0.3 (Godot addon)
- **License:** All rights reserved (private)
- **Authors:** Andre Vianna & Lola Lovelace (Casulo AI Labs)

## Directory Tree (Top 4 Levels)

```
Farhaven/
+-- .aid/                          # AID methodology workspace
|   +-- knowledge/                 # Knowledge base (18 documents)
|   +-- work-001-core/             # Active work package
|       +-- delivery-001/ .. 006/  # 6 delivery phases
|       +-- features/              # 12 feature specs + archived
+-- .claude/                       # Claude agent configuration
|   +-- agents/                    # 16 specialist agent definitions
|   +-- skills/                    # 9 AID skill definitions
|   +-- templates/                 # Document templates
+-- addons/                        # Godot addons
|   +-- gdUnit4/                   # Unit testing framework (934 files)
+-- data/                          # Game data resources (76 .tres + 1 .json)
|   +-- biomes/                    # BiomeData .tres (5 biomes)
|   +-- catalog/                   # CatalogEntry .tres (4 files: anomalies, fauna, flora, minerals)
|   +-- events/                    # GameEvent .tres (12 discovery events, E-prefixed) — added delivery-006a
|   +-- maps/                      # Map definitions (.json)
|   +-- props/                     # PropDef .tres (32 files, P-prefixed)
|   +-- recipes/                   # Recipe .tres (26 files, R-prefixed)
+-- docs/                          # Design documentation (17 files)
|   +-- design/                    # Design system, mockups, redesigns
|   +-- references/                # Competitor analysis
+-- scenes/                        # Godot scene files (13 files)
|   +-- player/                    # Player scene
|   +-- ui/                        # UI panel scenes
|   +-- world/                     # World renderer scenes + scripts
+-- scripts/                       # GDScript source (66 .gd files)
|   +-- auto_interaction/          # Proximity-based auto-gather (delegates to RecipeRuntime)
|   +-- building/                  # Building system: placement (SSH snap + collision) + structure renderer
|   +-- core/                      # Gear hierarchy + Event system + CollisionHelper — added delivery-006a
|   +-- crafting/                  # Legacy crafting system
|   +-- data/                      # PropDef (extends Gear) + PropRegistry
|   |   +-- capabilities/          # Capability Resources (7 files) — added delivery-005a
|   +-- hex/                       # Hex grid core (math incl. SSH, tiles, biomes, map loader)
|   +-- hud/                       # HUD elements (stat bars, notifications, floating text)
|   +-- inventory/                 # Weight-based inventory management
|   +-- lighting/                  # LightingManager autoload — added delivery-005a
|   +-- player/                    # Player controller, camera, input, pathfinding
|   +-- recipes/                   # Recipe system (11 files, Recipe extends ScriptBase) — added delivery-005a, refactored 006a
|   +-- rendering/                 # Visual renderers (resources, labels, scan progress)
|   +-- scanner/                   # Scanner/catalog system
+-- shaders/                       # GLSL shaders (3 files)
+-- tests/                         # Test suites (41 .gd files)
|   +-- integration/               # Delivery-level integration tests
|   +-- unit/                      # Unit test files
+-- ui/                            # UI scripts (13 .gd files)
+-- project.godot                  # Godot project configuration
+-- CLAUDE.md                      # Project instructions for Claude agents
+-- README.md                      # Project readme
+-- .gitignore                     # Git ignore rules
+-- icon.svg                       # App icon
```

## File Counts by Directory

| Directory | .gd files | .tscn files | .tres files | Other | Total |
|-----------|-----------|-------------|-------------|-------|-------|
| scripts/ | 66 | -- | -- | ~66 .uid | ~132 |
| scenes/ | 1 | 15 | -- | 1 .uid | 17 |
| ui/ | 15 | 1 | -- | ~15 .uid | ~31 |
| tests/ | 98 | -- | -- | ~98 .uid | ~196 |
| data/ | -- | -- | 76 | 1 .json | 77 |
| shaders/ | -- | -- | -- | 3 .gdshader + 3 .uid | 6 |
| docs/ | -- | -- | -- | 13 .md + 3 .png + 1 .import | 17 |
| addons/ | 900+ | -- | -- | misc | 934 |

> File counts updated 2026-04-09 after delivery-006a. scripts/ grew to 66 (core/5 added, building/ added). data/ grew to 76 .tres (props=32 P-prefixed, recipes=26 R-prefixed, events=12 added, biomes=5, catalog=1). tests/ grew to 98.

## Key Files and Entry Points

### Project Configuration
| File | Purpose |
|------|---------|
| `project.godot` | Engine config: name, main scene, display settings, autoloads, renderer |
| `.gitignore` | Excludes .godot/, exports, IDE files, logs, test reports |

### Entry Points
| File | Role | Evidence |
|------|------|----------|
| `scenes/main.tscn` | Main scene (game start) | `project.godot` line 19: `run/main_scene` |
| `scripts/main.gd` | Bootstrap script -- wires all systems, loads map | Attached to main.tscn root node |
| `scripts/data/prop_registry.gd` | Autoload singleton (`PropRegistry`) -- indexes all PropDef files | `project.godot`: autoload declaration |
| `scripts/hex/hex_grid.gd` | Autoload singleton (`HexGrid`) -- map container, signal bus, resource state | `project.godot`: autoload declaration |
| `scripts/recipes/recipe_registry.gd` | Autoload singleton (`RecipeRegistry`) -- indexes all Recipe files | `project.godot`: autoload (added 005a) |
| `scripts/core/event_registry.gd` | Autoload singleton (`EventRegistry`) -- indexes all GameEvent files | `project.godot`: autoload (added 006a) |
| `scripts/recipes/recipe_runtime.gd` | Autoload singleton (`RecipeRuntime`) -- executes pending recipes | `project.godot`: autoload (added 005a) |

### Scene Structure (from main.tscn)
- `Main` (Node) -- root, runs `main.gd`
  - `World` (Node3D) -- 3D game world
    - `HexGridRenderer` -- terrain rendering
    - `PropRenderer` -- resource prop rendering
    - `PropLabelRenderer` -- label markers
    - `ScanProgressRenderer` -- scan progress overlay
    - `Player` (player.tscn) -- player character with sub-systems
  - `HUD` -- UI overlay layer
    - `HUD` (hud.tscn) -- stat bars, panels, notifications

### Data Files
| File | Format | Purpose |
|------|--------|---------|
| `data/maps/ch1.json` | JSON | Chapter 1 map definition (tile positions, biomes, resources, structures) |
| `data/biomes/*.tres` | Godot Resource | Biome definitions (crash_site, forest, grassland, rocky, water) |
| `data/catalog/*.tres` | Godot Resource | Catalog entries (anomalies, fauna, flora, minerals) |
| `data/props/*.tres` | Godot Resource | PropDef definitions (32 files, P-prefixed: source props, items, structures, tools) |
| `data/recipes/*.tres` | Godot Resource | Recipe definitions (26 files, R-prefixed: gather, craft, cook, consume, passive) |
| `data/events/*.tres` | Godot Resource | GameEvent definitions (12 discovery events) — added delivery-006a |

### Shader Files
| File | Purpose |
|------|---------|
| `shaders/hex_tile.gdshader` | Hex tile terrain rendering with per-vertex color (fog of war removed; local lighting support added in delivery-005a) |
| `shaders/icon_billboard.gdshader` | Billboard icons for props |
| `shaders/scan_progress.gdshader` | Scan progress bar overlay |

### Documentation
| File | Content |
|------|---------|
| `docs/GDD.md` | Full Game Design Document -- mechanics, monetization, tech spec |
| `docs/01-godot-engine-setup.md` | Engine/language decision research (GDScript chosen over C#) |
| `docs/02-visual-assets-pipeline.md` | AI-generated 3D art pipeline research |
| `docs/story-bible.md` | Narrative lore, planet history, convoy backstory |
| `docs/vision-pivot-briefing.md` | Pivoted game identity -- episodic chapters, scanner as core mechanic |
| `docs/design/design-system.md` | "Warm Horizon" design system -- colors, typography, spacing |
| `docs/design/prop-taxonomy.md` | Prop categories: Decoration, Resource, Structure, Entity |
| `docs/design/scan-redesign-2026-04-02.md` | Scanner redesign -- proximity-based auto-scan |
| `docs/design/crash-landing-design.md` | Crash landing sequence design |
| `docs/design/scan-redesign-impact-audit.md` | Impact audit of scan redesign on existing features |
| `docs/references/my-little-universe.md` | Competitor analysis of My Little Universe |
| `docs/design/mockup-*.png` | UI mockups (HUD, catalog, inventory) |

## Project Configuration Details

### Display Settings (project.godot)
- Viewport: 1080x1920 (portrait, mobile-first)
- Stretch mode: viewport
- Orientation: portrait (handheld/orientation=1)
- Touch emulation from mouse enabled

### Rendering
- Renderer: `mobile` (Godot Mobile renderer)
- Texture compression: ETC2/ASTC enabled (for Android/iOS)

### Autoloads (9 singletons, loaded in order)
1. `PropRegistry` -- `scripts/data/prop_registry.gd` — indexes all PropDef files
2. `HexGrid` -- `scripts/hex/hex_grid.gd` — map container, tile queries, signal bus
3. `DayNightCycle` -- `scripts/day_night/day_night_cycle.gd` — time phase management
4. `LightingManager` -- `scripts/lighting/lighting_manager.gd` — local light tracking (added delivery-005a)
5. `RecipeRegistry` -- `scripts/recipes/recipe_registry.gd` — indexes all Recipe files (added delivery-005a)
6. `EventRegistry` -- `scripts/core/event_registry.gd` — indexes all GameEvent files (added delivery-006a)
7. `DiscoveryWatcher` -- `scripts/recipes/discovery_watcher.gd` — known-recipes list, watches events (added delivery-005a, rewritten 006a)
8. `RecipeRuntime` -- `scripts/recipes/recipe_runtime.gd` — recipe execution engine (added delivery-005a)
9. `SaveManager` -- `scripts/save/save_manager.gd` — game persistence

### Editor Plugins
- gdUnit4 -- unit testing framework

## Unusual or Notable Structural Observations

1. **No `assets/` directory yet.** The README describes an `assets/` folder with models, textures, audio, fonts, and UI, but it does not exist. The game currently uses programmatic rendering (ArrayMesh, MultiMesh) rather than imported 3D models.

2. **Scripts split across two locations.** Most scripts are in `scripts/`, but `scenes/world/hex_grid_renderer.gd` lives alongside its scene file, and all UI scripts are in `ui/` rather than `scripts/ui/`.

3. **`.uid` files everywhere.** Godot 4.x generates UID tracking files alongside every .gd file. These are committed to the repository (not gitignored).

4. **No export presets.** No `export_presets.cfg` file exists, meaning no Android or iOS export configuration has been set up yet.

5. **No CI/CD pipeline.** No `.github/workflows/`, no `Jenkinsfile`, no `Makefile`, no build scripts of any kind.

6. **Heavy addon footprint.** The `addons/gdUnit4/` directory contains 934 files -- more than the project's own source code (66 scripts + 15 UI scripts + 98 tests = 179 files).

7. **Map is hand-crafted, not procedural.** Despite the GDD mentioning procedural generation, `data/maps/ch1.json` is a hand-designed map loaded by `MapLoader`. The vision pivot moved to episodic chapters with designed maps.
