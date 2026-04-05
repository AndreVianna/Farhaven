// Per-vertex color pass-through shader for the single-ArrayMesh hex grid.
//
// Fog state (HIDDEN/REVEALED/VISIBLE) and biome color blending are handled
// entirely in GDScript by manipulating vertex colors before mesh commit.
// This shader simply outputs what the vertex color says.
//
// HIDDEN tiles are excluded from the mesh entirely (no geometry).
// REVEALED tiles have vertex colors pre-multiplied by ~0.4 in GDScript.
// VISIBLE tiles carry full biome colors.
// Highlights are also baked into vertex colors by GDScript.
//
// Time-of-day darkness:
//   darkness uniform (0.0 = bright, 1.0 = pitch black) is driven by DayNightCycle.
//   At night (darkness > 0.3), a distance-based lantern falloff from the player
//   keeps nearby tiles brighter while distant tiles go very dark.

shader_type spatial;
render_mode unshaded, cull_back;

uniform float darkness : hint_range(0.0, 1.0) = 0.0;
uniform vec2 player_world_pos = vec2(0.0, 0.0);

varying vec4 v_color;
varying vec3 v_world_pos;

void vertex() {
    v_color = COLOR;
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 base = v_color.rgb;

    // Apply global darkness
    float brightness = 1.0 - darkness;

    // Night lantern effect: distance-based falloff from player
    if (darkness > 0.3) {
        float dist = distance(v_world_pos.xz, player_world_pos);
        // Smooth falloff: full at 0, 0.8 at ~3.6, 0.6 at ~7.2, 0.3 beyond
        float lantern = clamp(1.0 - dist / 12.0, 0.3, 1.0);
        brightness *= lantern;
    }

    ALBEDO = base * brightness;
}
