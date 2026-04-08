# Crash Landing Design — Lore, Mechanics & Biome

*Defined 2026-04-02/03. Source: Andre + Lola design session.*

---

## 1. The Survival Pod — Engineering

The player arrives on the planet inside a military-grade survival pod. Every design choice has an engineering rationale.

### Phase 1: Separation
- **Ejection method:** Electromagnetic railgun (the military ship already has EM infrastructure)
- **No chemical propellant** — eliminates explosion risk in the hangar during combat
- **Acceleration:** Instantaneous, violent. The occupant survives because they're submerged in PFC liquid (see Phase 4)
- **Initial shape:** Ovoid — aerodynamically stable for initial trajectory
- **Micro-gravity navigation:** Automated system targets nearest planet. Maneuvering via bursts of inert gas (liquid nitrogen or helium in small canisters) — inert to avoid combustion during reentry
- **Occupant state:** Deep hibernation, zero awareness

### Phase 2: Atmospheric Reentry
- **Ablative heat shield:** Outer ceramic layer that burns away, absorbing reentry heat
- **Orientation:** Wider base faces descent direction
- **Stability:** Gyroscopic rotation maintained by the gas ejectors
- **Post-reentry:** Outer ablative layer is **explosively ejected** along with the spent gas canisters — clean separation revealing the inner pod

### Phase 3: Deceleration
- **Drogue chute** deploys simultaneously with outer layer ejection — stabilizes and slows from supersonic to subsonic
- **Inner pod shape:** Cylindrical (revealed after outer layer ejection)
- **Main chute** deploys after drogue — slows to survivable speed
- **Pod orientation:** Vertical at this point (hanging from chute)
- **Final meters:** External airbags inflate (kevlar + carbon fiber composite)

### Phase 4: Impact
- **First 1-2 bounces:** Airbags absorb impact normally
- **Critical event:** On second or third bounce, a sharp rock or crystal punctures one or two airbags
- **The airbags are kevlar + carbon fiber** — the fact that they tore tells you how sharp/hard the impact point was
- **No internal foam needed:** The hibernation chamber is filled with **perfluorocarbon (PFC) liquid**
  - PFC is a real substance — breathable liquid that distributes G-forces uniformly across the entire body
  - The occupant literally *breathes* the liquid during hibernation
  - Used in military medical research (The Abyss used this concept)
  - Non-flammable — no fire risk on impact
- **Post-rupture:** Pod bounces, rolls, carves a furrow in the ground
- **Final impact:** Pod splits open, astronaut is ejected several meters from the wreckage
- **Shell state:** Dented, cracked, open. Sparks from damaged electronics. No fire (PFC is non-flammable).

### Phase 5: Post-Landing
- **Beacon:** Activates automatically in the pod. Transmits rescue signal. Nobody is listening — but the astronaut doesn't know this.
- **Military protocol:** Training says stay near the pod and wait for rescue. Standard wait time: 3 days. After 3 days without contact, protocol switches to "auto-rescue."
- **The astronaut wears:**
  - Thermal regulation suit (body armor, environmental protection)
  - High-tech bracelet (scanner) — the central gameplay device

---

## 2. The Awakening — Opening Scene

### The Sequence
1. Astronaut was ejected from the pod in the final meters of impact
2. Gastric tube exit + impact force push most PFC out of lungs
3. Bracelet display: `"Starting Emergency Reawakening Cycle"` → `"Adrenaline Injection..."` → sequence continues
4. Adrenaline injection triggers consciousness
5. **First sensation:** Astronaut vomits remaining PFC liquid, coughs violently
6. The ground around them is wet with PFC. No fire. Sparks from the damaged pod nearby.
7. Gasps — first breath of real air on an alien planet
8. Bracelet shows biometrics: thirst, hunger, health status

### Sensory Details
- Wet ground, wet suit, coughing
- Pod sparking a few meters away
- Furrow in the ground behind the pod (impact trail)
- Debris scattered along the furrow
- Alien sky — unfamiliar colors, unfamiliar sun
- Sounds: wind, crackling electronics, alien fauna in the distance
- Temperature: comfortable (thermal suit working)

---

## 3. The Bracelet — Diegetic UI Device

The bracelet is military equipment. Everything the player sees as "HUD" is actually the bracelet's display. This makes all UI **diegetic** — it exists in the game world, not as an abstract overlay.

### Bracelet Functions
| Function | Gameplay Role |
|----------|--------------|
| **Biometrics** | Health, hunger, thirst bars — readings from the suit's sensors |
| **Scanner** | Proximity scan — catalogs flora, fauna, minerals, anomalies |
| **Flashlight** | Night illumination (~2 hex range) |
| **Mini-map** | Terrain mapping — builds as player explores (see §6) |
| **Beacon locator** | Always shows direction/distance back to pod |

