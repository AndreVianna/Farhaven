# Project Structure

> **Source:** discovery-scout
> **Status:** Active
> **Last Updated:** 2026-04-03

## Repository Overview

- **Repository:** https://github.com/AndreVianna/Farhaven.git (private)
- **VCS:** Git, hosted on GitHub
- **Current branch:** delivery-003 (off main)
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
+-- data/                          # Game data resources (19 files)
|   +-- biomes/                    # Biome definitions (.tres)
|   +-- catalog/                   # Catalog entries (.tres)
|   +-- maps/                      # Map definitions (.json)
+-- docs/                          # Design documentation (17 files)
|   +-- design/                    # Design system, mockups, redesigns
|   +-- references/                # Competitor analysis
+-- scenes/                        # Godot scene files (13 files)
|   +-- player/                    # Player scene
|   +-- ui/                        # UI panel scenes
|   +-- world/                     # World renderer scenes + scripts
+-- scripts/                       # GDScript source (32 .gd files)
|   +-- auto_interaction/          # Proximity-based auto-gather/scan
|   +-- crafting/                  # Crafting system
|   +-- hex/                       # Hex grid core (math, tiles, biomes, map loader)
|   +-- hud/                       # HUD elements (stat bars, notifications, floating text)
|   +-- inventory/                 # Inventory management
|   +-- player/                    # Player controller, camera, input, pathfinding
|   +-- rendering/                 # Visual renderers (resources, labels, scan progress)
|   +-- scanner/                   # Scanner/catalog system
+-- shaders/                       # GLSL shaders (3 files)
+-- tests/                         # Test suites (23 .gd files)
|   +-- integration/               # 3 delivery-level integration tests
|   +-- unit/                      # 20 unit test files
+-- ui/                            # UI scripts (8 .gd files)
+-- project.godot                  # Godot project configuration
+-- CLAUDE.md                      # Project instructions for Claude agents
+-- README.md                      # Project readme
+-- .gitignore                     # Git ignore rules
+-- icon.svg                       # App icon
```

## File Counts by Directory

| Directory | .gd files | .tscn files | .tres files | Other | Total |
|-----------|-----------|-------------|-------------|-------|-------|
| scripts/ | 32 | -- | -- | 32 .uid | 64 |
| scenes/ | 1 | 8 | -- | 1 .uid | 10 (+3 in world/) |
| ui/ | 8 | 1 | -- | 8 .uid | 17 |
| tests/ | 23 | -- | -- | 23 .uid | 46 |
| data/ | -- | -- | 18 | 1 .json | 19 |
| shaders/ | -- | -- | -- | 3 .gdshader + 3 .uid | 6 |
| docs/ | -- | -- | -- | 13 .md + 3 .png + 1 .import | 17 |
| addons/ | 900+ | -- | -- | misc | 934 |

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
| `scripts/data/resource_registry.gd` | Autoload singleton (`ResourceRegistry`) -- indexes all ResourceDef files | `project.godot` line 25: autoload declaration |
| `scripts/hex/hex_grid.gd` | Autoload singleton (`HexGrid`) -- map container, fog of war, resource state | `project.godot` line 26: autoload declaration |

### Scene Structure (from main.tscn)
- `Main` (Node) -- root, runs `main.gd`
  - `World` (Node3D) -- 3D game world
    - `HexGridRenderer` -- terrain rendering
    - `ResourceRenderer` -- resource prop rendering
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

### Shader Files
| File | Purpose |
|------|---------|
| `shaders/hex_tile.gdshader` | Hex tile terrain rendering with fog of war |
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

### Autoloads
- `ResourceRegistry` -- singleton, loaded from `scripts/data/resource_registry.gd` (project.godot line 25). Scans data/resources/ at startup and indexes all ResourceDef files.
- `HexGrid` -- singleton, loaded from `scripts/hex/hex_grid.gd` (project.godot line 26). Map container, stores tiles, manages fog of war and resource state.

### Editor Plugins
- gdUnit4 -- unit testing framework

## Unusual or Notable Structural Observations

1. **No `assets/` directory yet.** The README describes an `assets/` folder with models, textures, audio, fonts, and UI, but it does not exist. The game currently uses programmatic rendering (ArrayMesh, MultiMesh) rather than imported 3D models.

2. **Scripts split across two locations.** Most scripts are in `scripts/`, but `scenes/world/hex_grid_renderer.gd` lives alongside its scene file, and all UI scripts are in `ui/` rather than `scripts/ui/`.

3. **`.uid` files everywhere.** Godot 4.x generates UID tracking files alongside every .gd file. These are committed to the repository (not gitignored).

4. **No export presets.** No `export_presets.cfg` file exists, meaning no Android or iOS export configuration has been set up yet.

5. **No CI/CD pipeline.** No `.github/workflows/`, no `Jenkinsfile`, no `Makefile`, no build scripts of any kind.

6. **Heavy addon footprint.** The `addons/gdUnit4/` directory contains 934 files -- far more than the project's own source code (32 scripts + 8 UI scripts + 23 tests = 63 files).

7. **Map is hand-crafted, not procedural.** Despite the GDD mentioning procedural generation, `data/maps/ch1.json` is a hand-designed map loaded by `MapLoader`. The vision pivot moved to episodic chapters with designed maps.
