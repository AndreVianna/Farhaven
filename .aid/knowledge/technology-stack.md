# Technology Stack

> **Source:** discovery-architect
> **Status:** Active
> **Last Updated:** 2026-04-03

## Languages

| Language | Version | Source |
|----------|---------|--------|
| GDScript | 4.6 | project.godot line 20: config/features=PackedStringArray("4.6", "Mobile") |
| Godot Shading Language (GLSL-like) | 4.6 | shaders/*.gdshader (3 files) |

GDScript is the sole programming language. No C#, C++/GDExtension, or VisualScript is used. The project uses static typing consistently (: Type annotations, -> void return types).

## Frameworks and Libraries

| Name | Version | Purpose | Source |
|------|---------|---------|--------|
| Godot Engine | 4.6-stable | Game engine (standard edition, not .NET) | project.godot line 20 |
| gdUnit4 | 6.0.3 | Unit and integration testing framework | addons/gdUnit4/plugin.cfg, project.godot line 41 |

No other third-party libraries or addons are used. All game systems (hex grid, inventory, crafting, scanner, rendering) are custom-built.

## Package Manager

Godot does not have a package manager. Dependencies are managed manually:
- gdUnit4 is installed directly in addons/gdUnit4/ (934 files committed to repository)
- No package.json, Cargo.toml, requirements.txt, or equivalent

## Runtime

| Runtime | Version | Detection |
|---------|---------|-----------|
| Godot Engine | 4.6-stable | project.godot config_version=5, features=PackedStringArray("4.6", "Mobile") |
| Mobile renderer | Vulkan-based | project.godot line 49: renderer/rendering_method="mobile" |

Target platforms (from docs/GDD.md and project.godot):
- **Android:** API 26+ (Android 8.0), arm64-v8a required. ETC2/ASTC texture compression enabled (project.godot line 50).
- **iOS:** iOS 14+, A10+ chips. Metal rendering.
- **Desktop:** Development/testing only. Touch emulated from mouse (project.godot line 45).

No export_presets.cfg exists -- neither Android nor iOS export has been configured yet.

## Build System

Godot uses its own built-in build system. There are no external build scripts (no Makefile, no CI/CD pipeline, no GitHub Actions).

### Build Commands
```bash
# Run the game in editor (requires Godot 4.6 installed)
godot --path . --run

# Export for Android (once export_presets.cfg is created)
godot --headless --export-release "Android" farhaven.apk

# Export for iOS (requires macOS + Xcode, once export_presets.cfg is created)
godot --headless --export-release "iOS" farhaven.xcodeproj
```

### Lint Commands
```bash
# No linter is configured.
# GDScript has no standard external linter equivalent to ESLint or Pylint.
# The Godot editor provides built-in syntax checking and warnings.
```

### Test Commands
```bash
# Run all gdUnit4 tests (requires Godot 4.6 with gdUnit4 addon)
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/

# Run a specific test file
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/unit/test_inventory.gd
```

## Development Tools

| Tool | Version | Config Location | Purpose |
|------|---------|-----------------|---------|
| gdUnit4 | 6.0.3 | addons/gdUnit4/plugin.cfg | Unit/integration testing |
| Godot Editor | 4.6-stable | project.godot | IDE, scene editor, script editor, debugger |

No external linters, formatters, or type checkers are configured. The Godot editor provides built-in:
- GDScript syntax validation
- Static type checking (when type annotations are present)
- Scene tree validation
- Shader compilation

## Display and Rendering Configuration

| Setting | Value | Source |
|---------|-------|--------|
| Viewport size | 1080x1920 (portrait) | project.godot lines 34-35 |
| Stretch mode | viewport | project.godot line 36 |
| Orientation | portrait (handheld/orientation=1) | project.godot line 37 |
| Renderer | mobile (Vulkan) | project.godot line 49 |
| Texture compression | ETC2/ASTC | project.godot line 50 |
| Touch emulation | Enabled (mouse -> touch) | project.godot line 45 |

## Data Formats

| Format | Location | Purpose |
|--------|----------|---------|
| .tres (Godot Resource) | data/biomes/, data/catalog/, data/props/ | Typed game data (BiomeData, CatalogEntry, ResourceDef) |
| .json | data/maps/ch1.json | Hand-designed map definition (tile positions, biomes, resources, structures) |
| .tscn (Godot Scene) | scenes/ | Scene tree definitions (text format, version controlled) |
| .gdshader | shaders/ | Custom vertex/fragment shaders |
| .gd | scripts/, ui/ | GDScript source files |
| .uid | alongside .gd and .tscn files | Godot 4.x UID tracking (committed to repo) |

## Decision: Renderer Choice

**Decided:** Compatibility renderer (OpenGL ES 3.0). project.godot currently uses "mobile" (Vulkan-based) but the confirmed decision is to switch to Compatibility for maximum device reach. Farhaven's aesthetic is intentionally simple (per-vertex color, placeholder meshes, no complex shaders) and does not require Vulkan capabilities. ⚠️ project.godot needs to be updated to `renderer/rendering_method="gl_compatibility"`.
