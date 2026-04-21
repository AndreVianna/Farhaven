# Copper Vein (P01010) — Generation Prompts

## Style Anchor

Follow `assets/props/P00001/reference.png` as the **style anchor** for the
entire Farhaven prop set. Art style, lighting, background, and composition
must match. Only the silhouette/material changes per species.

Species identity: a chunk of alien stone with **native copper** visible
in veins and nodules across its surface. The copper has the characteristic
warm reddish-pink metallic shine of raw copper, contrasted with dull
gray stone. Patches of blue-green verdigris patina mark where the copper
has been weathered. **UNCOMMON rarity**. Yields copper_ore per harvest
with stone_breaking_tool.

## What varies / What stays fixed

**FIXED (material identity):**
- Base form (a chunk of dull gray alien stone with visible native copper
  on its surface — metallic reddish-pink patches contrasted against
  dull matte stone)
- Color palette (dull gray stone + warm reddish-pink copper metal +
  turquoise-green verdigris weathering)
- Material (matte rough stone contrasted with shiny metallic copper —
  copper catches the studio light with a warm reflective sheen)
- Scale (22-30 cm across)
- Art style (Subnautica/NMS, stylized, matte painterly with subtle
  metallic highlights)
- Composition (single subject, 3/4 high-angle, #888 gray background,
  soft even studio lighting with subtle rim light)

**VARIES (copper distribution and patina):**
- V1: **thick exposed copper patches** with minimal patina — fresh
- V2: **copper veins with heavy verdigris** — aged
- V3: **copper nodules embedded in stone** — clustered

---

## Variation 1 (Fresh exposed copper patches) — `reference_v1.png` → `mesh_v1.glb`

```
A chunk of dull gray alien stone about 26 cm across, irregular and chunky in silhouette with natural surface pitting. One side prominently displays thick exposed patches of native copper metal — warm reddish-pink metallic surfaces that catch the studio light with a clear metallic sheen, as if a hammer struck and revealed the fresh metal underneath. The copper patches are mostly bright and clean with only minimal hints of blue-green verdigris at the edges where weathering has just begun. A few small copper flakes sit at the base of the stone near the largest patch. The other faces of the stone remain dull gray and unremarkable, creating strong contrast between the metallic-bearing face and the plain stone. Reads as "native copper exposed on alien rock — fresh, bright, metallic."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — clean organic stone shape with vivid metallic copper patches, slightly exaggerated for readability, matte stone shading contrasted with soft metallic copper shading. Semi-realistic but painterly. Not photorealistic. The warm metallic copper against dull gray stone is the defining visual contrast.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire stone visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 2 (Veins with heavy verdigris) — `reference_v2.png` → `mesh_v2.glb`

```
A chunk of dull gray alien stone about 24 cm across, flatter and more slab-like in silhouette than variation 1. Across the upper surface run thin copper veins and small copper patches, but the copper is heavily weathered — large areas have oxidized to distinctive turquoise-green verdigris patina, giving the stone a striking dual-color mineralization. Warm reddish-pink metallic copper shows through where the patina has flaked off or where the metal is too thick to fully oxidize, and the transitional areas shift through orange-brown and teal tones. A few tiny copper-flake fragments and verdigris crumbs sit near the base. The rest of the stone is dull gray. Reads as "aged copper veining through alien rock — turquoise and pink, weathered."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — clean organic stone shape with copper/verdigris dual-tone mineralization, slightly exaggerated for readability, matte stone shading contrasted with metallic copper and matte turquoise verdigris. Semi-realistic but painterly. Not photorealistic. The turquoise-and-pink color combination is the defining visual idea.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire stone visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 3 (Copper nodules clustered in stone) — `reference_v3.png` → `mesh_v3.glb`

```
A chunk of dull gray alien stone about 28 cm across with a cluster of clearly 3D copper nodules bulging out of one upper face — several rounded knobs and irregular blobs of warm reddish-pink native copper metal, each 2-5 cm across, embedded in the stone matrix like clustered mineral jewels. The copper nodules catch the studio light with distinct metallic highlights, showing a mix of clean bright copper and subtle greenish-teal verdigris mottling on a few of them. Small faint blue-green staining rings surround each nodule on the surrounding stone. A couple of small copper flakes sit at the base near the cluster. The rest of the stone is dull gray with natural pitting. Reads as "native copper nodules growing out of alien rock — clustered, metallic, three-dimensional."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — clean organic stone shape with clustered 3D metallic copper nodules adding dramatic surface texture, slightly exaggerated for readability, matte stone shading contrasted with shiny metallic copper with verdigris accents. Semi-realistic but painterly. Not photorealistic.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire stone visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Meshy Pipeline Settings

- Target polycount: **3000 triangles** (Fixed, not Adaptive)
- Topology: **Triangle**
- Preserve UV: yes
- Texture generation: PBR bake (baseColor + metallicRoughness + normal)
