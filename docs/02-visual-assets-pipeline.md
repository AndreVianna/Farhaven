# Research Report: Visual Assets Pipeline for Farhaven (v2 — Deep Dive)

**Date:** 2026-03-30 (updated 13:00 UTC)
**Author:** Lola Lovelace

---

## 1. The Challenge — Crystal Clear

Farhaven needs ~100-150 unique 3D models that look like they belong in the **same game**. The #1 killer of AI-generated game art isn't quality — it's **inconsistency**. Every model looks like it came from a different game.

We need a pipeline that produces:
- **Volume:** 150+ models at near-zero marginal cost
- **Consistency:** Same style, palette, proportions across ALL assets
- **Quality:** Good enough that nobody says "this looks AI-generated"
- **Speed:** Weeks, not months
- **Mobile-ready:** <500 tris per object, shared texture atlases

---

## 2. Complete Asset Inventory

| Category | Count | Tri Budget | Priority | Notes |
|----------|-------|-----------|----------|-------|
| **Hex Tiles** | 7 biomes × 2-3 variants | ~100 tris each | P0 | Flat hex + terrain features |
| **Player Character** | 1 + 5 tool variants | ~800 tris | P0 | Needs rigging + animation |
| **Trees/Plants** | 6-10 per biome × 5 biomes | ~200-400 tris | P0 | Wind sway via shader |
| **Rocks/Minerals** | 4-6 per biome × 5 biomes | ~50-150 tris | P0 | Static, LOD not needed |
| **Resource Pickups** | ~15 types (wood, ore, crystal...) | ~100 tris | P0 | Floating/spinning |
| **Structures** | 10 buildings | ~300-500 tris | P0 | Static + smoke/glow particles |
| **Ship** | 1 base + 4 repair states | ~1200 tris | P0 | Hero asset, most detailed |
| **Night Fauna** | 3 creature types | ~400 tris | P1 | Needs rigging + simple anim |
| **Particles** | 15+ effects | N/A (GPU) | P1 | Godot particle system |
| **UI Icons** | 25+ items | N/A (2D) | P1 | 64×64 or 128×128 sprites |
| **Skybox** | 3 variants (day/dusk/night) | N/A | P2 | Procedural or panoramic |

**Total 3D models: ~130-180.** Plus 25+ 2D icons, 15+ particle effects, 3 skyboxes.

---

## 3. The AI 3D Tool Landscape (March 2026 — Current)

### Head-to-Head Comparison (Tested & Verified)

| Tool | Price/mo | Models/mo | $/model | Best For | Weakness |
|------|---------|-----------|---------|----------|----------|
| **Sloyd** | $15 | **Unlimited** | ~$0.015 | Props, buildings, weapons | Less organic shapes |
| **Tripo** | $15.90 | ~75 | $0.21 | Characters, organic, rigging | 40 credits per textured model |
| **Meshy v6** | $20 | ~50 | $0.40 | General purpose, plugins | 20 credits per textured model |
| **3D AI Studio** | $14-29 | ~1,000 | $0.014-0.029 | Multi-engine access | Web-only workflow |
| **Rodin** | $99 | varies | high | Hero assets, max quality | Too realistic for our style |

**Source:** Sloyd's own pricing comparison (March 24, 2026), verified against each platform.

### 🏆 The Winner for Our Project: Sloyd + Tripo Combo

**Why this combo:**

1. **Sloyd ($15/mo — UNLIMITED)** handles 80% of our assets:
   - All hex tiles, rocks, structures, tools, resource pickups, weapons
   - Parametric engine = tweak parameters, not re-generate
   - **Explicit polygon count control** — set target to 200 tris, get 200 tris
   - **Quad topology** — clean for animation and LODs
   - **Reference image input** — upload concept art, get matching 3D model
   - **Style training** — generate first 5 assets, train consistency, batch the rest
   - Exports: FBX, GLB, OBJ — all Godot-compatible

2. **Tripo ($15.90/mo — 75 models)** handles the 20% that needs rigging:
   - Player astronaut character
   - Night fauna (3 creatures)
   - Ship (hero asset)
   - **Auto-rigging built in** — upload mesh, get skeleton + basic animations
   - Best quad topology of any AI tool (confirmed by multiple reviews)
   - HD textures with PBR maps

