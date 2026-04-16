# Blade Grass (P00001) — Generation Prompts

## Style Anchor

The `reference.png` (v1) is the **style anchor** for the entire Farhaven prop set.
When generating other props through nano-banana, keep the art style, color
palette, composition, and lighting identical to this image — only the
silhouette/biology should differ between species.

## What varies between variants / What stays fixed

**FIXED (species identity):**
- Color palette (celadon-green body, darker veins, faint bioluminescent edges)
- Material (fibrous, slightly translucent)
- Overall growth form (radial tuft, ground cover)
- Art style (Subnautica/NMS, stylized, matte, painterly, not photorealistic)
- Composition (single subject, 3/4 high-angle, gray background, studio lighting)
- "Alien planet flora" feel

**VARIES (individual biological variation):**
- Number of blades (sparse vs dense)
- Blade length and thickness (short/stocky vs long/slender)
- Blade curvature (straight vs arched outward)
- Overall proportions (taller-than-wide vs wider-than-tall)
- Age / state (young dense tuft vs mature spread tuft)

---

## Variation 1 (Baseline / Style Anchor) — `reference.png` → `mesh_v1.glb`

```
A cluster of alien grass-like plant growing from the ground. Dense radial
tuft of long, slightly curved blade-shaped leaves emerging from a central
base. The blades are fibrous and slightly translucent, with a pale
celadon-green body and darker veins running lengthwise. Subtle
bioluminescent edges catch the light faintly. Small plant, approximately
30cm tall and 40cm wide at the top.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading, alien planet flora with an otherworldly
feel. Semi-realistic but painterly. Not photorealistic. Single pop of
saturated color against muted palette. Clean readable silhouette.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire plant visible with generous padding around
it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 2 (Dense, shorter blades) — `reference_v2.png` → `mesh_v2.glb`

```
A cluster of alien grass-like plant growing from the ground. Dense radial
tuft of numerous shorter, stockier blade-shaped leaves (about twice as
many blades as a typical specimen), emerging closely packed from a central
base. The blades are fibrous and slightly translucent, with a pale
celadon-green body and darker veins running lengthwise. Subtle
bioluminescent edges catch the light faintly. Compact young plant,
approximately 20cm tall and 45cm wide at the top — wider than tall.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading, alien planet flora with an otherworldly
feel. Semi-realistic but painterly. Not photorealistic. Single pop of
saturated color against muted palette. Clean readable silhouette.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire plant visible with generous padding around
it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 3 (Sparse, taller blades) — `reference_v3.png` → `mesh_v3.glb`

```
A cluster of alien grass-like plant growing from the ground. Sparse radial
tuft of fewer, longer, more slender blade-shaped leaves with more
pronounced curvature (about half as many blades as a typical specimen,
each blade longer and arching outward), emerging from a central base.
The blades are fibrous and slightly translucent, with a pale celadon-green
body and darker veins running lengthwise. Subtle bioluminescent edges
catch the light faintly. Mature plant, approximately 40cm tall and 35cm
wide at the top — taller than wide.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading, alien planet flora with an otherworldly
feel. Semi-realistic but painterly. Not photorealistic. Single pop of
saturated color against muted palette. Clean readable silhouette.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire plant visible with generous padding around
it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Meshy Pipeline Settings (used for all three variants)

- Target polycount: **3000 triangles** (Fixed, not Adaptive)
- Topology: **Triangle**
- Preserve UV: yes
- Texture generation: PBR bake (baseColor + metallicRoughness + normal)

Each final mesh lands around 2950–3000 tris with full PBR textures.
