# Flint Deposit (P01003) — Generation Prompts

## Style Anchor

Follow `assets/props/P00001/reference.png` as the **style anchor** for the
entire Farhaven prop set. Art style, lighting, background, and composition
must match. Only the silhouette/material changes per species.

Species identity: a **waxy-lustered flint nodule** partially exposed in
soil — formless/trigonal crystal, hardness 7, shatters with conchoidal
fracture, **waxy shine** (not metallic, not dull), diffused light
transmission (slight translucency at thin edges), **piezoelectric** (but
no visible glow), density 2.6. Common rarity, yields single flint_shard
per harvest with hammering_tool, no respawn.

## What varies / What stays fixed

**FIXED (material identity):**
- Color palette (desaturated blue-gray body with slight translucency at
  thin edges where darker blue-gray shows through, warm tan-brown earthy
  matrix where the nodule sits embedded in soil, faint cool cyan hint at
  the conchoidal fracture faces suggesting piezoelectric potential — no
  overt glow)
- Material (waxy-lustered surface on the exposed flint — not matte, not
  metallic, that characteristic resinous/waxy sheen of real flint; dull
  matte on the surrounding earth matrix)
- Scale (roughly fist-sized exposure, 12-20 cm across visible portion)
- Art style (Subnautica/NMS, stylized, matte + waxy flint highlight,
  painterly, not photorealistic)
- Composition (single subject, 3/4 high-angle, #888 gray background, soft
  even studio lighting with subtle cool rim light)

**VARIES (exposure / fracture pattern):**
- How much of the flint is exposed vs embedded
- Presence / prominence of conchoidal fracture faces
- Overall silhouette (rounded vs broken)

---

## Variation 1 (Baseline / rounded exposed nodule) — `reference_v1.png` → `mesh_v1.glb`

```
A flint nodule exposed in the ground, about 15 cm across. The shape is distinctly LUMPY and IRREGULAR — not smoothly rounded — with characteristic bulges, concavities, and angular protrusions typical of natural raw flint. The exposed surface has the glassy waxy luster unique to flint: near-black to dark blue-gray color with slight translucency at thin edges revealing a lighter blue-gray interior. Small shallow flake scars dot the surface where chips have weathered off naturally over time, each scar showing a subtle conchoidal arc curve. Faint cool cyan hints pool in a couple of the older flake scars. The nodule emerges from a small patch of warm tan-brown earthy matrix at its base — the visible flint is clearly a workable toolstone, not a rounded pebble. Reads as "raw flint, ready to strike and knap."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — clean organic shapes, slightly exaggerated silhouette for readability, matte shading on the earth matrix and distinctive waxy / resinous / glassy shading on the flint itself with subtle translucency at thin edges, alien planet geology with an otherworldly feel. Semi-realistic but painterly. Not photorealistic. Dark flint pops against the warm earthy matrix. Clean readable silhouette — unmistakably raw flint, irregular and sharp-edged.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire deposit visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 2 (Cracked showing conchoidal fracture) — `reference_v2.png` → `mesh_v2.glb`

```
A small alien flint deposit embedded in the ground. A flint nodule
about 18 cm across, mostly exposed above a small patch of warm tan-
brown earthy matrix, with a distinctive **conchoidal fracture face**
visible on one side — a smooth shallow curved scoop as if a flake has
been struck off, leaving a glossy waxy face with concentric arc
ripples characteristic of flint and obsidian fracture. The rest of the
surface is rounded and waxy-lustered, desaturated blue-gray. The
fracture face shows slightly translucent edges and a brighter cool
cyan hint catching the light — the piezoelectric property hinted
subtly through that one fresh scar. The earth matrix at the base is
dull matte with a few dislodged small shards scattered nearby. Reads
as "someone has already struck this one, and could strike again."

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading on the earth matrix and distinctive waxy
/ resinous shading on the flint itself, alien planet geology with an
otherworldly feel. Semi-realistic but painterly. Not photorealistic.
Cool blue-gray flint pops against the warm earthy matrix. Clean readable
silhouette — the conchoidal fracture face must be the focal detail.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire deposit visible with generous padding
around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 3 (Cluster of broken chunks) — `reference_v3.png` → `mesh_v3.glb`

```
A flint deposit exposed in the ground showing a CLUSTER of multiple broken flint chunks emerging from a common patch of warm tan-brown earthy matrix. Roughly five medium-sized flint chunks (each about 8-12 cm across) sit in the matrix, visibly fractured from a single parent nodule — several of them show distinctive conchoidal fracture faces (smooth curved scoops with concentric arc ripples characteristic of flint and obsidian fracture). Each chunk has the glassy waxy luster of flint, near-black to dark blue-gray with slight translucency at thin edges. Between the chunks the earthy matrix shows darker stained soil where flint dust and tiny flakes have accumulated over time. Subtle cool cyan hints on several of the fresh fracture faces. Total footprint about 28 cm wide. Reads as "a flint deposit in the middle of breaking apart — multiple workable pieces, all with sharp fresh fracture faces."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — clean organic shapes, slightly exaggerated silhouette for readability, matte shading on the earth matrix and distinctive waxy / resinous / glassy shading on the flint itself, alien planet geology with an otherworldly feel. Semi-realistic but painterly. Not photorealistic. Dark flint pops against the warm earthy matrix. Clean readable silhouette — a cluster of clearly-fractured sharp flint pieces, each one obviously workable.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire deposit visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Meshy Pipeline Settings

- Target polycount: **3000 triangles** (Fixed, not Adaptive)
- Topology: **Triangle**
- Preserve UV: yes
- Texture generation: PBR bake (baseColor + metallicRoughness + normal)
