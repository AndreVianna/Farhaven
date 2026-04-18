# Wild Herb (P00006) — Generation Prompts

## Style Anchor

Follow `assets/props/P00001/reference.png` as the **style anchor** for the
entire Farhaven prop set. Art style, lighting, background, and composition
must match. Only the silhouette/biology changes per species.

Species identity: small ground-level **rosette of soft aromatic alien herb
leaves** — flexible, radial symmetry, rosette growth form, hydration_level=5
(moderate-moist), edibility_level=4 (edible in small amounts),
toxicity_level=2 (mild). Uncommon rarity. Yields single herb_leaf per
harvest with 3-day respawn.

## What varies / What stays fixed

**FIXED (species identity):**
- Color palette (desaturated sage-mint green body, subtle silvery
  bioluminescent veins along each leaf's central rib, faint dusty violet
  tint at the leaf bases where they meet the central node)
- Material (soft, fibrous, slightly fuzzy surface — hairy not waxy)
- Overall growth form (radial ground-level rosette with leaves pointing
  outward and slightly upward, no central stem)
- Leaf shape (oval-to-lanceolate, rounded tips, gently serrated edges,
  ~6-10 cm long)
- "Alien herb" feel — delicate, aromatic, low
- Art style (Subnautica/NMS, stylized, matte, painterly, not photorealistic)
- Composition (single subject, 3/4 high-angle, #888 gray background, soft
  even studio lighting with subtle cool rim light)

**VARIES (individual biological variation):**
- Number of leaves and tightness of arrangement
- Leaf maturity (tightly folded young vs open curled mature)
- Overall diameter within the ~20-35 cm range
- Presence/prominence of bioluminescent veining

---

## Variation 1 (Baseline / medium rosette) — `reference_v1.png` → `mesh_v1.glb`

```
A small alien herb plant growing from the ground. A flat ground-level
radial rosette of roughly nine soft oval-to-lanceolate leaves, each
about 8 cm long, emerging from a central node and spreading outward
and slightly upward. The leaves are desaturated sage-mint green, fuzzy
and matte, with gently serrated edges and rounded tips; a subtle
silvery bioluminescent vein runs down the center rib of each leaf,
catching the light faintly. A faint dusty violet tint pools where
the leaves meet the central node. Overall radial symmetry, low to
the ground. Plant is approximately 6 cm tall and 25 cm wide — reading
as a typical mature specimen.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading with a slightly fuzzy surface quality,
alien planet flora with an otherworldly feel. Semi-realistic but
painterly. Not photorealistic. Sage-mint green pops gently against
the muted palette. Clean readable silhouette.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire plant visible with generous padding around
it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 2 (Young / tight compact) — `reference_v2.png` → `mesh_v2.glb`

```
A small alien herb plant growing from the ground. A tightly-packed
ground-level radial rosette of roughly fourteen smaller, newer leaves
(about 5 cm long each), emerging from a central node in a compact
bundle. The leaves are stiff and angled more upward than outward,
reading as young and still filling in. Color is a more saturated
sage-mint green — younger growth — with prominent silvery
bioluminescent veins down each leaf's central rib. Faint dusty violet
tint at the center where leaves meet. Overall radial symmetry, very
low-profile. Plant is approximately 5 cm tall and 18 cm wide — more
compact than a typical specimen.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading with a slightly fuzzy surface quality,
alien planet flora with an otherworldly feel. Semi-realistic but
painterly. Not photorealistic. Sage-mint green pops gently against
the muted palette. Clean readable silhouette.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire plant visible with generous padding around
it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 3 (Mature / open sprawl) — `reference_v3.png` → `mesh_v3.glb`

```
A small alien herb plant growing from the ground. An open ground-level
radial rosette of roughly seven larger mature leaves (about 11 cm
long each), emerging from a central node and splaying outward almost
flat to the ground — the leaves are wide and slightly drooping at
the tips, reading as mature and sun-soaked. Color is a softer, more
muted sage-mint green with visible silvery bioluminescent veins down
the central ribs, plus the faint dusty violet tint at the center.
The edges of some older leaves curl slightly downward. Overall radial
symmetry, very wide footprint. Plant is approximately 4 cm tall and
35 cm wide — flatter and broader than a typical specimen.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading with a slightly fuzzy surface quality,
alien planet flora with an otherworldly feel. Semi-realistic but
painterly. Not photorealistic. Sage-mint green pops gently against
the muted palette. Clean readable silhouette.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire plant visible with generous padding around
it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Meshy Pipeline Settings

- Target polycount: **3000 triangles** (Fixed, not Adaptive)
- Topology: **Triangle**
- Preserve UV: yes
- Texture generation: PBR bake (baseColor + metallicRoughness + normal)
