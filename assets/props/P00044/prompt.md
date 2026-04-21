# Dried Wood Sticks (P00044) — Generation Prompts

## Style Anchor

Follow `assets/props/P00001/reference.png` as the **style anchor** for the
entire Farhaven prop set. Art style, lighting, background, and composition
must match. Only the silhouette/material changes per species.

Species identity: a **scatter of dried alien branches / wood sticks**
lying on the ground — the natural debris left by broken-off tree limbs
that have dried out. Cross-biome organic debris: common in Forest,
occasional in Grassland and Rocky. Reads as "kindling scatter."
**COMMON rarity**. Yields dry_wood per harvest with bare hands.

## What varies / What stays fixed

**FIXED (species identity + palette):**
- Material (dried dead alien wood — matte, slightly rough bark, dry
  warm-brown core visible where bark has flaked off). **Same palette
  across all three variants** — weathered mid-age sticks with patchy
  dark-brown bark and warm-tan exposed wood, consistent look.
- Each individual stick: 12-22 cm long, 1-3 cm diameter, patchy bark,
  occasional side-twigs, matte finish
- Art style (Subnautica/NMS, stylized, matte painterly)
- Composition (single subject, 3/4 high-angle, #888 gray background,
  soft even studio lighting with subtle rim light)

**VARIES (QUANTITY and DISTRIBUTION):**
- V1: **sparse — 1-2 sticks alone**, spread apart, lots of empty space
- V2: **medium — 4-5 sticks** in loose natural scatter
- V3: **dense — 8-10 sticks** in a tight cluster/pile with overlap

---

## Variation 1 (Sparse — 1-2 sticks) — `reference_v1.png` → `mesh_v1.glb`

```
Just one or two dried alien branch sticks lying alone on the ground — a SPARSE composition with lots of empty space around them. Total footprint about 25 cm across and no more than 4 cm tall. Option A: a single stick ~18 cm long, 2 cm diameter, lying casually at a slight angle. Option B: two sticks — a main stick ~20 cm long and a small secondary stick ~8 cm placed a few centimeters away from it, not touching. The bark is weathered mid-age: patchy dark-brown bark still clinging to about half the length, the rest showing warm tan exposed dry wood. A couple of small side-twig stubs sprout off without leaves. The sticks read as individual, isolated fragments — the kind of debris you'd find along a path, not a pile. A couple of tiny bark flakes hint near the sticks. Reads as "a sparse find — one or two dried branches alone on alien ground."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — minimal sparse composition with one or two isolated weathered branches, slightly exaggerated for readability, matte bark and warm tan exposed-wood shading. Semi-realistic but painterly. Not photorealistic. CRITICAL: the SPARSENESS is the defining trait — this variant must look clearly less populous than variants 2 and 3.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire stick(s) visible with generous padding around them. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 2 (Medium — 4-5 sticks loose scatter) — `reference_v2.png` → `mesh_v2.glb`

```
A loose natural scatter of four or five dried alien branch sticks lying on the ground, together about 32 cm across and no more than 5 cm tall at the highest overlap. The sticks vary in length (12-22 cm) and thickness (1-3 cm diameter). Same weathered mid-age palette as the other variants: patchy dark-brown bark over warm tan exposed dry wood, consistent from stick to stick. The arrangement is casual and natural — one runs longways at the bottom, two cross diagonally over it, a fourth sits near one end, a fifth small stick lies off to one side. There is breathing room between them — they do not form a tight pile. A couple of bark flakes sit in the gaps. Reads as "a moderate scatter of dried branches — the everyday amount of debris on the alien forest floor."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — loose natural scatter of several weathered branches, slightly exaggerated for readability, matte bark and warm tan exposed-wood shading. Semi-realistic but painterly. Not photorealistic. Quantity feels the baseline/typical — clearly more than variant 1 (sparse) and clearly less than variant 3 (dense pile).

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire stick scatter visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 3 (Dense — 8-10 sticks, tight cluster/pile) — `reference_v3.png` → `mesh_v3.glb`

```
A tight cluster/pile of eight to ten dried alien branch sticks piled together on the ground, together about 35 cm across and up to 10 cm tall at the highest overlap. The sticks vary in length (12-22 cm) and thickness (1-3 cm diameter). Same weathered mid-age palette as the other variants: patchy dark-brown bark over warm tan exposed dry wood, consistent from stick to stick. The arrangement is denser and more disorganized than the loose scatter: many sticks overlap each other at multiple crossing points, some lie on top of others forming a small debris pile, the silhouette reads as a collapsed mini-heap rather than a scatter. Several small bark flakes and wood splinters sit in the gaps. Reads as "a significant accumulation of dried branches — a handful's worth of kindling piled up."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — dense pile of many weathered branches with complex overlap and layering, slightly exaggerated for readability, matte bark and warm tan exposed-wood shading. Semi-realistic but painterly. Not photorealistic. The DENSITY is the defining trait — many sticks, tightly stacked, clearly more than variants 1 and 2.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire stick pile visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Meshy Pipeline Settings

- Target polycount: **3000 triangles** (Fixed, not Adaptive)
- Topology: **Triangle**
- Preserve UV: yes
- Texture generation: PBR bake (baseColor + metallicRoughness + normal)
