// Billboard shader for element icon MultiMesh pools.
// Reads INSTANCE_CUSTOM in vertex() and passes alpha to fragment() via varying.
// INSTANCE_CUSTOM.a controls per-instance visibility (1.0 = visible, 0.0 = hidden).

shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 icon_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying float v_alpha;

void vertex() {
	v_alpha = INSTANCE_CUSTOM.a;

	// Billboard toward camera
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(1.0, 0.0, 0.0, 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(0.0, 0.0, 1.0, 0.0),
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
}

void fragment() {
	ALBEDO = icon_color.rgb;
	ALPHA = icon_color.a * v_alpha;
	if (ALPHA < 0.01) {
		discard;
	}
}
