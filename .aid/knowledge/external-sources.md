# External Sources

> **Source:** discovery-scout
> **Status:** Active
> **Last Updated:** 2026-04-03

## Source 1: Red Blob Games -- Hexagonal Grids

- **URL:** https://www.redblobgames.com/grids/hexagons/
- **Type:** Technical reference / interactive tutorial
- **Author:** Amit Patel
- **Relevance:** PRIMARY -- the foundational reference for the hex grid system

### Content Inventory

#### Coordinate Systems
- **Offset coordinates:** Even/odd row or column offsets. Simpler for rectangular maps but awkward for algorithms (neighbors differ by parity). NOT used by Farhaven.
- **Cube coordinates (q, r, s):** Three axes with constraint q + r + s = 0. All hex algorithms are clean and uniform. Distance = max(|dq|, |dr|, |ds|).
- **Axial coordinates (q, r):** Two of the three cube axes (s is derived as -q-r). Best trade-off: compact storage, clean algorithms. USED BY FARHAVEN -- confirmed in `scripts/hex/hex_math.gd` and `docs/01-godot-engine-setup.md`.
- **Doubled coordinates:** Alternative offset scheme. Not used.

#### Hex Geometry
- **Pointy-top vs flat-top orientation.** Affects pixel-to-hex and hex-to-pixel conversions. Farhaven uses **flat-top** hexagons (confirmed by `scripts/hex/hex_math.gd` line 5: "Flat-top hexagon layout" and the conversion formula using `3.0/2.0 * q` for x, which is the flat-top formula).
- **Size and spacing formulas.** Hex width = 2 * size, height = sqrt(3) * size (flat-top). Center-to-center distances.
- **Hex-to-pixel conversion.** Matrix multiplication using orientation-specific constants.
- **Pixel-to-hex conversion (rounding).** Cube rounding algorithm: round all three cube coords, find the one with largest rounding error, recalculate from the other two. Critical for tap-to-move input.

#### Neighbors and Movement
- **Six neighbor directions.** For axial: the six direction vectors are (1,0), (1,-1), (0,-1), (-1,0), (-1,1), (0,1).
- **Distance calculation.** Manhattan distance in cube coordinates divided by 2, or equivalently max of absolute differences.
- **Line drawing.** Linear interpolation in cube coordinates with nudge to avoid ambiguity at hex boundaries.

#### Pathfinding
- **A* on hex grids.** Standard A* works with hex distance as heuristic. Farhaven implements this in `scripts/player/player_pathfinder.gd`.
- **Breadth-first search for reachable tiles.** Used for movement range, visibility range.
- **Movement costs per tile.** Supports weighted edges (different biome traversal costs).

#### Range and Field of View
- **Hex range (ring and spiral).** All hexes within N steps. Used for fog of war reveal radius.
- **Field of view / line of sight.** Ray casting along hex lines, checking for obstacles.

#### Regions and Map Storage
- **Map shapes:** Rectangular, hexagonal, triangular, rhombus. Farhaven uses irregular hand-designed maps.
- **Hash map storage.** Farhaven stores tiles in Dictionary keyed by Vector2i (axial coords) -- matches the recommended sparse map approach for irregular shapes.

### Discrepancies with Farhaven Code
- The guide covers procedural hex map generation extensively; Farhaven has pivoted to hand-designed maps loaded from JSON (`data/maps/ch1.json`).
- The guide discusses wrapping/toroidal hex maps; not applicable to Farhaven (finite bounded maps).
- The guide covers hex grid rotation and reflection; not currently used in Farhaven.

---

## Source 2: Godot 4.x Documentation (General)

- **URL:** https://docs.godotengine.org/en/stable/
- **Type:** Official engine documentation
- **Relevance:** REFERENCE -- engine API and architecture

### Content Inventory

#### Scene System and Nodes
- **Scene tree architecture.** Godot uses a tree of Nodes. Each node has a type, children, and scripts. Farhaven follows this pattern with Main > World > Player hierarchy.
- **Autoloads (singletons).** Global nodes accessible from any script. Farhaven uses two autoloads: `PropRegistry` (`project.godot` line 25) and `HexGrid` (`project.godot` line 26).
- **Node lifecycle:** `_ready()`, `_process()`, `_physics_process()`, `_enter_tree()`, `_exit_tree()`. The `_ready()` ordering (children before parents) caused the inventory initialization bug fixed in commit 14b7eb4.
- **Signals.** Godot's observer pattern. Farhaven uses signals extensively for decoupling (tile_revealed, auto_gather_completed, etc.).

