# Research Report: Building Farhaven in Godot

**Date:** 2026-03-30
**Author:** Lola Lovelace

---

## 1. The C# vs GDScript Decision — ✅ RESOLVED

**Decision: GDScript** (Andre approved 2026-03-30)

### The Situation (as of Godot 4.6-stable — latest, late 2025)

**Godot C# mobile export is STILL labeled "experimental" in official docs.** The Godot 4.6 release notes (the most recent stable version) don't mention removing the experimental label from C#/Android/iOS. They DID remove the experimental label from Jolt Physics, but NOT from C# mobile.

The official Godot docs page (`tutorials/scripting/c_sharp/index.html`) — which is the **4.6 stable** docs — still says:
> "Android support is currently experimental."
> "iOS support is currently experimental and has a few limitations."

So this isn't old info. This is **current as of Godot 4.6-stable** (the latest version).

Specific issues still present in late 2025 / early 2026:

- **Android C# export:** Works but has known intermittent startup crash bugs
  - Issue #104721 (4.4.1-stable): Random crashes at startup — partially fixed via PR #105262
  - Issue #103915: Intermittent crashes on some devices
  - Issue #108805 (4.5): Broken export after upgrade
  - Issue #112397 (4.6-dev): All Android C# projects freeze then crash
  - Several games (Rift Riff, Kamaeru, Spooky Express) have shipped C# on Android but report ongoing crash issues

- **iOS C# export:** Requires NativeAOT, builds only on macOS with Xcode, uses trimming that can break reflection

- **Web export with C#:** NOT SUPPORTED. Period.

- Android C# uses `linux-bionic` runtime (Linux Mono, not real Android JNI) — some Android APIs will crash

### My Recommendation

**Use GDScript, not C#.** Here's why:

| Factor | C# | GDScript |
|--------|-----|---------|
| Mobile export | Experimental, crash bugs | Stable, production-proven |
| Community examples | Rare for mobile | Abundant |
| Performance | ~4× faster computation | Fast enough for our game |
| Andre's comfort | 34 years of C# | Zero GDScript |
| Tutorials/docs | Sparse for mobile | Extensive |
| Engine integration | Marshalling overhead | Native, zero overhead |
| Hot reload | Must recompile project | Instant |
| Asset Library plugins | Most are GDScript | Most are GDScript |

**The performance argument doesn't apply to us.** Farhaven is a casual mobile game with ~300 tiles, a few sprites, simple crafting logic. We're not doing physics simulations or real-time multiplayer. GDScript handles this trivially.

**The risk argument IS definitive.** Spending 2 months building a game in C# only to discover it crashes on 15% of Android devices at launch would kill our $2.99 monetization model — frustrated users leave 1-star reviews, conversion dies.

**The learning curve is real but short.** GDScript is Python-like. Andre will read it naturally. The biggest adjustment is Godot's node/scene architecture, which is the same regardless of language.

**UPDATE (2026-03-30):** Andre accepted GDScript without hesitation. Decision is final. ✅

---

## 2. Godot Version

**Use Godot 4.6-stable (latest).** Standard version (not .NET), since we're using GDScript.

Key features we'll use:
- TileMapLayer (new in 4.x, replaces old TileMap)
- 3D rendering with Compatibility renderer (for mobile performance)
- Built-in A* pathfinding
- AnimationPlayer/AnimationTree
- Export to Android (.apk/.aab) and iOS

---

## 3. Hex Grid Implementation

### The Bible: Red Blob Games

Amit Patel's guide (https://www.redblobgames.com/grids/hexagons/) is THE definitive reference. Updated through March 2025. Has code in C#, Python, JavaScript, C++, TypeScript.

### Coordinate System: Axial (q, r)

Use **axial coordinates** (q, r) for storage, calculate `s = -q - r` when algorithms need cube form. This is the sweet spot between simplicity and algorithm power.

```
     ___
    /   \
___/ 0,0 \___
   \     /   \
    \___/ 1,0 \
    /   \     /
   / 0,1 \___/
   \     /
    \___/
```

