```markdown
# Design System Strategy: Tactical Brutalism

### 1. Overview & Creative North Star
The Creative North Star for this design system is **"Tactical Brutalism."** In the harsh, low-light environments of a sci-fi survival experience, the UI must feel like a high-precision military readout—utilitarian, cold, and unapologetically sharp. 

We break the "standard" game UI template by embracing **0px border radii** and intentional asymmetry. This system eschews the soft, rounded corners of consumer apps in favor of a rigid, architectural grid. By utilizing high-contrast typography scales and overlapping semi-transparent layers, we create a sense of "Data Overlays" rather than a static menu. The interface should feel like a holographic projection emitted from a gritty, physical device.

---

### 2. Colors & Surface Logic
The palette is rooted in deep obsidian and navy tones, punctuated by high-energy bioluminescent accents.

*   **Primary Identity:** Use `primary` (#a8e8ff) and `primary_container` (#00d4ff) exclusively for critical interactive elements and "active" states. These should feel like they are emitting light.
*   **The "No-Line" Rule:** Sectioning must never rely on 1px solid borders. Instead, define boundaries through background shifts. A `surface_container_low` panel sitting on a `surface` background provides all the separation required. 
*   **Surface Hierarchy & Nesting:** Treat the UI as a series of physical "glass" panes. 
    *   **Base Layer:** `surface` (#111318).
    *   **Secondary Content:** `surface_container` (#1e2024).
    *   **High-Priority Overlays:** `surface_container_high` (#282a2e).
*   **The "Glass & Gradient" Rule:** All interactive panels should utilize a `surface_variant` at 60-80% opacity with a `backdrop-filter: blur(12px)`. To add "soul," apply a subtle linear gradient to main CTAs transitioning from `primary` to `tertiary`.

---

### 3. Typography: Technical Authority
We pair the geometric rigidity of **Space Grotesk** with the utilitarian clarity of **Inter**.

*   **The "Data Head" (Space Grotesk):** Used for `display`, `headline`, and `label` roles. This font communicates the "Technical" aspect of the brand. Use `label-sm` for micro-data points (coordinates, timestamps) to reinforce the "readout" aesthetic.
*   **The "Intel" (Inter):** Used for `title` and `body`. Inter provides the necessary legibility for survival logs, item descriptions, and narrative beats.
*   **Intentional Contrast:** Always pair a `display-lg` heading with a `label-md` sub-header in all-caps to create an editorial, high-end look.

---

### 4. Elevation & Depth
In a world of hard edges, depth is achieved through **Tonal Layering** rather than shadows.

*   **The Layering Principle:** Stack `surface_container_lowest` for background "voids" and `surface_container_highest` for active foreground elements. This creates a "machined" look where pieces feel snapped together.
*   **Ambient Shadows:** Traditional drop shadows are forbidden. If a floating HUD element requires separation, use an ultra-diffused glow using a low-opacity `primary` color (4-8% alpha) to mimic light spill from a screen.
*   **The "Ghost Border" Fallback:** For secondary containers, use a "Ghost Border"—a `px` width line using `outline_variant` at 15% opacity. This suggests a frame without creating a visual wall.
*   **Glassmorphism:** Navigation bars and inventory slots must use semi-transparent `surface_container` fills to allow the game world (background) to bleed through, maintaining immersion.

---

### 5. Components

#### Buttons: Tactical Triggers
*   **Primary:** Solid `primary_container` fill, `on_primary_container` text. 0px radius. Use a 2px `primary` glow on hover.
*   **Secondary:** Ghost Border (`outline_variant` at 20%) with `on_surface` text. 
*   **Interaction:** On press, the button should "glitch" briefly to `tertiary_fixed_dim`.

#### Vitals Bars (HP, Hunger, Thirst)
*   **Structure:** Sleek, horizontal bars. Height: `Spacing 2` (0.4rem).
*   **HP:** Fill with `error` (#ffb4ab); **Hunger:** Fill with `secondary_fixed` (#d7e2ff); **Thirst:** Fill with `primary` (#a8e8ff).
*   **The Detail:** Include a small `label-sm` text readout aligned to the right, slightly overlapping the bar edge for an asymmetric look.

#### Inventory Slots & Cards
*   **Constraint:** No dividers. Use `Spacing 1` (0.2rem) gutters between slots.
*   **State:** Unoccupied slots use `surface_container_lowest`. Hovered slots transition to `surface_container_highest`.
*   **Icons:** Minimalist, geometric line-art using the `outline` token.

#### Input Fields
*   **Styling:** Underline-only (2px `outline_variant`) or full `surface_container` fill. 
*   **Focus:** The underline shifts to `primary`. Helper text uses `label-sm` in `on_surface_variant`.

---

### 6. Do's and Don'ts

**Do:**
*   **Use Asymmetry:** Place labels in corners or offset them from their parent containers using the `Spacing Scale`.
*   **Embrace Monospace Vibes:** Treat `label-sm` as a critical design element for adding "tech" flavor to the UI corners.
*   **High-Contrast Scaling:** Jump from `display-lg` to `body-sm` within the same view to create visual drama.

**Don't:**
*   **No Rounded Corners:** Never use a radius other than 0px. This is non-negotiable for the "Tactical Brutalism" look.
*   **No Generic Shadows:** Avoid black "Drop Shadows." Use tonal shifts or light-based glows only.
*   **No 100% Opaque Borders:** High-contrast lines create "clutter." Use the Ghost Border rule to keep the UI feeling airy and high-tech.
*   **No Center Alignment:** For a professional, editorial feel, stick to strict left-justified or right-justified layouts. Center alignment feels too "casual" for a survival sim.