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

shader_type spatial;
render_mode unshaded, cull_back;

varying vec4 v_color;

void vertex() {
	v_color = COLOR;
}

void fragment() {
	ALBEDO = v_color.rgb;
}
