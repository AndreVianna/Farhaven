# UI Architecture

> **Source:** discovery-architect
> **Status:** Active
> **Last Updated:** 2026-04-03

This is a Godot 4.6 mobile game. "UI" refers to the in-game HUD and panel system, not a web frontend.

## Component Architecture

### Scene Tree (from scenes/main.tscn)

```
Main (Node) -- scripts/main.gd
+-- World (Node3D) -- 3D game world
|   +-- HexGridRenderer -- terrain mesh (ArrayMesh, single draw call)
|   +-- PropRenderer -- resource props (MultiMesh instancing)
|   +-- PropLabelRenderer -- floating text labels above props
|   +-- ScanProgressRenderer -- scan progress bar overlay
|   +-- Player (Node3D) -- scripts/player/player.gd
|   |   +-- PlayerModel (Node3D) -- procedural mesh (head, torso, arms, legs)
|   |   +-- PlayerInput (Node) -- touch classifier (tap vs joystick)
|   |   +-- ScannerSystem (Node) -- proximity auto-scan
|   |   +-- AutoInteractionSystem (Node) -- auto-gather/defend
|   |   +-- CraftingSystem (Node) -- recipe tracking + crafting
|   +-- Camera3D -- scripts/player/player_camera.gd (follows player)
+-- JoystickOverlay (CanvasLayer, layer 10) -- virtual joystick visual
|   +-- JoystickOverlay (Control) -- ui/joystick_overlay.gd
+-- HUD (CanvasLayer, layer 20) -- all UI elements
|   +-- HUD (Control) -- scripts/hud/hud.gd (top-level UI controller)
|       +-- TopBar
|       |   +-- StatBars -- HP/Hunger/Thirst progress bars
|       |   +-- DayCounter -- "DAY 07" display with phase icon
|       +-- FloatingTextContainer -- floating "+1 Wood" text manager
|       +-- NotificationContainer -- pill-shaped notification queue
|       +-- PlacementLabel -- "TAP TO PLACE" label (building mode)
|       +-- BottomBar
|       |   +-- InventoryButton -- opens inventory panel
|       |   +-- ScannerButton -- opens catalog panel
|       |   +-- CraftButton -- opens crafting panel (conditional visibility)
|       +-- InventoryPanel (PanelContainer) -- ui/inventory_panel.gd
|       +-- CatalogPanel (PanelContainer) -- ui/catalog_panel.gd
|       +-- CraftingPanel (PanelContainer) -- ui/crafting_panel.gd
+-- ScreenFade (CanvasLayer, layer 30) -- screen transition layer
```

### Composition Patterns

- **Node composition:** All player systems (input, scanner, auto-interaction, crafting) are child nodes of the Player node, composed via player.tscn. This is standard Godot component pattern.
- **Signal-driven wiring:** main.gd._wire_systems() connects data sources (Inventory, Catalog, CraftingSystem) to presentation (HUD panels) at startup using setter methods (connect_inventory, connect_catalog, connect_crafting).
- **Mutual exclusion:** Panels implement a panel_opened signal. HUD._on_panel_opened() closes all other panels when one opens (hud.gd lines 178-181).
- **Preload constants:** UI scripts use const preload() to reference dependencies (e.g., InventorySlotUI, ToolSlotUI, RecipeEntryUI), avoiding class_name registration issues with autoloads.

### Shared vs Page-Specific Components

**Shared (reusable):**
- InventorySlotUI (ui/inventory_slot_ui.gd) -- used in inventory grid
- ToolSlotUI (ui/tool_slot_ui.gd) -- used in tool slots row
- CatalogEntryUI (ui/catalog_entry_ui.gd) -- used in catalog list
- RecipeEntryUI (ui/recipe_entry_ui.gd) -- used in crafting recipe list
- FloatingTextManager (scripts/hud/floating_text_manager.gd) -- used by HUD for gather/damage/error text
- NotificationManager (scripts/hud/notification_manager.gd) -- used by HUD for toast notifications

**Panel-specific:**
- InventoryPanel -- tool slots row + scrollable resource grid + toxic item confirmation dialog
- CatalogPanel -- tabbed category view (flora/fauna/minerals/anomalies)
- CraftingPanel -- scrollable recipe list with craft buttons

## State Management

There is no state management framework (no Redux, Vuex, or equivalent). State is managed through ownership and signals:

- **Inventory state:** Owned by Player (player.gd line 26: var inventory = Inventory.new()). Inventory is a RefCounted object, not a scene node. Changes propagate via signals: inventory_changed, item_added, item_removed, inventory_full, tool_changed.
- **Catalog state:** Owned by ScannerSystem (scanner_system.gd line 61: _catalog = Catalog.new()). Catalog is RefCounted. Changes propagate via knowledge_state_changed, entry_cataloged signals.
- **Crafting state:** Owned by CraftingSystem node. Recipe discovery tracked in _discovered_recipes array. Changes via recipe_discovered, craft_completed signals.
- **Map state:** Owned by HexGrid autoload singleton. Tile data in _tiles Dictionary. Changes via tile_revealed, tile_visibility_changed, resource_depleted, resource_respawned signals.
- **UI state:** Each panel tracks its own visibility (visible property). No centralized UI state store.

**Data flow pattern:** Unidirectional within each system. Data owners emit signals, UI panels listen and refresh. Panels never mutate data directly -- they call methods on the owning system (e.g., CraftingPanel calls crafting_system.craft(recipe_name), CraftingSystem validates and emits craft_completed, panel refreshes).

## Design System

The project has a documented design system called **"Warm Horizon"** (docs/design/design-system.md).

### Design Tokens

**Color palette** (defined in docs/design/design-system.md, section 2):

