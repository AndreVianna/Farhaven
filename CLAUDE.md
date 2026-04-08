# Farhaven

<!-- AID-DISCOVER project-description -->
Crash-land on an alien planet. Explore hex tiles, gather, craft, build, survive, escape.
<!-- /AID-DISCOVER -->

## Project Overview
<!-- AID-DISCOVER project-overview -->
Monolithic Godot 4.6 single-player mobile game (portrait, 1080x1920). GDScript with static typing throughout. Scene-tree architecture with signal-driven communication. Two autoload singletons: HexGrid (world state) and PropRegistry (resource definitions). Targets Android and iOS (no export presets configured yet). 5,519 lines source code across 13 modules, 9,594 lines test code (gdUnit4 v6.0.3).
<!-- /AID-DISCOVER -->

## Build & Test
<!-- AID-DISCOVER build-test -->
- **Run game:** Open in Godot 4.6 editor → F5 (main scene: `scenes/main.tscn`)
- **Run all tests:** Godot editor → gdUnit4 panel → Run All, or CLI: `godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/`
- **Run specific test:** `godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add tests/unit/test_hex_math.gd`
- **No CI/CD pipeline exists yet**
- **No export presets configured** — mobile builds not yet produced
<!-- /AID-DISCOVER -->

## Code Conventions
<!-- AID-DISCOVER code-conventions -->
- **Files:** snake_case (`hex_grid.gd`, `player_input.gd`). Tests prefixed `test_`
- **Classes:** PascalCase class_name (`HexMath`, `HexTile`, `PlayerInput`)
- **Variables/functions:** snake_case. Constants UPPER_SNAKE_CASE. Signals snake_case
- **Identifiers:** Use StringName literals (`&"identifier"`)
- **Static typing:** Required everywhere (`: Type`, `-> void`)
- **Error handling:** `push_warning()`/`push_error()` with null guards and early returns
- **DI pattern:** Nullable fields with autoload fallback (`_grid: HexGrid` set in `_ready()` if null)
- **Signals over calls:** Systems communicate via signals, not direct method calls
- See .aid/knowledge/coding-standards.md for full details
<!-- /AID-DISCOVER -->

## Architecture
<!-- AID-DISCOVER architecture -->
- **Pattern:** Monolithic scene tree with component-based composition and signal-driven communication
- **Entry point:** `scripts/main.gd` — loads map, wires all subsystems
- **Autoloads:** HexGrid (world state singleton), PropRegistry (resource definitions)
- **Key modules:** Hex Grid Core, Player (input/pathfinding/camera), Inventory, Crafting, Scanner/Catalog, Auto-Interaction, HUD, Rendering, Audio, UI Panels
- **Data flow:** Map JSON → MapLoader → HexGrid → Renderer. Player input → Pathfinder → HexGrid → signals → all systems
- See .aid/knowledge/architecture.md for full details
<!-- /AID-DISCOVER -->

## Knowledge Base

After running Discovery, the Knowledge Base lives at .aid/knowledge/INDEX.md.
Read INDEX.md first for a map of all available documentation.

## Skills

AID methodology skills are installed in .claude/skills/.
Use them by describing the phase you want to execute.

## Agents

Specialist agents are available in .claude/agents/.

## Permissions

- Read any file in the project
- Write only within the project directory
- Run build and test commands
- Do NOT modify files outside the project root

## Conventions
- See .aid/knowledge/coding-standards.md for project-specific conventions

## AID Workspace

The `.aid/` directory contains the Knowledge Base and work artifacts.
Read `.aid/knowledge/INDEX.md` to find what you need.