**Total: $30.90/mo** for unlimited props + 75 rigged characters. We need 2-3 months max = **~$93 total** for ALL 3D assets.

### Why NOT the Others?

- **Meshy:** More expensive ($20/mo for only 50 models) and weaker topology than Tripo. Their v6 (Jan 2026) improved geometry significantly, but still behind Tripo for characters. Good Godot plugin though.
- **3D AI Studio:** Great value but web-only. No direct engine integration. Better as backup.
- **Rodin:** $99/mo, too realistic. Wrong art style for low-poly.

---

## 4. The Consistency Problem — And How to Solve It

### The Real Problem

Ask 3 AI tools to make "a low-poly tree" and you get:
- Tool A: Realistic proportions, muted colors, 8K tris
- Tool B: Cartoony, bright green, 400 tris
- Tool C: Abstract geometric, flat-shaded, 150 tris

All three are "low-poly trees." None belong in the same game.

### The Solution: Concept Art → Image-to-3D Pipeline

```
STEP 1: Define art style via CONCEPT ART (2D)
    ↓  Use AI image gen (Midjourney/DALL-E/Stitch) to create
    ↓  reference sheets for EACH asset category
    ↓  Same style, same palette, same proportions
    ↓
STEP 2: Image-to-3D conversion
    ↓  Feed concept art as REFERENCE IMAGE to Sloyd/Tripo
    ↓  AI matches the reference style, not its own default
    ↓  This is the key insight: image input > text prompts
    ↓
STEP 3: Parametric refinement (Sloyd only)
    ↓  Adjust parameters: scale, poly count, color palette
    ↓  Generate variants from same base (3 tree types from 1 template)
    ↓
STEP 4: Blender batch standardization
    ↓  Import batch → apply shared material → decimate to budget
    ↓  All objects share the same palette/material properties
    ↓  This is where consistency is ENFORCED
    ↓
STEP 5: Texture atlas
    ↓  Combine all objects per biome into shared atlases
    ↓  One material = one draw call for entire biome
    ↓
STEP 6: Export to Godot (.glb)
```

### The Key Insight: **Image Input > Text Prompts**

Both Sloyd and Tripo support **image-to-3D** (uploading a reference image). This is dramatically better than text prompts for consistency because:
- Text: "low-poly tree" = 1000 possible interpretations
- Image: [picture of YOUR tree style] = one interpretation, matching YOUR art direction

**The workflow is:**
1. Generate 10 concept art images in ONE AI session (same style bleeds through)
2. Use those 10 images as references for 10× 3D models
3. Result: 10 models that look like they belong together

---

## 5. Art Style Bible — Defining "Farhaven Look"

### Step 0: Generate a Style Sheet

Before ANY 3D work, generate a 2D concept art reference sheet:

```
Prompt for AI image gen:
"Low-poly alien planet game art style sheet showing:
 top row: 5 hex terrain tiles (forest, rock, water, desert, ruins)
 middle row: astronaut character, 3 alien trees, 2 crystals
 bottom row: wooden workbench, metal furnace, crashed spaceship
 Colors: teal sky, amber terrain, purple ruins, bioluminescent cyan accents
 Style: geometric, soft edges, flat shading, mobile game quality
 Similar to: Islanders meets Astroneer, pastel low-poly"
```

This sheet becomes the **visual contract**. Every 3D asset must match it.

### Color Palette (Locked)

```
CORE PALETTE (max 24 colors total — forces consistency):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TERRAIN BASE:
  Forest:   #5b8c3e (leaf) / #3d6b2e (shadow) / #8b6c42 (trunk)
  Rocky:    #8a8578 (stone) / #6b635a (shadow) / #b8c8e0 (crystal)
  Water:    #2a6b7a (deep) / #5ba8b5 (surface) / #ffffff (foam)
  Desert:   #d4a05a (sand) / #c4884a (shadow) / #e8d5a0 (highlight)
  Ruins:    #4a3a6b (stone) / #2a2040 (shadow) / #00ffd5 (glow)
  Volcanic: #6b2a2a (rock) / #ff6b35 (magma) / #ff9500 (glow)
  Crash:    #7a7a7a (metal) / #9a9a9a (hull) / #ffcc00 (warning)

SKY:
  Day:      #4db8a4 → #1a3a4a (gradient)
  Dusk:     #ff8855 → #4a2040 (gradient)
  Night:    #0a1628 (base) / #00ffd5 (bioluminescent) / #ff6bff (alien)

PLAYER:
  Suit:     #e8e8e8 (white) / #3a5a8a (blue accent) / #ffcc00 (visor)
```

