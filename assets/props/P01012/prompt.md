# Rubble Field (P01012) — Generation Prompts

## Style Anchor

Follow `assets/props/P00001/reference.png` as the **style anchor** for the
entire Farhaven prop set. Art style, lighting, background, and composition
must match. Only the silhouette/material changes per species.

Species identity: a small patch of **loose rocky scree** — many small
broken stone fragments scattered together in a shallow pile, as if a
nearby larger rock has disintegrated over time. Reads as "loose rock
debris, low profile, spread along the ground." **COMMON rarity**.
Decorative/minor harvest — yields stone per harvest.

## What varies / What stays fixed

**FIXED (material identity):**
- Form (a low shallow pile of many small irregular stone fragments,
  spread across a roughly circular area — NOT a single rock)
- Fragments vary in size from pea-sized to roughly fist-sized
- Color palette (dull gray-brown range, earthy, slightly dusty)
- Low profile — the pile sits close to the ground, reading as "scree,
  not boulder"
- Scale (footprint about 50-70 cm wide, height no more than ~15 cm)
- Art style (Subnautica/NMS, stylized, matte painterly)
- Composition (single subject, 3/4 high-angle, #888 gray background,
  soft even studio lighting with subtle rim light)

**VARIES (color mix / sharpness):**
- V1: **mixed gray weathered scree** — rounded
- V2: **sharp freshly broken scree** — angular
- V3: **reddish-brown iron-stained scree** — earthy

---

## Variation 1 (Rounded gray weathered scree) — `reference_v1.png` → `mesh_v1.glb`

```
A low shallow pile of many small weathered stone fragments spread along the ground in a roughly circular patch about 60 cm wide, no more than 12 cm tall at its highest point. Several dozen individual stones in a mix of dull gray-brown shades, ranging from pea-sized (about 1 cm) up to roughly fist-sized (about 8 cm across), all with rounded worn edges and smooth weathered surfaces. The stones are piled casually with natural gaps between them, a few perched on top of others, the overall silhouette loose and organic rather than neatly stacked. Subtle differences in color — some stones slightly warmer tan, some cooler gray, some almost charcoal — add visual interest without breaking the muted palette. Fine dust or very small grit is hinted at between the larger fragments. Reads as "old weathered rock debris that has sat here a long time."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — loose scree composition with many individual rounded stone fragments, slightly exaggerated for readability, matte stone shading across all pieces, cohesive palette. Semi-realistic but painterly. Not photorealistic. The LOW PROFILE scree-not-boulder silhouette is defining.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire rubble patch visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 2 (Sharp freshly broken scree) — `reference_v2.png` → `mesh_v2.glb`

```
A low shallow pile of many small freshly broken stone fragments spread along the ground in a roughly circular patch about 55 cm wide, no more than 14 cm tall at its highest point. Several dozen individual stones in a mix of dull gray-brown shades, ranging from pea-sized up to roughly fist-sized, but unlike variation 1 these fragments have SHARP angular edges and fresh clean fracture faces — this looks like recent debris rather than weathered scree. Several stones show lighter interior faces where they have been freshly broken, contrasting with their darker weathered exterior. The stones are piled casually with natural gaps, a few perched on top of others, giving an organic loose silhouette. Fine rock dust hints between the larger fragments. Reads as "freshly broken stone fragments — recent, angular, piled."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — loose scree composition with sharp angular stone fragments showing fresh fracture faces, slightly exaggerated for readability, matte stone shading with subtle tonal variation between weathered outer and fresh inner faces. Semi-realistic but painterly. Not photorealistic.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire rubble patch visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 3 (Reddish-brown iron-stained scree) — `reference_v3.png` → `mesh_v3.glb`

```
A low shallow pile of many small stone fragments spread along the ground in a roughly circular patch about 65 cm wide, no more than 13 cm tall at its highest point. Several dozen individual stones ranging from pea-sized to fist-sized, with a distinctly warmer palette than the other variations — most fragments show reddish-brown iron oxidation staining across their surfaces, giving the whole patch an earthy rusty tone. The stones have mixed weathering: some rounded, some sharp. Rust-orange streaks run down from higher stones onto lower ones, and a faint reddish dust fills the gaps between fragments. Reads as "iron-rich alien rock debris — warm, earthy, rust-stained."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — loose scree composition with warm rust-brown palette, slightly exaggerated for readability, matte stone shading with iron-oxide staining unifying the color across all fragments. Semi-realistic but painterly. Not photorealistic.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire rubble patch visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Meshy Pipeline Settings

- Target polycount: **3000 triangles** (Fixed, not Adaptive)
- Topology: **Triangle**
- Preserve UV: yes
- Texture generation: PBR bake (baseColor + metallicRoughness + normal)
