# Small Broken Shells (P01013) — Generation Prompts

## Style Anchor

Follow `assets/props/P00001/reference.png` as the **style anchor** for the
entire Farhaven prop set. Art style, lighting, background, and composition
must match. Only the silhouette/material changes per species.

Species identity: a **small scatter of broken alien shell fragments** —
calcareous (calcium-carbonate) debris left behind by long-dead small
creatures. Reads as "shell fragments ground by time, cross-biome
organic debris." Appears occasionally in Rocky, Grassland, and Forest
biomes as decorative/scavenge piece. **COMMON rarity**. Minor harvest:
yields calcium per harvest with bare hands.

## What varies / What stays fixed

**FIXED (material identity):**
- Form (a scatter of several broken shell fragments on the ground, no
  more than 20-30 cm wide footprint and very low profile — less than
  5 cm tall at highest)
- Material (chalky calcareous shell — matte pale, slightly porous,
  with occasional hints of nacreous pearl sheen on inner faces where
  the original creature's shell lining is visible)
- Color palette (pale cream-white to soft bone-gray, with subtle
  warm-peach or cool-lavender iridescent hints on inner surfaces)
- Small scale — each fragment 2-6 cm across, cluster small
- Art style (Subnautica/NMS, stylized, matte painterly)
- Composition (single subject, 3/4 high-angle, #888 gray background,
  soft even studio lighting with subtle rim light)

**VARIES (shell shape):**
- V1: **spiral conch-style fragments** — curled pieces
- V2: **flat bivalve-style fragments** — clam-like plates
- V3: **fluted scallop-style fragments** — ridged pieces

---

## Variation 1 (Spiral conch fragments) — `reference_v1.png` → `mesh_v1.glb`

```
A small scatter of broken alien shell fragments on the ground, about 25 cm across and no more than 4 cm tall, composed of five or six spiraled fragments that once belonged to small conch-like shells. Each fragment shows a characteristic curled spiral shape where the shell coiled back on itself, broken along clean edges. The outer surfaces are pale cream-white to soft bone-gray, chalky and matte, with fine natural ridging or growth-line texture running along the curves. A few of the fragments show their inner faces exposed — these inner surfaces carry a subtle iridescent pearl sheen with faint peach-to-lavender hints that catch the studio light softly. The fragments are scattered loosely with natural gaps between them, a few leaning against others. A few tiny shell chips and chalky dust hint in the gaps. Reads as "fossil-like spiraled shell fragments scattered on alien ground."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — loose scatter composition with curled spiraled shell shapes, slightly exaggerated for readability, chalky matte exterior contrasted with faintly iridescent inner surfaces. Semi-realistic but painterly. Not photorealistic. The SMALL LOW-PROFILE scatter silhouette is defining.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire scatter visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 2 (Flat bivalve fragments) — `reference_v2.png` → `mesh_v2.glb`

```
A small scatter of broken alien shell fragments on the ground, about 28 cm across and no more than 3 cm tall, composed of several flat bivalve-style shell pieces — like fragments of clam or mussel shells. Each fragment is a slightly curved thin plate, 3-6 cm across, with smooth concentric growth-ring texture on its outer face and a faintly iridescent inner face. The outer faces are pale bone-gray, chalky and matte; the inner faces catch the studio light with soft nacreous sheen — faint peach, lavender, and pale-blue iridescence plays across them. The fragments are scattered loosely, some lying convex-up, some concave-up so the iridescent inner face is visible, a couple overlapping. Tiny shell chips and chalky dust in the gaps. Reads as "broken alien bivalve shell fragments scattered on the ground."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — loose scatter composition with flat curved shell plates, slightly exaggerated for readability, chalky matte exterior contrasted with iridescent nacreous interior. Semi-realistic but painterly. Not photorealistic.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire scatter visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Variation 3 (Fluted scallop fragments) — `reference_v3.png` → `mesh_v3.glb`

```
A small scatter of broken alien shell fragments on the ground, about 24 cm across and no more than 4 cm tall, composed of several scallop-style shell pieces with distinctive radial fluting — strong raised ribs running from a hinge point outward like rays of a sun. Each fragment is 3-5 cm across, thicker than the bivalve variant, with clearly visible parallel ribs on its outer face. The outer faces are pale cream-white, chalky and matte. A couple of fragments lie with inner face up, revealing faintly iridescent nacreous interiors with soft pearl sheen. The fragments are scattered loosely with natural gaps and a couple overlapping. A few tiny chips and chalky dust in the gaps. Reads as "broken alien scallop-shell fragments — fluted, radial, chalky."

Art style: Stylized 3D game asset in the visual language of Subnautica and No Man's Sky — loose scatter composition with distinctive fluted/ribbed shell shapes, slightly exaggerated for readability, chalky matte exterior contrasted with iridescent nacreous interior on a couple of fragments. Semi-realistic but painterly. Not photorealistic. The radial fluting on the outer faces is the defining visual feature.

Composition: Single subject centered, 3/4 high-angle view, isolated on pure neutral gray background (#888888). Soft even studio lighting with a subtle cool rim light. No shadows on the background. No floor or ground plane visible. Entire scatter visible with generous padding around it. No other elements, no text, no watermark.

Render style: 3D model turnaround reference image for game asset production.
```

---

## Meshy Pipeline Settings

- Target polycount: **3000 triangles** (Fixed, not Adaptive)
- Topology: **Triangle**
- Preserve UV: yes
- Texture generation: PBR bake (baseColor + metallicRoughness + normal)
