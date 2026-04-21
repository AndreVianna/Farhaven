# Sulfur Vein (P01007) — Generation Prompts

## Style Anchor

Follow `assets/props/P00001/reference.png` as the **style anchor** for the
entire Farhaven prop set. Art style, lighting, background, and composition
must match. Only the silhouette/material changes per species.

Species identity: a rocky outcrop with bright **sulfur-yellow mineral
seepage** veining its surface. Reads as "sulfur deposit on dark stone."
The stone is muted gray-brown; the sulfur is vivid lemon-yellow to
greenish-yellow, crystallized in irregular patches and thin veins.
**UNCOMMON rarity**. Yields sulfur per harvest with stone_breaking_tool.

## What varies / What stays fixed

**FIXED (material identity):**
- Base form (a chunk of dark matte stone with visible bright yellow
  sulfur deposits on its surface)
- Color palette (dull gray-brown stone + vivid lemon-yellow to
  greenish-yellow sulfur + subtle faint orange-amber where the sulfur
  is oxidizing)
- Material (matte rough stone contrasted with granular-crystalline
  sulfur patches — sulfur reads slightly crystalline and waxy)
- Scale (20-30 cm across)
- Art style (Subnautica/NMS, stylized, matte painterly)
- Composition (single subject, 3/4 high-angle, #888 gray background,
  soft even studio lighting with subtle rim light)

**VARIES (sulfur distribution):**
- V1: **thick crusty patches** of sulfur on one side
- V2: **thin branching veins** of sulfur running across the surface
- V3: **clustered crystallized nodules** of sulfur, more 3D

---

## Variation 1 (Thick crusty patches) — `reference_v1.png` → `mesh_v1.glb`

```
A chunk of dark matte gray-brown alien stone about 26 cm across, irregular and chunky in silhouette with visible surface pitting. One side is heavily coated with thick crusty patches of vivid lemon-yellow sulfur, built up in several layers like dried mineral paint — the sulfur has texture and depth, reading as "crystallized granular crust" rather than a flat painted-on color. Faint orange-amber tones bleed into the sulfur patches where oxidation is beginning. A few small yellow sulfur flakes sit at the base of the stone near the thickest deposit. The other side of the stone remains dull gray-brown and unremarkable, creating strong contrast between mineral-bearing and plain faces. Reads as "sulfur-bearing alien rock — the yellow is unmistakable."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — clean organic stone shape contrasted with vivid sulfur crust, slightly exaggerated for readability, matte stone shading with slightly waxy-crystalline sulfur shading. Semi-realistic but painterly. Not photorealistic. The vivid yellow against dull stone is the defining visual contrast.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire stone visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 2 (Thin branching veins) — `reference_v2.png` → `mesh_v2.glb`

```
A chunk of dark matte gray-brown alien stone about 24 cm across, flatter and more plate-like in silhouette than variation 1. Across the upper surface run thin branching veins of vivid lemon-yellow to greenish-yellow sulfur, like the fossilized tracks of a river system, varying in width from a couple of millimeters to about a centimeter at the thickest junction. The veins are crystalline and slightly raised from the surrounding stone, catching the studio light with a subtle waxy sheen. A few faint orange-amber tones bleed into the thicker vein junctions. The rest of the stone surface is dull gray-brown with natural pitting. Reads as "sulfur veining through alien rock — thin, branching, mineralized."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — clean organic stone shape with delicate branching vein pattern, slightly exaggerated for readability, matte stone shading contrasted with slightly waxy-crystalline yellow sulfur. Semi-realistic but painterly. Not photorealistic.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire stone visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 3 (Clustered crystallized nodules) — `reference_v3.png` → `mesh_v3.glb`

```
A chunk of dark matte gray-brown alien stone about 28 cm across, with a cluster of clearly 3D crystallized sulfur nodules growing from one upper face — several small rounded knobs of vivid lemon-yellow to greenish-yellow sulfur bulging out of the surface, each 2-5 cm across, clumped together like a mineral bouquet. The sulfur nodules are slightly translucent at their edges and catch the studio light with a waxy crystalline sheen. Faint orange-amber oxidation rings surround each nodule on the surrounding stone. A couple of small yellow sulfur flakes sit near the base of the cluster. The rest of the stone is dull gray-brown. Reads as "sulfur crystals growing out of alien rock — bulbous, clustered, mineralized."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — clean organic stone shape with clustered 3D sulfur nodules adding dramatic surface texture, slightly exaggerated for readability, matte stone shading contrasted with translucent-edge waxy-crystalline yellow sulfur. Semi-realistic but painterly. Not photorealistic.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire stone visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Meshy Pipeline Settings

- Target polycount: **3000 triangles** (Fixed, not Adaptive)
- Topology: **Triangle**
- Preserve UV: yes
- Texture generation: PBR bake (baseColor + metallicRoughness + normal)
