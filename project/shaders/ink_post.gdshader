// Full-screen ink pass: depth + normal edge detection.
// This is what draws creases the inverted hull can't — where the trunk meets the
// ground, where one character overlaps another, folds inside a silhouette.
// Forward+ only (needs the normal-roughness buffer).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest, repeat_disable;

uniform vec4 ink_color : source_color = vec4(0.07, 0.06, 0.10, 1.0);
uniform float line_width : hint_range(1.0, 4.0) = 1.3;
uniform float depth_threshold : hint_range(0.0, 2.0) = 0.22;
uniform float normal_threshold : hint_range(0.0, 2.0) = 0.55;
uniform float max_distance = 45.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.9;

float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
	vec4 view = inv_proj * vec4(ndc, 1.0);
	return -(view.xyz / view.w).z;
}

void vertex() {
	// Draw a screen-covering triangle regardless of where the mesh actually is.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 texel = line_width / vec2(textureSize(depth_tex, 0));

	vec2 o[4];
	o[0] = vec2( texel.x,  0.0);
	o[1] = vec2(-texel.x,  0.0);
	o[2] = vec2( 0.0,  texel.y);
	o[3] = vec2( 0.0, -texel.y);

	float d_center = linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 n_center = texture(normal_tex, SCREEN_UV).rgb * 2.0 - 1.0;

	float depth_edge = 0.0;
	float normal_edge = 0.0;

	for (int i = 0; i < 4; i++) {
		vec2 uv = clamp(SCREEN_UV + o[i], vec2(0.0), vec2(1.0));
		float d = linear_depth(uv, INV_PROJECTION_MATRIX);
		depth_edge = max(depth_edge, abs(d - d_center));

		vec3 n = texture(normal_tex, uv).rgb * 2.0 - 1.0;
		normal_edge = max(normal_edge, 1.0 - dot(n, n_center));
	}

	// Scale the depth test with distance so far geometry doesn't turn into mud.
	float depth_hit = step(depth_threshold * max(d_center * 0.08, 0.35), depth_edge);
	float normal_hit = step(normal_threshold, normal_edge);

	float edge = clamp(max(depth_hit, normal_hit), 0.0, 1.0);
	edge *= 1.0 - smoothstep(max_distance * 0.6, max_distance, d_center);
	edge *= opacity;

	ALBEDO = mix(texture(screen_tex, SCREEN_UV).rgb, ink_color.rgb, edge);
	// Writing ALPHA is what pushes this material into the transparent pass, which
	// is the only place the screen texture has actually been captured yet.
	ALPHA = 1.0;
}