#### 3D Rendering
- **Rendering methods:** Forward+, Mobile, Compatibility. Farhaven uses `mobile` renderer (`project.godot` line 49). Decision: switch to Compatibility for maximum device reach.
- **MeshInstance3D, ArrayMesh, MultiMesh.** Farhaven uses ArrayMesh for terrain (single draw call) and MultiMesh for resource rendering.
- **Shaders (Godot Shading Language).** GLSL-like, with vertex/fragment functions. Three custom shaders in `shaders/`.
- **Camera3D.** Player camera in `scripts/player/player_camera.gd`.

#### Input Handling
- **Touch input.** `InputEventScreenTouch`, `InputEventScreenDrag`. Farhaven emulates touch from mouse (`project.godot` line 45).
- **Input mapping.** Godot action system. Farhaven handles raw touch events directly in `scripts/player/player_input.gd`.

#### Resources and Data
- **Resource (.tres) files.** Custom data containers. Farhaven uses them for biome definitions and catalog entries.
- **JSON loading.** Via `FileAccess` + `JSON.parse_string()`. Used by `scripts/hex/map_loader.gd`.

#### Export and Mobile
- **Export presets.** Configured via `export_presets.cfg`. Farhaven has NOT created this file yet.
- **Android export requirements.** Android SDK, debug keystore, JDK. Documented in `docs/01-godot-engine-setup.md`.
- **iOS export requirements.** macOS + Xcode required. Apple Developer account needed.

#### Testing
- **No built-in test framework.** Godot relies on community addons. Farhaven uses gdUnit4.

### Discrepancies with Farhaven Code
- `project.godot` sets renderer to `mobile` but `docs/01-godot-engine-setup.md` recommends `Compatibility` renderer for broadest device support. These are different renderers -- `mobile` is higher quality but less compatible than `Compatibility`.
- The docs recommend using Godot's built-in TileMapLayer for 2D hex grids; Farhaven builds a custom 3D hex system instead (appropriate for its 3D rendering approach).

---

## Source 3: GDScript Reference

- **URL:** https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/
- **Type:** Language reference
- **Relevance:** REFERENCE -- primary development language

### Content Inventory

#### Language Fundamentals
- **Python-like syntax.** Indentation-based, dynamically typed with optional static typing.
- **Static typing.** Supported via `: Type` annotations. Farhaven uses static typing consistently (e.g., `var _tiles: Dictionary = {}`, `func _ready() -> void:`).
- **Built-in types.** Vector2, Vector2i, Vector3, Dictionary, Array, StringName, etc. Farhaven uses Vector2i for hex coordinates, StringName for resource types.

#### Object-Oriented Features
- **Inheritance via `extends`.** Every script extends a Node type. Farhaven scripts extend Node, Node3D, Control, etc.
- **`class_name` registration.** Registers a class globally. Farhaven uses class_name in 30 of 41 source files. The 11 exceptions (autoloads, bootstrap, some renderers) use `preload()` instead (noted in hex_grid.gd: "Uses preload because autoloads initialize before class_name registration").
- **Signals.** Declared with `signal` keyword. Custom signals used throughout.
- **`@export` annotation.** Exposes variables to the editor. Used in scene configuration.
- **`@onready` annotation.** Defers initialization until node is in the tree.

#### Coroutines and Async
- **`await` keyword.** For signal-based async. Used with timers and animation completion.
- **`call_deferred()`.** Schedules a call for the next idle frame. Used in `main.gd` for bootstrap timing.

#### Performance Considerations
- **GDScript is interpreted** (with some JIT in 4.x). Not as fast as C#/C++, but sufficient for Farhaven's scale (~300 tiles, no physics simulation).
- **Typed arrays.** `Array[Type]` for better performance and type safety. Used in Farhaven (e.g., `Array[StringName]`).

### Discrepancies with Farhaven Code
- None significant. The codebase follows standard GDScript patterns consistently.

---

## Source 4: Godot Android Export Guidelines

- **URL:** https://docs.godotengine.org/en/stable/tutorials/platform/android/
- **Type:** Platform-specific export guide
- **Relevance:** CRITICAL -- primary target platform

### Content Inventory

#### Setup Requirements
- **Android SDK.** Minimum API level 21 (Android 5.0), but Farhaven targets API 26 (Android 8.0) per GDD.
- **JDK.** OpenJDK 17 recommended for Godot 4.x.
- **Debug keystore.** Required for development builds. Generated automatically or manually.
- **Release keystore.** Required for Play Store submission. Must be created and stored securely.

