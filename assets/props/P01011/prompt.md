# Quartz Spire (P01011) — Generation Prompts

## Style Anchor

Follow `assets/props/P00001/reference.png` as the **style anchor** for the
entire Farhaven prop set. Art style, lighting, background, and composition
must match. Only the silhouette/material changes per species.

Species identity: a **single tall alien quartz spire** growing upward
from a small stony base — one dominant elongated hexagonal prism rather
than a cluster. Clear to milky-white, sharp-tipped, reads as "a natural
quartz crystal scaled up." **COMMON rarity**. Yields raw_crystal per
harvest.

## What varies / What stays fixed

**FIXED (material identity):**
- Single dominant elongated hexagonal crystal spire with a sharp point
  at the top, sprouting from a small rough stony base
- Material (translucent quartz, smooth facets, sharp geometry)
- Base is small and secondary — the spire dominates the silhouette
- Scale (spire 35-55 cm tall)
- Art style (Subnautica/NMS, stylized, painterly)
- Composition (single subject, 3/4 high-angle, #888 gray background,
  soft even studio lighting with subtle rim light)

**VARIES (clarity, inclusions, silhouette):**
- V1: **clear spire** with one or two tiny companion crystals at the base
- V2: **milky-white spire** with cloudy inclusions
- V3: **smoky quartz spire** with subtle darker core

---

## Variation 1 (Clear spire with companions) — `reference_v1.png` → `mesh_v1.glb`

```
A single tall alien quartz spire growing upward from a small rough gray-brown stony base. One dominant elongated hexagonal crystal prism about 45 cm tall dominates the silhouette, standing nearly vertical with a slight lean to one side, terminating in a sharp pyramidal point. The quartz is clear and semi-transparent, catching the studio light through its facets with subtle prismatic sparkle at the point. A few internal hairline inclusions are faintly visible. Two much smaller companion quartz crystals (about 8 cm each) sprout from the base beside the main spire, also clear. The stony base is small and understated — just enough to anchor the spire. A couple of tiny crystal fragments sit at the foot. Reads as "a solitary alien quartz spire standing tall — clean, bright, glassy."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — single dominant vertical crystal with sharp clean facets, secondary companion crystals at the base for visual interest, slightly exaggerated for readability, matte stone shading on the small base contrasted with the translucent clear quartz. Semi-realistic but painterly. Not photorealistic.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire spire with base visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 2 (Milky-white cloudy spire) — `reference_v2.png` → `mesh_v2.glb`

```
A single tall alien quartz spire growing upward from a small rough gray-brown stony base. One dominant elongated hexagonal crystal prism about 40 cm tall stands slightly tilted from vertical, terminating in a sharp pyramidal point. The quartz is milky white with visible cloudy inclusions swirling through the interior, semi-translucent rather than transparent — light still passes through but diffuses softly, giving the spire a gentle internal glow. The facets catch the studio light with a soft pearly sheen rather than sharp reflections. The stony base is small and understated with a couple of tiny white crystal fragments at its foot. A single thin quartz bud sprouts from the base on the opposite side from the main spire's lean. Reads as "milky alien quartz spire — soft, pearly, glowing subtly."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — single dominant vertical crystal with cloudy internal inclusions, slightly exaggerated for readability, matte stone shading on the small base contrasted with the diffuse milky-white quartz. Semi-realistic but painterly. Not photorealistic. Softer reads than the clear variant.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire spire with base visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 3 (Smoky quartz spire) — `reference_v3.png` → `mesh_v3.glb`

```
A single tall alien quartz spire growing upward from a small rough gray-brown stony base. One dominant elongated hexagonal crystal prism about 50 cm tall stands nearly vertical, terminating in a sharp pyramidal point. The quartz is smoky brownish-gray, semi-translucent, with a distinctly darker charcoal-toned core visible through the outer layer — like looking into tinted glass. The facets catch the studio light with restrained warm-gray reflections rather than bright sparkle. The stony base is small and understated — matching the muted tone of the spire. A couple of tiny smoky crystal fragments sit at the foot of the base and one medium-sized fragment has broken off and rests against the main spire. Reads as "smoky alien quartz spire — muted, sophisticated, restrained."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — single dominant vertical crystal with smoky tinted interior, slightly exaggerated for readability, matte stone shading on the small base matching the muted spire tone. Semi-realistic but painterly. Not photorealistic. The most restrained of the three variants.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire spire with base visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Meshy Pipeline Settings

- Target polycount: **3000 triangles** (Fixed, not Adaptive)
- Topology: **Triangle**
- Preserve UV: yes
- Texture generation: PBR bake (baseColor + metallicRoughness + normal)