### Scanner Details
- Always on the wrist — never lost, never dropped
- Scan is proximity-based (auto-scan when near, ~6m / 1 hex)
- Three knowledge states: UNKNOWN → ENCOUNTERED → CATALOGED
- The ❓ markers float above props in the world

---

## 4. Emergency Kit — The Rule of Three

Tutorial: First thing the player does is walk to the pod and interact to open the emergency compartment. Inside: a backpack.

**The backpack IS the inventory.** No backpack = no inventory. Diegetic.

### Kit Contents

| Item | Slot | Permanent? | Purpose | Gameplay |
|------|------|------------|---------|----------|
| **Multi-tool** | Weapon | ✅ Yes | Military-grade multi-purpose tool | Harvest basic resources (branches, fruits, small rocks, fiber), basic defense, weak hunting. Always available — player never hits zero capability |
| **Flint & Steel** | Inventory | ✅ Yes | Fire starter | Ignite campfire, torch, furnace. Simple, permanent, military-grade |
| **Rations** | Inventory | ❌ 3 days | Military field rations | Restores hunger. 3-day supply creates the push to leave crash site |
| **Water** | Inventory | ❌ 3 days | Sealed water supply | Restores thirst. Same 3-day pressure |
| **Med Kit** | Inventory | ❌ 3 uses | First aid supplies | Restores health. 3 uses — forgiveness for early mistakes |

### The Rule of Three
- 3 days of food
- 3 days of water
- 3 uses of medical supplies
- **3 days is the military standard** for awaiting rescue before switching to auto-rescue protocol
- The astronaut knows this. The player discovers it.
- Uniform pressure: all consumables run out around the same time, pushing the player out of the crash site

### Tool Progression

| Tool | Source | Unlocks |
|------|--------|---------|
| **Hands** | Always | Nothing (pre-backpack only) |
| **Multi-tool** | Emergency kit | Branches, fruits, small rocks, fiber, basic defense |
| **Stone Axe** | Crafted (stone + branch + fiber) | Full trees (wood), faster harvesting |
| **Stone Pickaxe** | Crafted (stone + branch + fiber) | Ore, crystals, large rocks |
| **Metal tools** | Crafted (scrap/ore) | Everything faster, advanced resources |

Multi-tool never replaces crafted tools — it's slower, less efficient. But it's the floor. The player is never stuck.

---

## 5. Crash Site — Biome Design

### Identity
- **Feeling:** Safety. The womb. Home base — for now.
- **Visual:** Sandy-brown earth. Low scrub vegetation. Impact furrow with exposed earth. Pod wreckage with sparks. Debris trail.
- **Size:** Small — 8-12 hexes (~225-340 m²). Intimate, not sprawling.
- **Hazard:** None. Deliberate. The player learns mechanics here without pressure.
- **Fauna:** None hostile. Maybe curious small creatures observing from a distance — passive, flee on approach. The world feels alive without threat.

### Crash Debris Resources (UNIQUE to Crash Site)
These resources exist nowhere else on the planet. What's here is all there is — no farming, no respawn.

| Resource | Source | Potential Use |
|----------|--------|---------------|
| 🪢 **Parachute fabric** | Chutes tangled in terrain | Shelter material, rope, bandages |
| 🛡️ **Airbag fragments** | Ruptured kevlar + carbon fiber bags | Improvised armor, reinforcement |
| 🧱 **Ablative ceramic** | Heat shield fragments from outer shell | Furnace lining, tool hardening |
| ⛽ **Gas canister** | Maneuvering thruster canisters (partially filled) | Pressurization, refrigeration, future crafting |
| ⚡ **Pod wiring** | Damaged electronics from pod | Basic circuits, electrical components |
| 🔩 **Scrap metal** | Structural pieces of the destroyed pod | Advanced crafting, metal tools |

### Natural Resources (from impact)
The furrow itself exposed these — the pod tore up the ground:

| Resource | Source | Tool Required |
|----------|--------|---------------|
| 🪨 **Small rocks** | Exposed by impact furrow | Multi-tool or hands |
| 🪵 **Branches** | Broken by pod's path | Multi-tool |
| 🌿 **Fiber** | Torn vegetation along furrow | Multi-tool or hands |

### First Anomaly
- The pod itself is the first **Human Anomaly** 🧑
- Scanning the pod = first tutorial scan
- Reveals: flight log entry → narrative begins
- Beacon blinking inside the wreckage

### The Push to Leave
- Limited hexes, limited resources
- Rations run out on day 3
- Training says stay. Stomach says go.
- Journal might suggest: "Need to find water" / "Need better shelter"
- The conflict is **internal** — no NPC tells the player to leave

---

## 6. Fog of War — ELIMINATED from World