Why axial over offset:
- Vector operations (add, subtract, scale) work naturally
- Distance = `max(|dq|, |dr|, |ds|)` — one formula, no edge cases
- Neighbors are consistent (no even/odd column branching)
- Line drawing, range, pathfinding algorithms are all simpler

### Godot-Specific Hex Resources

1. **godot-gdhexgrid** (github.com/romlok/godot-gdhexgrid) — GDScript hex grid library. Pathfinding, LOS, neighbors, distances. Maps hex coords to Godot-space with +y flipped.

2. **Hexagon TileMapLayer** (Godot Asset Library #3733) — Set of tools for hexagon-based tilemaps in Godot with A* pathfinding and cube coordinates.

3. **josephmbustamante/Godot-3D-Hex-Grid-Tutorial** — 3D hex grid in Godot, Civ-style.

4. **jeremyz/godot-hexgrid** — Framework for hex map boardgames. Has distance, adjacents, 3D LOS, BFS reachable tiles, A* shortest path.

### My Recommendation for Our Hex System

**Build our own, using Red Blob Games algorithms.** The existing libraries are either Godot 3, GDScript-only, or strategy-game focused. Our survival game needs:

- Procedural generation (not pre-designed maps)
- Fog of war (reveal on adjacency)
- Per-tile biome data (resource types, hazards)
- Building placement on tiles
- Pathfinding for player AND night fauna

Architecture:
```
HexGrid (Node) — owns the grid data structure
├── HexTile (Resource) — biome, resources, fog state, building
├── HexRenderer (Node3D) — visual representation per tile
├── FogOfWar (system) — visibility calculations
└── Pathfinder (system) — A* on hex grid
```

---

## 4. Core Systems Architecture

### 4.1 Scene Tree Structure

```
Main (Node)
├── World (Node3D)
│   ├── HexGrid (Node3D) — generates & manages all tiles
│   ├── Player (CharacterBody3D)
│   ├── Structures (Node3D) — buildings placed by player
│   ├── Fauna (Node3D) — night creatures
│   └── Environment (Node3D) — sky, lighting, particles
├── UI (CanvasLayer)
│   ├── HUD — HP, hunger, thirst bars, day counter
│   ├── Inventory — grid-based pack
│   ├── CraftMenu — recipes and requirements
│   ├── ShipStatus — visual component checklist
│   └── Controls — joystick overlay
├── GameState (Node) — day/night cycle, save/load
└── AudioManager (Node)
```

### 4.2 Day/Night Cycle

Simple state machine:
```
DAY (3 min) → DUSK (30s warning) → NIGHT (1.5 min) → DAWN (transition) → DAY
```

Implementation:
- Timer-based, not real-time
- Dusk triggers UI warning (screen tint, sound)
- Night reduces visibility to 1 hex + torch range
- Night spawns fauna outside lit/walled areas
- Dawn despawns all fauna, resets visibility

### 4.3 Procedural Map Generation

1. Generate grid of ~250 hex tiles
2. Place crash site at center
3. Use noise-based biome assignment (Godot's FastNoiseLite)
4. Rules: water forms lakes (connected), ruins are sparse and far from center, volcanic is far
5. Scatter resources per biome type
6. Place Data Cores in 3 separate ruin clusters (for Nav Computer quest)
7. Validate: ensure all biomes are reachable, ensure enough resources for full game

### 4.4 Crafting System

Data-driven. Recipes in JSON/Resource:
```json
{
  "stone_axe": {
    "name": "Stone Axe",
    "requires": {"wood": 3, "stone": 2},
    "station": null,
    "unlocks": ["thick_trees"]
  },
  "furnace": {
    "name": "Furnace", 
    "requires": {"stone": 10, "ore": 5, "fiber": 3},
    "station": "workbench",
    "unlocks": ["smelting"]
  }
}
```

Keep the craft tree FLAT. Max 3 tiers deep. Nobody wants to manage supply chains in a casual game.

### 4.5 Controls

Dual control mode:
1. **Tap-to-move:** Raycast from touch → hex tile → A* pathfind → move
2. **Virtual joystick:** Dynamic position (appears where thumb touches lower half). Use Godot's `TouchScreenButton` or custom implementation.

Toggle in Settings. Default: tap-to-move.

### 4.6 Save System

Local JSON file per save slot:
- Player position, stats (HP, hunger, thirst)
- Grid state (explored tiles, placed buildings, gathered resources)  
- Inventory contents
- Ship components installed
- Day counter
- Crafting unlocks

Godot's `FileAccess` + JSON serialization. No cloud saves for v1.0.

---

## 5. Mobile Export Pipeline

### Android
1. Install Android SDK, OpenJDK (via Android Studio or standalone)
2. Set up debug keystore in Godot Editor → Editor Settings → Export → Android
3. Create export preset (Android)
4. Use **Compatibility** renderer (NOT Forward+ or Mobile — Compatibility is the most broadly supported)
5. Set minimum SDK to 26 (Android 8.0)
6. Target arm64 + x86_64
7. Export to .aab (Android App Bundle) for Play Store

### iOS
1. Requires macOS + Xcode (Andre has a Mac?)
2. Apple Developer Account ($99/year)
3. Export from Godot → Xcode project → build + submit
4. If no Mac: consider cloud-based macOS services (MacStadium, GitHub Actions with macOS runner)

### Performance Targets (Compatibility renderer)
- 60 FPS on mid-range (Snapdragon 600-series / A12+)
- 30 FPS on low-end (Snapdragon 400-series / A10)
- <200MB RAM
- <100MB APK
- Battery: should not overheat or drain noticeably

---

## 6. Estimated Development Timeline

| Phase | Duration | What |
|-------|----------|------|
| **Prototype** | 2 weeks | Hex grid + player movement + basic gathering |
| **Core Loop** | 2 weeks | Crafting, building, inventory, day/night |
| **Content** | 2 weeks | All biomes, full craft tree, ship repair |
| **Polish** | 2 weeks | UI, SFX, visual effects, tutorial |
| **Testing** | 1 week | Multi-device testing, balance, bugs |
| **Launch** | 1 week | Store assets, descriptions, submission |

**Total: ~10 weeks** to v1.0 if focused. Can overlap with Upwork work since most coding is agent-delegatable.

---

## 7. Key Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| C# mobile crashes | Critical | Use GDScript (recommended) |
| No Mac for iOS | Blocks iOS launch | Cloud build service or launch Android first |
| Art quality | Make or break | AI pipeline (see Report #2) |
| Scope creep | Delays launch | Strict MVP in GDD Section 13 |
| Planet curvature rendering | Nice-to-have blocker | Defer to post-launch; flat hex map is fine |
| Godot learning curve | 1-2 weeks | Andre knows C#; Godot concepts transfer from Unity experience; tutorials abundant |

---

## 8. Resources & Next Steps

### Must-Read
- Red Blob Games Hex Grids: https://www.redblobgames.com/grids/hexagons/
- Godot 3D Performance: https://docs.godotengine.org/en/latest/tutorials/performance/optimizing_3d_performance.html
- GDQuest First 3D Game: https://www.gdquest.com/library/first_3d_game_godot4_arena_fps/
- Godot Android Export: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html

### GitHub References
- godot-gdhexgrid: https://github.com/romlok/godot-gdhexgrid
- Godot 3D Hex Grid Tutorial: https://github.com/josephmbustamante/Godot-3D-Hex-Grid-Tutorial
- Hexagon TileMapLayer: https://godotengine.org/asset-library/asset/3733

### Install Plan
1. Download Godot 4.5-stable (standard, not .NET) — ~60MB
2. Install Android build tools (Android SDK, OpenJDK)
3. Create project: `Farhaven/`
4. Test empty scene export to Android device
5. Start hex grid prototype

---

*"Use the right tool for the job. For a casual mobile game, GDScript IS the right tool. Save C# for the server-side empire."*