#### Export Configuration
- **Export presets.** Defined in `export_presets.cfg`. Includes package name, version, permissions, icons, splash screen.
- **Architectures.** arm64-v8a (required for Play Store), armeabi-v7a (optional for older devices), x86_64 (emulators).
- **Output formats.** APK (direct install/testing), AAB (Android App Bundle, required for Play Store).

#### Rendering Considerations
- **Vulkan (Forward+ / Mobile).** Better visuals but requires Vulkan-capable devices. Farhaven uses Mobile renderer.
- **OpenGL (Compatibility).** Broadest support including older devices. docs/01-godot-engine-setup.md recommends this but project.godot uses Mobile.
- **ETC2/ASTC texture compression.** Enabled in project.godot. Required for OpenGL ES 3.0+ devices.

#### Performance and Optimization
- **Reducing draw calls.** Batch rendering, instancing. Farhaven addresses this with ArrayMesh and MultiMesh.
- **Memory management.** Target <200MB RAM usage per GDD.
- **APK size.** Target <100MB per GDD. Possible with low-poly art + compressed textures.

#### Play Store Requirements
- **Target SDK version.** Google requires targeting recent API levels (currently API 34+).
- **64-bit requirement.** arm64-v8a is mandatory.
- **App Bundle format.** AAB required for new apps since 2021.
- **Data safety section.** Must declare data collection practices. Farhaven collects no data (100% offline per GDD).

### Discrepancies with Farhaven Code
- **No export_presets.cfg exists.** Android export has not been configured.
- **Renderer mismatch.** Research doc recommends Compatibility renderer; project uses Mobile renderer. This affects which Android devices can run the game.

---

## Source 5: Godot iOS Export Guidelines

- **URL:** https://docs.godotengine.org/en/stable/tutorials/platform/ios/
- **Type:** Platform-specific export guide
- **Relevance:** CRITICAL -- secondary target platform

### Content Inventory

#### Setup Requirements
- **macOS required.** iOS builds can ONLY be created on macOS with Xcode installed.
- **Apple Developer Account.** $99/year. Required for device testing and App Store submission.
- **Xcode.** Latest stable version recommended. Includes iOS SDK, simulators, code signing tools.
- **Provisioning profiles.** Development and distribution profiles needed. Managed via Apple Developer portal.

#### Export Workflow
1. Configure export preset in Godot (bundle identifier, version, icons, launch screen).
2. Export from Godot generates an Xcode project.
3. Open in Xcode, configure signing, build, and submit.
- **No direct IPA export.** Must go through Xcode.

#### iOS-Specific Considerations
- **App Store guidelines.** Review process can reject apps for various reasons. Monetization model (demo + unlock) is allowed.
- **Minimum iOS version.** Farhaven targets iOS 14+ per GDD.
- **Metal rendering.** iOS uses Metal API. Forward+ and Mobile renderers both support Metal.
- **Touch handling.** iOS touch events map to Godot's InputEventScreenTouch.

#### Performance
- **A-series chip targets.** A12+ for 60 FPS, A10 for 30 FPS (per GDD).
- **Memory constraints.** iOS is stricter about memory than Android. <200MB target is appropriate.
- **Battery and thermal.** iOS throttles aggressively. Low-poly approach helps.

### Discrepancies with Farhaven Code
- **No macOS build environment confirmed.** docs/01-godot-engine-setup.md raises this as a question: "Andre has a Mac?"
- **No export_presets.cfg for iOS.** No iOS export configuration exists.
- **Cloud build alternative.** Research doc mentions MacStadium or GitHub Actions macOS runners as alternatives if no physical Mac is available.

---

## Cross-Source Analysis

### Confirmed Alignment
- Axial hex coordinates (Red Blob Games recommended, Farhaven implements)
- GDScript as language choice (Godot docs confirm best mobile support)
- Touch-based input handling (both Android and iOS docs support Godot's approach)
- Low-poly 3D with custom shaders (Godot rendering docs support this architecture)

### Unresolved Gaps
1. **Renderer choice.** Mobile vs Compatibility renderer has real device compatibility implications. The research doc and project config disagree.
2. **iOS build environment.** No confirmed macOS access for iOS builds.
3. **Export configuration.** Neither platform has export presets configured.
4. **Target API levels.** Google Play Store requirements evolve; the GDD's API 26 minimum may need updating to meet current store requirements.