### The Problem
- 18m fog visibility makes no sense on an open planet — humans can see kilometers
- Fog overlay prevents beautiful horizons and backgrounds
- On mobile, the screen itself is natural fog — viewport shows ~8-12 hexes max

### The Decision
**Fog of war is removed from the 3D world entirely.**

- All terrain is always visible and rendered (no gray overlay, no dimming)
- Props/resources appear based on camera frustum (natural Godot culling)
- Horizons are visible — mountains, biomes, sky — the world is beautiful from everywhere
- Night reduces visibility via LIGHTING, not fog — bracelet flashlight illuminates ~2 hexes

### Mini-Map on Bracelet
- Small display in HUD corner (bracelet screen)
- Starts empty/black
- Hexes appear as player visits them (color = biome)
- Shows: visited terrain, scanned resources (icons), pod beacon (blinking), player position
- Unvisited areas = black on mini-map, but fully visible in the 3D world
- This is the **only** fog-of-war system — it lives on the bracelet, not in the world

### Code Impact
Fog state system (`HIDDEN`/`REVEALED`/`VISIBLE`) to be refactored:
- `HexTile.fog_state` → replace with `visited: bool` (for mini-map)
- `tile_visibility_changed` signal → replace with `tile_visited`
- PropRenderer fog dimming → remove (all props render at full color)
- PropLabelRenderer fog checks → remove
- Respawn queue fog check → rethink (maybe distance-based instead)

---

## 7. Player Rotation — Camera Fixed

### Decision
- **Player model rotates** to face movement direction (smooth lerp)
- **Camera remains fixed** (isometric, same angle always)
- When player stops, model holds last rotation ("looking" where they were going)
- Same approach as My Little Universe

### Rationale
- Rotating camera on mobile = motion sickness + fat finger issues + disorientation
- Fixed camera = consistent spatial awareness
- Player rotation gives life to the character without complexity
- Mini-map provides orientation regardless of player facing

### Implementation
- Joystick already provides direction vector
- `look_at()` or Y-rotation lerp on player model toward movement direction
- Camera code unchanged
- Simple addition to player movement system

---

## 8. Hex Scale — Physical Dimensions

### Established Scale

| Measurement | Value |
|-------------|-------|
| **Hex diameter** | 6 meters |
| **Hex area** | ~28 m² |
| **Human height** | 1.80m = exactly 30% of hex diameter |
| **HEX_SIZE (Godot)** | 3.0 units |
| **Scale factor** | 1 Godot unit = 2 real meters |

### Gameplay Ranges (Real-World)

| System | Range | Real Distance | Meaning |
|--------|-------|---------------|---------|
| **Auto-gather** | ~1.5m circle around player | Arm's reach | Must walk right up to the prop |
| **Auto-scan** | 1 hex adjacent (~6m) | "I can see what that is from here" | Proximity catalog |
| **Camera viewport** | ~8-12 hexes (~48-72m) | Natural mobile fog | What the screen shows |

### Spatial Implications
- Crash site (8-12 hexes) = 225-340 m² = residential lot size
- Impact furrow (3-4 hexes) = 18-24m of skid marks
- One tree fits comfortably in a hex with space around it
- One shelter/structure occupies a full hex (~4-5m footprint)
- 10 hexes in a straight line = 60 meters — crash site disappears behind you quickly

---

## 9. Auto-Gather — No "Requires Tool" Message

### Decision
If the player walks near a resource they can't harvest (wrong tool), **nothing happens**. No text, no error, no feedback. Silence.

### Rationale
- "REQUIRES TOOL" is gamey — breaks immersion
- The player discovers tool requirements naturally through the catalog
- Catalog entry for a CATALOGED resource shows "Requires: Pickaxe" — the information is there, in-world
- The absence of auto-gather is itself the signal: "I walked past it and nothing happened. Why? Let me check the catalog."

### Code Impact
- Remove `auto_gather_failed` signal emission for `tool_gated` reason
- Remove "REQUIRES TOOL" floating text from HUD wiring
- Keep `inventory_full` feedback (that's a different situation — player CAN gather but has no space)

---

## 10. Design Decisions Not Yet Made

- [ ] Grassland biome details (next in sequence)
- [ ] Forest biome details
- [ ] Other biomes (Rocky, Water, Desert, Swamp, Ruins, Volcanic)
- [ ] Fire-starter interaction model (tap campfire with flint equipped? auto on approach?)
- [ ] Backpack as diegetic inventory — does picking up the backpack trigger inventory UI tutorial?
- [ ] Gas canister specific uses
- [ ] Parachute fabric / airbag fragment recipes
- [ ] Mini-map visual design and interaction
- [ ] Night lighting model (bracelet flashlight range, ambient moonlight)
- [ ] Opening cutscene (text? comic panels? animated? just bracelet text?)
