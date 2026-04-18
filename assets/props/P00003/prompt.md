# Seed Pod Bush (P00003) — Generation Prompts

## Style Anchor

Follow `assets/props/P00001/reference.png` as the **style anchor** for the
entire Farhaven prop set. Art style, lighting, background, and composition
must match. Only the silhouette/biology changes per species.

Species identity: knee-high woody bush bearing **fleshy oval seed pods**
hanging from slender branches — food source, flexible outer stems, radial
growth habit, hydration_level=4 (moderate), edibility_level=6 (good food).

## What varies / What stays fixed

**FIXED (species identity):**
- Color palette (warm olive-brown woody stems, pods in soft rose/coral/amber
  with faint translucence where pulp shows through, hints of cyan
  bioluminescent spots on pod skin)
- Material (woody flexible stems, fleshy semi-translucent pods)
- Overall growth form (radial multi-stem bush, upright branching)
- Pod shape (smooth elongated oval pods, 6–10 cm long, hanging or perched
  on branches)
- Art style (Subnautica/NMS, stylized, matte + subtle subsurface on pods,
  painterly, not photorealistic)
- Composition (single subject, 3/4 high-angle, #888 gray background, soft
  even studio lighting with subtle cool rim light)

**VARIES (individual biological variation):**
- Number and density of pods
- Ratio of visible branch structure to pod mass
- Pod maturity (closed and swollen vs cracked and showing pulp)
- Overall size within the ~60–80 cm tall / 50–70 cm wide range

---

## Variation 1 (Baseline / medium laden) — `reference_v1.png` → `mesh_v1.glb`

```
A knee-high alien bush growing from the ground. A woody, multi-stemmed
plant with five to seven upright olive-brown branches radiating from a
central base, each branch carrying several smooth oval seed pods. The
pods are fleshy and slightly translucent, 6–10 cm long, in a warm rose
to coral color with pale amber highlights where pulp shows faintly
through the skin; a handful of tiny cyan bioluminescent spots dot the
pod surfaces, catching the light. Overall radial symmetry. Plant is
approximately 70 cm tall and 60 cm wide at the canopy.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading with subtle subsurface scattering on the
pods, alien planet flora with an otherworldly feel. Semi-realistic but
painterly. Not photorealistic. Warm pod colors pop against the muted
earth-tone stems. Clean readable silhouette.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire plant visible with generous padding around
it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 2 (Young / sparse pods, more branch) — `reference_v2.png` → `mesh_v2.glb`

```
A knee-high alien bush growing from the ground. A woody, multi-stemmed
plant with four or five upright olive-brown branches radiating from a
central base; each branch carries only one to three small unripe seed
pods clustered near the branch tip. The pods are tightly closed, smaller
(about 5 cm long), firmer, and more saturated in color — deep rose with
minimal pulp-glow — indicating youth. The branching structure is clearly
visible, the plant reading as young and still filling in. A handful of
tiny cyan bioluminescent spots dot the pod skins. Overall radial symmetry.
Plant is approximately 60 cm tall and 50 cm wide — a bit leaner than a
mature specimen.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading with subtle subsurface scattering on the
pods, alien planet flora with an otherworldly feel. Semi-realistic but
painterly. Not photorealistic. Warm pod colors pop against the muted
earth-tone stems. Clean readable silhouette.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire plant visible with generous padding around
it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 3 (Mature / laden, some cracked) — `reference_v3.png` → `mesh_v3.glb`

```
A knee-high alien bush growing from the ground. A woody, multi-stemmed
plant heavy with ripe seed pods. Six to eight olive-brown branches
radiate from the central base, each drooping slightly under the weight
of many oval pods — a dozen or more pods visible in total, grouped in
clusters along each branch. Several pods have cracked open along their
length, revealing a glimpse of glowing amber pulp inside with small
embedded seeds; the cracked pods read as ripe and ready to harvest.
Other pods remain closed and swollen. Cyan bioluminescent spots dot
the pod skins. Overall radial symmetry but with a laden, slightly
sagging silhouette. Plant is approximately 75 cm tall and 70 cm wide —
the most massed of the three variants.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading with subtle subsurface scattering on the
pods, alien planet flora with an otherworldly feel. Semi-realistic but
painterly. Not photorealistic. Warm pod colors pop against the muted
earth-tone stems. Clean readable silhouette.

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
