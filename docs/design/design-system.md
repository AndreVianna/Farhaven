# Design System: Warm Horizon

### 1. Overview & Creative North Star

The Creative North Star is **"Warm Horizon"** — a charming, inviting sci-fi world that rewards curiosity over punishment. The UI should feel like a friendly companion device, not a military readout. Think field journal meets smart wristband.

**Reference:** `docs/design/mockup-hud-v2.png` (Stitch-generated, canonical)

**Inspirations:** Astroneer (warm low-poly, soft lighting), My Little Universe (simple iconography, auto-interaction feel), Slime Rancher (colorful palette, approachable sci-fi)

**Core Principles:**
- **Warm over cold.** Soft gradients, rounded corners, gentle shadows. Never harsh.
- **Readable at arm's length.** Mobile-first, thumb-friendly. Minimum touch target 96px.
- **World is the star.** UI is translucent overlay, never competing with the hex landscape and horizon.
- **Horizon always visible.** The planet's sky/environment peeks through between HUD elements — creates sense of place and wonder. No fog of war on the skyline.

---

### 2. Colors & Surface Logic

The palette is warm, earthy, with soft sci-fi accents. Drawn from the planet's biomes.

#### Primary Palette
| Token | Hex | Usage |
|-------|-----|-------|
| `sky_gradient_top` | #4A90D9 | Sky zenith — soft blue |
| `sky_gradient_bottom` | #A8D8EA | Sky horizon — pale warm blue |
| `surface_bg` | #1A1A2E → 85% opacity | Panel backgrounds — deep navy, translucent |
| `surface_panel` | #2A2A3E → 90% opacity | Elevated panels (inventory, catalog) |
| `accent_warm` | #F4A261 | Primary interactive — warm amber |
| `accent_green` | #7EC886 | Health, positive states, flora |
| `accent_blue` | #5BB5E0 | Thirst, scanner, info states |
| `accent_red` | #E07B7B | Damage, danger, low stats |
| `accent_gold` | #F0D060 | Hunger, crafting, discovery |
| `text_primary` | #FFFFFF | Primary text |
| `text_secondary` | #B0B8C8 | Secondary/dimmed text |
| `text_label` | #8890A0 | Labels, captions |

#### Biome Colors (Hex Grid)
| Biome | Base | Variations (2-3 tones) |
|-------|------|----------------------|
| Crash Site | #8B7355 | Scorched earth tones, metallic grays |
| Grassland | #6DBE5A | Warm greens, yellow-green, sage |
| Forest | #2D8B46 | Deep green, emerald, moss |
| Rocky | #9E8B78 | Warm stone, tan, sandy brown |
| Water | #4A9BD9 | Vivid blue, teal, foam white |

#### Surface Hierarchy
- **Game world** — always base layer, always visible
- **HUD elements** — translucent overlays that let the world breathe through
- **Panels** (inventory, catalog, journal) — fullscreen, darker translucent to focus attention
- **Cutscenes** — opaque, layer 40, pauses world

**The "Breathe" Rule:** HUD background areas should never be fully opaque. Even stat bars and buttons sit on semi-transparent backing so the horizon line and hex world remain present.

---

### 3. Typography

One font family. Clarity over style. Godot default font (Noto Sans) or a clean geometric sans-serif.

| Role | Size | Weight | Usage |
|------|------|--------|-------|
| `display` | 48pt | Bold | DAY counter, chapter titles |
| `heading` | 36pt | SemiBold | Panel titles, tab labels |
| `title` | 28pt | Medium | Section headers, entry names |
| `body` | 22pt | Regular | Descriptions, narrative text |
| `label` | 18pt | Medium | Button labels, stat labels, captions |
| `micro` | 14pt | Regular | Tooltips, quantity numbers on slots |

**Rules:**
- Center-aligned for HUD elements (buttons, counters, stat bars)
- Left-aligned for panel content (catalog entries, journal text)
- All-caps for button labels and tab headers only
- No monospace — this isn't a military terminal

---

### 4. Elevation & Depth

Depth through **subtle shadows and translucency**, not tonal layering.

- **Buttons:** Soft drop shadow (2px Y, 4px blur, black 20%). Pressed state = shadow shrinks to 1px.
- **Panels:** Gentle darkened vignette at edges. Background blur optional (performance-dependent).
- **Stat bars:** Inset feel — 2px inner shadow, rounded ends.
- **Floating text:** Rise + fade animation (60px over 1.0s). No shadow on floating text.
- **No glassmorphism.** Simple translucency (85-90% opacity) is enough.

**Corner Radius Scale:**
| Element | Radius |
|---------|--------|
| Buttons | 12px |
| Panels | 16px |
| Stat bars | 8px (full round ends) |
| Slots | 8px |
| Tabs | 12px top, 0px bottom |

---

### 5. Layout

Portrait 1080×1920. Three zones:

```
┌──────────────────────┐
│  A: Stats + Day       │  top ~120px
│                       │
│                       │
│  B: Game World        │  center — hex grid + horizon
│     + Horizon Sky     │  THIS IS THE STAR
│                       │
│                       │
│  C: Action Bar        │  bottom ~160px
└──────────────────────┘
```

#### Zone A — Status Bar (top)
- **Left:** 3 stat bars stacked (HP/Hunger/Thirst), each with icon (❤️/🍴/💧) on the left
- **Right:** DAY counter with phase icon (☀️/🌙)
- **Background:** gradient fade from `surface_bg` 85% → transparent downward (~80px fade)
- Stat bars: ~300px wide, 24px tall, rounded ends, color-filled left-to-right

