# Iron Nodule (P01005) — Generation Prompts

## Style Anchor

Follow `assets/props/P00001/reference.png` as the **style anchor** for the
entire Farhaven prop set. Art style, lighting, background, and composition
must match. Only the silhouette/material changes per species.

Species identity: a **heavy rust-streaked iron-bearing nodule** — irregular
crystal form with cubic pattern, hardness 4, bends (not shatters),
**metallic surface shine** where weathering has worn crust off, blocked
light, dense (7.9 g/cm³). **RARE rarity**. Yields single iron_ore per
harvest with stone_breaking_tool, no respawn.

## What varies / What stays fixed

**FIXED (material identity):**
- Color palette (warm rust-orange and rust-red oxidation crust dominating
  the outer surface, revealing a cooler **dull metallic gray-blue** where
  the crust has worn away or the nodule has fractured; faint darker
  copper-tan streaks where water has run; subtle cyan-violet mineral
  glint at the metallic faces — very subtle alien flavor on the
  metallic surfaces)
- Material (dull matte rust crust with soft dark-metallic sheen where
  raw iron is exposed; no bright chrome shine, more of a weathered
  steel quality)
- Weight reads heavy — chunky, dense silhouette
- Scale (roughly fist-to-two-fist sized — 18-30 cm across)
- Art style (Subnautica/NMS, stylized, matte + soft metallic, painterly,
  not photorealistic)
- Composition (single subject, 3/4 high-angle, #888 gray background, soft
  even studio lighting with subtle cool rim light)

**VARIES (weathering / exposure of raw iron):**
- How much rust crust vs exposed metallic surface
- Overall silhouette (rounded weathered vs angular fractured vs flaking)
- Presence of visible cubic crystal hints

---

## Variation 1 (Lumpy irregular rust-crusted) — `reference_v1.png` → `mesh_v1.glb`

```
A heavy alien iron nodule resting on the ground. A distinctly LUMPY and IRREGULAR chunky mass about 22 cm across — NOT rounded, NOT regular. The silhouette is asymmetric with clear bulges, concavities, jutting smaller protrusions, and weathered pitting. The surface is heavily covered in thick warm rust-orange and rust-red oxidation crust, rough and matte. A few small worn patches around the irregular protrusions reveal dull metallic gray-blue iron beneath, catching the light with a soft dark-metallic sheen. Darker copper-tan oxidation streaks follow the natural hollows and run down from higher surfaces. Small visible pits dot the rust crust. A very subtle cyan-violet glint sits on one of the exposed metallic patches — minimal alien accent. Reads as "a heavy irregular chunk of iron ore, weathered unevenly over long time."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — clean organic shapes, slightly exaggerated silhouette for readability, matte rust shading contrasted with soft dark-metallic shading on exposed patches, alien planet geology with an otherworldly feel. Semi-realistic but painterly. Not photorealistic. Warm rust dominates against the muted palette with cool metallic patches as highlights. Clean readable silhouette — irregular and lumpy, unmistakably natural ore.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire nodule visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 2 (Asymmetric blocky fracture) — `reference_v2.png` → `mesh_v2.glb`

```
A heavy alien iron nodule resting on the ground. A chunky ASYMMETRIC blocky mass about 25 cm across — irregular and clearly broken apart, NOT rounded, NOT regular. One large flat fractured face (perhaps a third of the total surface area) is cleanly exposed, showing the dull metallic gray-blue iron interior with small cubic crystal hints catching the light in geometric glints. The remaining outer surfaces are rust-crusted with VISIBLE IRREGULARITY: varying planes, small bumps, jutting protrusions, uneven weathering. Not smoothly shaped anywhere — the whole nodule reads as chunky and recently split. A few small rust flakes sit at the base near the fracture face. Darker copper-tan oxidation runs down from the fracture edges. Subtle cyan-violet glint on one of the cubic crystal facets on the fracture face. Heavy, dense, lumpy.

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — clean organic shapes, slightly exaggerated silhouette for readability, matte rust shading with a clear dark-metallic fracture face and irregular rust-crusted exterior, alien planet geology with an otherworldly feel. Semi-realistic but painterly. Not photorealistic. The contrast between rust crust and metallic interior is a defining feature, but the OVERALL IRREGULARITY of the shape is equally important. Clean readable silhouette — blocky, asymmetric, broken.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire nodule visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 3 (Flaking weathered outcrop) — `reference_v3.png` → `mesh_v3.glb`

```
A heavy alien iron nodule resting on the ground. A chunky asymmetric
mass about 28 cm across, heavily weathered — the thick rust crust is
spalling off in visible flakes and scales, leaving patchy areas of
exposed dull metallic gray-blue beneath and loose rust flakes scattered
around its base. The surface reads as "in the middle of slow
disintegration." Color mix of warm rust-orange/rust-red (crust), dull
metallic gray-blue (exposed iron), and the darker copper-tan streaks
of water runoff. Several small flakes have fully separated and sit
near the main mass. Subtle cyan-violet glint on one of the larger
exposed metallic patches. Silhouette is irregular, lumpy, lived-in.
Heavy, dense.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic shapes, slightly exaggerated silhouette
for readability, matte rust shading with patchy dark-metallic exposure
and scattered flakes, alien planet geology with an otherworldly feel.
Semi-realistic but painterly. Not photorealistic. The weathered,
flaking appearance is the defining feature. Clean readable silhouette.

Composition: Single subject centered, 3/4 high-angle view, isolated on
pure neutral gray background (#888888). Soft even studio lighting with
a subtle cool rim light. No shadows on the background. No floor or
ground plane visible. Entire nodule (with adjacent flakes) visible
with generous padding around it. No other elements, no text, no
watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Meshy Pipeline Settings

- Target polycount: **3000 triangles** (Fixed, not Adaptive)
- Topology: **Triangle**
- Preserve UV: yes
- Texture generation: PBR bake (baseColor + metallicRoughness + normal)
