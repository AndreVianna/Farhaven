# Loose Stone (P01002) — Generation Prompts

## Style Anchor

Follow `assets/props/P00001/reference.png` as the **style anchor** for the
entire Farhaven prop set. Art style, lighting, background, and composition
must match. Only the silhouette/material changes per species.

Species identity: a small **pile of fist-sized weathered stones** —
irregular crystal form, hardness 6, shatters, dull surface, blocked light,
density 2.7. Same material as Boulder but broken into workable pieces.
Yields 2 stone_piece per harvest, no respawn.

## What varies / What stays fixed

**FIXED (material identity):**
- Color palette (same warm gray as Boulder, with subtle rust-orange
  oxidation and faint cyan-green mineral vein hints)
- Material (matte dull stone, same as Boulder)
- Stone unit shape (rounded fist-sized river-tumbled pieces, roughly
  10-18 cm across each)
- Art style (Subnautica/NMS, stylized, matte, painterly, not photorealistic)
- Composition (single subject, 3/4 high-angle, #888 gray background, soft
  even studio lighting with subtle cool rim light)

**VARIES (arrangement / count):**
- Number of stones in the pile
- Distribution (tight pile vs spread cluster)
- Size variance within the pile
- Overall footprint within the ~35-55 cm range

---

## Variation 1 (Baseline / medium pile) — `reference_v1.png` → `mesh_v1.glb`

```
A small alien stone pile resting on the ground. Roughly seven fist-sized
weathered gray stones piled together in a loose cluster, each stone
about 12-14 cm across, rounded from tumbling and water-wear. The stones
are stacked naturally — two or three on the bottom, a few leaning
against each other on top, one perched at the peak. Warm gray color
with subtle rust-orange oxidation streaks and faint pale cyan-green
mineral vein hints visible on a couple of the stones. Matte dull
surface, no metallic sheen. The pile is approximately 25 cm tall and
40 cm wide at the base — reading as a typical hand-gatherable rock
pile.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading with no metallic sheen, alien planet
geology with an otherworldly feel. Semi-realistic but painterly. Not
photorealistic. Warm gray body with warm rust highlights against the
muted palette. Clean readable silhouette — clearly a pile of workable
stones, not a single boulder.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire pile visible with generous padding around
it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 2 (Dense small scree) — `reference_v2.png` → `mesh_v2.glb`

```
A small alien stone scatter resting on the ground. Roughly twelve
smaller weathered gray stones (each 8-10 cm across) spread in a dense
loose scree pattern rather than a pile — the stones are mostly single-
layer, touching or slightly overlapping but not stacked high. Warm
gray color with subtle rust-orange oxidation and faint pale cyan-green
mineral vein hints across the group. The stones are rounded but
slightly more angular than the baseline pile, reading as newer and
less tumbled. Matte dull surface. Footprint is wider and flatter —
approximately 15 cm tall and 50 cm wide — reading as freshly scattered
ground debris.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading with no metallic sheen, alien planet
geology with an otherworldly feel. Semi-realistic but painterly. Not
photorealistic. Warm gray body with warm rust highlights against the
muted palette. Clean readable silhouette — a flat scatter, not a tall pile.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire scatter visible with generous padding around
it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 3 (Natural scatter, no stacking) — `reference_v3.png` → `mesh_v3.glb`

```
A small natural scatter of alien weathered stones resting on the ground. Six stones total in mixed sizes — one about 20 cm across, three about 12 cm, two smaller ones about 7 cm — distributed naturally across a small area where they have settled after weathering out of a parent outcrop. **The stones are NOT stacked or piled on each other** — each rests flat on the ground in its own place, no balancing, no human arrangement. Slightly angular edges suggesting recent natural fracture. Warm gray color with subtle rust-orange oxidation streaks on a couple of them, faint pale cyan-green mineral vein hints visible on the larger stone. Matte dull surface, no metallic sheen. Footprint approximately 20 cm tall and 55 cm wide. Reads as "purely natural debris — nothing has been arranged here."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — clean organic shapes, slightly exaggerated silhouette for readability, matte shading with no metallic sheen, alien planet geology with an otherworldly feel. Semi-realistic but painterly. Not photorealistic. Warm gray body with warm rust highlights against the muted palette. Clean readable silhouette — an organic natural scatter, not a stack or pyramid.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire scatter visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Meshy Pipeline Settings

- Target polycount: **3000 triangles** (Fixed, not Adaptive)
- Topology: **Triangle**
- Preserve UV: yes
- Texture generation: PBR bake (baseColor + metallicRoughness + normal)
