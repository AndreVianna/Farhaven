# Boulder (P01001) — Generation Prompts

## Style Anchor

Follow `assets/props/P00001/reference.png` as the **style anchor** for the
entire Farhaven prop set. Art style, lighting, background, and composition
must match. Only the silhouette/material changes per species.

Species identity: large weathered **monolithic stone** — irregular crystal
form, hardness 6, shatters under force, dull surface, blocked light,
density 2.7, common rarity, decoration tag (not harvestable). Too massive
to shift without heavy tools.

## What varies / What stays fixed

**FIXED (material identity):**
- Color palette (warm weathered-gray body with subtle rust-orange oxidation
  streaks and faint cyan-green mineral vein hints — the alien flavor stays
  subtle, this is still recognizably STONE)
- Material (matte dull stone, rough surface, no metallic sheen, no
  translucency)
- Scale (roughly waist-high — ~80-100 cm tall)
- Art style (Subnautica/NMS, stylized, matte, painterly, not photorealistic)
- Composition (single subject, 3/4 high-angle, #888 gray background, soft
  even studio lighting with subtle cool rim light)

**VARIES (weathering / shape):**
- Overall silhouette (rounded worn vs angular craggy vs split-cracked)
- Surface texture (smooth worn vs rough chipped)
- Prominence of oxidation streaks and mineral vein hints
- Presence / depth of visible cracks

---

## Variation 1 (Baseline / rounded weathered) — `reference_v1.png` → `mesh_v1.glb`

```
A large alien boulder resting on the ground. A rounded weathered monolith
of warm gray stone, approximately 90 cm tall and 80 cm wide, with a
slightly asymmetric dome-like silhouette — smoothed by long exposure.
The surface is matte and dull, with a subtle grain visible up close.
Faint rust-orange oxidation streaks run down one side where water has
pooled and run off. Hints of pale cyan-green mineral veining are
visible in a couple of narrow bands crossing the stone — subtle, not
glowing, just the alien flavor. A few small shallow pits dot the
surface. Reads as a silent, weathered landmark.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading with no metallic sheen, alien planet
geology with an otherworldly feel. Semi-realistic but painterly. Not
photorealistic. Warm gray body with warm rust highlights against the
muted palette. Clean readable silhouette — clearly a boulder, not a
rock pile.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire boulder visible with generous padding
around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 2 (Angular craggy) — `reference_v2.png` → `mesh_v2.glb`

```
A large alien boulder resting on the ground. An angular craggy monolith
of warm gray stone, approximately 85 cm tall and 85 cm wide, with a
blocky silhouette of intersecting planar faces — like it was broken
off and rotated into place. The surface is matte, rougher than a
weathered boulder, with sharp ridges and flat faces where stone has
fractured. Rust-orange oxidation runs along a couple of the ridge
lines. Pale cyan-green mineral veining is slightly more visible on
the freshly-fractured faces, running in narrow irregular bands. A few
smaller chunks look ready to spall off. Reads as recently exposed and
less worn than a typical boulder.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading with no metallic sheen, alien planet
geology with an otherworldly feel. Semi-realistic but painterly. Not
photorealistic. Warm gray body with warm rust highlights against the
muted palette. Clean readable silhouette — clearly a boulder, not a
rock pile.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire boulder visible with generous padding
around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 3 (Split with visible crack) — `reference_v3.png` → `mesh_v3.glb`

```
A large alien boulder resting on the ground. A tall weathered monolith
of warm gray stone, approximately 100 cm tall and 70 cm wide, with a
roughly vertical silhouette and a pronounced deep crack running down
one side — the crack is clearly visible as a dark shadowed fissure
splitting the upper half into two unequal lobes that still lean on
each other. The surface is matte and mostly worn-smooth, but the
interior of the crack shows fresher, rougher stone with brighter
pale cyan-green mineral veining revealed by the fracture. Rust-orange
oxidation streaks run down from the crack edges. Reads as an old
landmark caught in the middle of a slow split.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading with no metallic sheen, alien planet
geology with an otherworldly feel. Semi-realistic but painterly. Not
photorealistic. Warm gray body with warm rust highlights against the
muted palette. Clean readable silhouette — the crack is the focal point.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire boulder visible with generous padding
around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Meshy Pipeline Settings

- Target polycount: **3000 triangles** (Fixed, not Adaptive)
- Topology: **Triangle**
- Preserve UV: yes
- Texture generation: PBR bake (baseColor + metallicRoughness + normal)
