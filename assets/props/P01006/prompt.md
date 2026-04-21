# Crystal Cluster (P01006) — Generation Prompts

## Style Anchor

Follow `assets/props/P00001/reference.png` as the **style anchor** for the
entire Farhaven prop set. Art style, lighting, background, and composition
must match. Only the silhouette/material changes per species.

Species identity: the **signature mineral of the Rocky biome** — a cluster
of tall translucent alien crystals growing upward out of a rough stony
base. Faintly self-luminous from within, with soft internal glow and
prismatic refraction at the tips. Hardness 7, shatters with hard impact.
**UNCOMMON rarity**. Yields raw_crystal per harvest with
stone_breaking_tool.

## What varies / What stays fixed

**FIXED (material identity):**
- Cluster composition (multiple elongated hexagonal crystal prisms
  growing up from a shared rough stony base — base reads as "the rock
  these crystals grew out of")
- Translucency (clearly semi-transparent toward the tips, more opaque
  toward the base)
- Self-luminosity (faint soft internal glow — NOT emissive and blinding,
  more like "the crystal catches light from inside")
- Material (polished facets, sharp geometric edges, smooth surfaces on
  the crystal bodies; rough pitted stone on the base)
- Scale (tallest crystal 30-45 cm; whole cluster fits within ~40 cm wide
  footprint)
- Art style (Subnautica/NMS, stylized, painterly, matte painterly with
  subtle glow passes, not photorealistic)
- Composition (single subject, 3/4 high-angle, #888 gray background, soft
  even studio lighting with subtle rim light)

**VARIES (color family + silhouette per variant — this is the signature
prop, so each variant shows a different color family):**
- V1: **cyan/blue-violet cluster** (cool color, coldest)
- V2: **golden-amber cluster** (warm color, warmest)
- V3: **magenta-purple cluster** (mid tone, most alien)

---

## Variation 1 (Cyan-violet cluster) — `reference_v1.png` → `mesh_v1.glb`

```
A cluster of tall alien crystals growing upward from a rough dark-gray stony base. Five or six elongated hexagonal crystal prisms of varying heights (the tallest about 40 cm, others 15-30 cm) sprout in a fan-like arrangement, tilted slightly outward as if grown naturally. The crystals are semi-translucent with a clear cyan-to-blue-violet gradient — cooler aquamarine toward the pointed tips, deeper indigo-violet toward the stony base. A soft internal glow reads as if light is trapped inside each crystal, brightest at the tips, subtle near the base. Sharp clean hexagonal facets catch the studio light with prismatic reflections — a hint of cyan-violet refraction flares on a few edges. The rough pitted stone base is dark charcoal-gray with cool blue-violet mineralization staining near where the crystals emerge, as if the base itself was seeded with the same alien minerals. A couple of tiny broken crystal fragments sit at the foot of the base. Reads as "the signature crystal of an alien planet — cold, beautiful, faintly glowing."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — clean geometric crystal shapes with sharp faceted edges contrasted against organic stone, subtle internal translucent glow, slightly exaggerated silhouette for readability. Semi-realistic but painterly. Not photorealistic. The cyan-violet color and soft glow are defining features — striking but not overpowering, elegant rather than cartoonish. Clean readable silhouette — elongated upright cluster.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire cluster visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 2 (Golden-amber cluster) — `reference_v2.png` → `mesh_v2.glb`

```
A cluster of tall alien crystals growing upward from a rough dark-gray stony base. Four or five elongated hexagonal crystal prisms of varying heights (the tallest about 38 cm) grouped more tightly in a fan-like arrangement. The crystals are semi-translucent with a warm golden-amber gradient — pale honey-gold toward the pointed tips, deep amber-orange toward the stony base, with a few faint reddish inclusions visible inside the largest prism. A soft internal glow reads warm and sunlit, as if each crystal has captured a small piece of afternoon light. Sharp clean hexagonal facets catch the studio light with warm golden reflections. The rough pitted stone base is dark charcoal-gray with warm amber-rust mineralization staining where the crystals emerge. A couple of tiny broken crystal fragments sit at the foot of the base. Reads as "the signature crystal of an alien planet — warm, precious, faintly glowing."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — clean geometric crystal shapes with sharp faceted edges contrasted against organic stone, subtle internal translucent glow, slightly exaggerated silhouette for readability. Semi-realistic but painterly. Not photorealistic. The golden-amber color and soft glow are defining features — striking but not overpowering, elegant rather than cartoonish. Clean readable silhouette — elongated upright cluster.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire cluster visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 3 (Magenta-purple cluster) — `reference_v3.png` → `mesh_v3.glb`

```
A cluster of tall alien crystals growing upward from a rough dark-gray stony base. Six or seven elongated hexagonal crystal prisms of varying heights (the tallest about 42 cm), arranged in a wider fan with a few individual prisms leaning at stronger angles — a more dramatic asymmetric silhouette. The crystals are semi-translucent with a vivid magenta-to-purple gradient — bright rose-magenta toward the pointed tips, deep royal purple toward the stony base. A soft internal glow reads rich and alien, brightest near the tip of the largest prism. Sharp clean hexagonal facets catch the studio light with faint pink-violet refraction flares. The rough pitted stone base is dark charcoal-gray with deep violet mineralization staining where the crystals emerge, and a few tiny magenta crystal buds sprout near the outer edge of the base. A couple of tiny broken crystal fragments sit at the foot of the base. Reads as "the signature crystal of an alien planet — vivid, otherworldly, faintly glowing."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — clean geometric crystal shapes with sharp faceted edges contrasted against organic stone, subtle internal translucent glow, slightly exaggerated silhouette for readability. Semi-realistic but painterly. Not photorealistic. The magenta-purple color and soft glow are defining features — bold and alien, elegant rather than cartoonish. Clean readable silhouette — wider asymmetric cluster.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire cluster visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Meshy Pipeline Settings

- Target polycount: **3000 triangles** (Fixed, not Adaptive)
- Topology: **Triangle**
- Preserve UV: yes
- Texture generation: PBR bake (baseColor + metallicRoughness + normal)