### Style Rules (Non-Negotiable)

1. **Flat/cel shading only.** No PBR. No realistic lighting on models. Godot unlit or toon shader.
2. **Max 500 tris per object.** Hex tiles ~100, trees ~300, rocks ~80, structures ~400, ship ~1200.
3. **Soft rounded geometry.** Even rocks. No sharp polygons.
4. **Shared material per biome.** One texture atlas per biome = one draw call.
5. **Limited palette.** The 24 colors above. Period. AI will try to add more. Override.
6. **Scale consistency.** Define unit grid: 1 hex = 2m across. Player = 1.2m tall. Everything derives.
7. **No realistic textures.** Flat colors or gentle gradients. Hand-painted feel if any.

---

## 6. Per-Category Production Plan

### 6.1 Hex Tiles (Sloyd — Priority: Week 1)
- Generate 1 master hex base shape (flat-top hexagon, ~100 tris)
- Parametric variants: grass overlay, rocky surface, water fill, sand dunes, ruin fragments
- 2-3 variants per biome = ~15 tiles total
- **Time:** 1 day generation + 1 day Blender polish

### 6.2 Vegetation (Sloyd — Priority: Week 2)
- Generate style reference image first (1 tree + 1 bush + 1 flower per biome)
- Image-to-3D for each reference
- Parametric variants: 3 tree shapes, 2 bush shapes, 2 grass clumps per biome
- ~35 vegetation models total
- **Time:** 2 days generation + 1 day Blender atlas

### 6.3 Rocks & Minerals (Sloyd — Priority: Week 2)
- Simplest category. 4-6 rock shapes per biome.
- Crystals for ruins/volcanic biome need emission setup in Godot (not in model)
- ~25 models total
- **Time:** 1 day

### 6.4 Resource Pickups (Sloyd — Priority: Week 2)
- Small floating/spinning objects: wood log, stone chunk, ore nugget, crystal shard, water drop, fiber, berries, fish, alien circuit, data core, etc.
- ~15 models, all <100 tris
- **Time:** 1 day

### 6.5 Structures (Sloyd — Priority: Week 3)
- 10 buildings from GDD (workbench, shelter, furnace, lab, wall, bridge, torch, storage, fuel refinery, launch pad)
- Image-to-3D from concept art for each
- Parametric tweaks for scale/style
- **Time:** 2 days generation + 1 day Blender

### 6.6 Player Character (Tripo — Priority: Week 3)
- Generate astronaut character from concept art reference
- Auto-rig via Tripo
- Export to Mixamo for walk/run/gather/craft animations
- Tool variants: swap hand mesh for axe/pickaxe/multi-tool
- **Time:** 2 days (generation + rigging + animation)

### 6.7 Ship (Tripo — Priority: Week 3)
- Hero asset, most detailed model in game
- Generate base wreck from reference
- Manual Blender work for 4 repair states (hull plates → engine → nav computer → fuel tank)
- **Time:** 2 days (generation + manual states)

### 6.8 Night Fauna (Tripo — Priority: Week 4)
- 3 creature types: small fast, medium tanky, large rare
- Generate from concept art → auto-rig → simple animations (idle, move, attack)
- **Time:** 2 days

### 6.9 UI Icons (AI Image Gen — Priority: Week 4)
- Generate icon sheet with Midjourney/DALL-E: all 25+ items on one sheet
- Cut and resize to 64×64 or 128×128
- Consistent style because generated in one session
- **Time:** 1 day

### 6.10 Particles & Skybox (Godot — Priority: Week 4)
- All particle effects built in Godot's GPUParticles3D
- Skybox: procedural gradient via shader (cheapest, most flexible)
- **Time:** 1-2 days

---

## 7. The Blender Standardization Pass

**This is the most important step.** It's where consistency is enforced.

### Batch Process (run on ALL models before import):

