# Hero Character — Generation Prompts

The player character. Sci-fi explorer, male, lean-muscular build.
Wakes up inside a hibernation chamber on an alien planet in the opening
of the game, wearing his cryosleep suit and basic field kit.

Target: ~10K triangles, PBR materials, rigged biped with walking and
running animations from Meshy.

## Nano-Banana Prompt (for reference image fed to Meshy Image-to-3D)

```
A male sci-fi explorer character, lean and athletically built, standing
in a neutral T-pose for 3D model rigging reference. He wears a form-fitting
white cryosleep suit that covers his entire body — a sleek thermal
underlayer, matte white with subtle panel lines and faint grey accent
seams along the shoulders, chest, waist, and limbs. The suit is tight
enough to show a lean muscular build without being skintight rubber — it
reads as functional spacefaring fabric, not a superhero bodysuit.

On his head, a thin minimalist helmet integrated with the suit collar.
The visor wraps the entire face in a smooth dark tinted panel (no facial
features visible through it) — clean, slightly iridescent, with a faint
blue rim glow where it meets the helmet shell. Helmet silhouette is sleek
and close-fitting, not bulky.

Equipment:
- A medium-sized utility backpack in matte graphite with white accents,
  proportioned to look practical for field exploration (not overloaded).
  Clean hard-surface design with a few visible straps and a small antenna.
- A forearm-mounted device on his right arm (wrist to mid-forearm): a
  multi-tool combining a small rectangular screen (scanner/portable
  computer), a compact flashlight emitter, and a secondary sensor. Matte
  dark grey with soft cyan indicator lights.
- A survival knife sheathed in a utility belt pouch on his left hip.
  Knife handle visible, dark grey with a small white grip accent.

Art style: Stylized 3D game asset in the visual language of Subnautica
and No Man's Sky — clean organic and hard-surface shapes, slightly
exaggerated silhouette for readability at gameplay distance, matte shading,
sci-fi explorer with an alien-frontier feel. Semi-realistic but painterly.
Not photorealistic. Muted palette (matte whites, cool greys, graphite,
small cyan highlights). Clean readable silhouette from every angle.

Composition: Single subject centered, straight T-pose (arms horizontal,
legs together, feet forward, looking straight ahead). 3/4 front high-angle
view. Isolated on pure neutral gray background (#888888). Soft even studio
lighting with a subtle cool rim light on the back edges. No shadows on
the background. No floor or ground plane visible. Entire figure visible
from helmet top to feet with generous padding. No weapons drawn, no action
pose. No other elements, no text, no watermark.

Adult male, approximately 180cm tall, lean athletic build.

Render style: 3D model turnaround reference image for game asset production.
```

## Meshy Pipeline Settings

- Target polycount: **10000 triangles** (hero is focal point, higher detail budget)
- Topology: **Triangle** (Quad is nicer for rigging deformation but Meshy's
  auto-rigging handles triangulated meshes fine)
- Preserve UV: yes
- Texture generation: PBR bake
- Rigging: **Biped auto-rig** applied by Meshy
- Animations: Walking, Running, Run_02 (generated via Meshy's animation library)

Final static mesh: 9998 tris with full PBR.
Animations bundled as separate `.glb` files with the rigged skin in
`assets/hero/animations/`.
