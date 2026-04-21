# Rock Lichen (P00043) — Generation Prompts

## Style Anchor

Follow `assets/props/P00001/reference.png` as the **style anchor** for the
entire Farhaven prop set. Art style, lighting, background, and composition
must match. Only the silhouette/material changes per species.

Species identity: a **cluster of flat alien lichen patches** — meant to
be applied as scatter/decal on top of existing rock surfaces in-game.
**CRITICAL: no stone base in the image — just the lichen patches
themselves.** Reads as "tiny, flat, colorful painterly stains that
would live on a rock." **COMMON rarity**. Yields lichen per harvest
with bare hands.

## What varies / What stays fixed

**FIXED (species identity):**
- Form (a cluster of 4-5 flat crustose lichen colonies directly on the
  neutral gray background — NO rock base, NO stone, NO ground plane,
  NO visible supporting surface. The lichen patches must read as flat
  organic stains floating alone, ready to be mapped onto any rock
  surface in-engine.)
- Lichen morphology: crustose (flat, paint-like, tightly adhered to a
  surface) with characteristic crinkled-scaly texture and slightly
  lobed/ruffled edges
- Scale (overall cluster about 20-25 cm across; each patch 3-7 cm)
- Art style (Subnautica/NMS, stylized, matte painterly)
- Composition (single subject, 3/4 high-angle, #888 gray background,
  soft even studio lighting with subtle rim light)

**VARIES (lichen color — visual-only, no life cycle — pick vivid but
alien-believable tones):**
- V1: **mustard-yellow and rust-orange** lichens
- V2: **sage-green and teal** lichens
- V3: **pale-blue and white** crustose lichens

---

## Variation 1 (Mustard-yellow and rust-orange) — `reference_v1.png` → `mesh_v1.glb`

```
A cluster of four or five flat alien crustose lichen patches, floating alone on the pure neutral gray background — NO rock base, NO stone, NO ground, NO supporting surface of any kind. Each patch is a flat paint-like colony 3-6 cm across, tightly adhered to an imagined surface (the surface itself is not shown). The patches are arranged loosely in a roughly circular group about 22 cm across, with a few overlapping edges between neighboring colonies. Two patches are vivid mustard-yellow, two are rust-orange with darker red-brown centers, and one shows a transitional mix where mustard blends into rust at a shared colony edge. Each colony has crinkled scaly surface texture and slightly ruffled or lobed edges typical of crustose lichen. A few tiny detached lichen flakes sit in the gaps between colonies. The lichen colors pop against the neutral gray without feeling cartoonish — they feel like organic mineral-paint. Reads as "flat alien lichen patches, ready to be mapped onto a rock in-game."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — FLAT crustose lichen patches isolated from any rock base, slightly exaggerated for readability, slightly crinkled flat organic painterly shading. Semi-realistic but painterly. Not photorealistic. CRITICAL: NO rock, NO stone, NO ground plane, NO background beyond the studio gray. The lichen cluster alone.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire lichen cluster visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 2 (Sage-green and teal) — `reference_v2.png` → `mesh_v2.glb`

```
A cluster of five or six flat alien crustose lichen patches, floating alone on the pure neutral gray background — NO rock base, NO stone, NO ground, NO supporting surface. Each patch is a flat paint-like colony 3-6 cm across, tightly adhered to an imagined surface. The patches are arranged loosely in a roughly circular group about 24 cm across, with overlapping edges between neighboring colonies. Two patches are sage-green, two are muted teal-green, and one or two smaller patches are a slightly brighter moss-green — all cool tones harmonizing against the gray background. Each colony has crinkled scaly surface texture and slightly ruffled or lobed edges. A few tiny detached lichen flakes in the gaps. Reads as "flat alien alpine lichen patches, ready to be mapped onto a rock in-game."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — FLAT crustose lichen patches isolated from any rock base, slightly exaggerated for readability, slightly crinkled flat organic painterly shading. Semi-realistic but painterly. Not photorealistic. CRITICAL: NO rock, NO stone, NO ground plane. The lichen cluster alone.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire lichen cluster visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 3 (Pale-blue and white crustose) — `reference_v3.png` → `mesh_v3.glb`

```
A cluster of four or five flat alien crustose lichen patches, floating alone on the pure neutral gray background — NO rock base, NO stone, NO ground, NO supporting surface. Each patch is a flat paint-like colony 3-7 cm across, tightly adhered to an imagined surface. The patches are arranged loosely in a roughly circular group about 22 cm across, with overlapping edges between neighboring colonies. Two patches are pale sky-blue, two are bone-white, and one transitional patch shows the two colors blending along a shared colony boundary. Each colony has crinkled scaly surface texture and slightly ruffled or lobed edges. The overall palette reads as alpine-frost, ghostly and restrained against the neutral gray background. A few tiny detached lichen flakes in the gaps. Reads as "flat alien frost-touched lichen patches, ready to be mapped onto a rock in-game."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — FLAT crustose lichen patches isolated from any rock base, slightly exaggerated for readability, slightly crinkled flat organic painterly shading. Semi-realistic but painterly. Not photorealistic. CRITICAL: NO rock, NO stone, NO ground plane. The lichen cluster alone.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire lichen cluster visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Meshy Pipeline Settings

- Target polycount: **3000 triangles** (Fixed, not Adaptive)
- Topology: **Triangle**
- Preserve UV: yes
- Texture generation: PBR bake (baseColor + metallicRoughness + normal)