1. **Import** all generated models (.fbx/.glb)
2. **Decimate** to target tri count (Decimate modifier → ratio)
3. **Re-color** to locked palette (Vertex Paint or replace materials)
4. **Scale** to unit grid (player = 1.2m, hex = 2m)
5. **UV unwrap** to atlas regions (one UV atlas per biome)
6. **Apply** all transforms (Ctrl+A → All Transforms)
7. **Export** as .glb (Godot's preferred format)

### Blender Addons That Help:
- **Sprytile** — pixel art style texturing on 3D models
- **Auto-Reload** — hot-reload in Godot on save
- **Vertex Color Master** — batch vertex color operations

---

## 8. Free Asset Packs for Prototyping (Before AI Pipeline)

Don't wait for AI assets. Start building gameplay with free placeholders:

| Pack | Source | Content | License |
|------|--------|---------|---------|
| **Kenney Nature Kit** | kenney.nl | Trees, rocks, grass, flowers | CC0 (public domain) |
| **Kenney Mini Characters** | kenney.nl | Simple characters + animations | CC0 |
| **Quaternius Space Kit** | quaternius.com | Sci-fi buildings, props, ships | CC0 |
| **Quaternius Nature Pack** | quaternius.com | Trees, rocks, nature items | CC0 |
| **Kay Lousberg Characters** | kaylousberg.com | 4 character models + 75 skins + 17 anims + 40 accessories | CC0 |
| **Kay Lousberg Platformer** | itch.io | 100+ low-poly models | CC0 |

**All CC0 = use freely, no attribution required, even commercially.**

These give us playable gameplay in Week 1-2 while the AI pipeline produces final assets.

---

## 9. Alternative: Fiverr/Commission as Backup

If AI consistency fails after honest effort:

| Option | Cost | Timeline | Pros | Cons |
|--------|------|----------|------|------|
| Fiverr low-poly 3D artist | $5-15/model | 1-2 weeks | Human consistency | Slow, expensive at volume |
| Asset pack (CraftPix) | $20-50/pack | Instant | Ready to use | Generic, not custom |
| Upwork 3D modeler | $15-30/hr | 2-4 weeks | Custom, professional | $2K+ for full set |

**Our target:** AI pipeline for 90%, manual touch for 10% (ship, character, hero assets).

---

## 10. Cost Summary (Revised)

| Item | Cost | Notes |
|------|------|-------|
| Sloyd Plus (3 months) | $45 | Unlimited generations — all props/structures |
| Tripo Professional (2 months) | $32 | 150 credits — character, fauna, ship |
| Mixamo | Free | Auto-rigging + animations |
| Blender 4.x | Free | Standardization + polish |
| Kenney/Quaternius packs | Free | Prototyping placeholders |
| Google Play Developer | $25 | One-time |
| Apple Developer | $99/year | Annual |
| **Total Art Pipeline** | **~$77** | For ALL ~150 3D models |
| **Total Launch Cost** | **~$201** | Including Store accounts |

---

## 11. Risk Matrix

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| AI models look inconsistent | High | Critical | Image-to-3D from concept art + Blender standardization pass |
| Poly counts too high for mobile | Medium | High | Sloyd has explicit poly control; Blender Decimate as backup |
| Character rigging breaks | Low | High | Tripo auto-rig + Mixamo fallback |
| Style doesn't "pop" on store | Medium | Critical | Study MLU/Astroneer/Islanders; iterate on style sheet first |
| Texture atlas performance | Low | Medium | Godot batching + shared materials per biome |
| AI tools change pricing | Low | Medium | 2-3 month project; lock in current plans |

---

## 12. Critical Path Summary

```
WEEK 1-2:  Free assets (Kenney/Quaternius) → BUILD GAMEPLAY
              ↓ Meanwhile: generate concept art style sheet
WEEK 3:    Subscribe Sloyd + Tripo
              → Hex tiles + vegetation + rocks (Sloyd)
              → Player character + rigging (Tripo + Mixamo)
WEEK 4:    Structures + resources (Sloyd)
              → Ship + fauna (Tripo)
              → UI icons (AI image gen)
WEEK 5:    Blender standardization pass on ALL models
              → Texture atlases per biome
              → Import to Godot, test performance
              → Particles + skybox in Godot
```

**The concept art style sheet is the SINGLE MOST IMPORTANT DELIVERABLE.** Everything downstream depends on it. Get this right, and the AI tools will follow. Get it wrong, and no amount of Blender polish will save consistency.

---

*"The secret isn't the AI tools. The secret is the reference image. Control the input, control the output."*
