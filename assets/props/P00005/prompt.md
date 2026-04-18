# Stalk Plant (P00005) — Generation Prompts

## Style Anchor

Follow `assets/props/P00001/reference.png` as the **style anchor** for the
entire Farhaven prop set. Art style, lighting, background, and composition
must match. Only the silhouette/biology changes per species.

Species identity: tall (2–3 m) **treelike single-stalk plant** with a rigid
woody column and a narrow crown of upward-pointing fronds — column growth
form, rigid, inedible (edibility_level=0), hydration_level=3, radial
symmetry, yields wood and fiber when cut.

## What varies / What stays fixed

**FIXED (species identity):**
- Color palette (cream-to-tan woody stalk with darker concentric banding
  rings, fronds in desaturated olive-sage with faint teal bioluminescent
  venation near the tips)
- Material (rigid woody stalk surface with faint fibrous striation; fronds
  fibrous and slightly stiff, not limp)
- Overall growth form (single thick central column, narrow upward-pointing
  frond crown at the top, no lower branches)
- "Alien tree-stalk" feel — like bamboo crossed with a narrow palm
- Art style (Subnautica/NMS, stylized, matte, painterly, not photorealistic)
- Composition (single subject, 3/4 high-angle, #888 gray background, soft
  even studio lighting with subtle cool rim light)

**VARIES (individual biological variation):**
- Stalk height and thickness (young/thin vs old/thick)
- Frond count and spread (sparse narrow crown vs dense spread)
- Presence and prominence of banding rings on the stalk
- Overall silhouette proportions within the ~2–3 m tall range

---

## Variation 1 (Baseline / mature 2 m) — `reference_v1.png` → `mesh_v1.glb`

```
A tall alien treelike plant growing from the ground. A single rigid
woody stalk, roughly 2 m tall and 18 cm thick, cream-to-tan in color
with subtle darker concentric banding rings every 20 cm or so along
its length. The stalk is straight and vertical, with a faint fibrous
striation running lengthwise on its surface. At the top, a narrow
crown of roughly eight upward-pointing fibrous fronds spreads outward
at a tight angle — each frond about 40 cm long, desaturated olive-sage
green, stiff (not drooping), with faint teal bioluminescent venation
near the tips catching the light softly. Overall radial symmetry,
clean vertical silhouette like bamboo crossed with a narrow palm. No
lower branches. Plant is approximately 2 m tall and 50 cm wide at the
frond crown.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading on the stalk, alien planet flora with an
otherworldly feel. Semi-realistic but painterly. Not photorealistic.
Warm tan stalk against cooler sage fronds. Clean readable silhouette.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire plant visible with generous padding around
it — frame vertically to fit the full height. No other elements, no
text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 2 (Young / shorter, denser frond crown) — `reference_v2.png` → `mesh_v2.glb`

```
A tall alien treelike plant growing from the ground. A single rigid
woody stalk, roughly 1.6 m tall and 14 cm thick, cream-to-tan with
faint darker concentric banding rings along its length. The stalk is
straight and vertical, faint fibrous striation on its surface. At the
top, a denser crown of roughly twelve upward-pointing fibrous fronds
spreads outward in a tight bundle — each frond about 35 cm long,
desaturated olive-sage green, stiff, with bright teal bioluminescent
venation near the tips. The crown reads as young and full — more fronds
than a mature specimen, packed closer together. Overall radial symmetry.
No lower branches. Plant is approximately 1.6 m tall and 45 cm wide
at the crown.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading on the stalk, alien planet flora with an
otherworldly feel. Semi-realistic but painterly. Not photorealistic.
Warm tan stalk against cooler sage fronds. Clean readable silhouette.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire plant visible with generous padding around
it — frame vertically to fit the full height. No other elements, no
text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 3 (Old / taller, sparse crown, prominent rings) — `reference_v3.png` → `mesh_v3.glb`

```
A tall alien treelike plant growing from the ground. A single rigid
woody stalk, roughly 2.8 m tall and 22 cm thick, cream-to-tan with
pronounced darker concentric banding rings clearly visible every
20–25 cm along its length — the stalk reads as old and weathered.
The stalk is mostly straight but has a very slight natural lean.
At the top, a sparser crown of only five long upward-pointing fibrous
fronds spreads outward at a wider angle — each frond about 55 cm long,
desaturated olive-sage with darker tips, stiff but slightly drooped
outward at the ends, with faint teal bioluminescent venation. Reads
as a mature elder specimen. No lower branches. Plant is approximately
2.8 m tall and 60 cm wide at the crown.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading on the stalk, alien planet flora with an
otherworldly feel. Semi-realistic but painterly. Not photorealistic.
Warm tan stalk against cooler sage fronds. Clean readable silhouette.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire plant visible with generous padding around
it — frame vertically to fit the full height. No other elements, no
text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Meshy Pipeline Settings

- Target polycount: **3000 triangles** (Fixed, not Adaptive)
- Topology: **Triangle**
- Preserve UV: yes
- Texture generation: PBR bake (baseColor + metallicRoughness + normal)