| Token | Hex | Usage |
|-------|-----|-------|
| surface_bg | #1A1A2E at 85% opacity | Panel backgrounds |
| surface_panel | #2A2A3E at 90% opacity | Elevated panels |
| accent_warm | #F4A261 | Primary interactive (amber) |
| accent_green | #7EC886 | Health, positive, flora |
| accent_blue | #5BB5E0 | Thirst, scanner, info |
| accent_red | #E07B7B | Damage, danger |
| accent_gold | #F0D060 | Hunger, crafting, discovery |
| text_primary | #FFFFFF | Primary text |
| text_secondary | #B0B8C8 | Dimmed text |

**Biome colors** (5 biomes with 2-3 variations each, loaded from data/biomes/*.tres at runtime).

### Code Reality vs Design System

The design system document specifies detailed tokens, typography scales, and component specs. The actual UI code implements a subset:
- Panel backgrounds use StyleBoxFlat with Color(0.08, 0.08, 0.12, 0.92) (inventory_panel.gd line 53, crafting_panel.gd line 29) -- this is close to but not exactly surface_bg #1A1A2E at 85%.
- Colors are hardcoded per-panel rather than referenced from a shared token system. There is no centralized theme resource or color constants file.
- Typography uses Godot default font (Noto Sans) as specified in the design system.
- Touch targets follow the 96px minimum guideline from the design system.

### Theming

No Godot Theme resource (.tres) is used. Styling is applied programmatically:
- StyleBoxFlat created in _ready() for panel backgrounds (inventory_panel.gd lines 52-56)
- Colors hardcoded inline (e.g., Color.GREEN, Color.RED in hud.gd)
- No dark mode / light mode switching
- No centralized token system in code

## Routing and Navigation

There is no router library. Navigation is panel-based:

- **Three panels:** Inventory, Catalog, Crafting -- opened by bottom bar buttons
- **Mutual exclusion:** Only one panel open at a time (hud.gd _on_panel_opened closes others)
- **Toggle pattern:** Each button toggles its panel (open if closed, close if open)
- **No deep linking or URL routing** -- this is a native game, not a web app
- **Craft button conditional:** Visible only when recipes are discovered (hud.gd lines 99-101)

### CanvasLayer Ordering
| Layer | Content |
|-------|---------|
| 10 | JoystickOverlay -- virtual joystick visual |
| 20 | HUD -- stat bars, buttons, panels |
| 30 | ScreenFade -- screen transition effects |

## Responsive and Adaptive

- **Fixed portrait layout:** 1080x1920 viewport (project.godot lines 34-35)
- **Stretch mode: viewport** -- Godot scales the entire viewport to fit the screen, maintaining aspect ratio
- **Mobile-first design:** Touch emulation enabled for desktop development (project.godot line 45)
- **No breakpoints:** Single layout for all screen sizes. Godot viewport stretch handles scaling.
- **Three-zone layout** (from design system):
  - Zone A (top ~120px): Stats + Day counter
  - Zone B (center): 3D hex grid game world
  - Zone C (bottom ~160px): Action bar buttons
  - Panels overlay the full screen when opened

## Accessibility

No explicit accessibility implementation is present in the codebase:

- **No WCAG level targeted** -- not documented or implemented
- **No ARIA patterns** -- not applicable to Godot (ARIA is a web standard)
- **No keyboard navigation** -- input is touch-only (PlayerInput handles InputEventScreenTouch and InputEventScreenDrag)
- **No screen reader support** -- Godot has limited accessibility APIs; none are used
- **Touch target sizing:** Design system specifies 96px minimum, 112px preferred (docs/design/design-system.md section 6). Code appears to follow this for bottom bar buttons.
- **Color contrast:** The design system uses warm colors against dark translucent backgrounds, which should provide adequate contrast, but no formal contrast ratio testing is documented.

## Styling Approach

All UI styling is **programmatic** (GDScript code), not declarative:

- **No CSS, no Tailwind, no styled-components** -- this is Godot, not web
- **StyleBoxFlat** created in code for panel backgrounds (inventory_panel.gd lines 52-56, crafting_panel.gd lines 28-30)
- **Inline color values** -- colors are hardcoded where used (e.g., Color(0.08, 0.08, 0.12, 0.92))
- **No Godot Theme resource** -- no .tres theme file for centralized styling
- **Shader-based rendering** for 3D elements:
  - hex_tile.gdshader -- terrain with per-vertex color and fog of war
  - icon_billboard.gdshader -- billboard icons for props
  - scan_progress.gdshader -- scan progress bar overlay

### Naming Convention
- UI scripts in ui/ directory use class_name registration (InventoryPanel, CatalogPanel, CraftingPanel, etc.)
- HUD scripts in scripts/hud/ use mixed approach (HUD has class_name, others do not)
- Scene files in scenes/ui/ match their script names

## Build and Bundle

- **Bundler:** Godot Engine built-in export system
- **Config location:** No export_presets.cfg exists yet
- **Code splitting:** Not applicable -- Godot loads scenes and scripts on demand via preload() and load()
- **Lazy loading:** Scenes use preload() for dependencies needed at startup, load() for deferred loading (e.g., map_loader.gd line 195 uses load() for the MapLoader script)
- **Performance optimizations in code:**
  - HexGridRenderer: Single ArrayMesh draw call for entire terrain (scenes/world/hex_grid_renderer.gd)
  - PropRenderer: MultiMesh instancing for resource props
  - AutoInteractionSystem: Throttled proximity checks at 0.1s intervals (auto_interaction_system.gd line 46)
  - Panels: Only refresh when visible (inventory_panel.gd line 159: if visible: _refresh_all())
- **No performance budget defined** beyond GDD targets (<200MB RAM, <100MB APK)
