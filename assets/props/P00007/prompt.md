# Spiral Fern (P00007) — Generation Prompts

## Style Anchor

Follow `assets/props/P00001/reference.png` as the **style anchor** for the
entire Farhaven prop set. Art style, lighting, background, and composition
must match. Only the silhouette/biology changes per species.

Species identity: fern-like plant with **tightly coiled logarithmic-spiral
fronds** ("fiddleheads") — flexible, radial symmetry, rosette growth form,
inedible (edibility_level=0, toxicity_level=0), hydration_level=5,
uncommon rarity, decoration tag. Yields single fern_frond per harvest
with 4-day respawn. The signature feature is the **Fibonacci coil**.

## What varies / What stays fixed

**FIXED (species identity):**
- Color palette (deep forest teal/turquoise body, pronounced silver-cyan
  bioluminescent veining tracing the spiral curves of each frond, darker
  emerald-green at the thick base stem)
- Material (smooth fibrous stems, slightly translucent tips near the
  tightest part of the coil, matte with a subtle silvery sheen along
  the veining)
- Overall growth form (clump of upright curled fronds rising from a
  central base, each frond ending in a perfect logarithmic spiral coil
  — like a fiddlehead fern but more mathematically precise)
- Signature: **the logarithmic / Fibonacci spiral** at each frond tip
  must be readable and prominent
- "Alien fern" feel — striking, ornamental, strange
- Art style (Subnautica/NMS, stylized, matte with subtle subsurface on
  coil tips, painterly, not photorealistic)
- Composition (single subject, 3/4 high-angle, #888 gray background, soft
  even studio lighting with subtle cool rim light)

**VARIES (individual biological variation):**
- Number of fronds and their heights
- How tightly vs loosely coiled the spiral tips are
- Mix of young (tight) and older (partially uncurled) fronds
- Overall cluster height within the ~30-60 cm range

---

## Variation 1 (Baseline / mixed heights) — `reference_v1.png` → `mesh_v1.glb`

```
An alien fern-like plant growing from the ground. A clump of roughly
seven upright curled fronds rising from a central dark emerald-green
base. Each frond is a smooth fibrous deep-teal stem that ends at its
tip in a **tight logarithmic Fibonacci spiral coil** — the coil is
clearly visible as a mathematically-precise spiral, about 3-5 cm in
diameter at the tip of each frond. Pronounced silver-cyan
bioluminescent veining traces the spiral curves of each coil, glowing
softly. The fronds vary in height (tallest about 45 cm, shortest about
20 cm), all pointing upward and slightly outward in a radial spread.
The coil tips are slightly translucent, catching the light. Overall
radial symmetry from above. Plant is approximately 45 cm tall and
30 cm wide — a typical specimen.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading with subtle translucence at the coil
tips, alien planet flora with an otherworldly feel. Semi-realistic but
painterly. Not photorealistic. Deep teal pops against the muted
palette; silver-cyan veining glows softly along the spiral curves.
Clean readable silhouette — the spiral coils must be the focal point.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire plant visible with generous padding around
it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 2 (Young / tightly coiled) — `reference_v2.png` → `mesh_v2.glb`

```
An alien fern-like plant growing from the ground. A compact tight
cluster of roughly five shorter fronds (all about 25 cm tall), rising
straight up from a central dark emerald-green base. Each frond ends
in an extremely tight, compact **logarithmic Fibonacci spiral coil** —
the coils are smaller (about 2-3 cm in diameter) and more tightly
wound, reading as young and still unfurling. The stems are thicker
and more saturated — vivid deep teal — with bright silver-cyan
bioluminescent veining prominently tracing each spiral curve. The
coil tips are noticeably translucent, glowing from within. Overall
very vertical cluster silhouette, radial symmetry from above. Plant
is approximately 25 cm tall and 20 cm wide — compact and young.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading with subtle translucence at the coil
tips, alien planet flora with an otherworldly feel. Semi-realistic but
painterly. Not photorealistic. Deep teal pops against the muted
palette; silver-cyan veining glows softly along the spiral curves.
Clean readable silhouette — the spiral coils must be the focal point.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire plant visible with generous padding around
it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 3 (Mature / mix of coiled and uncurled) — `reference_v3.png` → `mesh_v3.glb`

```
An alien fern-like plant growing from the ground. A tall open cluster
of roughly six fronds rising from a central dark emerald-green base.
Three of the fronds are long (about 55 cm tall) and their tips have
**fully uncurled** from spirals into graceful arching blades — the
arching blades are feather-textured along the former spiral curve and
gently droop outward at the very end. The other three fronds are
shorter (about 35 cm) and still end in open, looser **logarithmic
Fibonacci spiral coils** (about 4-6 cm in diameter) that read as
mid-unfurling. The overall silhouette reads mature — some old fronds
fully uncurled, some still coiling. Silver-cyan bioluminescent veining
is visible on both the coils and the spine of the uncurled blades.
The coil tips remain slightly translucent. Plant is approximately
55 cm tall and 50 cm wide — taller and broader than a typical specimen.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading with subtle translucence at the coil
tips, alien planet flora with an otherworldly feel. Semi-realistic but
painterly. Not photorealistic. Deep teal pops against the muted
palette; silver-cyan veining glows softly along the spiral curves and
uncurled blade spines. Clean readable silhouette — the mix of spirals
and arching blades must be clearly distinct.

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
