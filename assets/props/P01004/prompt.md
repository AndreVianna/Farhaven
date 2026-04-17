# Clay Patch (P01004) — Generation Prompts

## Style Anchor

Follow `assets/props/P00001/reference.png` as the **style anchor** for the
entire Farhaven prop set. Art style, lighting, background, and composition
must match. Only the silhouette/material changes per species.

Species identity: a **patch of exposed workable clay** on the ground —
formless crystal form, hardness 2, bends (not shatters), dull surface,
blocked light (opaque), density 1.8, common rarity, near_water tag,
yields 2 clay_lump per harvest (no tool required). Damp, malleable,
hardens when fired.

## What varies / What stays fixed

**FIXED (material identity):**
- Color palette (warm terracotta-to-ochre body with areas of darker
  damp-slick sheen where water has pooled, slight cool gray-green tint
  in cracks and shadows, faint subtle cyan mineral hints where clay
  meets older dry soil at the patch edges — the alien flavor stays
  very subtle here, this is still recognizably clay)
- Material (dull matte clay with a slight damp sheen on the most
  recently exposed areas, dry cracked texture on older surfaces)
- Scale (roughly hand-span — 25-40 cm across, very low profile)
- Art style (Subnautica/NMS, stylized, matte, painterly, not photorealistic)
- Composition (single subject, 3/4 high-angle, #888 gray background, soft
  even studio lighting with subtle cool rim light)

**VARIES (hydration / shape / no human marks):**
- How wet vs dry the clay reads
- Presence of natural cracks / drying patterns
- Overall shape (round patch vs irregular spread)

---

## Variation 1 (Baseline / damp fresh patch) — `reference_v1.png` → `mesh_v1.glb`

```
A small patch of alien workable clay exposed on the ground. A roughly oval clay patch about 30 cm across and 8 cm thick, freshly exposed, with a moist damp-slick surface. The clay is warm terracotta-to-ochre in color, with darker sheen where water has pooled in the lowest spots of the surface. Edges of the patch blend into slightly drier, older soil at the boundary where faint cool cyan-gray mineral hints are visible. The surface is smooth and gently undulating — not cracked, not worked — reading as "fresh exposure, ready to be scooped." A few small pebbles dot the edges where they've settled. Low-profile on the ground.

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — clean organic shapes, slightly exaggerated silhouette for readability, matte shading with a soft damp sheen on the clay surface, alien planet geology with an otherworldly feel. Semi-realistic but painterly. Not photorealistic. Warm terracotta pops against the muted palette. Clean readable silhouette — unambiguously a workable clay patch.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire patch visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 2 (Drying with natural cracks) — `reference_v2.png` → `mesh_v2.glb`

```
A small patch of alien workable clay exposed on the ground. A roughly oval clay patch about 35 cm across and 6 cm thick, partially dried, with a network of hairline shrinkage cracks radiating across the surface like crazed pottery. The clay is warm terracotta-to-ochre on the main body, with darker damp terracotta still visible inside the cracks where the moist clay underneath peeks through. Edges are more pronounced and slightly curled upward where drying has contracted the rim. Faint cool cyan-gray mineral hints at the drier edges. The surface texture is matte with a slight dusty quality on the most-dried portions. Low-profile on the ground. Reads as "caught between wet and dry — still workable but drying."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — clean organic shapes, slightly exaggerated silhouette for readability, matte shading with the crack network as the defining surface detail, alien planet geology with an otherworldly feel. Semi-realistic but painterly. Not photorealistic. Warm terracotta pops against the muted palette. Clean readable silhouette — the crazed surface is the signature.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire patch visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 3 (Irregular / water-shaped, untouched) — `reference_v3.png` → `mesh_v3.glb`

```
A patch of alien workable clay exposed on the ground. An irregular asymmetric patch about 40 cm across and 10 cm thick. The patch has a natural gradient — damper and darker terracotta on the lower side where water has pooled and settled, slightly drier and lighter terracotta on the higher side. A few thin natural water-erosion channels (not man-made scratches) cut across the surface from the high side toward the low side, carved by runoff. A small shallow natural depression sits asymmetrically on one edge where standing water once collected. **No hand prints. No finger trails. No tool marks of any kind.** Shape is organically irregular — nature-shaped, not human-shaped. Edges blend into slightly older soil with faint cool cyan-gray mineral hints. Matte with soft damp sheen on the lower side. Low-profile on the ground. Reads as "fresh exposure shaped only by water and weather, untouched by anyone."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — clean organic shapes, slightly exaggerated silhouette for readability, matte shading with damp sheen on lower areas and drier matte on higher areas, alien planet geology with an otherworldly feel. Semi-realistic but painterly. Not photorealistic. Warm terracotta pops against the muted palette. Clean readable silhouette — organically weathered, never touched.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire patch visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Meshy Pipeline Settings

- Target polycount: **3000 triangles** (Fixed, not Adaptive)
- Topology: **Triangle**
- Preserve UV: yes
- Texture generation: PBR bake (baseColor + metallicRoughness + normal)
