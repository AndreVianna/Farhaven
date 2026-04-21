# Crevice Flower (P00042) — Generation Prompts

## Style Anchor

Follow `assets/props/P00001/reference.png` as the **style anchor** for the
entire Farhaven prop set. Art style, lighting, background, and composition
must match. Only the silhouette/material changes per species.

Species identity: a **tiny sparse alien flowering plant** that grows
from cracks in rock — small leaf rosette close to the ground with a
single slender stem rising barely above it, bearing a few small vivid
flowers. Signature Rocky biome plant. Reads as "small, stubborn, and
colorful against the gray." Plants at the top of slopes are exposed to
wind, so overall profile stays low. **UNCOMMON rarity**. Yields
flower_petals per harvest with bare hands.

## What varies / What stays fixed

**FIXED (species identity):**
- Form (small basal rosette of succulent-like leaves close to the ground
  + a slender stem 12-18 cm tall bearing a few small flowers at the top)
- Leaves are small, thick, fleshy, slightly curved — adapted for dry rock
- Overall footprint small (15-20 cm wide)
- Art style (Subnautica/NMS, stylized, matte painterly)
- Composition (single subject, 3/4 high-angle, #888 gray background,
  soft even studio lighting with subtle rim light)

**VARIES (reproductive cycle — fruiting plant):**
- V1: **flowering** — flowers open and vivid
- V2: **dormant** — no flowers, just the rosette + bare stem
- V3: **seeding** — flowers replaced by tiny alien seedpods

---

## Variation 1 (Flowering) — `reference_v1.png` → `mesh_v1.glb`

```
A small alien flowering plant growing on the ground, about 15 cm wide and 16 cm tall. At the base a compact rosette of six to eight small fleshy succulent-like leaves spreads close to the ground — each leaf about 3-4 cm long, thick, curved, in a muted sage-green with a hint of dusty blue-gray. From the center of the rosette rises a single slender greenish stem about 14 cm tall, with three or four small vivid magenta-pink four-petalled flowers arranged near the top — each flower only about 1.5-2 cm across, with a tiny golden-yellow center. The flowers are open and in full bloom. The overall silhouette is small, sparse, and delicate — a single plant standing alone, clearly adapted for harsh rocky conditions. Reads as "a stubborn tiny alien wildflower growing from a crack in the rocks."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — delicate small plant silhouette with fleshy succulent leaves at base and slender flowering stem, slightly exaggerated for readability, matte painterly shading on leaves contrasted with more saturated vivid flower color. Semi-realistic but painterly. Not photorealistic. The SMALL SPARSE silhouette is defining — this is not a bouquet, it's a single tiny plant.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire plant visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 2 (Dormant) — `reference_v2.png` → `mesh_v2.glb`

```
A small alien flowering plant growing on the ground in dormant state, about 14 cm wide and 12 cm tall. At the base a compact rosette of six to eight small fleshy succulent-like leaves spreads close to the ground — each leaf about 3-4 cm long, thick, curved, in the same muted sage-green with dusty blue-gray hint as the flowering variant. From the center of the rosette rises a single slender greenish stem about 10 cm tall, but this variant has NO flowers and NO buds — just the bare slender stem, its tip showing a subtle brownish old-growth scar where past flowers have fallen away. One or two of the basal leaves show slight dry curled tips, indicating the plant is resting between bloom cycles. The overall silhouette is even more minimal than the flowering variant. Reads as "the same tiny alien plant, resting between blooms."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — delicate small plant silhouette with fleshy succulent rosette and bare stem, slightly exaggerated for readability, muted greens throughout with the dormant tone reading clearly (no flower color). Semi-realistic but painterly. Not photorealistic.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire plant visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 3 (Seeding) — `reference_v3.png` → `mesh_v3.glb`

```
A small alien flowering plant growing on the ground in seeding state, about 16 cm wide and 18 cm tall. At the base a compact rosette of six to eight small fleshy succulent-like leaves spreads close to the ground — each leaf about 3-4 cm long, thick, curved, sage-green with dusty blue-gray hint. From the center of the rosette rises a single slender greenish stem about 16 cm tall, but where the flowers would have been in variant 1 there are now three or four tiny alien seedpods — small elongated capsules about 1.5 cm long each, in a warm tawny-brown color with subtle ribbed texture, one of them slightly split open at the top showing fine dusty seeds ready to disperse. A couple of the basal leaves show slightly ruddy autumnal tinting. The overall silhouette matches the flowering variant but the "color pop" at the top is now warm brown pods instead of magenta flowers. Reads as "the same tiny alien plant, past bloom, releasing seeds."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — delicate small plant silhouette with fleshy succulent rosette and slender stem tipped with seedpods, slightly exaggerated for readability, muted greens contrasted with warm tawny seedpods. Semi-realistic but painterly. Not photorealistic. The reproductive-cycle difference from the flowering variant must be clear at a glance.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire plant visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Meshy Pipeline Settings

- Target polycount: **3000 triangles** (Fixed, not Adaptive)
- Topology: **Triangle**
- Preserve UV: yes
- Texture generation: PBR bake (baseColor + metallicRoughness + normal)
