# Puff Sac (P00002) — Generation Prompts

> **2026-04-21 — renamed and reclassified.** This prop was originally
> authored as "Tuft Moss" in the `plant` category. It is now **Puff Sac**
> in the `fungi` category — the existing dome-cluster silhouette with
> translucent skin, bioluminescent veins, and spore-pod tufts already
> reads as a fungal sac colony, so the meshes and reference images are
> kept. Only `display_name` and `category` in `P00002.tres` and the
> descriptive text in this file have changed.

Species identity: pressure-filled sac-like fungal cluster — soft dome
bodies with translucent outer layer, pulsing bioluminescent veins, and
small glowing spore pods that release fine spores when disturbed.
Ground cover, irregular symmetry, hydration_level=7.

## What varies / What stays fixed

**FIXED (species identity):**
- Color palette (deep teal body, desaturated forest green, lavender/pink
  bioluminescent spore pods, cyan-teal inner vein glow)
- Material (soft, spongy, translucent outer layer revealing veins below,
  subsurface scattering quality)
- Overall growth form (cushion-like dome cluster, ground-level)
- Art style (Subnautica/NMS, stylized, matte + subsurface scattering,
  painterly, not photorealistic)
- Alien bryophyte feel (no leaves, no stems, no blades)
- Composition (single subject, 3/4 high-angle, gray background, studio lighting)

**VARIES (individual biological variation):**
- Number and size of domes (few large vs many small)
- Density of spore pods
- Vein pattern prominence
- Overall cluster footprint (wide vs tight)

## Variation 1 — `reference_v1.png` → `mesh_v1.glb` ("Neon Cellular Cluster")

Large central dome with pronounced pink spore tuft on top, surrounded by
smaller satellite domes; vivid cyan veins crawling across surfaces.
Highest bioluminescent density of the three variants.

## Variation 2 — `reference_v2.png` → `mesh_v2.glb` ("Luminous Protocells")

Many smaller, more uniform domes packed tightly together. Fewer and more
subtle spore pods. Vein pattern present but softer. Reads as a denser,
younger colony.

## Variation 3 — `reference_v3.png` → `mesh_v3.glb` ("Luminescent Cortex")

Tight sculpted cluster with deeply-folded, almost brain-coral-like surface.
Vivid cyan veins following the folds; scattered pink spore pods. Reads as
a mature single organism with complex morphology.

---

## Nano-Banana Base Prompt (adapt per variant)

```
A cushion-like cluster of alien moss-like organism growing on the ground.
A soft, irregular mound of tightly packed spongy tissue, covered in tiny
tendrils and glistening beads of moisture. Translucent outer layer reveals
faint pulsing bioluminescent veins underneath, glowing softly in shades
of teal and cool violet. Small glowing spore pods dot the surface. The
silhouette is domed and irregular — not a uniform mat, but a lumpy cushion
with several low swells. No stems, no blades, no leaves — this is a
bryophyte-like mass.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading with subtle subsurface scattering, alien
planet flora with an unmistakably otherworldly feel. Semi-realistic but
painterly. Not photorealistic. Bioluminescent accents pop gently against
a muted, mossy palette (deep forest green, desaturated teal, hints of
grey-purple). Clean readable silhouette.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or ground
plane visible. Entire specimen visible with generous padding around it.
No other elements, no text, no watermark.

Small ground-cover specimen, approximately 15cm tall and 60cm wide.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Meshy Pipeline Settings

- Target polycount: **3000 triangles** (Fixed)
- Topology: **Triangle**
- Preserve UV: yes
- Texture generation: PBR bake

Each final mesh lands around 2975–2991 tris.
