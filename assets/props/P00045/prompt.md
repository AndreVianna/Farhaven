# Loose Small Feathers (P00045) — Generation Prompts

## Style Anchor

Follow `assets/props/P00001/reference.png` as the **style anchor** for the
entire Farhaven prop set. Art style, lighting, background, and composition
must match. Only the silhouette/material changes per species.

Species identity: a **small scatter of alien feathers** lying on the
ground — faunal debris shed by flying creatures. Cross-biome, most
common where flying creatures roost on rocks or perch in trees.
Reads as "something winged passed through here." **UNCOMMON rarity**.
Yields feathers per harvest with bare hands.

## What varies / What stays fixed

**FIXED (species identity):**
- Form (a loose scatter of 4-6 feathers on the ground, of varying sizes,
  casually arranged, NOT perfectly aligned)
- Feathers vary in length (4-10 cm each) and type (some down-like fluffy
  smaller ones, some more structured plume-shape with a visible central
  rachis)
- Very low profile — feathers lie almost flat on the ground with slight
  natural curl
- Scale (whole scatter about 20-30 cm across)
- Art style (Subnautica/NMS, stylized, matte painterly)
- Composition (single subject, 3/4 high-angle, #888 gray background,
  soft even studio lighting with subtle rim light)

**VARIES (feather color — visual-only, alien-believable tones):**
- V1: **earth-tones** — browns, tans, cream (camouflage flier)
- V2: **iridescent blue-green** — bright display feathers
- V3: **soft ash-gray with hints of deep wine-red** — subtle alien

---

## Variation 1 (Earth-tone camouflage feathers) — `reference_v1.png` → `mesh_v1.glb`

```
A small scatter of five alien feathers lying on the ground, together about 25 cm across and very low profile. The feathers vary in size (4-9 cm long): two are small downy fluffy feathers (cream-colored with soft tan tips), two are medium plumed feathers with visible central rachis and barbs (warm brown with subtle banding and cream bases), and one is a larger flight-feather style with a prominent rachis and asymmetric vanes (dark brown with lighter tan edges). The feathers lie with natural slight curls — one lies fully flat, one tips upward slightly at its end, two overlap at the center of the scatter, the largest curves gently. The palette is earthy browns and creams — alien but recognizable as camouflage coloring. A couple of tiny down-flecks fleck the gaps between feathers. Reads as "shed feathers from a small alien ground-bird or climber — soft, natural, low-profile."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — loose scatter of varied feathers with subtle curl and barb detail, slightly exaggerated for readability, matte soft feather shading. Semi-realistic but painterly. Not photorealistic. The SMALL LOW-PROFILE casual scatter is defining.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire feather scatter visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 2 (Iridescent blue-green display feathers) — `reference_v2.png` → `mesh_v2.glb`

```
A small scatter of five alien feathers lying on the ground, together about 28 cm across and very low profile. The feathers vary in size (5-10 cm long): two are small fluffy downy feathers (muted teal with darker tips), two are medium plumed feathers with visible rachis and barbs in vivid iridescent blue-green catching the studio light with cyan and violet shimmer at certain angles, and one is a larger flight-feather with a prominent rachis, asymmetric vanes, in deep peacock-blue with metallic green sheen along the edges. The feathers lie with natural slight curls and overlap in a casual arrangement. The iridescence reads as flashes of color on certain parts of each feather rather than a uniform paint. A couple of tiny iridescent down-flecks fleck the gaps. Reads as "shed display feathers from a brightly colored alien flier — vivid, iridescent, elegant."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — loose scatter with iridescent feathers showing subtle color shifts, slightly exaggerated for readability, matte base feather shading with selective iridescent highlights along rachis and outer barbs. Semi-realistic but painterly. Not photorealistic. The iridescence must read as natural feather structure, not as cartoonish paint.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire feather scatter visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 3 (Ash-gray with wine-red hints) — `reference_v3.png` → `mesh_v3.glb`

```
A small scatter of six alien feathers lying on the ground, together about 26 cm across and very low profile. The feathers vary in size (4-9 cm long): two are small downy fluffy feathers (soft ash-gray), three are medium plumed feathers with visible rachis and barbs in a cool dove-gray gradient with subtle deep wine-red tips catching the studio light softly, and one is a larger flight-feather with asymmetric vanes in darker smoke-gray with a wine-red band running along its rachis. The feathers lie with natural slight curls and overlap casually. The palette is restrained — cool ashy grays with the wine-red accent as a subtle alien flavor, never overpowering. A couple of tiny gray down-flecks fleck the gaps. Reads as "shed feathers from a subtle alien flier — ashen and softly accented."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — loose scatter with restrained palette and subtle accent color, slightly exaggerated for readability, matte soft feather shading with selective wine-red highlights. Semi-realistic but painterly. Not photorealistic. The most restrained of the three variants — elegant rather than flashy.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire feather scatter visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Meshy Pipeline Settings

- Target polycount: **3000 triangles** (Fixed, not Adaptive)
- Topology: **Triangle**
- Preserve UV: yes
- Texture generation: PBR bake (baseColor + metallicRoughness + normal)
