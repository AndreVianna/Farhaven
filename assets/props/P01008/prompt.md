# Obsidian Shard (P01008) — Generation Prompts

## Style Anchor

Follow `assets/props/P00001/reference.png` as the **style anchor** for the
entire Farhaven prop set. Art style, lighting, background, and composition
must match. Only the silhouette/material changes per species.

Species identity: a chunk of **volcanic alien obsidian** — glossy black
glass with razor-sharp conchoidal fractures. The defining trait is the
glossy black surface with hints of iridescent rainbow sheen catching the
light, contrasted against the matte finish of most other props. Reads
as "dangerous, sharp, glassy." **UNCOMMON rarity**. Yields obsidian
shards per harvest with stone_breaking_tool.

## What varies / What stays fixed

**FIXED (material identity):**
- Material (glossy deep-black volcanic glass with visible conchoidal
  fractures — the characteristic curved fracture surfaces of natural
  obsidian — and razor-sharp edges)
- Subtle iridescent rainbow sheen visible on some fracture faces where
  the angle catches the studio light (hints of cyan, magenta, gold)
- Scale (18-28 cm across)
- Art style (Subnautica/NMS, stylized, glossy contrasted with matte
  surroundings, painterly)
- Composition (single subject, 3/4 high-angle, #888 gray background,
  soft even studio lighting with subtle rim light)

**VARIES (shard shape):**
- V1: **single large angular wedge** — one dominant sharp shape
- V2: **fractured cluster of several shards** — broken apart
- V3: **irregular multi-facet chunk** — natural blocky mass with
  randomly oriented fracture planes, NOT a layered or organized form

---

## Variation 1 (Single large angular wedge) — `reference_v1.png` → `mesh_v1.glb`

```
A single large angular wedge of glossy deep-black volcanic obsidian resting on the ground, about 25 cm across and 18 cm tall. The silhouette is sharply angular with one dominant pointed ridge running along the top edge and several clean conchoidal fractures — the characteristic smooth curved fracture surfaces of natural obsidian — defining the visible faces. The surface is glossy black, reflective enough to catch the studio light with clear highlights, and a subtle iridescent rainbow sheen (faint cyan, magenta, and gold) reads on the two largest fracture faces where the light hits at the right angle. The edges between faces read as razor-sharp. A couple of tiny black obsidian chips sit at the base near the sharpest edge. Reads as "a single dangerous glassy shard of alien volcanic stone."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — sharp angular silhouette with glossy black glass material and subtle iridescent highlights, slightly exaggerated for readability, glossy black shading contrasted against the muted palette. Semi-realistic but painterly. Not photorealistic. The glossy quality and razor edges are the defining visual features.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire wedge visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 2 (Fractured cluster) — `reference_v2.png` → `mesh_v2.glb`

```
A cluster of several angular glossy black obsidian shards grouped on the ground, together about 26 cm across, as if a larger piece has broken apart and the fragments stayed close. One dominant central shard (about 18 cm) is flanked by three or four smaller shards leaning against it at various angles. Each shard has clean conchoidal fracture faces and razor-sharp edges. The glossy deep-black surfaces catch the studio light with sharp highlights, and subtle iridescent rainbow sheen (faint cyan, magenta, gold) plays across a few of the larger fracture faces. A handful of tiny obsidian chips sit scattered around the base of the cluster. Reads as "broken volcanic glass cluster — several sharp shards clumped together."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — multiple sharp angular shards arranged compositionally with glossy black glass material, slightly exaggerated for readability, glossy shading with iridescent accents. Semi-realistic but painterly. Not photorealistic.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire cluster visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 3 (Irregular multi-facet chunk) — `reference_v3.png` → `mesh_v3.glb`

```
An irregular chunky mass of glossy deep-black volcanic obsidian resting on the ground, about 24 cm across and 18 cm tall. The silhouette is a single asymmetric blocky chunk with MANY RANDOMLY ORIENTED fracture planes covering its surface — no two faces parallel, no organized layering, just a natural rough lumpy mass that has split and fractured along irregular planes as volcanic glass does. Some faces are small (a few cm), some are larger, some meet at acute angles forming sharp ridges, some meet at obtuse angles forming broader faces. The overall shape reads as "a random chunk that broke off a larger flow" — NOT decorative, NOT organized, NOT fan-shaped. The glossy deep-black surfaces catch the studio light with sharp highlights on each face, and subtle iridescent rainbow sheen (faint cyan, magenta, gold) plays across a few of the larger faces. Razor-sharp edges read dangerously. A couple of tiny obsidian chips sit at the base. Reads as "a natural chunk of alien volcanic glass — irregular, lumpy, many-sided."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — irregular asymmetric blocky mass with many randomly oriented small-to-medium fracture faces, slightly exaggerated for readability, glossy black glass material with iridescent accents on a few faces. Semi-realistic but painterly. Not photorealistic. CRITICAL: the form must read NATURAL and RANDOM, not decorative or organized in any way.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire chunk visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Meshy Pipeline Settings

- Target polycount: **3000 triangles** (Fixed, not Adaptive)
- Topology: **Triangle**
- Preserve UV: yes
- Texture generation: PBR bake (baseColor + metallicRoughness + normal)
