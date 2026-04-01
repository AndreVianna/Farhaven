// Per-instance fog tinting and highlight shader for hex tiles.
//
// INSTANCE_CUSTOM layout (Color packed as vec4):
//   x (R): fog intensity  — 0.0 = hidden (zero-scale), 0.5 = revealed/dimmed, 1.0 = visible/full
//   y (G): highlight R
//   z (B): highlight G
//   w (A): highlight B
//
// HIDDEN tiles are invisible via zero-scale transform — fog=0.0 is a safety fallback.
// Highlight is inactive when y+z+w == 0.

shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying vec4 v_custom;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
}

void fragment() {
	float fog = v_custom.x;
	vec3 highlight = v_custom.yzw;

	// Dim albedo by fog factor (0.5 = revealed, 1.0 = full brightness)
	vec3 albedo = base_color.rgb * fog;

	// Blend highlight color when any channel is active
	float highlight_active = step(0.001, max(highlight.r, max(highlight.g, highlight.b)));
	albedo = mix(albedo, highlight, highlight_active * 0.5);

	ALBEDO = albedo;
}
