# Thorn Shrub (P00004) — Generation Prompts

## Style Anchor

Follow `assets/props/P00001/reference.png` as the **style anchor** for the
entire Farhaven prop set. Art style, lighting, background, and composition
must match. Only the silhouette/biology changes per species.

Species identity: low, compact **radial burst of rigid needle-like thorns**
emerging from a dark woody base — defensive hazard, rigid, dry
(hydration_level=2), edibility_level=0, toxicity_level=4, radial symmetry,
growth form "tree" (single-point woody origin).

## What varies / What stays fixed

**FIXED (species identity):**
- Color palette (charred dark-umber woody base, thorns in pale bone/amber
  with darker tips, faint dusty violet sheen at the base of each thorn)
- Material (rigid glossy thorns, matte woody base)
- Overall growth form (radial burst from a single low woody node)
- "Hazard plant" silhouette — visibly dangerous, sharp, bristling
- Art style (Subnautica/NMS, stylized, matte, painterly, not photorealistic)
- Composition (single subject, 3/4 high-angle, #888 gray background, soft
  even studio lighting with subtle cool rim light)

**VARIES (individual biological variation):**
- Number of thorns and spacing between them
- Length vs thickness ratio of thorns
- Curvature (straight spikes vs slightly arched)
- Overall diameter within the ~40–60 cm range

---

## Variation 1 (Baseline / medium burst) — `reference_v1.png` → `mesh_v1.glb`

```
A low alien shrub growing from the ground. A compact radial burst of
roughly twenty stiff, needle-like thorns emerging from a dark umber
woody base, spreading outward and slightly upward like a spiky sea-urchin
silhouette. Each thorn is about 15 cm long, rigid, glossy, pale bone to
warm amber in color with a darker tip; a faint dusty violet sheen pools
where the thorn meets the woody base. Overall radial symmetry with
thorns distributed evenly around the half-dome. The plant is roughly
30 cm tall and 50 cm wide — low to the ground, unmistakably hazardous.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading on the woody base and subtly glossy
shading on the thorns, alien planet flora with an otherworldly feel.
Semi-realistic but painterly. Not photorealistic. Pale thorn color pops
against the dark woody base. Clean readable hazard silhouette.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire shrub visible with generous padding around
it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 2 (Dense / shorter thorns) — `reference_v2.png` → `mesh_v2.glb`

```
A low alien shrub growing from the ground. A tightly-packed radial burst
of roughly thirty-five shorter, thicker thorns emerging from a dark umber
woody base. Each thorn is about 9 cm long, stocky, rigid, glossy, pale
bone to warm amber with a darker tip. The thorns are packed densely
enough that the woody base is barely visible between them, reading as a
brutal pincushion. Overall radial symmetry, low compact half-dome form.
A faint dusty violet sheen pools where each thorn meets the woody base.
The plant is roughly 25 cm tall and 40 cm wide — shorter, more compact,
and denser than a typical specimen.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading on the woody base and subtly glossy
shading on the thorns, alien planet flora with an otherworldly feel.
Semi-realistic but painterly. Not photorealistic. Pale thorn color pops
against the dark woody base. Clean readable hazard silhouette.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire shrub visible with generous padding around
it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 3 (Sparse / long curved thorns) — `reference_v3.png` → `mesh_v3.glb`

```
A low alien shrub growing from the ground. A sparse radial spray of
about twelve longer, more slender thorns emerging from a dark umber
woody base, each thorn gently arching outward like curved fangs. Each
thorn is roughly 22 cm long, rigid, glossy, pale bone to warm amber
with a pronounced darker tip. The arrangement is more open — the woody
base is clearly visible between thorns — and the plant reads as an
elegant hazard rather than a brutal pincushion. A faint dusty violet
sheen pools where each thorn meets the base. Overall radial symmetry,
low profile with a wider reach. The plant is roughly 35 cm tall and
60 cm wide — taller and broader than a typical specimen, with more
negative space.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte shading on the woody base and subtly glossy
shading on the thorns, alien planet flora with an otherworldly feel.
Semi-realistic but painterly. Not photorealistic. Pale thorn color pops
against the dark woody base. Clean readable hazard silhouette.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire shrub visible with generous padding around
it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Meshy Pipeline Settings

- Target polycount: **3000 triangles** (Fixed, not Adaptive)
- Topology: **Triangle**
- Preserve UV: yes
- Texture generation: PBR bake (baseColor + metallicRoughness + normal)
