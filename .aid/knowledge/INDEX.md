# Knowledge Base Index -- Farhaven

Use this index to find the right document before making assumptions.
If your task touches an area covered here, read the relevant document first.

## Active Work

- **work-001-core** -- Core MVP (hex grid, movement, gathering, crafting, survival, day/night, building/threats). 12 features (14 functional requirements), approved.
- **work-002-level-editor** -- Web-based game data editor (map, resource, biome). 9 features, approved.

| Document | Summary |
|----------|---------|
| project-structure.md | Repository layout, directory tree (4 levels), file counts (63 project scripts, 934 addon files, 23 tests), entry points (2 autoloads: ResourceRegistry, HexGrid), structural observations |
| external-sources.md | Analysis of 5 external sources: Red Blob Games hex guide (coord systems, algorithms), Godot 4.x docs, GDScript reference, Android/iOS export guides. Cross-referenced with codebase |
| architecture.md | Monolithic Godot 4.6 scene-tree architecture, signal-driven communication, 11 modules with dependencies, 4 data flow diagrams (startup, movement, gather, scan), 4 doc-vs-code discrepancies |
| technology-stack.md | GDScript 4.6 with static typing, Godot 4.6-stable (standard edition), gdUnit4 v6.0.3, Compatibility renderer (decided, not yet applied in project.godot), no external dependencies |
| module-map.md | 13 modules mapped: Bootstrap, Hex Grid Core, Data Layer, Player, Inventory, Crafting, Auto-Interaction, Scanner/Catalog, HUD, Rendering, Audio, UI Panels, Shaders. 5,519 source lines, 9,594 test lines |
| coding-standards.md | snake_case files/vars, PascalCase class_name, static typing throughout, signal-driven comms, push_warning/push_error, nullable-field DI for testability |
| data-model.md | All entity schemas (HexTile, ResourceNode, ResourceDef, BiomeData, CatalogEntry, Inventory, Item/Recipe), relationships, 9 Dictionary indexes, validation rules, complete data tables |
| api-contracts.md | Signal/method interfaces for 15+ systems, 2 autoload singletons (ResourceRegistry, HexGrid), 5 signal flow diagrams, 4 doc-vs-code discrepancies |
| integration-map.md | 100% offline game, Godot engine integrations (autoloads, rendering, input, audio, save/load), gdUnit4 addon, planned Android/iOS targets, 4 stubbed future systems |
| domain-glossary.md | 70+ terms across 10 categories: hex grid, movement/traversal, resources/gathering, inventory/tools, crafting, scanner/catalog, rendering, UI/HUD |
| test-landscape.md | 23 test suites, ~600 test functions (512 unit + 88 integration), 1.74:1 test-to-code ratio. 20/41 source files untested (incl. hex_grid.gd). No CI/CD, save/load untested |
| security-model.md | Offline single-player: save system uses plain Dictionary serialization, inconsistent input validation on load, demo/premium unlock not yet implemented |
| tech-debt.md | Medium overall, 13 items. Top 5 high-priority: no CI/CD, no export config, 50% untested files, untested save/load, renderer mismatch. Zero TODO/FIXMEs |
| infrastructure.md | No build automation, no export presets, no mobile builds produced. iOS needs unconfirmed macOS. Android API target (26) below Play Store requirements (34+) |
| ui-architecture.md | Full scene tree, "Warm Horizon" design system (partially implemented), 3 bottom-drawer panels, programmatic StyleBoxFlat styling, no Theme resource, no accessibility |
| feature-inventory.md | 13 confirmed features: 8 implemented (hex grid, movement, gathering, inventory, crafting, scanner, HUD, auto-interaction), 4 stubbed (survival, building, day/night, fauna), 1 not started (journal & narrative) |
| known-issues.md | Platform gotchas and development environment notes |
