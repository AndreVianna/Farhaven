// Textured variant of hex_tile.gdshader.
//
// Samples `terrain_texture` with per-vertex UV (0..1 hex-local), then modulates
// by v_color.rgb (which still carries corner-color blending, elevation tint,
// highlight override, and cliff darkening set by GDScript) and the same
// brightness pipeline (darkness, player lantern, local lights) as the solid
// color shader. The cliff side triangles bypass UV sampling and fall back to
// pure vertex color — they use the color-only shader instead.
//
// Keep this in sync with `hex_tile.gdshader` whenever the lighting logic
// changes; the two are deliberate parallel paths.

shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D terrain_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float darkness : hint_range(0.0, 1.0) = 0.0;
uniform vec2 player_world_pos = vec2(0.0, 0.0);

uniform int light_count : hint_range(0, 8) = 0;
uniform vec2 light_positions[8];
uniform float light_radii[8];

varying vec4 v_color;
varying vec3 v_world_pos;
varying vec2 v_uv;

void vertex() {
	v_color = COLOR;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_uv = UV;
}

void fragment() {
	vec3 tex = texture(terrain_texture, v_uv).rgb;
	vec3 base = tex * v_color.rgb;

	float brightness = 1.0 - darkness;

	if (darkness > 0.3) {
		float dist = distance(v_world_pos.xz, player_world_pos);
		float lantern = clamp(1.0 - dist / 12.0, 0.3, 1.0);

		float local_light = 0.0;
		for (int i = 0; i < 8; i++) {
			if (i >= light_count) break;
			float d = distance(v_world_pos.xz, light_positions[i]);
			float r = light_radii[i];
			if (d < r) {
				float t = 1.0 - d / r;
				local_light = max(local_light, t * t);
			}
		}

		float combined = max(lantern, local_light);
		brightness *= combined;
	}

	ALBEDO = base * brightness;
}