#### Zone B — Game World (center)
- Hex grid fills this area
- **Horizon line visible** above the hex terrain — sky gradient creates atmosphere
- Camera angle ~45-50° shows 3-4 rings of hexes + distant elevated terrain
- No permanent UI here. Only transient: floating text (+1 Wood), scan progress ring

#### Zone C — Action Bar (bottom)
- 4 main buttons equally spaced: **Inventory** 🎒, **Build** 🔨, **Scanner** 🔍, **Journal** 📖
- Each button: 96-128px square, icon above, label below
- Icon style: simple, filled, rounded — NOT line-art
- Background: gradient fade from `surface_bg` 85% → transparent upward (~80px fade)
- **Craft button** appears conditionally (near workbench) — 5th button, same style

#### Panels (fullscreen overlay)
- Triggered by action bar buttons
- Anchor top=0 (fullscreen), `surface_panel` background
- Close button top-right, 96px
- Mutual exclusion — only one panel open at a time
- Game world dimly visible through translucent background

---

### 6. Components

#### Stat Bars
- Height: 24px, full-round ends (radius = height/2)
- Icon 32px to the left of each bar
- HP: `accent_green` fill → `accent_red` when <25%
- Hunger: `accent_gold` fill
- Thirst: `accent_blue` fill
- Background track: white 15% opacity
- No numeric readout in HUD (clean look). Numbers in Status panel (future).

#### Action Buttons
- Size: 112×112px (icon 64px + label 18pt below)
- Background: `surface_bg` 80% opacity, rounded 12px
- Active/selected: `accent_warm` border glow (2px)
- Disabled: 40% opacity
- Icon style: solid fill, single color (`text_primary`), simple geometric shapes
- Touch target: full 112px square minimum

#### Inventory Slots
- Size: 110×110px, rounded 8px
- Background by category: flora=green 15%, mineral=brown 15%, tool=blue 15%, empty=white 5%
- Quantity label: bottom-right, `micro` size, bold
- Consumable indicator: subtle pulsing border on tap-to-use items

#### Catalog Entry Rows
- Height: 100px minimum
- Icon: 72px category-colored circle with symbol
- Name: `title` size (24pt)
- Description: `body` size (18pt), `text_secondary` color
- Unknown entries: ❓ icon, "Unknown" text, dimmed

#### Catalog Tabs
- Height: 96px
- Full-width, equally distributed
- Active tab: `accent_warm` underline (3px)
- Label: `heading` size (36pt), all-caps
- Categories: FLORA / FAUNA / MINERALS / ANOMALIES

#### Day Counter
- `display` size (48pt), bold
- Format: "DAY 07"
- Phase icon: ☀️ (day/dawn), 🌅 (dusk), 🌙 (night)
- Color shifts with phase: day=`accent_gold`, dusk=`accent_warm`, night=`accent_blue`

#### Floating Text
- Rise 60px over 1.0s, fade out last 0.3s
- Colors: gather=`accent_green`, damage=`accent_red`, scan=`accent_blue`, error=`accent_red`, discovery=`accent_gold`
- Font: `title` size (28pt), bold, with 1px dark outline for readability over any background

#### Notifications
- Bottom-center, above action bar
- Rounded pill shape (full-round ends)
- `surface_panel` background, `text_primary` text
- Slide up + fade in, hold 2s, fade out
- Max queue: 3

---

### 7. Horizon & Environment

**The horizon is not decoration — it's emotional design.**

- Sky gradient visible above hex terrain: `sky_gradient_top` → `sky_gradient_bottom`
- Creates sense of being ON a planet, not in a void
- Distant terrain silhouettes (elevated rocky hexes) break the horizon line naturally
- Day/night cycle shifts sky colors:
  - **Day:** warm blue sky, soft white clouds (future)
  - **Dusk:** amber/orange gradient, long shadows
  - **Night:** deep purple (#2D1B4E), stars (future), warm not cold
  - **Dawn:** pink/gold gradient, hopeful feel
- **No fog of war on the skyline.** Fog only affects hex tile content (icons, resources). The horizon and sky are always full-color, always inviting.

---

### 8. Do's and Don'ts

**Do:**
- **Round the corners.** Everything has radius. Buttons, bars, panels, slots.
- **Keep it warm.** Ambers, greens, soft blues. Even "danger" red is warm (#E07B7B), not screaming.
- **Let the world breathe.** Translucent backgrounds, gradient fades, visible horizon.
- **Use icons + labels together.** Never icon-only or label-only on buttons.
- **Center-align HUD elements.** Buttons, counters, stat bars — all centered/symmetric.
- **Size for thumbs.** 96px minimum touch target, 112px preferred.

**Don't:**
- ~~Sharp corners (0px radius)~~ — everything rounds
- ~~Dark/cold palette~~ — no obsidian, no navy, no "military"
- ~~Opaque UI backgrounds~~ — always translucent, let the world through
- ~~Line-art icons~~ — solid, filled, simple
- ~~Tiny text (<18pt for any interactive label)~~ — mobile first
- ~~UI that competes with the game world~~ — UI serves the world, not the other way around

---

### 9. Animation & Feel

- **Panel open/close:** Slide up from bottom, 0.2s ease-out
- **Button press:** Scale 95% + shadow shrink, 0.1s
- **Stat bar change:** Smooth tween, 0.3s
- **Tab switch:** Content crossfade, 0.15s
- **Floating text:** Rise + fade, 1.0s
- **Notification:** Slide up + fade in 0.2s, hold 2.0s, fade out 0.3s

All animations are quick and snappy. Nothing longer than 0.3s for interactive feedback. The game should feel *responsive and alive*, not sluggish.

---

*"The best UI is the one that makes you forget it's there — and makes you feel like you're really standing on this planet."*
